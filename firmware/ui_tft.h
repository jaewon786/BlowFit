#pragma once

#include <stdint.h>
#include "config.h"
#include "state_machine.h"

// ST7735 80x160 TFT renderer. Draws dirty regions only to avoid flicker
// and keep frame budget under 50 ms.

namespace ui_tft {

void begin();

// Render current state. Call every ui_cfg::RENDER_INTERVAL_MS.
void render(DeviceState s, float currentCmH2O, const state_machine::Metrics& m,
            uint32_t nowMs, uint8_t batteryPct);

// Force full redraw (e.g. on state transition).
void invalidate();

}  // namespace ui_tft
