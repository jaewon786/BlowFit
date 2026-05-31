// 공용 상단 status bar (170×20) — BT 아이콘(좌) + 배터리(우).
// 디자인 device-display.jsx DStatusBar 와 동일 구성. 모든 기기 화면 공용.
#pragma once

#include <lvgl.h>

namespace screens {

/// [parent] 상단에 status bar 생성.
///   connected: BT 아이콘 색 (true=primary, false=muted gray)
///   battery_pct: 0~100 배터리 잔량. <0 이면 "--%".
void make_status_bar(lv_obj_t* parent, bool connected, int battery_pct);

}  // namespace screens
