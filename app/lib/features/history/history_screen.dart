import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/db/app_database.dart';
import '../../core/db/db_providers.dart';

/// 12-week session history with max/avg pressure trend and target-hits.
class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  static const _weeks = 12;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(sessionRepositoryProvider);
    final since = DateTime.now().subtract(const Duration(days: _weeks * 7));

    return Scaffold(
      appBar: AppBar(title: const Text('훈련 기록')),
      body: StreamBuilder<List<Session>>(
        stream: repo.watchSince(since),
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final sessions = snap.data!;
          if (sessions.isEmpty) {
            return const Center(
              child: Text('아직 완료한 세션이 없습니다.\n훈련을 시작해보세요.',
                textAlign: TextAlign.center),
            );
          }
          final weekly = _bucketByWeek(sessions, _weeks);
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _SummaryRow(sessions: sessions),
              const SizedBox(height: 16),
              _TrendCard(weekly: weekly),
              const SizedBox(height: 16),
              const Text('최근 세션',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              ...sessions.reversed.take(20).map((s) => _SessionTile(s)),
            ],
          );
        },
      ),
    );
  }
}

class _WeekBucket {
  final int weekOffset; // 0 = current week, higher = older
  final double avgMax;
  final double avgAvg;
  final int totalHits;
  final int sessionCount;
  _WeekBucket(this.weekOffset, this.avgMax, this.avgAvg,
      this.totalHits, this.sessionCount);
}

List<_WeekBucket> _bucketByWeek(List<Session> sessions, int weeks) {
  final now = DateTime.now();
  final buckets = List.generate(weeks, (i) => <Session>[]);
  for (final s in sessions) {
    final days = now.difference(s.receivedAt).inDays;
    final idx = days ~/ 7;
    if (idx >= 0 && idx < weeks) buckets[idx].add(s);
  }
  return List.generate(weeks, (i) {
    final b = buckets[i];
    if (b.isEmpty) return _WeekBucket(i, 0, 0, 0, 0);
    final maxAvg = b.map((s) => s.maxPressure).reduce((a, b) => a + b) / b.length;
    final avgAvg = b.map((s) => s.avgPressure).reduce((a, b) => a + b) / b.length;
    final hits = b.map((s) => s.targetHits).reduce((a, b) => a + b);
    return _WeekBucket(i, maxAvg, avgAvg, hits, b.length);
  });
}

class _SummaryRow extends StatelessWidget {
  final List<Session> sessions;
  const _SummaryRow({required this.sessions});

  @override
  Widget build(BuildContext context) {
    final totalSessions = sessions.length;
    final totalMinutes =
        sessions.fold<int>(0, (acc, s) => acc + s.durationSec) ~/ 60;
    final totalHits = sessions.fold<int>(0, (acc, s) => acc + s.targetHits);
    return Row(
      children: [
        _Stat(label: '세션', value: '$totalSessions'),
        _Stat(label: '누적 분', value: '$totalMinutes'),
        _Stat(label: '목표 달성', value: '$totalHits'),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;
  const _Stat({required this.label, required this.value});
  @override
  Widget build(BuildContext context) => Expanded(
    child: Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Column(children: [
          Text(value, style: const TextStyle(
            fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(
            fontSize: 12, color: Colors.white70)),
        ]),
      ),
    ),
  );
}

class _TrendCard extends StatelessWidget {
  final List<_WeekBucket> weekly;
  const _TrendCard({required this.weekly});

  @override
  Widget build(BuildContext context) {
    // Reverse so oldest is on the left, newest on the right.
    final reversed = weekly.reversed.toList();
    final maxSpots = <FlSpot>[];
    final avgSpots = <FlSpot>[];
    for (var i = 0; i < reversed.length; i++) {
      final b = reversed[i];
      if (b.sessionCount == 0) continue;
      maxSpots.add(FlSpot(i.toDouble(), b.avgMax));
      avgSpots.add(FlSpot(i.toDouble(), b.avgAvg));
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('12주 추세 (최대 / 평균 압력)',
              style: TextStyle(fontSize: 14, color: Colors.white70)),
            const SizedBox(height: 12),
            SizedBox(
              height: 200,
              child: LineChart(LineChartData(
                minY: 0, maxY: 50,
                titlesData: FlTitlesData(
                  leftTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: true, reservedSize: 32),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 24,
                      interval: 3,
                      getTitlesWidget: (v, _) {
                        final weekOffset = weekly.length - 1 - v.toInt();
                        return Text('-${weekOffset}w',
                          style: const TextStyle(fontSize: 10));
                      },
                    ),
                  ),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                gridData: const FlGridData(show: true),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  if (maxSpots.isNotEmpty)
                    LineChartBarData(
                      spots: maxSpots, isCurved: true, barWidth: 3,
                      color: Colors.tealAccent,
                      dotData: const FlDotData(show: true),
                    ),
                  if (avgSpots.isNotEmpty)
                    LineChartBarData(
                      spots: avgSpots, isCurved: true, barWidth: 2,
                      color: Colors.white54,
                      dotData: const FlDotData(show: false),
                    ),
                ],
              )),
            ),
            const SizedBox(height: 8),
            Row(children: const [
              _LegendDot(color: Colors.tealAccent), SizedBox(width: 4),
              Text('최대', style: TextStyle(fontSize: 12)),
              SizedBox(width: 16),
              _LegendDot(color: Colors.white54), SizedBox(width: 4),
              Text('평균', style: TextStyle(fontSize: 12)),
            ]),
          ],
        ),
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  const _LegendDot({required this.color});
  @override
  Widget build(BuildContext context) => Container(
    width: 10, height: 10,
    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
  );
}

class _SessionTile extends StatelessWidget {
  final Session session;
  const _SessionTile(this.session);

  @override
  Widget build(BuildContext context) {
    final when = session.startedAt ?? session.receivedAt;
    final fmt = DateFormat('M/d (E) HH:mm', 'ko');
    return Card(
      child: ListTile(
        title: Text(fmt.format(when)),
        subtitle: Text(
          '${(session.durationSec / 60).toStringAsFixed(1)}분 · '
          '최대 ${session.maxPressure.toStringAsFixed(1)} cmH₂O · '
          '목표 ${session.targetHits}회',
        ),
        trailing: Text('${session.orificeLevel + 1}단계',
          style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }
}
