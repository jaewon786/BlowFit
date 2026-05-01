import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'app_database.g.dart';

class Sessions extends Table {
  IntColumn get id => integer().autoIncrement()();

  // Device-assigned session id (uint32). Unique per device but may collide
  // across two devices — pair with deviceId when multi-device support lands.
  IntColumn get deviceSessionId => integer()();

  DateTimeColumn get startedAt => dateTime().nullable()();
  IntColumn get durationSec => integer()();
  RealColumn get maxPressure => real()();
  RealColumn get avgPressure => real()();
  IntColumn get enduranceSec => integer()();
  IntColumn get orificeLevel => integer()();
  IntColumn get targetHits => integer()();
  IntColumn get sampleCount => integer()();
  IntColumn get crc32 => integer()();

  // When the app persisted the row. Used for sort/paging when startedAt is
  // null (SYNC_TIME not performed).
  DateTimeColumn get receivedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  List<Set<Column>> get uniqueKeys => [
        {deviceSessionId},
      ];
}

@DriftDatabase(tables: [Sessions])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_open());

  /// In-memory executor seam for unit tests.
  AppDatabase.forTesting(QueryExecutor e) : super(e);

  @override
  int get schemaVersion => 1;

  static QueryExecutor _open() =>
      driftDatabase(name: 'blowfit', native: const DriftNativeOptions());
}
