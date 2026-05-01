import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/blowfit_colors.dart';
import '../../core/theme/blowfit_widgets.dart';

/// 12주 호기/흡기 압력 추이 화면. 디자인 시안의 08 화면.
///
/// 현재는 디자인 prototype 의 placeholder 데이터로 그래프 모양과 레이아웃을
/// 검증한다. 실제 운용 단계에선 `weekly_summary` 같은 집계 provider 와 연결.
class TrendScreen extends ConsumerStatefulWidget {
  const TrendScreen({super.key});

  @override
  ConsumerState<TrendScreen> createState() => _TrendScreenState();
}

class _TrendScreenState extends ConsumerState<TrendScreen> {
  // 현재 디자인은 4개 탭 (주간/월간/12주/전체) — 하단 동작은 추후. 12주 고정.
  int _periodIndex = 2;
  static const _periods = ['주간', '월간', '12주', '전체'];

  // 12주 placeholder 데이터 — 실제 구현 시 SessionRepository 의 주간 평균
  // 집계로 대체.
  static const _weeks = <_WeekPoint>[
    _WeekPoint(week: 1, exhale: 16.2, inhale: -14.0),
    _WeekPoint(week: 2, exhale: 17.0, inhale: -14.6),
    _WeekPoint(week: 3, exhale: 17.8, inhale: -15.3),
    _WeekPoint(week: 4, exhale: 18.4, inhale: -16.1),
    _WeekPoint(week: 5, exhale: 18.9, inhale: -16.8),
    _WeekPoint(week: 6, exhale: 19.6, inhale: -17.4),
    _WeekPoint(week: 7, exhale: 20.1, inhale: -18.0),
    _WeekPoint(week: 8, exhale: 20.8, inhale: -18.7),
    _WeekPoint(week: 9, exhale: 21.4, inhale: -19.3),
    _WeekPoint(week: 10, exhale: 22.0, inhale: -19.9),
    _WeekPoint(week: 11, exhale: 22.7, inhale: -20.6),
    _WeekPoint(week: 12, exhale: 23.4, inhale: -21.2),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('진행 추이'),
        actions: [
          TextButton(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('내보내기 기능은 곧 출시됩니다')),
              );
            },
            child: const Text(
              '내보내기',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: BlowfitColors.blue500,
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          children: [
            _PeriodTabs(
              labels: _periods,
              selected: _periodIndex,
              onSelect: (i) => setState(() => _periodIndex = i),
            ),
            const SizedBox(height: 14),
            _HeroChart(weeks: _weeks),
            const SizedBox(height: 12),
            _DirectionGrid(
              exhaleFrom: _weeks.first.exhale,
              exhaleTo: _weeks.last.exhale,
              inhaleFrom: _weeks.first.inhale.abs(),
              inhaleTo: _weeks.last.inhale.abs(),
            ),
            const SizedBox(height: 14),
            const _MilestonesCard(),
          ],
        ),
      ),
    );
  }
}

class _WeekPoint {
  const _WeekPoint({
    required this.week,
    required this.exhale,
    required this.inhale,
  });
  final int week;
  final double exhale;
  final double inhale;
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
          for (var i = 0; i < labels.length; i++)
            Expanded(
              child: _PeriodTab(
                label: labels[i],
                selected: i == selected,
                onTap: () => onSelect(i),
              ),
            ),
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
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(9),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          decoration: BoxDecoration(
            color: selected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
            boxShadow: selected ? BlowfitColors.shadowLevel1 : null,
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: selected ? BlowfitColors.ink : BlowfitColors.ink3,
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
  const _HeroChart({required this.weeks});
  final List<_WeekPoint> weeks;

  static const _exhaleColor = BlowfitColors.blue500;
  static const _inhaleColor = Color(0xFF0099CC);

  double get _improvementPct {
    if (weeks.length < 2) return 0;
    final first = weeks.first.exhale;
    final last = weeks.last.exhale;
    if (first <= 0) return 0;
    return ((last - first) / first * 100);
  }

  @override
  Widget build(BuildContext context) {
    final pct = _improvementPct.round();
    final exhaleSpots =
        weeks.map((w) => FlSpot(w.week.toDouble(), w.exhale)).toList();
    final inhaleSpots =
        weeks.map((w) => FlSpot(w.week.toDouble(), w.inhale)).toList();

    return BlowfitCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '12주간 호흡근 강화',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: BlowfitColors.ink3,
            ),
          ),
          const SizedBox(height: 4),
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
                    '시작 시점 대비',
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
                minX: 1,
                maxX: 12,
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
                      interval: 2,
                      getTitlesWidget: (v, meta) {
                        final w = v.round();
                        if (w < 1 || w > 12) return const SizedBox.shrink();
                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            '${w}w',
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
                ),
                lineBarsData: [
                  _line(exhaleSpots, _exhaleColor),
                  _line(inhaleSpots, _inhaleColor),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  LineChartBarData _line(List<FlSpot> spots, Color color) {
    return LineChartBarData(
      spots: spots,
      isCurved: true,
      curveSmoothness: 0.3,
      preventCurveOverShooting: true,
      color: color,
      barWidth: 2.5,
      dotData: FlDotData(
        show: true,
        getDotPainter: (spot, _, __, ___) => FlDotCirclePainter(
          radius: 3,
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
    required this.inhaleFrom,
    required this.inhaleTo,
  });

  final double exhaleFrom;
  final double exhaleTo;
  final double inhaleFrom;
  final double inhaleTo;

  int _delta(double from, double to) {
    if (from <= 0) return 0;
    return ((to - from) / from * 100).round();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
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
        Expanded(
          child: _DirectionCard(
            label: '흡기 (들이쉬기)',
            color: const Color(0xFF0099CC),
            from: inhaleFrom,
            to: inhaleTo,
            deltaPct: _delta(inhaleFrom, inhaleTo),
          ),
        ),
      ],
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
          Text(
            '+$deltaPct%',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: BlowfitColors.green500,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Milestones card
// ---------------------------------------------------------------------------

class _MilestonesCard extends StatelessWidget {
  const _MilestonesCard();

  @override
  Widget build(BuildContext context) {
    final milestones = [
      _Milestone(achieved: true, title: '1주차 — 첫 훈련 완료', date: '2월 6일'),
      _Milestone(achieved: true, title: '7일 연속 훈련', date: '2월 13일'),
      _Milestone(achieved: true, title: '호기 20 cmH₂O 돌파', date: '3월 18일'),
      _Milestone(
          achieved: false, title: '30일 연속 훈련 (12 / 30)', date: '진행 중'),
      _Milestone(achieved: false, title: '호기 25 cmH₂O 돌파', date: '—'),
    ];
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
          for (var i = 0; i < milestones.length; i++) ...[
            if (i > 0) const Divider(height: 1, color: BlowfitColors.gray150),
            _MilestoneRow(milestone: milestones[i]),
          ],
        ],
      ),
    );
  }
}

class _Milestone {
  const _Milestone({
    required this.achieved,
    required this.title,
    required this.date,
  });
  final bool achieved;
  final String title;
  final String date;
}

class _MilestoneRow extends StatelessWidget {
  const _MilestoneRow({required this.milestone});
  final _Milestone milestone;

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
            milestone.date,
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
