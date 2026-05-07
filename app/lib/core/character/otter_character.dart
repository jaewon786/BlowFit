// 호흡 캐릭터 위젯 — Rive 캐릭터 + 호기/흡기 압력 기반 4-phase 애니메이션.
//
// seal.riv 가 다음 standalone animations 노출:
//   Exhalation         — 호기 액티브 (pressure > +threshold) → 풍선 커짐
//   Exhalation after   — 호기 직후 hold (캐릭터 idle 동작 + 풍선 max 유지)
//   inhalation         — 흡기 액티브 (휴리스틱: 호기 끝나면 자동) → 풍선 작아짐
//   Inhalation after   — 흡기 직후 / rest hold (캐릭터 idle + 풍선 min 유지)
//
// 흡기 센서가 없으므로 휴리스틱으로 흡기 시점 추정. 호기는 실제 압력 도달
// 시에만 재생됨 (자동 진행 안 함):
//   pressure > +5             → Exhalation       (풍선 커짐)
//   호기 직후 0.5초             → Exhalation after (풍선 max 유지, 캐릭터 모션)
//   호기 후 0.5~4.5초           → inhalation       (풍선 작아짐)
//   호기 후 4.5초+ / 첫 호기 전 → Inhalation after (풍선 min 유지, 캐릭터 모션)
//
// 액티브 phase (Exhalation/inhalation) — 한 번 재생 후 마지막 frame 에 멈춤.
// hold phase (Exhalation after/Inhalation after) — 끝까지 가면 loop (계속 모션).
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

/// 호흡 phase — painter 내부에서 압력 + 시간으로 결정.
enum _BreathPhase {
  /// 호기 중 — Exhalation 애니 진행.
  exhaling,

  /// 호기 직후 0.5초 — Exhalation 마지막 frame 유지.
  holdAfterExhale,

  /// 흡기 중 (휴리스틱) — inhalation 애니 진행.
  inhaling,

  /// 호흡 멈춤 또는 초기 상태 — 마지막 frame 유지.
  rest,
}

/// pressure 절대값 < `_pressureThreshold` (cmH₂O) 면 호기 아님.
const double _pressureThreshold = 5.0;

/// 호기 끝난 후 풍선이 잠시 유지되는 시간.
const double _holdAfterExhaleSec = 0.5;

/// 휴리스틱 흡기 phase 지속 시간 (호기 끝난 후 holdAfterExhaleSec 만큼 지나서부터).
const double _inhaleDurationSec = 4.0;

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

  /// 현재 호흡 압력 (cmH₂O). 양수 = 호기, |값|<5 = 정지.
  /// 음압 (흡기) 데이터는 차후 차압 센서 도입 후 활성화.
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
    _painter.pressure = widget.pressure;
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
      _painter.pressure = widget.pressure;
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
    return widget.fallback ?? const SizedBox.shrink();
  }
}

/// 호기/흡기 휴리스틱 phase machine + animation 적용 painter.
///
/// 매 frame `advance` 가 다음을 수행:
///   1) pressure 가 +threshold 초과면 호기 (exhaling)
///   2) 호기 직후 0.5초는 hold (exhale 마지막 frame 유지)
///   3) 호기 후 0.5~4.5초는 흡기 (inhaling, 휴리스틱)
///   4) 그 외엔 rest (마지막 frame 유지)
///
/// 활성 phase (exhaling/inhaling) 에서는 animation time 진행 + 끝나면 멈춤.
/// hold/rest phase 에서는 animation 을 advance 하지 않고 현재 time 의
/// frame 만 apply → 풍선 크기 유지, 캐릭터 모션도 정지.
base class _BreathingAnimationPainter extends rive.BasicArtboardPainter {
  _BreathingAnimationPainter({
    super.fit,
    super.alignment,
  });

  rive.Animation? _exhaleAnim;
  rive.Animation? _exhaleAfterAnim;
  rive.Animation? _inhaleAnim;
  rive.Animation? _inhaleAfterAnim;

  /// 현재 호흡 압력 (cmH₂O). 위젯이 prop 변경 시 setter 로 주입.
  double _pressure = 0.0;

  set pressure(double value) => _pressure = value;

  /// 직전 frame 에서 호기 중이었는지. 전환 감지용.
  bool _wasExhaling = false;

  /// 한 번이라도 호기 했는지. 첫 호기 전엔 흡기 휴리스틱 적용 안 함.
  bool _hasExhaled = false;

  /// 호기가 끝난 시점 이후 경과 초.
  double _timeSinceExhaleEnd = 0.0;

  /// 직전 frame 의 phase. 전환 시 active 애니 time=0 초기화 트리거.
  _BreathPhase _previousPhase = _BreathPhase.rest;

  /// 직전 frame 에 실제로 apply 한 애니 — "active → after" 전환 감지용.
  rive.Animation? _lastAppliedAnim;

  @override
  void artboardChanged(rive.Artboard artboard) {
    super.artboardChanged(artboard);
    _exhaleAnim = artboard.animationNamed('Exhalation');
    _exhaleAfterAnim = artboard.animationNamed('Exhalation after');
    _inhaleAnim = artboard.animationNamed('inhalation');
    _inhaleAfterAnim = artboard.animationNamed('Inhalation after');
    notifyListeners();
  }

  @override
  bool advance(double elapsedSeconds) {
    // 1) 시간 추적 — 호기 → 호기 종료 전환 감지 + 경과 초 누적.
    final isExhaling = _pressure > _pressureThreshold;
    if (_wasExhaling && !isExhaling) {
      // 호기 → 호기 아님 전환: 타이머 리셋.
      _timeSinceExhaleEnd = 0.0;
      _hasExhaled = true;
    } else if (!isExhaling) {
      _timeSinceExhaleEnd += elapsedSeconds;
    }
    _wasExhaling = isExhaling;

    // 2) 현재 phase 결정.
    final phase = _computePhase(isExhaling);

    // 3) phase 전환 시 새 애니 time=0 으로 리셋 (활성 phase 만).
    if (phase != _previousPhase) {
      _onPhaseEnter(phase);
      _previousPhase = phase;
    }

    // 4) phase 별로 animation apply.
    return _applyPhase(phase, elapsedSeconds);
  }

  _BreathPhase _computePhase(bool isExhaling) {
    if (isExhaling) return _BreathPhase.exhaling;
    if (!_hasExhaled) return _BreathPhase.rest;
    if (_timeSinceExhaleEnd < _holdAfterExhaleSec) {
      return _BreathPhase.holdAfterExhale;
    }
    if (_timeSinceExhaleEnd < _holdAfterExhaleSec + _inhaleDurationSec) {
      return _BreathPhase.inhaling;
    }
    return _BreathPhase.rest;
  }

  /// phase 전환 시 — 액티브 phase 에 진입할 때만 active 애니 time=0 리셋.
  /// hold/rest phase 에선 active 애니가 끝날 때까지 계속 재생 → 자연스러운
  /// 마무리 후 after 애니로 자동 전환.
  void _onPhaseEnter(_BreathPhase to) {
    switch (to) {
      case _BreathPhase.exhaling:
        _exhaleAnim?.time = 0;
      case _BreathPhase.inhaling:
        _inhaleAnim?.time = 0;
      case _BreathPhase.holdAfterExhale:
      case _BreathPhase.rest:
        // 즉시 리셋 안 함 — active 애니가 끝까지 재생된 후 after 애니
        // 첫 진입 시 _applyPhase 가 자동 리셋.
        break;
    }
  }

  bool _applyPhase(_BreathPhase phase, double elapsedSeconds) {
    // exhaling/holdAfterExhale 은 같은 "호기 트랙" — Exhalation 미완이면
    // 그것 계속 재생, 완료됐으면 Exhalation after 로 전환.
    // inhaling/rest 는 같은 "흡기 트랙" — 동일 패턴.
    final isExhaleTrack = phase == _BreathPhase.exhaling ||
        phase == _BreathPhase.holdAfterExhale;

    rive.Animation? anim;
    bool isAfterAnim;
    if (isExhaleTrack) {
      final exhAnim = _exhaleAnim;
      if (exhAnim != null && exhAnim.time < exhAnim.duration) {
        anim = exhAnim;
        isAfterAnim = false;
      } else {
        anim = _exhaleAfterAnim;
        isAfterAnim = true;
      }
    } else {
      final inhAnim = _inhaleAnim;
      if (inhAnim != null && inhAnim.time < inhAnim.duration) {
        anim = inhAnim;
        isAfterAnim = false;
      } else {
        anim = _inhaleAfterAnim;
        isAfterAnim = true;
      }
    }

    if (anim == null) return false;

    // active → after 첫 전환 시 after 애니 time=0 리셋해서 처음부터.
    if (anim != _lastAppliedAnim) {
      if (isAfterAnim) {
        anim.time = 0;
      }
      _lastAppliedAnim = anim;
    }

    final stillRunning = anim.advanceAndApply(elapsedSeconds);
    if (!stillRunning) {
      if (isAfterAnim) {
        // hold/rest "after" 애니는 캐릭터 idle 이라 계속 loop.
        anim.time = 0;
      } else {
        // 액티브 애니는 풍선 max/min 에서 멈춤 — 다음 frame 에 자동으로
        // after 애니로 분기.
        anim.time = anim.duration;
      }
    }
    return true;
  }
}
