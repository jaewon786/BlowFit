// 상단 거리 진행 바 — 0 / 1500m.
//
// 좌측에 현재 거리, 우측에 목표 거리. 가운데 가로 progress bar.

import 'package:flutter/material.dart';

import '../../../core/theme/blowfit_colors.dart';

class ProgressBarTop extends StatelessWidget {
  const ProgressBarTop({
    super.key,
    required this.currentMeters,
    required this.targetMeters,
    this.embedded = false,
  });

  final double currentMeters;
  final double targetMeters;

  /// true 면 외부 카드 (배경 + 그림자 + radius) 없이 content 만 — 통합 HUD 안에
  /// 다른 위젯들과 같이 들어갈 때 사용.
  final bool embedded;

  @override
  Widget build(BuildContext context) {
    final ratio = targetMeters <= 0
        ? 0.0
        : (currentMeters / targetMeters).clamp(0.0, 1.0);
    final cur = currentMeters.clamp(0, targetMeters).round();
    final tgt = targetMeters.round();

    final content = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(
                Icons.flag_outlined,
                size: 14,
                color: BlowfitColors.ink2,
              ),
              const SizedBox(width: 4),
              const Text(
                '진행 거리',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: BlowfitColors.ink2,
                ),
              ),
              const Spacer(),
              Text(
                '$cur',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: BlowfitColors.blue500,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
              Text(
                ' / $tgt m',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: BlowfitColors.ink,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              height: 8,
              child: Stack(
                children: [
                  Container(color: BlowfitColors.gray150),
                  FractionallySizedBox(
                    widthFactor: ratio,
                    heightFactor: 1,
                    child: Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            BlowfitColors.blue400,
                            BlowfitColors.blue500,
                          ],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      );

    if (embedded) return content;
    return Container(
      decoration: BoxDecoration(
        color: const Color.fromRGBO(255, 255, 255, 0.92),
        borderRadius: BorderRadius.circular(BlowfitRadius.lg),
        boxShadow: BlowfitColors.shadowLevel1,
      ),
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
      child: content,
    );
  }
}
