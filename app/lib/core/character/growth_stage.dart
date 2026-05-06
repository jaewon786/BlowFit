// 12주 성장 시스템 — 시작일로부터 경과한 주 수에 따라 캐릭터 단계 결정.
//
// State Machine 의 numeric input (예: `growthStage`) 에 enum.index 를 그대로
// 전달해서 Rive 측에서 분기. 디자이너 합의 후 단계 수/임계 주차 변경 가능.
//
// 단계 임계값 (요구사항):
//   1주차 (week 0~3) : 작은 아기 수달 / 또는 기본 모습
//   4주차 (week 4~7) : 성장한 어린 수달 / 또는 모자
//   8주차 (week 8~11): 청년 수달 / 또는 스카프
//   12주차+ (week 12+): 완전 성장 + 메달/왕관

import 'package:flutter/foundation.dart' show visibleForTesting;

enum GrowthStage {
  /// 0~3주 — 시작 단계 (아기 수달 / 기본).
  baby,

  /// 4~7주 — 안정 단계 (어린 수달 / 모자).
  young,

  /// 8~11주 — 능숙 단계 (청년 수달 / 스카프).
  adult,

  /// 12주+ — 완성 단계 (성장 완료 + 메달/왕관).
  master,
}

/// 시작일 기준 경과 주 수 → 성장 단계.
///
/// `weeksSince` 는 정수 주 (월요일 시작 가정 안함 — 단순 7일 단위로 카운트).
/// 음수면 baby 로 클램프.
GrowthStage stageFromWeeks(int weeksSince) {
  if (weeksSince < 4) return GrowthStage.baby;
  if (weeksSince < 8) return GrowthStage.young;
  if (weeksSince < 12) return GrowthStage.adult;
  return GrowthStage.master;
}

/// 시작일과 현재 시각 (기본 = `DateTime.now()`) 사이의 경과 주 수.
///
/// `startedAt` 이 미래거나 null 이면 0 반환.
int weeksSince(DateTime? startedAt, {DateTime? now}) {
  if (startedAt == null) return 0;
  final n = now ?? DateTime.now();
  if (n.isBefore(startedAt)) return 0;
  final days = n.difference(startedAt).inDays;
  return days ~/ 7;
}

/// startedAt → 단계 직접 변환 (편의 함수).
GrowthStage stageFromStartedAt(DateTime? startedAt, {DateTime? now}) {
  return stageFromWeeks(weeksSince(startedAt, now: now));
}

@visibleForTesting
int debugStageIndex(GrowthStage s) => s.index;
