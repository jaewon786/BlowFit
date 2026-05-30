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

  /// [autoConnect] true 면 OS 가 광고 잡힐 때마다 자동 reconnect (본딩된
  /// 디바이스용, background reconnect). false 면 즉시 GATT connect 시도 —
  /// manual button tap 같은 user-initiated 흐름에 적합. 페어링 안 된 환경에선
  /// false 가 더 빠르고 직접적.
  Future<void> connect(DiscoveredDevice device, {bool autoConnect = true});
  Future<void> disconnect();

  /// 현재 연결 상태가 healthy 한지 확인하고, 필요 시 재연결 / characteristic
  /// 재바인딩을 시도. `true` 반환 시 write/read 가 안전한 상태.
  ///
  /// [forceRebind] true 면 cached state 가 connected 여도 service 재발견 +
  /// characteristic 재바인딩 강제 수행. 앱 resume 흐름에서 사용 — Android 의
  /// `isConnected` 는 OS cached state 라서 GATT 가 실제로는 죽어있어도 true 를
  /// 반환할 수 있음. 강제 rediscover 가 throw 하면 hard reconnect 로 fallback.
  Future<bool> ensureConnected({bool forceRebind = false});

  /// flutter_blue_plus 의 process-level singleton 인 `connectedDevices` 에서
  /// BlowFit-* 디바이스를 찾아 main manager 에 흡수. BleForegroundService 의
  /// service isolate 가 BLE 잡고 있는 경우, main app 의 새 scan 은 device
  /// 가 advertising 안 함 (이미 연결됨) → scan 결과 0. 이 함수가 OS-level
  /// 연결을 adopt 해서 새 scan/connect 불필요. `true` 반환 시 read/write
  /// 안전.
  Future<bool> tryAdoptExistingConnection();

  Future<void> startSession(OrificeLevel level);
  Future<void> stopSession();
  Future<void> syncTime();
  Future<void> zeroCalibrate();
  Future<void> setTarget(int lowCmH2O, int highCmH2O);

  /// Train 세션 길이 (초) 를 기기로 전송 (SET_DURATION opcode).
  Future<void> setTrainDuration(int seconds);

  void dispose();
}
