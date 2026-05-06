// Rive 수달 캐릭터 위젯 — 호흡 + 성장에 반응하는 메인 비주얼.
//
// `assets/character/otter.riv` 가 등록되어 있고 로드 가능하면 Rive 애니메이션
// 으로 렌더링. 디자이너 산출물이 아직 없거나 로드가 실패하면 [fallback] 위젯
// 을 대신 보여줌 (없으면 빈 SizedBox).
//
// Rive 측 계약 (디자이너 합의):
//   - State Machine 이름: `BreathingState` (생성자 파라미터로 override 가능)
//   - Inputs:
//       pressure       (Number)  — BLE 호기 압력 (cmH₂O), 0~30 typical
//       targetReached  (Bool)    — 목표 구간 진입 여부
//       sessionState   (Number)  — SessionState.index (0=idle / 1=active / 2=complete)
//       growthStage    (Number)  — GrowthStage.index (0=baby / 1=young / 2=adult / 3=master)
//
// Inputs 중 일부가 .riv 에 없어도 위젯은 정상 동작 (해당 input 만 무시).
// 흡기(음압) 데이터는 차후 차압 센서 도입 후 pressure 가 음수로 들어올 예정.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:rive/rive.dart';

import 'growth_stage.dart';

/// 세션 진행 상태 — Rive `sessionState` 입력에 매핑.
/// 펌웨어 `DeviceStateCode` → 이 enum 매핑은 호출처(training_screen)에서 처리.
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
    required this.pressure,
    required this.targetReached,
    required this.sessionState,
    required this.stage,
    this.fallback,
    this.assetPath = 'assets/character/otter.riv',
    this.stateMachineName = 'BreathingState',
  });

  /// 현재 호기 압력 (cmH₂O). 흡기 차후 활성화 시 음수도 허용.
  final double pressure;

  /// 목표 구간 진입 여부 (예: 20~30 cmH₂O).
  final bool targetReached;

  /// 세션 단계 — idle / active / complete.
  final SessionState sessionState;

  /// 12주 성장 단계 — baby / young / adult / master.
  final GrowthStage stage;

  /// `.riv` 가 없거나 로드 실패 시 보여줄 대체 위젯. null 이면 빈 SizedBox.
  /// 통상 BreathOrb 같은 기존 호흡 애니메이션을 주입.
  final Widget? fallback;

  /// 에셋 경로 — 테스트 / 다른 캐릭터 디버그용 override 가능.
  final String assetPath;

  /// State Machine 이름.
  final String stateMachineName;

  @override
  State<OtterCharacter> createState() => _OtterCharacterState();
}

class _OtterCharacterState extends State<OtterCharacter> {
  Future<bool>? _loadProbe;
  StateMachineController? _controller;
  SMINumber? _pressureInput;
  SMIBool? _targetReachedInput;
  SMINumber? _sessionStateInput;
  SMINumber? _growthStageInput;

  @override
  void initState() {
    super.initState();
    _loadProbe = _probeAsset();
  }

  /// 에셋 존재/로드 가능 여부 사전 체크 — Rive 위젯이 직접 throw 하기 전에
  /// fallback 으로 분기하기 위함.
  Future<bool> _probeAsset() async {
    try {
      await rootBundle.load(widget.assetPath);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// `RiveAnimation` 로드 직후 — State Machine + inputs 바인딩.
  void _onRiveInit(Artboard artboard) {
    final ctrl = StateMachineController.fromArtboard(
      artboard,
      widget.stateMachineName,
    );
    if (ctrl == null) {
      // State Machine 이름 불일치 — fallback 으로 떨어지지는 않고 그냥
      // 정적 artboard 로 보여줌. 디자이너와 이름 합의 필요.
      return;
    }
    artboard.addController(ctrl);
    _controller = ctrl;
    _pressureInput = ctrl.findInput<double>('pressure') as SMINumber?;
    _targetReachedInput = ctrl.findInput<bool>('targetReached') as SMIBool?;
    _sessionStateInput = ctrl.findInput<double>('sessionState') as SMINumber?;
    _growthStageInput = ctrl.findInput<double>('growthStage') as SMINumber?;
    _syncInputs();
  }

  /// 위젯 prop → Rive input 동기화. input 이 없으면 no-op.
  void _syncInputs() {
    _pressureInput?.value = widget.pressure;
    _targetReachedInput?.value = widget.targetReached;
    _sessionStateInput?.value = widget.sessionState.index.toDouble();
    _growthStageInput?.value = widget.stage.index.toDouble();
  }

  @override
  void didUpdateWidget(covariant OtterCharacter old) {
    super.didUpdateWidget(old);
    _syncInputs();
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _loadProbe,
      builder: (context, snap) {
        final loaded = snap.data ?? false;
        if (!loaded) {
          // 로딩 중 / 실패 / asset 없음 — 모두 fallback. 깜빡임 방지.
          return widget.fallback ?? const SizedBox.shrink();
        }
        return RiveAnimation.asset(
          widget.assetPath,
          fit: BoxFit.contain,
          onInit: _onRiveInit,
        );
      },
    );
  }
}
