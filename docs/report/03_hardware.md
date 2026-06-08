# 제 3 장  하드웨어 설계

> 본 장에서는 BRELOW 디바이스의 부품 구성, 전원 회로, GPIO 배선, I²C 버스 구성, 그리고 핵심 부품인 차압식 압력 센서의 동작 원리를 기술한다. 1차 자료는 `firmware-esp32/docs/wiring.md` 와 `firmware-esp32/include/config.h::pins` 이다.

---

## 3.1 BOM (Bill of Materials)

표 3.1 — BRELOW v4.1 의 부품 구성.

| 분류 | 부품 | 제조사 | 비고 |
|---|---|---|---|
| 메인보드/MCU | T-Display-S3 (ESP32-S3) | LILYGO | 1.9" IPS LCD 170×320, 8 MB PSRAM, 16 MB Flash, BLE 5.0 |
| 압력 센서 | MPXV7007DP | NXP | 양방향 차압 ±7 kPa (≈ ±71 cmH₂O) |
| ADC 인터페이스 | MCP3221 (12-bit I²C ADC) | Microchip | MikroE Diff Press Click 보드에 내장 |
| 햅틱 드라이버 | DRV2605L | Texas Instruments | SparkFun Qwiic Haptic Motor Driver |
| 햅틱 액추에이터 | 코인형 ERM 진동 모터 (DC 3 V) | 범용 | 직경 10 mm |
| 배터리 | LiPo 400 mAh | 범용 | 단셀 3.7 V |
| 충전 IC | LILYGO 보드 내장 | — | USB-C 입력 |
| 외부 전원 버튼 | PB61412L | 범용 (택트 + LED) | LED 내장 6핀 스위치 |

> 모든 페리페럴은 보드의 **3.3 V** 레일에서 전원을 받는다. MPXV7007 의 권장 V₍s₎ 는 5 V 이나, 본 설계는 회로 단순화를 위해 단일 3.3 V 레일에서 운용한다(under-spec). 변환식이 **ratiometric** 이므로 V₍s₎ 와 무관하게 비율(ratio)로 정상 동작하며, 출력 스윙이 66 % 로 축소되는 영향은 ±2 ~ 5 % 의 게인 오차로 흡수된다. (자세한 분석은 `firmware-esp32/docs/mpxv7007_migration.md` §2.3 참조.)

---

## 3.2 전원 트리 (Power Tree)

```
USB-C ─► T-Display-S3 (내장 충전 IC) ─┬─► LiPo 400 mAh 충전
                                       └─► 3 V3 레귤레이터
LiPo 400 mAh ─► 보드 배터리 커넥터 (USB 없을 때 구동)
보드 3 V3 ─┬─► MCP3221 / MPXV7007 (Press Click 보드 VCC)
           └─► DRV2605L VCC
보드 GND  ─┴─► 공통 GND
GPIO15    ─► TFT LDO enable (배터리 모드 HIGH 필수)
```

그림 3.1 — BRELOW 의 전원 트리. 외부 페리페럴은 전부 보드 3.3 V 에서 분기.

### 3.2.1 전원 모드별 거동

| 모드 | 입력 | 화면 LDO | 동작 |
|---|---|---|---|
| USB 충전 + 사용 | USB-C 5 V | ON | LiPo 충전과 동시에 사용. VBAT 전압이 충전 전압(~4.2 V+)으로 올라가 잔량 표시가 100 % 로 고정. |
| 배터리 단독 | LiPo | ON (펌웨어가 `setup()` 에서 GPIO15 HIGH) | 무부하 4.2 V → 부하 시 ~4.0 V sag → 충전 IC 의 만충 감지선과 분리되어 `battery::isCharging()` false. |
| Deep sleep | LiPo | OFF | ESP32 RTC + EXT0 wake 만 살아 있음. 소비 전류 약 10 μA. |

> ⚠️ **배터리 극성 주의** — LILYGO 배치에 따라 JST 1.25 mm 커넥터의 +/- 가 보드 실크와 반대일 수 있다. 결선 전 멀티미터로 극성 확인 필수.

---

## 3.3 GPIO 핀 매핑

표 3.2 — `firmware-esp32/include/config.h::pins` 와 1:1 대응.

| GPIO | 신호 | 방향 | 비고 |
|---|---|---|---|
| GPIO 0 | BUTTON_BOOT | IN (내장 풀업) | T-Display 내장 BOOT. 짧게 = `session::startSession()`, 길게 2 s = deep sleep. |
| GPIO 4 | BAT_ADC (ADC1_CH3) | AIN | VBAT 2:1 분압. `analogReadMilliVolts(4) × 2` = V_bat. |
| GPIO 10 | HAPTIC_EN | OUT | DRV2605L EN/trigger (HIGH = enable). |
| GPIO 11 | LED_STATUS | OUT | 보조 상태 LED (선택 사용). |
| GPIO 12 | PWR_BUTTON | IN (풀업) | PB61412L 스위치. 짧게 = startSession, 길게 3 s = deep sleep. |
| GPIO 13 | PWR_LED | OUT | PB61412L LED (220 Ω 직렬). |
| GPIO 14 | BUTTON_USER | IN (내장 풀업) | T-Display 내장 USER. 짧게 = `session::stopSession()`. |
| GPIO 15 | TFT_POWER_ON | OUT | LCD LDO enable (배터리 모드 HIGH 필수). |
| GPIO 43 | I²C SDA | OD | MCP3221 + DRV2605L 공유. |
| GPIO 44 | I²C SCL | OD | 〃 |
| GPIO 5 / 7 / 8 / 9 / 38 / 39~48 | LCD 인터페이스 | — | TFT_eSPI Setup206 자동 처리. |

> Setup206 은 8-bit 병렬 인터페이스로 LCD 를 구동한다. SPI 보다 빠르지만 핀 점유가 크다. 본 프로젝트는 LCD 외 페리페럴이 적어 적합하다.

---

## 3.4 I²C 버스

표 3.3 — 버스 공유 장치.

| 장치 | 주소 | 비고 |
|---|---|---|
| MCP3221 (압력 ADC) | `0x4D` | 100 kHz read, 매 10 ms (= 100 Hz 샘플) |
| DRV2605L (햅틱) | `0x5A` | 효과 트리거 시에만 통신 |

**버스 사양**: SDA = GPIO 43, SCL = GPIO 44, **클럭 100 kHz** (Standard-mode).

> 400 kHz Fast-mode 도 데이터시트 상 가능하나, LVGL 디스플레이 리프레시 + BLE 송신과 task 경합이 발생할 때 100 kHz 가 더 안정적이다. 진단용 i2c_scan 스케치는 LVGL/BLE 가 없어 400 kHz 로도 안정 동작 확인됨(`firmware-esp32/tools/i2c_scan/`).

### 3.4.1 풀업 충돌

MCP3221 보드와 DRV2605L Qwiic 보드 모두 자체 I²C 풀업 저항을 내장하고 있다. 두 보드를 같은 버스에 병렬 연결하면 풀업이 병렬 합성되어 저항이 절반으로 떨어진다. 100 kHz 운용 시에는 실제 통신에 영향이 없는 것으로 실측되었으나, 400 kHz 로 올릴 경우 SparkFun 보드의 풀업 점퍼(`I2C`)를 칼로 절단해 한쪽만 남기는 것을 권장한다.

---

## 3.5 압력 센서 — MPXV7007DP 원리

### 3.5.1 차압식 vs 절대압식

MPXV7007**DP** 의 **D** 는 *Differential*, **P** 는 *Ported* 를 의미한다. 즉, 두 포트(P1, P2)의 압력 차를 측정하는 차압식 센서이다. P2 를 대기에 개방하면 P1 - P_atm 이 곧 게이지압이 되어 호기(양압) / 흡기(음압) 모두 측정 가능하다.

BRELOW 마우스피스는 P1 측에만 연결되고 P2 는 캐비넷 내 대기와 연결된다.

### 3.5.2 Ratiometric 변환식

MPXV7007 의 V_out 은 V_s 에 비례한다(ratiometric).

```
V_out = V_s × (0.057 × ΔP + 0.5)         ; ΔP in kPa
ratio = V_out / V_s = 0.057 × ΔP + 0.5   ; ← V_s 약분
→ ΔP_kPa  = (ratio − 0.5) / 0.057
→ ΔP_cmH₂O = ΔP_kPa × 10.197
```

식 3.1 — MPXV7007DP 의 차압 ↔ 출력 비율 관계.

MCP3221 의 V_DD = MPXV7007 의 V_s = 3.3 V 이며, MCP3221 출력값은 V_DD 대비 비율로 ADC 값이 산출되므로 ratio 계산은 데이터시트의 5 V 환경과 동일하게 적용 가능하다.

### 3.5.3 측정 가능 범위

표 3.4 — 센서 측정 범위.

| 구간 | 값 | 비고 |
|---|---|---|
| 데이터시트 풀스케일 | ±7 kPa = ±71.4 cmH₂O | 정확도 보장 구간 |
| ADC 이론 최댓값 (ratio = 1.0) | +8.77 kPa = +89.4 cmH₂O | 정확도 보장 X |
| ADC 이론 최솟값 (ratio = 0.0) | −8.77 kPa = −89.4 cmH₂O | 〃 |
| 펌웨어 saturation clamp | **±71 cmH₂O** | `config.h::sensor::MIN/MAX_CMH2O` |
| 호흡 훈련 영역 | +20 ~ +30 cmH₂O (호기), −20 ~ −60 (흡기) | 일반 사용자 |

> 펌웨어는 정확도 보장 구간만 사용하기 위해 ±71 cmH₂O 에서 clamp 한다. 이는 동시에 마우스피스 사용자의 안전 ceiling 역할도 한다.

---

## 3.6 외부 전원 버튼 — PB61412L

### 3.6.1 핀아웃 (데이터시트)

PB61412L 은 LED 가 내장된 6핀 택트 스위치이다.

- 스위치 4핀: ① ↔ ② 항시 연결, ③ ↔ ④ 항시 연결. 누르면 (①②) ↔ (③④) 도통.
- LED 2핀: L1 = anode, L2 = cathode.

### 3.6.2 결선

| PB61412L 핀 | 보드 |
|---|---|
| ① (또는 ②) | GPIO 12 (PWR_BUTTON) |
| ③ (또는 ④) | GND |
| L1 (anode) | GPIO 13 (PWR_LED), 220 Ω 직렬 |
| L2 (cathode) | GND |

펌웨어는 `INPUT_PULLUP` 으로 GPIO 12 를 읽어 누름 시 LOW 를 감지한다. LED 는 디바이스 ON 상태 표시.

---

## 3.7 인클로저 및 마우스피스

> 본 절은 기계공 / 시각디자인 협업 영역의 산출물을 기록한다. 본 보고서에는 (a) 외관 렌더링, (b) 마우스피스 부속의 사출 사양, (c) 오리피스 디스크(4 mm / 3 mm / 2 mm) 의 호환성을 명시한다. (도면 자료는 별도 첨부 — 부록 C.)

### 3.7.1 마우스피스 ↔ 센서 연결

마우스피스는 실리콘 튜브를 통해 본체 내 MikroE Press Click 의 P1 포트에 연결된다. P2 는 본체 내 대기에 개방된다. 누설(leak) 시 호기 측정값이 실제보다 낮게 측정되므로 실리콘 패킹의 압착이 중요하다.

### 3.7.2 오리피스 디스크

훈련 강도는 마우스피스 출구에 끼우는 오리피스 디스크의 직경으로 1차 조절된다. 펌웨어/앱은 디스크 종류를 `OrificeLevel` enum 으로 추적하며, 사용자가 BLE `START_SESSION` 시 함께 전송한다.

| OrificeLevel | 직경 | 권장 시기 |
|---|---|---|
| LOW (0) | 4.0 mm | 1 ~ 4 주차 (입문) |
| MEDIUM (1) | 3.0 mm | 5 ~ 8 주차 |
| HIGH (2) | 2.0 mm | 9 ~ 12 주차 (숙련) |

직경 ↔ 압력의 관계는 §10.3 의 검증 데이터로 정량 확인한다.

---

## 3.8 안전 및 한계

| 항목 | 조치 |
|---|---|
| 누설 → 압력 저측정 | 마우스피스 패킹, 실리콘 튜브 압착 |
| 과도 호기로 인한 폐 압력 손상 | 펌웨어 `EXHALE_SAFETY_LIMIT = +100 cmH₂O` clamp |
| 과도 흡기 시 점막 손상 | 펌웨어 `INHALE_SAFETY_LIMIT = −90 cmH₂O` clamp |
| 배터리 과방전 | 충전 IC 의 BMS + 펌웨어 저전압 deep sleep |
| 결로/침수 | 인클로저 IP 등급 미공식 측정 — 실내 사용 권장 |

표 3.5 — 안전 관련 설계 결정.

---

*— 제 3 장 끝 —*
