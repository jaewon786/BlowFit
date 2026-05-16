// LVGL <-> TFT_eSPI 통합 — implementation.

#include "display/lvgl_port.h"

#include <Arduino.h>
#include <TFT_eSPI.h>
#include <lvgl.h>
#include <esp_heap_caps.h>

#include "config.h"

namespace lvgl_port {

namespace {

  // 디스플레이 핸들 (전역 — flush 콜백에서 접근).
  TFT_eSPI g_tft;
  lv_display_t* g_disp = nullptr;

  // 더블 버퍼 — 각 (W × N) 픽셀. N=40 줄 정도면 partial render 한 번에
  // 충분히 큰 영역 처리 + RAM 부담 작음. 170×40×2bytes = 13.6KB per buffer.
  // PSRAM 활용 (heap_caps_malloc with MALLOC_CAP_SPIRAM) — internal SRAM 절약.
  constexpr int BUF_LINES = 40;
  constexpr size_t BUF_PX  = display::SCREEN_W * BUF_LINES;
  constexpr size_t BUF_BYTES = BUF_PX * sizeof(lv_color_t);

  lv_color_t* g_buf1 = nullptr;
  lv_color_t* g_buf2 = nullptr;

  // ----- LVGL flush 콜백 -----
  // LVGL 이 partial render 한 픽셀 버퍼를 디스플레이로 전송하는 콜백.
  // area: 갱신할 사각형 영역, px_map: lv_color_t 배열 (RGB565 + lv_conf.h 의
  // LV_COLOR_16_SWAP=1 적용된 상태).
  void flush_cb(lv_display_t* disp, const lv_area_t* area, uint8_t* px_map) {
    const uint32_t w = (area->x2 - area->x1 + 1);
    const uint32_t h = (area->y2 - area->y1 + 1);

    g_tft.startWrite();
    g_tft.setAddrWindow(area->x1, area->y1, w, h);
    // pushPixels: TFT_eSPI 가 RGB565 little-endian 으로 받음. LVGL 이 SWAP
    // 했으므로 그대로 전송.
    g_tft.pushPixels(reinterpret_cast<uint16_t*>(px_map), w * h);
    g_tft.endWrite();

    lv_display_flush_ready(disp);
  }

  // ----- LVGL 로그 콜백 (선택) -----
  void log_cb(lv_log_level_t level, const char* buf) {
    (void)level;
    Serial.print("[LVGL] ");
    Serial.print(buf);
  }

  // ----- LVGL tick 콜백 -----
  // LVGL 9.x 는 lv_conf.h 의 LV_TICK_CUSTOM 매크로를 지원하지 않음. 대신
  // runtime 에 lv_tick_set_cb() 로 tick 공급 함수 등록 필요. millis() 가
  // 부팅 후 ms 단위 — LVGL 이 timer/animation/redraw 계산에 사용.
  uint32_t arduino_tick_cb() {
    return millis();
  }

}  // anonymous namespace

void begin() {
  // 1. TFT 초기화 (LDO 전원은 main.cpp 의 bootHardware() 가 먼저 처리).
  g_tft.init();
  g_tft.setRotation(display::ROTATION);   // 0 = 세로 (USB 아래)
  g_tft.fillScreen(TFT_BLACK);
  g_tft.setSwapBytes(false);  // LVGL 의 LV_COLOR_16_SWAP=1 와 호환 — TFT 는 swap 안 함

  // 2. LVGL 코어 + tick + 로그.
  lv_init();
  lv_tick_set_cb(arduino_tick_cb);   // LVGL 9.x — lv_conf.h LV_TICK_CUSTOM 대체
#if LV_USE_LOG
  lv_log_register_print_cb(log_cb);
#endif

  // 3. 더블 버퍼 할당 — PSRAM 우선, 실패 시 internal heap.
  g_buf1 = (lv_color_t*)heap_caps_malloc(BUF_BYTES, MALLOC_CAP_SPIRAM | MALLOC_CAP_8BIT);
  g_buf2 = (lv_color_t*)heap_caps_malloc(BUF_BYTES, MALLOC_CAP_SPIRAM | MALLOC_CAP_8BIT);
  if (!g_buf1 || !g_buf2) {
    Serial.println("[lvgl_port] PSRAM alloc failed — fallback to internal heap");
    if (g_buf1) heap_caps_free(g_buf1);
    if (g_buf2) heap_caps_free(g_buf2);
    g_buf1 = (lv_color_t*)heap_caps_malloc(BUF_BYTES, MALLOC_CAP_INTERNAL | MALLOC_CAP_8BIT);
    g_buf2 = (lv_color_t*)heap_caps_malloc(BUF_BYTES, MALLOC_CAP_INTERNAL | MALLOC_CAP_8BIT);
  }
  if (!g_buf1 || !g_buf2) {
    Serial.println("[lvgl_port] FATAL: buffer alloc failed");
    return;
  }
  Serial.printf("[lvgl_port] Allocated buffers: %u bytes each (%s)\n",
                (unsigned)BUF_BYTES,
                heap_caps_get_allocated_size(g_buf1) > 0 ? "PSRAM/internal" : "?");

  // 4. LVGL display 객체 생성 + 버퍼 등록.
  g_disp = lv_display_create(display::SCREEN_W, display::SCREEN_H);
  lv_display_set_buffers(g_disp, g_buf1, g_buf2, BUF_BYTES,
                         LV_DISPLAY_RENDER_MODE_PARTIAL);
  lv_display_set_flush_cb(g_disp, flush_cb);

  Serial.println("[lvgl_port] init complete");
}

void tick() {
  if (g_disp == nullptr) return;
  lv_timer_handler();
}

}  // namespace lvgl_port
