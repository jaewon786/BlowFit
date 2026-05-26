// 하단 가로 압력 바 — Q4 결정: 범위 -30 ~ +30 cmH₂O.
//
// 좌측 끝 = -30 (흡기 max), 가운데 = 0, 우측 끝 = +30 (호기 max).
// 두 개의 초록색 zone:
//   - 양압 zone: [+targetLow, +targetHigh]  → 호기 시 목표
//   - 음압 zone: [-targetHigh, -targetLow]  → 흡기 시 목표
// 흰색 indicator 가 현재 압력 위치에 표시됨. zone 안이면 indicator 가 초록색.
//
// Q3 (호기/흡기 시간 분할) 정책에 따라, 흡기 phase 일 때 호출자가 [pressure] 를
// 음수로 뒤집어서 넣는다. 따라서 이 위젯은 부호 그대로 시각화만 한다.

import 'package:flutter/material.dart';

import '../../../core/theme/blowfit_colors.dart';

class PressureBarBottom extends StatelessWidget {
  const PressureBarBottom({
    super.key,
    required this.pressure,
    required this.targetLow,
    required this.targetHigh,
    this.range = 30.0,
    this.embedded = false,
  });

  /// 현재 압력 (cmH₂O). + = 호기, - = 흡기 (Q3 임시 부호 반전).
  final double pressure;

  /// 양압 목표 zone 의 하한 (양수). 음압 zone 은 [-high, -low].
  final double targetLow;
  final double targetHigh;

  /// 표시 범위. ±30 cmH₂O 가 디폴트.
  final double range;

  /// true 면 외부 카드 (배경 + 그림자 + radius) 없이 content 만 — 통합 HUD.
  final bool embedded;

  @override
  Widget build(BuildContext context) {
    final clamped = pressure.clamp(-range, range);
    final inExhaleZone = pressure >= targetLow && pressure <= targetHigh;
    final inInhaleZone = pressure <= -targetLow && pressure >= -targetHigh;
    final inZone = inExhaleZone || inInhaleZone;

    final content = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.air, size: 14, color: BlowfitColors.ink2),
              const SizedBox(width: 4),
              const Text(
                '실시간 압력',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: BlowfitColors.ink2,
                ),
              ),
              const Spacer(),
              Text(
                _formatSigned(pressure),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: inZone
                      ? BlowfitColors.green500
                      : BlowfitColors.blue500,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              const Text(
                ' cmH₂O',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: BlowfitColors.ink2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          LayoutBuilder(
            builder: (context, constraints) {
              final w = constraints.maxWidth;
              const h = 18.0;

              // x position 변환: pressure ∈ [-range, range] → [0, w].
              double xFromPressure(double p) {
                final t = (p.clamp(-range, range) + range) / (2 * range);
                return t * w;
              }

              final exhaleZoneStart = xFromPressure(targetLow);
              final exhaleZoneEnd = xFromPressure(targetHigh);
              final inhaleZoneStart = xFromPressure(-targetHigh);
              final inhaleZoneEnd = xFromPressure(-targetLow);
              final indicatorX = xFromPressure(clamped);

              return SizedBox(
                height: h + 18,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    // 회색 트랙
                    Positioned(
                      left: 0,
                      right: 0,
                      top: 0,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          height: h,
                          color: BlowfitColors.gray150,
                        ),
                      ),
                    ),
                    // 음압 zone (좌측)
                    Positioned(
                      left: inhaleZoneStart,
                      width: (inhaleZoneEnd - inhaleZoneStart).clamp(0.0, w),
                      top: 0,
                      child: Container(
                        height: h,
                        decoration: BoxDecoration(
                          color: const Color.fromRGBO(0, 191, 64, 0.45),
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                    // 양압 zone (우측)
                    Positioned(
                      left: exhaleZoneStart,
                      width: (exhaleZoneEnd - exhaleZoneStart).clamp(0.0, w),
                      top: 0,
                      child: Container(
                        height: h,
                        decoration: BoxDecoration(
                          color: const Color.fromRGBO(0, 191, 64, 0.45),
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                    // 0 baseline 점선
                    Positioned(
                      left: w / 2 - 0.5,
                      top: -2,
                      bottom: 14,
                      child: Container(
                        width: 1,
                        color: BlowfitColors.gray400,
                      ),
                    ),
                    // 현재 압력 indicator
                    Positioned(
                      left: indicatorX - 7,
                      top: -3,
                      child: Container(
                        width: 14,
                        height: h + 6,
                        decoration: BoxDecoration(
                          color: inZone
                              ? BlowfitColors.green500
                              : Colors.white,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: inZone
                                ? BlowfitColors.greenInk
                                : BlowfitColors.blue500,
                            width: 2,
                          ),
                          boxShadow: BlowfitColors.shadowLevel1,
                        ),
                      ),
                    ),
                    // 라벨 — 끝 ±range 제거. 가운데 0 + 초록 zone 범위 표시.
                    const Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: Center(
                        child: Text(
                          '0',
                          style: TextStyle(
                            fontSize: 10,
                            color: BlowfitColors.ink3,
                            fontFeatures: [FontFeature.tabularFigures()],
                          ),
                        ),
                      ),
                    ),
                    // 음압 zone 범위 (-targetHigh ~ -targetLow)
                    Positioned(
                      left: inhaleZoneStart,
                      width: (inhaleZoneEnd - inhaleZoneStart).clamp(0.0, w),
                      bottom: 0,
                      child: Text(
                        '-${targetHigh.round()}  ~  -${targetLow.round()}',
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        softWrap: false,
                        overflow: TextOverflow.visible,
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: BlowfitColors.greenInk,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                    // 양압 zone 범위 (+targetLow ~ +targetHigh)
                    Positioned(
                      left: exhaleZoneStart,
                      width: (exhaleZoneEnd - exhaleZoneStart).clamp(0.0, w),
                      bottom: 0,
                      child: Text(
                        '+${targetLow.round()}  ~  +${targetHigh.round()}',
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        softWrap: false,
                        overflow: TextOverflow.visible,
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: BlowfitColors.greenInk,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
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

  String _formatSigned(double v) {
    final sign = v >= 0 ? '+' : '';
    return '$sign${v.toStringAsFixed(1)}';
  }
}
