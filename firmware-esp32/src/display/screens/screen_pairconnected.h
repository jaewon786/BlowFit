// 연결 완료 화면 (PairConnected).
//
// 설계: BlowFit.html ScrPairConnected — 다크 배경 + 상단 status bar (BT
// connected) + 중앙 초록 원 + 체크 심볼 + "연결 완료" + "훈련 준비 완료".
//
// 호출 시점: setup() 의 페어링 대기 loop 가 연결 감지한 직후. 약 2초간
// 표시 후 Standby 로 자동 전환.

#pragma once

namespace screens {

  void pairconnected_show();

}  // namespace screens
