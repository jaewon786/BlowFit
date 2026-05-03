import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

/// 사용자 친화 메시지 + 카테고리.
///
/// `category` 가 [BleErrorCategory.btOff] 이면 ConnectScreen 의 _FailedView
/// 가 BT-off 전용 아이콘/CTA 를 보여줄 수 있다.
class BleErrorMessage {
  final String title;
  final String desc;
  final BleErrorCategory category;

  /// 개발자용 raw 메시지 — 디버그 빌드에서만 화면 하단에 작게 노출.
  final String details;

  const BleErrorMessage({
    required this.title,
    required this.desc,
    required this.category,
    required this.details,
  });
}

enum BleErrorCategory {
  /// 블루투스 어댑터 꺼짐.
  btOff,

  /// Android 5 회 / 30 초 스캔 횟수 제한 — 30초 cool-down 필요.
  scanThrottled,

  /// 권한 (Bluetooth Scan / Connect) 거부.
  permission,

  /// 스캔/연결 도중 timeout.
  timeout,

  /// 위치 서비스 비활성 (Android 11 이하 또는 OEM).
  locationOff,

  /// 분류 불가 — 일반 에러 메시지.
  generic,
}

/// FlutterBluePlusException / PlatformException / 기타 throwable 을
/// 한국어 친화 메시지로 매핑.
class BleErrorTranslator {
  BleErrorTranslator._();

  static BleErrorMessage translate(Object error) {
    final raw = error.toString();

    if (error is FlutterBluePlusException) {
      return _translateFbp(error, raw);
    }
    if (error is PlatformException) {
      return _translatePlatform(error, raw);
    }
    return _generic(raw);
  }

  // ---------------------------------------------------------------------------
  // FlutterBluePlusException 매핑
  // ---------------------------------------------------------------------------
  static BleErrorMessage _translateFbp(
      FlutterBluePlusException e, String raw) {
    final code = e.code;
    final desc = (e.description ?? '').toLowerCase();

    // ErrorPlatform.fbp — Dart 측 에러. code 는 FbpErrorCode index.
    if (e.platform == ErrorPlatform.fbp) {
      // 0=success, 1=timeout, 2=androidOnly, 3=applePlatformOnly,
      // 4=createBondFailed, 5=removeBondFailed, 6=deviceIsDisconnected,
      // 7=serviceNotFound, 8=characteristicNotFound, 9=adapterIsOff,
      // 10=connectionCanceled, 11=userRejected
      switch (code) {
        case 9: // adapterIsOff
          return _btOff(raw);
        case 1: // timeout
          return BleErrorMessage(
            title: '응답이 없습니다',
            desc: '디바이스 전원이 켜져 있고 가까이 있는지\n확인한 뒤 다시 시도해주세요.',
            category: BleErrorCategory.timeout,
            details: raw,
          );
        case 6: // deviceIsDisconnected
          return BleErrorMessage(
            title: '연결이 끊겼습니다',
            desc: '디바이스를 가까이 둔 뒤 다시 연결해주세요.',
            category: BleErrorCategory.generic,
            details: raw,
          );
        case 11: // userRejected
          return BleErrorMessage(
            title: '연결이 취소되었습니다',
            desc: '시스템 페어링 요청을 수락한 뒤\n다시 시도해주세요.',
            category: BleErrorCategory.generic,
            details: raw,
          );
      }
    }

    // ErrorPlatform.android — code 는 BluetoothLeScanner errorCode.
    // 1=ALREADY_STARTED, 2=APPLICATION_REGISTRATION_FAILED,
    // 3=INTERNAL_ERROR, 4=FEATURE_UNSUPPORTED, 5=OUT_OF_HARDWARE_RESOURCES,
    // 6=SCANNING_TOO_FREQUENTLY.
    if (e.platform == ErrorPlatform.android) {
      if (code == 6 || desc.contains('too_frequently') || desc.contains('throttle')) {
        return BleErrorMessage(
          title: '잠시 후 다시 시도해주세요',
          desc: '시스템이 짧은 시간 내 반복 스캔을 제한했습니다.\n30초 후에 다시 시도해주세요.',
          category: BleErrorCategory.scanThrottled,
          details: raw,
        );
      }
      if (code == 4 || desc.contains('unsupported')) {
        return BleErrorMessage(
          title: '이 기기는 BLE 를 지원하지 않습니다',
          desc: '블루투스 4.0 이상을 지원하는 기기에서\n사용해주세요.',
          category: BleErrorCategory.generic,
          details: raw,
        );
      }
      if (desc.contains('adapter is off') || desc.contains('bluetooth_off')) {
        return _btOff(raw);
      }
    }

    // 위치 서비스 (Android 11 이하).
    if (desc.contains('location') &&
        (desc.contains('off') || desc.contains('disabled'))) {
      return BleErrorMessage(
        title: '위치 서비스가 꺼져 있습니다',
        desc: 'Android 에서 BLE 스캔에는 위치 서비스가\n필요합니다. 시스템 설정에서 켜주세요.',
        category: BleErrorCategory.locationOff,
        details: raw,
      );
    }

    // 권한 키워드.
    if (desc.contains('permission') || desc.contains('not_authorized')) {
      return _permission(raw);
    }

    // BT off 키워드 fallback (description 에 포함된 케이스).
    if (desc.contains('off') || desc.contains('disabled')) {
      return _btOff(raw);
    }

    return _generic(raw);
  }

  // ---------------------------------------------------------------------------
  // raw PlatformException 매핑 (방법채널에서 직접 throw 된 경우)
  // ---------------------------------------------------------------------------
  static BleErrorMessage _translatePlatform(
      PlatformException e, String raw) {
    final code = e.code.toUpperCase();
    final msg = (e.message ?? '').toLowerCase();

    if (code.contains('PERMISSION') || msg.contains('permission')) {
      return _permission(raw);
    }
    if (code.contains('BLUETOOTH_OFF') ||
        msg.contains('adapter is off') ||
        msg.contains('bluetooth is off')) {
      return _btOff(raw);
    }
    if (code.contains('LOCATION') || msg.contains('location')) {
      return BleErrorMessage(
        title: '위치 서비스가 꺼져 있습니다',
        desc: 'Android 에서 BLE 스캔에는 위치 서비스가\n필요합니다. 시스템 설정에서 켜주세요.',
        category: BleErrorCategory.locationOff,
        details: raw,
      );
    }
    if (msg.contains('too_frequently') || msg.contains('throttle')) {
      return BleErrorMessage(
        title: '잠시 후 다시 시도해주세요',
        desc: '시스템이 짧은 시간 내 반복 스캔을 제한했습니다.\n30초 후에 다시 시도해주세요.',
        category: BleErrorCategory.scanThrottled,
        details: raw,
      );
    }
    return _generic(raw);
  }

  // ---------------------------------------------------------------------------
  static BleErrorMessage _btOff(String raw) => BleErrorMessage(
        title: '블루투스가 꺼져 있습니다',
        desc: '시스템 블루투스를 켠 뒤\n다시 시도해주세요.',
        category: BleErrorCategory.btOff,
        details: raw,
      );

  static BleErrorMessage _permission(String raw) => BleErrorMessage(
        title: '블루투스 권한이 필요합니다',
        desc: '설정에서 블루투스 검색 / 연결 권한을\n허용해주세요.',
        category: BleErrorCategory.permission,
        details: raw,
      );

  static BleErrorMessage _generic(String raw) => BleErrorMessage(
        title: '연결할 수 없습니다',
        desc: '잠시 후 다시 시도해주세요. 문제가 지속되면\n앱을 재시작하거나 디바이스를 다시 켜보세요.',
        category: BleErrorCategory.generic,
        details: raw,
      );
}
