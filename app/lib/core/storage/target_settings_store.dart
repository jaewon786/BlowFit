import 'package:shared_preferences/shared_preferences.dart';

/// Persists the target pressure zone so the Settings screen can display the
/// last-saved values. Source of truth is still the device (storage.cpp on
/// firmware) — this is just a UI cache to avoid resetting sliders to defaults
/// across app launches.
class TargetSettingsStore {
  TargetSettingsStore(this._prefs);

  static const _kLow = 'target_low_cmh2o';
  static const _kHigh = 'target_high_cmh2o';

  static const defaultLow = 20;
  static const defaultHigh = 30;

  final SharedPreferences _prefs;

  static Future<TargetSettingsStore> open() async {
    final prefs = await SharedPreferences.getInstance();
    return TargetSettingsStore(prefs);
  }

  TargetZone load() {
    return TargetZone(
      low: _prefs.getInt(_kLow) ?? defaultLow,
      high: _prefs.getInt(_kHigh) ?? defaultHigh,
    );
  }

  Future<void> save(TargetZone zone) async {
    await _prefs.setInt(_kLow, zone.low);
    await _prefs.setInt(_kHigh, zone.high);
  }
}

class TargetZone {
  final int low;
  final int high;
  const TargetZone({required this.low, required this.high});

  /// At least 5 cmH2O wide and clamped to a sensor-realistic range.
  bool get isValid => high >= low + 5 && low >= 5 && high <= 50;

  @override
  bool operator ==(Object other) =>
      other is TargetZone && other.low == low && other.high == high;

  @override
  int get hashCode => Object.hash(low, high);
}
