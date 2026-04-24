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

  static const deviceNamePrefix = 'BlowFit';
}

// Session Control opcodes
class Opcode {
  Opcode._();
  static const startSession  = 0x01;
  static const stopSession   = 0x02;
  static const syncTime      = 0x03;
  static const zeroCalibrate = 0x04;
  static const setTarget     = 0x05;
}

// Device states (keep enum ordinal in sync with protocol byte value)
enum DeviceStateCode {
  boot(0), standby(1), prep(2), train(3), rest(4), summary(5), weekly(6), error(7);

  final int value;
  const DeviceStateCode(this.value);
  static DeviceStateCode fromByte(int b) =>
      values.firstWhere((e) => e.value == b, orElse: () => DeviceStateCode.error);
}

enum OrificeLevel {
  low(0, '4.0mm'),
  medium(1, '3.0mm'),
  high(2, '2.0mm');

  final int value;
  final String label;
  const OrificeLevel(this.value, this.label);
}
