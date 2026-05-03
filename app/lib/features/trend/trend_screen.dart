import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/coach/milestone_engine.dart';
import '../../core/db/db_providers.dart';
import '../../core/db/trend_bucketing.dart';
import '../../core/theme/blowfit_colors.dart';
import '../../core/theme/blowfit_widgets.dart';

/// 진행 추이 화면. 디자인 시안의 08 화면.
///
/// 4개 탭 — 일간 (이번 주 월~일) / 주간 (이번 달 1~4주) / 월간 (최근 4개월) /
/// 년간 (올해 1~12월). 기본은 일간.
///
/// Z안 적용 — 활성 데이터 < 2 면 변화율 숨김, 활성 데이터 0 이면 empty state.
class TrendScreen extends ConsumerStatefulWidget {
  const TrendScreen({super.key});

  @override
  ConsumerState<TrendScreen> createState() => _TrendScreenState();
}

class _TrendScreenState extends ConsumerState<TrendScreen> {
  // 기본은 일간 (index 0).
  int _periodIndex = 0;
  static const _periods = ['일간', '주간', '월간', '년간'];
  static const _periodValues = TrendPeriod.values;

  @override
  Widget build(BuildContext context) {
    final period = _periodValues[_periodIndex];
    final bucketsAsync = ref.watch(trendBucketsProvider(period));
    final milestonesAsync = ref.watch(milestonesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('진행 추이'),
      ),
      body: SafeArea(
        child: bucketsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) =>
              const Center(child: Text('추이를 불러올 수 없습니다.')),
          data: (buckets) {
            final active =
                buckets.where((b) => !b.isEmpty).toList(growable: false);
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
              children: [
                _PeriodTabs(
                  labels: _periods,
                  selected: _periodIndex,
                  onSelect: (i) => setState(() => _periodIndex = i),
                ),
                const SizedBox(height: 14),
                if (active.isEmpty)
                  const _EmptyTrendCard()
                else
                  _HeroChart(
                    buckets: buckets,
                    active: active,
                    period: period,
                  ),
                if (active.length >= 2) ...[
                  const SizedBox(height: 12),
                  _DirectionGrid(
                    exhaleFrom: active.first.avgExhale!,
                    exhaleTo: active.last.avgExhale!,
                  ),
                ],
                const SizedBox(height: 14),
                _MilestonesCard(
                  milestones: milestonesAsync.valueOrNull ?? const [],
                  loading: milestonesAsync.isLoading,
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
// Empty state — 세션 0개일 때
// ---------------------------------------------------------------------------

class _EmptyTrendCard extends StatelessWidget {
  const _EmptyTrendCard();

  @override
  Widget build(BuildContext context) {
    return BlowfitCard(
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 28),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: BlowfitColors.blue50,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.show_chart,
                color: BlowfitColors.blue500, size: 28),
          ),
          const SizedBox(height: 14),
          const Text(
            '아직 추이를 그릴 데이터가 없어요',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: BlowfitColors.ink,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            '첫 훈련을 완료하면\n주간 평균 호기 압력이 여기에 그려져요.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: BlowfitColors.ink3,
              height: 1.5,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Period tab segment
// ---------------------------------------------------------------------------

class _PeriodTabs extends StatelessWidget {
  const _PeriodTabs({
    required this.labels,
    required this.selected,
    required this.onSelect,
  });

  final List<String> labels;
  final int selected;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: BlowfitColors.gray100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++) ...[
            if (i > 0) const SizedBox(width: 4),
            Expanded(
              child: _PeriodTab(
                label: labels[i],
                selected: i == selected,
                onTap: () => onSelect(i),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PeriodTab extends StatelessWidget {
  const _PeriodTab({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // ClipRRect 로 splash 가 옆 탭으로 새지 않게 강제. selected 든 아니든
    // 탭하면 InkWell 의 splash + highlight 가 보이도록 명시적 색 지정.
    return ClipRRect(
      borderRadius: BorderRadius.circular(9),
      child: Container(
        decoration: BoxDecoration(
          color: selected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(9),
          boxShadow: selected ? BlowfitColors.shadowLevel1 : null,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            // selected 시 흰 배경 위에서도 보이도록 살짝 진한 splash.
            splashColor: selected
                ? BlowfitColors.blue500.withValues(alpha: 0.12)
                : BlowfitColors.blue500.withValues(alpha: 0.10),
            highlightColor: selected
                ? BlowfitColors.blue500.withValues(alpha: 0.06)
                : BlowfitColors.blue500.withValues(alpha: 0.04),
            child: SizedBox(
              height: double.infinity,
              child: Center(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color:
                        selected ? BlowfitColors.ink : BlowfitColors.ink3,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Hero chart — bidirectional line chart (호기 above 0, 흡기 below)
// ---------------------------------------------------------------------------

class _HeroChart extends StatelessWidget {
  const _HeroChart({
    required this.buckets,
    required this.active,
    required this.period,
  });

  /// 모든 자리 (빈 자리 포함). 일간=7, 주간=4, 월간=4, 년간=12.
  final List<TrendBucket> buckets;

  /// 빈 자리 제외 — pct 계산용.
  final List<TrendBucket> active;

  final TrendPeriod period;

  static const _exhaleColor = BlowfitColors.blue500;
  static const _inhaleColor = Color(0xFF0099CC);

  /// 활성 데이터 < 2 면 변화율 계산 불가 (Z안).
  int? get _improvementPct {
    if (active.length < 2) return null;
    final first = active.first.avgExhale;
    final last = active.last.avgExhale;
    if (first == null || last == null || first <= 0) return null;
    return ((last - first) / first * 100).round();
  }

  /// 헤더 카피 — B안 통일.
  String get _heroTitle {
    switch (period) {
      case TrendPeriod.daily:
        return '일간 추이';
      case TrendPeriod.weekly:
        return '주간 추이';
      case TrendPeriod.monthly:
        return '월간 추이';
      case TrendPeriod.yearly:
        return '년간 추이';
    }
  }

  /// x 축 메이저 tick 간격.
  double get _xInterval => 1;

  /// 차트 좌우 여백 — 첫 점과 마지막 점이 가장자리에 붙지 않도록.
  /// 월간 (12개) 은 자리 많아 여유 적게, 나머지는 여유 충분히.
  double get _xPadding {
    switch (period) {
      case TrendPeriod.daily:
      case TrendPeriod.weekly:
      case TrendPeriod.yearly:
        return 0.4;
      case TrendPeriod.monthly:
        return 0.15;
    }
  }

  double get _chartMinX => 1 - _xPadding;
  double get _chartMaxX => buckets.length + _xPadding;

  /// 변화율 라벨 — 모든 윈도우에서 첫 활성 자리 기준으로 동적.
  /// 사용자가 화요일부터 훈련했으면 "화요일 대비", 2주차부터면 "2주차 대비".
  /// 변화율은 active.length >= 2 일 때만 호출되니 active 비어있는 경우 없음.
  String get _deltaLabel {
    if (active.isEmpty) return '시작 시점 대비'; // safety net
    final firstLabel = active.first.label;
    switch (period) {
      case TrendPeriod.daily:
        // "월" → "월요일 대비"
        return '$firstLabel요일 대비';
      case TrendPeriod.weekly:
        // "1주" → "1주차 대비"
        return '$firstLabel차 대비';
      case TrendPeriod.monthly:
        // "1월" → "1월 대비"
        return '$firstLabel 대비';
      case TrendPeriod.yearly:
        // "2024" → "2024년 대비"
        return '$firstLabel년 대비';
    }
  }

  /// 라벨 lookup — xPos → label.
  String _labelAt(int xPos) {
    final b = buckets.firstWhere(
      (b) => b.xPos == xPos,
      orElse: () => TrendBucket(
        xPos: xPos,
        label: '',
        avgExhale: null,
        maxExhale: null,
        sessionCount: 0,
        bucketStart: DateTime(0),
      ),
    );
    return b.label;
  }

  @override
  Widget build(BuildContext context) {
    final pct = _improvementPct;
    // 차트 점은 bucket.xPos 를 x 좌표로. 빈 자리는 점 없음 (line 끊어짐).
    final exhaleSpots = <FlSpot>[];
    for (final b in buckets) {
      final v = b.avgExhale;
      if (v != null) exhaleSpots.add(FlSpot(b.xPos.toDouble(), v));
    }

    return BlowfitCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _heroTitle,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: BlowfitColors.ink3,
            ),
          ),
          const SizedBox(height: 4),
          // 변화율은 활성 데이터 >= 2 일 때만 표시. 미달 시 자리만 약간 비움.
          if (pct != null)
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  pct >= 0 ? '+$pct%' : '$pct%',
                  style: const TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.9,
                    color: BlowfitColors.ink,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(width: 8),
                Row(
                  children: [
                    Icon(
                      pct >= 0 ? Icons.arrow_upward : Icons.arrow_downward,
                      size: 11,
                      color: pct >= 0
                          ? BlowfitColors.green500
                          : BlowfitColors.red500,
                    ),
                    const SizedBox(width: 2),
                    Text(
                      _deltaLabel,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: pct >= 0
                            ? BlowfitColors.green500
                            : BlowfitColors.red500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          const SizedBox(height: 14),
          const Row(
            children: [
              _Legend(color: _exhaleColor, label: '호기 평균'),
              SizedBox(width: 14),
              _Legend(color: _inhaleColor, label: '흡기 평균'),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 200,
            child: LineChart(
              LineChartData(
                minX: _chartMinX,
                maxX: _chartMaxX,
                minY: -30,
                maxY: 30,
                clipData: const FlClipData.all(),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: 10,
                  getDrawingHorizontalLine: (v) => FlLine(
                    color: v.abs() < 0.01
                        ? BlowfitColors.gray400
                        : BlowfitColors.gray150,
                    strokeWidth: v.abs() < 0.01 ? 1.2 : 1,
                  ),
                ),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 32,
                      interval: 10,
                      getTitlesWidget: (v, meta) {
                        final n = v.round();
                        final label = n > 0 ? '+$n' : '$n';
                        return Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: Text(
                            label,
                            textAlign: TextAlign.right,
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
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 22,
                      interval: _xInterval,
                      getTitlesWidget: (v, meta) {
                        final xPos = v.round();
                        if (xPos < 1 || xPos > buckets.length) {
                          return const SizedBox.shrink();
                        }
                        // 정수 좌표에만 라벨 — 비정수 (interpolation) 은 무시.
                        if ((v - xPos).abs() > 0.001) {
                          return const SizedBox.shrink();
                        }
                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            _labelAt(xPos),
                            style: const TextStyle(
                              fontSize: 10,
                              color: BlowfitColors.ink3,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                lineBarsData: [
                  _line(exhaleSpots, _exhaleColor),
                  // 흡기는 하드웨어 미지원 — 차후 차압 센서 도입 시 활성화.
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  LineChartBarData _line(List<FlSpot> spots, Color color) {
    // 디자인 v2 의 trend-profile.jsx 는 SVG 마지막 점만 circle 로 그림
    // (`<circle cx={xScale(data.length-1)} ...>`). 우리도 가장 최근 데이터
    // 포인트에만 dot 을 표시 — 12주의 모든 주에 점이 찍히지 않도록.
    return LineChartBarData(
      spots: spots,
      isCurved: spots.length >= 3, // 점 2개 이하는 직선 (curve 가 wobble 함)
      curveSmoothness: 0.3,
      preventCurveOverShooting: true,
      color: color,
      barWidth: 2.5,
      dotData: FlDotData(
        show: spots.isNotEmpty,
        checkToShowDot: (spot, bar) =>
            spot == bar.spots.last,
        getDotPainter: (spot, _, __, ___) => FlDotCirclePainter(
          radius: 4,
          color: color,
          strokeWidth: 2,
          strokeColor: Colors.white,
        ),
      ),
      belowBarData: BarAreaData(
        show: true,
        color: color.withValues(alpha: 0.06),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: BlowfitColors.ink2,
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// 2x1 direction summary cards
// ---------------------------------------------------------------------------

class _DirectionGrid extends StatelessWidget {
  const _DirectionGrid({
    required this.exhaleFrom,
    required this.exhaleTo,
  });

  /// 활성 첫 주 / 마지막 주 호기 평균. activeWeeks.length >= 2 일 때만 호출됨.
  final double exhaleFrom;
  final double exhaleTo;

  int _delta(double from, double to) {
    if (from <= 0) return 0;
    return ((to - from) / from * 100).round();
  }

  @override
  Widget build(BuildContext context) {
    // IntrinsicHeight + stretch — 두 카드의 높이를 호기 (긴 쪽) 기준으로 통일.
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _DirectionCard(
              label: '호기 (내쉬기)',
              color: BlowfitColors.blue500,
              from: exhaleFrom,
              to: exhaleTo,
              deltaPct: _delta(exhaleFrom, exhaleTo),
            ),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: _PlaceholderDirectionCard(
              label: '흡기 (들이쉬기)',
              color: Color(0xFF0099CC),
            ),
          ),
        ],
      ),
    );
  }
}

/// 흡기 카드 — 하드웨어 미지원 placeholder.
class _PlaceholderDirectionCard extends StatelessWidget {
  const _PlaceholderDirectionCard({
    required this.label,
    required this.color,
  });
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return BlowfitCard(
      padding: const EdgeInsets.all(14),
      // 박스 높이는 부모의 IntrinsicHeight 가 호기 카드에 맞춰 늘려줌.
      // 내부 "—" 는 가운데 정렬로 자연스럽게 배치.
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: BlowfitColors.ink2,
                ),
              ),
            ],
          ),
          // 단일 "—" 를 남은 공간 가운데에 둠.
          const Expanded(
            child: Center(
              child: Text(
                '—',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: BlowfitColors.gray400,
                  letterSpacing: -0.44,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DirectionCard extends StatelessWidget {
  const _DirectionCard({
    required this.label,
    required this.color,
    required this.from,
    required this.to,
    required this.deltaPct,
  });

  final String label;
  final Color color;
  final double from;
  final double to;
  final int deltaPct;

  @override
  Widget build(BuildContext context) {
    return BlowfitCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: BlowfitColors.ink2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                from.toStringAsFixed(1),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: BlowfitColors.ink3,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.arrow_forward,
                  size: 12, color: BlowfitColors.ink3),
              const SizedBox(width: 4),
              Text(
                to.toStringAsFixed(1),
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: color,
                  letterSpacing: -0.44,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          // 양수 → 초록 ↑, 음수 → 빨강 ↓, 0 → 회색.
          Builder(builder: (_) {
            final positive = deltaPct > 0;
            final negative = deltaPct < 0;
            final pctColor = positive
                ? BlowfitColors.green500
                : negative
                    ? BlowfitColors.red500
                    : BlowfitColors.ink3;
            final sign = positive ? '+' : ''; // 음수는 toString 에 '-' 포함
            return Row(
              children: [
                if (positive)
                  Icon(Icons.arrow_upward, size: 11, color: pctColor)
                else if (negative)
                  Icon(Icons.arrow_downward, size: 11, color: pctColor),
                if (positive || negative) const SizedBox(width: 2),
                Text(
                  '$sign$deltaPct%',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: pctColor,
                  ),
                ),
              ],
            );
          }),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Milestones card
// ---------------------------------------------------------------------------

class _MilestonesCard extends StatelessWidget {
  const _MilestonesCard({required this.milestones, required this.loading});

  final List<Milestone> milestones;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return BlowfitCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '마일스톤',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: BlowfitColors.ink,
            ),
          ),
          const SizedBox(height: 12),
          if (loading && milestones.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else
            for (var i = 0; i < milestones.length; i++) ...[
              if (i > 0) const Divider(height: 1, color: BlowfitColors.gray150),
              _MilestoneRow(milestone: milestones[i]),
            ],
        ],
      ),
    );
  }
}

class _MilestoneRow extends StatelessWidget {
  const _MilestoneRow({required this.milestone});
  final Milestone milestone;

  /// 미달성 + 진행 중 케이스만 별도 라벨; 그 외 미달성은 '—'.
  String _dateLabel() {
    final at = milestone.achievedAt;
    if (at != null) return DateFormat('M월 d일', 'ko').format(at);
    if (milestone.kind == MilestoneKind.thirtyDayStreak) return '진행 중';
    return '—';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: milestone.achieved
                  ? BlowfitColors.green100
                  : BlowfitColors.gray100,
              shape: BoxShape.circle,
            ),
            child: Icon(
              milestone.achieved ? Icons.check : Icons.emoji_events,
              size: milestone.achieved ? 16 : 14,
              color: milestone.achieved
                  ? BlowfitColors.greenInk
                  : BlowfitColors.gray400,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              milestone.title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: milestone.achieved
                    ? BlowfitColors.ink
                    : BlowfitColors.ink2,
              ),
            ),
          ),
          Text(
            _dateLabel(),
            style: const TextStyle(
              fontSize: 12,
              color: BlowfitColors.ink3,
            ),
          ),
        ],
      ),
    );
  }
}
