// BlowFit v4.0 펌웨어 — 핀맵 + 상수 + enum.
// LILYGO T-Display S3 (ESP32-S3) 기준.
//
// 전반적 룩-필은 v3.2 firmware/config.h 와 비슷하지만 보드/센서가 달라
// 핀 번호와 일부 토글이 변경됨. 호스트 g++ 테스트 호환을 위해 Arduino-only
// 타입은 헤더에 두지 않음.

#pragma once

#include <stdint.h>

// ----- Hardware feature flags -----
// 외부 페리페럴이 아직 도착하지 않았을 때 또는 BSP 가 해당 라이브러리를 제공
// 하지 않을 때 활성 코드를 우회하기 위한 컴파일 시 토글.
#ifndef HAS_DISPLAY
#define HAS_DISPLAY 1   // LILYGO T-Display S3 일체형 1.9" IPS. TFT_eSPI Setup206.
#endif
#ifndef HAS_LVGL
#define HAS_LVGL 1      // LVGL 9.x GUI. lv_conf.h 활성화 필요.
#endif
#ifndef HAS_FLASH
#define HAS_FLASH 1     // ESP32 NVS (Preferences) — 기본 활성. 세션 영속화.
#endif
#ifndef HAS_BATTERY
#define HAS_BATTERY 1   // VBAT 모니터링 (LiPo 400mAh, T-Display S3 내장 회로).
#endif
#ifndef HAS_BLE
#define HAS_BLE 1       // ESP32 BLE Arduino. v4.0 의 핵심 기능.
#endif

// ----- Pin map -----
namespace pins {

  // 외부 부품 — 사용자 배선
  // 압력 센서는 MikroE Diff Press Click (MPXV7007DP + MCP3221 12-bit I²C ADC).
  // 보드 내장 MCP3221 이 0~5V analog 를 받아 I²C 로 변환 → MCU 측 GPIO 는 3.3V
  // logic 만 노출되어 안전. 자세한 내용은 docs/mpxv7007_migration.md 참조.
  // I²C 버스 (MCP3221 ADC + DRV2605L 햅틱 드라이버 공유).
  constexpr uint8_t I2C_SDA         = 43;  // GPIO43 (UART0 TX, USB-CDC 사용 중이라 free)
  constexpr uint8_t I2C_SCL         = 44;  // GPIO44 (UART0 RX, 위와 동일)
  // 햅틱(진동) 모터는 DRV2605L 햅틱 드라이버(I²C, addr 0x5A)로 구동.
  // GPIO10 = DRV2605L EN/트리거 라인 (효과 트리거는 I²C GO bit). 직접 PWM 아님.
  constexpr uint8_t HAPTIC_EN       = 10;  // GPIO10 — DRV2605L EN/trigger
  constexpr uint8_t LED_STATUS      = 11;  // GPIO11 — 상태 LED (선택)

  // 내장 — TFT_eSPI Setup206 가 자동 처리. 참고용으로만 명시:
  //   GPIO5  — TFT_RST
  //   GPIO7  — TFT_DC
  //   GPIO8  — TFT_WR (쓰기 strobe)
  //   GPIO9  — TFT_RD
  //   GPIO39~48 — 8-bit 병렬 데이터
  //   GPIO38 — 백라이트 PWM (TFT_BL, TFT_eSPI 가 직접 제어)
  //   GPIO15 — LDO 전원 enable (배터리 모드 HIGH 필수, firmware setup() 직접 처리)
  constexpr uint8_t TFT_POWER_ON = 15;  // LDO enable — 배터리 모드 필수
  // 배터리 전압 측정 — T-Display-S3 내장. VBAT 가 2:1 분압되어 GPIO4(ADC1_CH3)
  // 로 들어옴. Vbat = analogReadMilliVolts(4) × 2. 추가 하드웨어 불필요.
  constexpr uint8_t BAT_ADC = 4;

  // 사용자 입력 버튼 (T-Display S3 내장)
  constexpr uint8_t BUTTON_BOOT = 0;   // 부트 버튼 (short = startSession, long = deep sleep)
  constexpr uint8_t BUTTON_USER = 14;  // 사용자 버튼 (short = stopSession)

  // 외부 전원 버튼 (M11) — PB61412L tact 스위치 + LED.
  // ESP32-S3 의 모든 GPIO 가 RTC GPIO 라 EXT0 deep sleep wakeup 가능.
  // GPIO12 는 좌측 헤더 free + ADC1 가능 (배터리 측정 후 옵션).
  constexpr uint8_t PWR_BUTTON  = 12;  // 외부 전원 버튼 (input pullup)
  constexpr uint8_t PWR_LED     = 13;  // 외부 전원 LED (output, 220Ω 직렬)

}  // namespace pins

// ----- Power management (M11) -----
namespace power {

  // Deep sleep 진입 조건.
  constexpr uint32_t LONG_PRESS_MS     = 2000;   // BOOT 버튼 long-press = 2초 (deep sleep)
  // BOOT 버튼은 short-press 가 startSession 이라 long-press 로 deep sleep.
  // 외부 PWR_BUTTON (PB61412L):
  //   - short-press            → startSession (훈련 시작)
  //   - long-press 3초          → deep sleep (끄기)
  //   - deep sleep 에서 3초 hold → wake (켜기, wakeGate 게이트)
  constexpr uint32_t PWR_LONG_PRESS_MS = 3000;   // 전원 버튼 long-press = 3초 (deep sleep)
  constexpr uint32_t WAKE_HOLD_MS      = 3000;   // 깨우기 — 전원 버튼 3초 연속 hold 필요

  // Standby idle 시 자동 deep sleep (옵션 — 추후 활성화).
  // constexpr uint32_t IDLE_DEEP_SLEEP_MS = 5UL * 60 * 1000;  // 5분

}  // namespace power

// ----- Pressure sensor (MPXV7007DP via MikroE Diff Press Click + MCP3221) -----
// 양방향 차압 센서, 5V Vs, ±7 kPa (≈ ±71 cmH₂O). 보드 내장 MCP3221 12-bit I²C
// ADC 가 sensor output (0.5~4.5V) 을 ratiometric 으로 변환.
//
// 변환식 (datasheet, 5V ratiometric):
//   Vout/Vs = 0.057 × ΔP_kPa + 0.5
//   ratio   = ADC / 4095
//   ΔP_kPa  = (ratio - 0.5) / 0.057
//   ΔP_cmH2O = ΔP_kPa × 10.197
//
// MCP3221 은 VDD 기준 ratiometric 이라 절대 전압 측정 불필요 — ADC ↔ ratio 만
// 사용. ADC_VREF 같은 항목은 의도적으로 두지 않음.
namespace sensor {

  constexpr int   ADC_MAX        = 4095;     // MCP3221 12-bit
  constexpr float ZERO_RATIO     = 0.5f;     // ΔP=0 시 ratio (datasheet)
  constexpr float K_FACTOR_RATIO = 0.057f;   // ratio per kPa
  constexpr float KPA_TO_CMH2O   = 10.197f;

  // 차압 센서 포트(구멍/호스) 방향 보정용 극성.
  //   정상: 호기(불기)=양압(+), 흡기(마시기)=음압(-).
  // 압력 구멍/호스를 반대로 연결하면 부호가 뒤집혀 그래프가 거꾸로 움직인다
  // (호기에 빨아야 올라감). 이 경우 -1.0 으로 전체 극성을 반전해 보정한다.
  // (정상 배선이면 +1.0)
  constexpr float PRESSURE_SIGN  = -1.0f;

  // MCP3221 I²C 주소 — 0x48~0x4F 중 하나. MikroE Click 기본 0x4D 추정.
  // MS2 (tools/i2c_scan) 로 실측 확인 후 필요 시 갱신.
  constexpr uint8_t MCP3221_ADDR = 0x4D;
  // I²C frequency: 100kHz standard-mode. 400kHz Fast-mode 도 가능하지만 본
  // 펌웨어의 LVGL/BLE task 점유 환경에선 100kHz 가 더 안정적. i2c_scan
  // sketch 는 가벼워서 400kHz OK 였음.
  constexpr uint32_t I2C_FREQ_HZ = 100000;   // Standard-mode (안정성 우선)

  // 영점 보정용 — 부팅 후 첫 N 샘플 평균을 zeroOffset 로 저장.
  // 부팅 시간 2초 = 200 sample × 10ms. 더 길게 (500 = 5초) 하면 평균 noise
  // 감소하지만 호흡 훈련 응용엔 200 sample 도 충분.
  constexpr int   ZERO_CALIBRATION_SAMPLES = 200;  // 100Hz × 2초

  // 안전한 측정 범위 (saturation guard). MPXV7007 풀스케일 ±71 cmH₂O 보다 약간
  // 보수적으로 설정 → 비정상 입력은 clamp.
  constexpr float MIN_CMH2O = -71.0f;
  constexpr float MAX_CMH2O = +71.0f;

}  // namespace sensor

// ----- Training session timing & target pressure (clinical-evidence-based) ---
//
// 한 곳에서 관리되는 임상 상수. session.cpp / ble_service.cpp / app 이 모두
// 이 값을 참조한다. 단계(Beginner/Normal/Advanced) 전환은 setIntensity() 한
// 호출로 끝나도록 비율 표 (INTENSITY_*_PCT) 만 갈아치우면 된다.
//
// ## 훈련 시간
//   1 호흡 cycle = 흡기 5s + 호기 5s + 휴식 5s   = 15 s   (BREATH_*_MS)
//   1 set       = 10 breaths × 15 s              = 150 s  (BREATHS_PER_SET)
//   1 session   = 2 sets + 세트 사이 30 s 휴식   ≈ 5.5 분
//   권장          하루 1~2회 (5분 또는 5분 × 2)
//
// 근거:
//   - Vranish & Bailey 2016 (Sleep 39(7):1453-9) — 5분/일 IMT (30 breaths
//     × 75% PImax × 5 days/week × 6 weeks) 로 혈압·수면 개선.
//   - The Breather (PN Medical) 공식 프로토콜 — 10 breaths × 2 sets,
//     주 6회. IMT/EMT 양방향 동시.
//
// ## 목표 압력 (%PImax / %MEP 적응형)
//   목표압력은 사용자 PImax (최대 흡기압) / MEP (최대 호기압) 의 비율로 계산.
//   PImax/MEP 실측 기능은 별도 마일스톤 — 그 전에는 일반 성인 평균 (Black &
//   Hyatt 1969) 기본값을 사용. 측정 기능이 붙는 즉시 setPimaxMep() 로 주입.
//
//   강도 level → (low_pct ~ high_pct):
//     Beginner    30 ~ 40 %    호흡 재활 초보·노인 시작 강도 (Bissett 2019)
//     Normal      50 ~ 60 %    POWERbreathe sustainable zone   ← 기본
//     Advanced    70 ~ 75 %    Vranish & Bailey 2016 IMT 프로토콜
//
//   예: Normal · PImax 80 → 흡기 -40 ~ -48 cmH₂O
//                · MEP 60  → 호기 +30 ~ +36 cmH₂O
//
// ## 안전 상한 (consumer device ceiling)
//   사용자가 PImax/MEP 를 과대 입력해 계산된 target 이 ceiling 을 넘으면
//   target 을 ceiling 으로 clamp + 경고 로그. 측정값 자체는 sensor 단에서
//   ±71 cmH₂O 로 saturate 되므로 별도 처리 불필요.
namespace session {

  // ── Timing ───────────────────────────────────────────────────────────────
  constexpr uint32_t BREATH_INHALE_MS = 5000;   // 한 호흡 내 흡기
  constexpr uint32_t BREATH_EXHALE_MS = 5000;   // 한 호흡 내 호기
  constexpr uint32_t BREATH_REST_MS   = 5000;   // 한 호흡 끝 휴식
  constexpr uint8_t  BREATHS_PER_SET  = 10;
  constexpr uint8_t  TOTAL_SETS       = 2;
  constexpr uint32_t SET_REST_MS      = 30000;  // 세트 사이 휴식 (30 s)
  constexpr uint32_t PREP_MS          = 0;      // 준비 단계 — 0 (즉시 시작)
  constexpr uint32_t SUMMARY_MS       = 8000;   // Summary 자동 복귀 (8 s)
  constexpr uint16_t SAMPLE_HZ        = 100;

  // 파생 — 1 set 의 train 시간 (호흡 × cycle).
  constexpr uint32_t SET_TRAIN_MS =
      BREATHS_PER_SET *
      (BREATH_INHALE_MS + BREATH_EXHALE_MS + BREATH_REST_MS);  // 150000 ms

  // BLE SET_DURATION 으로 받은 train 시간의 안전 범위 (1 set 기준).
  // session.cpp::setTrainDuration() 가 이 범위로 clamp.
  constexpr uint32_t TRAIN_DURATION_MIN_MS =  60000;   // 1 분
  constexpr uint32_t TRAIN_DURATION_MAX_MS = 600000;   // 10 분

  // ── %PImax/%MEP target ──────────────────────────────────────────────────
  // PImax / MEP 기본 — 사용자별 측정 전 일반 성인 평균값.
  constexpr float PIMAX_DEFAULT_CMH2O = 80.0f;
  constexpr float MEP_DEFAULT_CMH2O   = 60.0f;

  // 강도 level. enum class 가 아닌 plain enum — BLE payload (1 byte) 와
  // 직접 매핑되어 0/1/2 값이 그대로 의미를 가짐.
  enum IntensityLevel : uint8_t {
    INTENSITY_BEGINNER = 0,  // 30 ~ 40 %
    INTENSITY_NORMAL   = 1,  // 50 ~ 60 %  ← 기본
    INTENSITY_ADVANCED = 2,  // 70 ~ 75 %
  };
  constexpr IntensityLevel INTENSITY_DEFAULT = INTENSITY_NORMAL;

  // 비율표 — 인덱스 = IntensityLevel 값.
  constexpr float INTENSITY_LOW_PCT[3]  = {0.30f, 0.50f, 0.70f};
  constexpr float INTENSITY_HIGH_PCT[3] = {0.40f, 0.60f, 0.75f};

  // ── 다이얼(orifice) 보정계수 ───────────────────────────────────────────────
  // 다이얼은 구멍 크기로 저항을 바꾼다(큰 구멍=약한 저항=낮은 압력). 기준 2단(2mm)
  // 에서 측정한 PImax/MEP 로 다른 단계 목표를 자동 산출하기 위한 보정계수.
  // 베르누이 ΔP ∝ 1/A² ∝ 1/d⁴, 호흡 일률 일정 가정 → ΔP ∝ 1/d^(4/3).
  // 기준 2단 대비: 1단 3mm=(2/3)^(4/3)≈0.58 · 2단 2mm=1.00 · 3단 1mm=(2/1)^(4/3)≈2.52.
  // 인덱스 = orifice level (0=1단/3mm, 1=2단/2mm, 2=3단/1mm).
  constexpr float   DIAL_COEFFICIENT[3] = {0.58f, 1.00f, 2.52f};
  constexpr uint8_t ORIFICE_DEFAULT     = 1;  // 기준 2단

  // ── Safety ceiling ──────────────────────────────────────────────────────
  // target (계산값) 이 이를 넘으면 clamp + 경고. magnitude 단위 (양수).
  constexpr float INHALE_SAFETY_LIMIT_CMH2O = 90.0f;   // |음압| 한계
  constexpr float EXHALE_SAFETY_LIMIT_CMH2O = 100.0f;  // 양압 한계

}  // namespace session

// ----- BLE -----
namespace ble {

  // ATT MTU 협상 목표 — Pressure Stream 22B 패킷이 한 packet 에 들어가도록.
  constexpr uint16_t MTU_TARGET = 185;

  // Connection interval 권장 (ms) — 짧으면 끊김 적고 배터리 소모 큼.
  constexpr uint16_t CONN_INTERVAL_MIN_MS = 15;
  constexpr uint16_t CONN_INTERVAL_MAX_MS = 30;

  // 광고 이름. prefix 'BRELOW' — 앱이 prefix 매칭으로 스캔.
  constexpr const char* DEVICE_NAME = "BRELOW";

}  // namespace ble

// ----- Display (LVGL) -----
// 세로 모드 native — TFT_eSPI 의 setRotation(0) 기준.
// (가로 모드 필요 시 setRotation(1) + SCREEN_W/H 스왑.)
namespace display {

  constexpr int16_t SCREEN_W = 170;  // T-Display S3 세로 모드
  constexpr int16_t SCREEN_H = 320;
  constexpr uint8_t TARGET_FPS = 60;
  constexpr uint8_t ROTATION   = 0;  // 0=세로 (USB 아래), 2=세로 뒤집힘

}  // namespace display

// ----- Device State enum (v3.2 와 동일) -----
enum DeviceState : uint8_t {
  STATE_BOOT     = 0,
  STATE_STANDBY  = 1,
  STATE_PREP     = 2,
  STATE_TRAIN    = 3,
  STATE_REST     = 4,
  STATE_SUMMARY  = 5,
  STATE_WEEKLY   = 6,
  STATE_ERROR    = 7,
};

// ----- Orifice Level enum -----
enum OrificeLevel : uint8_t {
  ORIFICE_LOW    = 0,  // 4mm 디스크
  ORIFICE_MEDIUM = 1,  // 3mm 디스크
  ORIFICE_HIGH   = 2,  // 2mm 디스크
};
