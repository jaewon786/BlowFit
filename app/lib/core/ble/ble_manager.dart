import '../models/pressure_sample.dart';
import 'blowfit_uuids.dart';
import 'discovered_device.dart';
import 'seq_gap_detector.dart';

/// Abstract BLE client for the BlowFit device. UI/providers depend on this
/// interface; concrete implementations (RealBleManager over flutter_blue_plus,
/// FakeBleManager for offline dev/CI) implement it.
abstract class BleManager {
  Stream<PressureSample> get pressureStream;
  Stream<DeviceSnapshot> get deviceStateStream;
  Stream<SessionSummary> get sessionSummaryStream;
  Stream<bool> get connectionStream;
  Stream<BleHealth> get bleHealthStream;

  Future<List<DiscoveredDevice>> scan({Duration timeout = const Duration(seconds: 6)});
  Future<void> connect(DiscoveredDevice device);
  Future<void> disconnect();

  Future<void> startSession(OrificeLevel level);
  Future<void> stopSession();
  Future<void> syncTime();
  Future<void> zeroCalibrate();
  Future<void> setTarget(int lowCmH2O, int highCmH2O);

  void dispose();
}
