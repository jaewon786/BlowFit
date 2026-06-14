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
// 다이얼 보정 (유체역학):
//   - PImax/MEP 는 기준 다이얼 2단(2mm)에서 측정한 값으로 저장.
//   - 목표 = PImax(or MEP) × 강도% × 다이얼 보정계수(OrificeLevel.coefficient).
//
// 안전 상한 (consumer device ceiling):
//   - 흡기 target high > 90 cmH₂O → clamp
//   - 호기 target high > 100 cmH₂O → clamp

import 'package:shared_preferences/shared_preferences.dart';

import '../ble/blowfit_uuids.dart';

/// 강도 단계 — 펌웨어 session::IntensityLevel 과 1:1 매핑 (BLE payload byte).
enum IntensityLevel {
  beginner(0, '약하게', 0.30, 0.40),
  normal(1, '보통', 0.50, 0.60),
  advanced(2, '강하게', 0.70, 0.75);

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
  static const _kDial  = 'dial_orifice_level'; // 현재 다이얼 단계 (OrificeLevel.value)

  /// 일반 성인 평균 (Black & Hyatt 1969).
  static const defaultPimax = 80.0;
  static const defaultMep   = 60.0;
  static const defaultLevel = IntensityLevel.normal;

  /// 기본 다이얼 — 기준 2단(측정 단계, 계수 1.00).
  static const defaultDial = OrificeLevel.medium;

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

  /// 현재 선택된 다이얼 단계 (기본 2단=기준).
  OrificeLevel loadDialLevel() {
    final v = _prefs.getInt(_kDial);
    return v == null ? defaultDial : OrificeLevel.fromValue(v);
  }

  Future<void> savePimax(double pimax) =>
      _prefs.setInt(_kPimax, (pimax * 10).round());

  Future<void> saveMep(double mep) =>
      _prefs.setInt(_kMep, (mep * 10).round());

  Future<void> saveLevel(IntensityLevel level) =>
      _prefs.setInt(_kLevel, level.value);

  Future<void> saveDialLevel(OrificeLevel dial) =>
      _prefs.setInt(_kDial, dial.value);

  /// 흡기 target (cmH₂O magnitude) — PImax × (low_pct~high_pct) × 다이얼 보정계수.
  /// [dial] 미지정 시 저장된 현재 단계 사용. 안전 상한 초과 시 high 를 clamp
  /// (low 도 추월하면 같이 끌어내림).
  ({double low, double high}) inhaleTarget({OrificeLevel? dial}) {
    final pimax = loadPimax();
    final level = loadLevel();
    final coeff = (dial ?? loadDialLevel()).coefficient;
    var low  = pimax * level.lowPct * coeff;
    var high = pimax * level.highPct * coeff;
    if (high > inhaleSafetyLimitCmH2O) {
      high = inhaleSafetyLimitCmH2O;
      if (low > high) low = high;
    }
    return (low: low, high: high);
  }

  ({double low, double high}) exhaleTarget({OrificeLevel? dial}) {
    final mep = loadMep();
    final level = loadLevel();
    final coeff = (dial ?? loadDialLevel()).coefficient;
    var low  = mep * level.lowPct * coeff;
    var high = mep * level.highPct * coeff;
    if (high > exhaleSafetyLimitCmH2O) {
      high = exhaleSafetyLimitCmH2O;
      if (low > high) low = high;
    }
    return (low: low, high: high);
  }

  /// 계산된 target high 가 안전 상한을 넘었는지 (현재 다이얼 기준) — ⚠ 표시용.
  bool get inhaleExceedsSafetyLimit =>
      loadPimax() * loadLevel().highPct * loadDialLevel().coefficient >
      inhaleSafetyLimitCmH2O;
  bool get exhaleExceedsSafetyLimit =>
      loadMep() * loadLevel().highPct * loadDialLevel().coefficient >
      exhaleSafetyLimitCmH2O;
}
