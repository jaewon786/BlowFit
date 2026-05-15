// 대기 화면 (Standby) — implementation.

#include "display/screens/screen_standby.h"
#include "display/theme.h"
#include "config.h"

#include <lvgl.h>
#include <cstdio>

namespace screens {

namespace {

  // 화면 위젯 핸들 (status 갱신 시 사용).
  lv_obj_t* g_lbl_ble    = nullptr;
  lv_obj_t* g_lbl_batt   = nullptr;
  lv_obj_t* g_lbl_status = nullptr;

  /// 마우스피스 원형 일러스트 그리기 — LVGL 원 + 가운데 흰 점.
  void draw_mouthpiece_icon(lv_obj_t* parent, int center_y) {
    // 외곽 큰 원 (마우스피스 입구 — 진한 파랑)
    lv_obj_t* outer = lv_obj_create(parent);
    lv_obj_set_size(outer, 80, 80);
    lv_obj_align(outer, LV_ALIGN_TOP_MID, 0, center_y - 40);
    lv_obj_set_style_radius(outer, LV_RADIUS_CIRCLE, 0);
    lv_obj_set_style_bg_color(outer, theme::color(theme::BLUE_500), 0);
    lv_obj_set_style_border_width(outer, 0, 0);
    lv_obj_set_style_pad_all(outer, 0, 0);
    lv_obj_clear_flag(outer, LV_OBJ_FLAG_SCROLLABLE);

    // 내부 작은 원 (구멍 — 어두운 파랑)
    lv_obj_t* hole = lv_obj_create(outer);
    lv_obj_set_size(hole, 36, 36);
    lv_obj_center(hole);
    lv_obj_set_style_radius(hole, LV_RADIUS_CIRCLE, 0);
    lv_obj_set_style_bg_color(hole, theme::color(theme::BLUE_600), 0);
    lv_obj_set_style_border_width(hole, 0, 0);
    lv_obj_set_style_pad_all(hole, 0, 0);
    lv_obj_clear_flag(hole, LV_OBJ_FLAG_SCROLLABLE);
  }

}  // anonymous namespace

void standby_show() {
  lv_obj_t* scr = lv_screen_active();
  lv_obj_clean(scr);   // 기존 자식 위젯 모두 제거
  lv_obj_set_style_bg_color(scr, theme::color(theme::GRAY_900), 0);
  lv_obj_set_style_pad_all(scr, 0, 0);

  // -------- 상단 status bar (가로 row) --------
  // 좌측 BLE 표시
  g_lbl_ble = lv_label_create(scr);
  lv_label_set_text(g_lbl_ble, "BLE");
  lv_obj_set_style_text_font(g_lbl_ble, theme::font_14(), 0);
  lv_obj_set_style_text_color(g_lbl_ble, theme::color(theme::GRAY_400), 0);
  lv_obj_align(g_lbl_ble, LV_ALIGN_TOP_LEFT, 10, 10);

  // 우측 배터리 표시
  g_lbl_batt = lv_label_create(scr);
  lv_label_set_text(g_lbl_batt, "-- %");
  lv_obj_set_style_text_font(g_lbl_batt, theme::font_14(), 0);
  lv_obj_set_style_text_color(g_lbl_batt, theme::color(theme::GRAY_400), 0);
  lv_obj_align(g_lbl_batt, LV_ALIGN_TOP_RIGHT, -10, 10);

  // -------- 중앙 로고 --------
  lv_obj_t* lbl_title = lv_label_create(scr);
  lv_label_set_text(lbl_title, "BlowFit");
  lv_obj_set_style_text_font(lbl_title, theme::font_28(), 0);
  lv_obj_set_style_text_color(lbl_title, theme::color(0xFFFFFF), 0);
  lv_obj_align(lbl_title, LV_ALIGN_TOP_MID, 0, 50);

  lv_obj_t* lbl_ver = lv_label_create(scr);
  lv_label_set_text(lbl_ver, "v4.0");
  lv_obj_set_style_text_font(lbl_ver, theme::font_20(), 0);
  lv_obj_set_style_text_color(lbl_ver, theme::color(theme::BLUE_400), 0);
  lv_obj_align(lbl_ver, LV_ALIGN_TOP_MID, 0, 86);

  // -------- 중간 마우스피스 일러스트 --------
  draw_mouthpiece_icon(scr, 170);

  // -------- 하단 안내문 + 상태 --------
  lv_obj_t* lbl_hint = lv_label_create(scr);
  lv_label_set_text(lbl_hint, "입에 무세요");
  lv_obj_set_style_text_font(lbl_hint, theme::font_20(), 0);
  lv_obj_set_style_text_color(lbl_hint, theme::color(0xFFFFFF), 0);
  lv_obj_align(lbl_hint, LV_ALIGN_BOTTOM_MID, 0, -56);

  g_lbl_status = lv_label_create(scr);
  lv_label_set_text(g_lbl_status, "연결 대기 중");
  lv_obj_set_style_text_font(g_lbl_status, theme::font_14(), 0);
  lv_obj_set_style_text_color(g_lbl_status, theme::color(theme::GRAY_400), 0);
  lv_obj_align(g_lbl_status, LV_ALIGN_BOTTOM_MID, 0, -24);
}

void standby_set_connected(bool connected) {
  if (g_lbl_ble) {
    lv_obj_set_style_text_color(
        g_lbl_ble,
        theme::color(connected ? theme::BLUE_400 : theme::GRAY_400),
        0);
  }
  if (g_lbl_status) {
    lv_label_set_text(g_lbl_status, connected ? "연결됨" : "연결 대기 중");
    lv_obj_set_style_text_color(
        g_lbl_status,
        theme::color(connected ? theme::GREEN_500 : theme::GRAY_400),
        0);
  }
}

void standby_set_battery(int8_t percent) {
  if (!g_lbl_batt) return;
  if (percent < 0) {
    lv_label_set_text(g_lbl_batt, "-- %");
    return;
  }
  char buf[8];
  std::snprintf(buf, sizeof(buf), "%d%%", percent);
  lv_label_set_text(g_lbl_batt, buf);

  // 컬러: 30% 이하 = 빨강, 그 외 = 회색
  const uint32_t color = (percent <= 30) ? theme::RED_500 : theme::GRAY_400;
  lv_obj_set_style_text_color(g_lbl_batt, theme::color(color), 0);
}

}  // namespace screens
