import 'package:blowfit/core/storage/last_device_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('load returns null when no device persisted', () async {
    final store = await LastDeviceStore.open();
    expect(store.load(), isNull);
  });

  test('save then load round-trips id and name', () async {
    final store = await LastDeviceStore.open();
    await store.save(const LastDevice(id: 'aa:bb:cc', name: 'BlowFit-001'));
    expect(store.load(), const LastDevice(id: 'aa:bb:cc', name: 'BlowFit-001'));
  });

  test('save overwrites previous device', () async {
    final store = await LastDeviceStore.open();
    await store.save(const LastDevice(id: '1', name: 'first'));
    await store.save(const LastDevice(id: '2', name: 'second'));
    expect(store.load(), const LastDevice(id: '2', name: 'second'));
  });

  test('clear removes persisted device', () async {
    final store = await LastDeviceStore.open();
    await store.save(const LastDevice(id: 'x', name: 'y'));
    await store.clear();
    expect(store.load(), isNull);
  });

  test('load survives a fresh open (persisted to disk)', () async {
    SharedPreferences.setMockInitialValues({
      'last_device_id': 'persisted',
      'last_device_name': 'Saved Device',
    });
    final store = await LastDeviceStore.open();
    expect(store.load(), const LastDevice(id: 'persisted', name: 'Saved Device'));
  });

  test('treats empty id as no saved device', () async {
    SharedPreferences.setMockInitialValues({
      'last_device_id': '',
      'last_device_name': 'orphan',
    });
    final store = await LastDeviceStore.open();
    expect(store.load(), isNull);
  });

  test('LastDevice equality and hashCode', () {
    const a = LastDevice(id: 'x', name: 'y');
    const b = LastDevice(id: 'x', name: 'y');
    const c = LastDevice(id: 'x', name: 'z');
    expect(a, b);
    expect(a.hashCode, b.hashCode);
    expect(a == c, isFalse);
  });
}
