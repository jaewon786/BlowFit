// Figma DoT — 추이 화면 (라이트모드).
//
// 디자인 출처: 1:2128 추이 - 라이트모드 (402×1415, scroll 가능).
// 모든 좌표/크기는 Figma frame px 그대로. 화면 너비/402 로 scale.
// 배경 ellipse 47/48 의 fill/transform 은 figma plugin API 로 추출한 정확한
// 데이터 (nodes 1:2172 + 1:2132).

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/db_providers.dart';
import '../../core/db/trend_bucketing.dart';
import '../../core/theme/blowfit_colors.dart';
import '../../core/theme/blowfit_theme.dart';

const double _kFrameW = 402;
const double _kFrameH = 1415;

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

class TrendScreen extends ConsumerStatefulWidget {
  const TrendScreen({super.key});
  @override
  ConsumerState<TrendScreen> createState() => _TrendScreenState();
}

class _TrendScreenState extends ConsumerState<TrendScreen> {
  int _tabIndex = 0;
  DateTime _calendarMonth = DateTime(2026, 5);

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final f = _Frame(media.size.width);
    final frameH = f.sy(_kFrameH);

    return Scaffold(
      backgroundColor: const Color(0xFF4BA22B), // 잔디 마지막 stop 색
      body: SingleChildScrollView(
        child: SizedBox(
          width: media.size.width,
          height: frameH,
          child: Stack(
            children: [
              // 1. 배경 — sky + 잔디 ellipse (figma 와 1:1)
              Positioned.fill(
                child: LayoutBuilder(
                  builder: (_, c) => CustomPaint(
                    size: Size(c.maxWidth, c.maxHeight),
                    painter: _TrendBgPainter(),
                  ),
                ),
              ),
              // 2. 콘텐츠
              _TrendContent(
                f: f,
                tabIndex: _tabIndex,
                onTab: (i) => setState(() => _tabIndex = i),
                calendarMonth: _calendarMonth,
                onPrevMonth: () => setState(
                  () => _calendarMonth = DateTime(
                    _calendarMonth.year,
                    _calendarMonth.month - 1,
                  ),
                ),
                onNextMonth: () => setState(
                  () => _calendarMonth = DateTime(
                    _calendarMonth.year,
                    _calendarMonth.month + 1,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Trend 배경 페인터 — Figma plugin API 추출 데이터 그대로 (frame 1415 기준)
// ─────────────────────────────────────────────────────────────────────────────

class _TrendBgPainter extends CustomPainter {
  // Ellipse 47 (추이) - 1:2172
  static const _e47Width = 1017.3922729492188;
  static const _e47Height = 1284.04150390625;
  static const _e47Transform = <List<double>>[
    [0.9964643716812134, -0.08401674032211304, -453.1190185546875],
    [0.08401674032211304, 0.9964643716812134, 650.0],
  ];
  static const _e47Colors = <Color>[
    Color(0xFFCFFF94),
    Color(0xFF89C76A),
    Color(0xFF4BA22B),
  ];
  static const _e47Stops = <double>[0.0, 0.5144, 1.0];

  // Ellipse 48 (추이) - 1:2132
  static const _e48Width = 488.5125427246094;
  static const _e48Height = 503.53411865234375;
  static const _e48Transform = <List<double>>[
    [0.7538431286811829, -0.6570544242858887, 323.30615234375],
    [0.6570544242858887, 0.7538431286811829, 455.0],
  ];
  static const _e48Colors = <Color>[
    Color(0xFFE2F8C8),
    Color(0xFF78CA59),
  ];
  static const _e48Stops = <double>[0.0, 1.0];

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final paint = Paint();
    final scale = size.width / _kFrameW;

    // sky gradient
    paint.shader = const LinearGradient(
      begin: Alignment(-0.4, -1.0),
      end: Alignment(0.4, 1.0),
      stops: [0.082, 0.589, 1.0],
      colors: [
        DotColors.lightBgTop,
        DotColors.lightBgBottom,
        DotColors.lightBgBottom,
      ],
    ).createShader(rect);
    canvas.drawRect(rect, paint);
    paint.shader = null;

    // 48 (앞쪽 작은 곡선) 먼저 그리고 47 그 위 — 홈과 동일한 z-order.
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
  bool shouldRepaint(_TrendBgPainter old) => false;
}

// ─────────────────────────────────────────────────────────────────────────────
// Trend 콘텐츠 — Figma 좌표 그대로
// ─────────────────────────────────────────────────────────────────────────────

class _TrendContent extends ConsumerWidget {
  const _TrendContent({
    required this.f,
    required this.tabIndex,
    required this.onTab,
    required this.calendarMonth,
    required this.onPrevMonth,
    required this.onNextMonth,
  });
  final _Frame f;
  final int tabIndex;
  final ValueChanged<int> onTab;
  final DateTime calendarMonth;
  final VoidCallback onPrevMonth;
  final VoidCallback onNextMonth;

  // ─── 차트 기하 (figma frame 좌표) ────────────────────────────
  // X-axis: 66 (left) ~ 358 (right), width 292.
  // Y-axis: 378 (top, +30 cmH₂O) ~ 521 (bottom, -30), 0 at 450.
  //   y = 450 - pressure * 2.4
  static const _chartLeft = 66.0;
  static const _chartRight = 358.0;
  static const _chartWidth = _chartRight - _chartLeft;
  static const _chartZeroY = 450.0;
  static const _pxPerCmH2O = 2.4;
  static const _dotSize = 7.0;

  /// 탭 index → TrendPeriod 매핑.
  TrendPeriod get _period {
    return TrendPeriod.values[tabIndex];
  }

  /// Bucket xPos (1-based) 를 차트 x 좌표로 변환. N 개 버킷을 [chartLeft,
  /// chartRight] 에 균등 분포.
  double _xForBucket(int xPos1Based, int bucketCount) {
    final spacing = _chartWidth / bucketCount;
    return _chartLeft + (xPos1Based - 0.5) * spacing - _dotSize / 2;
  }

  /// 호기 평균 (양수) 를 차트 y 좌표로. 위쪽 (양수 y).
  double _yForExhale(double avg) =>
      _chartZeroY - avg * _pxPerCmH2O - _dotSize / 2;

  /// 흡기 평균 (절댓값 — 음수 미러) 를 차트 y 좌표로. 아래쪽.
  /// DB 에 흡기 별도 stat 이 없으므로 호기 평균을 음수로 미러링. 추후 펌웨어
  /// 가 호기/흡기 분리 통계 보내면 실제 값 사용.
  double _yForInhale(double avg) =>
      _chartZeroY + avg * _pxPerCmH2O - _dotSize / 2;

  static const _ink = Color(0xFF101010);
  static const _ink2 = Color(0xFF252525);
  static const _muted = Color(0xFF898989);
  static const _calGray = Color(0xFF808080);

  // 탭별 indicator x 좌표 (frame). 일간 시 union shape 의 indicator 위치 = 20.
  // 다른 탭 선택 시 같은 width 79 의 indicator 가 그 탭 위로 이동.
  static const _tabXs = [47.0, 140.0, 234.0, 329.0]; // 텍스트 left x
  static const _tabs = ['일간', '주간', '월간', '년간'];

  List<Widget> _buildChartArea(WidgetRef ref) {
    // 선택된 탭의 indicator x = 텍스트 x - 27 (좌측 padding).
    final indicatorX = _tabXs[tabIndex] - 27;
    // 실제 데이터 — period 별 버킷. AsyncValue.valueOrNull 이 null 이면 (로딩
    // 중) 빈 리스트 — 차트 skeleton 만 보이고 dot 없음.
    final buckets =
        ref.watch(trendBucketsProvider(_period)).valueOrNull ?? const [];
    return [
      // 1. 일간 (선택된 탭) indicator — 흰색 박스, frame (indicatorX, 280, 79, 40.64)
      f.at(
        x: indicatorX,
        y: 280,
        w: 79,
        h: 40.64,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(f.sx(10)),
              topRight: Radius.circular(f.sx(10)),
            ),
          ),
        ),
      ),
      // 2. 차트 카드 — 흰색 박스, frame (20, 320, 362, 234)
      //    Figma Union 의 정확한 corner 모양:
      //    - 일간 (indicator x=20, card 좌측과 정렬): top-left = sharp
      //    - 년간 (indicator x+79=381, card 우측과 정렬): top-right = sharp
      //    - 주간/월간 (indicator 중간): top corner 모두 rounded
      //    - bottom corner: 항상 rounded
      f.at(
        x: 20,
        y: 319, // 1px 위로 — indicator bottom 과 겹쳐서 union 효과
        w: 362,
        h: 235,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: tabIndex == 0
                  ? Radius.zero
                  : Radius.circular(f.sx(10)),
              topRight: tabIndex == _tabs.length - 1
                  ? Radius.zero
                  : Radius.circular(f.sx(10)),
              bottomLeft: Radius.circular(f.sx(10)),
              bottomRight: Radius.circular(f.sx(10)),
            ),
          ),
        ),
      ),
      // 3. 탭 텍스트 4개 — 모두 frame y=292 위치.
      //    선택된 탭: SemiBold, opacity 1.0. 미선택: Medium, opacity 0.7.
      for (var i = 0; i < _tabs.length; i++)
        f.at(
          x: _tabXs[i] - 8, // 텍스트 좌측 hit area 살짝 키움
          y: 286,
          child: GestureDetector(
            onTap: () => onTab(i),
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: f.sx(8),
                vertical: f.sx(6),
              ),
              child: Text(
                _tabs[i],
                style: TextStyle(
                  fontSize: f.sx(13),
                  fontWeight: i == tabIndex
                      ? FontWeight.w600
                      : FontWeight.w500,
                  color: _ink.withValues(alpha: i == tabIndex ? 1.0 : 0.7),
                  fontFamily: BlowfitTheme.fontFamily,
                ),
              ),
            ),
          ),
        ),
      // 4. 호기 평균 legend (frame 45,343, 9×9 #0A89FC radius 1)
      f.at(
        x: 45,
        y: 343,
        w: 9,
        h: 9,
        child: Container(
          decoration: BoxDecoration(
            color: DotColors.primary,
            borderRadius: BorderRadius.circular(f.sx(1)),
          ),
        ),
      ),
      f.at(
        x: 60,
        y: 341,
        child: Text(
          '호기 평균',
          style: TextStyle(
            fontSize: f.sx(10),
            fontWeight: FontWeight.w500,
            color: _ink2,
            fontFamily: BlowfitTheme.fontFamily,
          ),
        ),
      ),
      // 5. 흡기 평균 legend (frame 113,343, 9×9 #32B65E radius 1)
      f.at(
        x: 113,
        y: 343,
        w: 9,
        h: 9,
        child: Container(
          decoration: BoxDecoration(
            color: DotColors.inhale,
            borderRadius: BorderRadius.circular(f.sx(1)),
          ),
        ),
      ),
      f.at(
        x: 128,
        y: 341,
        child: Text(
          '흡기 평균',
          style: TextStyle(
            fontSize: f.sx(10),
            fontWeight: FontWeight.w500,
            color: _ink2,
            fontFamily: BlowfitTheme.fontFamily,
          ),
        ),
      ),
      // 6. Y-axis labels (frame x, y per label)
      for (final entry in const [
        ('+30', 44.0, 373.0),
        ('+20', 44.0, 397.0),
        ('+10', 45.0, 421.0),
        ('0', 54.0, 445.0),
        ('-10', 46.0, 468.0),
        ('-20', 46.0, 492.0),
        ('-30', 45.0, 516.0),
      ])
        f.at(
          x: entry.$2,
          y: entry.$3,
          child: Text(
            entry.$1,
            style: TextStyle(
              fontSize: f.sx(8),
              fontWeight: FontWeight.w500,
              color: _muted,
              fontFamily: BlowfitTheme.fontFamily,
            ),
          ),
        ),
      // 7. Grid lines (7개, frame x=66, w=292, y=378..521)
      for (final y in const [
        378.0,
        402.0,
        426.0,
        450.0,
        473.0,
        497.0,
        521.0,
      ])
        f.at(
          x: 66,
          y: y,
          w: 292,
          h: 1,
          child: Container(color: _muted.withValues(alpha: 0.25)),
        ),
      // 8. 실제 데이터 dots — 호기 (blue, +Y) + 흡기 mirror (green, -Y).
      // 데이터 없는 (sessionCount==0) 버킷은 dot 생략 — 빈 자리 그대로.
      for (final b in buckets)
        if (!b.isEmpty && b.avgExhale != null) ...[
          // 호기 dot (파랑, 위쪽)
          f.at(
            x: _xForBucket(b.xPos, buckets.length),
            y: _yForExhale(b.avgExhale!),
            w: _dotSize,
            h: _dotSize,
            child: Container(
              decoration: const BoxDecoration(
                color: DotColors.primary,
                shape: BoxShape.circle,
              ),
            ),
          ),
          // 흡기 dot (초록, 아래쪽 mirror) — DB 에 흡기 별도 stat 없으므로
          // 호기 평균을 음수로 미러링. 펌웨어가 호기/흡기 분리 stat 보내면
          // 그때 실제 흡기 평균 사용.
          f.at(
            x: _xForBucket(b.xPos, buckets.length),
            y: _yForInhale(b.avgExhale!),
            w: _dotSize,
            h: _dotSize,
            child: Container(
              decoration: const BoxDecoration(
                color: DotColors.inhale,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ],
    ];
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Stack(
      children: [
        // ─── 로고 (35×30 at 15,56) ────────────────────────────────
        f.at(
          x: 15,
          y: 56,
          w: 35,
          h: 30,
          child: Image.asset('assets/dot/logo.png', fit: BoxFit.contain),
        ),
        // ─── 설정 / 알림 ──────────────────────────────────────────
        f.at(
          x: 358,
          y: 53,
          w: 28,
          h: 28,
          child: Image.asset('assets/dot/icon_settings.png', fit: BoxFit.contain),
        ),
        f.at(
          x: 311,
          y: 53,
          w: 30,
          h: 30,
          child: Image.asset('assets/dot/icon_bell.png', fit: BoxFit.contain),
        ),
        // ─── "추이" (15 SemiBold opacity 0.7 at 19,110) ───────────
        f.at(
          x: 19,
          y: 105,
          child: Text(
            '추이',
            style: TextStyle(
              fontSize: f.sx(15),
              fontWeight: FontWeight.w600,
              color: _ink.withValues(alpha: 0.7),
              fontFamily: BlowfitTheme.fontFamily,
            ),
          ),
        ),
        // ─── "얼마나 성장했어요!" (20 Bold at 19,131) ─────────────
        f.at(
          x: 19,
          y: 127,
          child: Text(
            '얼마나 성장했어요!',
            style: TextStyle(
              fontSize: f.sx(20),
              fontWeight: FontWeight.w700,
              color: _ink,
              letterSpacing: -0.4,
              fontFamily: BlowfitTheme.fontFamily,
            ),
          ),
        ),

        // ─── Summary 카드 (362×91 at 20,168, white opacity 0.8, r10)
        f.at(
          x: 20,
          y: 168,
          w: 362,
          h: 91,
          child: _SummaryCard(f: f, textColor: _ink),
        ),

        // ─── 탭 + 차트 카드 (Figma Union 1:2136 모양) ─────────────
        //   union = 일간 indicator(20,280,79,40.64) + 차트카드(20,320,362,234)
        //   다른 탭 (주간/월간/년간) 텍스트는 union 밖 — 배경 잔디가 비침.
        ..._buildChartArea(ref),

        // ─── 캘린더 카드 (362×348 at 20,575) ──────────────────────
        f.at(
          x: 20,
          y: 575,
          w: 362,
          h: 348,
          child: _CalendarCard(
            f: f,
            month: calendarMonth,
            onPrev: onPrevMonth,
            onNext: onNextMonth,
            ink: _ink,
            calGray: _calGray,
          ),
        ),

        // ─── 업적 카드 (362×348 at 20,944) ────────────────────────
        f.at(
          x: 20,
          y: 944,
          w: 362,
          h: 348,
          child: _AchievementsCard(f: f, ink: _ink),
        ),

        // ─── 페이지 indicator (Group 53 at 191,1320) ──────────────
        f.at(
          x: 191,
          y: 1320,
          w: 19,
          h: 6,
          child: Row(
            children: [
              Container(
                width: f.sx(6),
                height: f.sx(6),
                decoration: const BoxDecoration(
                  color: Colors.black26,
                  shape: BoxShape.circle,
                ),
              ),
              SizedBox(width: f.sx(7)),
              Container(
                width: f.sx(6),
                height: f.sx(6),
                decoration: const BoxDecoration(
                  color: DotColors.primary,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Summary 카드 — 이번 주 1회 | 이번 달 1일 | 지금까지 1회
// ─────────────────────────────────────────────────────────────────────────────

class _SummaryCard extends ConsumerWidget {
  const _SummaryCard({required this.f, required this.textColor});
  final _Frame f;
  final Color textColor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(trendSummaryStatsProvider).valueOrNull;
    final weekSessions = stats?.thisWeekSessions ?? 0;
    final monthDays = stats?.thisMonthDays ?? 0;
    final total = stats?.totalSessions ?? 0;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(f.sx(10)),
      ),
      child: Stack(
        children: [
          // "이번 주" (60, 186 → card 40,18)
          Positioned(
            left: f.sx(40),
            top: f.sx(18),
            child: _label('이번 주', textColor),
          ),
          Positioned(
            left: f.sx(37),
            top: f.sx(35),
            child: _value('$weekSessions회', textColor),
          ),
          Positioned(
            left: f.sx(117),
            top: f.sx(17),
            child: Container(width: 1, height: f.sx(58), color: Colors.black12),
          ),
          Positioned(
            left: f.sx(164),
            top: f.sx(18),
            child: _label('이번 달', textColor),
          ),
          Positioned(
            left: f.sx(161),
            top: f.sx(35),
            child: _value('$monthDays일', textColor),
          ),
          Positioned(
            left: f.sx(241),
            top: f.sx(17),
            child: Container(width: 1, height: f.sx(58), color: Colors.black12),
          ),
          Positioned(
            left: f.sx(284),
            top: f.sx(18),
            child: _label('지금까지', textColor),
          ),
          Positioned(
            left: f.sx(285),
            top: f.sx(35),
            child: _value('$total회', textColor),
          ),
        ],
      ),
    );
  }

  Widget _label(String t, Color c) => Text(
        t,
        style: TextStyle(
          fontSize: f.sx(12),
          fontWeight: FontWeight.w500,
          color: c,
          fontFamily: BlowfitTheme.fontFamily,
        ),
      );

  Widget _value(String t, Color c) => Text(
        t,
        // height 명시 안 함 — figma 의 AUTO lineHeight 와 일치.
        style: TextStyle(
          fontSize: f.sx(30),
          fontWeight: FontWeight.w700,
          color: c,
          fontFamily: BlowfitTheme.fontFamily,
        ),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Calendar 카드 — 2026년 5월
// ─────────────────────────────────────────────────────────────────────────────

class _CalendarCard extends ConsumerWidget {
  const _CalendarCard({
    required this.f,
    required this.month,
    required this.onPrev,
    required this.onNext,
    required this.ink,
    required this.calGray,
  });
  final _Frame f;
  final DateTime month;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final Color ink;
  final Color calGray;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 이 달 훈련한 날짜 집합 (1-based day-of-month).
    final trainedDays =
        ref.watch(monthTrainedDaysProvider(month)).valueOrNull ?? const <int>{};
    // 카드 (20, 575) ~ (382, 923). card-local 좌표:
    //   < (50, 603, 5x10) → card (30, 28)
    //   "2026년 5월" (163, 601, 77x14) → card (143, 26), centered around 200
    //   > (353, 613, 5x10) → card (333, 38)
    //   요일 (50/98/148/196/246/294/344, 641) → card y=66
    //   날짜 (47~352, 676~885) → card y=101~310
    //
    // 요일 색: 일=red, 토=#08F, 평일=ink
    // 날짜: 13px Bold, #808080
    //
    // 5월 2026 시작: 1일 = 금요일 (frame 297, 676). 즉 첫 주 일~목 비고.
    //   1주차: -, -, -, -, -, 1, 2
    //   2주차: 3, 4, 5, 6, 7, 8, 9
    //   ...
    final firstDow = DateTime(month.year, month.month, 1).weekday % 7; // Sun=0
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    const dayLabels = ['일', '월', '화', '수', '목', '금', '토'];
    // 요일별 x 좌표 (frame): 50, 98, 148, 196, 246, 294, 344
    const dayXs = [50.0, 98.0, 148.0, 196.0, 246.0, 294.0, 344.0];
    // 주차별 y 좌표 (frame): 676, 717, 758, 799, 842, 885 (간격 ~41)
    const weekYs = [676.0, 717.0, 758.0, 799.0, 842.0, 885.0];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(f.sx(10)),
      ),
      child: Stack(
        children: [
          // 좌측 화살표
          Positioned(
            left: f.sx(50 - 20),
            top: f.sx(603 - 575),
            child: GestureDetector(
              onTap: onPrev,
              child: Icon(Icons.chevron_left, color: ink, size: f.sx(18)),
            ),
          ),
          // 우측 화살표
          Positioned(
            left: f.sx(353 - 20),
            top: f.sx(613 - 575),
            child: GestureDetector(
              onTap: onNext,
              child: Icon(Icons.chevron_right, color: ink, size: f.sx(18)),
            ),
          ),
          // 월 표시 "2026년 5월"
          Positioned(
            left: 0,
            right: 0,
            top: f.sx(601 - 575),
            child: Center(
              child: Text(
                '${month.year}년 ${month.month}월',
                style: TextStyle(
                  fontSize: f.sx(15),
                  fontWeight: FontWeight.w700,
                  color: ink,
                  fontFamily: BlowfitTheme.fontFamily,
                ),
              ),
            ),
          ),
          // 요일 헤더
          for (var i = 0; i < 7; i++)
            Positioned(
              left: f.sx(dayXs[i] - 20),
              top: f.sx(641 - 575),
              child: Text(
                dayLabels[i],
                style: TextStyle(
                  fontSize: f.sx(11),
                  fontWeight: FontWeight.w500,
                  color: i == 0
                      ? DotColors.sunday
                      : i == 6
                          ? DotColors.saturday
                          : ink,
                  fontFamily: BlowfitTheme.fontFamily,
                ),
              ),
            ),
          // 날짜 셀 — 훈련한 날은 primary blue + bold, 평일은 calGray.
          // 일요일 / 토요일은 본 색상 유지 (요일 헤더와 일관성).
          for (var d = 1; d <= daysInMonth; d++)
            () {
              final idx = d - 1 + firstDow;
              final row = idx ~/ 7;
              final col = idx % 7;
              if (row >= weekYs.length) return const SizedBox.shrink();
              final trained = trainedDays.contains(d);
              final cellColor = trained
                  ? DotColors.primary
                  : (col == 0
                      ? DotColors.sunday.withValues(alpha: 0.7)
                      : col == 6
                          ? DotColors.saturday.withValues(alpha: 0.7)
                          : calGray);
              return Positioned(
                left: f.sx(dayXs[col] - 20),
                top: f.sx(weekYs[row] - 575),
                child: Text(
                  '$d',
                  style: TextStyle(
                    fontSize: f.sx(13),
                    fontWeight:
                        trained ? FontWeight.w700 : FontWeight.w500,
                    color: cellColor,
                    fontFamily: BlowfitTheme.fontFamily,
                  ),
                ),
              );
            }(),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Achievements 카드
// ─────────────────────────────────────────────────────────────────────────────

class _AchievementsCard extends ConsumerWidget {
  const _AchievementsCard({required this.f, required this.ink});
  final _Frame f;
  final Color ink;

  // Figma 의 item y 좌표 (frame, card-local 변환은 944 빼기). 최대 5개 표시
  // — MilestoneEngine.compute 가 정확히 5개 반환.
  static const _itemYs = [1017.0, 1056.0, 1098.0, 1140.0, 1182.0];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final milestones = ref.watch(milestonesProvider).valueOrNull ?? const [];
    final achievedColor = DotColors.primary;
    final lockedColor = ink.withValues(alpha: 0.25);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(f.sx(10)),
      ),
      child: Stack(
        children: [
          // 업적 타이틀
          Positioned(
            left: f.sx(44 - 20),
            top: f.sx(970 - 944),
            child: Text(
              '업적',
              style: TextStyle(
                fontSize: f.sx(17),
                fontWeight: FontWeight.w700,
                color: ink,
                fontFamily: BlowfitTheme.fontFamily,
              ),
            ),
          ),
          // milestones — 미달성 항목은 체크박스 회색 / 텍스트 fade.
          for (var i = 0;
              i < milestones.length && i < _itemYs.length;
              i++) ...[
            // 체크박스
            Positioned(
              left: f.sx(51 - 20),
              top: f.sx(_itemYs[i] + 1 - 944),
              child: Container(
                width: f.sx(15),
                height: f.sx(15),
                decoration: BoxDecoration(
                  color: milestones[i].achievedAt != null
                      ? achievedColor
                      : lockedColor,
                  borderRadius: BorderRadius.circular(f.sx(3)),
                ),
                child: milestones[i].achievedAt != null
                    ? Icon(Icons.check, size: f.sx(11), color: Colors.white)
                    : null,
              ),
            ),
            // 텍스트
            Positioned(
              left: f.sx(82 - 20),
              top: f.sx(_itemYs[i] - 944),
              child: Text(
                milestones[i].title,
                style: TextStyle(
                  fontSize: f.sx(13),
                  fontWeight: FontWeight.w600,
                  color: milestones[i].achievedAt != null
                      ? ink
                      : ink.withValues(alpha: 0.5),
                  fontFamily: BlowfitTheme.fontFamily,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
