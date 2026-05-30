import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../ble/ble_providers.dart';
import '../ble/discovered_device.dart';
import '../coach/milestone_engine.dart';
import '../storage/storage_providers.dart';
import 'app_database.dart';
import 'session_repository.dart';
import 'trend_bucketing.dart';

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
        // 훈련 시간도 함께 sync — 펌웨어 reboot 시 default(10분) 로 리셋되므로
        // 사용자가 설정한 값을 매 connect 마다 재전송.
        final durStore = await ref.read(trainDurationStoreProvider.future);
        await ref
            .read(bleManagerProvider)
            .setTrainDuration(durStore.loadMinutes() * 60);
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
    final manager = ref.read(bleManagerProvider);

    // STEP 1 — BleForegroundService (별도 isolate) 가 잡고 있는 OS-level
    // GATT connection 흡수 시도. flutter_blue_plus 는 process-level singleton
    // 이라 service isolate 의 connectedDevices 가 main isolate 에서도 보임.
    // Service 가 연결 잡은 상태에서 device 는 advertising 안 함 → scan 으로는
    // 못 찾음. 이 path 가 split-brain (디바이스 LCD=연결, 앱=미연결) 해결.
    try {
      if (await manager.tryAdoptExistingConnection()) {
        debugPrint('[auto] adopted existing OS connection — skip scan');
        return;
      }
    } catch (e) {
      debugPrint('[auto] adopt threw: $e');
    }

    // STEP 2 — adopt 실패 (service 가 연결 안 잡았거나 device 가 다름) 시
    // 기존 scan + connect 흐름.
    try {
      final store = await ref.read(lastDeviceStoreProvider.future);
      final last = store.load();
      if (last == null) return; // 처음 사용자 — manual scan 으로 진행

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

/// 최근 N주 호기 평균/최대. Dashboard 등에서 가벼운 윈도우용.
final weeklyAggregatesByWindowProvider =
    StreamProvider.family<List<WeeklyAggregate>, int>((ref, weeks) {
  return ref
      .watch(sessionRepositoryProvider)
      .watchWeeklyAggregates(weeks: weeks);
});

/// Trend 화면 — period 별 버킷.
final trendBucketsProvider =
    StreamProvider.family<List<TrendBucket>, TrendPeriod>((ref, period) {
  return ref.watch(sessionRepositoryProvider).watchTrendBuckets(period);
});

/// 이번 주 / 지난 주 호기 평균. Dashboard quick stats.
final weekAvgPressureProvider =
    StreamProvider<WeekPressureAvgPair>((ref) {
  return ref.watch(sessionRepositoryProvider).watchWeekAvgPressurePair();
});

/// 첫 세션 호기 통계. Profile 베이스라인 카드.
final firstSessionStatsProvider =
    FutureProvider<FirstSessionStats?>((ref) {
  return ref.watch(sessionRepositoryProvider).firstSessionStats();
});

/// Trend 화면 Calendar — 주어진 달에서 1+ 세션 있는 day-of-month 집합.
/// `month` 의 year/month 만 사용 (day 는 무시).
final monthTrainedDaysProvider =
    StreamProvider.family<Set<int>, DateTime>((ref, month) {
  final repo = ref.watch(sessionRepositoryProvider);
  final monthStart = DateTime(month.year, month.month, 1);
  final nextMonth = DateTime(month.year, month.month + 1, 1);
  return repo.watchSince(monthStart).map((sessions) {
    final days = <int>{};
    for (final s in sessions) {
      final t = s.receivedAt;
      if (t.isBefore(monthStart) || !t.isBefore(nextMonth)) continue;
      days.add(t.day);
    }
    return days;
  });
});

/// Trend 화면 Summary 카드 — "이번 주 N회 | 이번 달 N회 | 지금까지 N회".
///   thisWeekSessions : 이번 주 (월요일 시작) 의 총 세션 수.
///   thisMonthSessions: 이번 달의 총 세션 수 (회수).
///   totalSessions    : 지금까지 누적 세션 수.
typedef TrendSummaryStats = ({
  int thisWeekSessions,
  int thisMonthSessions,
  int totalSessions,
});

final trendSummaryStatsProvider = StreamProvider<TrendSummaryStats>((ref) {
  final repo = ref.watch(sessionRepositoryProvider);
  // 1년 윈도우 — 사용자 대부분이 1년 안에서 사용. "지금까지" 는 정확히는
  // 무제한이지만 watchSince(1년 전) 으로 근사. 추후 watchAll 필요 시 별도
  // 메서드로 분리.
  final since = DateTime.now().subtract(const Duration(days: 365));
  return repo.watchSince(since).map((sessions) {
    final now = DateTime.now();
    // 이번 주 월요일 00:00.
    final daysFromMon = now.weekday - DateTime.monday;
    final monday = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: daysFromMon));
    final monthStart = DateTime(now.year, now.month, 1);

    var weekSessions = 0;
    var monthSessions = 0;
    for (final s in sessions) {
      final t = s.receivedAt;
      if (!t.isBefore(monday)) weekSessions++;
      if (!t.isBefore(monthStart) && t.year == now.year && t.month == now.month) {
        monthSessions++;
      }
    }
    return (
      thisWeekSessions: weekSessions,
      thisMonthSessions: monthSessions,
      totalSessions: sessions.length,
    );
  });
});

/// Trend 화면 마일스톤 카드용 — 최근 200일 세션 + 현재 streak 합쳐서
/// MilestoneEngine 으로 5종 마일스톤 계산.
final milestonesProvider = StreamProvider<List<Milestone>>((ref) {
  final repo = ref.watch(sessionRepositoryProvider);
  // 200일 윈도우 — 30일 streak / 호기 25 돌파 모두 안에 들어옴.
  final since = DateTime.now().subtract(const Duration(days: 200));
  return repo.watchSince(since).asyncMap((sessions) async {
    final streak = await repo.watchConsecutiveDays().first;
    return MilestoneEngine.compute(
      sessions: sessions,
      currentStreak: streak,
    );
  });
});
