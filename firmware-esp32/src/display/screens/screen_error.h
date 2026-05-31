// 오류 화면 (Error) — 연결 끊김 / 충전 필요. device-display.jsx ScrError.
#pragma once

#include <cstdint>

namespace screens {

enum class ErrorKind : uint8_t {
  Disconnect,  // 블루투스 연결 끊김
  Battery,     // 저배터리 / 충전 필요
};

/// 오류 화면 표시. (트리거: 연결 끊김 감지 / 저배터리 — 후속 배터리 감지 연동)
void error_show(ErrorKind kind);

}  // namespace screens
