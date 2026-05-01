import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/db/app_database.dart';
import '../../core/db/db_providers.dart';

class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  static const _pageSize = 20;
  static const _lookbackDays = 200; // covers 최근 6개월 (월간 탭 + 비교)

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  int _visibleCount = HistoryScreen._pageSize;

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(sessionRepositoryProvider);
    final since = DateTime.now()
        .subtract(const Duration(days: HistoryScreen._lookbackDays));

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('훈련 기록'),
          bottom: const TabBar(
            tabs: [Tab(text: '주간'), Tab(text: '월간')],
          ),
        ),
        body: SafeArea(
          child: StreamBuilder<List<Session>>(
            stream: repo.watchSince(since),
            builder: (context, snap) {
              if (!snap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final sessions = snap.data!;
              final newestFirst = sessions.reversed.toList(growable: false);
              final pageCount = _visibleCount.clamp(0, newestFirst.length);
              final visible = newestFirst.take(pageCount).toList(growable: false);
              final hasMore = newestFirst.length > pageCount;

              return Column(
                children: [
                  SizedBox(
                    height: 320,
                    child: TabBarView(
                      children: [
                        _WeeklyTrend(sessions: sessions),
                        _MonthlyTrend(sessions: sessions),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: sessions.isEmpty
                        ? const Center(
                            child: Text(
                              '아직 완료한 세션이 없습니다.\n훈련을 시작해보세요.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.black54),
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                            itemCount: visible.length + 2 /* header + footer */,
                            itemBuilder: (context, i) {
                              if (i == 0) {
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text(
                                        '최근 세션',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.black87,
                                        ),
                                      ),
                                      Text(
                                        '$pageCount / ${newestFirst.length}',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Colors.black54,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }
                              final idx = i - 1;
                              if (idx < visible.length) {
                                return _SessionTile(session: visible[idx]);
                              }
                              if (hasMore) {
                                return Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  child: Center(
                                    child: OutlinedButton.icon(
                                      onPressed: () => setState(() {
                                        _visibleCount += HistoryScreen._pageSize;
                                      }),
                                      icon: const Icon(Icons.expand_more),
                                      label: const Text('더 보기'),
                                    ),
                                  ),
                                );
                              }
                              return const SizedBox.shrink();
                            },
                          ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Weekly trend (월~일 7 bars + 전주 대비)
// ---------------------------------------------------------------------------

DateTime _startOfDay(DateTime t) => DateTime(t.year, t.month, t.day);

DateTime _startOfWeek(DateTime t) {
  final daysFromMon = t.weekday - DateTime.monday;
  return _startOfDay(t).subtract(Duration(days: daysFromMon));
}

double _avgPressure(Iterable<Session> sessions) {
  if (sessions.isEmpty) return 0;
  final sum = sessions.fold<double>(0, (a, s) => a + s.avgPressure);
  return sum / sessions.length;
}

class _WeeklyTrend extends StatelessWidget {
  const _WeeklyTrend({required this.sessions});
  final List<Session> sessions;

  @override
  Widget build(BuildContext context) {
    final thisMon = _startOfWeek(DateTime.now());
    final lastMon = thisMon.subtract(const Duration(days: 7));

    // Per-day average for current week (월~일).
    final dailyAvg = List<double>.filled(7, 0);
    for (var i = 0; i < 7; i++) {
      final dayStart = thisMon.add(Duration(days: i));
      final dayEnd = dayStart.add(const Duration(days: 1));
      final daySessions = sessions.where((s) =>
          s.receivedAt.isAfter(dayStart) && s.receivedAt.isBefore(dayEnd));
      dailyAvg[i] = _avgPressure(daySessions);
    }

    final thisWeek = sessions.where((s) => s.receivedAt.isAfter(thisMon));
    final lastWeek = sessions.where((s) =>
        s.receivedAt.isAfter(lastMon) && s.receivedAt.isBefore(thisMon));

    return _TrendBody(
      title: '평균 압력 추이 (cmH₂O)',
      barLabels: const ['월', '화', '수', '목', '금', '토', '일'],
      values: dailyAvg,
      currentLabel: '이번 주 평균',
      currentValue: _avgPressure(thisWeek),
      previousValue: _avgPressure(lastWeek),
      previousLabel: '지난주',
    );
  }
}

DateTime _addMonths(DateTime t, int months) {
  var year = t.year;
  var month = t.month + months;
  while (month <= 0) {
    month += 12;
    year--;
  }
  while (month > 12) {
    month -= 12;
    year++;
  }
  return DateTime(year, month, 1);
}

class _MonthlyTrend extends StatelessWidget {
  const _MonthlyTrend({required this.sessions});
  final List<Session> sessions;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final thisMonth = DateTime(now.year, now.month, 1);

    // 최근 5개월: -4달 ~ 이번 달. 가장 우측 막대 = 이번 달.
    final monthAvgs = List<double>.filled(5, 0);
    final labels = <String>[];
    for (var i = 0; i < 5; i++) {
      final monthStart = _addMonths(thisMonth, -4 + i);
      final monthEnd = _addMonths(monthStart, 1);
      final monthSessions = sessions.where((s) =>
          !s.receivedAt.isBefore(monthStart) && s.receivedAt.isBefore(monthEnd));
      monthAvgs[i] = _avgPressure(monthSessions);
      labels.add(i == 4 ? '이번 달' : '${monthStart.month}월');
    }

    final priorMonthStart = _addMonths(thisMonth, -1);
    final thisSessions =
        sessions.where((s) => !s.receivedAt.isBefore(thisMonth));
    final priorSessions = sessions.where((s) =>
        !s.receivedAt.isBefore(priorMonthStart) &&
        s.receivedAt.isBefore(thisMonth));

    return _TrendBody(
      title: '평균 압력 추이 (cmH₂O)',
      barLabels: labels,
      values: monthAvgs,
      currentLabel: '이번 달 평균',
      currentValue: _avgPressure(thisSessions),
      previousValue: _avgPressure(priorSessions),
      previousLabel: '지난달',
    );
  }
}

class _TrendBody extends StatelessWidget {
  const _TrendBody({
    required this.title,
    required this.barLabels,
    required this.values,
    required this.currentLabel,
    required this.currentValue,
    required this.previousValue,
    required this.previousLabel,
  });

  final String title;
  final List<String> barLabels;
  final List<double> values;
  final String currentLabel;
  final double currentValue;
  final double previousValue;
  final String previousLabel;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    // Y축은 항상 0, 10, 20, 30, 40 라벨이 보이도록 최소 40까지 잡고, 그 이상의
    // 값이 있으면 다음 10 단위로 올림.
    final dataMax = values.fold<double>(0, (a, b) => b > a ? b : a);
    final maxY = dataMax <= 40
        ? 40.0
        : ((dataMax / 10).ceil() * 10).toDouble();

    final hasPrev = previousValue > 0.01;
    final diffPct = hasPrev
        ? ((currentValue - previousValue) / previousValue * 100).round()
        : 0;
    final improving = diffPct > 0;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 13, color: Colors.black54),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 160,
            child: BarChart(
              BarChartData(
                maxY: maxY,
                alignment: BarChartAlignment.spaceAround,
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 32,
                      interval: 10,
                      getTitlesWidget: (v, meta) {
                        // 고정폭 + 오른쪽 정렬 → "0"의 끝자리가 "10"/"20"의
                        // 끝자리(일의 자리)와 같은 세로 축에 정렬됨.
                        return Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: SizedBox(
                            width: 18,
                            child: Text(
                              v.toInt().toString(),
                              textAlign: TextAlign.right,
                              style: const TextStyle(
                                fontSize: 11,
                                color: Colors.black54,
                                fontFeatures: [FontFeature.tabularFigures()],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 24,
                      interval: 1,
                      getTitlesWidget: (v, meta) {
                        final idx = v.round();
                        if (idx < 0 || idx >= barLabels.length) {
                          return const SizedBox.shrink();
                        }
                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            barLabels[idx],
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.black54,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: 10,
                  getDrawingHorizontalLine: (_) => FlLine(
                    color: Colors.grey.shade200,
                    strokeWidth: 1,
                  ),
                ),
                borderData: FlBorderData(show: false),
                barGroups: [
                  for (var i = 0; i < values.length; i++)
                    BarChartGroupData(x: i, barRods: [
                      BarChartRodData(
                        toY: values[i],
                        color: primary,
                        width: 18,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(4),
                        ),
                      ),
                    ]),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          currentLabel,
                          style: const TextStyle(fontSize: 12, color: Colors.black54),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${currentValue.toStringAsFixed(1)} cmH₂O',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (hasPrev)
                    Row(
                      children: [
                        Icon(
                          improving ? Icons.arrow_upward : Icons.arrow_downward,
                          color: improving ? Colors.green : Colors.redAccent,
                          size: 16,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${diffPct.abs()}% ($previousLabel 대비)',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: improving ? Colors.green : Colors.redAccent,
                          ),
                        ),
                      ],
                    )
                  else
                    Text(
                      '$previousLabel 데이터 없음',
                      style: const TextStyle(fontSize: 12, color: Colors.black45),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SessionTile extends StatelessWidget {
  const _SessionTile({required this.session});
  final Session session;

  @override
  Widget build(BuildContext context) {
    final when = session.startedAt ?? session.receivedAt;
    final fmt = DateFormat('M/d (E) HH:mm', 'ko');
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text(fmt.format(when)),
        subtitle: Text(
          '${(session.durationSec / 60).toStringAsFixed(1)}분 · '
          '최대 ${session.maxPressure.toStringAsFixed(1)} cmH₂O · '
          '목표 ${session.targetHits}회',
        ),
        trailing: const Icon(Icons.chevron_right, size: 20),
        onTap: () => context.push('/session/${session.id}'),
      ),
    );
  }
}
