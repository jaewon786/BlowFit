import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import '../models/pressure_sample.dart';
import 'ble_manager.dart';
import 'blowfit_codec.dart';
import 'blowfit_uuids.dart';
import 'discovered_device.dart';
import 'seq_gap_detector.dart';

/// flutter_blue_plus-backed BLE client for the real BlowFit device and
/// tools/ble-sim.py simulator.
class RealBleManager implements BleManager {
  RealBleManager();

  final _pressureController = StreamController<PressureSample>.broadcast();
  final _stateController    = StreamController<DeviceSnapshot>.broadcast();
  final _summaryController  = StreamController<SessionSummary>.broadcast();
  final _connectionController = StreamController<bool>.broadcast();
  final _healthController   = StreamController<BleHealth>.broadcast();
  final _gapDetector        = SeqGapDetector();

  @override
  Stream<PressureSample> get pressureStream => _pressureController.stream;
  @override
  Stream<DeviceSnapshot> get deviceStateStream => _stateController.stream;
  @override
  Stream<SessionSummary> get sessionSummaryStream => _summaryController.stream;
  @override
  Stream<bool> get connectionStream => _connectionController.stream;
  @override
  Stream<BleHealth> get bleHealthStream => _healthController.stream;

  final Map<String, BluetoothDevice> _devices = {};
  BluetoothDevice? _device;
  BluetoothCharacteristic? _control;
  StreamSubscription<List<ScanResult>>? _scanSub;
  StreamSubscription<BluetoothConnectionState>? _connSub;

  @override
  Future<List<DiscoveredDevice>> scan({Duration timeout = const Duration(seconds: 6)}) async {
    // withServices 필터 제거 — mbed BSP 의 ArduinoBLE 가 광고 패킷에 128-bit
    // 서비스 UUID 를 포함시키지 않아서 필터를 걸면 우리 디바이스도 걸러짐.
    // 이름 prefix 로만 필터링하면 충분.
    await FlutterBluePlus.startScan(
      timeout: timeout,
    );
    final results = <DiscoveredDevice>[];
    final sub = FlutterBluePlus.scanResults.listen((r) {
      for (final s in r) {
        final name = s.device.platformName;
        final id = s.device.remoteId.str;
        if (name.startsWith(BlowfitUuids.deviceNamePrefix)
            && !results.any((e) => e.id == id)) {
          _devices[id] = s.device;
          results.add(DiscoveredDevice(id: id, name: name, rssi: s.rssi));
        }
      }
    });
    await Future<void>.delayed(timeout);
    await sub.cancel();
    await FlutterBluePlus.stopScan();
    return results;
  }

  @override
  Future<void> connect(DiscoveredDevice device) async {
    final fbp = _devices[device.id];
    if (fbp == null) {
      throw StateError('Device ${device.id} not found — rescan first');
    }
    _device = fbp;
    _connSub?.cancel();
    _connSub = fbp.connectionState.listen((s) {
      final isConnected = s == BluetoothConnectionState.connected;
      _connectionController.add(isConnected);
      if (!isConnected) {
        // Reset packet-loss telemetry so the next session starts with a clean
        // history; otherwise stale gaps from a prior link can mark the next
        // session as "degraded" before any real loss has happened.
        _gapDetector.reset();
        _healthController.add(_gapDetector.snapshot());
      }
    });

    await fbp.connect(autoConnect: false, mtu: 185);
    final services = await fbp.discoverServices();
    final svc = services.firstWhere(
      (s) => s.uuid == BlowfitUuids.service,
      orElse: () => throw StateError('BlowFit service not found'),
    );

    for (final c in svc.characteristics) {
      if (c.uuid == BlowfitUuids.pressureStream) {
        await c.setNotifyValue(true);
        c.lastValueStream.listen(_decodePressure);
      } else if (c.uuid == BlowfitUuids.deviceState) {
        await c.setNotifyValue(true);
        c.lastValueStream.listen(_decodeState);
      } else if (c.uuid == BlowfitUuids.sessionSummary) {
        await c.setNotifyValue(true);
        c.lastValueStream.listen(_decodeSummary);
      } else if (c.uuid == BlowfitUuids.sessionControl) {
        _control = c;
      }
    }

    await syncTime();
  }

  @override
  Future<void> disconnect() async {
    await _device?.disconnect();
    _device = null;
  }

  @override
  Future<void> startSession(OrificeLevel level) async {
    await _control?.write(
      [Opcode.startSession, level.value],
      withoutResponse: false,
    );
  }

  @override
  Future<void> stopSession() async {
    await _control?.write([Opcode.stopSession], withoutResponse: false);
  }

  @override
  Future<void> syncTime() async {
    final epoch = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final bytes = ByteData(5)
      ..setUint8(0, Opcode.syncTime)
      ..setUint32(1, epoch, Endian.little);
    await _control?.write(
      bytes.buffer.asUint8List(),
      withoutResponse: false,
    );
  }

  @override
  Future<void> zeroCalibrate() async {
    await _control?.write([Opcode.zeroCalibrate], withoutResponse: false);
  }

  @override
  Future<void> setTarget(int lowCmH2O, int highCmH2O) async {
    await _control?.write(
      [Opcode.setTarget, lowCmH2O, highCmH2O],
      withoutResponse: false,
    );
  }

  void _decodePressure(List<int> bytes) {
    final block = BlowfitCodec.decodePressureBlock(bytes, DateTime.now());
    if (block == null) return;
    final dropped = _gapDetector.onSeq(block.seq);
    if (dropped > 0 && kDebugMode) {
      // ignore: avoid_print
      print('BLE seq gap: dropped=$dropped seq=${block.seq}');
    }
    _healthController.add(_gapDetector.snapshot());
    for (final s in block.samples) {
      _pressureController.add(s);
    }
  }

  void _decodeState(List<int> bytes) {
    _stateController.add(DeviceSnapshot.fromBytes(bytes));
  }

  void _decodeSummary(List<int> bytes) {
    final s = BlowfitCodec.decodeSummary(bytes);
    if (s != null) _summaryController.add(s);
  }

  @override
  void dispose() {
    _scanSub?.cancel();
    _connSub?.cancel();
    _pressureController.close();
    _stateController.close();
    _summaryController.close();
    _connectionController.close();
    _healthController.close();
  }
}
