// 시간대별 동적 배경 — 6개 zone 그라데이션 (디자이너 일러스트 도착 전 임시).
//
// build() 마다 zone 을 즉시 계산. Training 등 자주 rebuild 되는 화면에서
// 시간이 바뀌면 자연스럽게 갱신되고, AnimatedSwitcher 가 zone 변경 시
// 부드럽게 페이드 (~600ms). 디자이너 일러스트 도착 후 _ZoneBackground 의
// 그라데이션을 AssetImage 로 교체하면 됨 (외부 API 변경 없음).
//
// 자동 30분 타이머는 의도적으로 사용하지 않음 — Timer.periodic 이 위젯
// 테스트에서 leak 되는 이슈 + Training 화면은 BLE 압력 stream 으로 거의
// 매 frame rebuild 되므로 시각상 차이 없음.

import 'package:flutter/material.dart';

/// 6개 시간대 — `zoneForHour` 로 분기.
enum TimeZone {
  /// 5~7시 — 새벽, 보라/분홍 그라데이션.
  dawn,

  /// 7~11시 — 아침, 밝은 하늘.
  morning,

  /// 11~14시 — 점심, 맑은 파란 하늘.
  noon,

  /// 14~17시 — 오후, 황금빛.
  afternoon,

  /// 17~20시 — 저녁, 노을.
  evening,

  /// 20~5시 — 밤, 짙은 남색.
  night,
}

/// 24시간 시각 (0~23) → zone 매핑. 경계는 시작 포함, 끝 제외.
TimeZone zoneForHour(int hour) {
  if (hour < 5) return TimeZone.night;
  if (hour < 7) return TimeZone.dawn;
  if (hour < 11) return TimeZone.morning;
  if (hour < 14) return TimeZone.noon;
  if (hour < 17) return TimeZone.afternoon;
  if (hour < 20) return TimeZone.evening;
  return TimeZone.night;
}

/// zone 별 LinearGradient 색상 토큰 — 일러스트 도착 전 임시.
/// 모든 zone 이 옅은 파스텔 (Material 100~200 shade) 로 통일 — 어두운 배경
/// 에서 기존 UI(검정 텍스트, 차트 라인) 가독성 깨지는 문제 방지. 진한 색감
/// 의 시간대 분위기는 디자이너 일러스트 도착 후 복원.
({Color top, Color bottom}) _gradientColors(TimeZone zone) {
  switch (zone) {
    case TimeZone.dawn:
      // 새벽 — 옅은 분홍 → 옅 하늘
      return (top: const Color(0xFFFCE4EC), bottom: const Color(0xFFE3F2FD));
    case TimeZone.morning:
      // 아침 — 옅 하늘 → 옅 노랑
      return (top: const Color(0xFFE3F2FD), bottom: const Color(0xFFFFF9C4));
    case TimeZone.noon:
      // 점심 — 옅 하늘 → 흰
      return (top: const Color(0xFFE1F5FE), bottom: const Color(0xFFFFFFFF));
    case TimeZone.afternoon:
      // 오후 — 옅 노랑 → 살구
      return (top: const Color(0xFFFFF8E1), bottom: const Color(0xFFFFE0B2));
    case TimeZone.evening:
      // 저녁 — 살구 → 라벤더 (노을 느낌, 가독성 유지)
      return (top: const Color(0xFFFFCCBC), bottom: const Color(0xFFE1BEE7));
    case TimeZone.night:
      // 밤 — 옅 인디고 (밤 분위기 약간만 — 어두운 색 회피)
      return (top: const Color(0xFFE8EAF6), bottom: const Color(0xFFC5CAE9));
  }
}

/// 자식 위에 시간대별 배경을 깔아주는 컨테이너. body 가 child 안에 들어감.
///
/// `clock` 은 테스트 전용 — 실제 동작에선 매 build 마다 `DateTime.now()` 로
/// 현재 시각의 zone 계산. zone 이 바뀌면 [AnimatedSwitcher] 가 페이드 전환.
class TimeBackground extends StatelessWidget {
  const TimeBackground({
    super.key,
    required this.child,
    this.transitionDuration = const Duration(milliseconds: 600),
    @visibleForTesting this.clock,
  });

  final Widget child;
  final Duration transitionDuration;

  /// 테스트 전용 — 시간 주입. null 이면 `DateTime.now()`.
  final DateTime Function()? clock;

  @override
  Widget build(BuildContext context) {
    final now = (clock ?? DateTime.now)();
    final zone = zoneForHour(now.hour);
    final colors = _gradientColors(zone);
    return AnimatedSwitcher(
      duration: transitionDuration,
      child: Container(
        // ValueKey 로 zone 바뀔 때 새 자식으로 인식 → 페이드 트리거.
        key: ValueKey<TimeZone>(zone),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [colors.top, colors.bottom],
          ),
        ),
        child: child,
      ),
    );
  }
}
