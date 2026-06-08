// 목표 압력 설정 화면 — v4.1 %PImax 기반 적응형.
//
// 구성:
//   1. 강도 단계 카드 — 초보/일반/숙련 RadioListTile (한 변수로 비율 전환)
//   2. 내 PImax/MEP 카드 — TextField. 안전 상한 초과 시 ⚠ 경고
//   3. 현재 목표 미리보기 카드 — 흡기/호기 절대값 + (X% PImax/MEP)
//   4. 영점 보정 카드 — 기존 유지 (압력 측정 hw 보정)
//
// 근거 (배경 설명용):
//   - 50~60% PImax  POWERbreathe 임상 표준 (sustainable zone, 기본)
//   - 70~75% PImax  Vranish & Bailey 2016 IMT 프로토콜 (강도 ↑)
//   - 30~40% PImax  호흡 재활 초보 (Bissett 2019)
//   - 안전 상한 흡기 90 / 호기 100 cmH₂O — consumer device ceiling
//
// 펌웨어 전송 (저장 버튼): BLE SET_TARGET v4.1 payload
//   opcode 0x05 + level(1B) + pimax×10(u16 LE) + mep×10(u16 LE) = 6B

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/ble/ble_providers.dart';
import '../../core/storage/pimax_mep_store.dart';
import '../../core/storage/storage_providers.dart';

class TargetSettingsScreen extends ConsumerStatefulWidget {
  const TargetSettingsScreen({super.key});

  @override
  ConsumerState<TargetSettingsScreen> createState() => _TargetSettingsScreenState();
}

class _TargetSettingsScreenState extends ConsumerState<TargetSettingsScreen> {
  IntensityLevel _level = PimaxMepStore.defaultLevel;
  late final TextEditingController _pimaxCtrl;
  late final TextEditingController _mepCtrl;
  bool _loaded = false;
  bool _saving = false;
  bool _calibrating = false;

  @override
  void initState() {
    super.initState();
    _pimaxCtrl = TextEditingController();
    _mepCtrl = TextEditingController();
    WidgetsBinding.instance.addPostFrameCallback((_) => _hydrate());
  }

  @override
  void dispose() {
    _pimaxCtrl.dispose();
    _mepCtrl.dispose();
    super.dispose();
  }

  Future<void> _hydrate() async {
    final store = await ref.read(pimaxMepStoreProvider.future);
    if (!mounted) return;
    setState(() {
      _level = store.loadLevel();
      _pimaxCtrl.text = store.loadPimax().toStringAsFixed(0);
      _mepCtrl.text = store.loadMep().toStringAsFixed(0);
      _loaded = true;
    });
  }

  /// 현재 입력값 기반 흡기/호기 target 계산 (저장 전 미리보기).
  ({double low, double high}) _previewInhale() {
    final pimax = double.tryParse(_pimaxCtrl.text) ?? PimaxMepStore.defaultPimax;
    var low = pimax * _level.lowPct;
    var high = pimax * _level.highPct;
    if (high > PimaxMepStore.inhaleSafetyLimitCmH2O) {
      high = PimaxMepStore.inhaleSafetyLimitCmH2O;
      if (low > high) low = high;
    }
    return (low: low, high: high);
  }

  ({double low, double high}) _previewExhale() {
    final mep = double.tryParse(_mepCtrl.text) ?? PimaxMepStore.defaultMep;
    var low = mep * _level.lowPct;
    var high = mep * _level.highPct;
    if (high > PimaxMepStore.exhaleSafetyLimitCmH2O) {
      high = PimaxMepStore.exhaleSafetyLimitCmH2O;
      if (low > high) low = high;
    }
    return (low: low, high: high);
  }

  /// 사용자가 PImax 를 너무 크게 적어 흡기 target 이 안전 상한 초과 → ⚠.
  bool get _inhaleExceeds {
    final pimax = double.tryParse(_pimaxCtrl.text) ?? PimaxMepStore.defaultPimax;
    return pimax * _level.highPct > PimaxMepStore.inhaleSafetyLimitCmH2O;
  }

  bool get _exhaleExceeds {
    final mep = double.tryParse(_mepCtrl.text) ?? PimaxMepStore.defaultMep;
    return mep * _level.highPct > PimaxMepStore.exhaleSafetyLimitCmH2O;
  }

  Future<void> _save() async {
    final pimax = double.tryParse(_pimaxCtrl.text);
    final mep = double.tryParse(_mepCtrl.text);
    if (pimax == null || pimax <= 0 || mep == null || mep <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('PImax / MEP 는 0 보다 큰 수로 입력하세요.')),
      );
      return;
    }
    setState(() => _saving = true);

    String? saveError;
    try {
      final store = await ref.read(pimaxMepStoreProvider.future);
      await store.saveLevel(_level);
      await store.savePimax(pimax);
      await store.saveMep(mep);
      ref.invalidate(pimaxMepStoreProvider);
    } catch (e) {
      saveError = e.toString();
    }

    String? bleError;
    try {
      await ref.read(bleManagerProvider).setIntensityTarget(
            level: _level.value,
            pimax: pimax,
            mep: mep,
          );
    } catch (e) {
      bleError = e.toString();
    }

    if (!mounted) return;
    setState(() => _saving = false);
    final msg = saveError != null
        ? '로컬 저장 실패: $saveError'
        : (bleError != null
            ? '로컬 저장 OK · 기기 전송 실패: $bleError'
            : '저장 완료 (${_level.label} · PImax ${pimax.toStringAsFixed(0)} / MEP ${mep.toStringAsFixed(0)})');
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
    final inhalePreview = _loaded ? _previewInhale() : null;
    final exhalePreview = _loaded ? _previewExhale() : null;

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
                            Icon(Icons.bluetooth_disabled, color: Colors.orange),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '기기에 연결되어 있지 않습니다. 저장한 값은 다음 연결 시 자동 전송됩니다.',
                                style: TextStyle(color: Colors.orange),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // ── 강도 단계 ──
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '강도 단계',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'PImax / MEP 에 곱할 % 범위. 한 변수로 흡기·호기 4개 목표가 한꺼번에 갱신됩니다.',
                            style: TextStyle(fontSize: 12, color: Colors.black54),
                          ),
                          const SizedBox(height: 8),
                          for (final lv in IntensityLevel.values)
                            RadioListTile<IntensityLevel>(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              value: lv,
                              groupValue: _level,
                              onChanged: (v) {
                                if (v != null) setState(() => _level = v);
                              },
                              title: Text(lv.label),
                              subtitle: Text(
                                '${(lv.lowPct * 100).round()} ~ ${(lv.highPct * 100).round()}%'
                                '${lv == PimaxMepStore.defaultLevel ? "  · 기본 (POWERbreathe sustainable zone)" : ""}',
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ── 내 PImax / MEP ──
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '내 PImax / MEP',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'PImax = 최대 흡기압, MEP = 최대 호기압 (cmH₂O). 측정 기능이 없으면 일반 성인 평균(80 / 60) 사용.',
                            style: TextStyle(fontSize: 12, color: Colors.black54),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _pimaxCtrl,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(3),
                            ],
                            decoration: InputDecoration(
                              labelText: 'PImax (cmH₂O)',
                              suffixText: 'cmH₂O',
                              border: const OutlineInputBorder(),
                              helperText: _inhaleExceeds
                                  ? '⚠ 흡기 목표가 안전 상한 ${PimaxMepStore.inhaleSafetyLimitCmH2O.toInt()} cmH₂O를 초과해 자동 제한됩니다.'
                                  : null,
                              helperStyle: const TextStyle(color: Colors.redAccent),
                            ),
                            onChanged: (_) => setState(() {}),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _mepCtrl,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(3),
                            ],
                            decoration: InputDecoration(
                              labelText: 'MEP (cmH₂O)',
                              suffixText: 'cmH₂O',
                              border: const OutlineInputBorder(),
                              helperText: _exhaleExceeds
                                  ? '⚠ 호기 목표가 안전 상한 ${PimaxMepStore.exhaleSafetyLimitCmH2O.toInt()} cmH₂O를 초과해 자동 제한됩니다.'
                                  : null,
                              helperStyle: const TextStyle(color: Colors.redAccent),
                            ),
                            onChanged: (_) => setState(() {}),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ── 현재 목표 미리보기 ──
                  Card(
                    color: Colors.blue.shade50,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '계산된 목표 압력',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          if (inhalePreview != null)
                            _TargetRow(
                              label: '흡기',
                              valueText:
                                  '-${inhalePreview.low.toStringAsFixed(0)} ~ -${inhalePreview.high.toStringAsFixed(0)} cmH₂O',
                              pctText: '${_level.midPct}% PImax',
                              warning: _inhaleExceeds,
                            ),
                          if (exhalePreview != null) ...[
                            const SizedBox(height: 4),
                            _TargetRow(
                              label: '호기',
                              valueText:
                                  '+${exhalePreview.low.toStringAsFixed(0)} ~ +${exhalePreview.high.toStringAsFixed(0)} cmH₂O',
                              pctText: '${_level.midPct}% MEP',
                              warning: _exhaleExceeds,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _saving ? null : _save,
                      icon: _saving
                          ? const SizedBox(
                              width: 16, height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.save),
                      label: const Text('저장하고 기기로 전송'),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ── 영점 보정 (기존 유지) ──
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

class _TargetRow extends StatelessWidget {
  const _TargetRow({
    required this.label,
    required this.valueText,
    required this.pctText,
    required this.warning,
  });
  final String label;
  final String valueText;
  final String pctText;
  final bool warning;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 36,
          child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        ),
        Expanded(
          child: Text(
            valueText,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          ),
        ),
        Text(
          pctText,
          style: TextStyle(
            fontSize: 13,
            color: warning ? Colors.redAccent : Colors.black54,
          ),
        ),
        if (warning) ...[
          const SizedBox(width: 4),
          const Icon(Icons.warning_amber, size: 16, color: Colors.redAccent),
        ],
      ],
    );
  }
}
