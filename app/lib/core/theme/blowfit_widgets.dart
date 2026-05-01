import 'package:flutter/material.dart';

import 'blowfit_colors.dart';

/// BlowFit 표준 카드 — 화이트 배경, 큰 radius, 부드러운 그림자.
///
/// Material `Card` 대신 사용. 디자인 시안의 `.bf-card` (radius 20, sh-1) 와
/// 동일하게 그려진다.
class BlowfitCard extends StatelessWidget {
  const BlowfitCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.radius = BlowfitRadius.xl,
    this.color = BlowfitColors.card,
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final container = Container(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(radius),
        boxShadow: BlowfitColors.shadowLevel1,
      ),
      child: Padding(padding: padding, child: child),
    );
    if (onTap == null) return container;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(radius),
        onTap: onTap,
        child: container,
      ),
    );
  }
}

/// 작은 라벨 칩 — `bf-chip` 의 색 변종.
enum BlowfitChipTone { neutral, blue, green, amber, red }

class BlowfitChip extends StatelessWidget {
  const BlowfitChip({
    super.key,
    required this.label,
    this.icon,
    this.tone = BlowfitChipTone.neutral,
  });

  final String label;
  final IconData? icon;
  final BlowfitChipTone tone;

  ({Color bg, Color fg}) get _colors {
    switch (tone) {
      case BlowfitChipTone.blue:
        return (bg: BlowfitColors.blue50, fg: BlowfitColors.blue600);
      case BlowfitChipTone.green:
        return (bg: BlowfitColors.green100, fg: BlowfitColors.greenInk);
      case BlowfitChipTone.amber:
        return (bg: BlowfitColors.amberBg, fg: BlowfitColors.amberInk);
      case BlowfitChipTone.red:
        return (bg: BlowfitColors.red100, fg: BlowfitColors.redInk);
      case BlowfitChipTone.neutral:
        return (bg: BlowfitColors.gray100, fg: BlowfitColors.gray700);
    }
  }

  @override
  Widget build(BuildContext context) {
    final (:bg, :fg) = _colors;
    return Container(
      height: 28,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: fg),
            const SizedBox(width: 6),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }
}

/// 연속 일수 배지 — 홈 헤더 우측에 들어가는 amber 톤 streak.
class StreakBadge extends StatelessWidget {
  const StreakBadge({super.key, required this.days});
  final int days;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 28,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: BlowfitColors.amberBg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.local_fire_department,
              size: 14, color: BlowfitColors.amberInk),
          const SizedBox(width: 6),
          Text(
            '$days일 연속',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: BlowfitColors.amberInk,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}
