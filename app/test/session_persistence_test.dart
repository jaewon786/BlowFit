import 'package:blowfit/core/ble/ble_providers.dart';
import 'package:blowfit/core/ble/blowfit_uuids.dart';
import 'package:blowfit/core/ble/discovered_device.dart';
import 'package:blowfit/core/ble/fake_ble_manager.dart';
import 'package:blowfit/core/db/app_database.dart';
import 'package:blowfit/core/db/db_providers.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('sessionPersistenceProvider writes BLE session summaries to the DB',
      () async {
    final fake = FakeBleManager();
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(() async {
      fake.dispose();
      await db.close();
    });

    final container = ProviderContainer(
      overrides: [
        bleManagerProvider.overrideWithValue(fake),
        appDatabaseProvider.overrideWithValue(db),
      ],
    );
    addTearDown(container.dispose);

    // Activate the persistence listener.
    container.read(sessionPersistenceProvider);

    // Simulate the full BLE session flow: connect -> start -> stop.
    await fake.connect(const DiscoveredDevice(
      id: 'fake:blowfit-sim',
      name: 'BlowFit-SIM (fake)',
      rssi: -42,
    ));
    await fake.startSession(OrificeLevel.medium);

    // Let some pressure samples accumulate before stopping.
    await Future<void>.delayed(const Duration(milliseconds: 200));
    await fake.stopSession();

    // Drain microtasks so the Riverpod listener gets the summary and inserts.
    await Future<void>.delayed(const Duration(milliseconds: 100));

    final rows = await db.select(db.sessions).get();
    expect(rows, isNotEmpty, reason: 'expected one session row from FakeBleManager');
    expect(rows.first.deviceSessionId, 1);
    expect(rows.first.orificeLevel, OrificeLevel.medium.value);
    expect(rows.first.sampleCount, greaterThan(0));
  });
}
