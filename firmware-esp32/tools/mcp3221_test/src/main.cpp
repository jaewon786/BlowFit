// MCP3221 단독 read 테스트 — MPXV7007DP 차압 센서 검증.
//
// 동작:
//   1. Wire.begin(SDA=43, SCL=44, 400kHz)
//   2. 200ms 마다 MCP3221 의 12-bit ADC 값 read
//   3. ratio (0..1), kPa, cmH2O 변환 + 시리얼 출력
//
// MCP3221 datasheet 의 read format:
//   Byte 1 (MSB): 0 0 0 0 D11 D10 D9 D8   ← upper nibble = 0
//   Byte 2 (LSB): D7 D6 D5 D4 D3 D2 D1 D0
//   12-bit value = ((byte1 & 0x0F) << 8) | byte2  (0~4095)
//
// MPXV7007DP ratiometric 출력 (Vs 무관, ratio 만 보면 됨):
//   ratio = adc / 4095 = 0.057 × ΔP_kPa + 0.5
//   ΔP_kPa = (ratio - 0.5) / 0.057
//   ΔP_cmH2O = ΔP_kPa × 10.197
//
// 우리 환경 — B1 (3.3V Vs, under-spec 운용):
//   - MPXV7007 Vs = 3.3V (datasheet 권장 4.75~5.25V)
//   - 출력 swing 66% 축소 (정확도 ±2~5%)
//   - 호흡 영역 (20~30 cmH2O) 충분
//
// 사용자 검증 절차:
//   1. USB 연결 + 시리얼 모니터 열기
//   2. 정지 (마우스피스 안 물기) → cmH2O ≈ ±0~3 (영점 미보정)
//   3. 호기 (입으로 후 불기, 강도 점점 세게) → cmH2O 양수 증가
//   4. 흡기 (입으로 빨기) → cmH2O 음수 감소
//   5. 호스 한 쪽 (P1) 만 마우스피스 → 양압/음압 둘 다 발생

#include <Arduino.h>
#include <Wire.h>

constexpr uint8_t  I2C_SDA       = 43;
constexpr uint8_t  I2C_SCL       = 44;
constexpr uint32_t I2C_FREQ_HZ   = 400000;
constexpr uint8_t  MCP3221_ADDR  = 0x4D;

// MCP3221 의 출력 sample 주기 = 약 31.25 μs (32kHz).
// 우리 read 주기 = 200ms (5Hz) — 사용자 시각 확인용 적당한 속도.
constexpr uint32_t SAMPLE_INTERVAL_MS = 200;

void setup() {
  // T-Display S3 화면 LDO enable — 시각 확인용 (i2c_scan 과 동일).
  pinMode(15, OUTPUT);
  digitalWrite(15, HIGH);

  Serial.begin(115200);
  delay(500);
  Serial.println();
  Serial.println("====================================================");
  Serial.println("BlowFit — MCP3221 read test");
  Serial.println("Build: " __DATE__ " " __TIME__);
  Serial.printf ("I2C: SDA=GPIO%u SCL=GPIO%u @ %lu Hz  addr=0x%02X\n",
                 I2C_SDA, I2C_SCL, (unsigned long)I2C_FREQ_HZ,
                 (unsigned)MCP3221_ADDR);
  Serial.println("Format: [t_ms] raw=NNNN  ratio=N.NNNN  kPa=±N.NN  cmH2O=±NN.NN");
  Serial.println("");
  Serial.println("Test:");
  Serial.println("  - 정지 → cmH2O ≈ 0 (±몇 cmH2O 영점 미보정)");
  Serial.println("  - 호기 → cmH2O 양수 증가");
  Serial.println("  - 흡기 → cmH2O 음수 감소");
  Serial.println("====================================================");

  Wire.begin(I2C_SDA, I2C_SCL, I2C_FREQ_HZ);
  delay(100);
}

void loop() {
  static uint32_t last_sample_ms = 0;
  const uint32_t now = millis();
  if (now - last_sample_ms < SAMPLE_INTERVAL_MS) return;
  last_sample_ms = now;

  // MCP3221 read — 2 byte.
  const uint8_t got = Wire.requestFrom(MCP3221_ADDR, (uint8_t)2);
  if (got < 2) {
    Serial.printf("[%lu] read failed (got %u bytes)\n",
                  (unsigned long)now, (unsigned)got);
    return;
  }
  const uint8_t hi = Wire.read();
  const uint8_t lo = Wire.read();
  const uint16_t adc = ((uint16_t)(hi & 0x0F) << 8) | lo;

  // 변환식 (ratiometric, Vs 무관).
  const float ratio = adc / 4095.0f;
  const float kPa = (ratio - 0.5f) / 0.057f;
  const float cmH2O = kPa * 10.197f;

  // 출력 — 정렬된 column 으로 시각 추적 쉽게.
  Serial.printf("[%6lu] raw=%4u  ratio=%.4f  kPa=%+6.2f  cmH2O=%+7.2f\n",
                (unsigned long)now, (unsigned)adc, ratio, kPa, cmH2O);
}
