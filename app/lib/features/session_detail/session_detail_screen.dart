import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/db/app_database.dart';
import '../../core/db/db_providers.dart';

class SessionDetailScreen extends ConsumerWidget {
  const SessionDetailScreen({super.key, required this.sessionId});
  final int sessionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionAsync = ref.watch(sessionByIdProvider(sessionId));

    return Scaffold(
      appBar: AppBar(title: const Text('세션 기록')),
      body: SafeArea(
        child: sessionAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('불러올 수 없음: $e')),
          data: (s) {
            if (s == null) {
              return const Center(
                child: Text(
                  '세션을 찾을 수 없습니다.',
                  style: TextStyle(color: Colors.black54),
                ),
              );
            }
            return _SessionBody(session: s);
          },
        ),
      ),
    );
  }
}

class _SessionBody extends StatelessWidget {
  const _SessionBody({required this.session});
  final Session session;

  @override
  Widget build(BuildContext context) {
    final when = session.startedAt ?? session.receivedAt;
    final dateLine = DateFormat('y.MM.dd (E)', 'ko').format(when);
    final orificeLabel = _orificeLabel(session.orificeLevel);
    final comment = _analysisComment(session);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Text(
              dateLine,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                orificeLabel,
                style: const TextStyle(fontSize: 11, color: Colors.black54),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              children: [
                _StatRow(
                  icon: Icons.show_chart,
                  label: '최대 압력',
                  value: '${session.maxPressure.toStringAsFixed(1)} cmH₂O',
                ),
                _div(),
                _StatRow(
                  icon: Icons.linear_scale,
                  label: '평균 압력',
                  value: '${session.avgPressure.toStringAsFixed(1)} cmH₂O',
                ),
                _div(),
                _StatRow(
                  icon: Icons.timer_outlined,
                  label: '지구력 시간',
                  value: _fmt(Duration(seconds: session.enduranceSec)),
                ),
                _div(),
                _StatRow(
                  icon: Icons.access_time,
                  label: '훈련 시간',
                  value: _fmt(Duration(seconds: session.durationSec)),
                ),
                _div(),
                _StatRow(
                  icon: Icons.fitness_center,
                  label: '성공 횟수',
                  value: '${session.targetHits}회',
                  hint: '15초 이상 유지 기준',
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          '분석 코멘트',
          style: TextStyle(
            fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              comment,
              style: const TextStyle(
                fontSize: 14, color: Colors.black87, height: 1.5,
              ),
            ),
          ),
        ),
      ],
    );
  }

  static Widget _div() => const Divider(height: 1, indent: 56, endIndent: 16);

  String _orificeLabel(int level) {
    switch (level) {
      case 0: return '저강도 (4mm)';
      case 1: return '중강도 (3mm)';
      case 2: return '고강도 (2mm)';
      default: return '단계 $level';
    }
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  String _analysisComment(Session s) {
    if (s.targetHits >= 4) {
      return '오늘도 목표를 잘 달성했어요! 꾸준한 훈련이 가장 중요합니다.';
    } else if (s.targetHits >= 2) {
      return '준수한 결과입니다. 다음 세션에는 목표 구간(20-30 cmH₂O)을 더 길게 유지해보세요.';
    } else if (s.targetHits >= 1) {
      return '한 번 성공했네요. 어느 정도의 압력이 편한지 감을 잡았다면, 다음에는 시간을 늘려봅시다.';
    } else {
      return '오늘은 목표 구간 유지가 어려웠어요. 한 단계 가벼운 오리피스로 시작해보거나, 호흡을 더 깊게 가져가세요.';
    }
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow({
    required this.icon,
    required this.label,
    required this.value,
    this.hint,
  });
  final IconData icon;
  final String label;
  final String value;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 28, height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: primary.withOpacity(0.10),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 16, color: primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 14, color: Colors.black87,
                  ),
                ),
                if (hint != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    hint!,
                    style: const TextStyle(fontSize: 11, color: Colors.black45),
                  ),
                ],
              ],
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}
