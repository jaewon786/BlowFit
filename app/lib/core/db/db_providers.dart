import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../ble/ble_providers.dart';
import '../ble/discovered_device.dart';
import '../storage/storage_providers.dart';
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

/// 연결될 때마다 SharedPreferences 의 목표 압력대를 펌웨어로 재전송.
/// 펌웨어가 reboot 되면 RAM 의 g_targetLow/High 가 default (20-30) 으로
/// 리셋되므로, 사용자가 설정한 zone (예: 10-20) 이 디바이스 LCD 와 endurance
/// 계산에 일관되게 반영되도록 매 connect 시 sync.
final targetSyncProvider = Provider<void>((ref) {
  ref.listen(connectionProvider, (_, next) {
    next.whenData((connected) async {
      if (!connected) return;
      // Service discovery + setNotifyValue 가 안정화될 때까지 충분히 대기.
      // 너무 짧으면 _control characteristic 가 아직 null 이라 write 가 no-op.
      await Future.delayed(const Duration(milliseconds: 1500));
      try {
        final store = await ref.read(targetSettingsStoreProvider.future);
        final zone = store.load();
        await ref.read(bleManagerProvider).setTarget(zone.low, zone.high);
      } catch (_) {
        // 실패 시 사용자가 설정 화면에서 다시 저장하면 복구. silently ignore.
      }
    });
  }, fireImmediately: true);
});

/// 앱 시작 시 1회 자동 재연결 시도. SharedPreferences 의 lastDevice 가 있으면
/// targeted scan + auto connect. 실패해도 silent (사용자가 수동 SCAN 으로 fallback).
final autoReconnectProvider = Provider<void>((ref) {
  // Provider 첫 watch 시점에 백그라운드로 시도. 1초 지연으로 BLE 어댑터 초기화 +
  // permission 처리 등이 끝날 시간 확보.
  Future.delayed(const Duration(seconds: 1), () async {
    // 이미 연결됐으면 (e.g. 사용자가 빨리 manual scan 진행) skip.
    if ((ref.read(connectionProvider).valueOrNull ?? false)) return;
    try {
      final store = await ref.read(lastDeviceStoreProvider.future);
      final last = store.load();
      if (last == null) return; // 처음 사용자 — manual scan 으로 진행

      final manager = ref.read(bleManagerProvider);
      // 빠른 targeted scan (3s).
      final results = await manager.scan(timeout: const Duration(seconds: 3));
      // 마지막 device id 와 일치하는 거 찾기 (없으면 null).
      DiscoveredDevice? match;
      for (final d in results) {
        if (d.id == last.id) {
          match = d;
          break;
        }
      }
      if (match == null) return; // 디바이스 꺼져있음 — silent fallback

      await manager.connect(match);
      // 성공 시 lastDevice 는 이미 connect_screen 에서 저장됨 — 갱신 불필요
    } catch (_) {
      // 권한 / 어댑터 / 기타 실패 — 사용자 수동 진행 가능
    }
  });
});

/// Distinct-day streak ending today. Drives Dashboard "연속 일수".
final consecutiveDaysProvider = StreamProvider<int>((ref) {
  return ref.watch(sessionRepositoryProvider).watchConsecutiveDays();
});

/// Days this week (Mon-start) with at least one session. Drives "주간 달성".
final weekHitsProvider = StreamProvider<int>((ref) {
  return ref.watch(sessionRepositoryProvider).watchWeekHits();
});

/// Total training time today. Drives the "오늘의 목표" progress bar.
final todayDurationProvider = StreamProvider<Duration>((ref) {
  return ref.watch(sessionRepositoryProvider).watchTodayDuration();
});

/// Earliest session date — null for new users. Used by the guide screen to
/// recommend an orifice level based on training experience.
final firstSessionDateProvider = FutureProvider<DateTime?>((ref) {
  return ref.watch(sessionRepositoryProvider).firstSessionDate();
});

/// Single-session lookup by primary key. Drives the SessionDetail screen.
final sessionByIdProvider = FutureProvider.family<Session?, int>((ref, id) {
  return ref.watch(sessionRepositoryProvider).findById(id);
});
