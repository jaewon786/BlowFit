// Samsung Health Data SDK 온디바이스 검증용 테스트 화면 (개발용).
//
// 실기기(갤럭시폰 + 삼성헬스 개발자모드 + 워치 수면데이터)에서 권한 동의,
// 수면/SpO2 읽기, DB 동기화·조회가 실제로 동작하는지 버튼으로 확인한다.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/db/db_providers.dart';

class SamsungHealthTestScreen extends ConsumerStatefulWidget {
  const SamsungHealthTestScreen({super.key});

  @override
  ConsumerState<SamsungHealthTestScreen> createState() =>
      _SamsungHealthTestScreenState();
}

class _SamsungHealthTestScreenState
    extends ConsumerState<SamsungHealthTestScreen> {
  final List<String> _log = <String>[];
  bool _busy = false;

  void _add(String s) => setState(() => _log.insert(0, s));

  DateTime get _to => DateTime.now();
  DateTime get _from => DateTime.now().subtract(const Duration(days: 14));

  Future<void> _run(String label, Future<void> Function() body) async {
    if (_busy) return;
    setState(() => _busy = true);
    _add('▶ $label');
    try {
      await body();
    } catch (e) {
      _add('❌ $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final svc = ref.read(samsungHealthServiceProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Samsung Health 테스트')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _btn('① 사용 가능?', () async {
                  _add('isAvailable = ${await svc.isAvailable()}');
                }),
                _btn('② 권한 확인', () async {
                  _add('hasPermissions = ${await svc.hasPermissions()}');
                }),
                _btn('③ 권한 요청', () async {
                  _add('requestPermissions = ${await svc.requestPermissions()}');
                }),
                _btn('④ 수면 읽기(14일)', () async {
                  final list = await svc.readSleep(_from, _to);
                  _add('수면 ${list.length}건');
                  for (final s in list.take(10)) {
                    _add('  ${s.start} ~ ${s.end} | 점수=${s.score} | ${s.durationMin}분');
                  }
                }),
                _btn('⑤ SpO2 읽기(14일)', () async {
                  final list = await svc.readSpo2(_from, _to);
                  _add('SpO2 ${list.length}건');
                  for (final s in list.take(10)) {
                    _add('  ${s.start} | avg=${s.avg} min=${s.min} max=${s.max}');
                  }
                }),
                _btn('⑤-2 무호흡 읽기(14일)', () async {
                  final list = await svc.readApneaSigns(_from, _to);
                  _add('무호흡 ${list.length}건');
                  for (final a in list.take(10)) {
                    _add('  ${a.end} | ${a.sign}');
                  }
                }),
                _btn('⑥ 동기화→DB(30일)', () async {
                  final n = await ref.read(sleepSyncProvider).sync(days: 30);
                  _add('DB 저장 $n 밤');
                }),
                _btn('⑦ DB 조회', () async {
                  final rows = await ref.read(sleepRepositoryProvider).recent();
                  _add('DB ${rows.length}건');
                  for (final r in rows.take(10)) {
                    _add('  ${r.night.toString().split(' ').first} | 점수=${r.score} | ${r.durationMin}분 | SpO2min=${r.spo2Min}');
                  }
                }),
                _btn('⑧ 데모 주입', () async {
                  final nights = await ref.read(sleepRepositoryProvider).seedDemo();
                  final sess =
                      await ref.read(sessionRepositoryProvider).seedDemoSessions();
                  _add('데모 수면 $nights박 + 훈련 $sess회 주입 완료');
                }),
                _btn('⑨ DB 비우기', () async {
                  await ref.read(sleepRepositoryProvider).clear();
                  await ref.read(sessionRepositoryProvider).clearDemoSessions();
                  _add('데모 수면 + 데모 훈련 비움');
                }),
                _btn('⑩ 효과 화면 열기', () async {
                  if (mounted) context.push('/sleep-effect');
                }),
                _btn('⚠️ 전체 데이터 초기화', _resetAll),
                _btn('로그 지우기', () async {
                  setState(_log.clear);
                }),
              ],
            ),
          ),
          if (_busy) const LinearProgressIndicator(),
          const Divider(height: 1),
          Expanded(
            child: Container(
              width: double.infinity,
              color: const Color(0xFF111111),
              padding: const EdgeInsets.all(12),
              child: SingleChildScrollView(
                child: SelectableText(
                  _log.isEmpty ? '버튼을 눌러 테스트하세요.' : _log.join('\n'),
                  style: const TextStyle(
                    color: Color(0xFFB8F0C8),
                    fontFamily: 'monospace',
                    fontSize: 12,
                    height: 1.5,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 모든 훈련 세션 + 수면 기록 삭제 (확인 다이얼로그). 되돌릴 수 없음.
  Future<void> _resetAll() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('전체 데이터 초기화'),
        content: const Text(
            '모든 훈련 세션과 수면 기록을 삭제합니다.\n되돌릴 수 없습니다.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('취소')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('삭제', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (ok != true) {
      _add('초기화 취소');
      return;
    }
    await ref.read(sessionRepositoryProvider).deleteAll();
    await ref.read(sleepRepositoryProvider).clear();
    _add('전체 데이터 삭제 완료 (세션 + 수면)');
  }

  Widget _btn(String label, Future<void> Function() body) => ElevatedButton(
        onPressed: _busy ? null : () => _run(label, body),
        child: Text(label),
      );
}
