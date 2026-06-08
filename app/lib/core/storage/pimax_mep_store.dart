// 사용자 PImax/MEP/강도(Intensity) 영속 — %PImax 기반 적응형 목표압력의 입력값.
//
// 기기(session.cpp)가 진실의 원천: 앱은 연결 시 BLE SET_TARGET v4.1 payload
// (level + pimax×10 + mep×10) 로 이 값을 전송. 앱 재시작 후에도 값이 유지되도록
// SharedPreferences 캐시.
//
// 기본값(임상 근거):
//   - PImax 80 / MEP 60 — 일반 성인 평균 (Black & Hyatt 1969)
//   - Normal (50~60% PImax) — POWERbreathe 임상 표준
//
// 안전 상한 (consumer device ceiling):
//   - 흡기 target high (PImax × high_pct) > 90 cmH₂O → 경고
//   - 호기 target high (MEP   × high_pct) > 100 cmH₂O → 경고

import 'package:shared_preferences/shared_preferences.dart';

/// 강도 단계 — 펌웨어 session::IntensityLevel 과 1:1 매핑 (BLE payload byte).
enum IntensityLevel {
  beginner(0, '초보자', 0.30, 0.40),
  normal(1, '일반', 0.50, 0.60),
  advanced(2, '숙련자', 0.70, 0.75);

  const IntensityLevel(this.value, this.label, this.lowPct, this.highPct);

  /// BLE wire 값 (0/1/2).
  final int value;

  /// UI 표시 라벨 (한국어).
  final String label;

  /// PImax/MEP 에 곱할 비율 (low/high).
  final double lowPct;
  final double highPct;

  /// UI 표시용 평균 % — "55% PImax" 처럼 single number 로 보여줄 때.
  int get midPct => ((lowPct + highPct) * 50).round();

  static IntensityLevel fromValue(int v) {
    for (final l in IntensityLevel.values) {
      if (l.value == v) return l;
    }
    return IntensityLevel.normal;
  }
}

class PimaxMepStore {
  PimaxMepStore(this._prefs);

  static const _kPimax = 'pimax_cmh2o_x10';   // ×10 정수로 저장 (decimal 1자리)
  static const _kMep   = 'mep_cmh2o_x10';
  static const _kLevel = 'intensity_level';

  /// 일반 성인 평균 (Black & Hyatt 1969).
  static const defaultPimax = 80.0;
  static const defaultMep   = 60.0;
  static const defaultLevel = IntensityLevel.normal;

  /// Consumer device ceiling — Vranish 2016 등 IMT 임상 상한 + 압력 손상 예방.
  static const inhaleSafetyLimitCmH2O = 90.0;
  static const exhaleSafetyLimitCmH2O = 100.0;

  final SharedPreferences _prefs;

  static Future<PimaxMepStore> open() async {
    final prefs = await SharedPreferences.getInstance();
    return PimaxMepStore(prefs);
  }

  double loadPimax() {
    final x10 = _prefs.getInt(_kPimax);
    return x10 == null ? defaultPimax : x10 / 10.0;
  }

  double loadMep() {
    final x10 = _prefs.getInt(_kMep);
    return x10 == null ? defaultMep : x10 / 10.0;
  }

  IntensityLevel loadLevel() {
    final v = _prefs.getInt(_kLevel);
    return v == null ? defaultLevel : IntensityLevel.fromValue(v);
  }

  Future<void> savePimax(double pimax) =>
      _prefs.setInt(_kPimax, (pimax * 10).round());

  Future<void> saveMep(double mep) =>
      _prefs.setInt(_kMep, (mep * 10).round());

  Future<void> saveLevel(IntensityLevel level) =>
      _prefs.setInt(_kLevel, level.value);

  /// 흡기 target (cmH₂O magnitude) — PImax × (low_pct~high_pct).
  /// 안전 상한 초과 시 high 를 clamp (low 도 추월하면 같이 끌어내림).
  ({double low, double high}) inhaleTarget() {
    final pimax = loadPimax();
    final level = loadLevel();
    var low  = pimax * level.lowPct;
    var high = pimax * level.highPct;
    if (high > inhaleSafetyLimitCmH2O) {
      high = inhaleSafetyLimitCmH2O;
      if (low > high) low = high;
    }
    return (low: low, high: high);
  }

  ({double low, double high}) exhaleTarget() {
    final mep = loadMep();
    final level = loadLevel();
    var low  = mep * level.lowPct;
    var high = mep * level.highPct;
    if (high > exhaleSafetyLimitCmH2O) {
      high = exhaleSafetyLimitCmH2O;
      if (low > high) low = high;
    }
    return (low: low, high: high);
  }

  /// 사용자가 PImax/MEP 를 너무 높게 입력해서 계산된 target high 가 안전 상한을
  /// 넘었는지 — 설정 화면에서 ⚠ 표시용.
  bool get inhaleExceedsSafetyLimit =>
      loadPimax() * loadLevel().highPct > inhaleSafetyLimitCmH2O;
  bool get exhaleExceedsSafetyLimit =>
      loadMep() * loadLevel().highPct > exhaleSafetyLimitCmH2O;
}
