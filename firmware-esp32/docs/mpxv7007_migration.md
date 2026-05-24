# MPXV7007 Migration Plan (XGZP6847 → MPXV7007DP via MikroE Diff Press Click)

> 작성: 2026-05-20 / 브랜치: `feature/t-display-mpxv7007`
> 베이스: `feature/t-display-firmware` (M1~M7 WIP)

## 0. 왜 바꾸나

| 항목 | XGZP6847A010KPGPN33 (기존) | **MPXV7007DP + MCP3221 (Diff Press Click)** |
|---|---|---|
| 측정 방식 | Gauge (단일 포트, 대기 대비) | **Differential (양 포트 호스 차압)** |
| 측정 범위 | ±10 kPa (±102 cmH₂O) | ±7 kPa (±71 cmH₂O) |
| 출력 | Analog 0~3.3V (3.3V 모델) | Analog 0.5~4.5V (5V 모델) → **보드 내장 MCP3221 12-bit I²C** |
| MCU 인터페이스 | analogRead(GPIO4) | **Wire (I²C SDA=GPIO43, SCL=GPIO44)** |
| 3.3V GPIO 보호 | 직접 입력 가능 (3.3V 센서) | **보드 내장 ADC 가 5V 영역 전부 흡수 — GPIO 노출 없음** ✅ |
| 영점 안정성 | 1.45V (제조 편차 ±50mV) | **차압 0 = 2.5V 고정 (대기끼리 빼서 자체 보정)** |
| 노이즈 | 100Hz EMA 로 충분 | 12-bit ADC + I²C burst → 더 깨끗 |
| 가격 | 28,000원 | 약 48,000원 (Click 보드) |

핵심: **분압 회로 / 전압 클램프 불필요 + 차압 = 호기/흡기 자동 구분 + 영점 드리프트 최소**.

## 1. 핀 할당 (확정 — 2026-05-24 schematic 확인 후 최종)

```
LILYGO T-Display S3 — 사용자 외부 헤더
├─ GPIO43 (UART0 TX, but USB-CDC 사용 중이므로 free) ─ I²C SDA → Click SDA
├─ GPIO44 (UART0 RX, 위와 동일)                       ─ I²C SCL → Click SCL
├─ GPIO10  ─ Vibration (PWM) [기존 유지]
├─ GPIO11  ─ LED status [기존 유지]
├─ GPIO14  ─ BUTTON_USER (T-Display S3 내장) [기존 유지]
├─ 3V3 ──┬─→ Click 3.3V  (MCP3221 VDD via JP1, I²C 풀업)
│         └─→ Click 5V    (MPXV7007 Vs — under-spec 3.3V 운용, schematic 분석으로 안전 확정)
└─ GND ────→ Click GND
```

**전원 토폴로지**: Option B1 (3V3 단일 레일, 부품 추가 없음). 자세한 배경
은 §7 참조. Click 보드 안에 3V3 패드 ↔ 5V 패드를 짧은 점퍼 와이어로 bridge
하면 외부 배선 = 4선 (3V3, GND, SDA, SCL).

**JP1 (VCC SEL) jumper**: 가능하면 +3.3V 위치로 설정 (출고 default 는 보통
+5V). 어느 위치든 동작은 동일.

### GPIO43/44 안전성 검토

- ESP32-S3 의 UART0 default TX/RX. `ARDUINO_USB_CDC_ON_BOOT=1` (이미 platformio.ini 에 설정) 로 인해 Serial 출력은 USB 로 라우팅 → UART0 pin 은 free.
- Boot ROM 이 부팅 시 ~100ms 동안 GPIO43 으로 UART log 출력 — MCP3221 은 I²C 주소가 일치하지 않는 신호는 무시하므로 영향 없음.
- 펌웨어 업로드는 USB-Serial/JTAG (GPIO19/20) 경유 — UART0 핀과 무관.

### MCP3221 I²C 주소

- 데이터시트 표준: `0b1001_AAA` (0x48~0x4F). MikroE Click 보드는 보통 **0x4D** (`AAA=101`) 로 출고. MS2 에서 I²C 스캔으로 실측 확인.

## 2. 변환 공식 (MPXV7007DP ratiometric — Vs 무관)

```
Vout = Vs × (0.057 × ΔP + 0.5)       ; ΔP in kPa, Vs ∈ {3.3V, 5V}
ratio = Vout / Vs = 0.057 × ΔP + 0.5  ; ← Vs 약분되어 사라짐
→ ΔP_kPa = (ratio - 0.5) / 0.057
→ ΔP_cmH2O = ΔP_kPa × 10.197 × gain_correction
```

MCP3221 VDD = MPXV7007 Vs = 3.3V (단일 레일) 이라 ratio 수식은 데이터시트 5V 환경과 동일하게 적용 가능. 단, 칩 내부 온도/비선형 보상이 5V trim 이라 ~±2% gain 오차가 잔여 — `gain_correction` 으로 흡수 (§7.3 캘리브레이션 절차 참조).

MCP3221 은 12-bit, **VDD 대비 ratiometric** (= ratio = ADC / 4095). 두 ratiometric 이 cascade 되므로 절대 전압 측정 불필요:

```cpp
const uint16_t adc   = mcp3221_read12();   // 0..4095
const float    ratio = adc / 4095.0f;      // 0.5 @ ΔP=0
const float    kPa   = (ratio - 0.5f) / 0.057f;
const float    cmH2O = kPa * 10.197f;
```

풀스케일 ΔP=+7 kPa → ratio=0.899 → ADC≈3681
풀스케일 ΔP=-7 kPa → ratio=0.101 → ADC≈ 414
정지 (대기끼리) → ratio≈0.5 → ADC≈2048

## 3. 마일스톤 (예상 ~3.5시간)

| MS | 작업 | 산출물 | 검증 |
|---|---|---|---|
| **MS1** | 브랜치 분기 + plan doc + config.h 핀 정의 | 본 문서, config.h | 컴파일은 아직 안 함 |
| **MS2** | I²C 스캔 sketch (tools/i2c_scan/) | 스캔 출력 로그 | Click 보드 주소 1개 검출 (0x48~0x4F) |
| **MS3** | MCP3221 단독 read sketch (tools/mcp3221_test/) | raw ADC + ratio + cmH₂O 시리얼 출력 | 입으로 불어 양수, 빨아 음수, 정지 ≈0 |
| **MS4** | sensor.cpp 교체 (analogRead → Wire) | 본 펌웨어의 sensor::tick() | 호스트 g++ 단위 테스트 그대로 통과 |
| **MS5** | 전체 펌웨어 빌드 + 업로드 + LVGL 화면 검증 | 동작 영상 | M7 lv_tick_set_cb fix 도 같이 검증 |
| **MS6** | 영점 보정 + **게인 캘리브 (NVS 저장)** + saturation guard (±71 cmH₂O) | 캘리브레이션 로그 + NVS dump | 부팅 5초 후 zero offset 안정, ±71 clamp, U자수조 기준 게인 ±5% 안에 수렴 |
| **MS7** | state machine 통합 + 세션 한 사이클 | 시리얼 트레이스 | Standby→Train(4분)→Rest(30s)×3→Summary |
| **MS8** | 커밋 정리 + README/docs 갱신 | git log | 본 doc 의 ⏳ 모두 ✅ |

## 4. 코드 변경 범위 (예고)

- ✏️ `firmware-esp32/include/config.h` — `pins::PRESSURE_SENSOR` 제거, `pins::I2C_SDA/I2C_SCL` 추가, `sensor::MCP3221_ADDR` / `sensor::K_FACTOR_RATIO=0.057` / `sensor::ZERO_RATIO=0.5` 신설. 기존 `K_FACTOR / ZERO_VOLTAGE` 폐기 표시.
- ✏️ `firmware-esp32/include/sensor.h` — API 유지 (`currentCmH2O / tick / calibrateZero / adcToCmH2O`) + `calibrateGain(reference_cmH2O)` 추가 (MS6). `adcToCmH2O` 시그니처는 호스트 테스트 호환 위해 `int adc, float zeroOffset` 그대로 유지하되 내부 식만 교체.
- ✏️ `firmware-esp32/src/sensor.cpp` — `analogRead` → `Wire.requestFrom(MCP3221_ADDR, 2)` + 2-byte read. begin() 신설 (Wire.begin(SDA, SCL, 400kHz)). `g_gainCorrection` 멤버 + NVS load/save (MS6).
- ✏️ `firmware-esp32/src/main.cpp` — `setup()` 에 `Wire.begin(pins::I2C_SDA, pins::I2C_SCL, 400000)` + sensor::loadCalibrationFromNVS() 호출 추가.
- ➕ `firmware-esp32/tools/i2c_scan/` (MS2)
- ➕ `firmware-esp32/tools/mcp3221_test/` (MS3)
- ✏️ `firmware-esp32/README.md` — 센서 + 핀맵 + 전원 토폴로지 + 캘리브 절차 갱신 (MS8)

## 5. 롤백 계획

- 본 브랜치 (`feature/t-display-mpxv7007`) 는 `feature/t-display-firmware` 와 독립. MPXV7007 이 실패하면 `feature/t-display-firmware` 로 돌아가서 XGZP6847 으로 진행 가능.
- ST7735 / XIAO 환경은 `feature/st7735-test` 에 별도 보존됨 (commit 3522e31).

## 6. Open Questions (해결됨/잔여)

- [x] Click 보드 수령 — 완료 (silkscreen "Diff Press click" 확인).
- [x] **전원 토폴로지** — §7 결정: 3.3V 단일 레일 (B1) + 게인 캘리브로 정확도 회복.
- [ ] MPXV7007DP 의 양 포트 호스 연결 방향 — P1=호기측, P2=대기 (open) 가 표준. MS3 빌드 직전에 호기 = 양수 부호인지 시각 확인.
- [ ] U자 수조 마노미터 준비 (캘리브 기준압 발생기) — MS6 시작 전 필요.

## 7. 전원 토폴로지 — 결정 변경 이력

### 7.0 결정 이력

| 날짜 | 결정 | 사유 |
|---|---|---|
| 2026-05-21 | B1 (3V3 분기 → 5V 핀) 선정 | 부품 없이 단순. schematic 확인 없이 추정 |
| 2026-05-24 (오전) | A (TPS61023 boost) 로 변경 | 다른 AI 의 위험 우려 받아들임. schematic 미확인 상태에서 보수적 결정 |
| 2026-05-24 (오후) | **B1 로 재변경 (최종)** | **schematic 확인 (diff-press-schematic-v100) 결과 B1 안전 확정**. 회로가 단순 (MPXV7007 + MCP3221 + JP1 + 풀업/필터). LDO/op-amp/voltage divider 없음. 5V 핀에 3.3V 공급은 단순 under-voltage 운용일 뿐 손상 위험 0. JP1 (VCC SEL) jumper 로 MCP3221 의 VDD 선택 가능 — 어느 위치든 OK |

### 7.1 의사결정 — Option B1 (3V3 단일 레일, schematic 확인 후 최종)

| 옵션 | 부품/공간 | 정확도 | 채택 |
|---|---|---|---|
| **B1. 3V3 → Click 3V3 + Click 5V 양쪽** | 0, 0 | ±0.5~1.0 cmH₂O (under-spec, 호흡 영역 충분) | ⭐ |
| A. TPS61023 boost (3.7V→5V) | +모듈 1개 (17.8×11.3×5.6mm) | spec 보장 (±0.3 cmH₂O) | 미채택 (정확도 차이 미미) |
| C. USB 5V 직결 | 0, 0 | spec 보장 단 배터리 모드 불가 | 개발 단계만 사용 |

선정 이유:
- **Schematic 확인** (diff-press-schematic-v100.pdf):
  - 단순 회로 — MPXV7007 + MCP3221 + JP1 + 풀업 R2/R3 + 필터 C1~C4
  - LDO, op-amp, voltage divider 등 5V 의존 회로 **전무**
  - MPXV7007 VOUT → MCP3221 AIN 직결 (중간 scaling 없음)
- 5V 핀에 3.3V 공급은 단순 under-voltage 운용 — 손상 위험 0
- 호흡 훈련 응용 정확도 충분 (±1 cmH₂O zone 폭 10cmH₂O 의 10%)
- 부품 추가 없음 — 케이스 portability 우선

### 7.2 회로 — 4선 외부 배선 + JP1 설정

```
T-Display 3V3 ──┬──→ Click 3V3 핀  ──→ (직결) MCP3221 VDD (JP1=3.3V 위치)
                │                       또는 풀업 R2/R3
                └──→ Click 5V 핀  ──→ (직결) MPXV7007 Vs (under-spec 운용)

T-Display GND ────→ Click GND
T-Display GPIO43 ─→ Click SDA
T-Display GPIO44 ─→ Click SCL
```

총 4선 외부 배선 (3V3, GND, SDA, SCL) + Click 보드 안에서 3V3 ↔ 5V 짧은
점퍼 와이어로 bridge (또는 외부에서 분기).

### 7.3 JP1 (VCC SEL) jumper

Click 보드에 3핀 jumper. MCP3221 의 VDD 선택:
- **JP1 = 3.3V 위치** (권장 — 모든 회로 직결 3.3V, 가장 명확)
- JP1 = 5V 위치 (출고 default — 우리 케이스에선 5V 핀에 3.3V 가 들어오므로
  결과적으로 같은 3.3V. 동작 동일)

MikroE 출고 default = +5V 위치 (일반적). 우리 B1 운용 시 어느 위치든
동작하지만 깔끔하게 JP1 을 +3.3V 위치로 옮기는 것을 권장.

### 7.4 회로상 안전성 (schematic 분석 결과)

5V 핀에 3.3V 공급해도 손상 위험이 0인 이유:
- LDO regulator 없음 → reverse current 불가능
- op-amp / voltage divider scaling 회로 없음 → under-voltage 시 비선형 없음
- MPXV7007 의 VCC pin (3번) 은 단순 전원 → 3.3V 가 spec 밖이지만 회로
  손상 메커니즘 자체가 없음 (단순 op-amp 내장 트랜지스터의 bias 만 줄어듦)
- MCP3221 의 VDD = 어차피 우리 JP1 설정에 따라 3.3V 로 작동 → 그 자체로
  spec 안 (2.7~5.5V)

### 7.5 변환식 — 변경 없음

```
ratio = ADC / 4095 = Vout / Vs    ← ratiometric, Vs 무관
ΔP_kPa = (ratio - 0.5) / 0.057
ΔP_cmH2O = ΔP_kPa × 10.197
```

MCP3221 VDD = MPXV7007 Vs = 3.3V (단일 레일) → ratio 계산 동일. 펌웨어의
config.h 변경 불필요.

### 7.6 캘리브레이션 (MS6 에서 구현)

자동 (매 부팅): 영점 보정 — 2초간 ADC 평균 → zeroOffset 저장. config.h 의
`ZERO_CALIBRATION_SAMPLES = 200` 이미 설정.

1회성 (양산 단계 또는 정확도 요구 시): 게인 캘리브 — under-spec 운용의
~±2% gain 편차 흡수. U자 수조 마노미터 기준값으로 보정 → NVS 영구 저장.
필수 아님 (호흡 영역에선 영점만으로도 충분).

### 7.7 배터리 통합 (MS8 이후)

본 토폴로지 (B1) 는 **T-Display 의 3V3 핀** 만 사용 → 배터리 모드 (USB
미연결) 에서도 T-Display 내부 LDO 가 그대로 3.3V 공급 → **추가 boost
converter 불필요**.

LiPo 400mAh + JST PH 1.25mm 커넥터 → T-Display S3 배터리 입력 → 내부 LDO
→ 3.3V → 화면 + ESP32 + (분기) Click 보드 전원 (3V3 핀 + 5V 핀 양쪽).

### 7.3 캘리브레이션 절차 (MS6 에서 구현)

**자동 (매 부팅)**: 영점 보정 — 5초간 ADC 평균을 `zeroOffsetCmH2O` 로 저장. 사용자는 마우스피스 입에 물기 전 상태 유지.

**1회성 (사용자 또는 공장 단계)**: 게인 캘리브 — NVS 에 영구 저장.

```cpp
// sensor.h
void calibrateGain(float reference_cmH2O);   // 트리거: BLE opcode 또는 long-press 버튼
float currentCmH2O();                         // 내부에서 ×g_gainCorrection 자동 적용
void  loadCalibrationFromNVS();               // setup() 에서 호출
```

기준 압력 발생기:
- **U자 수조 마노미터** — 물 채운 호스 한쪽을 마우스피스에, 한쪽은 대기. 수면 높이차 = cmH₂O 직접값.
- 약 1만원 (호스 + 자 + 보드) / 정확도 ±0.5 cmH₂O / 측정 절차 5분.
- 더 정밀하게 가려면 임상용 압력계 (Fluke RPM 시리즈 등) — 양산 단계에서 결정.

캘리브 적용 시점:
- (a) 매 디바이스 1회 (양산 단계, 공장에서)
- (b) 사용자가 정확도 의심 시 재캘리브 가능 (Settings UI 에서 트리거)


---

본 doc 는 작업 진행에 따라 inline 으로 갱신. 최종은 MS8 에서 README 로 정리.
