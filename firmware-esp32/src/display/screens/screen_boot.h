// 부팅 / 로딩 화면 (Boot).
//
// 설계: BlowFit.html ScrBoot — 다크 배경 + 80×80 파랑 로고 원 + "BlowFit"
// 텍스트 + 하단 LVGL spinner.
//
// 호출: setup() 에서 한 번 호출, 부팅 후 3초간 표시. 그 뒤 calibrateZero
// 동안 정지 화면 유지 → 끝나면 session state machine 의 Boot→Standby
// 전환에 따라 자동으로 다음 화면으로.

#pragma once

namespace screens {

  /// 부팅 화면 렌더링.
  void boot_show();

}  // namespace screens
