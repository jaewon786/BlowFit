// Kirby.riv 캐릭터 — Idle / Exhale (걷기) / Inhale (별 먹기) 상태머신.
//
// Rive 0.14 API + ViewModel data binding 우선, 실패 시 state machine input
// 폴백. Kirby.riv 내부 스펙:
//   - StateMachine: BreathingSM
//   - ViewModel: ViewModel1 (Instance)
//   - Properties / Inputs: isExhaling (bool), isInhaling (bool), pressure (num)
//
// 외부에서 [phase] + [pressure] 를 prop 으로 주면 적절한 SM 상태로 전환.

import 'package:flutter/material.dart';
import 'package:rive/rive.dart' as rive;

/// 외부에서 의도하는 캐릭터 동작 단계.
enum KirbyPhase {
  /// 호흡 안 함 / 목표 zone 밖 — Idle 애니메이션.
  idle,

  /// 호기 (양압) 목표 zone 안 — 걷기 애니메이션 + 배경 스크롤 트리거.
  exhale,

  /// 흡기 (음압) 목표 zone 안 — 별 먹기 애니메이션.
  inhale,
}

class KirbyCharacter extends StatefulWidget {
  const KirbyCharacter({
    super.key,
    required this.phase,
    required this.pressure,
    this.assetPath = 'assets/character/kirby.riv',
  });

  /// 현재 캐릭터 동작 단계.
  final KirbyPhase phase;

  /// 현재 압력값 (cmH₂O). Kirby.riv 의 pressure 프로퍼티 / 인풋에 그대로 전달.
  /// 단, Q3 (호기/흡기 시간 분할) 정책에 따라 흡기 phase 일 때 호출자가 음수로
  /// 뒤집어서 넣어준다.
  final double pressure;

  final String assetPath;

  @override
  State<KirbyCharacter> createState() => _KirbyCharacterState();
}

class _KirbyCharacterState extends State<KirbyCharacter> {
  rive.File? _file;
  rive.RiveWidgetController? _controller;

  // Data-binding 경로 핸들 (있으면 사용, 없으면 null).
  rive.ViewModelInstanceBoolean? _vmExhale;
  rive.ViewModelInstanceBoolean? _vmInhale;
  rive.ViewModelInstanceNumber? _vmPressure;

  // SM input 폴백.
  // ignore: deprecated_member_use
  rive.BooleanInput? _smExhale;
  // ignore: deprecated_member_use
  rive.BooleanInput? _smInhale;
  // ignore: deprecated_member_use
  rive.NumberInput? _smPressure;

  String? _loadError;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final file = await rive.File.asset(
        widget.assetPath,
        riveFactory: rive.Factory.flutter,
      );
      if (file == null) {
        if (mounted) {
          setState(() => _loadError = '${widget.assetPath} 디코딩 실패');
        }
        return;
      }
      if (!mounted) {
        file.dispose();
        return;
      }
      final controller = rive.RiveWidgetController(file);

      // 1) ViewModel auto-bind 시도.
      try {
        final vmi = controller.dataBind(rive.DataBind.auto());
        _vmExhale = vmi.boolean('isExhaling');
        _vmInhale = vmi.boolean('isInhaling');
        _vmPressure = vmi.number('pressure');
      } catch (_) {
        // VM 없거나 default instance 미설정 — SM input 폴백.
      }

      // 2) SM input 폴백 — VM 핸들이 하나도 못 잡힌 경우에만.
      if (_vmExhale == null && _vmInhale == null && _vmPressure == null) {
        // ignore: deprecated_member_use
        _smExhale = controller.stateMachine.boolean('isExhaling');
        // ignore: deprecated_member_use
        _smInhale = controller.stateMachine.boolean('isInhaling');
        // ignore: deprecated_member_use
        _smPressure = controller.stateMachine.number('pressure');
      }

      setState(() {
        _file = file;
        _controller = controller;
      });
      _applyPhase();
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadError = e.toString());
    }
  }

  void _applyPhase() {
    final isExhale = widget.phase == KirbyPhase.exhale;
    final isInhale = widget.phase == KirbyPhase.inhale;
    final p = widget.pressure;

    // VM 우선
    _vmExhale?.value = isExhale;
    _vmInhale?.value = isInhale;
    _vmPressure?.value = p;

    // SM 폴백
    if (_smExhale != null) _smExhale!.value = isExhale;
    if (_smInhale != null) _smInhale!.value = isInhale;
    if (_smPressure != null) _smPressure!.value = p;
  }

  @override
  void didUpdateWidget(covariant KirbyCharacter oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.phase != oldWidget.phase ||
        widget.pressure != oldWidget.pressure) {
      _applyPhase();
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    _file?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loadError != null) {
      return _ErrorPlaceholder(message: _loadError!);
    }
    final c = _controller;
    if (c == null) {
      return const SizedBox.shrink();
    }
    return rive.RiveWidget(
      controller: c,
      fit: rive.Fit.contain,
    );
  }
}

class _ErrorPlaceholder extends StatelessWidget {
  const _ErrorPlaceholder({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Text(
          'Kirby.riv 로드 실패\n$message',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 11, color: Colors.redAccent),
        ),
      ),
    );
  }
}
