// 수면 효과 시각화 — baseline vs recent before/after + SpO2 추이.

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/app_database.dart';
import '../../core/db/db_providers.dart';
import '../../core/health/sleep_analysis.dart';

class SleepEffectScreen extends ConsumerWidget {
  const SleepEffectScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(recentSleepProvider);
    final trainedDates =
        ref.watch(trainedDatesProvider).valueOrNull ?? <DateTime>{};
    return Scaffold(
      appBar: AppBar(title: const Text('수면 효과')),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('오류: $e')),
        data: (records) {
          if (records.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  '수면 데이터가 없습니다.\n\n워치 착용 후 동기화하거나,\n테스트 화면에서 데모 데이터를 주입하세요.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.black54, height: 1.6),
                ),
              ),
            );
          }
          final sorted = [...records]
            ..sort((a, b) => a.night.compareTo(b.night));
          final effect = computeSleepEffect(records);
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                '최근 ${effect.nights}박 · 초반과 최근 7박 평균 비교',
                style: const TextStyle(fontSize: 13, color: Colors.black54),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _EffectCard(
                      label: '최저 혈중산소',
                      unit: '%',
                      before: effect.baselineSpo2Min,
                      after: effect.recentSpo2Min,
                      decimals: 1,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _EffectCard(
                      label: '수면 점수',
                      unit: '',
                      before: effect.baselineScore,
                      after: effect.recentScore,
                      decimals: 0,
                    ),
                  ),
                ],
              ),
              if (effect.hasApnea) ...[
                const SizedBox(height: 12),
                _ApneaCard(
                  baseline: effect.apneaBaseline,
                  recent: effect.apneaRecent,
                ),
              ],
              const SizedBox(height: 24),
              const Text(
                '최저 혈중산소(SpO₂) 추이',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              SizedBox(height: 220, child: _Spo2Chart(sorted)),
              const SizedBox(height: 12),
              const Text(
                '훈련일 (파랑 = 그날 훈련함)',
                style: TextStyle(fontSize: 12, color: Colors.black54),
              ),
              const SizedBox(height: 6),
              _TrainingStrip(
                nights: [for (final r in sorted) r.night],
                trained: trainedDates,
              ),
              const SizedBox(height: 12),
              const Text(
                '※ 갤럭시워치 측정값(삼성헬스) 기반. 진단이 아닌 참고용 추세입니다.',
                style: TextStyle(fontSize: 11, color: Colors.black38),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _EffectCard extends StatelessWidget {
  const _EffectCard({
    required this.label,
    required this.unit,
    required this.before,
    required this.after,
    required this.decimals,
  });

  final String label;
  final String unit;
  final double? before;
  final double? after;
  final int decimals;

  @override
  Widget build(BuildContext context) {
    final delta = (before != null && after != null) ? after! - before! : null;
    final improved = delta == null ? null : delta > 0; // 둘 다 높을수록 좋음
    final color = improved == null
        ? Colors.grey
        : (improved ? const Color(0xFF00A838) : const Color(0xFFE0533B));
    String fmt(double? v) => v == null ? '—' : v.toStringAsFixed(decimals);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE6E9EC)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(fontSize: 12, color: Colors.black54)),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(fmt(before),
                  style:
                      const TextStyle(fontSize: 15, color: Colors.black38)),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 6),
                child: Icon(Icons.arrow_forward, size: 14, color: Colors.black38),
              ),
              Text(
                '${fmt(after)}$unit',
                style: TextStyle(
                    fontSize: 24, fontWeight: FontWeight.bold, color: color),
              ),
            ],
          ),
          const SizedBox(height: 4),
          if (delta != null)
            Text(
              '${delta >= 0 ? '+' : ''}${delta.toStringAsFixed(decimals)}$unit',
              style: TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w600, color: color),
            ),
        ],
      ),
    );
  }
}

class _ApneaCard extends StatelessWidget {
  const _ApneaCard({this.baseline, this.recent});

  final String? baseline;
  final String? recent;

  String _label(String? s) => switch (s) {
        'DETECTED' => '있음',
        'NOT_DETECTED' => '없음',
        _ => '—',
      };

  @override
  Widget build(BuildContext context) {
    final improved = baseline == 'DETECTED' && recent == 'NOT_DETECTED';
    final worse = baseline == 'NOT_DETECTED' && recent == 'DETECTED';
    final color = improved
        ? const Color(0xFF00A838)
        : (worse ? const Color(0xFFE0533B) : Colors.black87);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE6E9EC)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('수면무호흡 징후',
              style: TextStyle(fontSize: 12, color: Colors.black54)),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(_label(baseline),
                  style: const TextStyle(fontSize: 15, color: Colors.black38)),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 6),
                child:
                    Icon(Icons.arrow_forward, size: 14, color: Colors.black38),
              ),
              Text(_label(recent),
                  style: TextStyle(
                      fontSize: 22, fontWeight: FontWeight.bold, color: color)),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Galaxy Watch 무호흡 선별 (중등도~중증 징후 여부)',
            style: TextStyle(fontSize: 11, color: Colors.black38),
          ),
        ],
      ),
    );
  }
}

/// 차트 아래 훈련일 스트립 — 밤별로 그날(또는 전날) 훈련했으면 파랑.
class _TrainingStrip extends StatelessWidget {
  const _TrainingStrip({required this.nights, required this.trained});

  final List<DateTime> nights; // 오름차순
  final Set<DateTime> trained;

  bool _isTrained(DateTime night) {
    final d0 = DateTime(night.year, night.month, night.day);
    final d1 = d0.subtract(const Duration(days: 1)); // 전날 저녁 훈련
    return trained.contains(d0) || trained.contains(d1);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      // 차트 좌측 Y축(reservedSize 32) 만큼 들여써서 대략 정렬.
      padding: const EdgeInsets.only(left: 32),
      child: SizedBox(
        height: 12,
        child: Row(
          children: [
            for (final n in nights)
              Expanded(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 0.5),
                  decoration: BoxDecoration(
                    color: _isTrained(n)
                        ? const Color(0xFF0066FF)
                        : const Color(0xFFE6E9EC),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Spo2Chart extends StatelessWidget {
  const _Spo2Chart(this.records);

  final List<SleepRecord> records; // 날짜 오름차순

  @override
  Widget build(BuildContext context) {
    final spots = <FlSpot>[];
    for (var i = 0; i < records.length; i++) {
      final v = records[i].spo2Min;
      if (v != null) spots.add(FlSpot(i.toDouble(), v));
    }
    if (spots.length < 2) {
      return const Center(child: Text('SpO₂ 데이터가 부족합니다'));
    }
    final ys = spots.map((s) => s.y);
    final minY = (ys.reduce((a, b) => a < b ? a : b) - 2).floorToDouble();
    final maxY = (ys.reduce((a, b) => a > b ? a : b) + 2).ceilToDouble();

    return LineChart(
      LineChartData(
        minY: minY,
        maxY: maxY,
        gridData: const FlGridData(show: true, drawVerticalLine: false),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          leftTitles: const AxisTitles(
            sideTitles:
                SideTitles(showTitles: true, reservedSize: 32, interval: 2),
          ),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            barWidth: 3,
            color: const Color(0xFF0066FF),
            dotData: const FlDotData(show: false),
            belowBarData:
                BarAreaData(show: true, color: const Color(0x140066FF)),
          ),
        ],
      ),
    );
  }
}
