import 'dart:async';
import 'dart:collection';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/ble/blowfit_uuids.dart';
import '../../core/ble/ble_providers.dart';
import '../../core/models/pressure_sample.dart';
import '../../core/storage/storage_providers.dart';
import '../../core/theme/blowfit_colors.dart';
import '../../core/theme/blowfit_widgets.dart';

class TrainingScreen extends ConsumerStatefulWidget {
  const TrainingScreen({super.key});

  @override
  ConsumerState<TrainingScreen> createState() => _TrainingScreenState();
}

class _TrainingScreenState extends ConsumerState<TrainingScreen> {
  static const _windowSec = 30;
  static const _defaultOrifice = OrificeLevel.medium;
  // 목표 압력 기본값 — Settings 에서 재정의되면 build() 에서 덮어씀.
  double _targetLow = 20.0;
  double _targetHigh = 30.0;

  /// 차트 x = 세션 시작 후 경과 초. 샘플 도착 빈도(Real 200Hz / Fake 50Hz)와
  /// 무관하게 wall-clock 과 1:1 로 진행함.
  final Queue<FlSpot> _points = Queue();
  double _current = 0;
  bool _sessionActive = false;
  DateTime? _sessionStart;
  Duration _enduranceMs = Duration.zero;
  Timer? _ticker;
  // Summary 모달이 떴는지 추적. _stop() 의 watchdog 이 모달이 안 뜬 케이스에서만
  // 강제로 홈 복귀하기 위해 사용.
  bool _summaryShown = false;

  DeviceStateCode _phase = DeviceStateCode.standby;

  @override
  void initState() {
    super.initState();
    ref.listenManual<AsyncValue<PressureSample>>(pressureSampleProvider, (_, next) {
      next.whenData(_addSample);
    });
    ref.listenManual<AsyncValue<SessionSummary>>(sessionSummaryProvider, (_, next) {
      next.whenData(_showSummary);
    });
    ref.listenManual<AsyncValue<DeviceSnapshot>>(deviceStateProvider, (_, next) {
      next.whenData((s) => setState(() => _phase = DeviceStateCode.fromByte(s.stateCode)));
    });
    ref.listenManual<AsyncValue<bool>>(connectionProvider, (_, next) {
      next.whenData(_onConnectionChange);
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final connected = ref.read(connectionProvider).valueOrNull ?? false;
      if (connected && !_sessionActive) _start();
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  void _onConnectionChange(bool connected) {
    if (!connected && _sessionActive) {
      setState(() {
        _sessionActive = false;
        _phase = DeviceStateCode.standby;
        // 연결 끊김 시 timer 동결. _sessionStart 가 살아있으면 build() 가 매번
        // now - _sessionStart 를 다시 계산해서 시간이 계속 흐름.
        _sessionStart = null;
      });
      _ticker?.cancel();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            duration: Duration(seconds: 6),
            content: Text('연결이 끊어졌습니다 — 진행 중이던 세션 요약을 받지 못했습니다.'),
          ),
        );
      }
    }
  }

  void _addSample(PressureSample s) {
    final start = _sessionStart;
    if (start == null) return;
    final elapsedSec =
        DateTime.now().difference(start).inMilliseconds / 1000.0;
    setState(() {
      _current = s.cmH2O;
      _points.add(FlSpot(elapsedSec, s.cmH2O));
      // 슬라이딩 윈도우: 가장 최근 30초만 유지.
      while (_points.isNotEmpty &&
          _points.first.x < elapsedSec - _windowSec) {
        _points.removeFirst();
      }
      // endurance 는 _ticker (1s) 가 _current 기준으로 누적 — sample 단위 timing
      // 사용 안 함 (BLE packet jitter + zero-padding 영향 방지).
    });
  }

  Future<void> _start() async {
    // startSession 직전에 목표 압력대를 다시 한 번 펌웨어로 푸시.
    // (펌웨어 reboot 시 RAM 의 zone 이 default 로 리셋되는 케이스 안전망 —
    // targetSyncProvider 의 connect-시 sync 가 timing 으로 못 잡았을 때 대비.)
    try {
      final store = await ref.read(targetSettingsStoreProvider.future);
      final zone = store.load();
      await ref.read(bleManagerProvider).setTarget(zone.low, zone.high);
    } catch (_) {
      // non-fatal — 펌웨어가 default zone (20-30) 으로 진행
    }
    try {
      await ref.read(bleManagerProvider).startSession(_defaultOrifice);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('훈련 시작 실패: $e')),
      );
      return;
    }
    setState(() {
      _sessionActive = true;
      _points.clear();
      _sessionStart = DateTime.now();
      _enduranceMs = Duration.zero;
    });
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        // 매 초 단위로 endurance 누적. sample-단위 timestamp diff 보다 안정적
        // (BLE packet jitter + 펌웨어 zero-padding 영향 안 받음).
        if (_sessionActive &&
            _current >= _targetLow &&
            _current <= _targetHigh) {
          _enduranceMs += const Duration(seconds: 1);
        }
      });
    });
  }

  Future<void> _stop() async {
    await ref.read(bleManagerProvider).stopSession();
    setState(() {
      _sessionActive = false;
      // build() 의 elapsed = now - _sessionStart 가 계속 커지지 않도록 동결.
      _sessionStart = null;
    });
    _ticker?.cancel();
    _summaryShown = false;
    // Watchdog: SessionSummary BLE notify 가 도달 못 하는 케이스에서도 화면이
    // 멈추지 않도록 4초 후에 modal 안 떴으면 홈으로 복귀.
    Future.delayed(const Duration(seconds: 4), () {
      if (!mounted) return;
      if (_sessionActive) return; // 새 세션 시작했으면 무시
      if (_summaryShown) return;  // 모달 이미 떴으면 그대로 둠
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('세션이 종료되었습니다. 기록 탭에서 결과를 확인하세요.'),
        ),
      );
      final nav = Navigator.of(context);
      if (nav.canPop()) nav.pop();
    });
  }

  void _showSummary(SessionSummary s) {
    if (!mounted) return;
    _summaryShown = true;
    setState(() {
      _sessionActive = false;
      _sessionStart = null;
    });
    _ticker?.cancel();
    showModalBottomSheet<void>(
      context: context,
      builder: (_) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '세션 요약',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _summaryRow('최대 압력', '${s.maxPressure.toStringAsFixed(1)} cmH₂O'),
            _summaryRow('평균 압력', '${s.avgPressure.toStringAsFixed(1)} cmH₂O'),
            _summaryRow('지구력 시간', _fmt(s.endurance)),
            _summaryRow('성공 횟수', '${s.targetHits}회'),
            _summaryRow('훈련 시간', _fmt(s.duration)),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: () {
                Navigator.pop(context);
                if (context.canPop()) {
                  context.pop();
                } else {
                  context.go('/');
                }
              },
              child: const Text('확인'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _summaryRow(String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(k, style: const TextStyle(color: Colors.black54)),
            Text(v, style: const TextStyle(fontWeight: FontWeight.w600)),
          ],
        ),
      );

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  // _phaseLabel 은 Phase 4 디자인 변경에서 _PhaseGuide 위젯이 자체 매핑하므로
  // 더 이상 필요없음.

  @override
  Widget build(BuildContext context) {
    final connected = ref.watch(connectionProvider).valueOrNull ?? false;
    final state = ref.watch(deviceStateProvider).valueOrNull;
    final health = ref.watch(bleHealthProvider).valueOrNull;
    final degraded = health?.isDegraded ?? false;
    final zone = ref
        .watch(targetSettingsStoreProvider)
        .valueOrNull
        ?.load();
    if (zone != null) {
      _targetLow = zone.low.toDouble();
      _targetHigh = zone.high.toDouble();
    }
    final elapsed = _sessionStart == null
        ? Duration.zero
        : DateTime.now().difference(_sessionStart!);
    final elapsedSec = elapsed.inMilliseconds / 1000.0;
    final visibleEnd =
        elapsedSec < _windowSec ? _windowSec.toDouble() : elapsedSec;
    final endX = visibleEnd.ceilToDouble();
    final startX = (endX - _windowSec).clamp(0.0, double.infinity);

    // 펌웨어 set 진행도 — Metrics.setIndex / TOTAL_SETS. 디자인은 1/3 ~ 3/3.
    // 현재 firmware 가 setIndex 를 BLE 로 노출 안 해서 임시로 1 고정.
    const totalSets = 3;
    final currentSet = _sessionActive ? 1 : 1;

    return Scaffold(
      backgroundColor: BlowfitColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            _TrainingTopBar(
              currentSet: currentSet,
              totalSets: totalSets,
              onClose: () => context.pop(),
            ),
            const SizedBox(height: 4),
            _PhaseGuide(
              phase: _phase,
              sessionActive: _sessionActive,
            ),
            if (degraded) ...[
              const SizedBox(height: 8),
              const _DegradedSignalBanner(),
            ],
            const SizedBox(height: 12),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _LiveChart(
                  points: _points,
                  startX: startX,
                  endX: endX,
                  current: _current,
                  targetLow: _targetLow,
                  targetHigh: _targetHigh,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _BottomStats(
                endurance: _enduranceMs,
                elapsed: elapsed,
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: connected && _sessionActive ? _stop : null,
                  child: const Text('훈련 종료'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Top bar — close + set chip + (right side reserved for future pause)
// ---------------------------------------------------------------------------

class _TrainingTopBar extends StatelessWidget {
  const _TrainingTopBar({
    required this.currentSet,
    required this.totalSets,
    required this.onClose,
  });

  final int currentSet;
  final int totalSets;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          _CircleIconButton(icon: Icons.close, onTap: onClose),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(999),
              boxShadow: BlowfitColors.shadowLevel1,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  '세트 ',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: BlowfitColors.ink,
                  ),
                ),
                Text(
                  '$currentSet',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: BlowfitColors.blue500,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
                Text(
                  ' / $totalSets',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: BlowfitColors.ink,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          // 향후 일시정지 버튼 자리 — 현재는 빈 공간으로 close 버튼과 시각적 균형.
          const SizedBox(width: 36),
        ],
      ),
    );
  }
}

class _CircleIconButton extends StatelessWidget {
  const _CircleIconButton({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: BlowfitColors.shadowLevel1,
          ),
          child: Icon(icon, size: 20, color: BlowfitColors.gray700),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Phase guide — chip + big text (current pressure visualized via chart)
// ---------------------------------------------------------------------------

class _PhaseGuide extends StatelessWidget {
  const _PhaseGuide({required this.phase, required this.sessionActive});
  final DeviceStateCode phase;
  final bool sessionActive;

  ({String chip, String guide, String sub, IconData icon}) get _content {
    switch (phase) {
      case DeviceStateCode.train:
        return (
          chip: '호기 단계',
          guide: '입으로 강하게 내쉬세요',
          sub: '복부의 힘을 사용하세요',
          icon: Icons.arrow_upward,
        );
      case DeviceStateCode.prep:
        return (
          chip: '준비',
          guide: '곧 시작합니다',
          sub: '편안한 자세로 앉아주세요',
          icon: Icons.timer_outlined,
        );
      case DeviceStateCode.rest:
        return (
          chip: '휴식',
          guide: '잠시 쉬어요',
          sub: '다음 세트를 준비하세요',
          icon: Icons.pause_circle_outline,
        );
      case DeviceStateCode.summary:
        return (
          chip: '완료',
          guide: '훈련 완료!',
          sub: '잘하셨어요',
          icon: Icons.check_circle_outline,
        );
      case DeviceStateCode.standby:
      case DeviceStateCode.boot:
      case DeviceStateCode.weekly:
      case DeviceStateCode.error:
        return (
          chip: '대기',
          guide: sessionActive ? '시작 중...' : '훈련을 시작하세요',
          sub: '기기를 입에 물고 준비하세요',
          icon: Icons.air,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final content = _content;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: BlowfitColors.blue500,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(content.icon, size: 12, color: Colors.white),
                const SizedBox(width: 6),
                Text(
                  content.chip,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: 0.48,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            content.guide,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.78,
              height: 1.25,
              color: BlowfitColors.ink,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            content.sub,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: BlowfitColors.ink3,
            ),
          ),
        ],
      ),
    );
  }
}

class _DegradedSignalBanner extends StatelessWidget {
  const _DegradedSignalBanner();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: BlowfitColors.amberBg,
          borderRadius: BorderRadius.circular(BlowfitRadius.md),
        ),
        child: const Row(
          children: [
            Icon(Icons.signal_cellular_alt_2_bar,
                size: 16, color: BlowfitColors.amberInk),
            SizedBox(width: 8),
            Text(
              '신호 약함 — 일부 데이터가 누락될 수 있습니다',
              style: TextStyle(
                fontSize: 12,
                color: BlowfitColors.amberInk,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Bottom stats — endurance + elapsed
// ---------------------------------------------------------------------------

class _BottomStats extends StatelessWidget {
  const _BottomStats({required this.endurance, required this.elapsed});
  final Duration endurance;
  final Duration elapsed;

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: BlowfitCard(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '지구력 시간',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: BlowfitColors.ink3,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _fmt(endurance),
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: BlowfitColors.ink,
                    letterSpacing: -0.44,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: BlowfitCard(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '훈련 시간',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: BlowfitColors.ink3,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _fmt(elapsed),
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: BlowfitColors.ink,
                    letterSpacing: -0.44,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Bidirectional live chart — Y axis ±30 cmH2O, target zone band,
// realtime current pressure label.
// ---------------------------------------------------------------------------

class _LiveChart extends StatelessWidget {
  const _LiveChart({
    required this.points,
    required this.startX,
    required this.endX,
    required this.current,
    required this.targetLow,
    required this.targetHigh,
  });

  final Queue<FlSpot> points;
  final double startX;
  final double endX;
  final double current;
  final double targetLow;
  final double targetHigh;

  // 디자인의 ±30 cmH2O 양방향 시각화를 따른다. 현재 하드웨어 (XGZP6847A005KPG)
  // 는 양압만 측정하므로 음수 영역은 항상 비어있고, 차후 차압 센서로 교체 시
  // 흡기 데이터가 자동으로 그래프 하단에 들어옴.
  static const double _yMin = -30.0;
  static const double _yMax = 30.0;

  @override
  Widget build(BuildContext context) {
    return BlowfitCard(
      padding: const EdgeInsets.fromLTRB(8, 14, 12, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 헤더 — 라벨 + 현재값 + 목표 구간 범례
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              children: [
                const Text(
                  '실시간 압력',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: BlowfitColors.ink,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  '${current.toStringAsFixed(1)} cmH₂O',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: BlowfitColors.blue500,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
                const Spacer(),
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: BlowfitColors.green100,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 6),
                const Text(
                  '목표 구간',
                  style: TextStyle(
                    fontSize: 11,
                    color: BlowfitColors.ink3,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: LineChart(
              LineChartData(
                minY: _yMin,
                maxY: _yMax,
                minX: startX,
                maxX: endX,
                clipData: const FlClipData.all(),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: 10,
                  getDrawingHorizontalLine: (v) {
                    // y=0 baseline 은 더 진하게.
                    final isZero = v.abs() < 0.01;
                    return FlLine(
                      color: isZero
                          ? BlowfitColors.gray400
                          : BlowfitColors.gray150,
                      strokeWidth: isZero ? 1.2 : 1,
                    );
                  },
                ),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 32,
                      interval: 10,
                      getTitlesWidget: (v, meta) {
                        // -30, -20, ..., +30
                        final n = v.round();
                        final label = n > 0 ? '+$n' : '$n';
                        return Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: SizedBox(
                            width: 24,
                            child: Text(
                              label,
                              textAlign: TextAlign.right,
                              style: const TextStyle(
                                fontSize: 10,
                                color: BlowfitColors.ink3,
                                fontFeatures: [FontFeature.tabularFigures()],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 22,
                      interval: 5,
                      getTitlesWidget: (v, meta) {
                        final sec = v.round();
                        if (sec < 0 || sec % 5 != 0) {
                          return const SizedBox.shrink();
                        }
                        return Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            sec == 0 ? '0' : '${sec}s',
                            style: const TextStyle(
                              fontSize: 10,
                              color: BlowfitColors.ink3,
                              fontFeatures: [FontFeature.tabularFigures()],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                ),
                rangeAnnotations: RangeAnnotations(
                  horizontalRangeAnnotations: [
                    // 호기 (양압) 목표 구간.
                    HorizontalRangeAnnotation(
                      y1: targetLow,
                      y2: targetHigh,
                      color: const Color.fromRGBO(0, 191, 64, 0.12),
                    ),
                    // 흡기 (음압) 목표 구간 — 차후 흡기 센서 추가 시 활용.
                    HorizontalRangeAnnotation(
                      y1: -targetHigh,
                      y2: -targetLow,
                      color: const Color.fromRGBO(0, 191, 64, 0.08),
                    ),
                  ],
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: points.toList(growable: false),
                    isCurved: true,
                    curveSmoothness: 0.25,
                    preventCurveOverShooting: true,
                    color: BlowfitColors.blue500,
                    barWidth: 2.5,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      color: const Color.fromRGBO(0, 102, 255, 0.06),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
