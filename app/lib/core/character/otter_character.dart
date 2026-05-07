// 호흡 캐릭터 위젯 — Rive 캐릭터 자체에 모든 비주얼 (캐릭터 + 풍선) 포함.
//
// 현재 [assetPath] 기본값은 임시 placeholder `seal.riv` (Rive Marketplace 의
// Sappy seal — 물개가 풍선껌 부는 idle 애니메이션 포함). 풍선까지 .riv 안에
// 그려져 있으므로 Flutter 측에서 추가 오버레이 없음.
//
// rive 0.14.x API:
//   File.asset(path, riveFactory: Factory.flutter) — 비동기 로드 (nullable)
//   RiveWidgetController(file) — 기본 artboard + 기본 state machine
//   RiveWidget(controller: ctrl, fit: Fit.contain) — 렌더
//   file.dispose() + controller.dispose() — 위젯 dispose 시 호출 필수
//
// .riv 가 없거나 로딩 실패하면 [fallback] 위젯으로 안전 분기 (예: BreathOrb).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rive/rive.dart';

import 'growth_stage.dart';

/// Rive 에셋 경로 — 테스트가 빈 문자열 또는 미존재 경로로 override 하면
/// OtterCharacter 가 fallback 으로 안전 분기.
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

  /// 차후 입력 wiring 시 사용. 현재는 기본 state machine 사용 (StateMachineDefault).
  final String stateMachineName;

  @override
  State<OtterCharacter> createState() => _OtterCharacterState();
}

class _OtterCharacterState extends State<OtterCharacter> {
  File? _riveFile;
  RiveWidgetController? _controller;

  @override
  void initState() {
    super.initState();
    _loadRive();
  }

  /// rive 0.14 API: File.asset → RiveWidgetController. 에러 시 _controller
  /// 가 null 로 남아 build 에서 fallback 분기.
  Future<void> _loadRive() async {
    if (widget.assetPath.isEmpty) return;
    try {
      final file = await File.asset(
        widget.assetPath,
        riveFactory: Factory.flutter,
      );
      if (file == null) {
        debugPrint('OtterCharacter: .riv decoded as null');
        return;
      }
      final controller = RiveWidgetController(file);
      if (!mounted) {
        controller.dispose();
        file.dispose();
        return;
      }
      setState(() {
        _riveFile = file;
        _controller = controller;
      });
    } catch (e) {
      debugPrint('OtterCharacter: .riv load failed → $e');
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    _riveFile?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    if (controller != null) {
      // 투명 배경 — 부모의 TimeBackground 그라데이션이 그대로 보임. 캐릭터
      // 몸통이 흰색에 가까워서 흰 backdrop 을 깔면 가려지는 문제 해결.
      return RiveWidget(
        controller: controller,
        fit: Fit.contain,
      );
    }
    // 로딩 중 / 실패 / asset 없음 — 모두 fallback (없으면 빈 SizedBox).
    return widget.fallback ?? const SizedBox.shrink();
  }
}
