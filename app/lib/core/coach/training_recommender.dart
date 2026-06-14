// 압력 추이(성장) + 목표 도달률 기반 훈련 추천 — 다이얼 단계 + 훈련 시간.
//
// 순수 함수(저장소/네트워크 비의존)라 단위 테스트 가능. 입력은 drift Session 이
// 아닌 [SessionPerf] DTO 로 받는다.
//
// 신호:
//   1) 압력 추이(주 신호) — 세션 날숨 평균을 다이얼 보정계수로 나눠 *기준 2단
//      환산값* 으로 통일 → 서로 다른 단계에서 훈련해도 성장 추세를 비교 가능.
//      최근 절반 vs 이전 절반 평균으로 상승/유지/하락 판정.
//   2) 목표 도달률(보정 신호) — enduranceSec / durationSec 평균(=목표 zone 체류율).
//
// 결정:
//   성장 up/flat & 도달률 높음 → 다이얼 한 단계 ↑ (+ 시간 ↑)
//   도달률 낮음 or 성장 down   → 다이얼 한 단계 ↓
//   그 외                       → 유지
//   가드레일 — 한 번에 한 단계, 주차 상한(dialForWeeks)으로 clamp.

import '../ble/blowfit_uuids.dart';
import 'growth_message.dart';

/// 추천 입력용 한 세션 성과 (Session 에 비의존).
class SessionPerf {
  const SessionPerf({
    required this.orificeLevel,
    required this.avgExhale,
    required this.enduranceSec,
    required this.durationSec,
    required this.at,
  });

  final int orificeLevel; // 훈련한 다이얼 (0/1/2)
  final double avgExhale; // 날숨 평균 압력 (cmH₂O)
  final int enduranceSec; // 목표 zone 체류 시간
  final int durationSec; // 세션 전체 시간
  final DateTime at;
}

/// 훈련 추천 결과.
class TrainingRecommendation {
  const TrainingRecommendation({
    required this.dial,
    required this.minutes,
    required this.reason,
    required this.isFallback,
  });

  final OrificeLevel dial;
  final int minutes;
  final String reason;
  final bool isFallback; // 데이터 부족 → 주차 기반 폴백

  /// "다이얼 N단 · M분"
  String get summary => '다이얼 ${dial.stage}단 · $minutes분';
}

/// 경험 주차 → 권장 다이얼 (데이터 부족 폴백 + 상한 가드레일 공용).
OrificeLevel dialForWeeks(int weeks) {
  if (weeks < 4) return OrificeLevel.low; // 1단
  if (weeks < 8) return OrificeLevel.medium; // 2단
  return OrificeLevel.high; // 3단
}

/// 압력 추이 + 목표 도달률로 다음 훈련의 다이얼·시간을 추천.
TrainingRecommendation recommendTraining({
  required List<SessionPerf> recent,
  required OrificeLevel currentDial,
  required int currentMinutes,
  required int weeksUsing,
  List<int> durationOptions = const [5, 10],
  int minSessions = 3,
  double masteredHit = 0.65,
  double strugglingHit = 0.30,
}) {
  // 1) 데이터 부족 → 주차 기반 폴백.
  if (recent.length < minSessions) {
    return TrainingRecommendation(
      dial: dialForWeeks(weeksUsing),
      minutes: durationOptions.first,
      reason: '훈련 기록이 쌓이면 압력 추이로 맞춤 추천을 드려요.',
      isFallback: true,
    );
  }

  final sorted = [...recent]..sort((a, b) => a.at.compareTo(b.at));

  // 2) 목표 도달률 (시간 대비 zone 체류).
  var hitSum = 0.0;
  var hitN = 0;
  for (final s in sorted) {
    if (s.durationSec > 0) {
      hitSum += (s.enduranceSec / s.durationSec).clamp(0.0, 1.0);
      hitN++;
    }
  }
  final hitRate = hitN == 0 ? 0.0 : hitSum / hitN;

  // 3) 성장 추세 — 기준 2단 환산값으로 통일 후 전반/후반 비교.
  final refAvgs = [
    for (final s in sorted)
      s.avgExhale / OrificeLevel.fromValue(s.orificeLevel).coefficient,
  ];
  final half = refAvgs.length ~/ 2;
  final earlier = refAvgs.sublist(0, half);
  final later = refAvgs.sublist(refAvgs.length - half);
  final trend = weeklyGrowth(
    thisWeek: _mean(later),
    lastWeek: _mean(earlier),
  ).trend;

  // 4) 다이얼 결정.
  var dial = currentDial;
  if (trend != GrowthTrend.down && hitRate >= masteredHit) {
    dial = _stepUp(currentDial);
  } else if (hitRate <= strugglingHit || trend == GrowthTrend.down) {
    dial = _stepDown(currentDial);
  }
  // 주차 상한 가드레일 — 초반에 너무 높은 단계 방지.
  final cap = dialForWeeks(weeksUsing);
  if (dial.value > cap.value) dial = cap;

  // 5) 시간 결정.
  var minutes = currentMinutes;
  final di = durationOptions.indexOf(currentMinutes);
  if (hitRate >= masteredHit && dial.value >= currentDial.value) {
    if (di >= 0 && di < durationOptions.length - 1) {
      minutes = durationOptions[di + 1];
    }
  } else if (hitRate <= strugglingHit) {
    if (di > 0) minutes = durationOptions[di - 1];
  }

  // 6) 사유 문구 — 최종 다이얼/시간 변화 기준.
  final up = dial.value > currentDial.value;
  final down = dial.value < currentDial.value;
  String reason;
  if (up) {
    reason = '압력이 꾸준히 늘고 목표도 잘 도달해요. 다이얼을 ${dial.stage}단으로 올려보세요.';
  } else if (down) {
    reason = '아직 목표 압력에 자주 못 미쳐요. 다이얼을 ${dial.stage}단으로 낮춰 편하게 해요.';
  } else if (hitRate >= masteredHit) {
    reason = '목표를 잘 도달하고 있어요. 지금 단계를 유지해요.';
  } else {
    reason = '지금 단계가 적당해요. 꾸준히 이어가요.';
  }
  if (minutes > currentMinutes) {
    reason += ' 익숙해졌으니 시간도 $minutes분으로 늘려보세요.';
  }

  return TrainingRecommendation(
    dial: dial,
    minutes: minutes,
    reason: reason,
    isFallback: false,
  );
}

double _mean(List<double> xs) =>
    xs.isEmpty ? 0 : xs.reduce((a, b) => a + b) / xs.length;

OrificeLevel _stepUp(OrificeLevel d) =>
    d.value >= 2 ? d : OrificeLevel.fromValue(d.value + 1);

OrificeLevel _stepDown(OrificeLevel d) =>
    d.value <= 0 ? d : OrificeLevel.fromValue(d.value - 1);
