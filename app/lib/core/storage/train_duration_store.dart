import 'package:shared_preferences/shared_preferences.dart';

/// Train 세션 길이(분)를 영속화. 설정 화면에서 사용자가 선택하고, 연결 시
/// 기기로 SET_DURATION 전송. 기기(session.cpp)가 실제 진실의 원천이지만 앱
/// 재시작 후에도 선택값을 유지하기 위한 캐시.
class TrainDurationStore {
  TrainDurationStore(this._prefs);

  static const _kMinutes = 'train_duration_min';

  /// 기본 5분 — 임상 표준 1 세션 = 10 breaths × 2 sets (약 5.5분 포함 휴식).
  /// 근거: Vranish & Bailey 2016 (5분/일), The Breather 공식 프로토콜.
  static const defaultMinutes = 5;

  /// 선택 가능한 훈련 시간(분) 목록 — 5분(1회) / 10분(2회 합산).
  /// 권장: 하루 1~2회.
  static const options = <int>[5, 10];

  final SharedPreferences _prefs;

  static Future<TrainDurationStore> open() async {
    final prefs = await SharedPreferences.getInstance();
    return TrainDurationStore(prefs);
  }

  /// 저장된 훈련 시간(분). 없으면 기본 10분.
  int loadMinutes() => _prefs.getInt(_kMinutes) ?? defaultMinutes;

  Future<void> save(int minutes) => _prefs.setInt(_kMinutes, minutes);
}
