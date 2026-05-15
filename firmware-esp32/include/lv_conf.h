// LVGL v9 설정 — BlowFit v4.0 (T-Display S3, 170×320 세로).
//
// 위치: firmware-esp32/lv_conf.h (platformio.ini 의 LV_CONF_PATH 매크로 참조).
// LVGL 라이브러리는 LV_CONF_INCLUDE_SIMPLE 가 켜져 있으면 이 파일을 자동 include.

#ifndef LV_CONF_H
#define LV_CONF_H

#include <stdint.h>

// ============================================================================
// 색상 / 메모리
// ============================================================================
#define LV_COLOR_DEPTH         16          // ST7789 RGB565
#define LV_COLOR_16_SWAP       1           // ESP32 little-endian → SPI byte swap
#define LV_USE_DRAW_SW         1
#define LV_DRAW_SW_COMPLEX     1

// SW renderer ASM 가속 = NONE (ESP32-S3 Xtensa 는 ARM NEON/Helium 미지원 →
// 명시 안 하면 LVGL 빌드 시스템이 helium .S 파일을 Xtensa 어셈블러로 컴파일
// 시도하면서 "unknown opcode 'typedef'" 에러 발생.)
#define LV_DRAW_SW_ASM_NONE    0
#define LV_DRAW_SW_ASM_NEON    1
#define LV_DRAW_SW_ASM_HELIUM  2
#define LV_DRAW_SW_ASM_CUSTOM  255
#define LV_DRAW_SW_ASM         LV_DRAW_SW_ASM_NONE

// LVGL 내부 메모리 풀 — PSRAM 활용 가능하지만 일단 internal heap 48KB.
#define LV_MEM_CUSTOM          0
#define LV_MEM_SIZE            (48 * 1024)
#define LV_MEM_POOL_INCLUDE    <stdlib.h>

// ============================================================================
// HAL — tick / 입력
// ============================================================================
#define LV_TICK_CUSTOM         1
#define LV_TICK_CUSTOM_INCLUDE "Arduino.h"
#define LV_TICK_CUSTOM_SYS_TIME_EXPR (millis())

#define LV_DISP_DEF_REFR_PERIOD   16    // ~60 FPS
#define LV_INDEV_DEF_READ_PERIOD  30

// ============================================================================
// 위젯 활성화 (M2~M7 에서 사용)
// ============================================================================
#define LV_USE_LABEL           1
#define LV_USE_BAR             1
#define LV_USE_ARC             1
#define LV_USE_BUTTON          1
#define LV_USE_IMG             1
#define LV_USE_LINE            1
#define LV_USE_OBJ_PROPERTY    1
#define LV_USE_ANIMIMG         1

// ============================================================================
// 폰트
// ============================================================================
#define LV_FONT_MONTSERRAT_12  1
#define LV_FONT_MONTSERRAT_14  1
#define LV_FONT_MONTSERRAT_16  1
#define LV_FONT_MONTSERRAT_20  1
#define LV_FONT_MONTSERRAT_28  1
#define LV_FONT_MONTSERRAT_48  1    // 큰 압력 숫자 표시용

#define LV_FONT_DEFAULT &lv_font_montserrat_14

// 한글 폰트는 M3 에서 Pretendard subset 추가 예정 — 그 전까지 영문만.

// ============================================================================
// 디버그 / 로그
// ============================================================================
#define LV_USE_LOG             1
#define LV_LOG_LEVEL           LV_LOG_LEVEL_WARN
#define LV_LOG_PRINTF          1     // printf() 로 출력 → 시리얼

// PERF_MONITOR / MEM_MONITOR — M2 (LVGL 통합) 단계에서 활성 예정. M1 빌드 통과
// 우선이라 default 0 으로 둠. (1 로 두면 LVGL internal default 와 redefine
// 경고 발생 — 본질적 문제는 아니지만 로그 노이즈)
#define LV_USE_PERF_MONITOR    0
#define LV_USE_MEM_MONITOR     0

// ============================================================================
// 기타
// ============================================================================
#define LV_USE_ASSERT_NULL        1
#define LV_USE_ASSERT_MALLOC      1
#define LV_USE_ASSERT_STYLE       0
#define LV_USE_ASSERT_MEM_INTEGRITY  0
#define LV_USE_ASSERT_OBJ         0

#define LV_CACHE_DEF_SIZE         0

#endif // LV_CONF_H
