import 'package:shared_preferences/shared_preferences.dart';

/// 디자인 v2 의 02 화면 (`profile-setup.jsx`) 에서 입력받는 사용자 프로필을
/// 영속화. SharedPreferences 기반 — 의료 정보 수준이 아니라서 SQLite 까지
/// 가지 않음.
///
/// 처음 사용자는 `load()` 가 null 을 반환 → 온보딩 → ProfileSetup → Pairing
/// 흐름 진입. 두 번째 실행부터는 ProfileSetup 을 건너뛰고 곧장 Pairing 으로
/// 갈 수 있도록 하는 게 자연스러우나, 현재 Phase 는 디자인 적용까지만이라
/// 라우팅 로직은 기존 (Onboarding → ProfileSetup → Pairing) 그대로.
class UserProfileStore {
  UserProfileStore(this._prefs);

  static const _kName = 'user_profile_name';
  static const _kAge = 'user_profile_age';
  static const _kGender = 'user_profile_gender';
  static const _kStartedAt = 'user_profile_started_at';

  final SharedPreferences _prefs;

  static Future<UserProfileStore> open() async {
    final prefs = await SharedPreferences.getInstance();
    return UserProfileStore(prefs);
  }

  /// 한 필드라도 비어있으면 null. UI 는 null 시 placeholder ('이름을
  /// 설정해주세요') 를 보여주거나 onboarding flow 로 보낸다.
  UserProfile? load() {
    final name = _prefs.getString(_kName);
    final age = _prefs.getInt(_kAge);
    final gender = _prefs.getString(_kGender);
    if (name == null || age == null || gender == null) return null;
    final startedIso = _prefs.getString(_kStartedAt);
    return UserProfile(
      name: name,
      age: age,
      gender: UserGender.fromCode(gender),
      startedAt: startedIso != null ? DateTime.tryParse(startedIso) : null,
    );
  }

  Future<void> save(UserProfile profile) async {
    await _prefs.setString(_kName, profile.name);
    await _prefs.setInt(_kAge, profile.age);
    await _prefs.setString(_kGender, profile.gender.code);
    final started = profile.startedAt ?? DateTime.now();
    await _prefs.setString(_kStartedAt, started.toIso8601String());
  }

  Future<void> clear() async {
    await _prefs.remove(_kName);
    await _prefs.remove(_kAge);
    await _prefs.remove(_kGender);
    await _prefs.remove(_kStartedAt);
  }
}

class UserProfile {
  final String name;
  final int age;
  final UserGender gender;

  /// 첫 ProfileSetup 저장 시점 — Profile 화면 '12주차' 자동 계산용.
  final DateTime? startedAt;

  const UserProfile({
    required this.name,
    required this.age,
    required this.gender,
    this.startedAt,
  });

  @override
  bool operator ==(Object other) =>
      other is UserProfile &&
      other.name == name &&
      other.age == age &&
      other.gender == gender &&
      other.startedAt == startedAt;

  @override
  int get hashCode => Object.hash(name, age, gender, startedAt);
}

/// 디자인의 3-칼럼 세그먼트: 남성 / 여성 / 선택 안함.
enum UserGender {
  male('M', '남성'),
  female('F', '여성'),
  none('N', '선택 안함');

  const UserGender(this.code, this.label);
  final String code;
  final String label;

  static UserGender fromCode(String code) {
    return switch (code) {
      'M' => UserGender.male,
      'F' => UserGender.female,
      _ => UserGender.none,
    };
  }
}
