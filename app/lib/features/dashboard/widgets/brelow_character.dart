// BRELOW 진화형 캐릭터 — Rive (Egg → Baby → Oxygen) 3단계.
//
// 각 단계가 별도 .riv 파일(단일 아트보드)이며, 내부에 alive/happy/bloom 타임라인이
// 들어있다. 세 파일의 State Machine 에는 입력(trigger/bool)이 없으므로
// RiveWidgetController 를 서브클래싱하여 선택한 타임라인을 직접
// (animationNamed → advanceAndApply) 재생한다 (소위 "Path B").
//
//   alive : 기본 idle (무한 loop)
//   happy : 세션 완료 등 1회성 (재생 후 alive 복귀)
//   bloom : 진화 모션 1회성 (재생 후 alive 복귀). Stage3(Oxygen) 엔 없음.
//
// 진화 흐름: 부모가 [stage] 를 바꾸면 해당 .riv 를 새로 로드. bloom 은 "현재 단계
// 가 다음 단계로 변신" 모션이므로, 부모가 bloom 을 트리거하고 [onBloomComplete]
// 에서 다음 단계로 [stage] 를 올리는 식으로 사용한다.

import 'package:flutter/widgets.dart';
import 'package:rive/rive.dart' as rive;

/// 진화 단계 — 각 단계는 단일 아트보드 .riv 파일에 매핑된다.
enum CharacterStage {
  egg(1, 'assets/character/stage1_egg.riv'),
  baby(2, 'assets/character/stage2_baby.riv'),
  oxygen(3, 'assets/character/stage3_oxygen.riv');

  const CharacterStage(this.level, this.asset);

  /// 1=Egg, 2=Baby, 3=Oxygen.
  final int level;

  /// 이 단계의 Rive 에셋 경로.
  final String asset;

  /// 마지막(최종) 단계 여부 — bloom(진화) 대상이 없음.
  bool get isFinal => this == CharacterStage.oxygen;

  /// 다음 단계 (최종이면 자기 자신).
  CharacterStage get next =>
      isFinal ? this : CharacterStage.fromLevel(level + 1);

  /// 레벨(1~3) → 단계. 범위를 벗어나면 egg/oxygen 으로 clamp.
  static CharacterStage fromLevel(int level) {
    if (level <= 1) return CharacterStage.egg;
    if (level >= 3) return CharacterStage.oxygen;
    return CharacterStage.baby;
  }

  /// 진화 임계 — 누적 distinct 훈련일.
  static const int babyThresholdDays = 7;
  static const int oxygenThresholdDays = 30;

  /// 누적 훈련일 → 도달해야 할 목표 단계.
  static CharacterStage forTrainingDays(int days) {
    if (days >= oxygenThresholdDays) return CharacterStage.oxygen;
    if (days >= babyThresholdDays) return CharacterStage.baby;
    return CharacterStage.egg;
  }
}

/// 1회성 모션.
enum CharacterMotion { happy, bloom }

/// 부모가 캐릭터에 1회성 모션을 트리거하기 위한 핸들.
///
/// ```dart
/// final c = BrelowCharacterController();
/// // ...
/// c.playHappy();          // 세션 완료 시
/// c.playBloom();          // 진화 시 (onBloomComplete 후 stage 상승)
/// ```
class BrelowCharacterController extends ChangeNotifier {
  CharacterMotion? _pending;

  /// 위젯이 보류 중인 모션을 가져가 소비한다(1회).
  CharacterMotion? takePending() {
    final p = _pending;
    _pending = null;
    return p;
  }

  /// happy(1회) 재생 요청.
  void playHappy() {
    _pending = CharacterMotion.happy;
    notifyListeners();
  }

  /// bloom(1회, 진화) 재생 요청.
  void playBloom() {
    _pending = CharacterMotion.bloom;
    notifyListeners();
  }
}

class BrelowCharacter extends StatefulWidget {
  const BrelowCharacter({
    super.key,
    required this.stage,
    this.controller,
    this.onBloomComplete,
    this.fit = rive.Fit.contain,
    this.alignment = Alignment.center,
  });

  /// 표시할 진화 단계 (해당 .riv 로드). 바뀌면 새 단계 파일을 로드한다.
  final CharacterStage stage;

  /// 1회성 모션 트리거 핸들 (선택).
  final BrelowCharacterController? controller;

  /// bloom(진화) 재생이 끝났을 때 1회 호출 — 부모가 다음 단계로 올리는 용도.
  /// (Stage3 처럼 bloom 이 없으면 즉시 호출된다.)
  final VoidCallback? onBloomComplete;

  final rive.Fit fit;

  /// 슬롯 안에서 캐릭터 정렬. 대시보드는 bottomCenter 로 발끝을 그림자에 맞춘다.
  final Alignment alignment;

  @override
  State<BrelowCharacter> createState() => _BrelowCharacterState();
}

class _BrelowCharacterState extends State<BrelowCharacter> {
  // 모든 단계 .riv 를 미리 로드해두면 진화 시 동기로 즉시 교체할 수 있어,
  // 다음 캐릭터가 로드될 때까지 잠깐 사라지는 공백(async 로드 텀)이 없어진다.
  final Map<CharacterStage, rive.File> _files = {};
  _StageRiveController? _controller;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    widget.controller?.addListener(_onExternalMotion);
    _loadAll();
  }

  Future<void> _loadAll() async {
    // 1) 현재 단계 먼저 로드 → 최대한 빨리 표시.
    await _ensureLoaded(widget.stage);
    if (!mounted) return;
    _buildCurrentController();
    // 2) 나머지 단계는 "병렬" 선로딩 → 진화 시 swap 이 항상 동기(파일이 이미
    //    메모리에 있음)로 끝나 로드 지연 hitch 가 없다. (순차 로드면 마지막
    //    단계(oxygen)가 늦게 준비돼, 일찍 진화하면 swap 때 async 로드+디코드가
    //    걸려 렉처럼 보였음.)
    await Future.wait([
      for (final stage in CharacterStage.values)
        if (stage != widget.stage) _ensureLoaded(stage),
    ]);
  }

  Future<void> _ensureLoaded(CharacterStage stage) async {
    if (_files.containsKey(stage)) return;
    try {
      final file =
          await rive.File.asset(stage.asset, riveFactory: rive.Factory.flutter);
      if (!mounted) {
        file?.dispose();
        return;
      }
      if (file != null) _files[stage] = file;
    } catch (_) {
      // 개별 로드 실패는 무시 — 표시 시 _buildCurrentController 에서 처리.
    }
  }

  void _buildCurrentController() {
    if (_controller != null) return;
    final file = _files[widget.stage];
    if (file == null) {
      setState(() => _loadError = '${widget.stage.asset} 로드 실패');
      return;
    }
    setState(() {
      _controller = _StageRiveController(file);
      _loadError = null;
    });
  }

  // 외부(BrelowCharacterController) 에서 happy/bloom 요청이 들어왔을 때.
  void _onExternalMotion() {
    final motion = widget.controller?.takePending();
    final c = _controller;
    if (motion == null || c == null) return;
    switch (motion) {
      case CharacterMotion.happy:
        c.playHappy();
      case CharacterMotion.bloom:
        c.playBloom(widget.onBloomComplete);
    }
  }

  @override
  void didUpdateWidget(covariant BrelowCharacter oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?.removeListener(_onExternalMotion);
      widget.controller?.addListener(_onExternalMotion);
    }
    if (oldWidget.stage != widget.stage) {
      _swapToStage(widget.stage);
    }
  }

  // 단계 교체 — 선로딩된 파일이면 동기로 즉시 교체(공백 없음). 아직 로딩 전이면
  // 기존 캐릭터를 유지한 채 로드 후 교체(blank 회피). 파일은 dispose 하지 않고
  // 캐싱 유지(재진화/리셋 시 재사용).
  Future<void> _swapToStage(CharacterStage target) async {
    if (!_files.containsKey(target)) {
      await _ensureLoaded(target);
      if (!mounted || widget.stage != target) return;
    }
    final file = _files[target];
    if (file == null) return;
    final oldController = _controller;
    setState(() {
      _controller = _StageRiveController(file);
      _loadError = null;
    });
    // 기존 컨트롤러는 새 프레임이 그려진 뒤 정리(렌더 중 disposed 참조 방지).
    if (oldController != null) {
      WidgetsBinding.instance
          .addPostFrameCallback((_) => oldController.dispose());
    }
  }

  @override
  void dispose() {
    widget.controller?.removeListener(_onExternalMotion);
    _controller?.dispose();
    for (final f in _files.values) {
      f.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loadError != null) {
      // 로드 실패 시 조용히 빈 자리 (디자인 깨짐 방지). 디버그용으로만 로그.
      assert(() {
        debugPrint('[BrelowCharacter] load error: $_loadError');
        return true;
      }());
      return const SizedBox.shrink();
    }
    final c = _controller;
    if (c == null) return const SizedBox.shrink();
    return rive.RiveWidget(
      controller: c,
      fit: widget.fit,
      alignment: widget.alignment,
    );
  }
}

/// RiveWidgetController 서브클래스 — State Machine 대신 named 타임라인을 직접 구동.
///
/// base/final 클래스 상속 규칙상 서브타입도 base/final/sealed 여야 하므로 final.
final class _StageRiveController extends rive.RiveWidgetController {
  _StageRiveController(super.file) {
    _alive = artboard.animationNamed('alive');
    _happy = artboard.animationNamed('happy');
    _bloom = artboard.animationNamed('bloom'); // Stage3 엔 없을 수 있음(null).
    _current = _alive;
  }

  rive.Animation? _alive;
  rive.Animation? _happy;
  rive.Animation? _bloom;
  rive.Animation? _current;

  bool _oneShot = false;
  VoidCallback? _onOneShotDone;

  /// 1회성 모션 재생 배율(>1 = 빠르게). advance 시 elapsed 에 곱해 타임라인을
  /// 더 빠르게 진행 → 모션이 짧아진다. (alive/loop 에는 적용 안 함.)
  double _oneShotSpeed = 1.0;

  /// bloom(진화) 재생 배율. .riv 의 변신 모션이 단계마다 길이가 달라
  /// (egg≈1.3s, baby≈1.7s) baby→oxygen 이 더 느리게 "느껴지던" 문제 →
  /// 1.5배속으로 더 빠릿하고 단계 간 차이도 축소. (원본 .riv 는 그대로.)
  static const double _bloomSpeed = 1.5;

  void playHappy() => _startOneShot(_happy);

  void playBloom(VoidCallback? onDone) {
    // bloom 이 없으면(최종 단계) 즉시 완료 콜백.
    if (_bloom == null) {
      onDone?.call();
      return;
    }
    _startOneShot(_bloom, onDone: onDone, speed: _bloomSpeed);
  }

  void _startOneShot(
    rive.Animation? anim, {
    VoidCallback? onDone,
    double speed = 1.0,
  }) {
    if (anim == null) {
      onDone?.call();
      return;
    }
    anim.time = 0;
    _current = anim;
    _oneShot = true;
    _oneShotSpeed = speed;
    _onOneShotDone = onDone;
    notifyListeners(); // 다음 프레임 즉시 반영.
  }

  @override
  bool advance(double elapsedSeconds) {
    final cur = _current;
    if (cur == null) return false;
    // 1회성 모션은 배율 적용(빠르게), idle(alive)은 실시간 그대로.
    final dt = _oneShot ? elapsedSeconds * _oneShotSpeed : elapsedSeconds;
    final playing = cur.advanceAndApply(dt);
    if (!playing) {
      if (_oneShot) {
        // 1회성(happy/bloom) 종료 → alive loop 로 복귀.
        _oneShot = false;
        final cb = _onOneShotDone;
        _onOneShotDone = null;
        _current = _alive;
        _alive?.time = 0;
        cb?.call();
      } else {
        // idle 이 loop 설정이 아니어도 강제로 다시 돌려 끊김 없이 유지.
        cur.time = 0;
      }
    }
    return active; // alive 가 항상 돌도록 매 프레임 tick 유지.
  }

  @override
  void dispose() {
    _alive?.dispose();
    _happy?.dispose();
    _bloom?.dispose();
    super.dispose();
  }
}
