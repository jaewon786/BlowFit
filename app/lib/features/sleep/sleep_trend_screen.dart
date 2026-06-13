// 수면 추이 화면 — 추이(Trend) 화면과 동일한 비주얼 스타일.
//   잔디/하늘 배경(추이와 동일 페인터) + 헤더(로고/토글/설정/알림) +
//   요약 카드(최저 혈중산소·수면점수·수면무호흡 징후) + 최저 SpO₂ 라인차트 +
//   하단 페이지 indicator(nav 위 고정).
// 데이터: sleep_records (실측, 없으면 데모 시드).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../core/db/app_database.dart';
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
  Widget build(BuildContext context) {
    final isDark = ref.watch(themeModeProvider) == ThemeMode.dark;
    final media = MediaQuery.of(context);
    final f = _Frame(media.size.width);
    final records = ref.watch(recentSleepProvider).valueOrNull ?? const [];
    final sorted = [...records]..sort((a, b) => a.night.compareTo(b.night));
    final effect = computeSleepEffect(records);
    final buckets = bucketizeSpo2(records, _period);
    final trainedDates =
        ref.watch(trainedDatesProvider).valueOrNull ?? const <DateTime>{};

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
              sorted,
              effect,
              buckets,
              trainedDates,
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
    List<SleepRecord> sorted,
    SleepEffect effect,
    List<Spo2Bucket> buckets,
    Set<DateTime> trainedDates,
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
        // 훈련 연관성 카드 — 차트 아래.
        f.at(
          x: 20,
          y: 600,
          w: 362,
          h: 150,
          child: _TrainingCorrelationCard(
            f: f,
            records: sorted,
            trainedDates: trainedDates,
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
    // 최근 측정값 기준. 데이터 없으면 '—'.
    final spo2 = effect.recentSpo2Min;
    final score = effect.recentScore;
    final apnea = effect.apneaRecent;
    final spo2Str = spo2 != null ? '${spo2.round()}%' : '—';
    final scoreStr = score != null ? '${score.round()}점' : '—';
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

  @override
  Widget build(BuildContext context) {
    final allEmpty = buckets.every((b) => b.avgSpo2Min == null);
    // 카드 내부 세로 레이아웃: 탭 행(높이 ~32) → 그 아래 차트 영역.
    // 차트 영역은 card-local frame 좌표로 그리되, 탭 행 높이만큼 내려서 시작.
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF181836) : Colors.white,
        borderRadius: BorderRadius.circular(f.sx(10)),
      ),
      child: Stack(
        children: [
          // ── 탭 행 (일간/주간/월간/년간) — 카드 상단, 4등분 균등 배치 ──
          Positioned(
            left: 0,
            right: 0,
            top: f.sx(12),
            child: Row(
              children: [
                for (var i = 0; i < _tabs.length; i++)
                  Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => onTab(i),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _tabs[i],
                            style: TextStyle(
                              fontSize: f.sx(13),
                              fontWeight: i == tabIndex
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color: i == tabIndex
                                  ? DotColors.primary
                                  : (isDark ? DotColors.darkTextMuted : _muted),
                              fontFamily: BlowfitTheme.fontFamily,
                            ),
                          ),
                          SizedBox(height: f.sx(5)),
                          // active indicator (pill)
                          Container(
                            width: f.sx(20),
                            height: f.sx(2.5),
                            decoration: BoxDecoration(
                              color: i == tabIndex
                                  ? DotColors.primary
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(f.sx(2)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
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
      ),
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
    required this.records,
    required this.trainedDates,
    required this.isDark,
  });
  final _Frame f;
  final List<SleepRecord> records; // asc
  final Set<DateTime> trainedDates;
  final bool isDark;

  bool _isTrained(SleepRecord r) =>
      trainedDates.contains(DateTime(r.night.year, r.night.month, r.night.day));

  @override
  Widget build(BuildContext context) {
    final cmp = compareTrainingSpo2(records, trainedDates);
    final inkColor = isDark ? DotColors.darkTextPrimary : _ink;
    final mutedColor = isDark ? DotColors.darkTextMuted : _muted;
    final trainedStr =
        cmp.trainedAvg != null ? '${cmp.trainedAvg!.round()}%' : '—';
    final untrainedStr =
        cmp.untrainedAvg != null ? '${cmp.untrainedAvg!.round()}%' : '—';

    // 최근 ~14박 (오래→최신, 왼→오른쪽). records 는 asc 정렬.
    final recent =
        records.length > 14 ? records.sublist(records.length - 14) : records;

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
            // 타이틀
            Text(
              '훈련과 수면',
              style: TextStyle(
                fontSize: f.sx(13),
                fontWeight: FontWeight.w700,
                color: inkColor,
                fontFamily: BlowfitTheme.fontFamily,
              ),
            ),
            SizedBox(height: f.sx(10)),
            // 평균 비교 한 줄
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  '훈련한 날 평균 최저 산소  ',
                  style: TextStyle(
                    fontSize: f.sx(11),
                    fontWeight: FontWeight.w500,
                    color: mutedColor,
                    fontFamily: BlowfitTheme.fontFamily,
                  ),
                ),
                Text(
                  trainedStr,
                  style: TextStyle(
                    fontSize: f.sx(13),
                    fontWeight: FontWeight.w700,
                    color: DotColors.primary,
                    fontFamily: BlowfitTheme.fontFamily,
                  ),
                ),
                Text(
                  '   ·   안 한 날  ',
                  style: TextStyle(
                    fontSize: f.sx(11),
                    fontWeight: FontWeight.w500,
                    color: mutedColor,
                    fontFamily: BlowfitTheme.fontFamily,
                  ),
                ),
                Text(
                  untrainedStr,
                  style: TextStyle(
                    fontSize: f.sx(13),
                    fontWeight: FontWeight.w700,
                    color: mutedColor,
                    fontFamily: BlowfitTheme.fontFamily,
                  ),
                ),
              ],
            ),
            SizedBox(height: f.sx(12)),
            // 일별 훈련 띠 (strip) — 최근 ~14박.
            if (recent.isEmpty)
              Text(
                '최근 수면 기록이 없어요',
                style: TextStyle(
                  fontSize: f.sx(11),
                  color: mutedColor,
                  fontFamily: BlowfitTheme.fontFamily,
                ),
              )
            else
              Row(
                children: [
                  for (var i = 0; i < recent.length; i++) ...[
                    if (i > 0) SizedBox(width: f.sx(5)),
                    _DayCell(
                      f: f,
                      trained: _isTrained(recent[i]),
                      isDark: isDark,
                    ),
                  ],
                ],
              ),
            SizedBox(height: f.sx(10)),
            // legend
            Text(
              '● 훈련함  ○ 안 함',
              style: TextStyle(
                fontSize: f.sx(10),
                fontWeight: FontWeight.w500,
                color: mutedColor,
                fontFamily: BlowfitTheme.fontFamily,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.f,
    required this.trained,
    required this.isDark,
  });
  final _Frame f;
  final bool trained;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final hollow = isDark ? Colors.white24 : Colors.black12;
    return Container(
      width: f.sx(14),
      height: f.sx(14),
      decoration: BoxDecoration(
        color: trained ? DotColors.primary : hollow,
        borderRadius: BorderRadius.circular(f.sx(4)),
      ),
    );
  }
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
