// TFT_eSPI Setup206 — LILYGO T-Display S3 (ST7789, 1.9" IPS, 170×320, 8-bit
// parallel). LILYGO 공식 example 의 setup 과 동일.
//
// 세로 (portrait) 기본: TFT_WIDTH=170, TFT_HEIGHT=320. main.cpp 에서
// tft.setRotation(0) — 시계방향 0도 (스피커/USB 가 아래쪽).
//
// 참고: GPIO15 (PWR/LDO enable) 는 TFT_eSPI 에서 처리하지 않음. main.cpp 의
// setup() 에서 HIGH 로 직접 세팅해야 배터리 모드에서 디스플레이가 켜진다.

#pragma once

// ----- Driver -----
#define USER_SETUP_ID 206
#define ST7789_DRIVER
#define INIT_SEQUENCE_3
#define CGRAM_OFFSET

// ST7789 panel 의 RGB → BGR 정렬 보정 (LILYGO 패널은 RGB)
#define TFT_RGB_ORDER TFT_RGB

// ----- Interface (8-bit parallel) -----
#define TFT_PARALLEL_8_BIT
#define TFT_INVERSION_ON

// ----- Panel size (세로 모드 native) -----
#define TFT_WIDTH  170
#define TFT_HEIGHT 320

// ----- Pin mapping (T-Display S3 보드 고정 배선) -----
#define TFT_DC    7   // RS / DC
#define TFT_RST   5   // 리셋
#define TFT_WR    8   // 쓰기 strobe
#define TFT_RD    9   // 읽기 strobe

#define TFT_D0   39
#define TFT_D1   40
#define TFT_D2   41
#define TFT_D3   42
#define TFT_D4   45
#define TFT_D5   46
#define TFT_D6   47
#define TFT_D7   48

// CS 는 보드에 GND 로 직결되어 있어서 TFT_eSPI 에서 사용 안 함.
// (보드 schematic: TFT_CS to GND)

// ----- Backlight (GPIO38, PWM 가능) -----
#define TFT_BL              38
#define TFT_BACKLIGHT_ON    HIGH

// ----- Font (LVGL 사용시 TFT_eSPI 폰트는 거의 안 씀, 그래도 기본 로딩) -----
#define LOAD_GLCD
#define LOAD_FONT2
#define LOAD_FONT4
#define LOAD_FONT6
#define LOAD_FONT7
#define LOAD_FONT8
#define LOAD_GFXFF
#define SMOOTH_FONT

// ----- SPI freq (parallel 이라 사실상 의미 없음) -----
#define SPI_FREQUENCY  27000000
#define SPI_READ_FREQUENCY  20000000

// ----- Caveat: PWR_ON (GPIO15) -----
// 이 핀은 T-Display S3 의 LDO enable 로 디스플레이 전원 자체를 켠다.
// USB 전원 모드에서는 default HIGH 일 수 있으나 배터리 모드에서는 반드시
// firmware setup() 에서 pinMode(15, OUTPUT) + digitalWrite(15, HIGH) 해야 함.
