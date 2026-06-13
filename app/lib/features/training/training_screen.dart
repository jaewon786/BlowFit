// Figma DoT — 훈련 화면 (라이트모드).
//
// 디자인 출처: 1:2236 훈련화면 - 라이트모드 (402×874).
//
// Ring 동작:
//   4-phase cycle 반복 (exhale → exhaleRest → inhale → inhaleRest)
//   - exhale phase  : 파란 호가 12시(-π/2) → 시계방향 → 6시(+π/2). |pressure|/목표mid * 180°
//   - exhaleRest    : 파란 호 그대로 유지
//   - inhale phase  : 초록 호가 6시 → 좌측(9시) → 12시. |pressure|/목표mid * 180°
//   - inhaleRest    : 진입 시 두 arc 모두 0 으로 reset (다음 cycle 준비)
//   풀스케일(180°, 호 끝=호기 6시·흡기 12시) = 목표 압력 중간값(mid). 목표 구간
//   (low~high)은 그 끝점을 가운데 두고 amber 밴드로 표시 → 중간값이 6시/12시.
// 가운데 텍스트: phase 카운트다운 (10초→0초 또는 3초→0초), 색 검정 고정.
// 압력 source: BLE `pressureSampleProvider` 의 PressureSample.cmH2O 실시간.

import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../core/ble/ble_providers.dart';
import '../../core/storage/storage_providers.dart';
import '../../core/storage/train_duration_store.dart';
import '../../core/theme/blowfit_colors.dart';
import '../../core/theme/blowfit_theme.dart';

const double _kFrameW = 402;

class _Frame {
  _Frame(this.screenW) : scale = screenW / _kFrameW;
  final double screenW;
  final double scale;
  double sx(double v) => v * scale;
  double sy(double v) => v * scale;

  Positioned at({
    required double x,
    required double y,
    double? w,
    double? h,
    required Widget child,
  }) {
    return Positioned(
      left: sx(x),
      top: sy(y),
      width: w == null ? null : sx(w),
      height: h == null ? null : sy(h),
      child: child,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Phase 정의
// ─────────────────────────────────────────────────────────────────────────────

enum _Phase { exhale, exhaleRest, inhale, inhaleRest }

// 펌웨어 session.cpp 의 TURN_*_MS 와 1:1 동기화.
// 1 호흡 cycle = exhale 5s + exhaleRest 5s + inhale 5s + inhaleRest 5s = 20s.
//   → 호기 → 휴식 → 흡기 → 휴식 반복.
//
// 근거: Vranish & Bailey 2016 (5분/일 IMT) + The Breather 10×2 sets 프로토콜.
const _phaseDuration = <_Phase, double>{
  _Phase.exhale: 5.0,
  _Phase.exhaleRest: 5.0, // 호기 뒤 휴식
  _Phase.inhale: 5.0,
  _Phase.inhaleRest: 5.0, // 흡기 뒤 휴식
};

// 색상 — 추이 차트와 동일 스킴.
const _exhaleColor = Color(0xFF0A89FC); // 파란 (호기)
const _inhaleColor = Color(0xFF32B65E); // 초록 (흡기)

class TrainingScreen extends ConsumerStatefulWidget {
  const TrainingScreen({super.key});
  @override
  ConsumerState<TrainingScreen> createState() => _TrainingScreenState();
}

class _TrainingScreenState extends ConsumerState<TrainingScreen>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;

  _Phase _phase = _Phase.exhale;
  double _phaseElapsed = 0; // 현재 phase 의 경과 초
  double _exhaleArc = 0; // 0~180°, 파란 호 길이
  double _inhaleArc = 0; // 0~180°, 초록 호 길이
  double _currentPressure = 0; // cmH₂O (양/음 모두 가능)
  // 사이클별 peak-hold — 하단 호기/흡기 숫자에 표시. 호기 phase 진입 시
  // _peakExhale, 흡기 phase 진입 시 _peakInhale 리셋 → phase 동안 누적 최대/최소.
  double _peakExhale = 0; // 최대 양압 (호기)
  double _peakInhale = 0; // 최소 음압 (흡기, 음수)
  // 이번 세션 (= 훈련 화면 진입 후) 정보 — 상단 카드에 표시.
  double _sessionElapsed = 0; // 누적 경과 초
  Duration _lastTick = Duration.zero;

  // 호 풀스케일(180° = 호 끝) = "목표 압력 중간값(mid)". 즉 목표 중앙 도달 시 호가
  // 끝점(호기 6시 / 흡기 12시)에 닿고, 목표 밴드(low~high)는 그 끝점을 가운데 두고
  // 양옆으로 걸친다. build 에서 store 의 target mid 로 갱신, _onTick 이 매 프레임 사용.
  // store 로드 전엔 Normal 기본값(MEP60·PImax80 × mid 55%).
  double _exhaleScale = 33; // (30+36)/2 — MEP60 × Normal mid 55%
  double _inhaleScale = 44; // (40+48)/2 — PImax80 × Normal mid 55%

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick)..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  void _onTick(Duration elapsed) {
    if (_lastTick == Duration.zero) {
      _lastTick = elapsed;
      return;
    }
    final dt = (elapsed - _lastTick).inMicroseconds / 1e6;
    _lastTick = elapsed;

    final phaseDur = _phaseDuration[_phase]!;

    setState(() {
      _phaseElapsed += dt;
      _sessionElapsed += dt;

      // active phase 에서만, 그리고 phase 방향에 맞는 압력에만 반응.
      //   호기 phase: 양압(p>0)만 → 흡기(음압)해도 arc/peak 안 움직임.
      //   흡기 phase: 음압(p<0)만 → 호기(양압)해도 arc/peak 안 움직임.
      // arc 는 실시간(instantaneous), peak 는 최댓값 hold.
      if (_phase == _Phase.exhale) {
        final p = _currentPressure > 0 ? _currentPressure : 0.0;
        final scale = _exhaleScale > 0 ? _exhaleScale : 33.0;
        _exhaleArc = (p / scale * 180).clamp(0.0, 180.0);
        if (p > _peakExhale) _peakExhale = p;
      } else if (_phase == _Phase.inhale) {
        final p = _currentPressure < 0 ? _currentPressure : 0.0; // ≤ 0
        final scale = _inhaleScale > 0 ? _inhaleScale : 44.0;
        _inhaleArc = (-p / scale * 180).clamp(0.0, 180.0);
        if (p < _peakInhale) _peakInhale = p; // 더 깊은 음압
      }

      // phase 전환
      if (_phaseElapsed >= phaseDur) {
        _phaseElapsed = 0;
        _phase = _nextPhase(_phase);
        // phase 진입 시 해당 peak 리셋 → 새 호흡마다 0 부터 다시 측정.
        if (_phase == _Phase.exhale) _peakExhale = 0;
        if (_phase == _Phase.inhale) _peakInhale = 0;
        // inhaleRest 진입 시 — 한 호흡(호기+흡기) 완료. 다음 cycle 준비.
        if (_phase == _Phase.inhaleRest) {
          _exhaleArc = 0;
          _inhaleArc = 0;
        }
      }
    });
  }

  static _Phase _nextPhase(_Phase p) {
    switch (p) {
      case _Phase.exhale:
        return _Phase.exhaleRest;
      case _Phase.exhaleRest:
        return _Phase.inhale;
      case _Phase.inhale:
        return _Phase.inhaleRest;
      case _Phase.inhaleRest:
        return _Phase.exhale;
    }
  }

  @override
  Widget build(BuildContext context) {
    // BLE pressure stream → instance var 에 저장 (ticker 가 사용).
    ref.listen(pressureSampleProvider, (prev, next) {
      next.whenData((sample) {
        _currentPressure = sample.cmH2O;
      });
    });

    // 호 풀스케일 = 목표 압력 중간값(mid = (low+high)/2) → mid 가 호 끝(6시/12시)에
    // 온다. _onTick 이 다음 프레임부터 사용.
    final pm = ref.watch(pimaxMepStoreProvider).valueOrNull;
    if (pm != null) {
      final et = pm.exhaleTarget();
      final it = pm.inhaleTarget();
      _exhaleScale = (et.low + et.high) / 2;
      _inhaleScale = (it.low + it.high) / 2;
    }

    // 현재 압력이 활성 phase 목표대역 [low,high] 안이면 목표원을 솔리드로 표시
    // (밖이면 점선 테두리 + 연한 fill). 휴식 phase 는 압력 무시 → false.
    bool inTarget = false;
    if (pm != null) {
      final mag = _currentPressure.abs();
      if (_phase == _Phase.exhale) {
        final t = pm.exhaleTarget();
        inTarget = mag >= t.low && mag <= t.high;
      } else if (_phase == _Phase.inhale) {
        final t = pm.inhaleTarget();
        inTarget = mag >= t.low && mag <= t.high;
      }
    }

    final isDark = ref.watch(themeModeProvider) == ThemeMode.dark;
    final media = MediaQuery.of(context);
    final f = _Frame(media.size.width);
    final phaseDur = _phaseDuration[_phase]!;
    final remainingSec = (phaseDur - _phaseElapsed).ceil().clamp(0, 999);

    return Scaffold(
      // 다크: figma Rectangle 69 단색 #060725 / 라이트: 잔디 마지막 stop 색
      backgroundColor:
          isDark ? const Color(0xFF060725) : const Color(0xFF4BA22B),
      body: Stack(
        children: [
          // 1. 배경 — sky gradient + ellipse 47/48
          Positioned.fill(
            child: LayoutBuilder(
              builder: (_, c) => CustomPaint(
                size: Size(c.maxWidth, c.maxHeight),
                painter: _TrainBgPainter(isDark: isDark),
              ),
            ),
          ),
          // 2. 콘텐츠
          _TrainingContent(
            f: f,
            isDark: isDark,
            phase: _phase,
            exhaleArc: _exhaleArc,
            inhaleArc: _inhaleArc,
            inTarget: inTarget,
            remainingSec: remainingSec,
            peakExhale: _peakExhale,
            peakInhale: _peakInhale,
            sessionElapsed: _sessionElapsed,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 배경 페인터 — Rectangle 69 sky + Ellipse 47/48 잔디 (figma 그대로)
// ─────────────────────────────────────────────────────────────────────────────

class _TrainBgPainter extends CustomPainter {
  _TrainBgPainter({required this.isDark});
  final bool isDark;

  static const _skyColors = <Color>[
    Color(0xFFDFF9FF),
    Color(0xFFC6F5FF),
    Color(0xFF8DE9FD),
  ];
  static const _skyStops = <double>[0.0, 0.2692, 1.0];

  // ─── 다크 모드 ellipse 색 — 홈(dashboard) _BgPainter 다크 recipe 미러 ───
  //   ellipse 47: figma 1:2264 / ellipse 48: figma 1:2263.
  static const _e47DarkColors = <Color>[
    Color(0xFF34346A), // pos 0.0    (어두운 보라/네이비, 잔디 위 가장자리)
    Color(0xFF1D1E45), // pos 0.1298
    Color(0xFF10112F), // pos 0.3654
    Color(0xFF05061B), // pos 1.0    (매우 어두운 네이비)
  ];
  static const _e47DarkStops = <double>[0.0, 0.1298, 0.3654, 1.0];
  static const _e48DarkColors = <Color>[
    Color(0xFF161841), // pos 0.0
    Color(0xFF05061B), // pos 1.0
  ];
  static const _e48DarkStops = <double>[0.0, 1.0];

  static const _e47Width = 934.5897216796875;
  static const _e47Height = 710.517333984375;
  static const _e47Transform = <List<double>>[
    [0.9912595152854919, 0.1310185194015503, -425.085205078125],
    [-0.13192658126354218, 0.991379976272583, 690.787109375],
  ];
  static const _e47Colors = <Color>[
    Color(0xFFCFFF94),
    Color(0xFF89C76A),
    Color(0xFF4BA22B),
  ];
  static const _e47Stops = <double>[0.0, 0.5144, 1.0];

  static const _e48Width = 447.7158203125;
  static const _e48Height = 461.1383056640625;
  static const _e48Transform = <List<double>>[
    [0.7556201219558716, -0.6590954661369324, 324.93408203125],
    [0.6550101041793823, 0.752059280872345, 556.0],
  ];
  static const _e48Colors = <Color>[
    Color(0xFFE2F8C8),
    Color(0xFF78CA59),
  ];
  static const _e48Stops = <double>[0.0, 1.0];

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final scale = size.width / _kFrameW;

    if (isDark) {
      // 다크 모드 배경 — figma Rectangle 69 단색 #060725 + 어두운 물결 ellipse
      // 두 개 (홈 다크와 동일 recipe). 라이트와 같은 transform/크기, 색만 다크.
      canvas.drawRect(rect, Paint()..color = const Color(0xFF060725));
      _drawEllipse(
        canvas,
        scale,
        _e48Transform,
        _e48Width,
        _e48Height,
        _e48DarkColors,
        _e48DarkStops,
      );
      _drawEllipse(
        canvas,
        scale,
        _e47Transform,
        _e47Width,
        _e47Height,
        _e47DarkColors,
        _e47DarkStops,
      );
      return;
    }

    final skyPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment(-1.326, 1.65),
        end: Alignment(-0.674, -1.648),
        stops: _skyStops,
        colors: _skyColors,
      ).createShader(rect);
    canvas.drawRect(rect, skyPaint);

    _drawEllipse(
      canvas,
      scale,
      _e48Transform,
      _e48Width,
      _e48Height,
      _e48Colors,
      _e48Stops,
    );
    _drawEllipse(
      canvas,
      scale,
      _e47Transform,
      _e47Width,
      _e47Height,
      _e47Colors,
      _e47Stops,
    );
  }

  void _drawEllipse(
    Canvas canvas,
    double scale,
    List<List<double>> m,
    double w,
    double h,
    List<Color> colors,
    List<double> stops,
  ) {
    canvas.save();
    canvas.scale(scale, scale);
    canvas.transform(
      Float64List.fromList(<double>[
        m[0][0],
        m[1][0],
        0,
        0,
        m[0][1],
        m[1][1],
        0,
        0,
        0,
        0,
        1,
        0,
        m[0][2],
        m[1][2],
        0,
        1,
      ]),
    );
    final rect = Rect.fromLTWH(0, 0, w, h);
    final shader = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: colors,
      stops: stops,
    ).createShader(rect);
    canvas.drawOval(rect, Paint()..shader = shader);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_TrainBgPainter old) => old.isDark != isDark;
}

// ─────────────────────────────────────────────────────────────────────────────
// 훈련 콘텐츠 — 정적 layout + 동적 ring/타이머
// ─────────────────────────────────────────────────────────────────────────────

class _TrainingContent extends ConsumerWidget {
  const _TrainingContent({
    required this.f,
    required this.isDark,
    required this.phase,
    required this.exhaleArc,
    required this.inhaleArc,
    required this.inTarget,
    required this.remainingSec,
    required this.peakExhale,
    required this.peakInhale,
    required this.sessionElapsed,
  });
  final _Frame f;
  final bool isDark;
  final _Phase phase;
  final double exhaleArc;
  final double inhaleArc;
  final bool inTarget; // 현재 압력이 목표대역 안인지 (목표원 솔리드/점선 토글)
  final int remainingSec;
  final double peakExhale; // 이번 호기 최대 압력 (양수)
  final double peakInhale; // 이번 흡기 최소 압력 (음수)
  final double sessionElapsed; // 이번 세션 경과 초

  static const _ink = Color(0xFF101010);
  static const _restColor = Color(0xFF9E9E9E); // 휴식 — 중립 회색

  // 라이트는 검정(_ink), 다크는 흰색. 텍스트/아이콘/divider 가 다크에서 흰색으로.
  Color get _inkColor => isDark ? DotColors.darkTextPrimary : _ink;

  /// 오늘 날짜 → "5월 30일, 토요일" 형식.
  static String _koreanDate(DateTime d) {
    const wk = ['월', '화', '수', '목', '금', '토', '일'];
    return '${d.month}월 ${d.day}일, ${wk[d.weekday - 1]}요일';
  }

  /// 경과 초 → "mm:ss".
  static String _fmtElapsed(double seconds) {
    final t = seconds.floor();
    final m = (t ~/ 60).toString().padLeft(2, '0');
    final s = (t % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  /// 현재 phase 의 가운데 라벨 텍스트.
  static String _phaseLabel(_Phase p) {
    switch (p) {
      case _Phase.exhale:
        return '날숨';
      case _Phase.inhale:
        return '들숨';
      case _Phase.exhaleRest:
      case _Phase.inhaleRest:
        return '휴식';
    }
  }

  /// 현재 phase 의 라벨/강조 색.
  static Color _phaseColor(_Phase p) {
    switch (p) {
      case _Phase.exhale:
        return _exhaleColor;
      case _Phase.inhale:
        return _inhaleColor;
      case _Phase.exhaleRest:
      case _Phase.inhaleRest:
        return _restColor;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 상단 — 이번 세션 정보 (경과 시간 / 훈련 시간 / 목표 압력대).
    //
    // v4.1: 단일 zone (legacy) 대신 %PImax 기반 적응형. 현재 phase 가 흡기일
    // 때는 흡기 target (- 음압), 호기일 때는 호기 target (+ 양압) 의 압력 범위를
    // 표시. 라벨은 "목표 압력" 으로 통일. Rest phase 는 직전 phase 의 표시 유지.
    final pmStore = ref.watch(pimaxMepStoreProvider).valueOrNull;
    final isInhaleSide = phase == _Phase.inhale || phase == _Phase.inhaleRest;
    final String targetText;
    const String targetLabel = '목표 압력';
    if (pmStore != null) {
      // 부호 없이 절대값으로 표시 (예: 30~36). 흡기/호기 구분은 phase 색으로.
      final t = isInhaleSide ? pmStore.inhaleTarget() : pmStore.exhaleTarget();
      targetText = '${t.low.round()}~${t.high.round()}';
    } else {
      // 로딩 중 fallback — Normal · 기본값 기준.
      targetText = isInhaleSide ? '40~48' : '30~36';
    }
    // 사용자가 설정에서 선택한 훈련 시간(분, 기본 5). 기기 세션 길이와 동일.
    final trainMinutes =
        ref.watch(trainDurationStoreProvider).valueOrNull?.loadMinutes() ??
            TrainDurationStore.defaultMinutes;
    return Stack(
      children: [
        // ─── 브랜드 로고 (81×22 at 17,56) — 홈·추이와 동일 BRELOW wordmark ──
        f.at(
          x: 17,
          y: 56,
          w: 81,
          h: 22,
          child: Image.asset(
            // 다크: 글자만 흰색 변형(파란 O 유지). 라이트: 원본.
            isDark ? 'assets/dot/logo_dark.png' : 'assets/dot/logo.png',
            fit: BoxFit.contain,
            filterQuality: FilterQuality.high,
          ),
        ),

        // ─── 테마(라이트/다크) 토글 — 설정 좌측, hit 44×44 (Figma 97:254) ──
        // 다크에선 해(light_mode) 아이콘 → 탭 시 라이트로 전환. 라이트에선 달.
        f.at(
          // 설정(y60,19h)·알림(y60,18h) 아이콘 중심(≈y69)에 맞추도록, 44×44 탭박스를
          // 내려 중앙정렬된 22 아이콘 중심을 y69 로 (y47 + 44/2 = y69).
          x: 262,
          y: 47,
          w: 44,
          h: 44,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => ref.read(themeModeProvider.notifier).toggle(),
            child: Container(
              color: Colors.transparent,
              alignment: Alignment.center,
              child: Icon(
                isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
                size: f.sx(22),
                color: _inkColor,
              ),
            ),
          ),
        ),

        // ─── 우상단 아이콘 (설정 좌 / 알림 우) — 홈·추이와 동일 SVG ──
        // Figma 1:2236: settings vector (320,60) 20×19, bell vector (366,60)
        // 16×18. 기존 코드가 좌우 뒤바뀌고 raster PNG 였던 것 → SVG + Figma 위치.
        f.at(
          x: 320,
          y: 60,
          w: 20,
          h: 19,
          child: SvgPicture.asset(
            'assets/dot/icon_settings.svg',
            fit: BoxFit.contain,
            colorFilter: ColorFilter.mode(_inkColor, BlendMode.srcIn),
          ),
        ),
        f.at(
          x: 366,
          y: 60,
          w: 16,
          h: 18,
          child: SvgPicture.asset(
            'assets/dot/icon_bell.svg',
            fit: BoxFit.contain,
            colorFilter: ColorFilter.mode(_inkColor, BlendMode.srcIn),
          ),
        ),

        // ─── 날짜 (오늘 날짜 동적) ─────────────────────────────────
        f.at(
          x: 19,
          y: 113,
          child: Text(
            _koreanDate(DateTime.now()),
            style: TextStyle(
              fontSize: f.sx(15),
              fontWeight: FontWeight.w600,
              color: _inkColor,
              fontFamily: BlowfitTheme.fontFamily,
            ),
          ),
        ),

        // ─── 상단 — 이번 세션 정보 (경과 시간 / 훈련 시간 / 목표 압력) ────
        // 누적 통계(주/달/누적)는 홈·추이 영역 → 훈련 중엔 세션 진행 정보 표시.
        // divider(150,248) 기준 3컬럼 중앙 정렬 (자릿수 무관 가운데). 가운데
        // "훈련 시간" 컬럼을 좁히고(양쪽 divider 안쪽으로) 좌·우 컬럼을 넓혀
        // "+30~+36" 같은 목표 압력이 줄바꿈되지 않도록 함.
        _sessionCol(20, 150, _fmtElapsed(sessionElapsed), '경과 시간'),
        _sessionCol(150, 248, '$trainMinutes분', '훈련 시간'),
        _sessionCol(248, 382, targetText, targetLabel),
        f.at(
          x: 150,
          y: 174,
          w: 1,
          h: 58,
          child: Container(
            color: isDark
                ? Colors.white.withValues(alpha: 0.15)
                : Colors.black.withValues(alpha: 0.15),
          ),
        ),
        f.at(
          x: 248,
          y: 174,
          w: 1,
          h: 58,
          child: Container(
            color: isDark
                ? Colors.white.withValues(alpha: 0.15)
                : Colors.black.withValues(alpha: 0.15),
          ),
        ),

        // ─── 원형 ring (도넛 + arc + dot) ─────────────────────────
        f.at(
          x: 45,
          y: 291,
          w: 312,
          h: 312,
          child: CustomPaint(
            painter: _RingPainter(
              f: f,
              isDark: isDark,
              phase: phase,
              exhaleArc: exhaleArc,
              inhaleArc: inhaleArc,
              inTarget: inTarget,
            ),
          ),
        ),

        // ─── 가운데 phase 라벨 + 카운트다운 ───────────────────────
        // 호기/흡기/휴식 단어(색상) + 남은 초. 안쪽 원 배경색과 함께 명확히 구분.
        f.at(
          x: 45,
          y: 291,
          w: 312,
          h: 312,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _phaseLabel(phase),
                  style: TextStyle(
                    fontSize: f.sx(22),
                    fontWeight: FontWeight.w700,
                    color: _phaseColor(phase),
                    fontFamily: BlowfitTheme.fontFamily,
                  ),
                ),
                SizedBox(height: f.sy(4)),
                Text(
                  '$remainingSec초',
                  style: TextStyle(
                    fontSize: f.sx(40),
                    fontWeight: FontWeight.w700,
                    color: _inkColor, // 라이트 검정 / 다크 흰색
                    fontFamily: BlowfitTheme.fontFamily,
                  ),
                ),
              ],
            ),
          ),
        ),

        // ─── 하단 호기/흡기 ────────────────────────────────────────
        f.at(
          x: 70,
          y: 689,
          child: Text(
            '날숨',
            style: TextStyle(
              fontSize: f.sx(15),
              fontWeight: FontWeight.w500,
              color: _inkColor,
              fontFamily: BlowfitTheme.fontFamily,
            ),
          ),
        ),
        f.at(
          x: 300,
          y: 689,
          child: Text(
            '들숨',
            style: TextStyle(
              fontSize: f.sx(15),
              fontWeight: FontWeight.w500,
              color: _inkColor,
              fontFamily: BlowfitTheme.fontFamily,
            ),
          ),
        ),
        // 호기 실시간 peak (양압) — 호기 라벨(중심 x≈85) 아래 가운데 정렬.
        // 미연결/무압력 시 0. 폭 120 박스에서 Center → 자릿수와 무관하게 중앙.
        Positioned(
          left: f.sx(85 - 60),
          top: f.sy(706),
          width: f.sx(120),
          child: Center(
            child: Text(
              '${peakExhale.round()}',
              style: TextStyle(
                fontSize: f.sx(45),
                fontWeight: FontWeight.w700,
                color: _inkColor,
                fontFamily: BlowfitTheme.fontFamily,
              ),
            ),
          ),
        ),
        // 흡기 실시간 peak (음압) — 흡기 라벨(중심 x≈315) 아래 가운데 정렬.
        Positioned(
          left: f.sx(315 - 60),
          top: f.sy(706),
          width: f.sx(120),
          child: Center(
            child: Text(
              '${peakInhale.round()}',
              style: TextStyle(
                fontSize: f.sx(45),
                fontWeight: FontWeight.w700,
                color: _inkColor,
                fontFamily: BlowfitTheme.fontFamily,
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// 상단 1개 컬럼 — [left]~[right] (frame px) 구간 중앙에 값(위) + 라벨(아래).
  Widget _sessionCol(double left, double right, String value, String label) {
    return Positioned(
      left: f.sx(left),
      width: f.sx(right - left),
      top: f.sy(171),
      child: Column(
        children: [
          // FittedBox(scaleDown): 컬럼 폭을 넘으면 줄바꿈 대신 아주 살짝만 축소
          // → "+30~+36" 같은 값이 절대 줄바꿈/잘리지 않고 한 줄 유지.
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              maxLines: 1,
              softWrap: false,
              style: TextStyle(
                fontSize: f.sx(30),
                fontWeight: FontWeight.w700,
                color: _inkColor,
                fontFamily: BlowfitTheme.fontFamily,
              ),
            ),
          ),
          SizedBox(height: f.sy(4)),
          Text(
            label,
            style: TextStyle(
              fontSize: f.sx(12),
              fontWeight: FontWeight.w500,
              color: _inkColor,
              fontFamily: BlowfitTheme.fontFamily,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Ring Painter — 흰 도넛 + 파란 호기 호 + 초록 흡기 호 + 진행 dot
// ─────────────────────────────────────────────────────────────────────────────

class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.f,
    required this.isDark,
    required this.phase,
    required this.exhaleArc,
    required this.inhaleArc,
    required this.inTarget,
  });
  final _Frame f;
  final bool isDark;
  final _Phase phase;
  final double exhaleArc; // 0~180 degrees
  final double inhaleArc; // 0~180 degrees
  final bool inTarget; // 압력이 목표대역 안 → 목표원 솔리드 / 밖 → 점선+연한 fill

  // phase 별 안쪽 원 배경색 — 라이트: 호기 연파랑 / 흡기 연초록 / 휴식 연회색.
  // 다크(Figma 97:254): 모든 phase 공통 #393B6B (어두운 네이비-그레이).
  Color _innerColor(_Phase p) {
    if (isDark) return const Color(0xFF393B6B);
    switch (p) {
      case _Phase.exhale:
        return const Color(0xFFE3F1FE);
      case _Phase.inhale:
        return const Color(0xFFE7F6EC);
      case _Phase.exhaleRest:
      case _Phase.inhaleRest:
        return const Color(0xFFF0F0F0);
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    final strokeW = f.sx(50);
    final radius = (size.width - strokeW) / 2;
    final center = Offset(size.width / 2, size.height / 2);
    final ringRect = Rect.fromCircle(center: center, radius: radius);

    // 0. 안쪽 원 — phase 색 배경. 도넛 안쪽 가장자리까지 채움.
    canvas.drawCircle(
      center,
      radius - strokeW / 2,
      Paint()..color = _innerColor(phase),
    );

    // 1. 도넛 base — 라이트: 흰색 / 다크: #272751 (figma Ellipse 50 stroke 50 INSIDE)
    final basePaint = Paint()
      ..color = isDark ? const Color(0xFF272751) : Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeW
      ..strokeCap = StrokeCap.butt;
    canvas.drawCircle(center, radius, basePaint);

    // 1.5 목표 압력 — 호 끝점(호기 6시 / 흡기 12시 = 목표 중간값)에 "호기/흡기 색"
    //     원 1개로 표시. (풀스케일이 목표 중간값이라 끝점 = 목표 위치.) fill 호 아래라
    //     dot 이 끝점에 닿으면 자연스레 덮인다.
    {
      final isInhaleSide = phase == _Phase.inhale || phase == _Phase.inhaleRest;
      // 호 끝점: 호기 12시(-π/2)+180°=6시, 흡기 6시(+π/2)+180°=12시.
      final base = isInhaleSide ? math.pi / 2 : -math.pi / 2;
      final a = base + math.pi;
      final tCenter = Offset(
        center.dx + radius * math.cos(a),
        center.dy + radius * math.sin(a),
      );
      final tColor = isInhaleSide ? _inhaleColor : _exhaleColor;
      final tRadius = strokeW / 2; // 링 도넛 폭에 꽉 차게 (진행 dot 과 동일 크기)
      if (inTarget) {
        // 압력이 목표대역 안 — 원래대로 솔리드 원 (테두리 없음).
        canvas.drawCircle(tCenter, tRadius, Paint()..color = tColor);
      } else {
        // 미도달 — 연한 fill(@25%) + 점선 테두리.
        canvas.drawCircle(
          tCenter,
          tRadius,
          Paint()..color = tColor.withValues(alpha: 0.25),
        );
        _drawDashedCircle(canvas, tCenter, tRadius, tColor, f.sx(2.5));
      }
    }

    // 2. 파란 호기 호 (시계방향) — 12시 시작 → exhaleArc 만큼.
    if (exhaleArc > 0) {
      final exhalePaint = Paint()
        ..color = _exhaleColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeW
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(
        ringRect,
        -math.pi / 2, // 12시 시작
        exhaleArc * math.pi / 180, // 시계방향 (양수)
        false,
        exhalePaint,
      );
    }

    // 3. 초록 흡기 호 — 6시 시작 → 좌측 경로 (9시 거쳐) 으로 12시 방향으로 자람.
    //    visual y-down 좌표계에서 6시(π/2) 부터 각도 증가 = 시계방향 visual,
    //    즉 6→9→12 좌측 절반 채움. inhaleArc=180° → 좌측 절반 완전 채움.
    if (inhaleArc > 0) {
      final inhalePaint = Paint()
        ..color = _inhaleColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeW
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(
        ringRect,
        math.pi / 2, // 6시 시작
        inhaleArc * math.pi / 180, // 시계방향 visual (6→9→12)
        false,
        inhalePaint,
      );
    }

    // 4. 진행 dot — 현재 active phase 의 호 끝에 위치
    double? dotAngle;
    Color? dotColor;
    if (phase == _Phase.exhale) {
      // 12시(-π/2) 에서 시계방향 → 호 끝
      dotAngle = -math.pi / 2 + exhaleArc * math.pi / 180;
      dotColor = _exhaleColor;
    } else if (phase == _Phase.inhale) {
      // 6시(π/2) 에서 시계방향 visual (좌측 경로) → 12시 방향 호 끝
      dotAngle = math.pi / 2 + inhaleArc * math.pi / 180;
      dotColor = _inhaleColor;
    }
    // rest phase 는 dot 안 보임 (사용자 의도 정적인 모양)

    if (dotAngle != null && dotColor != null) {
      final dotCenter = Offset(
        center.dx + radius * math.cos(dotAngle),
        center.dy + radius * math.sin(dotAngle),
      );
      // Figma Ellipse 51 = 50×50 = stroke 두께와 동일 크기.
      // strokeAlign INSIDE 인 도넛 위에 dot 이 ring stroke 위에 sit.
      canvas.drawCircle(dotCenter, strokeW / 2, Paint()..color = dotColor);
    }
  }

  /// 원 둘레를 짧은 호 세그먼트로 그려 점선 테두리 표현 (Flutter 점선 stroke 미지원).
  void _drawDashedCircle(
    Canvas canvas,
    Offset center,
    double radius,
    Color color,
    double strokeWidth,
  ) {
    const dashCount = 14; // 점선 개수
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    // stroke 가 fill 바깥으로 삐져나오지 않도록 반지름을 절반 두께만큼 안쪽으로.
    final rect = Rect.fromCircle(
      center: center,
      radius: radius - strokeWidth / 2,
    );
    const seg = (2 * math.pi) / dashCount;
    const dash = seg * 0.55; // 55% dash, 45% gap
    for (var i = 0; i < dashCount; i++) {
      canvas.drawArc(rect, i * seg, dash, false, paint);
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.isDark != isDark ||
      old.phase != phase ||
      old.exhaleArc != exhaleArc ||
      old.inhaleArc != inhaleArc ||
      old.inTarget != inTarget;
}
