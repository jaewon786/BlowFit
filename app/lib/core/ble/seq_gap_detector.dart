/// Tracks sequence numbers from the pressure characteristic and produces
/// dropped-packet statistics. Pure logic — fully unit-testable.
///
/// Sequence numbers are u16 (0..65535) and wrap. A backward jump larger than
/// [resetThreshold] is treated as a device restart and resets the counters
/// rather than counting 60k+ phantom drops.
class SeqGapDetector {
  SeqGapDetector({this.resetThreshold = 1024});

  /// Difference (mod 2^16) above which we assume a device restart instead of a
  /// genuine forward gap. Tunable for test scenarios.
  final int resetThreshold;

  int _last = -1;
  int _totalReceived = 0;
  int _totalDropped = 0;
  int _currentRunGood = 0;
  int _resets = 0;

  int get totalReceived => _totalReceived;
  int get totalDropped => _totalDropped;
  int get currentRunGood => _currentRunGood;
  int get resets => _resets;

  /// Total packets seen including the dropped phantom ones we infer.
  int get totalExpected => _totalReceived + _totalDropped;

  /// 0.0 when no losses, 1.0 when every packet is lost. NaN-safe (returns 0
  /// before any packet is received).
  double get lossRate =>
      totalExpected == 0 ? 0 : _totalDropped / totalExpected;

  /// Snapshot the current state into an immutable record for stream emission.
  BleHealth snapshot() => BleHealth(
        totalReceived: _totalReceived,
        totalDropped: _totalDropped,
        currentRunGood: _currentRunGood,
        resets: _resets,
        lossRate: lossRate,
      );

  /// Process a new sequence number. Returns the number of inferred dropped
  /// packets in the gap (0 when in-order, positive on forward gap).
  int onSeq(int seq) {
    _totalReceived++;
    if (_last < 0) {
      _last = seq;
      _currentRunGood = 1;
      return 0;
    }
    final expected = (_last + 1) & 0xFFFF;
    if (seq == expected) {
      _last = seq;
      _currentRunGood++;
      return 0;
    }
    final delta = (seq - _last) & 0xFFFF;
    if (delta >= resetThreshold) {
      // Backward jump or huge gap → device restart; treat as fresh start.
      _resets++;
      _last = seq;
      _currentRunGood = 1;
      return 0;
    }
    final dropped = delta - 1;
    _totalDropped += dropped;
    _last = seq;
    _currentRunGood = 0;
    return dropped;
  }

  void reset() {
    _last = -1;
    _totalReceived = 0;
    _totalDropped = 0;
    _currentRunGood = 0;
    _resets = 0;
  }
}

/// Snapshot of BLE link health for UI consumers.
class BleHealth {
  final int totalReceived;
  final int totalDropped;
  final int currentRunGood;
  final int resets;
  final double lossRate;

  const BleHealth({
    required this.totalReceived,
    required this.totalDropped,
    required this.currentRunGood,
    required this.resets,
    required this.lossRate,
  });

  static const healthy = BleHealth(
    totalReceived: 0,
    totalDropped: 0,
    currentRunGood: 0,
    resets: 0,
    lossRate: 0.0,
  );

  /// Heuristic: treat link as degraded when more than 5% of expected packets
  /// were dropped over a meaningful sample (>200 packets ≈ 10s at 20 Hz).
  bool get isDegraded => totalReceived > 200 && lossRate > 0.05;
}
