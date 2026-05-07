// 호흡 압력 → 풍선 크기 누적 로직 (pure).
//
// 디자이너의 .riv 가 풍선 size input 을 노출하기 전까지의 placeholder. 매
// 압력 샘플마다 호출 (`onSample` 핸들러 안) — 호기 시 +, 흡기 시 −, 그 외엔
// 유지. 결과는 [0, 1] 범위로 클램프되며 호흡이 멈추면 그 크기 유지.
//
// 차후 Rive 풍선이 추가되면 이 helper 결과를 그 .riv 의 Number input 으로
// 보내거나, 또는 Rive 측에서 자체적으로 pressure → size 처리 후 이 헬퍼는
// 폐기.

/// 압력 샘플 한 개로 풍선 크기를 갱신.
///
/// - `pressureCmH2O > +threshold` (호기, 기본 +5) → 비례적으로 커짐
/// - `pressureCmH2O < −threshold` (흡기, 차후 활성화) → 비례적으로 작아짐
/// - 그 외 (-threshold ~ +threshold) → 변화 없음 (호흡 멈춤 시 유지)
///
/// `rate` 는 사이클당 변화율 — 20Hz 샘플 기준 0.015 = 약 3초에 0→1 (full
/// 호기). `softMax` 는 비례 계산의 분모 — pressure 가 threshold + softMax
/// 이상이면 최대 속도 (factor 1.0).
double accumulateBalloon(
  double current,
  double pressureCmH2O, {
  double threshold = 5.0,
  double rate = 0.015,
  double softMax = 25.0,
}) {
  if (pressureCmH2O > threshold) {
    final excess = (pressureCmH2O - threshold) / softMax;
    final factor = excess.clamp(0.0, 1.0);
    return (current + rate * factor).clamp(0.0, 1.0);
  }
  if (pressureCmH2O < -threshold) {
    final excess = (-pressureCmH2O - threshold) / softMax;
    final factor = excess.clamp(0.0, 1.0);
    return (current - rate * factor).clamp(0.0, 1.0);
  }
  return current;
}
