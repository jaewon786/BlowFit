import 'dart:typed_data';

import '../models/pressure_sample.dart';

/// Pure decoders for the BlowFit BLE wire format.
///
/// The pressure characteristic emits a 22-byte packet (10 samples at 100 Hz)
/// and the summary characteristic emits a 32-byte packet. See docs/ble-protocol.md
/// for layout details. Kept free of streams/state so they can be unit tested.
class BlowfitCodec {
  BlowfitCodec._();

  static const int pressurePacketBytes = 22;
  static const int summaryPacketBytes = 32;
  static const int samplesPerPacket = 10;
  static const int sampleIntervalMs = 10; // 100 Hz

  /// Decodes a 22-byte pressure packet. Returns null on short input.
  ///
  /// Layout: u16 seq (LE) + 10×i16 raw pressure ×10 cmH2O (LE).
  /// The `baseTime` corresponds to the first sample; subsequent samples are
  /// spaced [sampleIntervalMs] ms apart.
  ///
  /// 펌웨어가 50ms 마다 notify 하는데 100Hz 샘플링이라 매 패킷 5 real + 5 zero-pad
  /// 가 들어옴. 마지막 sample 이 0 이면 _current 가 0 으로 덮어씌워져 endurance
  /// 카운트가 망가지므로 trailing zero 를 잘라냄. (idle 시 모두 0 이어도 최소 1
  /// 샘플은 emit 해서 stream 자체가 끊기지는 않게 함.)
  static PressureBlock? decodePressureBlock(List<int> bytes, DateTime baseTime) {
    if (bytes.length < pressurePacketBytes) return null;
    final bd = ByteData.sublistView(Uint8List.fromList(bytes));
    final seq = bd.getUint16(0, Endian.little);
    final raws = <int>[];
    for (var i = 0; i < samplesPerPacket; i++) {
      raws.add(bd.getInt16(2 + i * 2, Endian.little));
    }
    int lastReal = raws.length - 1;
    while (lastReal > 0 && raws[lastReal] == 0) {
      lastReal--;
    }
    final samples = <PressureSample>[];
    for (var i = 0; i <= lastReal; i++) {
      samples.add(PressureSample(
        timestamp: baseTime.add(Duration(milliseconds: i * sampleIntervalMs)),
        cmH2O: raws[i] / 10.0,
      ));
    }
    return PressureBlock(seq: seq, samples: samples);
  }

  /// Decodes a 32-byte session summary packet. Returns null on short input.
  ///
  /// Layout (LE):
  ///   0..3   u32 startEpochSec (0 = unknown)
  ///   4..7   u32 durationSec
  ///   8..11  f32 maxPressure (cmH2O)
  ///   12..15 f32 avgPressure (cmH2O)
  ///   16..19 u32 enduranceSec
  ///   20     u8  orificeLevel
  ///   21     u8  targetHits
  ///   22..23 u16 sampleCount
  ///   24..27 u32 crc32
  ///   28..31 u32 sessionId
  static SessionSummary? decodeSummary(List<int> bytes) {
    if (bytes.length < summaryPacketBytes) return null;
    final bd = ByteData.sublistView(Uint8List.fromList(bytes));
    final startEpoch = bd.getUint32(0, Endian.little);
    return SessionSummary(
      sessionId: bd.getUint32(28, Endian.little),
      startedAt: startEpoch == 0
          ? null
          : DateTime.fromMillisecondsSinceEpoch(startEpoch * 1000),
      duration: Duration(seconds: bd.getUint32(4, Endian.little)),
      maxPressure: bd.getFloat32(8, Endian.little),
      avgPressure: bd.getFloat32(12, Endian.little),
      endurance: Duration(seconds: bd.getUint32(16, Endian.little)),
      orificeLevel: bd.getUint8(20),
      targetHits: bd.getUint8(21),
      sampleCount: bd.getUint16(22, Endian.little),
      crc32: bd.getUint32(24, Endian.little),
    );
  }
}

class PressureBlock {
  final int seq;
  final List<PressureSample> samples;
  const PressureBlock({required this.seq, required this.samples});
}
