import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/pressure_sample.dart';
import 'ble_manager.dart';

final bleManagerProvider = Provider<BleManager>((ref) {
  final m = BleManager();
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
