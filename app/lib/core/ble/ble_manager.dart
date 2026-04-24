import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import 'blowfit_uuids.dart';
import '../models/pressure_sample.dart';

/// Central BLE client for the BlowFit device. Presents streams of pressure
/// samples, device state, and session summaries without exposing raw
/// flutter_blue_plus types to the UI layer.
class BleManager {
  BleManager();

  final _pressureController = StreamController<PressureSample>.broadcast();
  final _stateController    = StreamController<DeviceSnapshot>.broadcast();
  final _summaryController  = StreamController<SessionSummary>.broadcast();
  final _connectionController = StreamController<bool>.broadcast();

  Stream<PressureSample> get pressureStream => _pressureController.stream;
  Stream<DeviceSnapshot> get deviceStateStream => _stateController.stream;
  Stream<SessionSummary> get sessionSummaryStream => _summaryController.stream;
  Stream<bool> get connectionStream => _connectionController.stream;

  BluetoothDevice? _device;
  BluetoothCharacteristic? _control;
  StreamSubscription<List<ScanResult>>? _scanSub;
  StreamSubscription<BluetoothConnectionState>? _connSub;
  int _lastSeq = -1;

  Future<List<ScanResult>> scan({Duration timeout = const Duration(seconds: 6)}) async {
    await FlutterBluePlus.startScan(
      withServices: [BlowfitUuids.service],
      timeout: timeout,
    );
    final results = <ScanResult>[];
    final sub = FlutterBluePlus.scanResults.listen((r) {
      for (final s in r) {
        final name = s.device.platformName;
        if (name.startsWith(BlowfitUuids.deviceNamePrefix)
            && !results.any((e) => e.device.remoteId == s.device.remoteId)) {
          results.add(s);
        }
      }
    });
    await Future<void>.delayed(timeout);
    await sub.cancel();
    await FlutterBluePlus.stopScan();
    return results;
  }

  Future<void> connect(BluetoothDevice device) async {
    _device = device;
    _connSub?.cancel();
    _connSub = device.connectionState.listen((s) {
      _connectionController.add(s == BluetoothConnectionState.connected);
    });

    await device.connect(autoConnect: false, mtu: 185);
    final services = await device.discoverServices();
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

  Future<void> disconnect() async {
    await _device?.disconnect();
    _device = null;
  }

  Future<void> startSession(OrificeLevel level) async {
    await _control?.write(
      [Opcode.startSession, level.value],
      withoutResponse: false,
    );
  }

  Future<void> stopSession() async {
    await _control?.write([Opcode.stopSession], withoutResponse: false);
  }

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

  Future<void> zeroCalibrate() async {
    await _control?.write([Opcode.zeroCalibrate], withoutResponse: false);
  }

  Future<void> setTarget(int lowCmH2O, int highCmH2O) async {
    await _control?.write(
      [Opcode.setTarget, lowCmH2O, highCmH2O],
      withoutResponse: false,
    );
  }

  // ---------------- decoders ----------------

  void _decodePressure(List<int> bytes) {
    if (bytes.length < 22) return;
    final bd = ByteData.sublistView(Uint8List.fromList(bytes));
    final seq = bd.getUint16(0, Endian.little);
    if (_lastSeq >= 0) {
      final expected = (_lastSeq + 1) & 0xFFFF;
      if (seq != expected && kDebugMode) {
        // ignore: avoid_print
        print('BLE seq gap: expected=$expected got=$seq');
      }
    }
    _lastSeq = seq;

    final now = DateTime.now();
    for (var i = 0; i < 10; i++) {
      final raw = bd.getInt16(2 + i * 2, Endian.little);
      _pressureController.add(PressureSample(
        timestamp: now.add(Duration(milliseconds: i * 10)),
        cmH2O: raw / 10.0,
      ));
    }
  }

  void _decodeState(List<int> bytes) {
    _stateController.add(DeviceSnapshot.fromBytes(bytes));
  }

  void _decodeSummary(List<int> bytes) {
    if (bytes.length < 32) return;
    final bd = ByteData.sublistView(Uint8List.fromList(bytes));
    final startEpoch = bd.getUint32(0, Endian.little);
    _summaryController.add(SessionSummary(
      sessionId:   bd.getUint32(28, Endian.little),
      startedAt:   startEpoch == 0 ? null
                     : DateTime.fromMillisecondsSinceEpoch(startEpoch * 1000),
      duration:    Duration(seconds: bd.getUint32(4, Endian.little)),
      maxPressure: bd.getFloat32(8, Endian.little),
      avgPressure: bd.getFloat32(12, Endian.little),
      endurance:   Duration(seconds: bd.getUint32(16, Endian.little)),
      orificeLevel: bd.getUint8(20),
      targetHits:   bd.getUint8(21),
      sampleCount:  bd.getUint16(22, Endian.little),
      crc32:        bd.getUint32(24, Endian.little),
    ));
  }

  void dispose() {
    _scanSub?.cancel();
    _connSub?.cancel();
    _pressureController.close();
    _stateController.close();
    _summaryController.close();
    _connectionController.close();
  }
}
