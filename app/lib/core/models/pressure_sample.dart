import 'package:flutter/foundation.dart';

@immutable
class PressureSample {
  final DateTime timestamp;
  final double cmH2O;

  const PressureSample({required this.timestamp, required this.cmH2O});
}

@immutable
class DeviceSnapshot {
  final int stateCode;
  final int orificeLevel;
  final int batteryPct;
  final bool charging;
  final bool connected;
  final bool lowBattery;

  const DeviceSnapshot({
    required this.stateCode,
    required this.orificeLevel,
    required this.batteryPct,
    required this.charging,
    required this.connected,
    required this.lowBattery,
  });

  factory DeviceSnapshot.fromBytes(List<int> b) {
    if (b.length < 4) {
      return const DeviceSnapshot(
        stateCode: 0, orificeLevel: 0, batteryPct: 0,
        charging: false, connected: false, lowBattery: false,
      );
    }
    final flags = b[3];
    return DeviceSnapshot(
      stateCode: b[0],
      orificeLevel: b[1],
      batteryPct: b[2],
      charging:    (flags & 0x01) != 0,
      connected:   (flags & 0x02) != 0,
      lowBattery:  (flags & 0x04) != 0,
    );
  }
}

@immutable
class SessionSummary {
  final int sessionId;
  final DateTime? startedAt;
  final Duration duration;
  final double maxPressure;
  final double avgPressure;
  final Duration endurance;
  final int orificeLevel;
  final int targetHits;
  final int sampleCount;
  final int crc32;

  const SessionSummary({
    required this.sessionId,
    required this.startedAt,
    required this.duration,
    required this.maxPressure,
    required this.avgPressure,
    required this.endurance,
    required this.orificeLevel,
    required this.targetHits,
    required this.sampleCount,
    required this.crc32,
  });
}
