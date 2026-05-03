import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/coach/coaching_engine.dart';
import '../../core/db/db_providers.dart';
import '../../core/models/pressure_sample.dart';
import '../../core/theme/blowfit_colors.dart';
import '../../core/theme/blowfit_widgets.dart';

/// 훈련 종료 직후 표시되는 결과 화면. 디자인 시안의 06 화면 (`screens/result.jsx`).
///
/// 입력: SessionSummary (BLE 종료 알림에서 받은 데이터, training_screen 에서
/// `context.go('/result', extra: summary)` 로 전달됨).
class ResultScreen extends ConsumerWidget {
  const ResultScreen({super.key, required this.summary});

  final SessionSummary summary;

  /// 100점 기준 점수. targetHits (목표 hold 횟수) + endurance ratio.
  int get _score {
    if (summary.duration.inSeconds <= 0) return 0;
    final endRatio = summary.endurance.inMilliseconds /
        summary.duration.inMilliseconds;
    final hitsPart = (summary.targetHits.clamp(0, 5) / 5) * 50;
    final endPart = endRatio.clamp(0.0, 1.0) * 50;
    return (hitsPart + endPart).round().clamp(0, 100);
  }

  // 디자인 v2 에서 별 row 제거됨 — 점수 + 메시지만 남김.

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final score = _score;
    final endurancePct = summary.duration.inMilliseconds > 0
        ? (summary.endurance.inMilliseconds /
                summary.duration.inMilliseconds)
            .clamp(0.0, 1.0)
        : 0.0;
    // 지난 주 평균 호기와 이번 세션 호기 평균 비교 → coach note delta.
    final lastWeekAvg =
        ref.watch(weekAvgPressureProvider).valueOrNull?.lastWeek;
    final delta = lastWeekAvg != null
        ? summary.avgPressure - lastWeekAvg
        : null;

    final scoreMessage = CoachingEngine.resultScoreMessage(
      score: score,
      targetHits: summary.targetHits,
    );
    final note = CoachingEngine.resultNote(
      score: score,
      targetHits: summary.targetHits,
      endurancePct: endurancePct,
      deltaVsLastWeek: delta,
    );

    return Scaffold(
      backgroundColor: BlowfitColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            _TopBar(onClose: () => context.go('/')),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                children: [
                  _HeroScore(
                    score: score,
                    message: scoreMessage,
                  ),
                  const SizedBox(height: 14),
                  _StatsGrid(summary: summary),
                  const SizedBox(height: 14),
                  _SessionSummary(summary: summary),
                  const SizedBox(height: 14),
                  _CoachNote(tip: note),
                ],
              ),
            ),
            _BottomActions(
              onHistory: () => context.go('/history'),
              onDone: () => context.go('/'),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Top bar
// ---------------------------------------------------------------------------

class _TopBar extends StatelessWidget {
  const _TopBar({required this.onClose});
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          IconButton(
            onPressed: onClose,
            icon: const Icon(Icons.close, color: BlowfitColors.ink),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          ),
          const Spacer(),
          const Text(
            '훈련 결과',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: BlowfitColors.ink,
              letterSpacing: -0.34,
            ),
          ),
          const Spacer(),
          // 공유 버튼은 추후 — placeholder.
          SizedBox(
            width: 36,
            height: 36,
            child: TextButton(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('공유 기능은 곧 출시됩니다')),
                );
              },
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: const Size(36, 36),
              ),
              child: const Text(
                '공유',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: BlowfitColors.blue500,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Hero score — gradient blue card with circular progress (v2 에서 별 row 제거됨)
// ---------------------------------------------------------------------------

class _HeroScore extends StatelessWidget {
  const _HeroScore({
    required this.score,
    required this.message,
  });

  final int score;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(BlowfitRadius.xxl),
        gradient: const LinearGradient(
          colors: [BlowfitColors.blue500, BlowfitColors.blue700],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color.fromRGBO(0, 102, 255, 0.24),
            blurRadius: 24,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          const Text(
            '오늘의 점수',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color.fromRGBO(255, 255, 255, 0.8),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: 160,
            height: 160,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox.expand(
                  child: CircularProgressIndicator(
                    value: score / 100,
                    strokeWidth: 12,
                    strokeCap: StrokeCap.round,
                    backgroundColor:
                        const Color.fromRGBO(255, 255, 255, 0.2),
                    valueColor: const AlwaysStoppedAnimation<Color>(
                        Colors.white),
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$score',
                      style: const TextStyle(
                        fontSize: 56,
                        fontWeight: FontWeight.w700,
                        height: 1,
                        letterSpacing: -2.24,
                        color: Colors.white,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                    const Text(
                      '/ 100',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color.fromRGBO(255, 255, 255, 0.8),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // 디자인 v2 에서 별 5개 row 제거 — 점수 + 메시지만 남김.
          const SizedBox(height: 12),
          Text(
            message,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 2x2 stats grid — 호기 평균/최대, 흡기 평균/최대
// ---------------------------------------------------------------------------

class _StatsGrid extends StatelessWidget {
  const _StatsGrid({required this.summary});
  final SessionSummary summary;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _StatTile(
                label: '호기 평균',
                value: summary.avgPressure.toStringAsFixed(1),
                unit: 'cmH₂O',
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _StatTile(
                label: '호기 최대',
                value: summary.maxPressure.toStringAsFixed(1),
                unit: 'cmH₂O',
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        const Row(
          children: [
            Expanded(
              child: _StatTile(
                label: '흡기 평균',
                value: '—',
                unit: 'cmH₂O',
                placeholder: true,
              ),
            ),
            SizedBox(width: 10),
            Expanded(
              child: _StatTile(
                label: '흡기 최대',
                value: '—',
                unit: 'cmH₂O',
                placeholder: true,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.label,
    required this.value,
    required this.unit,
    this.placeholder = false,
  });

  final String label;
  final String value;
  final String unit;
  final bool placeholder;

  @override
  Widget build(BuildContext context) {
    return BlowfitCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: BlowfitColors.ink3,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.48,
                  color: placeholder
                      ? BlowfitColors.gray400
                      : BlowfitColors.ink,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(width: 4),
              Text(
                unit,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: BlowfitColors.ink3,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Session summary — 3 progress rows
// ---------------------------------------------------------------------------

class _SessionSummary extends StatelessWidget {
  const _SessionSummary({required this.summary});
  final SessionSummary summary;

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    if (d.inHours > 0) {
      return '${d.inHours}시간 $m분';
    }
    return '$m분 ${s.toString().padLeft(2, '0')}초';
  }

  @override
  Widget build(BuildContext context) {
    final endurancePct = summary.duration.inMilliseconds > 0
        ? (summary.endurance.inMilliseconds /
                summary.duration.inMilliseconds)
            .clamp(0.0, 1.0)
        : 0.0;

    return BlowfitCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '세션 요약',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: BlowfitColors.ink,
            ),
          ),
          const SizedBox(height: 12),
          _SummaryRow(
            label: '목표 구간 유지',
            value: _fmt(summary.endurance),
            pct: endurancePct,
            color: BlowfitColors.green500,
          ),
          const SizedBox(height: 12),
          _SummaryRow(
            label: '총 훈련 시간',
            value: _fmt(summary.duration),
            pct: 1,
            color: BlowfitColors.blue500,
          ),
          const SizedBox(height: 12),
          _SummaryRow(
            label: '목표 hit',
            value: '${summary.targetHits}회',
            pct: (summary.targetHits / 5).clamp(0.0, 1.0),
            color: BlowfitColors.blue500,
            last: true,
          ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.label,
    required this.value,
    required this.pct,
    required this.color,
    this.last = false,
  });

  final String label;
  final String value;
  final double pct;
  final Color color;
  final bool last;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: BlowfitColors.ink2,
              ),
            ),
            Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: BlowfitColors.ink,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: pct,
            minHeight: 6,
            backgroundColor: BlowfitColors.gray150,
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
        if (!last) const SizedBox(height: 0),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Coach note — blue50 background tip
// ---------------------------------------------------------------------------

class _CoachNote extends StatelessWidget {
  const _CoachNote({required this.tip});
  final CoachingTip tip;

  /// 톤별 카드 배경/원형/텍스트 색.
  ({Color cardBg, Color iconBg, Color text, IconData icon}) get _tokens {
    switch (tip.tone) {
      case CoachingTone.positive:
        return (
          cardBg: BlowfitColors.blue50,
          iconBg: BlowfitColors.blue500,
          text: BlowfitColors.blue700,
          icon: Icons.emoji_events,
        );
      case CoachingTone.info:
        return (
          cardBg: BlowfitColors.blue50,
          iconBg: BlowfitColors.blue500,
          text: BlowfitColors.blue700,
          icon: Icons.lightbulb_outline,
        );
      case CoachingTone.warning:
        return (
          cardBg: BlowfitColors.amberBg,
          iconBg: BlowfitColors.amber500,
          text: BlowfitColors.amberInk,
          icon: Icons.warning_amber_outlined,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = _tokens;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: t.cardBg,
        borderRadius: BorderRadius.circular(BlowfitRadius.md),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: t.iconBg,
              shape: BoxShape.circle,
            ),
            child: Icon(t.icon, color: Colors.white, size: 16),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              tip.body,
              style: TextStyle(
                fontSize: 13,
                color: t.text,
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

// ---------------------------------------------------------------------------
// Bottom actions
// ---------------------------------------------------------------------------

class _BottomActions extends StatelessWidget {
  const _BottomActions({
    required this.onHistory,
    required this.onDone,
  });

  final VoidCallback onHistory;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Row(
        children: [
          Expanded(
            flex: 1,
            child: OutlinedButton(
              onPressed: onHistory,
              style: OutlinedButton.styleFrom(
                foregroundColor: BlowfitColors.gray700,
                backgroundColor: BlowfitColors.gray100,
                side: BorderSide.none,
                minimumSize: const Size(0, 56),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                textStyle: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              child: const Text('기록 보기'),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: FilledButton(
              onPressed: onDone,
              child: const Text('완료'),
            ),
          ),
        ],
      ),
    );
  }
}
