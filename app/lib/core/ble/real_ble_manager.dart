import 'dart:async';
import 'dart:io' show Platform;

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
  // 중복 service-discovery 방지 (재연결 이벤트가 짧게 여러 번 fire 될 때).
  bool _binding = false;
  // ensureConnected 동시 호출 방지.
  Future<bool>? _ensureInFlight;

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
  Future<void> connect(DiscoveredDevice device, {bool autoConnect = true}) async {
    final fbp = _devices[device.id];
    if (fbp == null) {
      throw StateError('Device ${device.id} not found — rescan first');
    }
    _device = fbp;
    _setupConnectionListener(fbp);

    // autoConnect: true — OS 가 디바이스 광고 발견 시 자동 reconnect.
    // 펌웨어 측 BLE 본딩 (BLESecurity) 과 조합되면 OS 가 페어된 디바이스로
    // 인식하고 자동 재연결 흐름 활성.
    //
    // mtu: null 명시 — flutter_blue_plus 1.30+ 의 default mtu 가 non-null
    // (보통 512) 이라 mtu 인자 생략하면 default 가 적용됨. 그러면 라이브러리
    // 의 assertion `(mtu == null) || !autoConnect` 가 위반됨. null 명시로
    // assertion 통과 → connect 후 별도로 requestMtu(185) 협상.
    //
    // autoConnect=true 일 땐 connect() 가 즉시 return — 실제 연결은 OS 가
    // 백그라운드에서 진행. 따라서 discoverServices() 호출 전 connectionState
    // 가 connected 될 때까지 명시적 대기 필요.
    debugPrint('[ble] calling connect(autoConnect: $autoConnect, mtu: null)');
    await fbp.connect(autoConnect: autoConnect, mtu: null);

    // 실제 연결 완료까지 대기 (timeout 30s).
    debugPrint('[ble] waiting for connection to establish...');
    await fbp.connectionState
        .firstWhere((s) => s == BluetoothConnectionState.connected)
        .timeout(const Duration(seconds: 30), onTimeout: () {
      throw TimeoutException(
          'BLE connection timeout — device may be out of range or off');
    });
    debugPrint('[ble] connection established');

    await _negotiateMtu(fbp);
    await _discoverAndBind(fbp);

    await syncTime();
  }

  /// Connection state listener — disconnect 시 _control 정리, 재연결 시
  /// service 재발견. connect() / tryAdoptExistingConnection() 양쪽에서 공유.
  void _setupConnectionListener(BluetoothDevice fbp) {
    _connSub?.cancel();
    _connSub = fbp.connectionState.listen((s) async {
      final isConnected = s == BluetoothConnectionState.connected;
      _connectionController.add(isConnected);
      if (!isConnected) {
        debugPrint('[ble] disconnected — clearing _control');
        _control = null;
        _gapDetector.reset();
        _healthController.add(_gapDetector.snapshot());
      } else {
        if (_control == null) {
          debugPrint('[ble] (re)connected — rediscovering services');
          try {
            await _negotiateMtu(fbp);
            await _discoverAndBind(fbp);
          } catch (e) {
            debugPrint('[ble] auto rediscover failed: $e');
          }
        }
      }
    });
  }

  @override
  Future<bool> tryAdoptExistingConnection() async {
    // flutter_blue_plus 는 process-level singleton — connectedDevices 는
    // 같은 process 안의 모든 isolate (main + BleForegroundService 의 service
    // isolate 포함) 의 GATT connection 을 노출. Service 가 BLE 잡고 있을 때
    // main app 측에서 scan 해도 device 가 advertising 안 함 (이미 연결됨)
    // → "디바이스를 못 찾았습니다" 의 원인. 이 함수는 그 OS-level connection
    // 을 main manager 에 흡수해서 새 scan/connect 불필요하게 만듦.
    try {
      final connected = FlutterBluePlus.connectedDevices;
      debugPrint(
          '[ble] adopt: OS-level connected devices = ${connected.length}');
      for (final d in connected) {
        final name = d.platformName;
        debugPrint('[ble] adopt: candidate ${d.remoteId.str} "$name"');
        if (name.startsWith(BlowfitUuids.deviceNamePrefix)) {
          debugPrint('[ble] adopt: matched, adopting');
          _device = d;
          _devices[d.remoteId.str] = d;
          _setupConnectionListener(d);
          try {
            await _negotiateMtu(d);
            await _discoverAndBind(d);
          } catch (e) {
            debugPrint('[ble] adopt: rediscover failed: $e');
            return false;
          }
          _connectionController.add(_control != null);
          return _control != null;
        }
      }
      return false;
    } catch (e) {
      debugPrint('[ble] adopt: threw $e');
      return false;
    }
  }

  /// Android 만 — iOS 는 자동. 실패해도 default 로 fallback.
  Future<void> _negotiateMtu(BluetoothDevice fbp) async {
    if (!kIsWeb && Platform.isAndroid) {
      try {
        await fbp.requestMtu(185);
        debugPrint('[ble] MTU set to 185');
      } catch (e) {
        debugPrint('[ble] requestMtu(185) failed: $e (fallback to default)');
      }
    }
  }

  /// Service discovery + characteristic 바인딩. connect 직후 + 재연결마다
  /// 호출. `_binding` flag 로 중복 실행 방지.
  Future<void> _discoverAndBind(BluetoothDevice fbp) async {
    if (_binding) {
      debugPrint('[ble] _discoverAndBind: already in progress, skip');
      return;
    }
    _binding = true;
    try {
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
      debugPrint('[ble] characteristics bound — control=${_control?.uuid}');
    } finally {
      _binding = false;
    }
  }

  @override
  Future<bool> ensureConnected({bool forceRebind = false}) {
    // 동시 호출 합치기 — 여러 lifecycle event 가 짧게 fire 되어도 한 번만
    // 실제 reconnect 시도. 진행 중인 Future 가 있으면 그걸 await.
    final existing = _ensureInFlight;
    if (existing != null) return existing;
    final fut = _ensureConnectedInner(forceRebind: forceRebind);
    _ensureInFlight = fut;
    // 완료 후 슬롯 해제 (성공/실패 무관).
    fut.whenComplete(() => _ensureInFlight = null);
    return fut;
  }

  Future<bool> _ensureConnectedInner({required bool forceRebind}) async {
    final fbp = _device;
    if (fbp == null) {
      debugPrint('[ble] ensureConnected: no device — skip');
      return false;
    }
    final cached = fbp.isConnected;

    // 실제 link health 검증 — Android 의 isConnected 는 OS cached state 라
    // GATT 가 실제론 죽어도 true 를 반환할 수 있음. readRssi 는 HCI 명령으로
    // controller 에 직접 질의 — 링크가 죽었으면 throw. cached state 의 거짓
    // 양성을 검출하는 유일한 신뢰 가능 신호.
    bool isAlive = false;
    if (cached) {
      try {
        await fbp.readRssi().timeout(const Duration(seconds: 2));
        isAlive = true;
      } catch (e) {
        debugPrint('[ble] readRssi failed ($e) — link actually dead');
      }
    }
    debugPrint(
        '[ble] ensureConnected: isConnected=$cached alive=$isAlive '
        'control=${_control != null} forceRebind=$forceRebind');

    // 링크가 실제로 죽었으면 무조건 hard reconnect.
    if (!isAlive) {
      return _hardReconnect(fbp);
    }

    // 링크는 살아있지만 characteristic 이 stale 일 수 있음.
    //   - forceRebind=true (lifecycle resumed) → 무조건 재발견.
    //   - _control == null (이전 disconnect listener 가 정리) → 재발견.
    if (forceRebind || _control == null) {
      try {
        await _negotiateMtu(fbp);
        await _discoverAndBind(fbp);
        _connectionController.add(_control != null);
        return _control != null;
      } catch (e) {
        debugPrint(
            '[ble] ensureConnected: rediscover failed ($e) — hard reconnect');
        return _hardReconnect(fbp);
      }
    }

    // 살아있고 fresh — 그대로 사용.
    return true;
  }

  /// Disconnect → 짧게 대기 → reconnect → service 재발견. OS GATT cache 가
  /// stale 한 경우 정리. Resume 시 cached state 가 거짓 양성일 때 사용.
  Future<bool> _hardReconnect(BluetoothDevice fbp) async {
    debugPrint('[ble] hardReconnect: start');
    try {
      try {
        await fbp.disconnect();
      } catch (e) {
        debugPrint('[ble] hardReconnect: disconnect threw (ok): $e');
      }
      _control = null;
      _connectionController.add(false);
      // OS 가 GATT 정리할 시간 — 짧게 대기.
      await Future<void>.delayed(const Duration(milliseconds: 500));

      debugPrint('[ble] hardReconnect: connecting');
      await fbp.connect(autoConnect: true, mtu: null);
      // 30s — cold start connect() 와 동일. autoConnect=true 는 OS 가 광고
      // 잡을 때까지 대기, 펌웨어가 advertising 재시작에 1-2s 소요할 수 있음.
      await fbp.connectionState
          .firstWhere((s) => s == BluetoothConnectionState.connected)
          .timeout(const Duration(seconds: 30));
      debugPrint('[ble] hardReconnect: link up');

      await _negotiateMtu(fbp);
      await _discoverAndBind(fbp);
      _connectionController.add(_control != null);
      debugPrint(
          '[ble] hardReconnect: done, control=${_control != null}');
      return _control != null;
    } catch (e) {
      debugPrint('[ble] hardReconnect failed: $e');
      return false;
    }
  }

  @override
  Future<void> disconnect() async {
    await _device?.disconnect();
    _device = null;
  }

  @override
  Future<void> startSession(OrificeLevel level, {int startPhase = 0}) async {
    // App background → foreground 흐름에서 _control 이 stale 일 수 있음.
    // 1차: 빠른 경로 (cached state 신뢰). 실패 시 forceRebind 로 재시도.
    var ready = await ensureConnected();
    if (!ready || _control == null) {
      debugPrint('[ble] startSession: fast-path failed → forceRebind');
      ready = await ensureConnected(forceRebind: true);
    }
    if (!ready || _control == null) {
      debugPrint('[ble] startSession: ensureConnected failed — abort');
      return;
    }
    debugPrint('[ble] startSession → write [${Opcode.startSession}, '
        '${level.value}] to ${_control!.uuid}');
    try {
      await _control!.write(
        [Opcode.startSession, level.value, startPhase & 0xFF],
        withoutResponse: false,
      );
      debugPrint('[ble] startSession write completed');
    } catch (e) {
      debugPrint('[ble] startSession write failed: $e — forceRebind + retry');
      // 한 번 더 재시도 — GATT 오류로 실패 시 hard reconnect 로 회복.
      _control = null;
      final retry = await ensureConnected(forceRebind: true);
      if (retry && _control != null) {
        try {
          await _control!.write(
            [Opcode.startSession, level.value, startPhase & 0xFF],
            withoutResponse: false,
          );
          debugPrint('[ble] startSession write completed on retry');
        } catch (e2) {
          debugPrint('[ble] startSession retry also failed: $e2');
        }
      }
    }
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

  @override
  Future<void> setIntensityTarget({
    required int level,
    required double pimax,
    required double mep,
  }) async {
    // payload: opcode + level(1B) + pimax×10(u16 LE) + mep×10(u16 LE) = 6B 총
    // 펌웨어 ble_service.cpp 는 opcode 제외한 plen==5 분기.
    final pimaxX10 = (pimax * 10).round().clamp(0, 65535);
    final mepX10   = (mep   * 10).round().clamp(0, 65535);
    await _control?.write(
      [
        Opcode.setTarget,
        level & 0xFF,
        pimaxX10 & 0xFF, (pimaxX10 >> 8) & 0xFF,
        mepX10   & 0xFF, (mepX10   >> 8) & 0xFF,
      ],
      withoutResponse: false,
    );
  }

  @override
  Future<void> setTrainDuration(int seconds) async {
    // uint16 LE seconds.
    final lo = seconds & 0xFF;
    final hi = (seconds >> 8) & 0xFF;
    await _control?.write(
      [Opcode.setDuration, lo, hi],
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
