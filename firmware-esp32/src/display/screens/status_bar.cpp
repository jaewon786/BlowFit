// 공용 상단 status bar — implementation.

#include "display/screens/status_bar.h"
#include "display/theme.h"
#include "config.h"

#include <lvgl.h>

namespace screens {

void make_status_bar(lv_obj_t* parent, bool connected, int battery_pct) {
  lv_obj_t* bar = lv_obj_create(parent);
  lv_obj_set_size(bar, display::SCREEN_W, 26);
  lv_obj_align(bar, LV_ALIGN_TOP_MID, 0, 0);
  lv_obj_set_style_bg_opa(bar, LV_OPA_TRANSP, 0);
  lv_obj_set_style_border_width(bar, 0, 0);
  lv_obj_set_style_pad_hor(bar, 6, 0);
  lv_obj_set_style_pad_ver(bar, 3, 0);
  lv_obj_clear_flag(bar, LV_OBJ_FLAG_SCROLLABLE);

  // 좌측 — BT 아이콘 (Montserrat 심볼). 연결=primary, 미연결=muted.
  lv_obj_t* bt = lv_label_create(bar);
  lv_label_set_text(bt, LV_SYMBOL_BLUETOOTH);
  lv_obj_set_style_text_font(bt, &lv_font_montserrat_20, 0);
  lv_obj_set_style_text_color(
      bt, theme::color(connected ? theme::DEV_PRIMARY : theme::DEV_TEXT_MUTE), 0);
  lv_obj_align(bt, LV_ALIGN_LEFT_MID, 0, 2);

  const int p = battery_pct < 0 ? -1 : (battery_pct > 100 ? 100 : battery_pct);

  // 우측 — 배터리 아이콘 = 본체 박스 + 우측 단자 nub (디자인 DStatusBar).
  // 단자 nub (작은 돌기) — 가장 오른쪽, 본체에 붙임.
  lv_obj_t* nub = lv_obj_create(bar);
  lv_obj_set_size(nub, 2, 5);
  lv_obj_align(nub, LV_ALIGN_RIGHT_MID, -2, 0);
  lv_obj_set_style_bg_color(nub, theme::color(theme::DEV_TEXT_SUB), 0);
  lv_obj_set_style_bg_opa(nub, LV_OPA_COVER, 0);
  lv_obj_set_style_border_width(nub, 0, 0);
  lv_obj_set_style_radius(nub, 1, 0);
  lv_obj_clear_flag(nub, LV_OBJ_FLAG_SCROLLABLE);

  // 본체 외곽 박스 (숫자 % 표기 없음, 아이콘만).
  lv_obj_t* box = lv_obj_create(bar);
  lv_obj_set_size(box, 22, 11);
  lv_obj_align(box, LV_ALIGN_RIGHT_MID, -4, 0);
  lv_obj_set_style_bg_opa(box, LV_OPA_TRANSP, 0);
  lv_obj_set_style_border_color(box, theme::color(theme::DEV_TEXT_SUB), 0);
  lv_obj_set_style_border_width(box, 1, 0);
  lv_obj_set_style_radius(box, 2, 0);
  lv_obj_set_style_pad_all(box, 1, 0);
  lv_obj_clear_flag(box, LV_OBJ_FLAG_SCROLLABLE);

  // 배터리 내부 fill (잔량 비례, 색상: <=15 red / <=30 amber / else green).
  // fill 최대 폭 = 박스 내부 폭 = 22 − 테두리(2) − pad(2) = 18px.
  // (이전엔 14px 라 100% 여도 ~78% 만 차 보이던 버그.)
  constexpr int FILL_MAX_W = 18;
  lv_obj_t* fill = lv_obj_create(box);
  int w = (p < 0) ? 0 : (p * FILL_MAX_W) / 100;
  if (w < 1 && p > 0) w = 1;
  lv_obj_set_size(fill, w, 7);
  lv_obj_align(fill, LV_ALIGN_LEFT_MID, 0, 0);
  uint32_t c = (p <= 15) ? theme::DEV_RED
             : (p <= 30) ? theme::DEV_AMBER
                         : theme::DEV_GREEN;
  lv_obj_set_style_bg_color(fill, theme::color(c), 0);
  lv_obj_set_style_bg_opa(fill, LV_OPA_COVER, 0);
  lv_obj_set_style_border_width(fill, 0, 0);
  lv_obj_set_style_radius(fill, 1, 0);
  lv_obj_clear_flag(fill, LV_OBJ_FLAG_SCROLLABLE);
}

}  // namespace screens
