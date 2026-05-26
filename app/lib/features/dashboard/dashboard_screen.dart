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

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/ble/ble_providers.dart';
import '../../core/ble/blowfit_uuids.dart';
import '../../core/db/db_providers.dart';
import '../../core/storage/storage_providers.dart';
import '../../core/theme/blowfit_colors.dart';
import '../../core/theme/blowfit_theme.dart';
import '../settings/settings_screen.dart';

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
        canvas, scale, _e48Transform, _e48Width, _e48Height,
        _e48DarkColors, _e48DarkStops,
      );
      _drawEllipse(
        canvas, scale, _e47DarkTransform, _e47Width, _e47Height,
        _e47DarkColors, _e47DarkStops,
      );
      return;
    }

    // 라이트: 하늘 그라데이션 → 잔디 ellipse 두 개 (각각 gradient fill).
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

    // 48 먼저 (뒤) → 47 그 위에 그려서 47 이 시각적으로 앞쪽에 보이게.
    _drawEllipse(
      canvas, scale, _e48Transform, _e48Width, _e48Height,
      _e48Colors, _e48Stops,
    );
    _drawEllipse(
      canvas, scale, _e47Transform, _e47Width, _e47Height,
      _e47Colors, _e47Stops,
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
    final mascotAsset =
        isDark ? 'assets/dot/mascot_dark.png' : 'assets/dot/mascot.png';

    // 라이트: 검정 그대로, 다크: invert (흰색)
    final ColorFilter? invertFilter = isDark
        ? const ColorFilter.matrix([
            -1, 0, 0, 0, 255, //
            0, -1, 0, 0, 255, //
            0, 0, -1, 0, 255, //
            0, 0, 0, 1, 0, //
          ])
        : null;

    Widget buildIcon(String asset, double w, double h) {
      final img = Image.asset(asset, fit: BoxFit.contain);
      if (invertFilter == null) return img;
      return ColorFiltered(colorFilter: invertFilter, child: img);
    }

    return Stack(
      children: [
        // ─── 로고 (35×30 at 16,55) ────────────────────────────────
        f.at(x: 16, y: 55, w: 35, h: 30, child: buildIcon('assets/dot/logo.png', 35, 30)),

        // ─── 설정 아이콘 (28×28, hit 영역 60×60) ──────────────────
        f.at(
          x: 340,
          y: 35,
          w: 60,
          h: 60,
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
                child: SizedBox(
                  width: f.sx(28),
                  height: f.sx(28),
                  child: buildIcon(
                      'assets/dot/icon_settings.png', 28, 28),
                ),
              ),
            ),
          ),
        ),

        // ─── 알림 종 (20×19 at 320,60) ────────────────────────────
        f.at(
          x: 311,
          y: 53,
          w: 30,
          h: 30,
          child: buildIcon('assets/dot/icon_bell.png', 30, 30),
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
                  final store =
                      ref.watch(userProfileStoreProvider).valueOrNull;
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

        // ─── "얼마나 성장했어요!" (25 Bold at 19,133) ─────────────
        f.at(
          x: 19,
          y: 130,
          child: Text(
            '얼마나 성장했어요!',
            style: TextStyle(
              fontSize: f.sx(25),
              fontWeight: FontWeight.w700,
              letterSpacing: -0.5,
              height: 1.2,
              color: textPrimary,
              fontFamily: BlowfitTheme.fontFamily,
            ),
          ),
        ),

        // ─── "훈련하기" pill (93×43 at 289,114) — /training 으로 이동 ──
        f.at(
          x: 289,
          y: 114,
          w: 93,
          h: 43,
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
                  color:
                      isDark ? DotColors.darkCardSoft : DotColors.lightCtaBg,
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

        // ─── 마스코트 (216×183 at 93,345) ─────────────────────────
        f.at(
          x: 93,
          y: 345,
          w: 216,
          h: 183,
          child: Image.asset(mascotAsset, fit: BoxFit.contain),
        ),

        // ─── 통계 카드 (362×194) — 화면 bottom 기준 ──────────────
        // dots 영역 (16 gap + 6 dot + 16 gap) 위에 카드를 둠 — 화면 어떤
        // 사이즈에서도 dots 가 nav bar 위에 보이고, 카드와 dots 사이 간격
        // Figma 와 동일 (16dp). bottomInset 으로 system nav bar 회피.
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
    final subCardBg =
        isDark ? DotColors.darkCardSoft : DotColors.lightCardSoft;
    final textPrimary =
        isDark ? DotColors.darkTextPrimary : DotColors.lightTextPrimary;
    final trackBg = isDark ? DotColors.darkTrack : DotColors.lightTrack;
    final percentColor = isDark ? DotColors.primaryAlt : textPrimary;

    // ─── 오늘 통계 계산 ───
    // todayDurationProvider 는 StreamProvider<Duration>. AsyncValue 의
    // valueOrNull 이 null 이면 (로딩) duration=0 으로 placeholder 표시.
    final today =
        ref.watch(todayDurationProvider).valueOrNull ?? Duration.zero;
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
          // "1회" — 라벨보다 21px 안쪽 들여쓰기 (Figma 좌표 그대로)
          Positioned(
            left: f.sx(35),
            top: f.sx(41),
            child: Text(
              count,
              style: TextStyle(
                fontSize: f.sx(30),
                fontWeight: FontWeight.w700,
                color: textPrimary,
                height: 1.0,
                fontFamily: BlowfitTheme.fontFamily,
              ),
            ),
          ),
          // "00분" — "1회" 옆 baseline 정렬
          Positioned(
            left: f.sx(85),
            top: f.sx(54),
            child: Text(
              duration,
              style: TextStyle(
                fontSize: f.sx(17),
                fontWeight: FontWeight.w500,
                color: textPrimary,
                height: 1.0,
                fontFamily: BlowfitTheme.fontFamily,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
