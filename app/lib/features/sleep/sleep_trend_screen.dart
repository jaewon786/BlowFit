// 수면 추이 화면 — 추이(Trend) 화면과 동일한 비주얼 스타일.
//   잔디/하늘 배경(추이와 동일 페인터) + 헤더(로고/토글/설정/알림) +
//   요약 카드(최저 혈중산소·수면점수·수면무호흡 징후) + 최저 SpO₂ 라인차트 +
//   하단 페이지 indicator(nav 위 고정).
// 데이터: sleep_records (로컬 DB). 화면 진입 시 sleepAutoSync 가 갤럭시 워치
//   → DB 로 하루 1회 자동 동기화하므로 실측 SpO₂/수면점수/무호흡이 반영된다.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../core/db/db_providers.dart';
import '../../core/db/trend_bucketing.dart';
import '../../core/health/sleep_analysis.dart';
import '../../core/theme/blowfit_colors.dart';
import '../../core/theme/blowfit_theme.dart';
import '../settings/settings_screen.dart';

const double _kFrameW = 402;

const _ink = Color(0xFF101010);
const _ink2 = Color(0xFF252525);
const _muted = Color(0xFF898989);

class _Frame {
  _Frame(this.screenW) : scale = screenW / _kFrameW;
  final double screenW;
  final double scale;
  double sx(double v) => v * scale;

  Positioned at({
    required double x,
    required double y,
    double? w,
    double? h,
    required Widget child,
  }) {
    return Positioned(
      left: sx(x),
      top: sx(y),
      width: w == null ? null : sx(w),
      height: h == null ? null : sx(h),
      child: child,
    );
  }
}

class SleepTrendScreen extends ConsumerStatefulWidget {
  const SleepTrendScreen({super.key});
  @override
  ConsumerState<SleepTrendScreen> createState() => _SleepTrendScreenState();
}

class _SleepTrendScreenState extends ConsumerState<SleepTrendScreen> {
  int _tabIndex = 0;

  /// 탭 index → TrendPeriod 매핑 (일간/주간/월간/년간).
  TrendPeriod get _period => TrendPeriod.values[_tabIndex];

  @override
  void initState() {
    super.initState();
    // 화면 진입 시 갤럭시 워치 → 로컬 DB 자동 동기화(하루 1회 throttle).
    // sync 가 DB 를 upsert 하면 recentSleepProvider 스트림이 자동 emit 하여
    // 화면이 실측 데이터로 rebuild 된다. fire-and-forget.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(sleepAutoSyncProvider).maybeSync();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = ref.watch(themeModeProvider) == ThemeMode.dark;
    final media = MediaQuery.of(context);
    final f = _Frame(media.size.width);
    final records = ref.watch(recentSleepProvider).valueOrNull ?? const [];
    final effect = computeSleepEffect(records);
    final buckets = bucketizeSpo2(records, _period);

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF030414) : const Color(0xFF4BA22B),
      body: Stack(
        children: [
          // 배경 — 전체 화면 (sky+잔디 / 다크 솔리드 #030414)
          Positioned.fill(
            child: LayoutBuilder(
              builder: (_, c) => CustomPaint(
                size: Size(c.maxWidth, c.maxHeight),
                painter: _SleepBgPainter(isDark: isDark),
              ),
            ),
          ),
          // 콘텐츠 (헤더 + 요약/차트 카드) — 상단 정렬.
          Positioned.fill(
            child: _content(
              context,
              f,
              effect,
              buckets,
              isDark,
            ),
          ),
          // 페이지 indicator — 갤럭시 nav 버튼 위 고정 (홈/추이처럼).
          Positioned(
            left: 0,
            right: 0,
            bottom: media.padding.bottom + f.sx(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < 3; i++) ...[
                  if (i > 0) SizedBox(width: f.sx(7)),
                  Container(
                    width: f.sx(6),
                    height: f.sx(6),
                    decoration: BoxDecoration(
                      color: i == 2
                          ? DotColors.primary
                          : (isDark ? Colors.white24 : Colors.black26),
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _content(
    BuildContext context,
    _Frame f,
    SleepEffect effect,
    List<Spo2Bucket> buckets,
    bool isDark,
  ) {
    final headline = _headline(effect);
    return Stack(
      children: [
        // 로고
        f.at(
          x: 17,
          y: 56,
          w: 81,
          h: 22,
          child: Image.asset(
            isDark ? 'assets/dot/logo_dark.png' : 'assets/dot/logo.png',
            fit: BoxFit.contain,
            filterQuality: FilterQuality.high,
          ),
        ),
        // 테마(라이트/다크) 토글 — 설정 좌측, hit 44×44
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
                color: isDark ? DotColors.darkTextPrimary : _ink,
              ),
            ),
          ),
        ),
        // 설정
        f.at(
          x: 308,
          y: 41,
          w: 44,
          h: 44,
          child: Builder(
            builder: (ctx) => GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => Navigator.of(ctx, rootNavigator: true).push(
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              ),
              child: Container(
                color: Colors.transparent,
                alignment: Alignment.center,
                child: SvgPicture.asset(
                  'assets/dot/icon_settings.svg',
                  width: f.sx(22),
                  height: f.sx(21),
                  colorFilter: ColorFilter.mode(
                    isDark ? DotColors.darkTextPrimary : _ink,
                    BlendMode.srcIn,
                  ),
                ),
              ),
            ),
          ),
        ),
        // 알림 종
        f.at(
          x: 354,
          y: 41,
          w: 44,
          h: 44,
          child: Center(
            child: SvgPicture.asset(
              'assets/dot/icon_bell.svg',
              width: f.sx(18),
              height: f.sx(20),
              colorFilter: ColorFilter.mode(
                isDark ? DotColors.darkTextPrimary : _ink,
                BlendMode.srcIn,
              ),
            ),
          ),
        ),
        // "수면 추이"
        f.at(
          x: 19,
          y: 105,
          child: Text(
            '수면 추이',
            style: TextStyle(
              fontSize: f.sx(15),
              fontWeight: FontWeight.w600,
              color: (isDark ? DotColors.darkTextPrimary : _ink)
                  .withValues(alpha: 0.7),
              fontFamily: BlowfitTheme.fontFamily,
            ),
          ),
        ),
        // 헤드라인
        f.at(
          x: 19,
          y: 127,
          w: 364,
          child: Text(
            headline,
            style: TextStyle(
              fontSize: f.sx(20),
              fontWeight: FontWeight.w700,
              color: isDark ? DotColors.darkTextPrimary : _ink,
              letterSpacing: -0.4,
              fontFamily: BlowfitTheme.fontFamily,
            ),
          ),
        ),
        // 요약 카드 — 최저 혈중산소 / 수면점수 / 수면무호흡 징후
        f.at(
          x: 20,
          y: 175,
          w: 362,
          h: 91,
          child: _SummaryCard(f: f, effect: effect, isDark: isDark),
        ),
        // 차트 카드 — 일간/주간/월간/년간 탭 + 최저 SpO₂ 추이.
        f.at(
          x: 20,
          y: 290,
          w: 362,
          h: 290,
          child: _Spo2TrendCard(
            f: f,
            buckets: buckets,
            isDark: isDark,
            tabIndex: _tabIndex,
            onTab: (i) => setState(() => _tabIndex = i),
          ),
        ),
        // 훈련 효과 카드 — 차트 아래. 장기(전 vs 최근) 수면 지표 변화.
        f.at(
          x: 20,
          y: 600,
          w: 362,
          h: 150,
          child: _TrainingCorrelationCard(
            f: f,
            effect: effect,
            isDark: isDark,
          ),
        ),
      ],
    );
  }

  String _headline(SleepEffect e) {
    final d = e.spo2MinDelta;
    if (e.nights == 0) return '수면 데이터를 모아볼까요?';
    if (d == null) return '수면을 꾸준히 기록해 봐요!';
    if (d >= 0.5) return '잠자는 동안 혈중 산소가 좋아지고 있어요!';
    if (d <= -0.5) return '잠자는 동안 혈중 산소가 조금 낮아졌어요';
    return '잠자는 동안 혈중 산소가 잘 유지되고 있어요';
  }
}

// ───────────────────────── 요약 카드 ─────────────────────────
class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.f,
    required this.effect,
    required this.isDark,
  });
  final _Frame f;
  final SleepEffect effect;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    // 가장 최근 밤(어젯밤) 실측값 기준 — 삼성헬스 표시와 일치. 데이터 없으면 '—'.
    // (recent* 는 최근 7박 평균이라 단일 밤 점수와 달라 혼동을 유발했음.)
    final spo2 = effect.latestSpo2Min;
    final score = effect.latestScore;
    final apnea = effect.apneaRecent;
    final spo2Str = spo2 != null ? '${spo2.round()}%' : '—';
    final scoreStr = score != null ? '$score점' : '—';
    final apneaStr =
        apnea == 'DETECTED' ? '있음' : (apnea == 'NOT_DETECTED' ? '없음' : '—');

    final dividerColor =
        isDark ? Colors.white.withValues(alpha: 0.12) : Colors.black12;
    return Container(
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF181836)
            : Colors.white.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(f.sx(10)),
      ),
      child: Stack(
        children: [
          Positioned(
            left: f.sx(127),
            top: f.sx(17),
            child: Container(width: 1, height: f.sx(58), color: dividerColor),
          ),
          Positioned(
            left: f.sx(238),
            top: f.sx(17),
            child: Container(width: 1, height: f.sx(58), color: dividerColor),
          ),
          _col(0, 127, '최저 혈중산소', spo2Str),
          _col(127, 238, '수면점수', scoreStr),
          _col(238, 362, '수면무호흡 징후', apneaStr),
        ],
      ),
    );
  }

  Widget _col(double l, double r, String label, String value) => Positioned(
        left: f.sx(l),
        width: f.sx(r - l),
        top: f.sx(20),
        child: Column(
          children: [
            // 라벨이 길어 폭을 넘으면 살짝 축소(줄바꿈 방지).
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                maxLines: 1,
                softWrap: false,
                style: TextStyle(
                  fontSize: f.sx(11),
                  fontWeight: FontWeight.w500,
                  color: isDark ? DotColors.darkTextPrimary : _ink,
                  fontFamily: BlowfitTheme.fontFamily,
                ),
              ),
            ),
            SizedBox(height: f.sx(5)),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                maxLines: 1,
                softWrap: false,
                style: TextStyle(
                  fontSize: f.sx(24),
                  fontWeight: FontWeight.w700,
                  color: isDark ? DotColors.darkTextPrimary : _ink,
                  fontFamily: BlowfitTheme.fontFamily,
                ),
              ),
            ),
          ],
        ),
      );
}

// ───────────────────────── 차트 카드 ─────────────────────────
class _Spo2TrendCard extends StatelessWidget {
  const _Spo2TrendCard({
    required this.f,
    required this.buckets,
    required this.isDark,
    required this.tabIndex,
    required this.onTab,
  });
  final _Frame f;
  final List<Spo2Bucket> buckets;
  final bool isDark;
  final int tabIndex;
  final ValueChanged<int> onTab;

  static const _tabs = ['일간', '주간', '월간', '년간'];
  static const _segW = 362.0 / 4; // 카드(362) 4등분 = 탭 1칸 폭
  static const _tabRowH = 34.0; // 탭 행 높이 (이 아래부터 차트 카드)

  @override
  Widget build(BuildContext context) {
    final allEmpty = buckets.every((b) => b.avgSpo2Min == null);
    final cardBg = isDark ? const Color(0xFF181836) : Colors.white;
    final inkColor = isDark ? DotColors.darkTextPrimary : _ink;
    // 카드 내부 세로 레이아웃: 탭 행(높이 ~32) → 그 아래 차트 영역.
    // 차트 영역은 card-local frame 좌표로 그리되, 탭 행 높이만큼 내려서 시작.
    return Stack(
      children: [
        // ── 선택 탭 박스 (folder tab) — 선택된 탭만 카드색 배경 (일반 추이와 동일) ──
        Positioned(
          left: f.sx(tabIndex * _segW),
          top: 0,
          width: f.sx(_segW),
          height: f.sx(_tabRowH + 10),
          child: Container(
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius:
                  BorderRadius.vertical(top: Radius.circular(f.sx(10))),
            ),
          ),
        ),
        // ── 차트 카드 (탭 행 아래) — 선택 탭과 union corner ──
        Positioned(
          left: 0,
          right: 0,
          top: f.sx(_tabRowH),
          bottom: 0,
          child: Container(
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.only(
                topLeft:
                    tabIndex == 0 ? Radius.zero : Radius.circular(f.sx(10)),
                topRight: tabIndex == _tabs.length - 1
                    ? Radius.zero
                    : Radius.circular(f.sx(10)),
                bottomLeft: Radius.circular(f.sx(10)),
                bottomRight: Radius.circular(f.sx(10)),
              ),
            ),
          ),
        ),
        // ── 탭 텍스트 4개 (각 세그먼트 중앙). 선택만 진하게. ──
        for (var i = 0; i < _tabs.length; i++)
          Positioned(
            left: f.sx(i * _segW),
            top: f.sx(10),
            width: f.sx(_segW),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => onTab(i),
              child: Container(
                alignment: Alignment.center,
                child: Text(
                  _tabs[i],
                  style: TextStyle(
                    fontSize: f.sx(13),
                    fontWeight:
                        i == tabIndex ? FontWeight.w700 : FontWeight.w500,
                    color: inkColor.withValues(
                      alpha: i == tabIndex ? 1.0 : 0.6,
                    ),
                    fontFamily: BlowfitTheme.fontFamily,
                  ),
                ),
              ),
            ),
          ),
        // ── legend (탭 행 아래) ──
        Positioned(
          left: f.sx(16),
          top: f.sx(50),
          child: Row(
            children: [
              Container(
                width: f.sx(9),
                height: f.sx(9),
                decoration: BoxDecoration(
                  color: DotColors.primary,
                  borderRadius: BorderRadius.circular(f.sx(1)),
                ),
              ),
              SizedBox(width: f.sx(6)),
              Text(
                '최저 SpO₂ (%)',
                style: TextStyle(
                  fontSize: f.sx(10),
                  fontWeight: FontWeight.w500,
                  color: isDark ? DotColors.darkTextSecondary : _ink2,
                  fontFamily: BlowfitTheme.fontFamily,
                ),
              ),
            ],
          ),
        ),
        // ── 차트 (탭 행 + legend 아래 영역) ──
        Positioned(
          left: 0,
          right: 0,
          top: f.sx(64),
          bottom: 0,
          child: CustomPaint(
            painter: _Spo2LinePainter(
              scale: f.scale,
              buckets: buckets,
              isDark: isDark,
            ),
          ),
        ),
        if (allEmpty)
          Positioned(
            left: 0,
            right: 0,
            top: f.sx(64),
            bottom: 0,
            child: Center(
              child: Text(
                'SpO₂ 데이터 없음',
                style: TextStyle(
                  fontSize: f.sx(12),
                  color: isDark ? DotColors.darkTextMuted : _muted,
                  fontFamily: BlowfitTheme.fontFamily,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _Spo2LinePainter extends CustomPainter {
  _Spo2LinePainter({
    required this.scale,
    required this.buckets,
    required this.isDark,
  });
  final double scale;
  final List<Spo2Bucket> buckets;
  final bool isDark;
  static const _yMin = 80.0, _yMax = 100.0;

  @override
  void paint(Canvas canvas, Size size) {
    final padL = size.width * 0.12;
    final padR = size.width * 0.05;
    final padT = size.height * 0.06;
    final padB = size.height * 0.20; // x축 라벨 공간 확보
    final plot =
        Rect.fromLTRB(padL, padT, size.width - padR, size.height - padB);

    double yFor(double v) =>
        plot.top +
        (_yMax - v.clamp(_yMin, _yMax)) / (_yMax - _yMin) * plot.height;

    // grid + Y labels (100/95/90/85/80)
    final grid = Paint()
      ..color = isDark
          ? Colors.white.withValues(alpha: 0.12)
          : _muted.withValues(alpha: 0.25)
      ..strokeWidth = 1;
    for (final v in const [100.0, 95.0, 90.0, 85.0, 80.0]) {
      final y = yFor(v);
      canvas.drawLine(Offset(plot.left, y), Offset(plot.right, y), grid);
      final tp = TextPainter(
        text: TextSpan(
          text: v.toStringAsFixed(0),
          style: TextStyle(
            color: isDark ? DotColors.darkTextMuted : _muted,
            fontSize: 8 * scale,
            fontFamily: BlowfitTheme.fontFamily,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(
        canvas,
        Offset(plot.left - tp.width - 4 * scale, y - tp.height / 2),
      );
    }

    final n = buckets.length;
    if (n == 0) return;
    // x 좌표 — 버킷 중심(xPos 1-based) 을 plot 폭에 균등 배치.
    double xFor(int xPos) =>
        plot.left + (n == 1 ? 0.5 : (xPos - 1) / (n - 1)) * plot.width;

    // x축 라벨 (모든 슬롯, 빈 버킷도 라벨은 그림).
    for (final b in buckets) {
      final tp = TextPainter(
        text: TextSpan(
          text: b.label,
          style: TextStyle(
            color: isDark ? DotColors.darkTextMuted : _muted,
            fontSize: 8 * scale,
            fontFamily: BlowfitTheme.fontFamily,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(
        canvas,
        Offset(
          xFor(b.xPos) - tp.width / 2,
          plot.bottom + 5 * scale,
        ),
      );
    }

    // line + dots — 값 있는(avgSpo2Min != null) 버킷만.
    final pts = <Offset>[];
    for (final b in buckets) {
      final v = b.avgSpo2Min;
      if (v == null) continue;
      pts.add(Offset(xFor(b.xPos), yFor(v)));
    }
    if (pts.isEmpty) return;
    if (pts.length > 1) {
      final line = Paint()
        ..color = DotColors.primary
        ..strokeWidth = 2 * scale
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;
      final path = Path()..moveTo(pts.first.dx, pts.first.dy);
      for (final p in pts.skip(1)) {
        path.lineTo(p.dx, p.dy);
      }
      canvas.drawPath(path, line);
    }
    final dot = Paint()..color = DotColors.primary;
    for (final p in pts) {
      canvas.drawCircle(p, 3 * scale, dot);
    }
  }

  @override
  bool shouldRepaint(_Spo2LinePainter old) =>
      old.buckets != buckets || old.isDark != isDark;
}

// ───────────────────────── 훈련 연관성 카드 ─────────────────────────
class _TrainingCorrelationCard extends StatelessWidget {
  const _TrainingCorrelationCard({
    required this.f,
    required this.effect,
    required this.isDark,
  });
  final _Frame f;
  final SleepEffect effect;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final inkColor = isDark ? DotColors.darkTextPrimary : _ink;
    final mutedColor = isDark ? DotColors.darkTextMuted : _muted;

    // 장기 효과 — 훈련 초반(처음 ~7박) vs 최근(~7박) 수면 지표 변화.
    // 같은 날 인과가 아니라 시차를 반영한 누적 효과(computeSleepEffect 재사용).
    final hasEffect = effect.nights >= 4;
    final apneaImproved = effect.apneaBaseline == 'DETECTED' &&
        effect.apneaRecent == 'NOT_DETECTED';

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF181836) : Colors.white,
        borderRadius: BorderRadius.circular(f.sx(10)),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: f.sx(16),
          vertical: f.sx(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '훈련 효과',
              style: TextStyle(
                fontSize: f.sx(13),
                fontWeight: FontWeight.w700,
                color: inkColor,
                fontFamily: BlowfitTheme.fontFamily,
              ),
            ),
            SizedBox(height: f.sx(2)),
            Text(
              '훈련 전 → 최근 변화',
              style: TextStyle(
                fontSize: f.sx(11),
                fontWeight: FontWeight.w500,
                color: mutedColor,
                fontFamily: BlowfitTheme.fontFamily,
              ),
            ),
            SizedBox(height: f.sx(10)),
            if (!hasEffect)
              Text(
                '수면 기록이 쌓이면 훈련 전·후 변화를 보여드려요.',
                style: TextStyle(
                  fontSize: f.sx(11),
                  color: mutedColor,
                  fontFamily: BlowfitTheme.fontFamily,
                ),
              )
            else ...[
              _EffectRow(
                f: f,
                label: '최저 혈중산소',
                base: _baStr(
                  effect.baselineSpo2Min,
                  effect.recentSpo2Min,
                  '%',
                ),
                delta: _deltaStr(effect.spo2MinDelta, '%p'),
                improved: (effect.spo2MinDelta ?? 0) > 0,
                inkColor: inkColor,
                mutedColor: mutedColor,
              ),
              SizedBox(height: f.sx(6)),
              _EffectRow(
                f: f,
                label: '수면 점수',
                base: _baStr(effect.baselineScore, effect.recentScore, ''),
                delta: _deltaStr(effect.scoreDelta, ''),
                improved: (effect.scoreDelta ?? 0) > 0,
                inkColor: inkColor,
                mutedColor: mutedColor,
              ),
              SizedBox(height: f.sx(6)),
              _EffectRow(
                f: f,
                label: '수면무호흡 징후',
                base: _apneaBaStr(effect.apneaBaseline, effect.apneaRecent),
                delta: apneaImproved ? '개선' : '',
                improved: apneaImproved,
                inkColor: inkColor,
                mutedColor: mutedColor,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// 장기 효과 한 줄 — 라벨 + "전 → 후" + 변화량(개선 시 강조).
class _EffectRow extends StatelessWidget {
  const _EffectRow({
    required this.f,
    required this.label,
    required this.base,
    required this.delta,
    required this.improved,
    required this.inkColor,
    required this.mutedColor,
  });
  final _Frame f;
  final String label;
  final String base;
  final String delta;
  final bool improved;
  final Color inkColor;
  final Color mutedColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: f.sx(11),
              fontWeight: FontWeight.w500,
              color: mutedColor,
              fontFamily: BlowfitTheme.fontFamily,
            ),
          ),
        ),
        Text(
          base,
          style: TextStyle(
            fontSize: f.sx(12),
            fontWeight: FontWeight.w700,
            color: inkColor,
            fontFamily: BlowfitTheme.fontFamily,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        if (delta.isNotEmpty) ...[
          SizedBox(width: f.sx(6)),
          Text(
            delta,
            style: TextStyle(
              fontSize: f.sx(11),
              fontWeight: FontWeight.w700,
              color: improved ? DotColors.primary : mutedColor,
              fontFamily: BlowfitTheme.fontFamily,
            ),
          ),
        ],
      ],
    );
  }
}

// 장기 효과 포맷 헬퍼.
String _baStr(double? b, double? r, String unit) {
  if (b == null || r == null) return '—';
  return '${b.round()}$unit → ${r.round()}$unit';
}

String _deltaStr(double? d, String unit) {
  if (d == null) return '';
  final n = d.round();
  if (n == 0) return '';
  return n > 0 ? '+$n$unit' : '$n$unit';
}

String _apneaLabel(String? s) =>
    s == 'DETECTED' ? '있음' : (s == 'NOT_DETECTED' ? '없음' : '—');

String _apneaBaStr(String? b, String? r) {
  if (b == null && r == null) return '기록 없음';
  return '${_apneaLabel(b)} → ${_apneaLabel(r)}';
}

// ───────────────────────── 배경 페인터 (추이와 동일) ─────────────────────────
class _SleepBgPainter extends CustomPainter {
  _SleepBgPainter({required this.isDark});
  final bool isDark;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final paint = Paint();

    if (isDark) {
      // 다크 모드 배경 — 추이 다크와 동일 단색 #030414.
      canvas.drawRect(rect, Paint()..color = const Color(0xFF030414));
      return;
    }

    // 라이트 — 하늘 그라데이션만. (잔디 ellipse 제거: 수면은 콘텐츠가 하단을 다
    // 못 덮어 블러 잔디가 보였고, 추이로 스와이프 시 초록 언덕이 깜빡였음. 추이의
    // 보이는 영역도 하늘이라, 하늘만 두면 전환이 매끄럽다.)
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
  }

  @override
  bool shouldRepaint(_SleepBgPainter old) => old.isDark != isDark;
}
