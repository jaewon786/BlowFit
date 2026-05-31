# BlowFit v4.0 하드웨어 배선 (Wiring)

> 제품 BOM 과 실제 결선의 단일 진실 출처. 핀 번호는 `include/config.h` 와 일치.
> 보드: **LILYGO T-Display-S3 (ESP32-S3)**.

## 1. 제품 구성 (BOM)

| 구성품 | 부품 |
|---|---|
| 메인보드/MCU | LILYGO T-Display-S3 (ESP32-S3) |
| 압력 센서 | MPXV7007DP (MikroE Diff Press Click + MCP3221 I²C ADC) |
| 배터리 | LiPo 400mAh |
| 전원 버튼 | PB61412L (LED 내장 택트 스위치) |
| 햅틱 모터 | 코인형 ERM 진동 모터 (DC 3V) |
| 햅틱 드라이버 | DRV2605L (SparkFun Qwiic Haptic Motor Driver) |

## 2. 전원 트리

```
USB-C ─► T-Display-S3 (내장 충전 IC) ─┬─► LiPo 400mAh 충전
                                       └─► 3V3 레귤레이터
LiPo 400mAh ─► 보드 배터리 커넥터 (USB 없을 때 구동)
보드 3V3 ─┬─► MCP3221 Press Click VCC
          └─► DRV2605L VCC
보드 GND ─┴─► 공통 GND
```

- 배터리는 **보드 배터리 커넥터(JST 1.25mm)에만** 연결. 충전은 USB-C 자동.
- ⚠️ **배터리 극성 주의** — LILYGO 는 +/- 가 반대인 경우 있음. 꽂기 전 실크/멀티미터 확인.
- 페리페럴은 모두 보드 **3V3 + GND** 에서 전원. 모터는 GPIO/3V3 직접 연결 금지(드라이버 경유).
- 배터리 모드 시 화면 전원 = GPIO15 (TFT LDO enable) HIGH — 펌웨어 setup() 처리.

## 3. GPIO 핀 맵 (config.h 일치)

| GPIO | 연결 | 비고 |
|---|---|---|
| GPIO43 | I²C SDA | MCP3221 + DRV2605L 공유 |
| GPIO44 | I²C SCL | 〃 (100kHz) |
| GPIO10 | DRV2605L EN (HAPTIC_EN) | HIGH = 드라이버 enable |
| GPIO12 | PB61412L 스위치 (PWR_BUTTON) | INPUT_PULLUP, 누르면 LOW |
| GPIO13 | PB61412L LED (PWR_LED) | 220Ω 직렬, HIGH=ON |
| GPIO15 | TFT LDO enable | 보드 내장, 배터리 모드 필수 |
| GPIO0  | BOOT 버튼 (내장) | 짧게=훈련 시작 / 길게 2초=잠자기 |
| GPIO14 | USER 버튼 (내장) | 짧게=훈련 정지 |

## 4. I²C 버스 (SDA=GPIO43, SCL=GPIO44, 100kHz)

| 장치 | I²C 주소 |
|---|---|
| MCP3221 (Diff Press Click ADC) | 0x4D |
| DRV2605L (햅틱 드라이버) | 0x5A |

> ⚠️ 두 보드 모두 I²C 풀업 보유 → 병렬 시 합성 저항 과소. 불안정하면 SparkFun
> 보드의 `I2C` 풀업 점퍼(clearable)를 칼로 절단해 한쪽만 남길 것. (100kHz 라
> 보통은 그대로도 동작 — 업로드 후 두 주소 다 잡히면 안 잘라도 됨)

## 5. 압력 센서 — MPXV7007DP (MikroE Diff Press Click)

| Click 핀 | 보드 |
|---|---|
| VCC (3V3) | 3V3 |
| GND | GND |
| SDA | GPIO43 |
| SCL | GPIO44 |

- Click 의 3V3/5V 패드를 브리지해 단일 3.3V 레일 운용 (전원 토폴로지 Option B1).
- 양방향 차압 ±71 cmH₂O (호기 양압 / 흡기 음압). 자세한 배경: `mpxv7007_migration.md`.

## 6. 햅틱 — DRV2605L (SparkFun Qwiic) + 코인 ERM 모터

### 드라이버 → 보드
| DRV2605L | 보드 | 종류 |
|---|---|---|
| VCC | 3V3 | 전원 |
| GND | GND | 전원 |
| SDA | GPIO43 | 신호 |
| SCL | GPIO44 | 신호 |
| EN | GPIO10 | 신호 (HIGH=enable) |
| IN/TRIG | — | 미연결 (I²C GO bit 로 트리거) |

### 모터 → 드라이버 출력 (JP2)
| 코인 모터 (DC 3V, 2선) | DRV2605L |
|---|---|
| 빨강 (+) | OUT+ |
| 파랑/검정 (−) | OUT− |

- 코인형 = **ERM** → 펌웨어 ERM open-loop + ROM library 1 (`haptic.cpp`). LRA 아님.
- VCC 3.3V ≈ 모터 3V 정격 → 안전, OD_CLAMP 불필요.

## 7. 전원 버튼 — PB61412L (LED 내장 택트 스위치, 6핀)

### 핀아웃 (데이터시트)
- 스위치 4핀: **① — ② 연결**, **③ — ④ 연결**. 누르면 (①②) ↔ (③④) 닫힘.
- LED 2핀: **L1 = +(anode)**, **L2 = −(cathode)**.

### 결선 (최소 4선)
| PB61412L | 보드 |
|---|---|
| ① (또는 ②) | GPIO12 (PWR_BUTTON) |
| ③ (또는 ④) | GND |
| L1 (+) | 220Ω → GPIO13 (PWR_LED) |
| L2 (−) | GND |

- ⚠️ 스위치는 **위 쌍(①/②)에서 1개 + 아래 쌍(③/④)에서 1개**만 사용. 같은 쌍에
  GPIO12·GND 를 물리면 상시 단락.
- LED 극성 주의(L1=+ / L2=−). 220Ω 는 직렬이면 위치 무관.

### 동작 (power.cpp)
- 켜진 상태에서 **짧게 누름 → deep sleep (끄기)**: 세션 정리 → LED OFF → 화면 OFF.
- 잠자기에서 **누름 → wake (켜기, 재부팅)**. wake 소스 = PWR_BUTTON 또는 BOOT (EXT1, active-LOW).
- LED: 동작 중 ON, 잠자기 OFF.

## 8. 전체 연결 요약도

```
LiPo 400mAh ─►[배터리 커넥터] T-Display-S3 (ESP32-S3)
                                 │ 3V3 ─┬─► Click VCC ─┬─► DRV2605L VCC
                                 │ GND ─┴─► Click GND ─┴─► DRV2605L GND ─► (공통)
                                 │ GPIO43(SDA) ──► Click SDA + DRV2605L SDA
                                 │ GPIO44(SCL) ──► Click SCL + DRV2605L SCL
                                 │ GPIO10 ───────► DRV2605L EN
                                 │ GPIO12 ───────► PB61412L ①  (③→GND)
                                 │ GPIO13 ─[220Ω]► PB61412L L1(+)  (L2→GND)
                                 └ (DRV2605L OUT+/OUT− ─► 코인 ERM 모터)
```
