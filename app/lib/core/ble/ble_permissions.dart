import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

/// Outcome of requesting the runtime permissions needed to scan/connect.
enum BlePermissionStatus {
  /// All required permissions granted — proceed with scan.
  granted,

  /// User denied this time but can be re-prompted.
  denied,

  /// User selected "Don't ask again" or restricted by policy. Direct them
  /// to system settings via [openAppSettings].
  permanentlyDenied,

  /// Platform doesn't expose runtime permissions (iOS, web, desktop) — the
  /// platform itself will surface a system dialog when scanning starts.
  notApplicable,
}

class BlePermissions {
  BlePermissions._();

  /// Requests the BLE permission set required to scan/connect.
  ///
  /// We only request the modern Android 12+ permissions ([Permission.bluetoothScan]
  /// + [Permission.bluetoothConnect]). The manifest declares ACCESS_FINE_LOCATION
  /// with `android:maxSdkVersion="30"` so the platform handles legacy Android 11-
  /// location prompts internally during scan. Requesting locationWhenInUse here
  /// would wedge the flow on Android 12+ where that permission is intentionally
  /// not declared and so cannot be granted.
  static Future<BlePermissionStatus> request() async {
    if (kIsWeb || !Platform.isAndroid) return BlePermissionStatus.notApplicable;

    final results = await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
    ].request();

    if (results.values.any((s) => s.isPermanentlyDenied)) {
      return BlePermissionStatus.permanentlyDenied;
    }
    if (results.values.any((s) => s.isDenied || s.isRestricted)) {
      return BlePermissionStatus.denied;
    }
    return BlePermissionStatus.granted;
  }

  /// Opens the system settings page for this app so the user can grant
  /// permissions that were previously dismissed with "Don't ask again".
  static Future<bool> openSettings() => openAppSettings();
}
