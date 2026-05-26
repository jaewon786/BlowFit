import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/ble/ble_providers.dart';
import '../../core/storage/storage_providers.dart';
import '../../core/theme/blowfit_colors.dart';
import '../../core/theme/blowfit_widgets.dart';

/// 훈련 시작 전 페이지 (디자인 v2 의 05 — `screens/training.jsx`
/// `TrainingIntroScreen`).
///
/// 흐름: 홈 CTA → /training-intro → 사용자가 자세 잡고 "훈련 시작" 누름
/// → /training (실시간) → /result.
class TrainingIntroScreen extends ConsumerWidget {
  const TrainingIntroScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connected = ref.watch(connectionProvider).valueOrNull ?? false;
    final state = ref.watch(deviceStateProvider).valueOrNull;
    final orifice = state?.orificeLevel ?? 1;
    final zone = ref
        .watch(targetSettingsStoreProvider)
        .valueOrNull
        ?.load();
    final low = zone?.low ?? 20;
    final high = zone?.high ?? 30;

    return Scaffold(
      backgroundColor: BlowfitColors.bg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: const Text('훈련 시작'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                children: [
                  _SessionInfoCard(
                    orificeLevel: orifice,
                    targetLow: low,
                    targetHigh: high,
                  ),
                  const SizedBox(height: 12),
                  _Checklist(
                    connected: connected,
                    orificeLevel: orifice,
                  ),
                  const SizedBox(height: 12),
                  const _TipCard(),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  // 연결됐을 때만 활성. 미연결이면 페어링 화면으로.
                  onPressed: connected
                      ? () => context.push('/training')
                      : () => context.push('/connect'),
                  icon: Icon(
                      connected ? Icons.play_arrow : Icons.bluetooth_searching),
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
}

// ---------------------------------------------------------------------------
// 오늘의 세션 카드 — 큰 제목 + 3 column 정보 그리드
// ---------------------------------------------------------------------------

class _SessionInfoCard extends StatelessWidget {
  const _SessionInfoCard({
    required this.orificeLevel,
    required this.targetLow,
    required this.targetHigh,
  });

  final int orificeLevel;
  final int targetLow;
  final int targetHigh;

  @override
  Widget build(BuildContext context) {
    return BlowfitCard(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      child: Column(
        children: [
          const Text(
            '오늘의 세션',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: BlowfitColors.blue500,
              letterSpacing: 0.36,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            '5분 양방향 호흡 훈련',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: BlowfitColors.ink,
              letterSpacing: -0.44,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            '흡기 30초 · 호기 30초 · 3세트',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: BlowfitColors.ink3,
            ),
          ),
          const SizedBox(height: 14),
          Container(
            decoration: BoxDecoration(
              color: BlowfitColors.gray50,
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
            child: IntrinsicHeight(
              child: Row(
                children: [
                  Expanded(
                    child: _InfoTile(
                      label: '다이얼',
                      value: '${orificeLevel + 1}단',
                    ),
                  ),
                  const _InfoDivider(),
                  const Expanded(
                    child: _InfoTile(
                      label: '총 시간',
                      value: '5:00',
                    ),
                  ),
                  const _InfoDivider(),
                  Expanded(
                    child: _InfoTile(
                      label: '목표',
                      value: '±$targetHigh',
                    ),
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

class _InfoTile extends StatelessWidget {
  const _InfoTile({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: BlowfitColors.ink3,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.w700,
            color: BlowfitColors.ink,
            letterSpacing: -0.38,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}

class _InfoDivider extends StatelessWidget {
  const _InfoDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      color: BlowfitColors.gray150,
      margin: const EdgeInsets.symmetric(horizontal: 4),
    );
  }
}

// ---------------------------------------------------------------------------
// 시작 전 체크리스트 — 4개 항목
// ---------------------------------------------------------------------------

class _Checklist extends StatelessWidget {
  const _Checklist({
    required this.connected,
    required this.orificeLevel,
  });

  final bool connected;
  final int orificeLevel;

  @override
  Widget build(BuildContext context) {
    final items = <_ChecklistItem>[
      _ChecklistItem(
        ok: connected,
        text: connected
            ? '디바이스가 연결되어 있어요'
            : '디바이스가 연결되어 있지 않아요',
      ),
      _ChecklistItem(
        ok: connected,
        text: connected
            ? '다이얼이 ${orificeLevel + 1}단으로 설정되어 있어요'
            : '다이얼 단계 확인이 필요해요',
      ),
      const _ChecklistItem(
        ok: true,
        text: '마우스피스를 입에 물어주세요',
      ),
      const _ChecklistItem(
        ok: false,
        text: '편안한 자세로 앉아주세요',
      ),
    ];

    return BlowfitCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '시작 전 체크',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: BlowfitColors.ink,
            ),
          ),
          const SizedBox(height: 6),
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0)
              const Divider(height: 1, color: BlowfitColors.gray150),
            _ChecklistRow(item: items[i]),
          ],
        ],
      ),
    );
  }
}

class _ChecklistItem {
  final bool ok;
  final String text;
  const _ChecklistItem({required this.ok, required this.text});
}

class _ChecklistRow extends StatelessWidget {
  const _ChecklistRow({required this.item});
  final _ChecklistItem item;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: item.ok ? BlowfitColors.green500 : BlowfitColors.gray200,
              shape: BoxShape.circle,
            ),
            child: item.ok
                ? const Icon(Icons.check, size: 16, color: Colors.white)
                : null,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              item.text,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: item.ok ? BlowfitColors.ink : BlowfitColors.ink3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 팁 박스 — 파란 배경, 호흡 가이드
// ---------------------------------------------------------------------------

class _TipCard extends StatelessWidget {
  const _TipCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: BlowfitColors.blue50,
        borderRadius: BorderRadius.circular(BlowfitRadius.md),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Padding(
            padding: EdgeInsets.only(top: 1),
            child:
                Icon(Icons.lightbulb_outline, color: BlowfitColors.blue500, size: 18),
          ),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              // 디자인 v2 + onboarding 일관성: 양방향 호흡은 입으로.
              '입으로 천천히 들이마시고, 강하게 내쉬세요. 어깨에 힘을 빼고 배가 부풀어 오르도록 깊게 호흡하면 효과가 큽니다.',
              style: TextStyle(
                fontSize: 13,
                color: BlowfitColors.blue700,
                fontWeight: FontWeight.w500,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
