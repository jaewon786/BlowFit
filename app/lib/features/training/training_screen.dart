import 'dart:async';
import 'dart:collection';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/ble/blowfit_uuids.dart';
import '../../core/ble/ble_providers.dart';
import '../../core/models/pressure_sample.dart';
import '../../core/storage/storage_providers.dart';

class TrainingScreen extends ConsumerStatefulWidget {
  const TrainingScreen({super.key});

  @override
  ConsumerState<TrainingScreen> createState() => _TrainingScreenState();
}

class _TrainingScreenState extends ConsumerState<TrainingScreen> {
  static const _windowSec = 30;
  static const _defaultOrifice = OrificeLevel.medium;
  // 목표 압력 기본값 — Settings 에서 재정의되면 build() 에서 덮어씀.
  double _targetLow = 20.0;
  double _targetHigh = 30.0;

  /// 차트 x = 세션 시작 후 경과 초. 샘플 도착 빈도(Real 200Hz / Fake 50Hz)와
  /// 무관하게 wall-clock 과 1:1 로 진행함.
  final Queue<FlSpot> _points = Queue();
  double _current = 0;
  bool _sessionActive = false;
  DateTime? _sessionStart;
  Duration _enduranceMs = Duration.zero;
  DateTime? _lastSampleAt;
  Timer? _ticker;
  // Summary 모달이 떴는지 추적. _stop() 의 watchdog 이 모달이 안 뜬 케이스에서만
  // 강제로 홈 복귀하기 위해 사용.
  bool _summaryShown = false;

  DeviceStateCode _phase = DeviceStateCode.standby;

  @override
  void initState() {
    super.initState();
    ref.listenManual<AsyncValue<PressureSample>>(pressureSampleProvider, (_, next) {
      next.whenData(_addSample);
    });
    ref.listenManual<AsyncValue<SessionSummary>>(sessionSummaryProvider, (_, next) {
      next.whenData(_showSummary);
    });
    ref.listenManual<AsyncValue<DeviceSnapshot>>(deviceStateProvider, (_, next) {
      next.whenData((s) => setState(() => _phase = DeviceStateCode.fromByte(s.stateCode)));
    });
    ref.listenManual<AsyncValue<bool>>(connectionProvider, (_, next) {
      next.whenData(_onConnectionChange);
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final connected = ref.read(connectionProvider).valueOrNull ?? false;
      if (connected && !_sessionActive) _start();
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  void _onConnectionChange(bool connected) {
    if (!connected && _sessionActive) {
      setState(() {
        _sessionActive = false;
        _phase = DeviceStateCode.standby;
        // 연결 끊김 시 timer 동결. _sessionStart 가 살아있으면 build() 가 매번
        // now - _sessionStart 를 다시 계산해서 시간이 계속 흐름.
        _sessionStart = null;
      });
      _ticker?.cancel();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            duration: Duration(seconds: 6),
            content: Text('연결이 끊어졌습니다 — 진행 중이던 세션 요약을 받지 못했습니다.'),
          ),
        );
      }
    }
  }

  void _addSample(PressureSample s) {
    final start = _sessionStart;
    if (start == null) return;
    final elapsedSec =
        DateTime.now().difference(start).inMilliseconds / 1000.0;
    setState(() {
      _current = s.cmH2O;
      _points.add(FlSpot(elapsedSec, s.cmH2O));
      // 슬라이딩 윈도우: 가장 최근 30초만 유지.
      while (_points.isNotEmpty &&
          _points.first.x < elapsedSec - _windowSec) {
        _points.removeFirst();
      }
      // endurance 는 _ticker (1s) 가 _current 기준으로 누적. 여기선 _lastSampleAt 만
      // 갱신 (다른 용도 추후 가능성 위해 유지).
      _lastSampleAt = s.timestamp;
    });
  }

  Future<void> _start() async {
    // startSession 직전에 목표 압력대를 다시 한 번 펌웨어로 푸시.
    // (펌웨어 reboot 시 RAM 의 zone 이 default 로 리셋되는 케이스 안전망 —
    // targetSyncProvider 의 connect-시 sync 가 timing 으로 못 잡았을 때 대비.)
    try {
      final store = await ref.read(targetSettingsStoreProvider.future);
      final zone = store.load();
      await ref.read(bleManagerProvider).setTarget(zone.low, zone.high);
    } catch (_) {
      // non-fatal — 펌웨어가 default zone (20-30) 으로 진행
    }
    try {
      await ref.read(bleManagerProvider).startSession(_defaultOrifice);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('훈련 시작 실패: $e')),
      );
      return;
    }
    setState(() {
      _sessionActive = true;
      _points.clear();
      _sessionStart = DateTime.now();
      _enduranceMs = Duration.zero;
      _lastSampleAt = null;
    });
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        // 매 초 단위로 endurance 누적. sample-단위 timestamp diff 보다 안정적
        // (BLE packet jitter + 펌웨어 zero-padding 영향 안 받음).
        if (_sessionActive &&
            _current >= _targetLow &&
            _current <= _targetHigh) {
          _enduranceMs += const Duration(seconds: 1);
        }
      });
    });
  }

  Future<void> _stop() async {
    await ref.read(bleManagerProvider).stopSession();
    setState(() {
      _sessionActive = false;
      // build() 의 elapsed = now - _sessionStart 가 계속 커지지 않도록 동결.
      _sessionStart = null;
    });
    _ticker?.cancel();
    _summaryShown = false;
    // Watchdog: SessionSummary BLE notify 가 도달 못 하는 케이스에서도 화면이
    // 멈추지 않도록 4초 후에 modal 안 떴으면 홈으로 복귀.
    Future.delayed(const Duration(seconds: 4), () {
      if (!mounted) return;
      if (_sessionActive) return; // 새 세션 시작했으면 무시
      if (_summaryShown) return;  // 모달 이미 떴으면 그대로 둠
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('세션이 종료되었습니다. 기록 탭에서 결과를 확인하세요.'),
        ),
      );
      final nav = Navigator.of(context);
      if (nav.canPop()) nav.pop();
    });
  }

  void _showSummary(SessionSummary s) {
    if (!mounted) return;
    _summaryShown = true;
    setState(() {
      _sessionActive = false;
      _sessionStart = null;
    });
    _ticker?.cancel();
    showModalBottomSheet<void>(
      context: context,
      builder: (_) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '세션 요약',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _summaryRow('최대 압력', '${s.maxPressure.toStringAsFixed(1)} cmH₂O'),
            _summaryRow('평균 압력', '${s.avgPressure.toStringAsFixed(1)} cmH₂O'),
            _summaryRow('지구력 시간', _fmt(s.endurance)),
            _summaryRow('성공 횟수', '${s.targetHits}회'),
            _summaryRow('훈련 시간', _fmt(s.duration)),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: () {
                Navigator.pop(context);
                if (context.canPop()) {
                  context.pop();
                } else {
                  context.go('/');
                }
              },
              child: const Text('확인'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _summaryRow(String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(k, style: const TextStyle(color: Colors.black54)),
            Text(v, style: const TextStyle(fontWeight: FontWeight.w600)),
          ],
        ),
      );

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  String _phaseLabel(DeviceStateCode p) {
    switch (p) {
      case DeviceStateCode.prep:    return '준비 중';
      case DeviceStateCode.train:   return '훈련 중';
      case DeviceStateCode.rest:    return '휴식';
      case DeviceStateCode.summary: return '완료';
      case DeviceStateCode.weekly:  return '주간 요약';
      case DeviceStateCode.error:   return '오류';
      case DeviceStateCode.boot:
      case DeviceStateCode.standby: return '대기';
    }
  }

  @override
  Widget build(BuildContext context) {
    final connected = ref.watch(connectionProvider).valueOrNull ?? false;
    final state = ref.watch(deviceStateProvider).valueOrNull;
    final lowBattery = state != null && (state.lowBattery || state.batteryPct < 20);
    final health = ref.watch(bleHealthProvider).valueOrNull;
    final degraded = health?.isDegraded ?? false;
    // Settings 에서 저장된 목표 압력대를 읽어와 차트와 endurance 계산에 반영.
    final zone = ref
        .watch(targetSettingsStoreProvider)
        .valueOrNull
        ?.load();
    if (zone != null) {
      _targetLow = zone.low.toDouble();
      _targetHigh = zone.high.toDouble();
    }
    final elapsed = _sessionStart == null
        ? Duration.zero
        : DateTime.now().difference(_sessionStart!);
    // 차트 x 범위는 elapsed 기반으로 항상 최근 30초 윈도우. 샘플이 안 들어오는
    // 동안에도 x축이 흘러가도록 포인트가 아닌 wall-clock 으로 계산.
    final elapsedSec = elapsed.inMilliseconds / 1000.0;
    // 차트 x 범위는 항상 정수 초로 정렬 — fl_chart tick interval(5)이 minX 에
    // 앵커되므로 minX 가 정수여야 라벨이 정수초 위치에 안정적으로 표시됨.
    final visibleEnd = elapsedSec < _windowSec ? _windowSec.toDouble() : elapsedSec;
    final endX = visibleEnd.ceilToDouble();
    final startX = (endX - _windowSec).clamp(0.0, double.infinity);

    // Phase chip 은 "훈련 중" 일 때는 노출하지 않음 (와이어프레임과 일치).
    final showPhaseChip = _phase != DeviceStateCode.train &&
        _phase != DeviceStateCode.standby;

    return Scaffold(
      appBar: AppBar(
        title: const Text('실시간 훈련'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: _ConnectionChip(connected: connected),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              if (showPhaseChip || (lowBattery && connected) || degraded) ...[
                Row(
                  children: [
                    if (showPhaseChip) _PhaseChip(label: _phaseLabel(_phase)),
                    const Spacer(),
                    if (lowBattery && connected)
                      _MiniBadge(
                        icon: state.charging
                            ? Icons.battery_charging_full
                            : Icons.battery_alert,
                        text: '${state.batteryPct}%',
                        color: Colors.redAccent,
                      ),
                    if (degraded) ...[
                      const SizedBox(width: 4),
                      const _MiniBadge(
                        icon: Icons.signal_cellular_alt_2_bar,
                        text: '신호 약함',
                        color: Colors.orange,
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 8),
              ],
              _PressureCard(
                current: _current,
                primary: Theme.of(context).colorScheme.primary,
                targetLow: _targetLow,
                targetHigh: _targetHigh,
              ),
              const SizedBox(height: 12),
              Expanded(
                child: _LiveChart(
                  points: _points,
                  startX: startX,
                  endX: endX,
                  primary: Theme.of(context).colorScheme.primary,
                  targetLow: _targetLow,
                  targetHigh: _targetHigh,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: _StatTile(label: '지구력 시간', value: _fmt(_enduranceMs))),
                  const SizedBox(width: 12),
                  Expanded(child: _StatTile(label: '훈련 시간', value: _fmt(elapsed))),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: connected && _sessionActive ? _stop : null,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text(
                    '훈련 종료',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PressureCard extends StatelessWidget {
  const _PressureCard({
    required this.current,
    required this.primary,
    required this.targetLow,
    required this.targetHigh,
  });
  final double current;
  final Color primary;
  final double targetLow;
  final double targetHigh;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '현재 압력',
              style: TextStyle(fontSize: 13, color: Colors.black54),
            ),
            const SizedBox(height: 4),
            Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    current.toStringAsFixed(0),
                    style: TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                      color: primary,
                      height: 1.0,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'cmH₂O',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: primary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Center(
              child: Text(
                '목표 구간 ${targetLow.toStringAsFixed(0)}-${targetHigh.toStringAsFixed(0)} cmH₂O',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.green.shade700,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LiveChart extends StatelessWidget {
  const _LiveChart({
    required this.points,
    required this.startX,
    required this.endX,
    required this.primary,
    required this.targetLow,
    required this.targetHigh,
  });
  final Queue<FlSpot> points;
  final double startX;
  final double endX;
  final Color primary;
  final double targetLow;
  final double targetHigh;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 16, 16, 8),
        child: LineChart(
          LineChartData(
            minY: 0, maxY: 50,  // E-1 debug: ADC/100 의 풀스케일 ~41 까지 보이도록 50
            minX: startX, maxX: endX,
            clipData: const FlClipData.all(),
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
            titlesData: FlTitlesData(
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 32,
                  interval: 10,
                  getTitlesWidget: (v, meta) => Padding(
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
                  ),
                ),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 22,
                  interval: 5,
                  getTitlesWidget: (v, meta) {
                    // startX/endX 가 정수 초로 정렬돼 있으므로 v 도 정수.
                    // 절대 경과 초 (0초, 5초, ..., 30초, 35초, ...).
                    final sec = v.round();
                    if (sec < 0 || sec % 5 != 0) {
                      return const SizedBox.shrink();
                    }
                    return Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        sec == 0 ? '0' : '${sec}초',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.black54,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                    );
                  },
                ),
              ),
              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            ),
            rangeAnnotations: RangeAnnotations(
              horizontalRangeAnnotations: [
                HorizontalRangeAnnotation(
                  y1: targetLow, y2: targetHigh,
                  color: Colors.green.withOpacity(0.10),
                ),
              ],
            ),
            lineBarsData: [
              LineChartBarData(
                spots: points.toList(growable: false),
                isCurved: true,
                curveSmoothness: 0.25,
                preventCurveOverShooting: true,
                color: primary,
                barWidth: 2.5,
                dotData: const FlDotData(show: false),
                belowBarData: BarAreaData(
                  show: true,
                  color: primary.withOpacity(0.06),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ConnectionChip extends StatelessWidget {
  const _ConnectionChip({required this.connected});
  final bool connected;

  @override
  Widget build(BuildContext context) {
    final color = connected ? Colors.green : Colors.grey;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8, height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          connected ? '연결 중' : '끊김',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }
}

class _PhaseChip extends StatelessWidget {
  const _PhaseChip({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: primary.withOpacity(0.10),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        '현재: $label',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: primary,
        ),
      ),
    );
  }
}

class _MiniBadge extends StatelessWidget {
  const _MiniBadge({required this.icon, required this.text, required this.color});
  final IconData icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 11, fontWeight: FontWeight.w600, color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, color: Colors.black54),
            ),
            const SizedBox(height: 6),
            Text(
              value,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
