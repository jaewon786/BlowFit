// 충전 화면 (Charging) — device-display.jsx ScrCharging.
#pragma once

#include <cstdint>

namespace screens {

/// 충전 화면 표시. (트리거: USB 충전 감지 — 후속 충전 감지 연동)
void charging_show(uint8_t battery_pct);

}  // namespace screens
