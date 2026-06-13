// 수면추이/효과 화면 진입 시 Samsung Health(갤럭시 워치) → 로컬 DB 자동 동기화.
//
// 화면(recentSleepProvider)은 로컬 DB(SleepRecords)만 읽으므로, 워치 실측을
// 반영하려면 누군가 SleepSync.sync() 를 호출해 줘야 한다. 이 헬퍼가 화면 진입
// 시점에 그 호출을 "하루 1회" throttle 로 대신한다.
//
// 동작:
//   1. 마지막 시도 후 [minInterval] 이내면 skip (SDK/권한팝업 과호출 방지).
//   2. 시도 시각을 먼저 기록 → 실패해도 같은 창에서 재시도하지 않음.
//   3. 삼성헬스 미설치면 skip, 권한 없으면 1회 요청 → 동의되면 sync(30일).
//   4. fire-and-forget — sync 가 DB 를 upsert 하면 watchRecent 스트림이
//      자동 emit 하여 화면이 새 데이터로 rebuild 된다.

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'samsung_health_service.dart';
import 'sleep_sync.dart';

class SleepAutoSync {
  SleepAutoSync(this._svc, this._sync);

  final SamsungHealthService _svc;
  final SleepSync _sync;

  static const _kLastAttempt = 'sleep_auto_sync_last_ms';

  /// 하루 1회 수준 — 마지막 시도 후 이 시간 이내면 동기화 skip.
  /// 12h 로 두면 저녁 진입 + 다음날 아침 진입에서 각각 1회씩 → 지난밤 데이터를
  /// 아침에 놓치지 않으면서도 SDK 과호출/권한팝업을 막는다.
  static const minInterval = Duration(hours: 12);

  /// 조건 충족 시 백그라운드 동기화 1회.
  /// 반환: 저장한 밤 수(>=0), skip / 미설치 / 권한거부 / 실패 시 null.
  Future<int?> maybeSync() async {
    final prefs = await SharedPreferences.getInstance();

    final lastMs = prefs.getInt(_kLastAttempt);
    if (lastMs != null) {
      final last = DateTime.fromMillisecondsSinceEpoch(lastMs);
      if (DateTime.now().difference(last) < minInterval) {
        if (kDebugMode) debugPrint('[SleepAutoSync] skip — throttled');
        return null;
      }
    }
    // 시도 시각 먼저 기록 (실패해도 throttle 적용).
    await prefs.setInt(_kLastAttempt, DateTime.now().millisecondsSinceEpoch);

    try {
      if (!await _svc.isAvailable()) {
        if (kDebugMode) debugPrint('[SleepAutoSync] skip — 삼성헬스 미설치');
        return null;
      }
      var granted = await _svc.hasPermissions();
      if (!granted) granted = await _svc.requestPermissions();
      if (!granted) {
        if (kDebugMode) debugPrint('[SleepAutoSync] skip — 권한 거부');
        return null;
      }
      final saved = await _sync.sync(days: 30);
      if (kDebugMode) debugPrint('[SleepAutoSync] 동기화 완료 — $saved 밤 저장');
      return saved;
    } catch (e) {
      // 권한/네트워크/SDK 예외 — 화면엔 영향 없이 조용히 무시.
      if (kDebugMode) debugPrint('[SleepAutoSync] 실패 — $e');
      return null;
    }
  }

  /// 다음 진입 때 즉시 다시 동기화하도록 throttle 리셋 (수동 새로고침/테스트용).
  Future<void> resetThrottle() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kLastAttempt);
  }
}
