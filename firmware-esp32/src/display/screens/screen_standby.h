// 대기 화면 (Standby) — 부팅 후 첫 화면.
//
// 구성:
//   상단 status bar — BLE 연결 / 배터리 잔량
//   중앙 로고 — "BlowFit" + "v4.0"
//   중간 일러스트 — 마우스피스 입 아이콘 (LVGL 원으로 그림)
//   하단 안내문 — "입에 무세요" + "대기 중..."
//
// 후속 화면 (Prep, Train, Rest, Summary) 도 같은 패턴으로 screens/ 안에 모듈화.

#pragma once

#include <stdint.h>

namespace screens {

  /// 대기 화면 렌더링 — lvgl_port::begin() 이후 한 번 호출.
  /// 내부에서 lv_screen_active() 의 자식으로 위젯들 생성.
  void standby_show();

  /// BLE 연결 상태 갱신 (true=연결, false=대기).
  void standby_set_connected(bool connected);

  /// 배터리 % 갱신 (0~100). -1 이면 측정 불가 / 숨김.
  void standby_set_battery(int8_t percent);

  /// 현재 다이얼 단계 표시 갱신 — level 0/1/2 → "다이얼 1/2/3단".
  void standby_set_orifice(uint8_t level);

}  // namespace screens
