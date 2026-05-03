/// 디자인 v2 의 코칭 카피 — Dashboard '이번 주 코칭' 카드 + Result 코치 노트.
///
/// 모두 pure 함수. 입력값에 따라 분기되는 카피를 반환.
class CoachingEngine {
  CoachingEngine._();

  /// Dashboard '이번 주 코칭' — weekHits / streak / pressureDelta 입력으로
  /// 적절한 카피 분기. 입력이 모두 0/null 이면 신규 사용자용 안내.
  static CoachingTip dashboardWeekly({
    required int weekHits,
    required int currentStreak,
    required double? thisWeekAvg,
    required double? lastWeekAvg,
  }) {
    // 신규 사용자 — 기록 없음.
    if (weekHits == 0 && currentStreak == 0 && thisWeekAvg == null) {
      return const CoachingTip(
        eyebrow: '오늘 시작해보세요',
        body: '매일 5분 호흡 훈련으로\n수면의 질을 개선해보세요.',
        tone: CoachingTone.info,
      );
    }

    final delta = (thisWeekAvg != null && lastWeekAvg != null)
        ? thisWeekAvg - lastWeekAvg
        : null;

    // 향상 (지난주 대비 +1.5 cmH₂O 이상)
    if (delta != null && delta >= 1.5) {
      return CoachingTip(
        eyebrow: '이번 주 코칭',
        body: '호기 압력이 지난주 대비 +${delta.toStringAsFixed(1)} cmH₂O '
            '향상됐어요. 다음 주는 다이얼 한 단계 올려보세요.',
        tone: CoachingTone.positive,
      );
    }

    // 후퇴 (지난주 대비 -1.5 cmH₂O 이상)
    if (delta != null && delta <= -1.5) {
      return const CoachingTip(
        eyebrow: '이번 주 코칭',
        body: '컨디션이 살짝 떨어졌어요. 호흡을 더 깊게,\n복부의 힘으로 천천히 내쉬어 보세요.',
        tone: CoachingTone.warning,
      );
    }

    // 7일 이상 streak
    if (currentStreak >= 7) {
      return CoachingTip(
        eyebrow: '연속 훈련 $currentStreak일째',
        body: '꾸준함이 호흡근을 만들어요.\n오늘도 5분만 투자해봐요.',
        tone: CoachingTone.positive,
      );
    }

    // 이번 주 5회 이상
    if (weekHits >= 5) {
      return const CoachingTip(
        eyebrow: '이번 주 잘하고 있어요',
        body: '꾸준한 훈련이 가장 중요해요.\n남은 주를 꽉 채워봐요.',
        tone: CoachingTone.positive,
      );
    }

    // 이번 주 1~4회 — 기본 격려
    return const CoachingTip(
      eyebrow: '이번 주 코칭',
      body: '조금씩이라도 매일 훈련하면\n호흡근이 강해져요.',
      tone: CoachingTone.info,
    );
  }

  /// Result 화면 점수 메시지 (큰 카드의 짧은 문구).
  static String resultScoreMessage({
    required int score,
    required int targetHits,
  }) {
    if (score >= 90 && targetHits >= 4) return '훌륭한 훈련이었어요!';
    if (score >= 75) return '잘하셨어요!';
    if (score >= 50) return '꾸준히 발전하고 있어요';
    return '내일 다시 도전해봐요';
  }

  /// Result 화면 하단 코치 노트 (1~2줄).
  /// score 와 endurance 비율, 이번주 대비 향상도까지 종합.
  static CoachingTip resultNote({
    required int score,
    required int targetHits,
    required double endurancePct, // 0..1
    required double? deltaVsLastWeek, // null 이면 비교 불가
  }) {
    if (score < 50) {
      return const CoachingTip(
        eyebrow: '오늘의 팁',
        body: '한 단계 가벼운 오리피스로 시작하거나\n호흡을 더 깊게 가져가보세요.',
        tone: CoachingTone.info,
      );
    }

    if (deltaVsLastWeek != null && deltaVsLastWeek >= 1) {
      return CoachingTip(
        eyebrow: '오늘의 팁',
        body: '호흡근이 강해지고 있어요. 지난주 대비 '
            '+${deltaVsLastWeek.toStringAsFixed(1)} cmH₂O 향상됐어요.',
        tone: CoachingTone.positive,
      );
    }

    if (endurancePct >= 0.7) {
      return const CoachingTip(
        eyebrow: '오늘의 팁',
        body: '목표 구간을 잘 유지했어요.\n다음엔 다이얼 한 단계 올려봐도 좋아요.',
        tone: CoachingTone.positive,
      );
    }

    if (targetHits >= 4) {
      return const CoachingTip(
        eyebrow: '오늘의 팁',
        body: '오늘도 목표를 잘 달성했어요!\n꾸준한 훈련이 가장 중요합니다.',
        tone: CoachingTone.positive,
      );
    }

    return const CoachingTip(
      eyebrow: '오늘의 팁',
      body: '꾸준한 훈련이 호흡근을 만들어요.\n매일 5분씩만 투자해봐요.',
      tone: CoachingTone.info,
    );
  }
}

class CoachingTip {
  /// 짧은 라벨 ("이번 주 코칭" / "오늘의 팁" / "연속 훈련 7일째") — 카드 헤더.
  final String eyebrow;

  /// 본문 — 1~2 줄.
  final String body;

  final CoachingTone tone;

  const CoachingTip({
    required this.eyebrow,
    required this.body,
    required this.tone,
  });
}

enum CoachingTone { positive, info, warning }
