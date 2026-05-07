// 호흡 캐릭터 위젯 — Rive 캐릭터 (Idle 자동 재생) + Flutter 풍선 오버레이.
//
// 현재 [assetPath] 기본값은 임시 placeholder `seal.riv` (Rive Marketplace 의
// Sappy seal). 이 .riv 는 풍선 size 입력이 없어, 풍선은 Flutter 로 별도
// 오버레이 렌더링 (`balloonSize` prop 으로 크기 결정). 차후 디자이너가 풍선
// 까지 포함된 .riv 를 만들면:
//   1) assetPath 만 새 파일로 교체
//   2) Stack 의 _BalloonOverlay 제거
//   3) 새 .riv 의 Number input (예: `balloonSize`) 에 widget.balloonSize wiring
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
    required this.balloonSize,
    required this.targetReached,
    required this.sessionState,
    required this.stage,
    this.fallback,
    this.assetPath = 'assets/character/seal.riv',
    this.stateMachineName = 'BreathingSM',
  });

  /// 풍선 크기 (0~1). 호기 누적 → 1, 흡기 누적 → 0. accumulateBalloon 으로 계산.
  final double balloonSize;

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
  bool _loadFailed = false;

  @override
  void initState() {
    super.initState();
    _loadRive();
  }

  /// `.riv` 직접 파싱 — 에러 시 fallback 으로 안전 분기.
  /// `RiveAnimation.asset` 가 build 도중 throw 하는 케이스를 막기 위함
  /// (특히 test env 의 asset 환경 차이).
  /// `assetPath` 가 비어 있으면 즉시 fallback (테스트가 Rive 우회용으로 쓸 수 있음).
  Future<void> _loadRive() async {
    if (widget.assetPath.isEmpty) {
      if (!mounted) return;
      setState(() => _loadFailed = true);
      return;
    }
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
      if (!mounted) return;
      setState(() => _loadFailed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final Widget character;
    final artboard = _artboard;
    if (artboard != null) {
      character = Rive(artboard: artboard, fit: BoxFit.contain);
    } else if (_loadFailed) {
      character = widget.fallback ?? const SizedBox.shrink();
    } else {
      // 로딩 중 — fallback 보여주기 (없으면 빈 SizedBox).
      character = widget.fallback ?? const SizedBox.shrink();
    }
    return Stack(
      alignment: Alignment.center,
      children: [
        Positioned.fill(child: character),
        // 풍선 오버레이 — 캐릭터 우상단. balloonSize 비례로 크기 변화.
        Align(
          alignment: const Alignment(0.7, -0.8),
          child: _BalloonOverlay(size: widget.balloonSize),
        ),
      ],
    );
  }
}

/// 풍선 placeholder — Flutter Container 로 그린 분홍 원. 차후 풍선까지 포함된
/// .riv 가 도착하면 제거.
class _BalloonOverlay extends StatelessWidget {
  const _BalloonOverlay({required this.size});

  /// 0~1 사이의 정규화된 크기.
  final double size;

  @override
  Widget build(BuildContext context) {
    final clamped = size.clamp(0.0, 1.0);
    final diameter = 18.0 + clamped * 60.0; // 18~78px
    return AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOut,
      width: diameter,
      height: diameter,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFFFFB7C5).withValues(alpha: 0.85),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFF8A9A).withValues(alpha: 0.35),
            blurRadius: 12,
            spreadRadius: 1,
          ),
        ],
      ),
    );
  }
}
