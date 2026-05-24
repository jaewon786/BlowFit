// Android Foreground Service — 앱 종료 후에도 BLE 자동 재연결 유지.
//
// 흐름:
//   1. 사용자가 첫 페어링 완료 → main app 이 startService() 호출 → service 시작
//   2. Service 가 background isolate 에서 실행 (영구 알림 + Android service)
//   3. 30초 마다 onRepeatEvent 호출 → 본딩된 디바이스 광고 스캔
//   4. 디바이스 발견 시 connect 시도 (autoConnect=true)
//   5. 연결되면 service notification 갱신 + 데이터는 일단 keep-alive 만
//
// 한계:
//   - flutter_blue_plus 의 BluetoothDevice 객체는 isolate 단위로 분리됨 →
//     service isolate 에서 자체 BLE manager 인스턴스 사용. main app 의 인스턴스
//     와 공유 불가. 즉 service 가 연결한 상태에서 main app 켜면 service 가
//     일단 disconnect 하고 main app 이 다시 연결하는 패턴 (또는 service 가
//     계속 잡고 있고 main 은 데이터 stream 받는 형태 — 후속 작업).
//   - 첫 페어링은 반드시 main app 에서 — service 는 본딩 정보 활용해서 재연결만.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'blowfit_uuids.dart';

/// Service 실행 시점에 호출되는 entry point. @pragma 필수.
@pragma('vm:entry-point')
void startBleBackgroundTask() {
  FlutterForegroundTask.setTaskHandler(BleBackgroundTaskHandler());
}

class BleBackgroundTaskHandler extends TaskHandler {
  BluetoothDevice? _device;
  StreamSubscription<BluetoothConnectionState>? _connSub;
  bool _connecting = false;

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    debugPrint('[bg-ble] service started (starter: $starter)');
    FlutterForegroundTask.updateService(
      notificationTitle: 'BlowFit 백그라운드',
      notificationText: '디바이스 검색 중...',
    );
    // 1. OS 가 이미 잡은 connection 있는지 먼저 확인.
    await _syncOsConnectionState();
    // 2. 없으면 새로 시도.
    if ((_device?.isConnected ?? false) != true) {
      _tryReconnect();
    }
  }

  @override
  void onRepeatEvent(DateTime timestamp) {
    // 30초마다 호출. 1) OS-level connection 먼저 체크 (autoConnect=true 의
    // 시스템 차원 reconnect 가 우리 service 와 별도로 일어나는 케이스). 그 후
    // 2) _device 의 isConnected 가 false 면 새로 시도.
    if (_connecting) return;
    _syncOsConnectionState();
    if ((_device?.isConnected ?? false) != true) {
      _tryReconnect();
    }
  }

  /// FlutterBluePlus.connectedDevices 가 OS 의 GATT-connected 목록을 반환.
  /// 우리 lastDevice 가 있으면 service 의 _device 로 연동 + 알림 갱신.
  Future<void> _syncOsConnectionState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastId = prefs.getString('blowfit.lastDevice.id');
      if (lastId == null) return;

      // OS 가 잡고 있는 connected devices 목록 — service 가 만든 게 아니어도
      // 같은 process 안의 flutter_blue_plus 가 인식.
      final connected = FlutterBluePlus.connectedDevices;
      for (final d in connected) {
        if (d.remoteId.str == lastId) {
          if (_device?.remoteId.str != lastId) {
            debugPrint('[bg-ble] OS-level connection detected — adopting');
            _device = d;
            _setupConnectionListener(d);
            FlutterForegroundTask.updateService(
              notificationText: 'BlowFit 연결됨',
            );
          }
          return;
        }
      }
      // 우리 디바이스가 connected 목록에 없으면 _device 도 stale 처리.
      if (_device != null && !(_device?.isConnected ?? false)) {
        debugPrint('[bg-ble] no OS connection — clearing stale _device');
        _device = null;
      }
    } catch (e) {
      debugPrint('[bg-ble] _syncOsConnectionState error: $e');
    }
  }

  void _setupConnectionListener(BluetoothDevice d) {
    _connSub?.cancel();
    _connSub = d.connectionState.listen((s) {
      debugPrint('[bg-ble] connection state: $s');
      if (s == BluetoothConnectionState.connected) {
        FlutterForegroundTask.updateService(
          notificationText: 'BlowFit 연결됨',
        );
      } else if (s == BluetoothConnectionState.disconnected) {
        FlutterForegroundTask.updateService(
          notificationText: '연결 끊김 — 재시도 대기',
        );
      }
    });
  }

  @override
  Future<void> onDestroy(DateTime timestamp) async {
    debugPrint('[bg-ble] service destroyed');
    await _connSub?.cancel();
    try {
      await _device?.disconnect();
    } catch (_) {}
    _device = null;
  }

  /// 사용자가 알림을 탭하면 호출. main app 깨우기.
  @override
  void onNotificationPressed() {
    FlutterForegroundTask.launchApp('/');
  }

  Future<void> _tryReconnect() async {
    if (_connecting) return;
    _connecting = true;
    try {
      // 1. SharedPreferences 에서 lastDevice id 읽기.
      final prefs = await SharedPreferences.getInstance();
      final lastId = prefs.getString('blowfit.lastDevice.id');
      if (lastId == null) {
        debugPrint('[bg-ble] no lastDevice — skip');
        FlutterForegroundTask.updateService(
          notificationText: '페어링된 디바이스 없음',
        );
        return;
      }

      // 2. 짧은 스캔 (5초) — 본딩된 디바이스 발견 시도.
      debugPrint('[bg-ble] scanning for $lastId ...');
      FlutterForegroundTask.updateService(
        notificationText: '디바이스 검색 중...',
      );

      BluetoothDevice? found;
      final scanSub = FlutterBluePlus.scanResults.listen((results) {
        for (final r in results) {
          if (r.device.remoteId.str == lastId) {
            found = r.device;
            break;
          }
        }
      });
      await FlutterBluePlus.startScan(
        timeout: const Duration(seconds: 5),
      );
      await Future.delayed(const Duration(seconds: 5));
      await FlutterBluePlus.stopScan();
      await scanSub.cancel();

      if (found == null) {
        debugPrint('[bg-ble] device not advertising — will retry next cycle');
        FlutterForegroundTask.updateService(
          notificationText: '디바이스 신호 없음 — 30초 후 재시도',
        );
        return;
      }

      // 3. Connect (autoConnect=true 로 OS 차원 reconnect 유지).
      debugPrint('[bg-ble] connecting to ${found!.remoteId.str} ...');
      FlutterForegroundTask.updateService(
        notificationText: '연결 시도 중...',
      );
      _device = found;
      await found!.connect(autoConnect: true, mtu: null);
      // autoConnect=true 일 땐 connect() 즉시 return → 실제 연결 대기.
      await found!.connectionState
          .firstWhere((s) => s == BluetoothConnectionState.connected)
          .timeout(const Duration(seconds: 30), onTimeout: () {
        throw TimeoutException('background connect timeout');
      });

      debugPrint('[bg-ble] connected!');
      FlutterForegroundTask.updateService(
        notificationText: 'BlowFit 연결됨',
      );

      // 4. Connection state 변화 listen — disconnect 시 알림 갱신, reconnect 시
      // (OS autoConnect=true 가 자동으로 함) "연결됨" 알림.
      _setupConnectionListener(found!);
    } catch (e) {
      debugPrint('[bg-ble] reconnect failed: $e');
      FlutterForegroundTask.updateService(
        notificationText: '연결 실패 — 재시도 대기',
      );
    } finally {
      _connecting = false;
    }
  }
}

/// Service 시작 helper. main app 에서 첫 페어링 완료 후 호출.
class BleForegroundService {
  static Future<void> initialize() async {
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'blowfit_ble_service',
        channelName: 'BlowFit 자동 연결',
        channelDescription:
            '디바이스가 켜지면 자동으로 연결을 시도합니다',
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
        showWhen: false,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: false,
        playSound: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.repeat(30000),  // 30초마다
        autoRunOnBoot: false,   // TODO: 부팅 후 자동 시작은 별도 옵션
        autoRunOnMyPackageReplaced: true,
        allowWakeLock: true,
        allowWifiLock: false,
      ),
    );
  }

  static Future<bool> startService() async {
    if (await FlutterForegroundTask.isRunningService) {
      debugPrint('[bg-ble] service already running');
      return true;
    }
    final result = await FlutterForegroundTask.startService(
      serviceId: 256,
      notificationTitle: 'BlowFit 백그라운드',
      notificationText: '자동 연결 대기 중',
      callback: startBleBackgroundTask,
    );
    debugPrint('[bg-ble] startService result: $result');
    return result is ServiceRequestSuccess;
  }

  static Future<void> stopService() async {
    final result = await FlutterForegroundTask.stopService();
    debugPrint('[bg-ble] stopService result: $result');
  }

  /// Service 가 디바이스 id 를 알 수 있도록 SharedPreferences 에 저장.
  /// ConnectScreen 의 _attemptConnect 가 성공 시 호출.
  static Future<void> saveLastDeviceId(String id, String name) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('blowfit.lastDevice.id', id);
    await prefs.setString('blowfit.lastDevice.name', name);
    debugPrint('[bg-ble] saved lastDevice: $name ($id)');
  }
}

// blowfit_uuids 가 import 되어야 컴파일 OK — 서비스 안에서 UUID 참조 가능.
// 본 파일에선 직접 사용 안 하지만 placeholder import.
// ignore: unused_element
void _unused() => BlowfitUuids.service;
