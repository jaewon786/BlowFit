// I²C 버스 스캐너 — LILYGO T-Display S3 + MikroE Diff Press Click 검증용.
//
// 동작:
//   1. Wire.begin(SDA=43, SCL=44, 400kHz)
//   2. 0x01~0x7F 까지 모든 7-bit 주소에 대해 빈 transmission 시도
//   3. ACK 받은 주소를 시리얼로 출력
//   4. 5초 주기로 반복 — 핫플러그 / 노이즈 확인용
//
// 결과 해석:
//   - 0x48~0x4F 사이 단일 주소 → MCP3221 정상. 그 값을 본 펌웨어
//     include/config.h 의 sensor::MCP3221_ADDR 에 반영.
//   - 아무 주소도 안 잡힘 → 배선 / 풀업 / 전원 점검 (Click 보드는 내장
//     풀업이 있어서 외부 풀업 불필요).
//   - 여러 주소가 잡힘 → 다른 I²C 디바이스가 연결되어 있음. 본 보드 단독
//     환경이면 의심 (재배선).
//
// 참고: MCP3221 데이터시트 — 주소 패턴 0b1001_AAA (0x48~0x4F). MikroE
// 출고시 일반적으로 0x4D (AAA=101).

#include <Arduino.h>
#include <Wire.h>

// 디버그용 핀 대체 — GPIO43/44 로 응답 없는 경우 GPIO17/18 시도.
// (build_flags 로 -DUSE_ALT_PINS 지정하면 17/18 사용)
#ifdef USE_ALT_PINS
  constexpr uint8_t I2C_SDA = 17;
  constexpr uint8_t I2C_SCL = 18;
#else
  constexpr uint8_t I2C_SDA = 43;       // GPIO43 (UART0 TX, free in USB-CDC mode)
  constexpr uint8_t I2C_SCL = 44;       // GPIO44 (UART0 RX, free in USB-CDC mode)
#endif
constexpr uint32_t I2C_FREQ_HZ = 400000;  // Fast-mode

void scan_once(uint32_t freq_hz) {
  Wire.setClock(freq_hz);
  Serial.println();
  Serial.print("Scanning I2C bus @ ");
  Serial.print(freq_hz / 1000);
  Serial.println(" kHz ...");

  uint8_t found = 0;
  // Wire.endTransmission() error codes (Arduino-ESP32):
  //   0=success  1=data_too_long  2=NACK_on_address  3=NACK_on_data
  //   4=other_error  5=timeout
  uint16_t errCount[6] = {0, 0, 0, 0, 0, 0};

  for (uint8_t addr = 0x01; addr < 0x7F; ++addr) {
    Wire.beginTransmission(addr);
    const uint8_t err = Wire.endTransmission();
    if (err <= 5) errCount[err]++;
    if (err == 0) {
      Serial.print("  device @ 0x");
      if (addr < 0x10) Serial.print('0');
      Serial.print(addr, HEX);
      if (addr >= 0x48 && addr <= 0x4F) {
        Serial.print("  ← matches MCP3221 address range (0x48..0x4F)");
      }
      Serial.println();
      ++found;
    }
  }

  if (found == 0) {
    Serial.println("  (no devices found)");
    Serial.print("  error histogram: NACK_addr=");
    Serial.print(errCount[2]);
    Serial.print(" NACK_data=");
    Serial.print(errCount[3]);
    Serial.print(" other=");
    Serial.print(errCount[4]);
    Serial.print(" timeout=");
    Serial.println(errCount[5]);
    Serial.println("  diagnosis:");
    if (errCount[2] >= 120) {
      Serial.println("    NACK_addr 가 거의 전부 → 버스는 살아있고 풀업 OK,");
      Serial.println("    그러나 응답하는 chip 이 없음. 가장 흔한 원인:");
      Serial.println("      (a) MCP3221 의 VDD 가 안 들어옴 → 5V 연결 추가");
      Serial.println("      (b) SDA/SCL 스왑 → 두 선 한 번 바꿔서 재테스트");
    } else if (errCount[5] > 0 || errCount[4] > 0) {
      Serial.println("    timeout/other 다수 → SDA 또는 SCL 이 GND 와 short,");
      Serial.println("    또는 풀업 없음. 배선 / Click 보드 인식 다시 확인.");
    }
  } else {
    Serial.print("Total: ");
    Serial.print(found);
    Serial.println(" device(s)");
  }
}

void setup() {
  Serial.begin(115200);
  delay(500);
  Serial.println();
  Serial.println("====================================================");
  Serial.println("BlowFit — I2C bus scanner");
  Serial.println("Build: " __DATE__ " " __TIME__);
  Serial.print  ("Pins:  SDA=GPIO");
  Serial.print  (I2C_SDA);
  Serial.print  ("  SCL=GPIO");
  Serial.print  (I2C_SCL);
  Serial.println("  freq=400kHz (then 100kHz fallback)");
  Serial.println("====================================================");

  Wire.begin(I2C_SDA, I2C_SCL, I2C_FREQ_HZ);
  delay(100);
}

void loop() {
  // 400kHz fast-mode 우선, 응답 없으면 100kHz standard-mode 도 시도.
  // 긴 점퍼선 / 브레드보드 / 약한 풀업 환경에서 400kHz 가 실패하는 경우 대비.
  scan_once(I2C_FREQ_HZ);
  scan_once(100000);
  delay(5000);
}
