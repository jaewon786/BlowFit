// Single source of truth for BLE UUIDs. Must match:
//   docs/ble-protocol.md
//   firmware/ble_uuids.h
//   tools/ble-sim.py

import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class BlowfitUuids {
  BlowfitUuids._();

  static final service         = Guid('0000b410-0000-1000-8000-00805f9b34fb');
  static final pressureStream  = Guid('0000b411-0000-1000-8000-00805f9b34fb');
  static final sessionControl  = Guid('0000b412-0000-1000-8000-00805f9b34fb');
  static final sessionSummary  = Guid('0000b413-0000-1000-8000-00805f9b34fb');
  static final deviceState     = Guid('0000b414-0000-1000-8000-00805f9b34fb');
  static final historyList     = Guid('0000b415-0000-1000-8000-00805f9b34fb');

  static final batteryService  = Guid('0000180f-0000-1000-8000-00805f9b34fb');
  static final batteryLevel    = Guid('00002a19-0000-1000-8000-00805f9b34fb');

  static const deviceNamePrefix = 'BRELOW';
}

// Session Control opcodes
class Opcode {
  Opcode._();
  static const startSession  = 0x01;
  static const stopSession   = 0x02;
  static const syncTime      = 0x03;
  static const zeroCalibrate = 0x04;
  static const setTarget     = 0x05;
  static const setDuration   = 0x06; // 2B uint16 LE sec — Train 세션 길이
}

// Device states (keep enum ordinal in sync with protocol byte value)
enum DeviceStateCode {
  boot(0), standby(1), prep(2), train(3), rest(4), summary(5), weekly(6), error(7);

  final int value;
  const DeviceStateCode(this.value);
  static DeviceStateCode fromByte(int b) =>
      values.firstWhere((e) => e.value == b, orElse: () => DeviceStateCode.error);
}

/// 다이얼 단계 ↔ 구멍 지름 ↔ 유체역학 보정계수.
///
/// 다이얼은 구멍 크기로 저항을 바꾼다(큰 구멍=약한 저항=낮은 압력, 작은 구멍=강한
/// 저항=높은 압력). 목표 압력을 고정하면 단계마다 모순이 생기므로, 기준 2단(2mm)에서
/// 측정한 PImax/MEP 에 단계별 보정계수를 곱해 목표를 자동 산출한다.
///
/// 계수 근거 — 베르누이 ΔP ∝ 1/A² ∝ 1/d⁴, 호흡 일률(P·Q) 일정 가정 → ΔP ∝ 1/d^(4/3).
/// 기준 2단(2mm) 대비: 1단 3mm=(2/3)^(4/3)≈0.58 · 2단 2mm=1.00 · 3단 1mm=(2/1)^(4/3)≈2.52.
enum OrificeLevel {
  low(0, 1, '3.0mm', 0.58),
  medium(1, 2, '2.0mm', 1.00),
  high(2, 3, '1.0mm', 2.52);

  /// BLE wire 값(0/1/2) — 펌웨어 orifice level 과 1:1.
  final int value;

  /// 사용자 표기 다이얼 단계(1/2/3).
  final int stage;

  /// 구멍 지름 라벨.
  final String label;

  /// 목표 압력 보정계수 (기준 2단 대비).
  final double coefficient;

  const OrificeLevel(this.value, this.stage, this.label, this.coefficient);

  /// 기준 다이얼 단계 — PImax/MEP 를 이 단계에서 측정한다(계수 1.00).
  static const reference = OrificeLevel.medium;

  static OrificeLevel fromValue(int v) =>
      values.firstWhere((e) => e.value == v, orElse: () => OrificeLevel.medium);
}
