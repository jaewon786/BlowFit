// haptic.cpp — DRV2605L 햅틱 드라이버 구동 (raw Wire 레지스터 제어).
//
// 초기화 시퀀스는 TI DRV2605L datasheet + Adafruit_DRV2605 begin() 흐름을 따름:
//   standby 해제 → internal trigger → ERM open-loop → ROM library 1.

#include "haptic.h"
#include "config.h"

#include <Arduino.h>
#include <Wire.h>

namespace haptic {

namespace {

  constexpr uint8_t ADDR = 0x5A;  // DRV2605L 고정 I²C 주소

  // 레지스터 맵 (datasheet).
  constexpr uint8_t REG_STATUS    = 0x00;
  constexpr uint8_t REG_MODE      = 0x01;
  constexpr uint8_t REG_RTPIN     = 0x02;
  constexpr uint8_t REG_LIBRARY   = 0x03;
  constexpr uint8_t REG_WAVESEQ1  = 0x04;
  constexpr uint8_t REG_WAVESEQ2  = 0x05;
  constexpr uint8_t REG_GO        = 0x0C;
  constexpr uint8_t REG_OVERDRIVE = 0x0D;
  constexpr uint8_t REG_SUSTAINP  = 0x0E;
  constexpr uint8_t REG_SUSTAINN  = 0x0F;
  constexpr uint8_t REG_BREAK     = 0x10;
  constexpr uint8_t REG_AUDIOMAX  = 0x11;
  constexpr uint8_t REG_FEEDBACK  = 0x1A;
  constexpr uint8_t REG_CONTROL3  = 0x1D;

  bool g_ready = false;

  void w8(uint8_t reg, uint8_t val) {
    Wire.beginTransmission(ADDR);
    Wire.write(reg);
    Wire.write(val);
    Wire.endTransmission();
  }

  uint8_t r8(uint8_t reg) {
    Wire.beginTransmission(ADDR);
    Wire.write(reg);
    Wire.endTransmission(false);  // repeated start
    const uint8_t got = Wire.requestFrom(ADDR, (uint8_t)1);
    return (got >= 1) ? Wire.read() : 0;
  }

}  // namespace

void begin() {
  // EN HIGH — 칩 enable (standby 해제 전 필수).
  pinMode(pins::HAPTIC_EN, OUTPUT);
  digitalWrite(pins::HAPTIC_EN, HIGH);
  delay(5);

  // Wire 는 main.cpp 에서 이미 begin (sensor 와 공유). device 응답 확인.
  const uint8_t status = r8(REG_STATUS);
  if (status == 0x00 || status == 0xFF) {
    g_ready = false;
    Serial.println("[haptic] DRV2605L not responding (skip)");
    return;
  }

  w8(REG_MODE, 0x00);       // standby 해제 + internal trigger mode
  w8(REG_RTPIN, 0x00);      // real-time playback 비활성
  w8(REG_WAVESEQ1, 1);      // 기본 effect (slot 0)
  w8(REG_WAVESEQ2, 0);      // 시퀀스 종료
  w8(REG_OVERDRIVE, 0);
  w8(REG_SUSTAINP, 0);
  w8(REG_SUSTAINN, 0);
  w8(REG_BREAK, 0);
  w8(REG_AUDIOMAX, 0x64);
  // ERM open-loop: FEEDBACK bit7(N_ERM_LRA)=0, CONTROL3 bit5(ERM_OPEN_LOOP)=1.
  w8(REG_FEEDBACK, r8(REG_FEEDBACK) & 0x7F);
  w8(REG_CONTROL3, r8(REG_CONTROL3) | 0x20);
  // ROM library 1 (TS2200 ERM A).
  w8(REG_LIBRARY, 1);

  g_ready = true;
  Serial.println("[haptic] DRV2605L ready (ERM open-loop, lib 1)");
}

bool isReady() { return g_ready; }

void play(uint8_t effect, uint8_t repeat) {
  if (!g_ready) return;
  if (repeat < 1) repeat = 1;
  if (repeat > 8) repeat = 8;  // WAVESEQ1..8 (0x04..0x0B)
  // 같은 효과를 시퀀스 슬롯에 repeat 개 채움 → 칩이 연속 재생 (지속시간 ↑).
  for (uint8_t i = 0; i < repeat; i++) {
    w8(REG_WAVESEQ1 + i, effect);
  }
  // 8개 미만이면 다음 슬롯에 0 으로 시퀀스 종료.
  if (repeat < 8) {
    w8(REG_WAVESEQ1 + repeat, 0);
  }
  w8(REG_GO, 1);
}

}  // namespace haptic
