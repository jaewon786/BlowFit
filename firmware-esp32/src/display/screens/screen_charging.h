// 충전 화면 (Charging) — device-display.jsx ScrCharging.
#pragma once

#include <cstdint>

namespace screens {

/// 충전 화면 표시 (트리거: battery::isCharging()). 충전 중엔 실제 잔량을 알 수
/// 없어 % 숫자 없이 "충전 중" 애니메이션만 표시.
void charging_show();

}  // namespace screens
