import 'package:blowfit/core/ble/fake_ble_manager.dart';
import 'package:blowfit/core/ble/blowfit_uuids.dart';
import 'package:blowfit/core/ble/discovered_device.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('FakeBleManager discovers one fake device and emits pressure', () async {
    final m = FakeBleManager();
    final devices = await m.scan(timeout: const Duration(milliseconds: 100));
    expect(devices, hasLength(1));
    expect(devices.first.name, contains('BlowFit'));

    final connected = m.connectionStream.first;
    await m.connect(devices.first);
    expect(await connected, true);

    final first = m.pressureStream.first;
    await m.startSession(OrificeLevel.medium);
    final sample = await first.timeout(const Duration(seconds: 1));
    expect(sample.cmH2O, greaterThanOrEqualTo(0));

    final summary = m.sessionSummaryStream.first;
    await m.stopSession();
    final s = await summary.timeout(const Duration(seconds: 1));
    expect(s.sessionId, 1);
    expect(s.sampleCount, greaterThan(0));

    m.dispose();
  });

  test('DiscoveredDevice equality by fields', () {
    const a = DiscoveredDevice(id: 'x', name: 'y', rssi: -1);
    expect(a.id, 'x');
    expect(a.name, 'y');
    expect(a.rssi, -1);
  });
}
