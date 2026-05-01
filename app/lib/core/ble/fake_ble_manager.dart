import 'dart:async';
import 'dart:math' as math;

import '../models/pressure_sample.dart';
import 'ble_manager.dart';
import 'blowfit_uuids.dart';
import 'discovered_device.dart';
import 'seq_gap_detector.dart';

/// In-process BLE stand-in used when `--dart-define=FAKE_BLE=true`. Simulates
/// the real BlowFit device: one discoverable fake peripheral, realistic
/// breathing waveform, and a SessionSummary emitted on stopSession (or after
/// 30s of an unstopped session).
class FakeBleManager implements BleManager {
  FakeBleManager();

  static const _fakeId = 'fake:blowfit-sim';
  static const _breathCycleSec = 7.4;
  static const _peakCmH2O = 25.0;

  final _pressure = StreamController<PressureSample>.broadcast();
  final _state    = StreamController<DeviceSnapshot>.broadcast();
  final _summary  = StreamController<SessionSummary>.broadcast();
  final _conn     = StreamController<bool>.broadcast();
  final _health   = StreamController<BleHealth>.broadcast();
  final _rng      = math.Random(42);

  Timer? _pressureTimer;
  Timer? _autoStopTimer;
  DateTime? _sessionStartWall;
  double _sessionT = 0;
  int _sessionId = 0;
  OrificeLevel _orifice = OrificeLevel.medium;
  double _sessionMax = 0;
  double _sessionSum = 0;
  int _sessionCount = 0;
  double _enduranceSec = 0;
  int _targetHits = 0;
  double _aboveTargetRun = 0;
  bool _connected = false;

  @override
  Stream<PressureSample> get pressureStream => _pressure.stream;
  @override
  Stream<DeviceSnapshot> get deviceStateStream => _state.stream;
  @override
  Stream<SessionSummary> get sessionSummaryStream => _summary.stream;
  @override
  Stream<bool> get connectionStream => _conn.stream;
  @override
  Stream<BleHealth> get bleHealthStream => _health.stream;

  @override
  Future<List<DiscoveredDevice>> scan({Duration timeout = const Duration(seconds: 6)}) async {
    await Future<void>.delayed(const Duration(milliseconds: 800));
    return const [
      DiscoveredDevice(id: _fakeId, name: 'BlowFit-SIM (fake)', rssi: -42),
    ];
  }

  @override
  Future<void> connect(DiscoveredDevice device) async {
    if (device.id != _fakeId) {
      throw StateError('Unknown fake device: ${device.id}');
    }
    await Future<void>.delayed(const Duration(milliseconds: 300));
    _connected = true;
    _conn.add(true);
    _state.add(const DeviceSnapshot(
      stateCode: 1, // standby
      orificeLevel: 1,
      batteryPct: 85,
      charging: false,
      connected: true,
      lowBattery: false,
    ));
  }

  @override
  Future<void> disconnect() async {
    _pressureTimer?.cancel();
    _autoStopTimer?.cancel();
    _connected = false;
    _conn.add(false);
  }

  @override
  Future<void> startSession(OrificeLevel level) async {
    if (!_connected) throw StateError('not connected');
    _orifice = level;
    _sessionId++;
    _sessionStartWall = DateTime.now();
    _sessionT = 0;
    _sessionMax = 0;
    _sessionSum = 0;
    _sessionCount = 0;
    _enduranceSec = 0;
    _targetHits = 0;
    _aboveTargetRun = 0;

    _state.add(const DeviceSnapshot(
      stateCode: 3, // train
      orificeLevel: 1, batteryPct: 85,
      charging: false, connected: true, lowBattery: false,
    ));

    // 50 Hz emission (matches UI chart budget; avg 100Hz native sample rate is
    // more than needed for the 30s rolling window).
    const dtMs = 20;
    _pressureTimer?.cancel();
    _pressureTimer = Timer.periodic(const Duration(milliseconds: dtMs), (_) {
      _emitSample(dtMs / 1000.0);
    });

    _autoStopTimer?.cancel();
    _autoStopTimer = Timer(const Duration(seconds: 30), () {
      if (_pressureTimer?.isActive ?? false) stopSession();
    });
  }

  @override
  Future<void> stopSession() async {
    _pressureTimer?.cancel();
    _autoStopTimer?.cancel();

    final started = _sessionStartWall ?? DateTime.now();
    final duration = DateTime.now().difference(started);
    final avg = _sessionCount == 0 ? 0.0 : _sessionSum / _sessionCount;

    _state.add(const DeviceSnapshot(
      stateCode: 5, // summary
      orificeLevel: 1, batteryPct: 85,
      charging: false, connected: true, lowBattery: false,
    ));

    _summary.add(SessionSummary(
      sessionId: _sessionId,
      startedAt: started,
      duration: duration,
      maxPressure: _sessionMax,
      avgPressure: avg,
      endurance: Duration(seconds: _enduranceSec.round()),
      orificeLevel: _orifice.value,
      targetHits: _targetHits,
      sampleCount: _sessionCount,
      crc32: 0,
    ));
  }

  @override
  Future<void> syncTime() async {}
  @override
  Future<void> zeroCalibrate() async {}
  @override
  Future<void> setTarget(int lowCmH2O, int highCmH2O) async {}

  void _emitSample(double dt) {
    _sessionT += dt;
    final p = _waveform(_sessionT) + _rng.nextDouble() * 0.8 - 0.4;
    final clamped = p < 0 ? 0.0 : p;
    _pressure.add(PressureSample(timestamp: DateTime.now(), cmH2O: clamped));

    _sessionSum += clamped;
    _sessionCount++;
    if (clamped > _sessionMax) _sessionMax = clamped;

    const lo = 20.0, hi = 30.0;
    if (clamped >= lo && clamped <= hi) {
      _enduranceSec += dt;
      _aboveTargetRun += dt;
      if (_aboveTargetRun >= 15.0) {
        _targetHits++;
        _aboveTargetRun = 0;
      }
    } else {
      _aboveTargetRun = 0;
    }
  }

  /// One breathing cycle:
  ///   0.0–2.0s  inhale (≈0)
  ///   2.0–2.6s  ramp up
  ///   2.6–6.1s  hold near peak
  ///   6.1–6.6s  ramp down
  ///   6.6–7.4s  pause
  double _waveform(double t) {
    final tc = t % _breathCycleSec;
    if (tc < 2.0) return 0;
    if (tc < 2.6) {
      final x = (tc - 2.0) / 0.6;
      return _peakCmH2O * (3 * x * x - 2 * x * x * x);
    }
    if (tc < 6.1) return _peakCmH2O;
    if (tc < 6.6) {
      final x = (tc - 6.1) / 0.5;
      return _peakCmH2O * (1 - (3 * x * x - 2 * x * x * x));
    }
    return 0;
  }

  @override
  void dispose() {
    _pressureTimer?.cancel();
    _autoStopTimer?.cancel();
    _pressure.close();
    _state.close();
    _summary.close();
    _conn.close();
    _health.close();
  }
}
