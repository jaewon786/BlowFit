// 훈련 화면 v3 — Kirby 캐릭터 + 무한 스크롤 배경 + 거리 누적.
//
// 결정 (Q1~Q5):
//   Q1: 목표 거리 = 1500m
//   Q2: 걷기 속도 = 50 m/s (목표 zone 안에서만)
//   Q3: 호기/흡기 시간 분할 — _exhalePeriodSec 동안 호기 turn, _inhalePeriodSec
//        동안 흡기 turn 반복. 흡기 turn 일 때 센서 양압값을 음수로 뒤집어 표시
//        (v3.2 하드웨어 임시 정책 — v4.0 양방향 센서 도입 후 제거 예정)
//   Q4: 압력 바 범위 = -30 ~ +30 cmH₂O
//   Q5: 별 위치는 화면 우측 시작 → 캐릭터 입 위치 (중앙 위쪽)

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart' show Ticker;
import 'package:flutter/services.dart' show SystemUiOverlayStyle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/ble/blowfit_uuids.dart';
import '../../core/ble/ble_providers.dart';
import '../../core/models/pressure_sample.dart';
import '../../core/storage/storage_providers.dart';
import '../../core/theme/blowfit_colors.dart';
import 'widgets/celebration_overlay.dart';
import 'widgets/infinite_scroll_background.dart';
import 'widgets/kirby_character.dart';
import 'widgets/pressure_bar_bottom.dart';
import 'widgets/star_eating_overlay.dart';

/// 호기/흡기 turn — Q3 시간 분할.
enum _CycleTurn { exhale, inhale }

class TrainingScreen extends ConsumerStatefulWidget {
  const TrainingScreen({super.key});

  @override
  ConsumerState<TrainingScreen> createState() => _TrainingScreenState();
}

class _TrainingScreenState extends ConsumerState<TrainingScreen>
    with SingleTickerProviderStateMixin {
  // ---- 정책 상수 ----
  static const double _targetDistanceM = 1500;
  static const double _walkingSpeedMps = 50;
  static const _defaultOrifice = OrificeLevel.medium;
  // 30s 호기 + 30s 흡기 사이클.
  static const _exhalePeriodSec = 30.0;
  static const _inhalePeriodSec = 30.0;
  static const _cycleSec = _exhalePeriodSec + _inhalePeriodSec;

  // ---- 목표 압력 zone (양수) ----
  double _targetLow = 20.0;
  double _targetHigh = 30.0;

  // ---- 세션 / 압력 상태 ----
  /// 가장 최근 sensor raw 양압 (cmH₂O). 흡기 turn 일 때 displayPressure 에서
  /// 음수로 뒤집어서 사용.
  double _rawPressure = 0;
  bool _sessionActive = false;
  DateTime? _sessionStart;
  Timer? _ticker1Hz;

  // ---- Turn 전환 추적 — 호기↔흡기 변경 시 압력 0 reset + 짧은 transition. ----
  _CycleTurn? _lastTurn;
  DateTime? _turnChangedAt;
  static const _turnTransitionMs = 500;

  // ---- 거리 누적 (m). Ticker 기반 dt 적분. ----
  late final Ticker _frameTicker;
  Duration _lastFrameElapsed = Duration.zero;
  double _distanceM = 0;
  bool _celebrationShown = false;

  // ---- 세션 종료 / 결과 화면 watchdog ----
  bool _summaryShown = false;

  @override
  void initState() {
    super.initState();
    _frameTicker = createTicker(_onFrame)..start();

    ref.listenManual<AsyncValue<PressureSample>>(pressureSampleProvider, (_, n) {
      n.whenData(_onSample);
    });
    ref.listenManual<AsyncValue<SessionSummary>>(sessionSummaryProvider, (_, n) {
      n.whenData(_onSummary);
    });
    ref.listenManual<AsyncValue<bool>>(connectionProvider, (_, n) {
      n.whenData(_onConnectionChange);
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final connected = ref.read(connectionProvider).valueOrNull ?? false;
      if (connected && !_sessionActive) _start();
    });
  }

  @override
  void dispose() {
    _frameTicker.dispose();
    _ticker1Hz?.cancel();
    super.dispose();
  }

  // ---- BLE / 세션 관리 ----------------------------------------------------

  void _onConnectionChange(bool connected) {
    if (!connected && _sessionActive) {
      setState(() {
        _sessionActive = false;
        _sessionStart = null;
      });
      _ticker1Hz?.cancel();
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

  void _onSample(PressureSample s) {
    // Turn 전환 직후 짧은 transition window 동안에는 새 sensor 값 무시 — 압력바
    // indicator 가 0 에서 점프 없이 다시 올라오도록.
    final changed = _turnChangedAt;
    if (changed != null) {
      final since = DateTime.now().difference(changed).inMilliseconds;
      if (since < _turnTransitionMs) return;
    }
    _rawPressure = s.cmH2O;
    // setState 불필요 — _onFrame 에서 매 프레임 setState 함.
  }

  void _onSummary(SessionSummary s) {
    if (!mounted) return;
    _summaryShown = true;
    setState(() {
      _sessionActive = false;
      _sessionStart = null;
    });
    _ticker1Hz?.cancel();
    context.go('/result', extra: s);
  }

  Future<void> _start() async {
    try {
      final store = await ref.read(targetSettingsStoreProvider.future);
      final zone = store.load();
      await ref.read(bleManagerProvider).setTarget(zone.low, zone.high);
    } catch (_) {/* non-fatal */}

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
      _sessionStart = DateTime.now();
      _distanceM = 0;
      _celebrationShown = false;
      _lastTurn = null;
      _turnChangedAt = null;
      _rawPressure = 0;
    });
    _ticker1Hz?.cancel();
    _ticker1Hz = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {});
    });
  }

  Future<void> _stop({bool goHome = true}) async {
    await ref.read(bleManagerProvider).stopSession();
    setState(() {
      _sessionActive = false;
      _sessionStart = null;
    });
    _ticker1Hz?.cancel();
    if (!goHome) return;
    Future.delayed(const Duration(seconds: 4), () {
      if (!mounted) return;
      if (_sessionActive) return;
      if (_summaryShown) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('세션이 종료되었습니다. 기록 탭에서 결과를 확인하세요.'),
        ),
      );
      final nav = Navigator.of(context);
      if (nav.canPop()) nav.pop();
    });
  }

  // ---- Cycle / Distance --------------------------------------------------

  /// 현재 cycle turn 계산 — 세션 시작 후 elapsed 기준.
  _CycleTurn _currentTurn(double elapsedSec) {
    final mod = elapsedSec % _cycleSec;
    return mod < _exhalePeriodSec ? _CycleTurn.exhale : _CycleTurn.inhale;
  }

  /// 현재 turn 의 남은 시간 (s).
  double _remainingInTurn(double elapsedSec) {
    final mod = elapsedSec % _cycleSec;
    return mod < _exhalePeriodSec
        ? _exhalePeriodSec - mod
        : _cycleSec - mod;
  }

  void _onFrame(Duration elapsed) {
    final dt = (elapsed - _lastFrameElapsed).inMicroseconds / 1e6;
    _lastFrameElapsed = elapsed;
    if (dt <= 0) return;
    if (!_sessionActive) return;
    if (_celebrationShown) return;

    final start = _sessionStart;
    if (start == null) return;
    final elapsedSec =
        DateTime.now().difference(start).inMilliseconds / 1000.0;
    final turn = _currentTurn(elapsedSec);

    // Turn 전환 검지 — 호기↔흡기 변경 시 압력 0 reset + transition window 시작.
    if (_lastTurn != null && _lastTurn != turn) {
      _rawPressure = 0;
      _turnChangedAt = DateTime.now();
    }
    _lastTurn = turn;

    final raw = _rawPressure;

    // 호기 turn + 양압 zone 안일 때만 거리 누적. 흡기 turn 은 거리 증가 안 함
    // (사용자 결정 — 흡기는 호흡 훈련 목적, 진행은 호기로만).
    final inZoneAbs = raw >= _targetLow && raw <= _targetHigh;
    final shouldWalk = inZoneAbs && turn == _CycleTurn.exhale;

    if (shouldWalk) {
      _distanceM += _walkingSpeedMps * dt;
      if (_distanceM >= _targetDistanceM) {
        _distanceM = _targetDistanceM;
        _celebrationShown = true;
        // 세션은 유지하고 modal 만 표시 — 사용자 "결과 보기" 버튼이 _stop 호출.
      }
    }

    // setState 로 build 트리거. _onFrame 은 매 프레임 호출되므로 부드러운 갱신.
    setState(() {});
  }

  // ---- Build --------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final connected = ref.watch(connectionProvider).valueOrNull ?? false;
    final health = ref.watch(bleHealthProvider).valueOrNull;
    final degraded = health?.isDegraded ?? false;

    final zone = ref.watch(targetSettingsStoreProvider).valueOrNull?.load();
    if (zone != null) {
      _targetLow = zone.low.toDouble();
      _targetHigh = zone.high.toDouble();
    }

    final start = _sessionStart;
    final elapsed =
        start == null ? Duration.zero : DateTime.now().difference(start);
    final elapsedSec = elapsed.inMilliseconds / 1000.0;

    final turn = _sessionActive ? _currentTurn(elapsedSec) : _CycleTurn.exhale;
    final remaining = _sessionActive ? _remainingInTurn(elapsedSec) : 0.0;

    // displayPressure — 흡기 turn 이면 부호 뒤집기 (Q3 임시 정책).
    final displayPressure =
        turn == _CycleTurn.inhale ? -_rawPressure : _rawPressure;

    final inZoneAbs = _rawPressure >= _targetLow && _rawPressure <= _targetHigh;

    // Kirby 동작 결정.
    KirbyPhase kirbyPhase;
    if (!_sessionActive) {
      kirbyPhase = KirbyPhase.idle;
    } else if (turn == _CycleTurn.exhale && inZoneAbs) {
      kirbyPhase = KirbyPhase.exhale;
    } else if (turn == _CycleTurn.inhale && inZoneAbs) {
      kirbyPhase = KirbyPhase.inhale;
    } else {
      kirbyPhase = KirbyPhase.idle;
    }

    final walking = kirbyPhase == KirbyPhase.exhale;
    final eatingStars = kirbyPhase == KirbyPhase.inhale;

    // Idle 시 Rive 의 pressure 도 0 으로 강제 — Kirby.riv SM 이 pressure 값
    // 자체로 호흡 state transition 하는 케이스 차단.
    final pressureToKirby =
        kirbyPhase == KirbyPhase.idle ? 0.0 : displayPressure;

    // 레이아웃 상수.
    // 풀밭 (가운데 갈색 길) 위치 = 화면 위에서 ~64% 지점.
    // kirbyFootRatio: 작을수록 박스가 풀밭 라인 가까이 내려감 (박스 안 vertical
    // center 정렬 + Rive artboard 가로형 → 박스 가운데가 캐릭터 실제 위치).
    // 0.45 → 박스 가운데가 풀밭 라인에 정렬되어 캐릭터 발이 시각적으로 풀밭에.
    // kirbyHorizontalShift: 가운데에서 왼쪽으로 70px 이동.
    const kirbySize = 360.0;
    const grassLineRatio = 0.64;
    const kirbyFootRatio = 0.40;
    const kirbyHorizontalShift = -70.0;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
      child: Scaffold(
        body: LayoutBuilder(
        builder: (context, constraints) {
          final h = constraints.maxHeight;
          final w = constraints.maxWidth;
          final grassLineY = h * grassLineRatio;
          final kirbyTop = grassLineY - kirbySize * kirbyFootRatio;
          final kirbyLeft = (w - kirbySize) / 2 + kirbyHorizontalShift;
          // Kirby 박스 안 입 위치 — 박스 top 으로부터 박스 height 의 ~38%
          // (얼굴이 박스 위쪽 절반에 있음).
          final mouthY = kirbyTop + kirbySize * 0.38;
          // Alignment 좌표로 변환 (Stack 영역 = LayoutBuilder size).
          final mouthAlignY = (mouthY / h) * 2 - 1;

          return Stack(
            children: [
              // ---- 1) 무한 스크롤 배경 (전체 화면) ----
              Positioned.fill(
                child: InfiniteScrollBackground(
                  walking: walking,
                  speedMps: _walkingSpeedMps,
                ),
              ),

              // ---- 2) Kirby 캐릭터 — 풀밭 라인에 발 닿도록 절대 px 좌표 ----
              Positioned(
                left: kirbyLeft,
                top: kirbyTop,
                width: kirbySize,
                height: kirbySize,
                child: KirbyCharacter(
                  phase: kirbyPhase,
                  pressure: pressureToKirby,
                ),
              ),

              // ---- 3) 별 먹기 오버레이 (흡기 zone 시) ----
              Positioned.fill(
                child: StarEatingOverlay(
                  active: eatingStars,
                  mouthAlignment: Alignment(-0.05, mouthAlignY),
                ),
              ),

              // ---- 4a) 통합 HUD — 화면 위쪽 stick, 좌우 여백 0 ----
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: SafeArea(
                  bottom: false,
                  child: _TrainingHud(
                    currentMeters: _distanceM,
                    targetMeters: _targetDistanceM,
                    turn: turn,
                    remainingSec: remaining,
                    sessionActive: _sessionActive,
                    pressure: displayPressure,
                    targetLow: _targetLow,
                    targetHigh: _targetHigh,
                    degraded: degraded,
                  ),
                ),
              ),

              // ---- 4b) 종료 버튼 — 화면 아래 stick ----
              Positioned(
                left: 16,
                right: 16,
                bottom: 0,
                child: SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed:
                            connected && _sessionActive ? _stop : null,
                        child: const Text('훈련 종료'),
                      ),
                    ),
                  ),
                ),
              ),

              // ---- 5) Celebration overlay (도달 시) ----
              if (_celebrationShown)
                CelebrationOverlay(
                  distanceMeters: _distanceM,
                  elapsed: elapsed,
                  onContinue: () => _stop(goHome: true),
                ),
            ],
          );
        },
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 통합 HUD — 진행 거리 + Phase 배너 + 압력 바 한 카드. 화면 폭 100% + 위쪽 stick.
// ---------------------------------------------------------------------------

class _TrainingHud extends StatelessWidget {
  const _TrainingHud({
    required this.currentMeters,
    required this.targetMeters,
    required this.turn,
    required this.remainingSec,
    required this.sessionActive,
    required this.pressure,
    required this.targetLow,
    required this.targetHigh,
    required this.degraded,
  });

  final double currentMeters;
  final double targetMeters;
  final _CycleTurn turn;
  final double remainingSec;
  final bool sessionActive;
  final double pressure;
  final double targetLow;
  final double targetHigh;
  final bool degraded;

  @override
  Widget build(BuildContext context) {
    // 외곽 흰 카드 제거 — 배경 이미지의 sky 가 위쪽 영역에 그대로 보이도록.
    // Section 1 (진행거리) 은 카드 없이 sky 위 직접 표시 + 얇은 progress bar.
    // Section 2 (Phase) 는 그라디언트 카드 그대로 (호기/흡기 컬러 cue).
    // Section 3 (실시간 압력) 은 반투명 흰 카드 그대로 (sky 위 떠있는 느낌).
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
      child: Column(
        children: [
          // Section 1: 진행 거리 — sky 위 minimal.
          _ProgressMinimal(
            currentMeters: currentMeters,
            targetMeters: targetMeters,
          ),
          const SizedBox(height: 14),
          // Section 2: Phase 배너 (그라디언트 컬러).
          _PhaseBanner(
            turn: turn,
            remainingSec: remainingSec,
            sessionActive: sessionActive,
          ),
          const SizedBox(height: 12),
          // Section 3: 실시간 압력 바 (반투명 흰 카드).
          PressureBarBottom(
            pressure: pressure,
            targetLow: targetLow,
            targetHigh: targetHigh,
          ),
          if (degraded) ...[
            const SizedBox(height: 8),
            const _DegradedSignalBanner(),
          ],
        ],
      ),
    );
  }
}

/// 진행 거리 minimal — sky 위에 직접 표시 (카드 없음).
class _ProgressMinimal extends StatelessWidget {
  const _ProgressMinimal({
    required this.currentMeters,
    required this.targetMeters,
  });

  final double currentMeters;
  final double targetMeters;

  @override
  Widget build(BuildContext context) {
    final ratio = targetMeters <= 0
        ? 0.0
        : (currentMeters / targetMeters).clamp(0.0, 1.0);
    final cur = currentMeters.clamp(0, targetMeters).round();
    final tgt = targetMeters.round();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Icon(
              Icons.flag_outlined,
              size: 16,
              color: BlowfitColors.gray800,
            ),
            const SizedBox(width: 6),
            const Text(
              '진행 거리',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: BlowfitColors.gray800,
              ),
            ),
            const Spacer(),
            Text(
              '$cur',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: BlowfitColors.blue500,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
            Text(
              ' / $tgt m',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: BlowfitColors.gray800,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        // 얇은 progress bar — sky 위 흰색 트랙 + 파란 fill.
        ClipRRect(
          borderRadius: BorderRadius.circular(2),
          child: SizedBox(
            height: 3,
            child: Stack(
              children: [
                Container(color: const Color.fromRGBO(255, 255, 255, 0.55)),
                FractionallySizedBox(
                  widthFactor: ratio,
                  heightFactor: 1,
                  child: Container(color: BlowfitColors.blue500),
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
// Phase 배너 — 큰 카드, 호기/흡기 컬러 차별화 + 큰 카운트다운 숫자
// ---------------------------------------------------------------------------

class _PhaseBanner extends StatelessWidget {
  const _PhaseBanner({
    required this.turn,
    required this.remainingSec,
    required this.sessionActive,
  });

  final _CycleTurn turn;
  final double remainingSec;
  final bool sessionActive;

  @override
  Widget build(BuildContext context) {
    final isExhale = turn == _CycleTurn.exhale;
    // 호기 = 파랑, 흡기 = 보라/마젠타 — 명확히 다른 두 컬러.
    final List<Color> gradient = !sessionActive
        ? const [Color(0xFF6B7280), Color(0xFF4B5563)]
        : isExhale
            ? const [Color(0xFF5C8CFF), BlowfitColors.blue500]
            : const [Color(0xFFB084F2), Color(0xFF7C3AED)];
    final glow = !sessionActive
        ? const Color.fromRGBO(75, 85, 99, 0.25)
        : isExhale
            ? const Color.fromRGBO(0, 102, 255, 0.30)
            : const Color.fromRGBO(124, 58, 237, 0.30);
    final title = !sessionActive
        ? '대기 중'
        : isExhale
            ? '호기 차례'
            : '흡기 차례';
    final guide = !sessionActive
        ? '연결을 기다리는 중'
        : isExhale
            ? '강하게 내쉬세요'
            : '천천히 들이마시세요';
    final icon = isExhale ? Icons.north : Icons.south;
    final iconLabel = isExhale ? '내쉬기' : '들이마시기';

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(BlowfitRadius.lg),
        boxShadow: [
          BoxShadow(
            color: glow,
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          // 좌측 — 큰 화살표 아이콘 in 원
          Container(
            width: 56,
            height: 56,
            decoration: const BoxDecoration(
              color: Color.fromRGBO(255, 255, 255, 0.22),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 32, color: Colors.white),
          ),
          const SizedBox(width: 14),
          // 가운데 — 라벨 + 가이드
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.4,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: const Color.fromRGBO(255, 255, 255, 0.22),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        iconLabel,
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  guide,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Color.fromRGBO(255, 255, 255, 0.88),
                  ),
                ),
              ],
            ),
          ),
          // 우측 — 큰 카운트다운 숫자
          if (sessionActive)
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${remainingSec.ceil()}',
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                    height: 1,
                    letterSpacing: -1,
                    color: Colors.white,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
                const Text(
                  '초',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Color.fromRGBO(255, 255, 255, 0.85),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

class _DegradedSignalBanner extends StatelessWidget {
  const _DegradedSignalBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: BlowfitColors.amberBg,
        borderRadius: BorderRadius.circular(BlowfitRadius.md),
      ),
      child: const Row(
        children: [
          Icon(
            Icons.signal_cellular_alt_2_bar,
            size: 16,
            color: BlowfitColors.amberInk,
          ),
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
    );
  }
}
