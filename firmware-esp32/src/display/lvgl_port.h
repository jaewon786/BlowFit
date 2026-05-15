// LVGL <-> TFT_eSPI 통합 layer.
//
// 책임:
//   1) lv_init() + 더블 버퍼 할당 (PSRAM 활용)
//   2) lv_display_t* 생성 + flush 콜백 등록
//   3) TFT_eSPI 인스턴스 init + setRotation(세로)
//   4) loop() 에서 호출할 tick handler
//
// tick 은 lv_conf.h 의 LV_TICK_CUSTOM=1 + LV_TICK_CUSTOM_SYS_TIME_EXPR(millis())
// 으로 자동 공급되므로 별도 lv_tick_inc() 호출 불필요.

#pragma once

namespace lvgl_port {

  /// LVGL + TFT 초기화 — setup() 의 boot 단계에서 한 번 호출.
  /// 호출 전에 TFT 전원 (TFT_POWER_ON HIGH) 이 설정되어 있어야 함.
  void begin();

  /// loop() 에서 매번 호출 — LVGL 의 timer/animation/redraw 처리.
  void tick();

}  // namespace lvgl_port
