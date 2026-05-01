import 'package:blowfit/core/db/app_database.dart';
import 'package:blowfit/core/db/db_providers.dart';
import 'package:blowfit/core/db/session_repository.dart';
import 'package:blowfit/core/models/pressure_sample.dart';
import 'package:blowfit/features/history/history_screen.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';

/// HistoryScreen 은 [SessionRepository.watchSince] 결과만 사용. Drift 직접
/// 띄우면 stream timer 누수가 위젯 테스트에서 잡혀 실패하므로 메서드만 stub.
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
    child: MaterialApp.router(routerConfig: _stubRouter()),
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

  testWidgets('empty state when no sessions exist', (tester) async {
    _useTallView(tester);
    await tester.pumpWidget(_buildHarness(repo: _FakeRepo(const [])));
    await tester.pumpAndSettle();

    expect(find.text('훈련 기록'), findsOneWidget);
    expect(find.textContaining('아직 완료한 세션이 없습니다'), findsOneWidget);
  });

  testWidgets('weekly tab renders BarChart + 추이 헤더', (tester) async {
    _useTallView(tester);
    final repo = _FakeRepo([_session(id: 1, receivedAt: DateTime.now())]);
    await tester.pumpWidget(_buildHarness(repo: repo));
    await tester.pumpAndSettle();

    expect(find.text('주간'), findsOneWidget);
    expect(find.text('월간'), findsOneWidget);
    expect(find.byType(BarChart), findsOneWidget);
    expect(find.textContaining('평균 압력 추이'), findsOneWidget);
  });

  testWidgets('switching to monthly tab shows 이번 달 label', (tester) async {
    _useTallView(tester);
    final repo = _FakeRepo([_session(id: 1, receivedAt: DateTime.now())]);
    await tester.pumpWidget(_buildHarness(repo: repo));
    await tester.pumpAndSettle();

    await tester.tap(find.text('월간'));
    await tester.pumpAndSettle();

    expect(find.text('이번 달'), findsOneWidget);
  });

  testWidgets('지난주 데이터 없음 when no prior-week data', (tester) async {
    _useTallView(tester);
    final repo = _FakeRepo([_session(id: 1, receivedAt: DateTime.now())]);
    await tester.pumpWidget(_buildHarness(repo: repo));
    await tester.pumpAndSettle();

    expect(find.textContaining('지난주 데이터 없음'), findsOneWidget);
  });

  testWidgets('session tile tap navigates to /session/:id', (tester) async {
    _useTallView(tester);
    final repo = _FakeRepo([_session(id: 7, receivedAt: DateTime.now())]);
    await tester.pumpWidget(_buildHarness(repo: repo));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(ListTile).first);
    await tester.pumpAndSettle();

    expect(find.text('STUB:session/7'), findsOneWidget);
  });
}
