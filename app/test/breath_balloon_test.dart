import 'package:blowfit/core/character/breath_balloon.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('accumulateBalloon — 호기 (양압)', () {
    test('threshold (+5) 미만이면 변화 없음', () {
      expect(accumulateBalloon(0.5, 4.9), 0.5);
      expect(accumulateBalloon(0.5, 0.0), 0.5);
      expect(accumulateBalloon(0.5, 5.0), 0.5); // 경계값 — 정확히 같으면 무변화
    });

    test('+10 (보통 호기) 면 살짝 커짐', () {
      // excess = (10-5)/25 = 0.2, rate * 0.2 = 0.003
      final next = accumulateBalloon(0.5, 10.0);
      expect(next, greaterThan(0.5));
      expect(next, lessThan(0.51));
    });

    test('+30 (강한 호기) 면 최대 속도 = rate 만큼 커짐', () {
      // excess = (30-5)/25 = 1.0 → factor 1.0 → +rate (0.015)
      final next = accumulateBalloon(0.5, 30.0);
      expect(next, closeTo(0.515, 0.001));
    });

    test('1.0 초과 클램프', () {
      expect(accumulateBalloon(0.99, 30.0), 1.0);
      expect(accumulateBalloon(1.0, 30.0), 1.0);
    });
  });

  group('accumulateBalloon — 흡기 (음압, 차후 활성화)', () {
    test('-threshold 이내면 변화 없음', () {
      expect(accumulateBalloon(0.5, -4.9), 0.5);
      expect(accumulateBalloon(0.5, -5.0), 0.5);
    });

    test('-10 이면 살짝 작아짐', () {
      final next = accumulateBalloon(0.5, -10.0);
      expect(next, lessThan(0.5));
      expect(next, greaterThan(0.49));
    });

    test('-30 이면 최대 속도로 작아짐', () {
      final next = accumulateBalloon(0.5, -30.0);
      expect(next, closeTo(0.485, 0.001));
    });

    test('0.0 미만 클램프', () {
      expect(accumulateBalloon(0.01, -30.0), 0.0);
      expect(accumulateBalloon(0.0, -30.0), 0.0);
    });
  });

  group('accumulateBalloon — 호흡 누적 시뮬레이션', () {
    test('연속 호기 100 샘플 → 0 에서 시작해 충분히 커짐', () {
      var size = 0.0;
      for (var i = 0; i < 100; i++) {
        size = accumulateBalloon(size, 25.0); // 강한 호기
      }
      expect(size, greaterThan(0.5));
    });

    test('연속 호기 200 샘플 → 1.0 클램프', () {
      var size = 0.0;
      for (var i = 0; i < 200; i++) {
        size = accumulateBalloon(size, 30.0);
      }
      expect(size, 1.0);
    });

    test('호기 후 멈춤 → 풍선 크기 유지', () {
      var size = 0.5;
      for (var i = 0; i < 50; i++) {
        size = accumulateBalloon(size, 0.0); // 호흡 없음
      }
      expect(size, 0.5);
    });
  });

  group('accumulateBalloon — 커스텀 파라미터', () {
    test('rate 두 배 → 두 배 빠르게 변화', () {
      final slow = accumulateBalloon(0.5, 30.0, rate: 0.01);
      final fast = accumulateBalloon(0.5, 30.0, rate: 0.02);
      expect(fast - 0.5, closeTo((slow - 0.5) * 2, 0.001));
    });

    test('threshold 0 이면 매우 작은 압력에도 반응', () {
      final next = accumulateBalloon(0.5, 1.0, threshold: 0);
      expect(next, greaterThan(0.5));
    });
  });
}
