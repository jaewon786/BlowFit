import 'package:shared_preferences/shared_preferences.dart';

/// 캐릭터 진화 상태 영속화.
///
/// - shownLevel  : 현재 화면에 *표시 중*인 진화 단계 (1=Egg, 2=Baby, 3=Oxygen).
///   누적 훈련일이 임계(7·30)를 넘으면 bloom 재생 후 1씩 올라간다. 표시 단계를
///   따로 저장하는 이유는, 누적일에서 파생된 "목표 단계"가 표시 단계보다 커지는
///   순간을 감지해 진화(bloom) 모션을 *1회만* 재생하기 위해서다.
/// - seenSessions: 마지막으로 happy 를 띄운 시점의 누적 세션 수. 세션 수가 이보다
///   커지면 새 세션이 완료된 것 → happy 1회. -1 은 "아직 baseline 미설정"으로,
///   첫 관측 시 현재 값으로만 맞추고 happy 는 띄우지 않는다(앱 재설치/첫 실행 시
///   기존 세션으로 happy 가 오발사되는 것 방지).
class CharacterStageStore {
  CharacterStageStore(this._prefs);

  static const _kShownLevel = 'character_shown_level';
  static const _kSeenSessions = 'character_seen_sessions';

  final SharedPreferences _prefs;

  static Future<CharacterStageStore> open() async {
    final prefs = await SharedPreferences.getInstance();
    return CharacterStageStore(prefs);
  }

  /// 표시 중인 단계 레벨 (1~3). 기본 1(Egg).
  int loadShownLevel() => _prefs.getInt(_kShownLevel) ?? 1;

  Future<void> saveShownLevel(int level) =>
      _prefs.setInt(_kShownLevel, level);

  /// 마지막 happy 기준 누적 세션 수. -1 = baseline 미설정.
  int loadSeenSessions() => _prefs.getInt(_kSeenSessions) ?? -1;

  Future<void> saveSeenSessions(int count) =>
      _prefs.setInt(_kSeenSessions, count);
}
