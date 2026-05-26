// Figma DoT — 훈련 화면 (라이트모드).
//
// 디자인 출처: 1:2236 훈련화면 - 라이트모드 (402×874).
//
// Ring 동작:
//   4-phase cycle 반복 (exhale 10s → exhaleRest 3s → inhale 10s → inhaleRest 3s)
//   - exhale phase  : 파란 호가 12시(-π/2) → 시계방향 → 6시(+π/2). |pressure|/30 * 180°
//   - exhaleRest    : 파란 호 그대로 유지
//   - inhale phase  : 초록 호가 12시 → 시계반대 → 6시 (좌측 절반)
//   - inhaleRest    : 진입 시 두 arc 모두 0 으로 reset (다음 cycle 준비)
// 가운데 텍스트: phase 카운트다운 (10초→0초 또는 3초→0초), 색 검정 고정.
// 압력 source: BLE `pressureSampleProvider` 의 PressureSample.cmH2O 실시간.

import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/ble/ble_providers.dart';
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

const _phaseDuration = <_Phase, double>{
  _Phase.exhale: 10.0,
  _Phase.exhaleRest: 3.0,
  _Phase.inhale: 10.0,
  _Phase.inhaleRest: 3.0,
};

// 색상 — 추이 차트와 동일 스킴.
const _exhaleColor = Color(0xFF0A89FC); // 파란 (호기)
const _inhaleColor = Color(0xFF32B65E); // 초록 (흡기)
const _maxPressureCmH2O = 30.0; // 목표 압력 — 30 = 180° (절반)

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
  Duration _lastTick = Duration.zero;

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
    final pressureArc =
        (_currentPressure.abs() / _maxPressureCmH2O * 180).clamp(0.0, 180.0);

    setState(() {
      _phaseElapsed += dt;

      // active phase 에서만 arc 업데이트 (실시간 압력 매핑)
      if (_phase == _Phase.exhale) {
        _exhaleArc = pressureArc;
      } else if (_phase == _Phase.inhale) {
        _inhaleArc = pressureArc;
      }

      // phase 전환
      if (_phaseElapsed >= phaseDur) {
        _phaseElapsed = 0;
        _phase = _nextPhase(_phase);
        // inhaleRest 진입 시 — 다음 cycle 준비, 두 arc 모두 reset
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

    final media = MediaQuery.of(context);
    final f = _Frame(media.size.width);
    final phaseDur = _phaseDuration[_phase]!;
    final remainingSec = (phaseDur - _phaseElapsed).ceil().clamp(0, 999);

    return Scaffold(
      backgroundColor: const Color(0xFF4BA22B),
      body: Stack(
        children: [
          // 1. 배경 — sky gradient + ellipse 47/48
          Positioned.fill(
            child: LayoutBuilder(
              builder: (_, c) => CustomPaint(
                size: Size(c.maxWidth, c.maxHeight),
                painter: _TrainBgPainter(),
              ),
            ),
          ),
          // 2. 콘텐츠
          _TrainingContent(
            f: f,
            phase: _phase,
            exhaleArc: _exhaleArc,
            inhaleArc: _inhaleArc,
            remainingSec: remainingSec,
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
  static const _skyColors = <Color>[
    Color(0xFFDFF9FF),
    Color(0xFFC6F5FF),
    Color(0xFF8DE9FD),
  ];
  static const _skyStops = <double>[0.0, 0.2692, 1.0];

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

    final skyPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment(-1.326, 1.65),
        end: Alignment(-0.674, -1.648),
        stops: _skyStops,
        colors: _skyColors,
      ).createShader(rect);
    canvas.drawRect(rect, skyPaint);

    _drawEllipse(
      canvas, scale, _e48Transform, _e48Width, _e48Height,
      _e48Colors, _e48Stops,
    );
    _drawEllipse(
      canvas, scale, _e47Transform, _e47Width, _e47Height,
      _e47Colors, _e47Stops,
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
        m[0][0], m[1][0], 0, 0,
        m[0][1], m[1][1], 0, 0,
        0, 0, 1, 0,
        m[0][2], m[1][2], 0, 1,
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
  bool shouldRepaint(_TrainBgPainter old) => false;
}

// ─────────────────────────────────────────────────────────────────────────────
// 훈련 콘텐츠 — 정적 layout + 동적 ring/타이머
// ─────────────────────────────────────────────────────────────────────────────

class _TrainingContent extends StatelessWidget {
  const _TrainingContent({
    required this.f,
    required this.phase,
    required this.exhaleArc,
    required this.inhaleArc,
    required this.remainingSec,
  });
  final _Frame f;
  final _Phase phase;
  final double exhaleArc;
  final double inhaleArc;
  final int remainingSec;

  static const _ink = Color(0xFF101010);

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // ─── 우상단 아이콘 (설정/알림) ────────────────────────────
        f.at(
          x: 358,
          y: 53,
          w: 28,
          h: 28,
          child:
              Image.asset('assets/dot/icon_settings.png', fit: BoxFit.contain),
        ),
        f.at(
          x: 311,
          y: 53,
          w: 30,
          h: 30,
          child: Image.asset('assets/dot/icon_bell.png', fit: BoxFit.contain),
        ),

        // ─── 날짜 ─────────────────────────────────────────────────
        f.at(
          x: 19,
          y: 113,
          child: Text(
            '5월 22일, 금요일',
            style: TextStyle(
              fontSize: f.sx(15),
              fontWeight: FontWeight.w600,
              color: Colors.black,
              fontFamily: BlowfitTheme.fontFamily,
            ),
          ),
        ),

        // ─── 상단 통계 ─────────────────────────────────────────────
        f.at(
          x: 57,
          y: 171,
          child: _statNum('1회'),
        ),
        f.at(
          x: 181,
          y: 171,
          child: _statNum('1일'),
        ),
        f.at(
          x: 305,
          y: 171,
          child: _statNum('1회'),
        ),
        f.at(
          x: 137,
          y: 174,
          w: 1,
          h: 58,
          child: Container(color: Colors.black.withValues(alpha: 0.15)),
        ),
        f.at(
          x: 261,
          y: 174,
          w: 1,
          h: 58,
          child: Container(color: Colors.black.withValues(alpha: 0.15)),
        ),
        f.at(
          x: 60,
          y: 215,
          child: _statLabel('이번 주'),
        ),
        f.at(
          x: 184,
          y: 215,
          child: _statLabel('이번 달'),
        ),
        f.at(
          x: 304,
          y: 215,
          child: _statLabel('지금까지'),
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
              phase: phase,
              exhaleArc: exhaleArc,
              inhaleArc: inhaleArc,
            ),
          ),
        ),

        // ─── 가운데 카운트다운 텍스트 ─────────────────────────────
        f.at(
          x: 45,
          y: 291,
          w: 312,
          h: 312,
          child: Center(
            child: Text(
              '$remainingSec초',
              style: TextStyle(
                fontSize: f.sx(40),
                fontWeight: FontWeight.w700,
                color: _ink, // 검정 고정
                fontFamily: BlowfitTheme.fontFamily,
              ),
            ),
          ),
        ),

        // ─── 하단 호기/흡기 ────────────────────────────────────────
        f.at(
          x: 70,
          y: 689,
          child: Text(
            '호기',
            style: TextStyle(
              fontSize: f.sx(15),
              fontWeight: FontWeight.w500,
              color: _ink,
              fontFamily: BlowfitTheme.fontFamily,
            ),
          ),
        ),
        f.at(
          x: 300,
          y: 689,
          child: Text(
            '흡기',
            style: TextStyle(
              fontSize: f.sx(15),
              fontWeight: FontWeight.w500,
              color: _ink,
              fontFamily: BlowfitTheme.fontFamily,
            ),
          ),
        ),
        f.at(
          x: 57,
          y: 706,
          child: Text(
            '14',
            style: TextStyle(
              fontSize: f.sx(45),
              fontWeight: FontWeight.w700,
              color: _ink,
              fontFamily: BlowfitTheme.fontFamily,
            ),
          ),
        ),
        f.at(
          x: 277,
          y: 706,
          child: Text(
            '-14',
            style: TextStyle(
              fontSize: f.sx(45),
              fontWeight: FontWeight.w700,
              color: _ink,
              fontFamily: BlowfitTheme.fontFamily,
            ),
          ),
        ),
      ],
    );
  }

  Widget _statNum(String t) => Text(
        t,
        style: TextStyle(
          fontSize: f.sx(30),
          fontWeight: FontWeight.w700,
          color: _ink,
          fontFamily: BlowfitTheme.fontFamily,
        ),
      );

  Widget _statLabel(String t) => Text(
        t,
        style: TextStyle(
          fontSize: f.sx(12),
          fontWeight: FontWeight.w500,
          color: _ink,
          fontFamily: BlowfitTheme.fontFamily,
        ),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Ring Painter — 흰 도넛 + 파란 호기 호 + 초록 흡기 호 + 진행 dot
// ─────────────────────────────────────────────────────────────────────────────

class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.f,
    required this.phase,
    required this.exhaleArc,
    required this.inhaleArc,
  });
  final _Frame f;
  final _Phase phase;
  final double exhaleArc; // 0~180 degrees
  final double inhaleArc; // 0~180 degrees

  @override
  void paint(Canvas canvas, Size size) {
    final strokeW = f.sx(50);
    final radius = (size.width - strokeW) / 2;
    final center = Offset(size.width / 2, size.height / 2);
    final ringRect = Rect.fromCircle(center: center, radius: radius);

    // 1. 흰 도넛 base — 전체 ring 흰색 (figma Ellipse 50 stroke 50 INSIDE)
    final basePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeW
      ..strokeCap = StrokeCap.butt;
    canvas.drawCircle(center, radius, basePaint);

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

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.phase != phase ||
      old.exhaleArc != exhaleArc ||
      old.inhaleArc != inhaleArc;
}
