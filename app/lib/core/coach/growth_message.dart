/// 주간 성장 메시지 — 홈/추이 화면 헤드라인 공용 로직.
///
/// `weekAvgPressureProvider` 의 (이번주, 지난주) 호기 평균을 받아서 변화 방향과
/// 변화율(%)을 계산. 화면별 문구는 각 화면이 [GrowthTrend] 로 분기해서 생성한다.
library;

/// 주간 호기 평균 변화 방향.
enum GrowthTrend {
  /// 증가 (이번주 > 지난주).
  up,

  /// 감소 (이번주 < 지난주).
  down,

  /// 유지 (반올림 시 변화율 0%).
  flat,

  /// 비교 불가 — 첫 사용자거나 지난주 기록이 없음.
  noData,
}

/// 이번주/지난주 호기 평균 → (방향, 변화율%). 변화율은 항상 양수 (방향은 trend).
/// lastWeek 이 null 이거나 0 이하면 noData.
({GrowthTrend trend, int pct}) weeklyGrowth({
  double? thisWeek,
  double? lastWeek,
}) {
  if (thisWeek == null || lastWeek == null || lastWeek <= 0) {
    return (trend: GrowthTrend.noData, pct: 0);
  }
  final delta = ((thisWeek - lastWeek) / lastWeek * 100).round();
  if (delta > 0) return (trend: GrowthTrend.up, pct: delta);
  if (delta < 0) return (trend: GrowthTrend.down, pct: -delta);
  return (trend: GrowthTrend.flat, pct: 0);
}
