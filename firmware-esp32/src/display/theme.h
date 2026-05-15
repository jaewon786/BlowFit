// BlowFit 디자인 토큰 — 색상 + 폰트.
// Flutter 앱 (app/lib/core/theme/blowfit_colors.dart) 와 일관성 유지.
//
// 폰트는 LVGL extern declaration. 실제 정의는 fonts/ 디렉토리의 .c 파일에.

#pragma once

#include <lvgl.h>

// ============================================================================
// 폰트 (Pretendard Bold subset — 한글 + ASCII)
// ============================================================================
LV_FONT_DECLARE(lv_font_pretendard_b_14);
LV_FONT_DECLARE(lv_font_pretendard_b_20);
LV_FONT_DECLARE(lv_font_pretendard_b_28);

namespace theme {

  // 자주 쓰는 폰트 alias.
  inline const lv_font_t* font_14()  { return &lv_font_pretendard_b_14; }
  inline const lv_font_t* font_20()  { return &lv_font_pretendard_b_20; }
  inline const lv_font_t* font_28()  { return &lv_font_pretendard_b_28; }
  // 큰 숫자 (영문/숫자 전용) — LVGL Montserrat 48pt.
  inline const lv_font_t* font_big() { return &lv_font_montserrat_48; }

  // ==========================================================================
  // 색상 토큰 (Flutter blowfit_colors.dart 와 동일)
  // ==========================================================================

  // Brand — Blue
  constexpr uint32_t BLUE_50    = 0xEBF2FF;
  constexpr uint32_t BLUE_100   = 0xD6E4FF;
  constexpr uint32_t BLUE_400   = 0x5C8CFF;
  constexpr uint32_t BLUE_500   = 0x0066FF;  // primary
  constexpr uint32_t BLUE_600   = 0x0052CC;

  // 흡기 컬러 — Purple/Magenta
  constexpr uint32_t PURPLE_400 = 0xB084F2;
  constexpr uint32_t PURPLE_500 = 0x7C3AED;

  // Semantic
  constexpr uint32_t GREEN_500  = 0x00BF40;
  constexpr uint32_t GREEN_INK  = 0x006B25;
  constexpr uint32_t AMBER_500  = 0xFFA800;
  constexpr uint32_t AMBER_BG   = 0xFFF3DA;
  constexpr uint32_t RED_500    = 0xFF3B30;

  // Neutral
  constexpr uint32_t GRAY_900   = 0x111111;
  constexpr uint32_t GRAY_700   = 0x333333;
  constexpr uint32_t GRAY_500   = 0x767676;
  constexpr uint32_t GRAY_400   = 0xA1A1A1;
  constexpr uint32_t GRAY_300   = 0xC4C4C4;
  constexpr uint32_t GRAY_150   = 0xEEEEEE;
  constexpr uint32_t GRAY_50    = 0xFAFAFA;

  // Surface
  constexpr uint32_t BG         = 0xF5F6F8;
  constexpr uint32_t CARD       = 0xFFFFFF;
  constexpr uint32_t INK        = 0x111111;
  constexpr uint32_t INK_2      = 0x4B5563;
  constexpr uint32_t INK_3      = 0x6B7280;

  // ==========================================================================
  // 컬러 helper — uint32_t → lv_color_t
  // ==========================================================================
  inline lv_color_t color(uint32_t hex) {
    return lv_color_hex(hex);
  }

}  // namespace theme
