import 'package:blowfit/core/ble/seq_gap_detector.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SeqGapDetector', () {
    test('first packet is always in-order', () {
      final d = SeqGapDetector();
      expect(d.onSeq(42), 0);
      expect(d.totalReceived, 1);
      expect(d.totalDropped, 0);
      expect(d.currentRunGood, 1);
    });

    test('consecutive sequence numbers report no drops', () {
      final d = SeqGapDetector();
      for (var i = 0; i < 100; i++) {
        expect(d.onSeq(i), 0);
      }
      expect(d.totalDropped, 0);
      expect(d.lossRate, 0.0);
      expect(d.currentRunGood, 100);
    });

    test('forward gap reports the missing count', () {
      final d = SeqGapDetector();
      d.onSeq(10);
      expect(d.onSeq(15), 4); // 11, 12, 13, 14 dropped
      expect(d.totalDropped, 4);
      expect(d.totalReceived, 2);
      expect(d.currentRunGood, 0);
      expect(d.lossRate, closeTo(4 / 6, 0.001));
    });

    test('wrap-around at u16 boundary is in-order', () {
      final d = SeqGapDetector();
      d.onSeq(65535);
      expect(d.onSeq(0), 0);
      expect(d.totalDropped, 0);
      expect(d.currentRunGood, 2);
    });

    test('forward gap across wrap-around', () {
      final d = SeqGapDetector();
      d.onSeq(65534);
      expect(d.onSeq(2), 3); // 65535, 0, 1 dropped
      expect(d.totalDropped, 3);
    });

    test('backward jump is treated as device reset', () {
      final d = SeqGapDetector(resetThreshold: 1024);
      d.onSeq(50000);
      d.onSeq(50001);
      expect(d.onSeq(5), 0);
      expect(d.resets, 1);
      expect(d.totalDropped, 0);
      expect(d.currentRunGood, 1);
    });

    test('huge forward jump beyond threshold triggers reset', () {
      final d = SeqGapDetector(resetThreshold: 1024);
      d.onSeq(10);
      // delta = 5000, >= threshold
      expect(d.onSeq(5010), 0);
      expect(d.resets, 1);
      expect(d.totalDropped, 0);
    });

    test('runs reset to zero after a gap, then accumulate', () {
      final d = SeqGapDetector();
      d.onSeq(0);
      d.onSeq(1);
      d.onSeq(2);
      expect(d.currentRunGood, 3);
      d.onSeq(5); // gap
      expect(d.currentRunGood, 0);
      d.onSeq(6);
      d.onSeq(7);
      expect(d.currentRunGood, 2);
    });

    test('lossRate before any packet is zero, not NaN', () {
      final d = SeqGapDetector();
      expect(d.lossRate, 0.0);
    });

    test('snapshot is consistent with internal state', () {
      final d = SeqGapDetector();
      d.onSeq(0);
      d.onSeq(5); // 4 dropped
      final s = d.snapshot();
      expect(s.totalReceived, 2);
      expect(s.totalDropped, 4);
      expect(s.currentRunGood, 0);
      expect(s.resets, 0);
      expect(s.lossRate, closeTo(4 / 6, 0.001));
    });

    test('reset clears all state', () {
      final d = SeqGapDetector();
      d.onSeq(0);
      d.onSeq(10);
      d.reset();
      expect(d.totalReceived, 0);
      expect(d.totalDropped, 0);
      expect(d.currentRunGood, 0);
      expect(d.resets, 0);
      expect(d.onSeq(100), 0); // first packet again
    });
  });

  group('BleHealth', () {
    test('healthy sentinel has zero losses', () {
      expect(BleHealth.healthy.totalReceived, 0);
      expect(BleHealth.healthy.lossRate, 0.0);
      expect(BleHealth.healthy.isDegraded, isFalse);
    });

    test('isDegraded requires both sample size and loss threshold', () {
      // Below sample threshold → not degraded even with 100% loss.
      const small = BleHealth(
        totalReceived: 10, totalDropped: 100,
        currentRunGood: 0, resets: 0, lossRate: 0.9,
      );
      expect(small.isDegraded, isFalse);

      // Sufficient sample, low loss → not degraded.
      const goodLong = BleHealth(
        totalReceived: 1000, totalDropped: 10,
        currentRunGood: 50, resets: 0, lossRate: 0.01,
      );
      expect(goodLong.isDegraded, isFalse);

      // Sufficient sample, high loss → degraded.
      const bad = BleHealth(
        totalReceived: 1000, totalDropped: 100,
        currentRunGood: 0, resets: 0, lossRate: 0.09,
      );
      expect(bad.isDegraded, isTrue);
    });
  });
}
