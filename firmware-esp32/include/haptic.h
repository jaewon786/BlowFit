// DRV2605L 햅틱 모터 드라이버 (SparkFun Qwiic Haptic Motor Driver).
//
// I²C addr 0x5A, MCP3221(0x4D) 과 같은 버스(SDA=GPIO43, SCL=GPIO44) 공유.
// EN 핀(GPIO10) HIGH 로 칩 enable, 효과 트리거는 내부 ROM library + GO bit.
// 코인형 ERM 진동 모터(DC 3V) open-loop 구동. 외부 라이브러리 없이 Wire 직접 제어.
//
// 효과 ID 는 DRV2605L ROM "Waveform Library Effects List" (library 1, TS2200 ERM A).

#pragma once

#include <stdint.h>

namespace haptic {

  /// 미리 정의한 효과 ID (ROM library 1). 필요 시 datasheet 목록에서 교체.
  enum Effect : uint8_t {
    SESSION_START = 1,   // Strong Click 100% — 세션 시작
    EXHALE_CUE    = 4,   // Sharp Click 100%  — 호기(불기) 시작 cue
    INHALE_CUE    = 7,   // Soft Bump 100%    — 흡기(마시기) 시작 cue
    SESSION_DONE  = 12,  // Triple Click 100% — 세션 완료
  };

  /// EN HIGH + I²C 초기화 (ERM open-loop, library 1). Wire.begin() 은 호출자가
  /// 먼저 수행해야 함 (main.cpp 에서 sensor 와 공유). 통신 실패 시 isReady()=false.
  void begin();

  /// 초기화(디바이스 응답) 성공 여부.
  bool isReady();

  /// 효과 1개 재생 (GO bit).
  void play(uint8_t effect);

}  // namespace haptic
