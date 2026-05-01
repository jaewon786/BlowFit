import 'package:blowfit/core/storage/target_settings_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('load returns firmware defaults when nothing saved', () async {
    final store = await TargetSettingsStore.open();
    final zone = store.load();
    expect(zone.low, TargetSettingsStore.defaultLow);
    expect(zone.high, TargetSettingsStore.defaultHigh);
  });

  test('save then load round-trips values', () async {
    final store = await TargetSettingsStore.open();
    await store.save(const TargetZone(low: 22, high: 35));
    expect(store.load(), const TargetZone(low: 22, high: 35));
  });

  test('TargetZone.isValid enforces width and absolute bounds', () {
    expect(const TargetZone(low: 20, high: 30).isValid, isTrue);
    expect(const TargetZone(low: 5, high: 50).isValid, isTrue);
    // Width too small
    expect(const TargetZone(low: 20, high: 23).isValid, isFalse);
    // Below absolute min
    expect(const TargetZone(low: 4, high: 30).isValid, isFalse);
    // Above absolute max
    expect(const TargetZone(low: 20, high: 51).isValid, isFalse);
  });

  test('TargetZone equality + hashCode', () {
    const a = TargetZone(low: 20, high: 30);
    const b = TargetZone(low: 20, high: 30);
    const c = TargetZone(low: 21, high: 30);
    expect(a, b);
    expect(a.hashCode, b.hashCode);
    expect(a == c, isFalse);
  });
}
