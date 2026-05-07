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
final characterAssetPathProvider = Provider<String>((ref) {
  return 'assets/character/seal.riv';
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
  /// 분기. `RiveAnimation.asset` 가 build 도중 throw 하는 케이스를 막기 위함
  /// (특히 test env 의 asset 환경 차이).
  /// `assetPath` 가 비어 있으면 즉시 종료 (테스트가 Rive 우회용으로 쓸 수 있음).
  Future<void> _loadRive() async {
    if (widget.assetPath.isEmpty) return;
    try {
      final file = await RiveFile.asset(widget.assetPath);
      final artboard = file.mainArtboard.instance();
      final ctrl = StateMachineController.fromArtboard(
        artboard,
        widget.stateMachineName,
      );
      if (ctrl != null) artboard.addController(ctrl);
      if (!mounted) return;
      setState(() => _artboard = artboard);
    } catch (_) {
      // _artboard 그대로 null → build 에서 fallback 렌더.
    }
  }

  @override
  Widget build(BuildContext context) {
    final artboard = _artboard;
    if (artboard != null) {
      return Rive(artboard: artboard, fit: BoxFit.contain);
    }
    // 로딩 중 / 실패 / asset 없음 — 모두 fallback (없으면 빈 SizedBox).
    return widget.fallback ?? const SizedBox.shrink();
  }
}
