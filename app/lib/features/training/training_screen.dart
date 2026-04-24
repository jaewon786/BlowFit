import 'dart:collection';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/ble/blowfit_uuids.dart';
import '../../core/ble/ble_providers.dart';
import '../../core/models/pressure_sample.dart';

class TrainingScreen extends ConsumerStatefulWidget {
  const TrainingScreen({super.key});

  @override
  ConsumerState<TrainingScreen> createState() => _TrainingScreenState();
}

class _TrainingScreenState extends ConsumerState<TrainingScreen> {
  static const _windowSec = 30;
  static const _rateHz = 100;

  final Queue<FlSpot> _points = Queue();
  double _tCursor = 0;
  double _current = 0;
  bool _sessionActive = false;
  OrificeLevel _orifice = OrificeLevel.medium;

  @override
  void initState() {
    super.initState();
    ref.listenManual<AsyncValue<PressureSample>>(pressureSampleProvider, (_, next) {
      next.whenData(_addSample);
    });
    ref.listenManual<AsyncValue<SessionSummary>>(sessionSummaryProvider, (_, next) {
      next.whenData(_showSummary);
    });
  }

  void _addSample(PressureSample s) {
    setState(() {
      _current = s.cmH2O;
      _tCursor += 1 / _rateHz;
      _points.add(FlSpot(_tCursor, s.cmH2O));
      final keep = _windowSec * _rateHz;
      while (_points.length > keep) {
        _points.removeFirst();
      }
    });
  }

  Future<void> _start() async {
    await ref.read(bleManagerProvider).startSession(_orifice);
    setState(() {
      _sessionActive = true;
      _points.clear();
      _tCursor = 0;
    });
  }

  Future<void> _stop() async {
    await ref.read(bleManagerProvider).stopSession();
    setState(() => _sessionActive = false);
  }

  void _showSummary(SessionSummary s) {
    if (!mounted) return;
    setState(() => _sessionActive = false);
    showModalBottomSheet<void>(
      context: context,
      builder: (_) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('세션 요약', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            _row('최대 압력', '${s.maxPressure.toStringAsFixed(1)} cmH2O'),
            _row('평균 압력', '${s.avgPressure.toStringAsFixed(1)} cmH2O'),
            _row('지구력', '${s.endurance.inSeconds}초'),
            _row('목표 달성', '${s.targetHits}회 (15초+)'),
            _row('훈련 시간', '${s.duration.inMinutes}분 ${s.duration.inSeconds % 60}초'),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: () {
                Navigator.pop(context);
                context.go('/');
              },
              child: const Text('확인'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(String k, String v) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [Text(k), Text(v, style: const TextStyle(fontWeight: FontWeight.w600))],
    ),
  );

  Color _zoneColor(double p) {
    if (p < 15) return Colors.red;
    if (p < 20) return Colors.orange;
    if (p <= 30) return Colors.green;
    return Colors.deepOrange;
  }

  @override
  Widget build(BuildContext context) {
    final startX = _points.isEmpty ? 0.0 : _points.first.x;
    final endX = _points.isEmpty ? (_windowSec.toDouble()) : _points.last.x;

    return Scaffold(
      appBar: AppBar(title: const Text('훈련')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Card(
              color: _zoneColor(_current).withOpacity(0.15),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    const Text('현재 압력', style: TextStyle(fontSize: 14)),
                    Text(
                      '${_current.toStringAsFixed(1)} cmH2O',
                      style: TextStyle(
                        fontSize: 48, fontWeight: FontWeight.bold,
                        color: _zoneColor(_current),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: LineChart(LineChartData(
                    minY: 0, maxY: 40,
                    minX: startX, maxX: endX,
                    gridData: const FlGridData(show: true),
                    titlesData: const FlTitlesData(
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(showTitles: true, reservedSize: 32),
                      ),
                      bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    ),
                    rangeAnnotations: RangeAnnotations(
                      horizontalRangeAnnotations: [
                        HorizontalRangeAnnotation(
                          y1: 20, y2: 30,
                          color: Colors.green.withOpacity(0.15),
                        ),
                      ],
                    ),
                    lineBarsData: [
                      LineChartBarData(
                        spots: _points.toList(growable: false),
                        isCurved: false,
                        color: Colors.tealAccent,
                        barWidth: 2,
                        dotData: const FlDotData(show: false),
                      ),
                    ],
                  )),
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (!_sessionActive) ...[
              SegmentedButton<OrificeLevel>(
                segments: OrificeLevel.values.map((l) => ButtonSegment(
                  value: l,
                  label: Text(l.label),
                )).toList(),
                selected: {_orifice},
                onSelectionChanged: (s) => setState(() => _orifice = s.first),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _start,
                icon: const Icon(Icons.play_arrow),
                label: const Text('훈련 시작'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 16),
                ),
              ),
            ] else
              FilledButton.icon(
                onPressed: _stop,
                icon: const Icon(Icons.stop),
                label: const Text('종료'),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 16),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
