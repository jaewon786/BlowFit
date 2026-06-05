// battery.cpp — VBAT 측정 (T-Display-S3 내장 분압, GPIO4).

#include "battery.h"
#include "config.h"

#include <Arduino.h>

namespace battery {

namespace {

  uint16_t g_mv  = 0;
  int8_t   g_pct = -1;
  bool     g_charging = false;

  // 충전 감지 임계 (hysteresis). 충전 시 측정 ~4.3V, 구동 중 배터리 단독은
  // 부하 sag 로 ~4.0V 이하라 명확히 갈림.
  constexpr uint16_t CHARGE_ENTER_MV = 4150;
  constexpr uint16_t CHARGE_EXIT_MV  = 4050;

  // LiPo 단일 셀 전압(mV) → 잔량(%) 근사 테이블.
  // ⚠️ "부하(운영) 상태 기준" 보정 — 디바이스 구동 중엔 화면/BLE 부하로 단자
  // 전압이 무부하 대비 약 200mV sag 됨 (실측: 완충 직후 뺐을 때 ~4.0V).
  // 따라서 무부하 OCV 곡선을 그대로 쓰면 완충인데도 80%로 떨어져 보임.
  // → 구동 중 완충 전압(~4.0V)을 100%로 잡아, 충전기 분리 시 % 가 급락하지
  //   않도록 곡선 전체를 sag 만큼 아래로 이동시킴. 충전 중(4.0V↑)은 100% clamp.
  // 내림차순 (높은 전압 → 높은 %).
  struct Point { uint16_t mv; uint8_t pct; };
  constexpr Point CURVE[] = {
    {4000, 100}, {3950, 92}, {3900, 84}, {3850, 75}, {3800, 66},
    {3750, 56},  {3700, 46}, {3650, 37}, {3600, 28}, {3550, 20},
    {3500, 13},  {3450, 8},  {3400, 4},  {3300, 0},
  };
  constexpr int CURVE_N = sizeof(CURVE) / sizeof(CURVE[0]);

  int8_t mvToPercent(uint16_t mv) {
    if (mv >= CURVE[0].mv)          return 100;
    if (mv <= CURVE[CURVE_N - 1].mv) return 0;
    for (int i = 0; i < CURVE_N - 1; i++) {
      if (mv <= CURVE[i].mv && mv > CURVE[i + 1].mv) {
        // CURVE[i](상한) ~ CURVE[i+1](하한) 사이 선형 보간.
        const uint16_t hi_mv = CURVE[i].mv,     lo_mv = CURVE[i + 1].mv;
        const uint8_t  hi_p  = CURVE[i].pct,    lo_p  = CURVE[i + 1].pct;
        return (int8_t)(lo_p + (int)(mv - lo_mv) * (hi_p - lo_p) / (hi_mv - lo_mv));
      }
    }
    return 0;
  }

  uint16_t readVbatMv() {
    // 8회 평균 → 노이즈 완화. analogReadMilliVolts 는 ADC 보정 내장.
    uint32_t sum = 0;
    for (int i = 0; i < 8; i++) {
      sum += analogReadMilliVolts(pins::BAT_ADC);
    }
    const uint16_t pin_mv = (uint16_t)(sum / 8);
    return (uint16_t)(pin_mv * 2);  // 2:1 분압 복원.
  }

}  // namespace

void begin() {
  analogReadResolution(12);
  update();
  Serial.printf("[battery] VBAT=%umV (%d%%) on GPIO%u\n",
                (unsigned)g_mv, (int)g_pct, (unsigned)pins::BAT_ADC);
}

void update() {
  g_mv  = readVbatMv();
  g_pct = mvToPercent(g_mv);
  // 충전 감지 (hysteresis).
  if (!g_charging && g_mv >= CHARGE_ENTER_MV) {
    g_charging = true;
  } else if (g_charging && g_mv < CHARGE_EXIT_MV) {
    g_charging = false;
  }
  // 검증/보정용 — 측정 전압과 환산 % 출력 (USB 연결 시 모니터로 확인).
  Serial.printf("[battery] VBAT=%umV -> %d%% (%s)\n", (unsigned)g_mv,
                (int)g_pct, g_charging ? "charging" : "battery");
}

uint16_t milliVolts() { return g_mv; }
int8_t   percent()    { return g_pct; }
bool     isCharging() { return g_charging; }

}  // namespace battery
