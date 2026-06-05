// Power management — Deep sleep + 외부 전원 버튼.
//
// 시나리오:
//   1. 부팅 시 wakeup reason 확인 (RTC, EXT0 button, normal boot 등).
//   2. PWR_LED 켜기 (디바이스 ON 표시).
//   3. loop 에서 버튼 long-press 또는 PWR_BUTTON short-press 감지.
//   4. 감지 시 enterDeepSleep() 호출:
//      - 진행 중 session 정리
//      - 디스플레이 LDO OFF (GPIO15 LOW)
//      - LED OFF
//      - EXT0 wakeup 등록 (PWR_BUTTON 또는 BOOT 버튼)
//      - esp_deep_sleep_start()
//   5. 다음 wakeup 시 setup() 재실행 — 정상 부팅 흐름.
//
// 소비 전류:
//   ON:        ~80 mA (화면 + ESP32 + BLE 광고)
//   Deep sleep: ~10 μA (RTC + 버튼 모니터)
//   400 mAh 배터리: ON 5시간 / OFF 5년+

#pragma once

#include <stdint.h>

namespace power {

  /// setup() 최초반 (Serial.begin 직후, 디스플레이/센서 init 전) 호출.
  /// deep sleep 에서 EXT1(전원 버튼)로 깨어난 경우, 전원 버튼을 WAKE_HOLD_MS
  /// (3초) 동안 연속으로 눌러야 실제 부팅을 진행. 그 전에 떼면 다시 deep sleep
  /// 으로 복귀 (화면도 안 켜짐). 정상 부팅(USB/RST)이면 즉시 반환.
  void wakeGate();

  /// 이번 부팅이 deep sleep 에서 전원 버튼(EXT1)으로 깨어난 것인지 여부.
  /// wakeGate() 호출 후 유효. 켜짐 진동을 버튼 wake 일 때만 울리는 데 사용.
  bool wokeFromButton();

  /// setup() 초기 — wakeup reason 시리얼 출력, PWR_LED 켜기.
  void begin();

  /// loop() 에서 매 iteration 호출. BOOT 버튼 long-press 또는 PWR_BUTTON
  /// short-press 감지 시 deep sleep 진입.
  void tick(uint32_t now_ms);

  /// 직접 deep sleep 진입 (외부 트리거 — 예: 배터리 < 5%).
  /// 이 함수는 return 안 함.
  [[noreturn]] void enterDeepSleep();

}  // namespace power
