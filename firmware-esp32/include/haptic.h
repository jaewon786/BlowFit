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

  /// 미리 정의한 효과 ID (ROM library 1, TS2200 Library A).
  /// 강하고 긴(=잘 느껴지는) 효과 위주로 선택. 더 길게 하려면 play() 의
  /// repeat 인자로 시퀀스 반복.
  ///   1 = Strong Click 100% (짧은 tick), 14 = Strong Buzz 100%,
  ///   15 = 750ms Alert 100%, 16 = 1000ms Alert 100%
  enum Effect : uint8_t {
    SESSION_START = 16,  // 1000ms Alert 100% — 세션 시작 (길고 강하게)
    EXHALE_CUE    = 15,  // 750ms Alert 100%  — 호기(불기) 시작 cue
    INHALE_CUE    = 15,  // 750ms Alert 100%  — 흡기(마시기) 시작 cue
    REST_TICK     = 1,   // Strong Click      — 호흡 내 휴식(5s) 시작 짧은 cue
    REST_CUE      = 16,  // 1000ms Alert 100% — 세트 사이 휴식(30s) 전환 cue
    SESSION_DONE  = 16,  // 1000ms Alert 100% — 세션 완료 (repeat 로 길게)
    POWER_ON      = 16,  // 1000ms Alert 100% — 전원 켜짐 알림 (버튼 wake 시)
    POWER_OFF     = 16,  // 1000ms Alert 100% — 전원 꺼짐 알림 (sleep 직전)
  };

  /// EN HIGH + I²C 초기화 (ERM open-loop, library 1). Wire.begin() 은 호출자가
  /// 먼저 수행해야 함 (main.cpp 에서 sensor 와 공유). 통신 실패 시 isReady()=false.
  void begin();

  /// 초기화(디바이스 응답) 성공 여부.
  bool isReady();

  /// 효과 재생 (GO bit). repeat 로 같은 효과를 파형 시퀀서에 이어붙여 지속시간
  /// 을 늘림 (1~8, non-blocking — 칩이 자동으로 연속 재생). 기본 1회.
  void play(uint8_t effect, uint8_t repeat = 1);

}  // namespace haptic
