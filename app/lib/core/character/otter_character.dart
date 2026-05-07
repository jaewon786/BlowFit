// 호흡 캐릭터 위젯 — Rive 캐릭터 자체에 모든 비주얼 (캐릭터 + 풍선) 포함.
//
// 현재 [assetPath] 기본값은 임시 placeholder `seal.riv` (Rive Marketplace 의
// Sappy seal — 물개가 풍선껌 부는 idle 애니메이션 포함). 풍선까지 .riv 안에
// 그려져 있으므로 Flutter 측에서 추가 오버레이 없음.
//
// 차후 풍선 size 를 호흡 압력에 비례하게 만들고 싶으면, 디자이너가 .riv 의
// State Machine 에 Number input (예: `balloonSize`) 을 노출 → 여기서 wiring.
//
// .riv 가 없거나 로딩 실패하면 [fallback] 위젯으로 안전 분기 (예: BreathOrb).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rive/rive.dart';

import 'growth_stage.dart';

/// Rive 에셋 경로 — 테스트가 빈 문자열 또는 미존재 경로로 override 하면
/// OtterCharacter 가 fallback 으로 안전 분기. 비동기 RiveFile 파싱 에러가
/// 테스트 framework 로 전파되는 것을 방지.
///
/// 현재 빈 문자열 — seal.riv 가 rive 0.13 에서 paint-time RangeError 를
/// 일으키는 호환성 이슈로 임시 우회. BreathOrb fallback 만 표시. .riv 가
/// 단순화되거나 rive 0.14 API 로 마이그레이션 후 복원.
final characterAssetPathProvider = Provider<String>((ref) {
  return ''; // 임시 우회 — Rive 호환성 이슈, BreathOrb fallback 사용
});

/// 세션 진행 상태 — 차후 .riv 의 sessionState input 으로 매핑할 enum.
/// 펌웨어 `DeviceStateCode` 와의 매핑은 호출처에서 처리.
enum SessionState {
  /// 0 — 세션 안 함 (BOOT/STANDBY).
  idle,

  /// 1 — 세션 진행 중 (PREP/TRAIN/REST).
  active,

  /// 2 — 세션 완료 (SUMMARY).
  complete,
}

class OtterCharacter extends StatefulWidget {
  const OtterCharacter({
    super.key,
    required this.targetReached,
    required this.sessionState,
    required this.stage,
    this.fallback,
    this.assetPath = 'assets/character/seal.riv',
    this.stateMachineName = 'BreathingSM',
  });

  /// 목표 구간 진입 여부 — 차후 .riv 의 celebrate state 트리거용.
  final bool targetReached;

  /// 세션 단계 — idle / active / complete.
  final SessionState sessionState;

  /// 12주 성장 단계 — baby / young / adult / master.
  final GrowthStage stage;

  /// `.riv` 가 없거나 로드 실패 시 보여줄 대체 위젯. null 이면 빈 SizedBox.
  final Widget? fallback;

  final String assetPath;
  final String stateMachineName;

  @override
  State<OtterCharacter> createState() => _OtterCharacterState();
}

class _OtterCharacterState extends State<OtterCharacter> {
  Artboard? _artboard;

  @override
  void initState() {
    super.initState();
    _loadRive();
  }

  /// `.riv` 직접 파싱 — 에러 시 _artboard 가 null 로 남아 fallback 으로 안전
  /// 분기. State Machine 우회 — SimpleAnimation 으로 'Idle' (또는 첫
  /// animation) 만 재생. 일부 .riv (예: 호버/클릭 인터랙션 포함) 의 SM
  /// 멀티 레이어 구조가 rive 패키지에서 RangeError 를 일으키는 경우 회피.
  /// 현재 우리 use case 에선 SM input wiring 이 없어 이 단순화로 충분.
  /// `assetPath` 빈 문자열 → 즉시 종료 (테스트 우회용).
  Future<void> _loadRive() async {
    if (widget.assetPath.isEmpty) return;
    try {
      final file = await RiveFile.asset(widget.assetPath);
      final artboard = file.mainArtboard.instance();

      // 'Idle' animation 우선 검색 — 대소문자 무시. 없으면 첫 animation.
      if (artboard.animations.isNotEmpty) {
        final idle = artboard.animations.firstWhere(
          (a) => a.name.toLowerCase() == 'idle',
          orElse: () => artboard.animations.first,
        );
        artboard.addController(SimpleAnimation(idle.name));
      }

      if (!mounted) return;
      setState(() => _artboard = artboard);
    } catch (e) {
      debugPrint('OtterCharacter: .riv load failed → $e');
      // _artboard 그대로 null → build 에서 fallback 렌더.
    }
  }

  @override
  Widget build(BuildContext context) {
    final artboard = _artboard;
    if (artboard != null) {
      // ClipRRect — 부모 SizedBox 경계 강제. radius 24 로 둥글게 처리해서
      // .riv 의 자체 background fill 이 검정/흑색이라도 시각적으로 부드럽게
      // 분리됨.
      // ColoredBox(white) — Rive 가 일부만 칠하거나 background 가 비어 있을
      // 때를 대비해 흰 배경으로 채움. 사용자 보고 (검은 사각형) 회피.
      // Center — artboard 가 SizedBox 보다 작으면 가운데 정렬.
      return ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: ColoredBox(
          color: const Color(0xFFFFFFFF),
          child: Center(
            child: Rive(artboard: artboard, fit: BoxFit.contain),
          ),
        ),
      );
    }
    // 로딩 중 / 실패 / asset 없음 — 모두 fallback (없으면 빈 SizedBox).
    return widget.fallback ?? const SizedBox.shrink();
  }
}
