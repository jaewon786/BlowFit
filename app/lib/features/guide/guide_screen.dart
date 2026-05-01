import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/ble/blowfit_uuids.dart';
import '../../core/db/db_providers.dart';

/// Single training phase shown as a numbered list item.
class _Phase {
  final String title;
  final String duration;
  final String description;

  const _Phase({
    required this.title,
    required this.duration,
    required this.description,
  });
}

/// 시작 4분 + 휴식 30초 사이클을 3회 반복 = 약 13분.
/// (펌웨어 [config.h] 의 REST_MS 와는 별도로 가이드 표기 기준이며, 실제 훈련
/// 시간은 기기 펌웨어가 제어함.)
const _phases = <_Phase>[
  _Phase(
    title: '시작',
    duration: '4분',
    description: '호기 압력을 목표 구간(20-30 cmH₂O)에 유지하세요',
  ),
  _Phase(
    title: '휴식',
    duration: '30초',
    description: '자연스럽게 편안한 호흡으로 회복합니다',
  ),
  _Phase(
    title: '반복',
    duration: '총 3회',
    description: '시작과 휴식 단계를 3회 반복합니다',
  ),
];

/// 0~3주: 4mm, 4~7주: 3mm, 8주+: 2mm.
({OrificeLevel level, String label, String description, String diameter})
_recommendOrifice(int weeksUsing) {
  if (weeksUsing < 4) {
    return (
      level: OrificeLevel.low,
      label: '저강도',
      description: '입문 단계 (1~4주차)',
      diameter: '4.0mm',
    );
  } else if (weeksUsing < 8) {
    return (
      level: OrificeLevel.medium,
      label: '중강도',
      description: '기본 단계 (5~8주차)',
      diameter: '3.0mm',
    );
  } else {
    return (
      level: OrificeLevel.high,
      label: '고강도',
      description: '심화 단계 (9~12주차)',
      diameter: '2.0mm',
    );
  }
}

class GuideScreen extends ConsumerWidget {
  const GuideScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final firstDateAsync = ref.watch(firstSessionDateProvider);
    final firstDate = firstDateAsync.valueOrNull;
    final weeksUsing = firstDate == null
        ? 0
        : DateTime.now().difference(firstDate).inDays ~/ 7;
    final orifice = _recommendOrifice(weeksUsing);
    final isFirstTime = firstDate == null;

    return Scaffold(
      appBar: AppBar(title: const Text('훈련 가이드')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              '훈련 단계 (총 약 13분)',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  children: [
                    for (var i = 0; i < _phases.length; i++) ...[
                      _PhaseRow(index: i + 1, phase: _phases[i]),
                      if (i < _phases.length - 1)
                        const Divider(height: 1, indent: 60, endIndent: 16),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              '오리피스 교체 가이드',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 12),
            _OrificeCard(
              orifice: orifice,
              isFirstTime: isFirstTime,
              weeksUsing: weeksUsing,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () => context.push('/training'),
              icon: const Icon(Icons.play_arrow),
              label: const Text('훈련 시작'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PhaseRow extends StatelessWidget {
  const _PhaseRow({required this.index, required this.phase});
  final int index;
  final _Phase phase;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: primary.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Text(
              '$index',
              style: TextStyle(
                color: primary,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      phase.title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '(${phase.duration})',
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.black54,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  phase.description,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Colors.black54,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OrificeCard extends StatelessWidget {
  const _OrificeCard({
    required this.orifice,
    required this.isFirstTime,
    required this.weeksUsing,
  });

  final ({OrificeLevel level, String label, String description, String diameter}) orifice;
  final bool isFirstTime;
  final int weeksUsing;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Orifice disc illustration (placeholder via concentric circles).
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: primary.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    color: primary,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '현재 추천',
                    style: TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        orifice.label,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '(${orifice.diameter})',
                        style: const TextStyle(
                          fontSize: 13,
                          color: Colors.black54,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isFirstTime
                        ? '처음 사용하시는군요 — 가장 가벼운 단계로 시작합니다'
                        : '${orifice.description} · 훈련 ${weeksUsing}주차',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.black54,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
