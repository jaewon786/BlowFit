import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'last_device_store.dart';
import 'target_settings_store.dart';

/// Async because SharedPreferences.getInstance() is async on first call.
/// UI consumers should `.when(...)` and gate auto-reconnect on the loaded value.
final lastDeviceStoreProvider = FutureProvider<LastDeviceStore>((ref) {
  return LastDeviceStore.open();
});

final targetSettingsStoreProvider = FutureProvider<TargetSettingsStore>((ref) {
  return TargetSettingsStore.open();
});
