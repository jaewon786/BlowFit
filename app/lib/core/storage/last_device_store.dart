import 'package:shared_preferences/shared_preferences.dart';

/// Persists the most recently connected BlowFit device so we can re-pair
/// silently on next launch instead of forcing the user through the scan screen.
class LastDeviceStore {
  LastDeviceStore(this._prefs);

  static const _kId = 'last_device_id';
  static const _kName = 'last_device_name';

  final SharedPreferences _prefs;

  static Future<LastDeviceStore> open() async {
    final prefs = await SharedPreferences.getInstance();
    return LastDeviceStore(prefs);
  }

  LastDevice? load() {
    final id = _prefs.getString(_kId);
    final name = _prefs.getString(_kName);
    if (id == null || id.isEmpty) return null;
    return LastDevice(id: id, name: name ?? id);
  }

  Future<void> save(LastDevice d) async {
    await _prefs.setString(_kId, d.id);
    await _prefs.setString(_kName, d.name);
  }

  Future<void> clear() async {
    await _prefs.remove(_kId);
    await _prefs.remove(_kName);
  }
}

class LastDevice {
  final String id;
  final String name;
  const LastDevice({required this.id, required this.name});

  @override
  bool operator ==(Object other) =>
      other is LastDevice && other.id == id && other.name == name;

  @override
  int get hashCode => Object.hash(id, name);
}
