import 'package:blowfit/core/db/app_database.dart';
import 'package:blowfit/core/db/db_providers.dart';
import 'package:blowfit/core/db/session_repository.dart';
import 'package:blowfit/core/db/trend_bucketing.dart';
import 'package:blowfit/core/models/pressure_sample.dart';
import 'package:blowfit/core/theme/blowfit_theme.dart';
import 'package:blowfit/features/history/history_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';

/// HistoryScreen 은 Phase 5d 에서 calendar 그리드로 재구성됨. 위젯 레벨에선
/// SessionRepository 와 consecutiveDays/weekHits provider 만 의존.
class _FakeRepo implements SessionRepository {
  _FakeRepo(this._sessions);
  final List<Session> _sessions;

  @override
  Stream<List<Session>> watchSince(DateTime since) {
    return Stream.value(_sessions
        .where((s) => !s.receivedAt.isBefore(since))
        .toList(growable: false));
  }

  @override
  Future<int> insertFromSummary(SessionSummary s) async => 0;

  @override
  Stream<List<Session>> watchRecent({int limit = 30}) =>
      Stream.value(_sessions.reversed.take(limit).toList());

  @override
  Future<void> deleteAll() async {}

  @override
  Stream<int> watchConsecutiveDays({DateTime Function() now = _defaultNow}) =>
      Stream.value(0);

  @override
  Stream<int> watchWeekHits({DateTime Function() now = _defaultNow}) =>
      Stream.value(0);

  @override
  Stream<Duration> watchTodayDuration({DateTime Function() now = _defaultNow}) =>
      Stream.value(Duration.zero);

  @override
  Future<DateTime?> firstSessionDate() async {
    if (_sessions.isEmpty) return null;
    return _sessions.first.receivedAt;
  }

  @override
  Future<FirstSessionStats?> firstSessionStats() async => null;

  @override
  Stream<List<WeeklyAggregate>> watchWeeklyAggregates({
    int weeks = 12,
    DateTime Function() now = _defaultNow,
  }) =>
      const Stream.empty();

  @override
  Stream<WeekPressureAvgPair> watchWeekAvgPressurePair({
    DateTime Function() now = _defaultNow,
  }) =>
      Stream.value((thisWeek: null, lastWeek: null));

  @override
  Stream<List<TrendBucket>> watchTrendBuckets(
    TrendPeriod period, {
    DateTime Function() now = _defaultNow,
  }) =>
      const Stream.empty();

  @override
  Future<Session?> findById(int id) async =>
      _sessions.where((s) => s.id == id).firstOrNull;
}

DateTime _defaultNow() => DateTime.now();

Session _session({
  required int id,
  required DateTime receivedAt,
  double avg = 22.0,
  double max = 28.0,
  int durationSec = 240,
  int targetHits = 3,
}) {
  return Session(
    id: id,
    deviceSessionId: id,
    startedAt: null,
    durationSec: durationSec,
    maxPressure: max,
    avgPressure: avg,
    enduranceSec: 180,
    orificeLevel: 1,
    targetHits: targetHits,
    sampleCount: 24000,
    crc32: 0,
    receivedAt: receivedAt,
  );
}

GoRouter _stubRouter() => GoRouter(
      initialLocation: '/history',
      routes: [
        GoRoute(path: '/history', builder: (_, __) => const HistoryScreen()),
        GoRoute(
          path: '/session/:id',
          builder: (_, state) => Scaffold(
            body: Text('STUB:session/${state.pathParameters['id']}'),
          ),
        ),
      ],
    );

Widget _buildHarness({required _FakeRepo repo}) {
  return ProviderScope(
    overrides: [
      sessionRepositoryProvider.overrideWithValue(repo),
    ],
    child: MaterialApp.router(
      theme: BlowfitTheme.light(),
      routerConfig: _stubRouter(),
    ),
  );
}

void _useTallView(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('ko');
  });

  testWidgets('renders streak hero + calendar + recent sessions header',
      (tester) async {
    _useTallView(tester);
    await tester.pumpWidget(_buildHarness(repo: _FakeRepo(const [])));
    await tester.pumpAndSettle();

    expect(find.text('훈련 기록'), findsOneWidget);
    expect(find.text('연속 훈련'), findsOneWidget);
    expect(find.text('최근 세션'), findsOneWidget);
    // 캘린더 요일 헤더 — '월'/'화' 는 일자 그리드와 겹치지 않아 1번만 노출.
    expect(find.text('월'), findsOneWidget);
    expect(find.text('화'), findsOneWidget);
  });

  testWidgets('empty state shows hint when no sessions', (tester) async {
    _useTallView(tester);
    await tester.pumpWidget(_buildHarness(repo: _FakeRepo(const [])));
    await tester.pumpAndSettle();

    expect(find.textContaining('아직 완료한 세션이 없어요'), findsOneWidget);
  });

  testWidgets('stats triple shows 이번 달/이번 주/총 훈련 labels', (tester) async {
    _useTallView(tester);
    final repo = _FakeRepo([_session(id: 1, receivedAt: DateTime.now())]);
    await tester.pumpWidget(_buildHarness(repo: repo));
    await tester.pumpAndSettle();

    expect(find.text('이번 달'), findsOneWidget);
    expect(find.text('이번 주'), findsOneWidget);
    expect(find.text('총 훈련'), findsOneWidget);
  });

  testWidgets('session tile tap navigates to /session/:id', (tester) async {
    _useTallView(tester);
    final repo = _FakeRepo([_session(id: 7, receivedAt: DateTime.now())]);
    await tester.pumpWidget(_buildHarness(repo: repo));
    await tester.pumpAndSettle();

    // 'STUB:session/7' 까지 가는지 — 캘린더 안에 새로 그린 _SessionRow 탭.
    // 점수 텍스트 클릭으로 InkWell 트리거.
    await tester.tap(find.text('점수'));
    await tester.pumpAndSettle();

    expect(find.text('STUB:session/7'), findsOneWidget);
  });
}
