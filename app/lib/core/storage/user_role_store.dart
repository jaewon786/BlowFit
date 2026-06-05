import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 앱 사용 역할. 첫 실행 시 선택하며 **변경 불가** (clear 는 개발/리셋용).
///   - deviceUser : 디바이스를 직접 쓰는 훈련 당사자 (기존 전체 화면).
///   - companion  : 디바이스를 안 쓰는 동반자(배우자·애인). 사용자의 훈련
///                  현황을 보고 '눈치주기'로 알림을 보내는 전용 화면.
enum AppRole {
  deviceUser('device_user'),
  companion('companion');

  const AppRole(this.code);
  final String code;

  static AppRole? fromCode(String? c) => switch (c) {
        'device_user' => AppRole.deviceUser,
        'companion' => AppRole.companion,
        _ => null,
      };
}

/// 라우터(go_router)가 동기적으로 역할을 읽을 수 있도록 메모리에 보관하는
/// 전역 notifier. main() 에서 부팅 시 1회 로드하고, 역할 선택 시 갱신한다.
/// go_router 의 refreshListenable 로 연결돼 값이 바뀌면 redirect 가 재평가됨.
final appRoleNotifier = ValueNotifier<AppRole?>(null);

/// 역할 영속화 (SharedPreferences). 다른 store 들과 동일 패턴.
class UserRoleStore {
  UserRoleStore(this._prefs);

  static const _kRole = 'app_role';

  final SharedPreferences _prefs;

  static Future<UserRoleStore> open() async {
    final prefs = await SharedPreferences.getInstance();
    return UserRoleStore(prefs);
  }

  /// 미선택이면 null.
  AppRole? load() => AppRole.fromCode(_prefs.getString(_kRole));

  /// 선택 저장 + 전역 notifier 갱신 (라우터 redirect 트리거).
  Future<void> save(AppRole role) async {
    await _prefs.setString(_kRole, role.code);
    appRoleNotifier.value = role;
  }

  /// 개발/데이터 초기화용 — 정상 흐름에선 호출하지 않음 (역할 변경 불가).
  Future<void> clear() async {
    await _prefs.remove(_kRole);
    appRoleNotifier.value = null;
  }
}
