import 'package:blowfit/core/ble/blowfit_uuids.dart';
import 'package:blowfit/core/storage/pimax_mep_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Future<PimaxMepStore> openWith({
    double pimax = 80,
    double mep = 60,
    IntensityLevel level = IntensityLevel.normal,
    OrificeLevel? dial,
  }) async {
    final store = await PimaxMepStore.open();
    await store.savePimax(pimax);
    await store.saveMep(mep);
    await store.saveLevel(level);
    if (dial != null) await store.saveDialLevel(dial);
    return store;
  }

  test('다이얼 보정계수가 유체역학 스펙과 일치', () {
    expect(OrificeLevel.low.coefficient, 0.58); // 1단 3mm
    expect(OrificeLevel.medium.coefficient, 1.00); // 2단 2mm 기준
    expect(OrificeLevel.high.coefficient, 2.52); // 3단 1mm
    expect(OrificeLevel.reference, OrificeLevel.medium);
    expect(OrificeLevel.low.stage, 1);
    expect(OrificeLevel.high.stage, 3);
  });

  test('기본 다이얼은 기준(2단, 계수 1.0)', () async {
    final s = await openWith(pimax: 80);
    expect(s.loadDialLevel(), OrificeLevel.medium);
    final inh = s.inhaleTarget(); // 80*0.5*1.0 ~ 80*0.6*1.0
    expect(inh.low, closeTo(40, 0.001));
    expect(inh.high, closeTo(48, 0.001));
  });

  test('1단(3mm)은 목표를 0.58배로 낮춤', () async {
    final s = await openWith(pimax: 50);
    final inh = s.inhaleTarget(dial: OrificeLevel.low);
    expect(inh.low, closeTo(50 * 0.50 * 0.58, 0.001)); // 14.5
    expect(inh.high, closeTo(50 * 0.60 * 0.58, 0.001)); // 17.4
  });

  test('3단(1mm)은 목표를 2.52배로 높임 (안전상한 내)', () async {
    final s = await openWith(pimax: 50);
    final inh = s.inhaleTarget(dial: OrificeLevel.high);
    expect(inh.low, closeTo(50 * 0.50 * 2.52, 0.001)); // 63
    expect(inh.high, closeTo(50 * 0.60 * 2.52, 0.001)); // 75.6 < 90
  });

  test('흡기 목표가 안전상한 90으로 clamp (고PImax·3단)', () async {
    // 80 * 0.60 * 2.52 = 120.96 > 90 → clamp.
    final s = await openWith(pimax: 80);
    final inh = s.inhaleTarget(dial: OrificeLevel.high);
    expect(inh.high, 90.0);
    expect(inh.low, 90.0); // low(100.8) 도 high 추월 → 같이 끌어내림
  });

  test('호기 목표는 MEP 기반 + 안전상한 100 clamp', () async {
    final s = await openWith(mep: 60);
    final exh = s.exhaleTarget(dial: OrificeLevel.high);
    expect(exh.high, closeTo(60 * 0.60 * 2.52, 0.001)); // 90.72 < 100

    final s2 = await openWith(mep: 80, level: IntensityLevel.advanced);
    final exh2 = s2.exhaleTarget(dial: OrificeLevel.high);
    expect(exh2.high, 100.0); // 80*0.75*2.52=151.2 → clamp 100
  });

  test('dial 인자 생략 시 저장된 단계 사용', () async {
    final s = await openWith(pimax: 50, dial: OrificeLevel.high);
    final inh = s.inhaleTarget(); // 저장된 high 사용
    expect(inh.high, closeTo(50 * 0.60 * 2.52, 0.001));
  });
}
