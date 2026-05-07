// 호흡 캐릭터 위젯 — Rive 캐릭터 + 호기/흡기 압력 기반 애니메이션 전환.
//
// seal.riv 가 다음 3개 standalone animation 노출:
//   Idle        — 평소 (호흡 멈춤 또는 약한 호흡)
//   Exhalation  — 호기 (pressure > +threshold)
//   inhalation  — 흡기 (pressure < -threshold, 차후 차압 센서 활성화 후)
//
// 커스텀 [_BreathingAnimationPainter] 가 매 frame `_phase` 에 해당하는
// animation 을 advanceAndApply. State Machine 은 사용 안 함 (BreathingSM
// 에 호흡 input 이 노출되지 않아 직접 animation 전환이 더 깔끔).
//
// .riv 가 없거나 로딩 실패하면 [fallback] 위젯으로 안전 분기 (예: BreathOrb).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rive/rive.dart' as rive;

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

/// 호흡 phase — pressure 값에서 도출.
enum _BreathPhase { idle, exhale, inhale }

/// pressure 절대값 < `_pressureThreshold` 면 호흡 정지로 간주.
const double _pressureThreshold = 5.0;

class OtterCharacter extends StatefulWidget {
  const OtterCharacter({
    super.key,
    required this.pressure,
    required this.targetReached,
    required this.sessionState,
    required this.stage,
    this.fallback,
    this.assetPath = 'assets/character/seal.riv',
  });

  /// 현재 호흡 압력 (cmH₂O). 양수 = 호기, 음수 = 흡기, |값| < 5 = 정지.
  final double pressure;

  /// 목표 구간 진입 여부 — 차후 .riv 의 celebrate state 트리거용.
  final bool targetReached;

  /// 세션 단계 — idle / active / complete.
  final SessionState sessionState;

  /// 12주 성장 단계 — baby / young / adult / master.
  final GrowthStage stage;

  /// `.riv` 가 없거나 로드 실패 시 보여줄 대체 위젯. null 이면 빈 SizedBox.
  final Widget? fallback;

  final String assetPath;

  @override
  State<OtterCharacter> createState() => _OtterCharacterState();
}

class _OtterCharacterState extends State<OtterCharacter> {
  rive.File? _riveFile;
  rive.Artboard? _artboard;
  late final _BreathingAnimationPainter _painter;

  @override
  void initState() {
    super.initState();
    _painter = _BreathingAnimationPainter(
      fit: rive.Fit.contain,
      alignment: Alignment.center,
    );
    _loadRive();
  }

  /// rive 0.14 API: File.asset → 기본 artboard. 에러 시 _artboard null →
  /// build 에서 fallback 분기.
  Future<void> _loadRive() async {
    if (widget.assetPath.isEmpty) return;
    try {
      final file = await rive.File.asset(
        widget.assetPath,
        riveFactory: rive.Factory.flutter,
      );
      if (file == null) {
        debugPrint('OtterCharacter: .riv decoded as null');
        return;
      }
      final artboard = file.defaultArtboard();
      if (artboard == null) {
        debugPrint('OtterCharacter: .riv has no default artboard');
        file.dispose();
        return;
      }
      if (!mounted) {
        artboard.dispose();
        file.dispose();
        return;
      }
      setState(() {
        _riveFile = file;
        _artboard = artboard;
      });
    } catch (e) {
      debugPrint('OtterCharacter: .riv load failed → $e');
    }
  }

  @override
  void didUpdateWidget(covariant OtterCharacter oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncPhase();
  }

  /// pressure → _phase 매핑. 양압 호기 / 그 외 모두 흡기.
  /// 흡기 하드웨어가 없는 동안 "호흡 멈춤" 도 흡기 애니메이션으로 표시 →
  /// 사용자에게 자연스러운 들숨↔날숨 사이클 시뮬레이션.
  void _syncPhase() {
    final p = widget.pressure;
    final next = p > _pressureThreshold
        ? _BreathPhase.exhale
        : _BreathPhase.inhale;
    _painter.phase = next;
  }

  @override
  void dispose() {
    _painter.dispose();
    _artboard?.dispose();
    _riveFile?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final artboard = _artboard;
    if (artboard != null) {
      _syncPhase();
      // Transform.translate 로 물리적 시프트 — RiveWidget 의 alignment
      // 파라미터가 일부 케이스에서 적용 안 되는 이슈 회피. 40px 우측 이동.
      return Transform.translate(
        offset: const Offset(40, 0),
        child: rive.RiveArtboardWidget(
          artboard: artboard,
          painter: _painter,
        ),
      );
    }
    // 로딩 중 / 실패 / asset 없음 — 모두 fallback (없으면 빈 SizedBox).
    return widget.fallback ?? const SizedBox.shrink();
  }
}

/// 호기/흡기/idle 3개 animation 사이를 [phase] 값에 따라 전환하는 painter.
/// rive 0.14 의 [rive.BasicArtboardPainter] 확장 — 매 frame `advance` 가
/// 현재 phase 의 animation 을 advanceAndApply. State Machine 사용 안 함.
base class _BreathingAnimationPainter extends rive.BasicArtboardPainter {
  _BreathingAnimationPainter({
    super.fit,
    super.alignment,
  });

  rive.Animation? _idleAnim;
  rive.Animation? _exhaleAnim;
  rive.Animation? _inhaleAnim;
  _BreathPhase _phase = _BreathPhase.idle;

  set phase(_BreathPhase value) {
    if (_phase != value) {
      _phase = value;
      // 새 phase 의 animation 을 time = 0 에서 재시작. 이전 재생이 끝까지
      // 갔으면 (One Shot) time 이 duration 에 멈춰 있어 재진입 시 진행
      // 안 함 → 매 phase 전환 시 강제 리셋해 자연스러운 재생.
      final newAnim = switch (value) {
        _BreathPhase.idle => _idleAnim,
        _BreathPhase.exhale => _exhaleAnim,
        _BreathPhase.inhale => _inhaleAnim,
      };
      if (newAnim != null) {
        newAnim.time = 0;
      }
    }
  }

  @override
  void artboardChanged(rive.Artboard artboard) {
    super.artboardChanged(artboard);
    // .riv 의 animation 이름 정확히 매칭 — 디자이너 합의:
    //   'Idle', 'Exhalation', 'inhalation' (i 소문자 주의).
    _idleAnim = artboard.animationNamed('Idle');
    _exhaleAnim = artboard.animationNamed('Exhalation');
    _inhaleAnim = artboard.animationNamed('inhalation');
    notifyListeners();
  }

  @override
  bool advance(double elapsedSeconds) {
    final anim = switch (_phase) {
      _BreathPhase.idle => _idleAnim,
      _BreathPhase.exhale => _exhaleAnim,
      _BreathPhase.inhale => _inhaleAnim,
    };
    if (anim == null) return false;
    // advanceAndApply 가 false 반환 = 애니메이션 끝남 (One Shot).
    // 같은 phase 가 유지되는 동안 화면이 멈추지 않도록 강제 loop —
    // time=0 으로 리셋해 다음 frame 부터 처음부터 재생.
    final stillRunning = anim.advanceAndApply(elapsedSeconds);
    if (!stillRunning) {
      anim.time = 0;
    }
    return true;
  }
}
