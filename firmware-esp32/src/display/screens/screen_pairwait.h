// 페어링 대기 화면 (PairWait).
//
// 설계: BlowFit.html ScrPairWait — 다크 배경 + 상단 status bar (BT off) +
// 중앙 파란 원 + BT 심볼 + "연결 대기 중" + 하단 spinner.
//
// 호출 시점: setup() 에서 boot/calibrate 끝 + ble_service::begin() 후.
// 앱이 BLE 로 연결될 때까지 무한 표시.

#pragma once

namespace screens {

  void pairwait_show();

}  // namespace screens
