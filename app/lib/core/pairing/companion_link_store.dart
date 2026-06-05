import 'package:shared_preferences/shared_preferences.dart';

/// 동반자가 연결한 디바이스 사용자 정보 (로컬 캐시).
/// Firestore `links/{companionUid}` 와 별개로, UI 가 빠르게 참조하도록
/// SharedPreferences 에 저장한다.
class CompanionLinkStore {
  CompanionLinkStore(this._prefs);

  static const _kUserId = 'companion_linked_user_id';
  static const _kUserName = 'companion_linked_user_name';

  final SharedPreferences _prefs;

  static Future<CompanionLinkStore> open() async {
    final prefs = await SharedPreferences.getInstance();
    return CompanionLinkStore(prefs);
  }

  CompanionLink? load() {
    final id = _prefs.getString(_kUserId);
    final name = _prefs.getString(_kUserName);
    if (id == null || name == null) return null;
    return CompanionLink(userId: id, userName: name);
  }

  Future<void> save(CompanionLink link) async {
    await _prefs.setString(_kUserId, link.userId);
    await _prefs.setString(_kUserName, link.userName);
  }

  Future<void> clear() async {
    await _prefs.remove(_kUserId);
    await _prefs.remove(_kUserName);
  }
}

class CompanionLink {
  final String userId;
  final String userName;
  const CompanionLink({required this.userId, required this.userName});
}
