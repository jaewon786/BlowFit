import 'dart:typed_data';

import 'package:blowfit/core/ble/blowfit_codec.dart';
import 'package:blowfit/core/models/pressure_sample.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('decodePressureBlock', () {
    test('returns null on short input', () {
      expect(BlowfitCodec.decodePressureBlock(const [1, 2, 3], DateTime.now()), isNull);
      expect(
        BlowfitCodec.decodePressureBlock(List.filled(21, 0), DateTime.now()),
        isNull,
      );
    });

    test('parses seq and 10 samples with 10ms spacing', () {
      // seq = 0x1234, samples = 100, 200, 300, ... 1000 (raw / 10 = cmH2O)
      final bd = ByteData(22);
      bd.setUint16(0, 0x1234, Endian.little);
      for (var i = 0; i < 10; i++) {
        bd.setInt16(2 + i * 2, (i + 1) * 100, Endian.little);
      }
      final base = DateTime.utc(2026, 1, 1, 0, 0, 0);
      final block = BlowfitCodec.decodePressureBlock(bd.buffer.asUint8List(), base)!;

      expect(block.seq, 0x1234);
      expect(block.samples, hasLength(10));
      expect(block.samples[0].cmH2O, 10.0);
      expect(block.samples[0].timestamp, base);
      expect(block.samples[9].cmH2O, 100.0);
      expect(
        block.samples[9].timestamp,
        base.add(const Duration(milliseconds: 90)),
      );
    });

    test('handles negative pressure (sensor drift below zero)', () {
      final bd = ByteData(22);
      bd.setUint16(0, 0, Endian.little);
      bd.setInt16(2, -50, Endian.little);  // -5.0 cmH2O
      for (var i = 1; i < 10; i++) {
        bd.setInt16(2 + i * 2, 0, Endian.little);
      }
      final block = BlowfitCodec.decodePressureBlock(
        bd.buffer.asUint8List(), DateTime.utc(2026),
      )!;
      expect(block.samples.first.cmH2O, -5.0);
    });

    test('seq wraps at u16 boundary', () {
      final bd = ByteData(22);
      bd.setUint16(0, 0xFFFF, Endian.little);
      final block = BlowfitCodec.decodePressureBlock(
        bd.buffer.asUint8List(), DateTime.utc(2026),
      )!;
      expect(block.seq, 0xFFFF);
    });
  });

  group('decodeSummary', () {
    test('returns null on short input', () {
      expect(BlowfitCodec.decodeSummary(const [1, 2, 3]), isNull);
      expect(BlowfitCodec.decodeSummary(List.filled(31, 0)), isNull);
    });

    test('parses all 32-byte fields', () {
      final bd = ByteData(32);
      const epoch = 1735689600;          // 2025-01-01T00:00:00Z
      bd.setUint32(0, epoch, Endian.little);
      bd.setUint32(4, 240, Endian.little);     // duration 240s
      bd.setFloat32(8, 28.5, Endian.little);   // maxPressure
      bd.setFloat32(12, 22.3, Endian.little);  // avgPressure
      bd.setUint32(16, 180, Endian.little);    // endurance 180s
      bd.setUint8(20, 1);                      // orificeLevel
      bd.setUint8(21, 4);                      // targetHits
      bd.setUint16(22, 24000, Endian.little);  // sampleCount
      bd.setUint32(24, 0xCAFEBABE, Endian.little); // crc32
      bd.setUint32(28, 42, Endian.little);     // sessionId

      final s = BlowfitCodec.decodeSummary(bd.buffer.asUint8List())!;
      expect(s.sessionId, 42);
      expect(s.startedAt, DateTime.fromMillisecondsSinceEpoch(epoch * 1000));
      expect(s.duration, const Duration(seconds: 240));
      expect(s.maxPressure, closeTo(28.5, 0.001));
      expect(s.avgPressure, closeTo(22.3, 0.001));
      expect(s.endurance, const Duration(seconds: 180));
      expect(s.orificeLevel, 1);
      expect(s.targetHits, 4);
      expect(s.sampleCount, 24000);
      expect(s.crc32, 0xCAFEBABE);
    });

    test('startedAt is null when epoch is zero (RTC unset)', () {
      final bd = ByteData(32);  // all zeros
      final s = BlowfitCodec.decodeSummary(bd.buffer.asUint8List())!;
      expect(s.startedAt, isNull);
      expect(s.duration, Duration.zero);
      expect(s.sessionId, 0);
    });
  });

  group('DeviceSnapshot.fromBytes', () {
    test('returns sentinel for short input', () {
      final s = DeviceSnapshot.fromBytes(const [1, 2]);
      expect(s.stateCode, 0);
      expect(s.connected, false);
    });

    test('decodes flag bits independently', () {
      // state=3 (Train), orifice=2, battery=80%, flags = charging|connected|lowBat
      const flags = 0x01 | 0x02 | 0x04;
      final s = DeviceSnapshot.fromBytes([3, 2, 80, flags]);
      expect(s.stateCode, 3);
      expect(s.orificeLevel, 2);
      expect(s.batteryPct, 80);
      expect(s.charging, true);
      expect(s.connected, true);
      expect(s.lowBattery, true);
    });

    test('charging-only flag', () {
      final s = DeviceSnapshot.fromBytes([1, 1, 95, 0x01]);
      expect(s.charging, true);
      expect(s.connected, false);
      expect(s.lowBattery, false);
    });
  });
}
