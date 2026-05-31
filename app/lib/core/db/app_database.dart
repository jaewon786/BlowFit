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

/// Samsung Health 에서 동기화한 하룻밤 수면 레코드 (밤 1건/일).
class SleepRecords extends Table {
  IntColumn get id => integer().autoIncrement()();

  // 그 밤의 날짜 키 (기상일, 자정 기준 DateTime). 밤당 1행 (upsert).
  DateTimeColumn get night => dateTime()();

  DateTimeColumn get startedAt => dateTime().nullable()();
  DateTimeColumn get endedAt => dateTime().nullable()();
  IntColumn get score => integer().nullable()(); // 수면 점수 0~100
  IntColumn get durationMin => integer().nullable()(); // 총 수면(분)

  // 수면 중 혈중산소(SpO2) — 측정 없으면 null.
  RealColumn get spo2Avg => real().nullable()();
  RealColumn get spo2Min => real().nullable()();
  RealColumn get spo2Max => real().nullable()();

  // 수면무호흡 징후 (DETECTED / NOT_DETECTED / UNDEFINED). 미측정 시 null.
  TextColumn get apneaSign => text().nullable()();

  TextColumn get source =>
      text().withDefault(const Constant('samsung_health'))();
  DateTimeColumn get receivedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  List<Set<Column>> get uniqueKeys => [
        {night},
      ];
}

@DriftDatabase(tables: [Sessions, SleepRecords])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_open());

  /// In-memory executor seam for unit tests.
  AppDatabase.forTesting(QueryExecutor e) : super(e);

  @override
  int get schemaVersion => 4;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) => m.createAll(),
        onUpgrade: (m, from, to) async {
          // v1 → v2: 흡기(음압) 통계 컬럼 추가 (기존 행은 default 0).
          if (from < 2) {
            await m.addColumn(sessions, sessions.avgInhale);
            await m.addColumn(sessions, sessions.maxInhale);
          }
          // v2 → v3: Samsung Health 수면 레코드 테이블 추가.
          if (from < 3) {
            await m.createTable(sleepRecords);
          }
          // v3 → v4: 수면무호흡 징후 컬럼 추가.
          if (from < 4) {
            await m.addColumn(sleepRecords, sleepRecords.apneaSign);
          }
        },
      );

  static QueryExecutor _open() =>
      driftDatabase(name: 'blowfit', native: const DriftNativeOptions());
}
