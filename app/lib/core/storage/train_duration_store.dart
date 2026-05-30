import 'package:shared_preferences/shared_preferences.dart';

/// Train 세션 길이(분)를 영속화. 설정 화면에서 사용자가 선택하고, 연결 시
/// 기기로 SET_DURATION 전송. 기기(session.cpp)가 실제 진실의 원천이지만 앱
/// 재시작 후에도 선택값을 유지하기 위한 캐시.
class TrainDurationStore {
  TrainDurationStore(this._prefs);

  static const _kMinutes = 'train_duration_min';

  static const defaultMinutes = 5;

  /// 선택 가능한 훈련 시간(분) 목록.
  static const options = <int>[3, 5, 10, 15, 20];

  final SharedPreferences _prefs;

  static Future<TrainDurationStore> open() async {
    final prefs = await SharedPreferences.getInstance();
    return TrainDurationStore(prefs);
  }

  /// 저장된 훈련 시간(분). 없으면 기본 10분.
  int loadMinutes() => _prefs.getInt(_kMinutes) ?? defaultMinutes;

  Future<void> save(int minutes) => _prefs.setInt(_kMinutes, minutes);
}
