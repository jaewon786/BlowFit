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

  // Surface (앱 라이트 테마 — 기기 화면에선 미사용)
  constexpr uint32_t BG         = 0xF5F6F8;
  constexpr uint32_t CARD       = 0xFFFFFF;
  constexpr uint32_t INK        = 0x111111;
  constexpr uint32_t INK_2      = 0x4B5563;
  constexpr uint32_t INK_3      = 0x6B7280;

  // ==========================================================================
  // 기기 화면 라이트 테마 (BlowFit.html / device-display.jsx — LVGL palette)
  //   채팅 최종 결정(chat1.md): 다크 → 연한 하늘색 라이트 테마로 전환.
  //   rgba 반투명 텍스트색은 흰 배경에 합성한 solid hex 로 근사.
  // ==========================================================================
  constexpr uint32_t DEV_BG        = 0xDCEEFF;   // screen base (연한 하늘색)
  constexpr uint32_t DEV_SURFACE   = 0xFFFFFF;   // card / container
  constexpr uint32_t DEV_SURFACE2  = 0xEAF4FF;   // raised
  constexpr uint32_t DEV_TEXT      = 0x0A2540;   // 진한 네이비
  constexpr uint32_t DEV_TEXT_SUB  = 0x5D6F81;   // ≈ rgba(10,37,64,.66) on white
  constexpr uint32_t DEV_TEXT_MUTE = 0x98A3AF;   // ≈ rgba(10,37,64,.42) on white
  constexpr uint32_t DEV_DIVIDER   = 0xE6E9EC;   // ≈ rgba(10,37,64,.10) on white
  constexpr uint32_t DEV_PRIMARY   = 0x0066FF;   // 호기 accent
  constexpr uint32_t DEV_PRIMARY_LT= 0x2F90FF;
  constexpr uint32_t DEV_CYAN      = 0x0099CC;   // 흡기 accent
  constexpr uint32_t DEV_GREEN     = 0x00A838;   // zone-hit / completion
  constexpr uint32_t DEV_GREEN_DARK= 0x006B25;   // 흡기 in-zone (진한 초록)
  constexpr uint32_t DEV_AMBER     = 0xE08600;   // rest / warning
  constexpr uint32_t DEV_RED       = 0xFF3B30;
  constexpr uint32_t DEV_YELLOW    = 0xF5B800;

  // ==========================================================================
  // 컬러 helper — uint32_t → lv_color_t
  // ==========================================================================
  inline lv_color_t color(uint32_t hex) {
    return lv_color_hex(hex);
  }

}  // namespace theme
