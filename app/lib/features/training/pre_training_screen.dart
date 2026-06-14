// 훈련 시작 전 선택 화면 — 다이얼 단계 / 훈련 시간 / 목표 압력 확인.
//
// 홈 "훈련하기" → 이 화면 → "훈련 시작".
//   - 다이얼 단계(1/2/3단)를 사용자가 직접 선택. 펌웨어로 startSession(orifice)
//     전송 → 펌웨어가 단계별 보정계수로 목표 압력을 자동 재계산.
//   - 목표 압력은 기준 2단에서 측정한 PImax/MEP × 강도% × 다이얼 보정계수.
//   - 선택한 다이얼/시간은 영속 저장 → 다음에도 기본값으로 유지.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/ble/ble_providers.dart';
import '../../core/ble/blowfit_uuids.dart';
import '../../core/coach/training_recommender.dart';
import '../../core/db/db_providers.dart';
import '../../core/storage/pimax_mep_store.dart';
import '../../core/storage/storage_providers.dart';
import '../../core/storage/train_duration_store.dart';

class PreTrainingScreen extends ConsumerStatefulWidget {
  const PreTrainingScreen({super.key});

  @override
  ConsumerState<PreTrainingScreen> createState() => _PreTrainingScreenState();
}

class _PreTrainingScreenState extends ConsumerState<PreTrainingScreen> {
  OrificeLevel? _dial;
  int? _durationMin;
  bool _starting = false;

  @override
  Widget build(BuildContext context) {
    final pm = ref.watch(pimaxMepStoreProvider).valueOrNull;
    final durStore = ref.watch(trainDurationStoreProvider).valueOrNull;
    final connected = ref.watch(connectionProvider).valueOrNull ?? false;
    final rec = ref.watch(trainingRecommendationProvider).valueOrNull;

    if (pm == null || durStore == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // 선택값(없으면 저장된 기본값).
    final dial = _dial ?? pm.loadDialLevel();
    final durationMin = _durationMin ?? durStore.loadMinutes();

    // 선택한 다이얼 기준 목표 압력 (절대값 magnitude).
    final inhale = pm.inhaleTarget(dial: dial);
    final exhale = pm.exhaleTarget(dial: dial);

    return Scaffold(
      appBar: AppBar(title: const Text('훈련 시작')),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                children: [
                  if (rec != null) ...[
                    _RecommendationBanner(
                      rec: rec,
                      onApply: () => setState(() {
                        _dial = rec.dial;
                        _durationMin = rec.minutes;
                      }),
                    ),
                    const SizedBox(height: 12),
                  ],
                  _DialCard(
                    selected: dial,
                    onSelect: (d) => setState(() => _dial = d),
                  ),
                  const SizedBox(height: 12),
                  _DurationCard(
                    selected: durationMin,
                    onSelect: (m) => setState(() => _durationMin = m),
                  ),
                  const SizedBox(height: 12),
                  _TargetPreviewCard(
                    dial: dial,
                    exhaleLow: exhale.low,
                    exhaleHigh: exhale.high,
                    inhaleLow: inhale.low,
                    inhaleHigh: inhale.high,
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _starting
                      ? null
                      : connected
                          ? () => _start(pm, dial, durationMin)
                          : () => context.push('/connect'),
                  icon: Icon(
                    connected ? Icons.play_arrow : Icons.bluetooth_searching,
                  ),
                  label: Text(connected ? '훈련 시작' : '기기 연결'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, 52),
                    textStyle: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _start(
    PimaxMepStore pm,
    OrificeLevel dial,
    int durationMin,
  ) async {
    setState(() => _starting = true);
    final mgr = ref.read(bleManagerProvider);

    // 선택값 영속 저장.
    await pm.saveDialLevel(dial);
    final durStore = await ref.read(trainDurationStoreProvider.future);
    await durStore.save(durationMin);
    ref
      ..invalidate(trainDurationStoreProvider)
      ..invalidate(pimaxMepStoreProvider);

    // 기기 전송 — PImax/MEP/강도(기준값) → 시간 → startSession(다이얼).
    // startSession 의 orifice 가 펌웨어 g_orifice 를 갱신하고, 펌웨어가
    // 단계별 보정계수로 목표를 재계산한다.
    try {
      await mgr.setIntensityTarget(
        level: pm.loadLevel().value,
        pimax: pm.loadPimax(),
        mep: pm.loadMep(),
      );
      await mgr.setTrainDuration(durationMin * 60);
      await mgr.startSession(dial);
    } catch (_) {
      // 미연결/전송 실패해도 화면은 진행 — 훈련 화면이 연결 상태를 표시.
    }

    if (!mounted) return;
    setState(() => _starting = false);
    context.push('/training');
  }
}

// ─────────────────────────── 다이얼 단계 선택 ───────────────────────────
class _DialCard extends StatelessWidget {
  const _DialCard({required this.selected, required this.onSelect});

  final OrificeLevel selected;
  final ValueChanged<OrificeLevel> onSelect;

  static const _hint = {
    OrificeLevel.low: '약함',
    OrificeLevel.medium: '기준',
    OrificeLevel.high: '강함',
  };

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: '다이얼 단계',
      subtitle: '기기 다이얼을 맞춘 단계를 선택하세요',
      child: Row(
        children: [
          for (final lvl in OrificeLevel.values) ...[
            if (lvl != OrificeLevel.low) const SizedBox(width: 8),
            Expanded(
              child: _DialOption(
                level: lvl,
                hint: _hint[lvl]!,
                selected: lvl == selected,
                onTap: () => onSelect(lvl),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _DialOption extends StatelessWidget {
  const _DialOption({
    required this.level,
    required this.hint,
    required this.selected,
    required this.onTap,
  });

  final OrificeLevel level;
  final String hint;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final border = selected ? cs.primary : cs.outlineVariant;
    final bg = selected ? cs.primary.withValues(alpha: 0.10) : Colors.transparent;
    final titleColor = selected ? cs.primary : cs.onSurface;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: bg,
          border: Border.all(color: border, width: selected ? 2 : 1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Text(
              '${level.stage}단',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: titleColor,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              level.label,
              style: TextStyle(
                fontSize: 12,
                color: cs.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              hint,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: selected ? cs.primary : cs.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────── 훈련 시간 선택 ───────────────────────────
class _DurationCard extends StatelessWidget {
  const _DurationCard({required this.selected, required this.onSelect});

  final int selected;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: '훈련 시간',
      child: Wrap(
        spacing: 8,
        children: [
          for (final m in TrainDurationStore.options)
            ChoiceChip(
              label: Text('$m분'),
              selected: m == selected,
              onSelected: (_) => onSelect(m),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────── 목표 압력 미리보기 ───────────────────────────
class _TargetPreviewCard extends StatelessWidget {
  const _TargetPreviewCard({
    required this.dial,
    required this.exhaleLow,
    required this.exhaleHigh,
    required this.inhaleLow,
    required this.inhaleHigh,
  });

  final OrificeLevel dial;
  final double exhaleLow;
  final double exhaleHigh;
  final double inhaleLow;
  final double inhaleHigh;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: '목표 압력',
      subtitle: '다이얼 ${dial.stage}단에 맞춰 자동 조정됩니다',
      child: Column(
        children: [
          _PreviewRow(
            label: '내쉬기 (날숨)',
            value: '${exhaleLow.round()} ~ ${exhaleHigh.round()} cmH₂O',
            color: const Color(0xFF0A89FC),
          ),
          const SizedBox(height: 10),
          _PreviewRow(
            label: '들이쉬기 (들숨)',
            value: '${inhaleLow.round()} ~ ${inhaleHigh.round()} cmH₂O',
            color: const Color(0xFF32B65E),
          ),
        ],
      ),
    );
  }
}

class _PreviewRow extends StatelessWidget {
  const _PreviewRow({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 10),
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: cs.onSurface,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: cs.onSurface,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────── 공통 섹션 카드 ───────────────────────────
class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    this.subtitle,
    required this.child,
  });

  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: cs.onSurface,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 2),
              Text(
                subtitle!,
                style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
              ),
            ],
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────── 추천 배너 ───────────────────────────
class _RecommendationBanner extends StatelessWidget {
  const _RecommendationBanner({required this.rec, required this.onApply});

  final TrainingRecommendation rec;
  final VoidCallback onApply;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
      decoration: BoxDecoration(
        color: cs.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.primary.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Icon(Icons.auto_awesome, color: cs.primary, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '추천: ${rec.summary}',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: cs.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  rec.reason,
                  style: TextStyle(
                    fontSize: 12,
                    color: cs.onSurfaceVariant,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          FilledButton.tonal(
            onPressed: onApply,
            style: FilledButton.styleFrom(
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 14),
            ),
            child: const Text('적용'),
          ),
        ],
      ),
    );
  }
}
