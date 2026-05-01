import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/ble/ble_providers.dart';
import '../../core/storage/storage_providers.dart';
import '../../core/storage/target_settings_store.dart';

class TargetSettingsScreen extends ConsumerStatefulWidget {
  const TargetSettingsScreen({super.key});

  @override
  ConsumerState<TargetSettingsScreen> createState() => _TargetSettingsScreenState();
}

class _TargetSettingsScreenState extends ConsumerState<TargetSettingsScreen> {
  double _low = TargetSettingsStore.defaultLow.toDouble();
  double _high = TargetSettingsStore.defaultHigh.toDouble();
  bool _loaded = false;
  bool _saving = false;
  bool _calibrating = false;

  static const _absoluteMin = 5.0;
  static const _absoluteMax = 50.0;
  static const _minWidth = 5.0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _hydrate());
  }

  Future<void> _hydrate() async {
    final store = await ref.read(targetSettingsStoreProvider.future);
    final zone = store.load();
    if (!mounted) return;
    setState(() {
      _low = zone.low.toDouble();
      _high = zone.high.toDouble();
      _loaded = true;
    });
  }

  Future<void> _saveTarget() async {
    setState(() => _saving = true);
    final zone = TargetZone(low: _low.round(), high: _high.round());

    // 1) 로컬 SharedPreferences 먼저 저장 — BLE 실패해도 캐시 유지.
    String? saveError;
    try {
      final store = await ref.read(targetSettingsStoreProvider.future);
      await store.save(zone);
      ref.invalidate(targetSettingsStoreProvider); // watcher 들에게 갱신 알림
    } catch (e) {
      saveError = e.toString();
    }

    // 2) BLE 로 펌웨어에 전송 (실패해도 로컬 저장은 남음)
    String? bleError;
    try {
      await ref.read(bleManagerProvider).setTarget(zone.low, zone.high);
    } catch (e) {
      bleError = e.toString();
    }

    if (!mounted) return;
    setState(() => _saving = false);
    final msg = saveError != null
        ? '로컬 저장 실패: $saveError'
        : (bleError != null
            ? '로컬 저장 OK · 기기 전송 실패: $bleError'
            : '목표 압력 저장: ${zone.low} - ${zone.high} cmH₂O');
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _confirmZeroCalibrate() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('영점 보정'),
        content: const Text(
          '센서를 대기 중인 상태(공기 차단 없이)로 두고 시작하세요.\n'
          '약 5초간 측정 후 현재 압력을 0으로 설정합니다.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('취소')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('시작')),
        ],
      ),
    );
    if (ok != true) return;

    setState(() => _calibrating = true);
    try {
      await ref.read(bleManagerProvider).zeroCalibrate();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('영점 보정을 시작했습니다.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('보정 실패: $e')),
      );
    } finally {
      if (mounted) setState(() => _calibrating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final connected = ref.watch(connectionProvider).valueOrNull ?? false;
    final isValid = _high >= _low + _minWidth;

    return Scaffold(
      appBar: AppBar(title: const Text('목표 압력 설정')),
      body: SafeArea(
        child: !_loaded
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (!connected)
                    Card(
                      color: Colors.orange.shade50,
                      child: const Padding(
                        padding: EdgeInsets.all(12),
                        child: Row(
                          children: [
                            Icon(Icons.bluetooth_disabled, color: Colors.orange),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '기기에 연결되어 있지 않습니다. 변경 사항은 다음 연결 시 적용되지 않습니다.',
                                style: TextStyle(color: Colors.orange),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  if (!connected) const SizedBox(height: 16),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '목표 압력대',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            '훈련 시 그래프에서 녹색으로 표시되는 영역입니다.',
                            style: TextStyle(fontSize: 12, color: Colors.black54),
                          ),
                          const SizedBox(height: 16),
                          // 두 슬라이더 모두 absolute min/max — 한쪽 움직여도 다른쪽
                          // thumb 시각 위치가 안 변함. 최소 폭 검사는 isValid 로.
                          _LabeledSlider(
                            label: '최소',
                            value: _low,
                            min: _absoluteMin,
                            max: _absoluteMax,
                            onChanged: (v) => setState(() => _low = v),
                          ),
                          const SizedBox(height: 8),
                          _LabeledSlider(
                            label: '최대',
                            value: _high,
                            min: _absoluteMin,
                            max: _absoluteMax,
                            onChanged: (v) => setState(() => _high = v),
                          ),
                          if (!isValid)
                            const Padding(
                              padding: EdgeInsets.only(top: 6),
                              child: Text(
                                '최대값은 최소값 + 5 이상이어야 합니다.',
                                style: TextStyle(fontSize: 12, color: Colors.redAccent),
                              ),
                            ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              onPressed: connected && isValid && !_saving ? _saveTarget : null,
                              icon: _saving
                                  ? const SizedBox(
                                      width: 16, height: 16,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    )
                                  : const Icon(Icons.save),
                              label: const Text('기기에 저장'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '영점 보정',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            '센서가 0 cmH₂O를 정확히 인식하도록 다시 보정합니다.',
                            style: TextStyle(fontSize: 12, color: Colors.black54),
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed:
                                  connected && !_calibrating ? _confirmZeroCalibrate : null,
                              icon: _calibrating
                                  ? const SizedBox(
                                      width: 16, height: 16,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    )
                                  : const Icon(Icons.center_focus_weak),
                              label: const Text('영점 보정 실행'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _LabeledSlider extends StatelessWidget {
  const _LabeledSlider({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(width: 40, child: Text(label)),
        Expanded(
          child: Slider(
            value: value.clamp(min, max),
            min: min,
            max: max,
            divisions: (max - min).round(),
            label: '${value.round()} cmH₂O',
            onChanged: onChanged,
          ),
        ),
        SizedBox(
          width: 56,
          child: Text(
            '${value.round()}',
            textAlign: TextAlign.end,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}
