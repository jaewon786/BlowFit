#pragma once

#include <stdint.h>

namespace button {

enum class Press : uint8_t {
  None,
  Short,
  Long,
};

void begin();

// Scan the button; returns Short/Long on release, None otherwise.
// Call every ui_cfg::BUTTON_SCAN_MS.
Press scan(uint32_t nowMs);

}  // namespace button
