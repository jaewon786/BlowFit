import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../ble/ble_providers.dart';
import 'app_database.dart';
import 'session_repository.dart';

final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

final sessionRepositoryProvider = Provider<SessionRepository>((ref) {
  return SessionRepository(ref.watch(appDatabaseProvider));
});

/// Listens to BLE session summaries and persists each one. Must be kept alive
/// for the lifetime of the app (e.g. read in main's ProviderScope overrides
/// or an early-mounted screen).
final sessionPersistenceProvider = Provider<void>((ref) {
  final repo = ref.watch(sessionRepositoryProvider);
  ref.listen(sessionSummaryProvider, (_, next) {
    next.whenData((summary) => repo.insertFromSummary(summary));
  });
});
