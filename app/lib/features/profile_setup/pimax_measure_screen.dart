// 온보딩 03 — MEP (최대 호기압) / PImax (최대 흡기압) 측정.
//
// 흐름 위치: /onboarding → /profile-setup → /pimax-measure → /connect
//
// 흐름 (호기 → 흡기, 각각 수동 시작):
//   호기를 먼저 측정하는 이유: 강한 호기는 자연스러운 동작이라 시작 부담이
//   적어 입문 단계로 적합. 흡기는 그 뒤에 진행.
//
//   1. introExhale       (수동) — "강하게 내쉬세요" + "측정 시작"
//   2. countdownExhale   (3 s)  — "3, 2, 1"
//   3. measureExhale     (5 s)  — 원형 게이지 + 실시간 +cmH₂O + peak
//   4. introInhale       (수동) — "강하게 들이쉬세요" + "측정 시작"
//   5. countdownInhale   (3 s)
//   6. measureInhale     (5 s)
//   7. summary           — MEP / PImax / 계산된 목표 압력 + "저장하고 시작" /
//                          "처음부터 다시 측정"
//
// 디바이스 측정 모드 (중요!):
//   호기 측정 시작 직전 (countdown 진입 시점) BLE startSession 을 호출해 펌웨어
//   를 Train state 로 들여놓는다. 이렇게 해야:
//     a. 디바이스 LCD 가 "훈련대기" 가 아닌 측정 중 화면을 보여 사용자가
//        측정 중임을 명확히 인지.
//     b. 펌웨어가 BLE pressure stream 을 100Hz 로 안정적으로 push.
//   summary 진입 또는 dispose 시 stopSession 으로 강제 종료 (펌웨어가 Summary
//   notify 를 보내지 않고 Standby 로 복귀하므로 세션 DB row 가 생기지 않음).
//   흡기 측정 종료 시 한 번 stop, 다음 측정 시 다시 start. start/stop pair 가
//   side-effect (햅틱 진동 등) 를 최소화.
//
// 측정 정의:
//   - PImax = 마우스피스로 강하게 흡입 시 발생하는 최대 음압 magnitude (cmH₂O)
//   - MEP   = 강하게 호출 시 최대 양압 (cmH₂O)
//   임상 표준 측정 (Black & Hyatt 1969) 의 1초간 sustained 최댓값 근사 — 5초
//   동안 ALS (autosampling) 으로 peak hold.
//
// 미연결 처리:
//   기기 미연결 시 측정 버튼은 disable. 대신 상단 "건너뛰기" → 기본값(80/60)
//   으로 skip + 다음 화면.
//
// 저장:
//   summary "저장하고 시작" → PimaxMepStore.savePimax/saveMep/saveLevel +
//   BLE 연결돼 있으면 setIntensityTarget 으로 펌웨어에 즉시 반영.

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/ble/ble_providers.dart';
import '../../core/ble/blowfit_uuids.dart';
import '../../core/models/pressure_sample.dart';
import '../../core/storage/pimax_mep_store.dart';
import '../../core/storage/storage_providers.dart';
import '../../core/theme/blowfit_colors.dart';

enum _Step {
  introExhale,      // 호기 — 사용자가 수동 시작
  countdownExhale,
  measureExhale,
  introInhale,      // 호기 측정 종료 → 자동 진입 (3초 안내 후 카운트다운)
  countdownInhale,
  measureInhale,
  summary,
}

/// 측정 동안 압력 stream 을 구독해 peak |p| 를 갱신할 때 쓰는 부호 방향.
/// inhale → 음압 (p < 0), exhale → 양압 (p > 0).
enum _Direction { inhale, exhale }

class PimaxMeasureScreen extends ConsumerStatefulWidget {
  const PimaxMeasureScreen({super.key});

  @override
  ConsumerState<PimaxMeasureScreen> createState() => _PimaxMeasureScreenState();
}

class _PimaxMeasureScreenState extends ConsumerState<PimaxMeasureScreen> {
  static const _measureSec = 5;       // 측정 길이
  static const _countdownSec = 3;     // intro → measure 전 카운트다운

  _Step _step = _Step.introExhale;    // 호기부터 시작
  int _countdownRemain = _countdownSec;
  int _measureRemain = _measureSec;

  double _pimax = 0;        // 측정된 max |음압|
  double _mep = 0;          // 측정된 max 양압
  double _currentMagnitude = 0;  // 실시간 |p| (게이지용)

  /// 펌웨어가 현재 Train state (= 우리가 startSession 으로 진입시킨 측정 모드)
  /// 인지. true 일 때 stopSession 호출 안전. 한 측정(호기 또는 흡기)이 끝나면
  /// false 로 돌리고, 다음 측정 시작 시 다시 true. dispose 안전망에도 사용.
  bool _deviceArmed = false;

  Timer? _tickTimer;
  StreamSubscription<PressureSample>? _sub;

  // ── 디바이스 측정 모드 on/off ────────────────────────────────────────────
  // 측정 시작 직전 startSession → 펌웨어 Train state. LCD 가 측정 화면으로
  // 바뀌고 pressure stream notify 가 안정적으로 흐른다.
  //
  // startPhase 로 cycle 시작 위치 지정 — 호기 측정은 0 (Exhale), 흡기 측정은
  // 1 (Inhale). 펌웨어가 즉시 해당 phase 화면을 표시해 앱과 sync.

  Future<void> _armDeviceMeasureMode(_Direction dir) async {
    if (_deviceArmed) return;
    try {
      await ref.read(bleManagerProvider).startSession(
            OrificeLevel.medium,
            startPhase: dir == _Direction.inhale ? 1 : 0,
          );
      _deviceArmed = true;
    } catch (_) {
      // 실패해도 측정 화면 자체는 진행 — 압력 stream 이 흐르면 측정은 가능.
    }
  }

  Future<void> _releaseDeviceMeasureMode() async {
    if (!_deviceArmed) return;
    _deviceArmed = false;
    try {
      await ref.read(bleManagerProvider).stopSession();
    } catch (_) {}
  }

  // ── 단계 전이 ─────────────────────────────────────────────────────────────

  void _startCountdown(_Step countdownStep) {
    setState(() {
      _step = countdownStep;
      _countdownRemain = _countdownSec;
    });
    // ※ 디바이스 측정 모드 진입(startSession) 은 카운트다운이 끝나는 시점에
    //    _startMeasure() 안에서 호출. 여기서 미리 호출하면 펌웨어가 PREP_MS=0
    //    으로 즉시 Train 으로 들어가 LCD 가 카운트다운 없이 측정 화면으로
    //    점프 → 앱 카운트와 sync 가 안 맞는다.

    _tickTimer?.cancel();
    _tickTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() => _countdownRemain -= 1);
      if (_countdownRemain <= 0) {
        t.cancel();
        // 다음 단계 = 같은 방향의 measure.
        if (countdownStep == _Step.countdownInhale) {
          _startMeasure(_Direction.inhale, _Step.measureInhale);
        } else {
          _startMeasure(_Direction.exhale, _Step.measureExhale);
        }
      }
    });
  }

  void _startMeasure(_Direction dir, _Step measureStep) {
    setState(() {
      _step = measureStep;
      _measureRemain = _measureSec;
      _currentMagnitude = 0;
      if (dir == _Direction.inhale) {
        _pimax = 0;
      } else {
        _mep = 0;
      }
    });
    // 카운트다운이 0 이 된 바로 이 시점에 디바이스를 측정 모드로 — LCD 가 앱
    // 측정 화면 전환과 동시에 측정 화면으로 바뀐다(앱·디바이스 sync). dir 에
    // 따라 펌웨어 cycle 시작 phase 도 호기/흡기로 매칭.
    _armDeviceMeasureMode(dir);

    // 압력 stream 구독 — 측정 방향에 맞는 부호만 추적.
    _sub?.cancel();
    _sub = ref.read(bleManagerProvider).pressureStream.listen((s) {
      if (!mounted) return;
      final p = s.cmH2O;
      final double mag;
      if (dir == _Direction.inhale) {
        if (p >= 0) return;       // 양압은 흡기 측정 대상 아님
        mag = -p;
        if (mag > _pimax) {
          setState(() {
            _pimax = mag;
            _currentMagnitude = mag;
          });
        } else {
          setState(() => _currentMagnitude = mag);
        }
      } else {
        if (p <= 0) return;
        mag = p;
        if (mag > _mep) {
          setState(() {
            _mep = mag;
            _currentMagnitude = mag;
          });
        } else {
          setState(() => _currentMagnitude = mag);
        }
      }
    });

    // 측정 시간 카운트다운.
    _tickTimer?.cancel();
    _tickTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() => _measureRemain -= 1);
      if (_measureRemain <= 0) {
        t.cancel();
        _sub?.cancel();
        _sub = null;
        setState(() => _currentMagnitude = 0);
        // 한 측정이 끝났으면 디바이스 stop — 다음 측정 시 다시 start.
        _releaseDeviceMeasureMode();
        // 호기 끝 → 흡기 intro (사용자가 직접 "측정 시작" 눌러야 진행).
        // 흡기 끝 → summary 직행.
        if (dir == _Direction.exhale) {
          setState(() => _step = _Step.introInhale);
        } else {
          setState(() => _step = _Step.summary);
        }
      }
    });
  }

  /// summary 에서 사용자가 측정을 처음부터 다시 하고 싶을 때.
  void _restartFromExhale() {
    _tickTimer?.cancel();
    _sub?.cancel();
    _releaseDeviceMeasureMode();
    setState(() {
      _step = _Step.introExhale;
      _pimax = 0;
      _mep = 0;
      _currentMagnitude = 0;
    });
  }

  /// 기본값(80/60) 으로 skip — 미연결 또는 측정 거부 시.
  Future<void> _skipWithDefaults() async {
    _tickTimer?.cancel();
    _sub?.cancel();
    await _releaseDeviceMeasureMode();
    final store = await ref.read(pimaxMepStoreProvider.future);
    await store.savePimax(PimaxMepStore.defaultPimax);
    await store.saveMep(PimaxMepStore.defaultMep);
    await store.saveLevel(PimaxMepStore.defaultLevel);
    ref.invalidate(pimaxMepStoreProvider);
    if (!mounted) return;
    context.go('/connect');
  }

  /// summary 단계 — 측정값 저장 + (연결돼 있으면) 펌웨어 전송 + 다음 화면.
  Future<void> _saveAndContinue() async {
    await _releaseDeviceMeasureMode();
    final pimax = _pimax > 0 ? _pimax : PimaxMepStore.defaultPimax;
    final mep   = _mep   > 0 ? _mep   : PimaxMepStore.defaultMep;
    try {
      final store = await ref.read(pimaxMepStoreProvider.future);
      await store.savePimax(pimax);
      await store.saveMep(mep);
      await store.saveLevel(PimaxMepStore.defaultLevel);  // Normal 시작
      ref.invalidate(pimaxMepStoreProvider);
      // 미연결이면 전송 실패 무시 — 다음 connect 때 targetSyncProvider 재전송.
      try {
        await ref.read(bleManagerProvider).setIntensityTarget(
              level: PimaxMepStore.defaultLevel.value,
              pimax: pimax,
              mep: mep,
            );
      } catch (_) {}
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('저장 실패: $e')),
      );
      return;
    }
    if (!mounted) return;
    context.go('/connect');
  }

  @override
  void dispose() {
    _tickTimer?.cancel();
    _sub?.cancel();
    // 측정 중 화면이 강제 종료(라우팅 / 시스템 back) 됐을 때 디바이스를 측정
    // 모드에 남기지 않는 안전망. await 불가 (dispose 동기) — fire-and-forget.
    if (_deviceArmed) {
      _deviceArmed = false;
      ref.read(bleManagerProvider).stopSession().catchError((_) {});
    }
    super.dispose();
  }

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final connected = ref.watch(connectionProvider).valueOrNull ?? false;
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            _TopBar(
              onBack: () {
                _tickTimer?.cancel();
                _sub?.cancel();
                // stopSession 은 짧은 BLE write — fire-and-forget OK.
                _releaseDeviceMeasureMode();
                if (context.canPop()) {
                  context.pop();
                } else {
                  context.go('/profile-setup');
                }
              },
              onSkip: () { _skipWithDefaults(); },
            ),
            _StepProgress(step: _step),
            const SizedBox(height: 8),
            Expanded(child: _body(connected)),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: _bottomButtons(connected),
            ),
          ],
        ),
      ),
    );
  }

  Widget _body(bool connected) {
    switch (_step) {
      case _Step.introExhale:
        return _IntroPanel(
          title: '최대 호기압 (MEP) 측정',
          description:
              '마우스피스를 입에 무신 뒤,\n5초 동안 가능한 가장 강하게\n숨을 내쉬어 주세요.',
          icon: Icons.arrow_upward_rounded,
          accent: const Color(0xFF0A89FC),
          connected: connected,
        );
      case _Step.introInhale:
        return _IntroPanel(
          title: '최대 흡기압 (PImax) 측정',
          description:
              '잠시 숨을 고르신 뒤,\n5초 동안 가능한 가장 강하게\n숨을 들이마셔 주세요.',
          icon: Icons.arrow_downward_rounded,
          accent: const Color(0xFF32B65E),
          connected: connected,
        );
      case _Step.countdownInhale:
      case _Step.countdownExhale:
        return _CountdownPanel(remain: _countdownRemain);
      case _Step.measureInhale:
        return _MeasurePanel(
          label: '들이쉬세요',
          remain: _measureRemain,
          current: _currentMagnitude,
          peak: _pimax,
          accent: const Color(0xFF32B65E),
          isInhale: true,
        );
      case _Step.measureExhale:
        return _MeasurePanel(
          label: '내쉬세요',
          remain: _measureRemain,
          current: _currentMagnitude,
          peak: _mep,
          accent: const Color(0xFF0A89FC),
          isInhale: false,
        );
      case _Step.summary:
        return _SummaryPanel(pimax: _pimax, mep: _mep);
    }
  }

  Widget _bottomButtons(bool connected) {
    switch (_step) {
      case _Step.introExhale:
        // 호기 — 사용자 수동 시작.
        return SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: connected
                ? () => _startCountdown(_Step.countdownExhale)
                : null,
            child: Text(connected ? '측정 시작' : '기기 연결 필요'),
          ),
        );
      case _Step.introInhale:
        // 흡기 — 호기 측정 끝나고 사용자 수동 시작.
        return SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: connected
                ? () => _startCountdown(_Step.countdownInhale)
                : null,
            child: Text(connected ? '측정 시작' : '기기 연결 필요'),
          ),
        );
      case _Step.countdownExhale:
      case _Step.countdownInhale:
      case _Step.measureExhale:
      case _Step.measureInhale:
        // 진행 중에는 버튼 없음.
        return const SizedBox(height: 48);
      case _Step.summary:
        return Column(
          children: [
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _saveAndContinue,
                child: const Text('저장하고 시작'),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: _restartFromExhale,
                child: const Text(
                  '처음부터 다시 측정',
                  style: TextStyle(color: BlowfitColors.ink3),
                ),
              ),
            ),
          ],
        );
    }
  }
}

// ───────────────────────────────────────────────────────────────────────────
// Sub-panels
// ───────────────────────────────────────────────────────────────────────────

class _IntroPanel extends StatelessWidget {
  const _IntroPanel({
    required this.title,
    required this.description,
    required this.icon,
    required this.accent,
    required this.connected,
  });
  final String title;
  final String description;
  final IconData icon;
  final Color accent;
  final bool connected;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          Text(
            title,
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w700,
              height: 1.3,
              letterSpacing: -0.78,
              color: BlowfitColors.ink,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            '내 호흡근 능력에 맞춘 목표 압력을 계산하기 위해 측정해요.',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              height: 1.5,
              color: BlowfitColors.ink2,
            ),
          ),
          const SizedBox(height: 32),
          Center(
            child: Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.10),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 72, color: accent),
            ),
          ),
          const SizedBox(height: 24),
          Center(
            child: Text(
              description,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                height: 1.5,
                color: BlowfitColors.ink2,
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (!connected)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(8),
                child: Text(
                  '기기 연결 후 측정할 수 있어요.\n상단 "건너뛰기" 로 기본값을 사용할 수도 있어요.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.orange,
                    height: 1.4,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _CountdownPanel extends StatelessWidget {
  const _CountdownPanel({required this.remain});
  final int remain;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            '준비',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w500,
              color: BlowfitColors.ink2,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            '$remain',
            style: const TextStyle(
              fontSize: 120,
              fontWeight: FontWeight.w800,
              color: BlowfitColors.ink,
              height: 1.0,
            ),
          ),
        ],
      ),
    );
  }
}

class _MeasurePanel extends StatelessWidget {
  const _MeasurePanel({
    required this.label,
    required this.remain,
    required this.current,
    required this.peak,
    required this.accent,
    required this.isInhale,
  });
  final String label;
  final int remain;
  final double current;
  final double peak;
  final Color accent;
  final bool isInhale;

  @override
  Widget build(BuildContext context) {
    // 실시간 게이지 — 100 cmH₂O 를 풀 스케일로 가정 (충분히 여유).
    const fullScale = 100.0;
    final fraction = (current / fullScale).clamp(0.0, 1.0);
    final peakFraction = (peak / fullScale).clamp(0.0, 1.0);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: accent,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '$remain초 남음',
            style: const TextStyle(
              fontSize: 14,
              color: BlowfitColors.ink2,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 24),
          // 큰 게이지 (원형). 현재 압력 = 실시간, peak = 측정 중 최댓값 hold.
          SizedBox(
            width: 220,
            height: 220,
            child: CustomPaint(
              painter: _GaugePainter(
                fraction: fraction,
                peakFraction: peakFraction,
                accent: accent,
                isInhale: isInhale,
              ),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${isInhale ? "-" : "+"}${current.toStringAsFixed(0)}',
                      style: const TextStyle(
                        fontSize: 44,
                        fontWeight: FontWeight.w800,
                        color: BlowfitColors.ink,
                      ),
                    ),
                    const Text(
                      'cmH₂O',
                      style: TextStyle(
                        fontSize: 13,
                        color: BlowfitColors.ink2,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'peak ${isInhale ? "-" : "+"}${peak.toStringAsFixed(0)} cmH₂O',
            style: TextStyle(
              fontSize: 14,
              color: accent,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryPanel extends ConsumerWidget {
  const _SummaryPanel({required this.pimax, required this.mep});
  final double pimax;
  final double mep;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 기본 강도(Normal) 로 계산된 흡기/호기 target 미리보기.
    const level = PimaxMepStore.defaultLevel;
    final effectivePimax = pimax > 0 ? pimax : PimaxMepStore.defaultPimax;
    final effectiveMep   = mep   > 0 ? mep   : PimaxMepStore.defaultMep;
    final inhaleLow  = (effectivePimax * level.lowPct).round();
    final inhaleHigh = (effectivePimax * level.highPct).round();
    final exhaleLow  = (effectiveMep * level.lowPct).round();
    final exhaleHigh = (effectiveMep * level.highPct).round();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          const Text(
            '측정 완료',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.78,
              color: BlowfitColors.ink,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            pimax > 0 && mep > 0
                ? '측정 결과로 적정 강도를 계산했어요.'
                : '일부 측정값이 없어 기본값으로 진행해요. 설정에서 언제든지 변경할 수 있어요.',
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              height: 1.5,
              color: BlowfitColors.ink2,
            ),
          ),
          const SizedBox(height: 24),
          // 측정 순서대로 표시 — 호기 (MEP) → 흡기 (PImax).
          _MeasureRow(label: 'MEP',   value: mep,   isInhale: false),
          const SizedBox(height: 8),
          _MeasureRow(label: 'PImax', value: pimax, isInhale: true),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '계산된 목표 압력 (${level.label} · ${level.midPct}%)',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: BlowfitColors.ink,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '흡기  -$inhaleLow ~ -$inhaleHigh cmH₂O',
                  style: const TextStyle(
                    fontSize: 15,
                    color: BlowfitColors.ink,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '호기  +$exhaleLow ~ +$exhaleHigh cmH₂O',
                  style: const TextStyle(
                    fontSize: 15,
                    color: BlowfitColors.ink,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MeasureRow extends StatelessWidget {
  const _MeasureRow({
    required this.label,
    required this.value,
    required this.isInhale,
  });
  final String label;
  final double value;
  final bool isInhale;

  @override
  Widget build(BuildContext context) {
    final showFallback = value <= 0;
    return Row(
      children: [
        SizedBox(
          width: 60,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: BlowfitColors.ink2,
            ),
          ),
        ),
        Expanded(
          child: Text(
            showFallback
                ? '기본값 ${(isInhale ? PimaxMepStore.defaultPimax : PimaxMepStore.defaultMep).toStringAsFixed(0)} cmH₂O'
                : '${isInhale ? "-" : "+"}${value.toStringAsFixed(0)} cmH₂O',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: showFallback ? BlowfitColors.ink3 : BlowfitColors.ink,
            ),
          ),
        ),
      ],
    );
  }
}

// ───────────────────────────────────────────────────────────────────────────
// Top bar — 뒤로 / 건너뛰기
// ───────────────────────────────────────────────────────────────────────────

class _TopBar extends StatelessWidget {
  const _TopBar({required this.onBack, required this.onSkip});
  final VoidCallback onBack;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          IconButton(
            onPressed: onBack,
            icon: const Icon(
              Icons.chevron_left,
              size: 26,
              color: BlowfitColors.ink,
            ),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          ),
          const Spacer(),
          TextButton(
            onPressed: onSkip,
            child: const Text(
              '건너뛰기',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: BlowfitColors.ink3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StepProgress extends StatelessWidget {
  const _StepProgress({required this.step});
  final _Step step;

  /// 진행률 — 7 단계 중 어느 정도 왔는지 (호기 → 흡기 순).
  double get _progress {
    switch (step) {
      case _Step.introExhale:      return 0.10;
      case _Step.countdownExhale:  return 0.20;
      case _Step.measureExhale:    return 0.40;
      case _Step.introInhale:      return 0.55;
      case _Step.countdownInhale:  return 0.65;
      case _Step.measureInhale:    return 0.85;
      case _Step.summary:          return 1.00;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: LinearProgressIndicator(
          value: _progress,
          minHeight: 4,
          backgroundColor: Colors.grey.shade200,
          valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF0066FF)),
        ),
      ),
    );
  }
}

// ───────────────────────────────────────────────────────────────────────────
// Gauge painter — 원형 progress (현재 압력) + peak 마커.
// ───────────────────────────────────────────────────────────────────────────

class _GaugePainter extends CustomPainter {
  _GaugePainter({
    required this.fraction,
    required this.peakFraction,
    required this.accent,
    required this.isInhale,
  });
  final double fraction;
  final double peakFraction;
  final Color accent;
  final bool isInhale;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.shortestSide / 2 - 12;
    // 트랙 — 회색 원호 (270°, 12시 부근 빈 공간).
    final trackPaint = Paint()
      ..color = Colors.grey.shade200
      ..style = PaintingStyle.stroke
      ..strokeWidth = 16
      ..strokeCap = StrokeCap.round;
    const startAngle = math.pi * 0.75;   // 135°
    const sweepAngle = math.pi * 1.5;    // 270°
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false,
      trackPaint,
    );
    // 현재 값 — 색상 stroke.
    final activePaint = Paint()
      ..color = accent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 16
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle * fraction.clamp(0.0, 1.0),
      false,
      activePaint,
    );
    // peak 마커 (작은 점) — peak 까지 도달했음을 표시.
    if (peakFraction > 0) {
      final ang = startAngle + sweepAngle * peakFraction.clamp(0.0, 1.0);
      final markerCenter = Offset(
        center.dx + radius * math.cos(ang),
        center.dy + radius * math.sin(ang),
      );
      final markerPaint = Paint()
        ..color = accent
        ..style = PaintingStyle.fill;
      canvas.drawCircle(markerCenter, 8, markerPaint);
      final outline = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      canvas.drawCircle(markerCenter, 8, outline);
    }
  }

  @override
  bool shouldRepaint(_GaugePainter old) =>
      old.fraction != fraction ||
      old.peakFraction != peakFraction ||
      old.accent != accent ||
      old.isInhale != isInhale;
}
