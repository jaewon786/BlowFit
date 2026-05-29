// Figma DoT — 추이 화면 (라이트모드).
//
// 디자인 출처: 1:2128 추이 - 라이트모드 (402×1415, scroll 가능).
// 모든 좌표/크기는 Figma frame px 그대로. 화면 너비/402 로 scale.
// 배경 ellipse 47/48 의 fill/transform 은 figma plugin API 로 추출한 정확한
// 데이터 (nodes 1:2172 + 1:2132).

import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../core/db/db_providers.dart';
import '../../core/db/trend_bucketing.dart';
import '../../core/theme/blowfit_colors.dart';
import '../../core/theme/blowfit_theme.dart';
import '../settings/settings_screen.dart';

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
  // 기본값 = 이번 달 (오늘 하이라이트가 맞으려면 현재 연/월 기준). 사용자가
  // 좌/우 화살표로 이동 가능.
  DateTime _calendarMonth = _thisMonth();

  static DateTime _thisMonth() {
    final n = DateTime.now();
    return DateTime(n.year, n.month);
  }

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
    //
    // Figma blur 효과 (use_figma 직접 추출):
    //   Ellipse 47 (1:2172): LAYER_BLUR radius=18.1 (NORMAL)
    //   Mask group (1:2129, Ellipse 48 포함): LAYER_BLUR radius=46.6→100 (PROGRESSIVE,
    //     위에서 아래로 점점 강해짐). 정확 시뮬레이션은 Flutter API 한계로 어려워서
    //     평균값 (~70) 의 NORMAL blur 로 근사. 시각적으로 비슷한 부드러운 분위기.
    _drawEllipse(
      canvas, scale, _e48Transform, _e48Width, _e48Height,
      _e48Colors, _e48Stops,
      blurSigma: 70,
    );
    _drawEllipse(
      canvas, scale, _e47Transform, _e47Width, _e47Height,
      _e47Colors, _e47Stops,
      blurSigma: 18.1,
    );
  }

  void _drawEllipse(
    Canvas canvas,
    double scale,
    List<List<double>> m,
    double w,
    double h,
    List<Color> colors,
    List<double> stops, {
    double? blurSigma,
  }) {
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
    final paint = Paint()..shader = shader;
    if (blurSigma != null && blurSigma > 0) {
      // saveLayer + ImageFilter.blur 로 Figma LAYER_BLUR 정확히 재현.
      // saveLayer 의 bounds 는 ellipse 영역 + blur radius 만큼 expand.
      final blurBounds = rect.inflate(blurSigma * 2);
      canvas.saveLayer(
        blurBounds,
        Paint()
          ..imageFilter =
              ui.ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
      );
      canvas.drawOval(rect, paint);
      canvas.restore();
    } else {
      canvas.drawOval(rect, paint);
    }
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

  /// 탭 index → TrendPeriod 매핑.
  TrendPeriod get _period {
    return TrendPeriod.values[tabIndex];
  }

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
    // 중) 빈 리스트 — 차트 skeleton 만 보이고 dot/line 없음.
    final buckets =
        ref.watch(trendBucketsProvider(_period)).valueOrNull ?? const [];
    return [
      // 1. 선택된 탭 indicator — 흰색 박스, frame (indicatorX, 292, 79, 47)
      f.at(
        x: indicatorX,
        y: 292,
        w: 79,
        h: 47,
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
      // 2. 차트 카드 — 흰색 박스, frame (20, 332, 362, 234)
      //    Figma Union 의 정확한 corner 모양:
      //    - 일간 (indicator x=20, card 좌측과 정렬): top-left = sharp
      //    - 년간 (indicator x+79=381, card 우측과 정렬): top-right = sharp
      //    - 주간/월간 (indicator 중간): top corner 모두 rounded
      //    - bottom corner: 항상 rounded
      f.at(
        x: 20,
        y: 331, // 1px 위로 — indicator bottom 과 겹쳐서 union 효과
        w: 362,
        h: 234,
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
      // 3. 탭 텍스트 4개 — 모두 frame y=304 위치.
      //    선택된 탭: SemiBold, opacity 1.0. 미선택: Medium, opacity 0.7.
      for (var i = 0; i < _tabs.length; i++)
        f.at(
          x: _tabXs[i] - 8, // 텍스트 좌측 hit area 살짝 키움
          y: 298,
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
      // 4. 호기 평균 legend (frame 45,354, 9×9 #0A89FC radius 1)
      f.at(
        x: 45,
        y: 354,
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
        y: 352,
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
      // 5. 흡기 평균 legend (frame 113,354, 9×9 #32B65E radius 1)
      f.at(
        x: 113,
        y: 354,
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
        y: 352,
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
      // 6. Y-axis labels (frame x, y per label) — 0 line 458 기준 ±30.
      for (final entry in const [
        ('+30', 44.0, 381.0),
        ('+20', 44.0, 405.0),
        ('+10', 45.0, 429.0),
        ('0', 54.0, 453.0),
        ('-10', 46.0, 476.0),
        ('-20', 46.0, 500.0),
        ('-30', 45.0, 524.0),
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
      // 7. Grid lines (7개, frame x=66, w=292, y=386..529)
      for (final y in const [
        386.0,
        410.0,
        434.0,
        458.0,
        481.0,
        505.0,
        529.0,
      ])
        f.at(
          x: 66,
          y: y,
          w: 292,
          h: 1,
          child: Container(color: _muted.withValues(alpha: 0.25)),
        ),
      // 8. 실제 데이터 라인 차트 — 호기 (파랑, 위) + 흡기 mirror (초록, 아래).
      //    Figma 업데이트: dot 만 찍던 것 → dot + 연결선 (line chart).
      //    데이터 없는 (sessionCount==0) 버킷은 line/dot 둘 다 생략.
      Positioned.fill(
        child: IgnorePointer(
          child: CustomPaint(
            painter: _ChartLinePainter(scale: f.scale, buckets: buckets),
          ),
        ),
      ),
      // 9. 라인 끝 라벨 — "호기 ↑" (우상단), "흡기 ↑" (우하단).
      f.at(
        x: 332,
        y: 365,
        child: _EndLabel(f: f, text: '호기'),
      ),
      f.at(
        x: 332,
        y: 533,
        child: _EndLabel(f: f, text: '흡기'),
      ),
    ];
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Stack(
      children: [
        // ─── 로고 (81×22 at 17,56) — 홈 화면과 동일한 BRELOW wordmark ───
        // Figma 제품 로고 1 (61:327) 좌표/크기 그대로. 가로 wordmark.
        f.at(
          x: 17,
          y: 56,
          w: 81,
          h: 22,
          child: Image.asset(
            'assets/dot/logo.png',
            fit: BoxFit.contain,
            filterQuality: FilterQuality.high,
          ),
        ),
        // ─── 설정 아이콘 (Figma SVG, 톱니바퀴) — 좌측, hit 44×44 ───
        // Figma 원본 위치: (320, 60). 다크 모드 ColorFilter 적용.
        f.at(
          x: 308,
          y: 41,
          w: 44,
          h: 44,
          child: Builder(
            builder: (ctx) => GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => Navigator.of(ctx, rootNavigator: true).push(
                MaterialPageRoute(
                  builder: (_) => const SettingsScreen(),
                ),
              ),
              child: Container(
                color: Colors.transparent,
                alignment: Alignment.center,
                child: SvgPicture.asset(
                  'assets/dot/icon_settings.svg',
                  width: f.sx(22),
                  height: f.sx(21),
                  colorFilter:
                      const ColorFilter.mode(_ink, BlendMode.srcIn),
                ),
              ),
            ),
          ),
        ),
        // ─── 알림 종 (Figma SVG) — 우측, hit 44×44 (placeholder) ──
        // Figma 원본 위치: (366, 60). 알림 기능 미구현 — SnackBar.
        f.at(
          x: 354,
          y: 41,
          w: 44,
          h: 44,
          child: Builder(
            builder: (ctx) => GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                ScaffoldMessenger.maybeOf(ctx)
                  ?..removeCurrentSnackBar()
                  ..showSnackBar(
                    const SnackBar(
                      content: Text('알림 기능 준비 중'),
                      duration: Duration(seconds: 1),
                    ),
                  );
              },
              child: Container(
                color: Colors.transparent,
                alignment: Alignment.center,
                child: SvgPicture.asset(
                  'assets/dot/icon_bell.svg',
                  width: f.sx(18),
                  height: f.sx(20),
                  colorFilter:
                      const ColorFilter.mode(_ink, BlendMode.srcIn),
                ),
              ),
            ),
          ),
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

        // ─── Summary 카드 (362×91 at 20,175, white opacity 0.8, r10)
        f.at(
          x: 20,
          y: 175,
          w: 362,
          h: 91,
          child: _SummaryCard(f: f, textColor: _ink),
        ),

        // ─── 탭 + 차트 카드 (Figma Union 1:2136 모양) ─────────────
        //   union = 일간 indicator(20,280,79,40.64) + 차트카드(20,320,362,234)
        //   다른 탭 (주간/월간/년간) 텍스트는 union 밖 — 배경 잔디가 비침.
        ..._buildChartArea(ref),

        // ─── 캘린더 카드 (362×348 at 20,587) ──────────────────────
        f.at(
          x: 20,
          y: 587,
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

        // ─── 업적 카드 (362×348 at 20,956) ────────────────────────
        f.at(
          x: 20,
          y: 956,
          w: 362,
          h: 348,
          child: _AchievementsCard(f: f, ink: _ink),
        ),

        // ─── 페이지 indicator (Group 53 at 191,1332) ──────────────
        f.at(
          x: 191,
          y: 1332,
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
    final monthSessions = stats?.thisMonthSessions ?? 0;
    final total = stats?.totalSessions ?? 0;

    // 3개 컬럼 — divider (frame x=137, 261 → card-local 117, 241) 로 구분.
    // 라벨/값을 각 컬럼 중앙 정렬 → 자릿수와 무관하게 가운데 배치.
    //   col1: 0~117 (center 58.5) / col2: 117~241 (center 179) / col3: 241~362 (center 301.5)
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(f.sx(10)),
      ),
      child: Stack(
        children: [
          // 세로 divider 2개
          Positioned(
            left: f.sx(117),
            top: f.sx(17),
            child: Container(width: 1, height: f.sx(58), color: Colors.black12),
          ),
          Positioned(
            left: f.sx(241),
            top: f.sx(17),
            child: Container(width: 1, height: f.sx(58), color: Colors.black12),
          ),
          // 이번 주 — 회수
          _col(0, 117, '이번 주', '$weekSessions회'),
          // 이번 달 — 회수 (기존 '일' → '회' 로 변경)
          _col(117, 241, '이번 달', '$monthSessions회'),
          // 지금까지 — 회수
          _col(241, 362, '지금까지', '$total회'),
        ],
      ),
    );
  }

  /// [left]~[right] (card-local frame px) 구간 중앙에 라벨(위) + 값(아래) 배치.
  Widget _col(double left, double right, String label, String value) {
    return Positioned(
      left: f.sx(left),
      width: f.sx(right - left),
      top: f.sx(18),
      child: Column(
        children: [
          _label(label, textColor),
          SizedBox(height: f.sx(2)),
          _value(value, textColor),
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
        // Figma 값 폰트 27 Bold. height 명시 안 함 — AUTO lineHeight 일치.
        style: TextStyle(
          fontSize: f.sx(27),
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

  // 훈련일 하이라이트 색 (Figma 추출):
  //   오늘  = solid #0084FF 원 + 흰 글씨
  //   훈련일 = 연파랑 #A5D3FF 원 + 진회색 #2F2F2F 글씨
  //   그 외  = 원 없음 + #808080 글씨
  static const _todayCircle = Color(0xFF0084FF);
  static const _trainedCircle = Color(0xFFA5D3FF);
  static const _trainedText = Color(0xFF2F2F2F);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 이 달 훈련한 날짜 집합 (1-based day-of-month).
    final trainedDays =
        ref.watch(monthTrainedDaysProvider(month)).valueOrNull ?? const <int>{};
    final now = DateTime.now();
    final isCurrentMonth = now.year == month.year && now.month == month.month;

    // 카드 (20, 587) 기준 card-local 좌표 = frame - (20, 587).
    //   < (50, 615)  → local (30, 28)
    //   "2026년 5월" (163, 613) → top local 26, 가로 중앙
    //   > (353, 625) → local (333, 38)
    //   요일 헤더 (y=653) → local top 66
    //   날짜 셀: 열 중심 = 55+49·col (frame), 행 중심 = 697+41.2·row (frame)
    //           각 날짜는 30×30 원 안에 중앙 정렬 (Figma Ellipse 30×30).
    //
    // 5월 2026 시작: 1일 = 금요일. 첫 주 일~목 비고.
    final firstDow = DateTime(month.year, month.month, 1).weekday % 7; // Sun=0
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    const dayLabels = ['일', '월', '화', '수', '목', '금', '토'];
    // 열 중심 (card-local): 35 + 49·i.
    const colCenter = [35.0, 84.0, 133.0, 182.0, 231.0, 280.0, 329.0];
    // 행 중심 (card-local): 110 + 41.2·r (최대 6주).
    const rowCenter = [110.0, 151.2, 192.4, 233.6, 274.8, 316.0];

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
            top: f.sx(615 - 587),
            child: GestureDetector(
              onTap: onPrev,
              child: Icon(Icons.chevron_left, color: ink, size: f.sx(18)),
            ),
          ),
          // 우측 화살표
          Positioned(
            left: f.sx(353 - 20),
            top: f.sx(625 - 587),
            child: GestureDetector(
              onTap: onNext,
              child: Icon(Icons.chevron_right, color: ink, size: f.sx(18)),
            ),
          ),
          // 월 표시 "2026년 5월"
          Positioned(
            left: 0,
            right: 0,
            top: f.sx(613 - 587),
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
          // 요일 헤더 — 열 중심 정렬. 일=red, 토=#08F, 평일=ink.
          for (var i = 0; i < 7; i++)
            Positioned(
              left: f.sx(colCenter[i] - 15),
              top: f.sx(653 - 587),
              width: f.sx(30),
              child: Center(
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
            ),
          // 날짜 셀 — 30×30 원 안에 중앙 정렬. 오늘/훈련일/평일 구분.
          for (var d = 1; d <= daysInMonth; d++)
            () {
              final idx = d - 1 + firstDow;
              final row = idx ~/ 7;
              final col = idx % 7;
              if (row >= rowCenter.length) return const SizedBox.shrink();
              final isToday = isCurrentMonth && d == now.day;
              final trained = trainedDays.contains(d);
              final Color? circleColor = isToday
                  ? _todayCircle
                  : (trained ? _trainedCircle : null);
              final textColor = isToday
                  ? Colors.white
                  : (trained ? _trainedText : calGray);
              return Positioned(
                left: f.sx(colCenter[col] - 15),
                top: f.sx(rowCenter[row] - 15),
                width: f.sx(30),
                height: f.sx(30),
                child: Container(
                  alignment: Alignment.center,
                  decoration: circleColor == null
                      ? null
                      : BoxDecoration(
                          color: circleColor,
                          shape: BoxShape.circle,
                        ),
                  child: Text(
                    '$d',
                    style: TextStyle(
                      fontSize: f.sx(13),
                      fontWeight: FontWeight.w700,
                      color: textColor,
                      fontFamily: BlowfitTheme.fontFamily,
                    ),
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

  // Figma 의 item y 좌표 (frame, card-local 변환은 956 빼기). 최대 5개 표시
  // — MilestoneEngine.compute 가 정확히 5개 반환.
  static const _itemYs = [1029.0, 1068.0, 1110.0, 1152.0, 1194.0];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final milestones = ref.watch(milestonesProvider).valueOrNull ?? const [];
    const achievedColor = DotColors.primary;
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
            top: f.sx(982 - 956),
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
              top: f.sx(_itemYs[i] + 1 - 956),
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
              top: f.sx(_itemYs[i] - 956),
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

// ─────────────────────────────────────────────────────────────────────────────
// 압력 차트 라인 페인터 — 호기 (파랑, 0 line 위) + 흡기 mirror (초록, 아래).
// Figma 업데이트로 dot 만 찍던 차트가 dot + 연결선 (line chart) 으로 변경됨.
// 좌표/스케일은 frame 402 기준, scale = screenW/402 로 변환.
// ─────────────────────────────────────────────────────────────────────────────

class _ChartLinePainter extends CustomPainter {
  _ChartLinePainter({required this.scale, required this.buckets});
  final double scale;
  final List<TrendBucket> buckets;

  // 차트 기하 (figma frame 좌표) — 0 line=458, +30=386, -30=529.
  static const _chartLeft = 66.0;
  static const _chartRight = 358.0;
  static const _chartWidth = _chartRight - _chartLeft;
  static const _zeroY = 458.0;
  static const _pxPerCmH2O = 2.4;
  static const _dotR = 3.0; // figma dot 6×6 → radius 3.

  @override
  void paint(Canvas canvas, Size size) {
    if (buckets.isEmpty) return;
    final s = scale;
    final spacing = _chartWidth / buckets.length;
    final exhale = <Offset>[];
    final inhale = <Offset>[];
    for (final b in buckets) {
      if (b.isEmpty || b.avgExhale == null) continue;
      final cx = (_chartLeft + (b.xPos - 0.5) * spacing) * s;
      final eY = (_zeroY - b.avgExhale! * _pxPerCmH2O) * s;
      // DB 에 흡기 별도 stat 없음 → 호기 평균을 음수로 미러링. 펌웨어가
      // 호기/흡기 분리 stat 보내면 그때 실제 흡기 평균 사용.
      final iY = (_zeroY + b.avgExhale! * _pxPerCmH2O) * s;
      exhale.add(Offset(cx, eY));
      inhale.add(Offset(cx, iY));
    }
    _drawSeries(canvas, exhale, DotColors.primary, s);
    _drawSeries(canvas, inhale, DotColors.inhale, s);
  }

  void _drawSeries(Canvas canvas, List<Offset> pts, Color color, double s) {
    if (pts.isEmpty) return;
    if (pts.length > 1) {
      final line = Paint()
        ..color = color
        ..strokeWidth = 2 * s
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;
      final path = Path()..moveTo(pts.first.dx, pts.first.dy);
      for (var i = 1; i < pts.length; i++) {
        path.lineTo(pts[i].dx, pts[i].dy);
      }
      canvas.drawPath(path, line);
    }
    final dot = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    for (final p in pts) {
      canvas.drawCircle(p, _dotR * s, dot);
    }
  }

  @override
  bool shouldRepaint(_ChartLinePainter old) =>
      old.scale != scale || old.buckets != buckets;
}

// ─────────────────────────────────────────────────────────────────────────────
// 차트 라인 끝 라벨 — "호기 ↑" / "흡기 ↑" (10 Medium black + 위 화살표).
// ─────────────────────────────────────────────────────────────────────────────

class _EndLabel extends StatelessWidget {
  const _EndLabel({required this.f, required this.text});
  final _Frame f;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          text,
          style: TextStyle(
            fontSize: f.sx(10),
            fontWeight: FontWeight.w500,
            color: Colors.black,
            fontFamily: BlowfitTheme.fontFamily,
          ),
        ),
        SizedBox(width: f.sx(3)),
        Icon(Icons.arrow_upward, size: f.sx(10), color: Colors.black),
      ],
    );
  }
}
