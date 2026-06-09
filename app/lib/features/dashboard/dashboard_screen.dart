// Figma DoT — 홈 화면 (라이트 + 다크).
//
// 디자인 출처:
//   1:2060  홈화면 - 라이트모드 (402 × 874)
//   1:2261  홈화면 - 다크모드   (402 × 874)
//
// Asset 출처:
//   home_light.png 에서 직접 crop +alpha 처리:
//     - grass.png : 잔디 영역 (mascot 영역은 transparent, 나머지는 column-fill)
//     - mascot.png: mascot 영역 (sky/grass 색은 transparent)
//     - mascot_dark.png: home_dark.png 의 mascot 영역
//     - icon_settings.png, icon_bell.png: 우상단 아이콘 (검정만 keep)
//     - logo.png: 좌상단 로고 (검정 alpha)
//
// 좌표는 Figma 402×874 frame px 그대로. 화면 너비/402 로 scale.
// 페이지 indicator dots 가 system nav bar 에 가려지지 않도록 SafeArea bottom.
// top 은 status bar 영역까지 컨텐츠가 보이도록 (logo 가 status bar 와 가까이).

import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../core/ble/ble_providers.dart';
import '../../core/ble/blowfit_uuids.dart';
import '../../core/coach/growth_message.dart';
import '../../core/db/db_providers.dart';
import '../../core/storage/storage_providers.dart';
import '../../core/theme/blowfit_colors.dart';
import '../../core/theme/blowfit_theme.dart';
import '../settings/settings_screen.dart';
import 'widgets/brelow_character_panel.dart';

const double _kFrameW = 402;

// ─────────────────────────────────────────────────────────────────────────────
// 단계별 캐릭터 레이아웃 — Figma DoT frame 97:2(Egg) / 97:57(Baby) / 97:105(Oxygen).
// 모든 좌표는 402×874 Figma frame 기준. _Frame.scale 로 화면 해상도에 맞게 변환.
// ─────────────────────────────────────────────────────────────────────────────
class _StageLayout {
  const _StageLayout({
    required this.bubbleX,
    required this.bubbleY,
    required this.bubbleW,
    required this.tailX,
    required this.tailY,
    required this.charX,
    required this.charY,
    required this.charW,
    required this.charH,
    required this.speechText,
    required this.shadowX,
    required this.shadowY,
    required this.shadowW,
    required this.shadowH,
    required this.charFeetY,
    this.charScale = 1.0,
  });

  /// 말풍선 Rectangle 77.
  final double bubbleX, bubbleY, bubbleW;

  /// 말풍선 꼬리 Vector 6117.
  final double tailX, tailY;

  /// 캐릭터 Rive 영역 (Mask group / image XXXX). Figma 의 visible 바운딩.
  final double charX, charY, charW, charH;

  /// 말풍선 안 텍스트.
  final String speechText;

  /// 지면 그림자 (Figma Ellipse 54) — 캐릭터 발밑의 블러 타원.
  final double shadowX, shadowY, shadowW, shadowH;

  /// 캐릭터 "발끝" 이 닿아야 할 Figma Y (= 그림자 중심 Y 기준).
  /// 캐릭터 슬롯을 bottomCenter 정렬하고 이 Y 를 슬롯 하단으로 삼아 캐릭터가
  /// 그림자 위에 안착하도록 한다. .riv 아트보드 하단 여백 때문에 발끝이 살짝
  /// 뜨면 이 값만 단계별로 몇 px 내려 미세조정한다(한 곳에서 관리).
  final double charFeetY;

  /// Rive 아트보드 padding 보정 배율. .riv 의 아트보드는 alive/happy/bloom 의
  /// 모션 extent 를 담기 위해 visible 캐릭터보다 큰 경우가 많다. `Fit.contain`
  /// 으로 렌더 시 슬롯의 visible 영역이 Figma 보다 작아 보이므로 슬롯 자체를
  /// 비례 확대해 보정한다(가로 폭 기준). 세로는 bottomCenter 정렬 + charFeetY 로
  /// 발끝 위치를 고정한다.
  final double charScale;

  /// 모든 단계 공통 고정값.
  static const double bubbleH = 50;
  // 꼬리 Vector 6117 의 Figma 원본 크기(17×14). SVG 에셋을 원본 비율로 렌더하므로
  // 절대 늘리지 말 것(가로로 늘리면 곡선이 왜곡됨).
  static const double tailW = 17;
  static const double tailH = 14;
}

const _kStageLayouts = <int, _StageLayout>{
  // Egg (97:2): Mask group 119,342 165.74×177 / shadow 108,494 188×49
  //             bubble 72,264 258×50 / tail 106,311
  1: _StageLayout(
    bubbleX: 72, bubbleY: 264, bubbleW: 258,
    tailX: 106, tailY: 311,
    charX: 119, charY: 342, charW: 165.74, charH: 177,
    speechText: '훈련을 통해 저를 산소로 만들어주세요!',
    shadowX: 108, shadowY: 494, shadowW: 188, shadowH: 49,
    // 실기기 측정: scale 1.55 에서 알이 Figma 의 78.4% (129.9 vs 165.74)로
    // 작게 렌더됨(.riv 아트보드 여백). scale = 1.55/0.784 ≈ 1.98 로 보정.
    // scale 키우면 하단여백×scale 도 ×1.277 커져 발끝이 떠오르므로 charFeetY
    // 도 575→586 으로 올려 그림자(중심 y≈518) 위에 발끝 유지.
    charFeetY: 586,
    charScale: 1.98,
  ),
  // Baby (97:57): image 2002 135,361 133×117 / shadow 132,448 140×49
  //               bubble 103,287 196×50 / tail 132,334
  2: _StageLayout(
    bubbleX: 103, bubbleY: 287, bubbleW: 196,
    tailX: 132, tailY: 334,
    charX: 135, charY: 361, charW: 133, charH: 117,
    speechText: '저는 쪼꼬미 아가입니다!',
    shadowX: 132, shadowY: 448, shadowW: 140, shadowH: 49,
    // 실기기 측정: scale 1.55 에서 Baby 가 Figma 의 71.4% (94.9 vs 133).
    // scale = 1.55/0.714 ≈ 2.17. 발끝도 그림자(472.5)보다 떠 있어 charFeetY 도
    // 478→526 으로 보정(scale 키운 만큼 하단여백×scale 증가분 반영).
    charFeetY: 526,
    charScale: 2.17,
  ),
  // Oxygen (97:105): image 2003 83,328 236×207 / shadow 94,507 216×49
  //                  bubble 107,254 188×50 / tail 132,301
  3: _StageLayout(
    bubbleX: 107, bubbleY: 254, bubbleW: 188,
    tailX: 132, tailY: 301,
    charX: 83, charY: 328, charW: 236, charH: 207,
    speechText: '저 이제 어른입니다.',
    shadowX: 94, shadowY: 507, shadowW: 216, shadowH: 49,
    // 실기기 측정: scale 1.35 에서 Oxygen 이 Figma 의 92% (217 vs 236).
    // scale = 1.35×236/217 ≈ 1.47. 발끝도 그림자(531.5)보다 떠 있어 charFeetY
    // 도 535→602 으로 보정(scale 키운 만큼 하단여백×scale 증가분 반영).
    charFeetY: 602,
    charScale: 1.47,
  ),
};

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

/// 홈 헤드라인 문구 — 주간 호기 평균 증감 3분기 + 무데이터 격려.
String _homeHeadline(({GrowthTrend trend, int pct}) g) {
  switch (g.trend) {
    case GrowthTrend.up:
      return '지난주보다 평균 압력이\n${g.pct}% 증가했어요!';
    case GrowthTrend.down:
      return '지난주보다 평균 압력이\n${g.pct}% 감소했어요!';
    case GrowthTrend.flat:
      return '지난주와 평균 압력이\n비슷해요!';
    case GrowthTrend.noData:
      return '꾸준히 훈련을\n시작해봐요!';
  }
}

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeModeProvider);
    final isDark = mode == ThemeMode.dark;
    final media = MediaQuery.of(context);
    final f = _Frame(media.size.width);

    return Scaffold(
      backgroundColor: isDark ? DotColors.darkBg : null,
      body: Stack(
        children: [
          // 배경 — Figma 의 두 회전 ellipse 를 frame 좌표 그대로 그림.
          // 화면 전체 cover. LayoutBuilder 로 painter 가 받는 size 명시.
          Positioned.fill(
            child: LayoutBuilder(
              builder: (_, c) => CustomPaint(
                size: Size(c.maxWidth, c.maxHeight),
                painter: _BgPainter(isDark: isDark),
              ),
            ),
          ),
          // 컨텐츠.
          _HomeContent(
            f: f,
            isDark: isDark,
            ref: ref,
            bottomInset: media.padding.bottom,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 배경 페인터 — Figma Ellipse 47 + Ellipse 48 을 frame(402×874) 좌표 그대로
//
//   Ellipse 47 (어두운 잔디, 뒷쪽): x=-348, y=338, w=985, h=786, rotate 4.82°
//   Ellipse 48 (밝은 잔디, 앞쪽) : x=312,  y=328, w=638, h=640, rotate 41.08°
//
// 색상은 home_light.png 픽셀 추출 기준: 진한 잔디 #A2DB79, 밝은 잔디 #B5E981.
// ─────────────────────────────────────────────────────────────────────────────

class _BgPainter extends CustomPainter {
  _BgPainter({required this.isDark});
  final bool isDark;

  // Figma plugin API 로 직접 추출한 Ellipse 47 / 48 의 정확한 데이터.
  // (file Shu32okKe6gBb7gUoqxdRT, nodes 1:2063 + 1:2062)
  //
  // 각 ellipse 의 fill 은 GRADIENT_LINEAR (단색 아님). gradientTransform 분석상
  // unit space y-up 기준이라 position 0 (밝은 색) = ellipse local top, position 1
  // (진한 색) = local bottom. Flutter LinearGradient(begin: topCenter, end:
  // bottomCenter) 와 매핑됨.
  //
  // relativeTransform 은 figma frame 좌표계에서 ellipse 의 회전+이동. Flutter
  // canvas.transform 으로 그대로 적용 가능.

  // ─── Ellipse 47 (라이트) — 뒷쪽 큰 잔디 곡선 ─────────────────
  static const _e47Width = 929.5265502929688;
  static const _e47Height = 710.48974609375;
  static const _e47Transform = [
    [0.9964643716812134, -0.08401674032211304, -348.306884765625],
    [0.08401674032211304, 0.9964643716812134, 338.3779296875],
  ];
  static const _e47Colors = [
    Color(0xFFCFFF94),
    Color(0xFF89C76A),
    Color(0xFF4BA22B),
  ];
  static const _e47Stops = [0.0, 0.5144, 1.0];

  // ─── Ellipse 48 (라이트) — 앞쪽 작은 잔디 곡선 ───────────────
  static const _e48Width = 446.32281494140625;
  static const _e48Height = 460.0470886230469;
  static const _e48Transform = [
    [0.7538431286811829, -0.6570544242858887, 312.7431640625],
    [0.6570544242858887, 0.7538431286811829, 328.080078125],
  ];
  static const _e48Colors = [
    Color(0xFFE2F8C8),
    Color(0xFF78CA59),
  ];
  static const _e48Stops = [0.0, 1.0];

  // ─── Ellipse 47 (다크) — figma 1:2264 ───────────────────────
  //   x 가 라이트(-348.31)와 살짝 다름 (-351.93). 회전/크기는 같음.
  static const _e47DarkTransform = [
    [0.9964643716812134, -0.08401674032211304, -351.9313049316406],
    [0.08401674032211304, 0.9964643716812134, 338.3775634765625],
  ];
  static const _e47DarkColors = [
    Color(0xFF34346A), // pos 0.0    (어두운 보라/네이비, 잔디 위 가장자리)
    Color(0xFF1D1E45), // pos 0.13
    Color(0xFF10112F), // pos 0.365
    Color(0xFF05061B), // pos 1.0    (매우 어두운 네이비)
  ];
  static const _e47DarkStops = [0.0, 0.1298, 0.3654, 1.0];

  // ─── Ellipse 48 (다크) — figma 1:2263 ───────────────────────
  static const _e48DarkColors = [
    Color(0xFF161841), // pos 0.0
    Color(0xFF05061B), // pos 1.0
  ];
  static const _e48DarkStops = [0.0, 1.0];

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final paint = Paint();
    final scale = size.width / _kFrameW;

    if (isDark) {
      // 다크 모드 배경 — figma Rectangle 69 (1:2262) 단색 #060725
      paint.color = const Color(0xFF060725);
      canvas.drawRect(rect, paint);
      // 48 먼저 (뒤) → 47 그 위에.
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
        _e47DarkTransform,
        _e47Width,
        _e47Height,
        _e47DarkColors,
        _e47DarkStops,
      );
      return;
    }

    // 라이트: 하늘 그라데이션 → 잔디 ellipse 두 개 (각각 gradient fill).
    //
    // Figma plugin 직접 추출:
    //   Rectangle 69 fill = GRADIENT_LINEAR
    //     stop 0 (pos 0): #99EBFC (lightBgTop)
    //     stop 1 (pos 1): #DBF9FF (lightBgBottom)
    //   SVG output: linearGradient (x1=201, y1=0) → (x2=393, y2=447.5)
    //     in 402×874 frame. 정규화: begin (0, -1) top center → end
    //     (0.955, 0.024) right-mid. 약 ~157° (남남동).
    paint.shader = const LinearGradient(
      begin: Alignment(0.0, -1.0),
      end: Alignment(0.955, 0.024),
      colors: [
        DotColors.lightBgTop, // #99EBFC
        DotColors.lightBgBottom, // #DBF9FF
      ],
    ).createShader(rect);
    canvas.drawRect(rect, paint);
    paint.shader = null;

    // 48 먼저 (뒤) → 47 그 위에 그려서 47 이 시각적으로 앞쪽에 보이게.
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

  /// Figma 의 relativeTransform 을 Flutter canvas 에 그대로 적용하고 ellipse 의
  /// 회전 전 local 좌표계 (0, 0)~(w, h) 에 oval 을 그린다. gradient 도 같은 local
  /// 좌표계에서 top → bottom 방향 (figma gradientTransform 결과).
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
    // Frame(402) → Screen scale.
    canvas.scale(scale, scale);
    // Ellipse 의 figma transform (회전 + translate). Float64List 는
    // column-major 4×4. figma 의 2×3 affine 을 4×4 로 확장.
    canvas.transform(
      Float64List.fromList(<double>[
        m[0][0], m[1][0], 0, 0, // col 0
        m[0][1], m[1][1], 0, 0, // col 1
        0, 0, 1, 0, // col 2
        m[0][2], m[1][2], 0, 1, // col 3 (translate)
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
  bool shouldRepaint(_BgPainter old) => old.isDark != isDark;
}

class _HomeContent extends StatelessWidget {
  const _HomeContent({
    required this.f,
    required this.isDark,
    required this.ref,
    required this.bottomInset,
  });
  final _Frame f;
  final bool isDark;
  final WidgetRef ref;
  final double bottomInset;

  @override
  Widget build(BuildContext context) {
    final textPrimary =
        isDark ? DotColors.darkTextPrimary : DotColors.lightTextPrimary;

    // (단계별 말풍선·캐릭터 위치는 아래 "무대" Consumer 에서만
    //  characterShownLevelProvider 를 watch 한다 — 여기서 watch 하면 진화(레벨
    //  변경) 한 프레임에 통계 카드·차트까지 통째로 리빌드되어 렉이 생기므로,
    //  무대 위젯(말풍선/꼬리/그림자/캐릭터)만 별도 Consumer 로 분리한다.)

    // (이전 raster PNG 용 invertFilter / buildIcon 은 SVG 전환 후 제거됨.
    //  SVG 는 SvgPicture.asset 의 colorFilter 파라미터로 다크 모드 처리.)

    return Stack(
      children: [
        // ─── 로고 (81×22 at 17,56) — Figma 새 가로형 로고 ──────────
        // 새 디자인은 가로 wordmark 형태. 1024×277 raster export 후 fit:contain
        // 으로 표시 — 어떤 DPI 에서도 sharp.
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

        // ─── 설정 아이콘 (Figma SVG, 톱니바퀴) — Figma 원본 위치 ────
        // Figma 좌표: vector (320, 60) 20×19. Hit 영역 44×44 로 확대.
        // 다크 모드 시 ColorFilter 로 색상 invert (검정 stroke → 흰색).
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
                  colorFilter: ColorFilter.mode(textPrimary, BlendMode.srcIn),
                ),
              ),
            ),
          ),
        ),

        // ─── 알림 종 (Figma SVG) — Figma 원본 위치 (우측) ──────────
        // Figma 좌표: vector (366, 60) 16×18. Hit 영역 44×44.
        // 알림 기능 미구현 — placeholder SnackBar.
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
                  colorFilter: ColorFilter.mode(textPrimary, BlendMode.srcIn),
                ),
              ),
            ),
          ),
        ),

        // ─── "안녕하세요. {이름}님" (15 SemiBold at 19,112) ────────
        // UserProfile.name 이 없으면 (온보딩 미완) "사용자" fallback.
        f.at(
          x: 19,
          y: 108,
          child: Row(
            children: [
              Consumer(
                builder: (_, ref, __) {
                  final store = ref.watch(userProfileStoreProvider).valueOrNull;
                  final name = store?.load()?.name ?? '사용자';
                  return Text(
                    '안녕하세요. $name님',
                    style: TextStyle(
                      fontSize: f.sx(15),
                      fontWeight: FontWeight.w600,
                      height: 1.2,
                      color: textPrimary,
                      fontFamily: BlowfitTheme.fontFamily,
                    ),
                  );
                },
              ),
              SizedBox(width: f.sx(4)),
              // Figma 의 12×12 노란 smiley 이모지 (home_light.png 에서 직접 추출).
              SizedBox(
                width: f.sx(12),
                height: f.sx(12),
                child: Image.asset('assets/dot/emoji.png', fit: BoxFit.contain),
              ),
            ],
          ),
        ),

        // ─── 메인 헤드라인 (25 Bold at 19,140, multi-line) ────────
        // weekAvgPressureProvider (이번주/지난주 호기 평균) 로 증감 % 동적 생성.
        // 데이터 없으면 (첫 사용자/지난주 0) 격려 문구. 232×70 박스 안 줄바꿈.
        f.at(
          x: 19,
          y: 140,
          w: 260,
          child: Consumer(
            builder: (_, ref, __) {
              final pair = ref.watch(weekAvgPressureProvider).valueOrNull;
              final g = weeklyGrowth(
                thisWeek: pair?.thisWeek,
                lastWeek: pair?.lastWeek,
              );
              return Text(
                _homeHeadline(g),
                style: TextStyle(
                  fontSize: f.sx(25),
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.5,
                  height: 1.19,
                  color: textPrimary,
                  fontFamily: BlowfitTheme.fontFamily,
                ),
              );
            },
          ),
        ),

        // ─── "훈련하기" pill (93×43) — /training 으로 이동 ──────────
        // Figma 에선 frame y=567 (통계 카드 y=620 바로 위 10dp gap) 이지만,
        // 통계 카드가 bottom-anchored (system nav 회피) 라서 버튼도 동일하게
        // bottom-anchored — 통계 카드 위 10dp 로 고정. 어떤 폰 aspect 에서도
        // 카드와 겹치지 않음. 우측 정렬 (frame 기준 left=289 → 우측 20dp).
        Positioned(
          right: f.sx(20),
          bottom: bottomInset + f.sx(16 + 6 + 16 + 194 + 10),
          width: f.sx(93),
          height: f.sx(43),
          child: Builder(
            builder: (ctx) => GestureDetector(
              onTap: () {
                debugPrint('[home] 훈련하기 onTap');
                final mgr = ref.read(bleManagerProvider);
                // BLE write — fire-and-forget. RealBleManager.startSession 이
                // 내부에서 ensureConnected (readRssi + 필요 시 hard reconnect)
                // 를 수행하므로 dashboard 가 multi-step 복구 로직 가질 필요 X.
                // 미연결이라 startSession 실패해도 navigation 은 진행 — 훈련
                // 화면이 자체적으로 연결 상태 표시.
                () async {
                  try {
                    await mgr.startSession(OrificeLevel.medium);
                  } catch (e) {
                    debugPrint('[home] startSession failed: $e');
                  }
                }();
                ctx.push('/training');
              },
              child: Container(
                decoration: BoxDecoration(
                  color: isDark ? DotColors.darkCardSoft : DotColors.lightCtaBg,
                  borderRadius: BorderRadius.circular(f.sx(10)),
                ),
                alignment: Alignment.center,
                child: Text(
                  '훈련하기',
                  style: TextStyle(
                    fontSize: f.sx(17),
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                    fontFamily: BlowfitTheme.fontFamily,
                  ),
                ),
              ),
            ),
          ),
        ),

        // ─── 다크 모드 토글 (icon-only at 262,41, hit 44×44) ───────
        // 새 Figma 디자인은 훈련하기가 한참 아래로 내려가서 pill 형태의 토글이
        // 어울리는 자리가 없음. 설정/알람 옆 작은 icon 으로 통일.
        f.at(
          x: 262,
          y: 41,
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
                color: textPrimary,
              ),
            ),
          ),
        ),

        // ─── 무대(말풍선·꼬리·그림자·캐릭터) — 단계별 위치/크기 ──────────
        // characterShownLevelProvider 는 여기서만 watch → 진화 시 이 4개만
        // 리빌드(통계 카드·차트는 그대로 유지되어 진화 프레임이 가벼워짐).
        //
        // IgnorePointer: 무대는 순수 장식이라 탭을 가로채면 안 된다. 특히 캐릭터
        // Rive 슬롯은 투명 padding 영역까지 hit 영역이라, 큰 슬롯(egg/oxygen)이
        // 우측 하단 "훈련하기" 버튼 위를 덮어 탭이 안 먹던 문제가 있었음 → 무대
        // 전체를 hit-test 에서 제외해 탭이 아래(버튼 등)로 통과하게 한다.
        Positioned.fill(
          child: IgnorePointer(
            child: Consumer(
              builder: (context, ref, _) {
                final shownLevel = ref.watch(characterShownLevelProvider);
                final layout = _kStageLayouts[shownLevel] ?? _kStageLayouts[1]!;
                return Stack(
                  children: [
                    // ─── 말풍선 박스 (단계별 위치/크기 — Figma 97:2/57/105) ───────
                    // Egg 258×50 at (72,264) / Baby 196×50 at (103,287) / Oxygen 188×50 at (107,254).
                    f.at(
                      x: layout.bubbleX,
                      y: layout.bubbleY,
                      w: layout.bubbleW,
                      h: _StageLayout.bubbleH,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(f.sx(10)),
                        ),
                        alignment: Alignment.center,
                        child: Padding(
                          padding: EdgeInsets.symmetric(horizontal: f.sx(10)),
                          // FittedBox(scaleDown): Figma 폰트(15px)로 들어가면 그대로, 기기
                          // 폰트 메트릭 차이로 살짝 넘치면 자동으로 아주 조금만 축소 →
                          // "요!" 가 ellipsis 로 잘리던 문제 방지(절대 안 잘림).
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              layout.speechText,
                              maxLines: 1,
                              softWrap: false,
                              style: TextStyle(
                                fontSize: f.sx(15),
                                fontWeight: FontWeight.w700,
                                color: Colors.black,
                                fontFamily: BlowfitTheme.fontFamily,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),

                    // ─── 말풍선 꼬리 (단계별 위치 — Vector 6117 17×14) ───────────
                    // Egg (106,311) / Baby (132,334) / Oxygen (132,301).
                    // Figma 원본 벡터를 SVG 에셋으로 그대로 렌더 → 모양 100% 일치(손으로
                    // 베지어를 맞추지 않음). BoxFit.fill 로 17×14 슬롯을 꽉 채우되, 슬롯
                    // 비율(17:14)이 viewBox 와 같으므로 왜곡 없음.
                    f.at(
                      x: layout.tailX,
                      y: layout.tailY,
                      w: _StageLayout.tailW,
                      h: _StageLayout.tailH,
                      child: SvgPicture.asset(
                        'assets/dot/speech_tail.svg',
                        fit: BoxFit.fill,
                      ),
                    ),

                    // ─── 지면 그림자 (Figma Ellipse 54) — 캐릭터보다 먼저(뒤) 그림 ────
                    // 가우시안 블러된 회색 타원. 캐릭터 발밑에 깔려 입체감을 줌.
                    f.at(
                      x: layout.shadowX,
                      y: layout.shadowY,
                      w: layout.shadowW,
                      h: layout.shadowH,
                      child: CustomPaint(
                        painter: _GroundShadowPainter(blurSigma: f.sx(8)),
                      ),
                    ),

                    // ─── 캐릭터 (단계별 위치/크기 — Figma 97:2/57/105) ────────────
                    // Figma visible 바운딩의 가로 폭에 charScale 을 곱해 Rive 아트보드
                    // padding 을 보정(크기). 세로는 bottomCenter 정렬 + charFeetY 로 발끝을
                    // 그림자 위에 안착시킨다. 슬롯 height 는 발끝(charFeetY) 위로 충분히
                    // 크게 잡아 캐릭터 전체가 들어가도록 함(말풍선과 겹쳐도 투명 padding).
                    () {
                      final slotW = layout.charW * layout.charScale;
                      // 슬롯 높이: 발끝 기준 위로 캐릭터가 다 들어갈 만큼. charH*scale 의
                      // 1.2배 여유 (모션 extent 포함). bottomCenter 라 위쪽 여백은 무해.
                      final slotH = layout.charH * layout.charScale * 1.2;
                      final left = 201.0 - slotW / 2; // frame 가로 중앙(201)에 정렬
                      final top = layout.charFeetY - slotH; // 슬롯 하단 = 발끝
                      return f.at(
                        x: left,
                        y: top,
                        w: slotW,
                        h: slotH,
                        child: const BrelowCharacterPanel(
                          alignment: Alignment.bottomCenter,
                        ),
                      );
                    }(),
                  ],
                );
              },
            ),
          ),
        ),

        // ─── (디버그 전용) 캐릭터 진화 테스트 버튼 ───────────────────
        // 누적 훈련일을 기다리지 않고 진화/happy/리셋을 즉시 트리거. 릴리즈
        // 빌드에는 포함되지 않음.
        if (kDebugMode)
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 0,
            right: 0,
            child: const Center(child: BrelowCharacterDebugBar()),
          ),

        // ─── 통계 카드 (362×194) — 화면 bottom 기준 ──────────────
        // dots 영역 (16 gap + 6 dot + 16 gap) 위에 카드를 둠 — 화면 어떤
        // 사이즈에서도 dots 가 nav bar 위에 보이고, 카드와 dots 사이 간격
        // Figma 와 동일 (16dp). bottomInset 으로 system nav bar 회피.
        // (기존 레이아웃 유지 — 절대 frame y 절대좌표로 바꾸지 말 것: 폰의
        //  system nav 영역에 dots 가 가려짐.)
        Positioned(
          left: f.sx(20),
          right: f.sx(20),
          bottom: bottomInset + f.sx(16 + 6 + 16),
          height: f.sx(194),
          child: _StatsCard(f: f, isDark: isDark),
        ),

        // ─── 페이지 indicator dots — system nav 위 16dp ───────────
        Positioned(
          left: 0,
          right: 0,
          bottom: bottomInset + f.sx(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: f.sx(6),
                height: f.sx(6),
                decoration: const BoxDecoration(
                  color: DotColors.primary,
                  shape: BoxShape.circle,
                ),
              ),
              SizedBox(width: f.sx(7)),
              Container(
                width: f.sx(6),
                height: f.sx(6),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.black26,
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
// 통계 카드
// ─────────────────────────────────────────────────────────────────────────────

class _StatsCard extends ConsumerWidget {
  const _StatsCard({required this.f, required this.isDark});
  final _Frame f;
  final bool isDark;

  // 일일 목표 — 30분. 향후 설정 화면에서 사용자 정의 가능하도록 SharedPreferences
  // 로 이전 가능. 한 cycle = 호기 10s + 호기쉼 3s + 흡기 10s + 흡기쉼 3s = 26s.
  static const _dailyGoalMinutes = 30;
  static const _cycleSeconds = 26;
  static const _phaseSeconds = 10; // 호기 또는 흡기 phase 만의 시간.

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cardBg = isDark ? DotColors.darkCard : DotColors.lightCard;
    final subCardBg = isDark ? DotColors.darkCardSoft : DotColors.lightCardSoft;
    final textPrimary =
        isDark ? DotColors.darkTextPrimary : DotColors.lightTextPrimary;
    final trackBg = isDark ? DotColors.darkTrack : DotColors.lightTrack;
    final percentColor = isDark ? DotColors.primaryAlt : textPrimary;

    // ─── 오늘 통계 계산 ───
    // todayDurationProvider 는 StreamProvider<Duration>. AsyncValue 의
    // valueOrNull 이 null 이면 (로딩) duration=0 으로 placeholder 표시.
    final today = ref.watch(todayDurationProvider).valueOrNull ?? Duration.zero;
    final cycleCount = today.inSeconds ~/ _cycleSeconds;
    // 호기/흡기 각 phase 의 실제 누적 분 — cycle 당 10s × cycleCount.
    final phaseMinutes = (cycleCount * _phaseSeconds) ~/ 60;
    // 일일 목표 대비 진행률 (0..100). 30분 도달 시 100%.
    final progressPct =
        ((today.inMinutes / _dailyGoalMinutes) * 100).clamp(0, 100).toInt();
    // Progress bar width — track 가로 320px 중 progressPct 비율.
    final progressBarWidth = (320.0 * progressPct / 100.0).clamp(19.0, 320.0);

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(f.sx(10)),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: const Color.fromRGBO(0, 0, 0, 0.06),
                  blurRadius: f.sx(16),
                  offset: Offset(0, f.sx(4)),
                ),
              ],
      ),
      child: Stack(
        children: [
          Positioned(
            left: f.sx(19),
            top: f.sx(17),
            child: Text(
              '오늘 총 몇 번 하셨어요!',
              style: TextStyle(
                fontSize: f.sx(17),
                fontWeight: FontWeight.w700,
                color: textPrimary,
                fontFamily: BlowfitTheme.fontFamily,
              ),
            ),
          ),
          Positioned(
            right: f.sx(21),
            top: f.sx(18),
            child: Text(
              '$progressPct%',
              style: TextStyle(
                fontSize: f.sx(17),
                fontWeight: FontWeight.w700,
                color: percentColor,
                fontFamily: BlowfitTheme.fontFamily,
              ),
            ),
          ),
          Positioned(
            left: f.sx(21),
            top: f.sx(43),
            child: Container(
              width: f.sx(320),
              height: f.sx(13),
              decoration: BoxDecoration(
                color: trackBg,
                borderRadius: BorderRadius.circular(f.sx(6.5)),
              ),
            ),
          ),
          Positioned(
            left: f.sx(21),
            top: f.sx(43),
            child: Container(
              width: f.sx(progressBarWidth),
              height: f.sx(13),
              decoration: BoxDecoration(
                color: DotColors.primary,
                borderRadius: BorderRadius.circular(f.sx(6.5)),
              ),
            ),
          ),
          Positioned(
            left: f.sx(21),
            top: f.sx(72),
            width: f.sx(155),
            height: f.sx(106),
            child: _BreathSubCard(
              f: f,
              label: '호기',
              count: '$cycleCount회',
              duration: '$phaseMinutes분',
              bg: subCardBg,
              textPrimary: textPrimary,
            ),
          ),
          Positioned(
            left: f.sx(186),
            top: f.sx(72),
            width: f.sx(155),
            height: f.sx(106),
            child: _BreathSubCard(
              f: f,
              label: '흡기',
              count: '$cycleCount회',
              duration: '$phaseMinutes분',
              bg: subCardBg,
              textPrimary: textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _BreathSubCard extends StatelessWidget {
  const _BreathSubCard({
    required this.f,
    required this.label,
    required this.count,
    required this.duration,
    required this.bg,
    required this.textPrimary,
  });
  final _Frame f;
  final String label;
  final String count;
  final String duration;
  final Color bg;
  final Color textPrimary;

  @override
  Widget build(BuildContext context) {
    // Figma sub-card 안 좌표 (sub-card top-left = 0,0):
    //   "호기" 라벨 : (14, 14), font 12 Medium
    //   "1회"     : (35, 41), font 30 Bold
    //   "00분"    : (85, 54), font 17 Medium
    // baseline-aligned (1회 bottom y=77, 00분 bottom y=74 — 거의 같음).
    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(f.sx(10)),
      ),
      child: Stack(
        children: [
          // 라벨 좌상단
          Positioned(
            left: f.sx(14),
            top: f.sx(14),
            child: Text(
              label,
              style: TextStyle(
                fontSize: f.sx(12),
                fontWeight: FontWeight.w500,
                color: textPrimary,
                fontFamily: BlowfitTheme.fontFamily,
              ),
            ),
          ),
          // 횟수 (30 Bold) + 분 (17 Medium) — baseline 정렬 Row.
          // 절대좌표 대신 Row 로 흘려서 "23회" 처럼 2자리수여도 "분" 과 안 겹침.
          Positioned(
            left: f.sx(35),
            top: f.sx(41),
            right: f.sx(8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  count,
                  style: TextStyle(
                    fontSize: f.sx(30),
                    fontWeight: FontWeight.w700,
                    color: textPrimary,
                    height: 1.0,
                    fontFamily: BlowfitTheme.fontFamily,
                  ),
                ),
                SizedBox(width: f.sx(5)),
                Text(
                  duration,
                  style: TextStyle(
                    fontSize: f.sx(17),
                    fontWeight: FontWeight.w500,
                    color: textPrimary,
                    height: 1.0,
                    fontFamily: BlowfitTheme.fontFamily,
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

// (말풍선 꼬리는 더 이상 CustomPainter 로 손수 그리지 않는다 — Figma 원본 벡터를
//  그대로 export 한 assets/dot/speech_tail.svg 를 SvgPicture 로 렌더한다.)

// ─────────────────────────────────────────────────────────────────────────────
// 지면 그림자 — Figma Ellipse 54 (layer-blur 타원).
//
// Figma 픽셀 분석:
//   - 중심 다크니스 ~37~40% (흰 배경 위 RGB 156,164,160 → 살짝 초록빛 어두운 회색)
//   - layer-blur 로 node box 대비 렌더가 가로 ~1.22×, 세로 ~1.90× 확장
//     (egg 233/188·94/49, oxy 260/216·93/49 → 가로 1.20~1.24, 세로 ~1.90 평균)
//   - 중심만 진하고 가장자리로 부드럽게 사라지는 가우시안형
//
// 재현: 슬롯(=node box) 중심에 RadialGradient(중심 0.40 → 가장자리 투명) 타원을
// box 대비 가로 1.22×·세로 1.90× 로 확대해 그린다. RadialGradient 가 비정방
// rect 에 매핑되며 타원형으로 늘어나 Figma 의 부드러운 falloff 를 그대로 재현.
// CustomPaint 는 clip 하지 않으므로 슬롯 밖으로 번져도 안전.
// ─────────────────────────────────────────────────────────────────────────────

class _GroundShadowPainter extends CustomPainter {
  const _GroundShadowPainter({required this.blurSigma});

  /// 가우시안 블러 강도 (화면 scale 반영). Figma layer-blur(~22px spread) 대응.
  final double blurSigma;

  @override
  void paint(Canvas canvas, Size size) {
    // node box 를 꽉 채운 평평한 타원 + 가우시안 블러 = Figma layer-blur 그림자
    // (평평한 타원이 darkest core, 블러가 사방 ~22px 로 부드럽게 퍼짐).
    // alpha 0.33 — 실기기 측정으로 Figma 다크니스(잔디 위 drop ~45)에 맞춤.
    final paint = Paint()
      ..color = const Color.fromRGBO(18, 38, 26, 0.33)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, blurSigma);
    canvas.drawOval(Offset.zero & size, paint);
  }

  @override
  bool shouldRepaint(_GroundShadowPainter old) => old.blurSigma != blurSigma;
}
