// 목표 압력 설정 화면 — 사용자 친화적.
//
// 구성:
//   1. 내 호흡 세기 카드 — 최대 날숨/들숨 세기(읽기전용) + "다시 측정하기" 버튼.
//      (직접 숫자를 고치는 대신, 측정 화면으로 가서 다시 측정한다.)
//   2. 강도 단계 카드 — 약하게/보통/강하게. 고르면 즉시 저장 + 기기 전송.
//   3. 지금 훈련 목표 카드 — 들숨/날숨 목표 압력 범위 미리보기.
//   4. 영점 보정 카드.
//
// "최대 날숨 세기" = MEP, "최대 들숨 세기" = PImax 를 쉬운 말로 표현.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/ble/ble_providers.dart';
import '../../core/storage/pimax_mep_store.dart';
import '../../core/storage/storage_providers.dart';

class TargetSettingsScreen extends ConsumerStatefulWidget {
  const TargetSettingsScreen({super.key});

  @override
  ConsumerState<TargetSettingsScreen> createState() =>
      _TargetSettingsScreenState();
}

class _TargetSettingsScreenState extends ConsumerState<TargetSettingsScreen> {
  IntensityLevel _level = PimaxMepStore.defaultLevel;
  double _pimax = PimaxMepStore.defaultPimax; // 최대 들숨 세기
  double _mep = PimaxMepStore.defaultMep; // 최대 날숨 세기
  bool _loaded = false;
  bool _calibrating = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _hydrate());
  }

  Future<void> _hydrate() async {
    final store = await ref.read(pimaxMepStoreProvider.future);
    if (!mounted) return;
    setState(() {
      _level = store.loadLevel();
      _pimax = store.loadPimax();
      _mep = store.loadMep();
      _loaded = true;
    });
  }

  /// 강도 단계 변경 → 즉시 저장 + (연결 시) 기기 전송. (미연결이면 다음 connect
  /// 때 targetSyncProvider 가 자동 재전송하므로 실패 무시.)
  Future<void> _onLevelChanged(IntensityLevel lv) async {
    setState(() => _level = lv);
    try {
      final store = await ref.read(pimaxMepStoreProvider.future);
      await store.saveLevel(lv);
      ref.invalidate(pimaxMepStoreProvider);
      await ref.read(bleManagerProvider).setIntensityTarget(
            level: lv.value,
            pimax: _pimax,
            mep: _mep,
          );
    } catch (_) {}
  }

  /// "다시 측정하기" → 측정 화면(fromSettings) push. 돌아오면 새 값 반영.
  Future<void> _remeasure() async {
    await context.push('/settings/measure');
    if (mounted) _hydrate();
  }

  ({double low, double high}) _inhaleTarget() {
    var low = _pimax * _level.lowPct;
    var high = _pimax * _level.highPct;
    if (high > PimaxMepStore.inhaleSafetyLimitCmH2O) {
      high = PimaxMepStore.inhaleSafetyLimitCmH2O;
      if (low > high) low = high;
    }
    return (low: low, high: high);
  }

  ({double low, double high}) _exhaleTarget() {
    var low = _mep * _level.lowPct;
    var high = _mep * _level.highPct;
    if (high > PimaxMepStore.exhaleSafetyLimitCmH2O) {
      high = PimaxMepStore.exhaleSafetyLimitCmH2O;
      if (low > high) low = high;
    }
    return (low: low, high: high);
  }

  String _levelDesc(IntensityLevel lv) {
    switch (lv) {
      case IntensityLevel.beginner:
        return '약하게 · 재활·입문에 좋아요';
      case IntensityLevel.normal:
        return '보통 · 권장';
      case IntensityLevel.advanced:
        return '강하게 · 고강도 훈련';
    }
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
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('시작'),
          ),
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
    return Scaffold(
      appBar: AppBar(title: const Text('목표 압력 설정')),
      body: SafeArea(
        child: !_loaded
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (!connected) ...[
                    Card(
                      color: Colors.orange.shade50,
                      child: const Padding(
                        padding: EdgeInsets.all(12),
                        child: Row(
                          children: [
                            Icon(
                              Icons.bluetooth_disabled,
                              color: Colors.orange,
                            ),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '기기에 연결되어 있지 않습니다. 바뀐 값은 다음 연결 시 자동으로 전송됩니다.',
                                style: TextStyle(color: Colors.orange),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // ── 내 호흡 세기 (읽기전용 + 다시 측정) ──
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '내 호흡 세기',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            '숨을 가장 강하게 내쉴 때와 들이쉴 때의 세기예요. '
                            '직접 고치지 않고, 다시 측정해서 내게 맞게 맞춰요.',
                            style:
                                TextStyle(fontSize: 12, color: Colors.black54),
                          ),
                          const SizedBox(height: 16),
                          _StrengthRow(label: '최대 날숨 세기', value: _mep),
                          const SizedBox(height: 10),
                          _StrengthRow(label: '최대 들숨 세기', value: _pimax),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              onPressed: _remeasure,
                              icon: const Icon(Icons.refresh),
                              label: const Text('다시 측정하기'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ── 강도 단계 ──
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '훈련 강도',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            '내 호흡 세기에서 얼마나 세게 훈련할지 정해요.',
                            style:
                                TextStyle(fontSize: 12, color: Colors.black54),
                          ),
                          const SizedBox(height: 8),
                          RadioGroup<IntensityLevel>(
                            groupValue: _level,
                            onChanged: (v) {
                              if (v != null) _onLevelChanged(v);
                            },
                            child: Column(
                              children: [
                                for (final lv in IntensityLevel.values)
                                  RadioListTile<IntensityLevel>(
                                    dense: true,
                                    contentPadding: EdgeInsets.zero,
                                    value: lv,
                                    title: Text(lv.label),
                                    subtitle: Text(_levelDesc(lv)),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ── 지금 훈련 목표 (미리보기) ──
                  Card(
                    color: Colors.blue.shade50,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '지금 훈련 목표',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '기준 다이얼 2단 · 훈련 시작 시 단계별 자동 조정',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.black.withValues(alpha: 0.5),
                            ),
                          ),
                          const SizedBox(height: 8),
                          _PreviewRow(
                            label: '내쉬기(날숨)',
                            target: _exhaleTarget(),
                            warning: _mep * _level.highPct >
                                PimaxMepStore.exhaleSafetyLimitCmH2O,
                          ),
                          const SizedBox(height: 4),
                          _PreviewRow(
                            label: '들이쉬기(들숨)',
                            target: _inhaleTarget(),
                            warning: _pimax * _level.highPct >
                                PimaxMepStore.inhaleSafetyLimitCmH2O,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ── 영점 보정 ──
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '영점 보정',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            '센서가 0을 정확히 인식하도록 다시 맞춰요.',
                            style:
                                TextStyle(fontSize: 12, color: Colors.black54),
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: connected && !_calibrating
                                  ? _confirmZeroCalibrate
                                  : null,
                              icon: _calibrating
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
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

class _StrengthRow extends StatelessWidget {
  const _StrengthRow({required this.label, required this.value});
  final String label;
  final double value;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              value.toStringAsFixed(0),
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            const SizedBox(width: 3),
            const Text(
              'cmH₂O',
              style: TextStyle(fontSize: 12, color: Colors.black54),
            ),
          ],
        ),
      ],
    );
  }
}

class _PreviewRow extends StatelessWidget {
  const _PreviewRow({
    required this.label,
    required this.target,
    required this.warning,
  });
  final String label;
  final ({double low, double high}) target;
  final bool warning;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 96,
          child: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        Expanded(
          child: Text(
            '${target.low.toStringAsFixed(0)} ~ ${target.high.toStringAsFixed(0)} cmH₂O',
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          ),
        ),
        if (warning)
          const Icon(Icons.warning_amber, size: 16, color: Colors.redAccent),
      ],
    );
  }
}
