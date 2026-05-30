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
  RealColumn get maxPressure => real()(); // 호기(양압) 최대
  RealColumn get avgPressure => real()(); // 호기(양압) 평균
  // 흡기(음압) 통계 — v4.0+ 펌웨어. 구버전/레거시 세션은 0 (default).
  RealColumn get avgInhale => real().withDefault(const Constant(0))();
  RealColumn get maxInhale => real().withDefault(const Constant(0))();
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
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) => m.createAll(),
        onUpgrade: (m, from, to) async {
          // v1 → v2: 흡기(음압) 통계 컬럼 추가 (기존 행은 default 0).
          if (from < 2) {
            await m.addColumn(sessions, sessions.avgInhale);
            await m.addColumn(sessions, sessions.maxInhale);
          }
        },
      );

  static QueryExecutor _open() =>
      driftDatabase(name: 'blowfit', native: const DriftNativeOptions());
}
