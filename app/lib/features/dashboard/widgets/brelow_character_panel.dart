// 홈(대시보드) 캐릭터 패널 — BrelowCharacter 를 앱 상태와 연결한다.
//
//  - 진화: 누적 distinct 훈련일이 7일(→Baby)·30일(→Oxygen) 임계를 넘는 순간,
//    현재 단계의 bloom(진화) 모션을 1회 재생한 뒤 다음 단계 .riv 로 교체.
//    "표시 단계"는 SharedPreferences 에 영속 → 임계를 다시 넘었다고 매번
//    재생하지 않음.
//  - happy: 누적 세션 수가 증가하면(= 세션 1회 완료) happy 1회 재생.
//
// BrelowCharacter 자체는 순수 표현 위젯이고, 트리거/영속 로직은 여기 모은다.

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/db_providers.dart';
import '../../../core/storage/character_stage_store.dart';
import '../../../core/storage/storage_providers.dart';
import 'brelow_character.dart';

/// 현재 화면에 표시 중인 캐릭터 단계 레벨 (1=Egg 2=Baby 3=Oxygen).
/// 대시보드가 이 값을 watch 하여 말풍선·캐릭터 위치를 단계별로 맞춘다.
final characterShownLevelProvider = StateProvider<int>((ref) => 1);

/// 진화(bloom) 진행 중 여부. 대시보드가 watch 하여 진화 시작 시 말풍선을 먼저
/// 페이드아웃했다가, 진화 완료 후 새 단계 말풍선을 다시 보인다.
final characterEvolvingProvider = StateProvider<bool>((ref) => false);

/// (디버그) 캐릭터 진화/표정 수동 트리거 명령.
enum CharacterDebugCmd { evolve, happy, reset }

/// 디버그 버튼 → 패널 명령 채널. seq 로 매번 distinct 하게 만들어 같은 명령도
/// 다시 처리되도록 한다. ([BrelowCharacterDebugBar] 가 발행, 패널이 listen.)
final characterDebugCmdProvider =
    StateProvider<({CharacterDebugCmd cmd, int seq})?>((ref) => null);

class BrelowCharacterPanel extends ConsumerStatefulWidget {
  const BrelowCharacterPanel({super.key, this.alignment = Alignment.center});

  /// 캐릭터 슬롯 정렬 — 대시보드는 bottomCenter 로 발끝을 그림자에 맞춘다.
  final Alignment alignment;

  @override
  ConsumerState<BrelowCharacterPanel> createState() =>
      _BrelowCharacterPanelState();
}

class _BrelowCharacterPanelState extends ConsumerState<BrelowCharacterPanel> {
  final BrelowCharacterController _motion = BrelowCharacterController();

  CharacterStageStore? _store;
  int _shownLevel = 1; // 1=Egg, 2=Baby, 3=Oxygen
  int _seenSessions = -1; // happy baseline (-1 = 미설정)
  bool _evolving = false;
  bool _ready = false;

  @override
  void dispose() {
    _motion.dispose();
    super.dispose();
  }

  // store 가 로드되면 1회 초기화 + 현재 stats 로 baseline/진화 평가.
  void _ensureStore() {
    if (_ready) return;
    final s = ref.read(characterStageStoreProvider).valueOrNull;
    if (s == null) return;
    _store = s;
    _shownLevel = s.loadShownLevel();
    _seenSessions = s.loadSeenSessions();
    _ready = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // 저장된 단계 레벨을 대시보드(말풍선/위치)에 반영.
      ref.read(characterShownLevelProvider.notifier).state = _shownLevel;
      final stats = ref.read(characterStatsProvider).valueOrNull;
      if (stats != null) _onStats(stats);
    });
  }

  void _onStats(CharacterStats stats) {
    final store = _store;
    if (store == null) return;

    // 1) happy — 누적 세션 증가 시 1회. baseline 미설정이면 맞추기만(오발사 방지).
    if (_seenSessions < 0) {
      _seenSessions = stats.sessionCount;
      store.saveSeenSessions(_seenSessions);
    } else if (stats.sessionCount > _seenSessions) {
      _seenSessions = stats.sessionCount;
      store.saveSeenSessions(_seenSessions);
      if (!_evolving) _motion.playHappy();
    }

    // 2) 진화 — 목표 단계 > 표시 단계면 bloom 후 1단계 상승.
    _maybeEvolve(stats);
  }

  void _maybeEvolve(CharacterStats stats) {
    if (_evolving) return;
    final target = CharacterStage.forTrainingDays(stats.trainingDays);
    if (target.level <= _shownLevel) return;
    _startEvolve();
  }

  /// 진화 시작 — 먼저 말풍선을 숨기고(대시보드가 페이드아웃), 잠깐 텀을 둔 뒤
  /// 캐릭터 bloom 을 재생한다. → "말풍선 먼저 사라짐 → 캐릭터 사라짐(변신)".
  void _startEvolve() {
    _evolving = true;
    ref.read(characterEvolvingProvider.notifier).state = true;
    Future.delayed(const Duration(milliseconds: 350), () {
      if (!mounted || !_evolving) return;
      _motion.playBloom(); // 현재(표시) 단계의 bloom.
    });
  }

  // bloom 재생 완료 → 다음 단계로 교체 + 영속. 다단계 점프 대비 재평가.
  void _onBloomComplete() {
    final newLevel = _shownLevel >= 3 ? 3 : _shownLevel + 1;
    setState(() => _shownLevel = newLevel);
    ref.read(characterShownLevelProvider.notifier).state = newLevel;
    _store?.saveShownLevel(newLevel);
    _evolving = false;
    ref.read(characterEvolvingProvider.notifier).state = false; // 새 말풍선 복귀
    // 새 단계 .riv 로드 후 한 번 더 평가(예: 데모 시드로 한 번에 여러 단계).
    Future.delayed(const Duration(milliseconds: 900), () {
      if (!mounted) return;
      final stats = ref.read(characterStatsProvider).valueOrNull;
      if (stats != null) _maybeEvolve(stats);
    });
  }

  // (디버그) 수동 명령 처리 — 누적일 임계와 무관하게 강제 트리거.
  void _handleDebug(CharacterDebugCmd cmd) {
    if (!_ready) return;
    switch (cmd) {
      case CharacterDebugCmd.evolve:
        if (_evolving) return;
        if (_shownLevel >= 3) return; // 이미 최종(Oxygen).
        _startEvolve(); // 말풍선 먼저 숨김 → bloom (→ _onBloomComplete 에서 상승).
      case CharacterDebugCmd.happy:
        _motion.playHappy();
      case CharacterDebugCmd.reset:
        _evolving = false;
        ref.read(characterEvolvingProvider.notifier).state = false;
        setState(() => _shownLevel = 1);
        ref.read(characterShownLevelProvider.notifier).state = 1;
        _store?.saveShownLevel(1);
    }
  }

  @override
  Widget build(BuildContext context) {
    // store 로드 감시 + stats 구독.
    ref.watch(characterStageStoreProvider);
    _ensureStore();

    ref.listen<AsyncValue<CharacterStats>>(characterStatsProvider, (_, next) {
      next.whenData(_onStats);
    });

    // (디버그) 수동 진화/happy/리셋 명령.
    ref.listen(characterDebugCmdProvider, (prev, next) {
      if (next == null || next == prev) return;
      _handleDebug(next.cmd);
    });

    if (!_ready) return const SizedBox.shrink();

    return BrelowCharacter(
      stage: CharacterStage.fromLevel(_shownLevel),
      controller: _motion,
      onBloomComplete: _onBloomComplete,
      alignment: widget.alignment,
    );
  }
}

/// (디버그 전용) 캐릭터 진화/표정 테스트 버튼 바.
///
/// 누적 훈련일을 기다리지 않고 진화(bloom→다음 단계)/happy/리셋을 즉시 트리거.
/// 대시보드에서 `if (kDebugMode)` 로만 노출한다.
class BrelowCharacterDebugBar extends ConsumerWidget {
  const BrelowCharacterDebugBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    void send(CharacterDebugCmd cmd) {
      ref.read(characterDebugCmdProvider.notifier).update(
            (s) => (cmd: cmd, seq: (s?.seq ?? 0) + 1),
          );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xCC101010),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _DebugBtn(
            '진화',
            const Color(0xFF0A89FC),
            () => send(CharacterDebugCmd.evolve),
          ),
          _DebugBtn(
            'happy',
            const Color(0xFF32B65E),
            () => send(CharacterDebugCmd.happy),
          ),
          _DebugBtn(
            '리셋',
            const Color(0xFF9E9E9E),
            () => send(CharacterDebugCmd.reset),
          ),
        ],
      ),
    );
  }
}

class _DebugBtn extends StatelessWidget {
  const _DebugBtn(this.label, this.color, this.onTap);
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 3),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: Color(0xFFFFFFFF),
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
