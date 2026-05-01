import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/pressure_sample.dart';
import 'ble_manager.dart';
import 'fake_ble_manager.dart';
import 'real_ble_manager.dart';
import 'seq_gap_detector.dart';

/// Enable with `flutter run --dart-define=FAKE_BLE=true` to use an in-process
/// BLE simulator. Useful for UI/DB/History work on Windows where bless-based
/// peripheral simulation is unreliable, and in CI.
const _useFake = bool.fromEnvironment('FAKE_BLE');

final bleManagerProvider = Provider<BleManager>((ref) {
  final BleManager m = _useFake ? FakeBleManager() : RealBleManager();
  ref.onDispose(m.dispose);
  return m;
});

final pressureSampleProvider = StreamProvider<PressureSample>((ref) {
  return ref.watch(bleManagerProvider).pressureStream;
});

final deviceStateProvider = StreamProvider<DeviceSnapshot>((ref) {
  return ref.watch(bleManagerProvider).deviceStateStream;
});

final sessionSummaryProvider = StreamProvider<SessionSummary>((ref) {
  return ref.watch(bleManagerProvider).sessionSummaryStream;
});

final connectionProvider = StreamProvider<bool>((ref) {
  return ref.watch(bleManagerProvider).connectionStream;
});

/// Per-link packet-loss telemetry. UI consumers can show a degraded-link
/// warning when [BleHealth.isDegraded] is true.
final bleHealthProvider = StreamProvider<BleHealth>((ref) {
  return ref.watch(bleManagerProvider).bleHealthStream;
});
