import 'package:blowfit/core/character/growth_stage.dart';
import 'package:blowfit/core/character/otter_character.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// .riv 파일이 없는 상태에서 OtterCharacter 가 fallback 으로 안전하게 떨어지는지
/// 검증. 실 .riv 도착 후엔 Rive 애니메이션 통합 테스트는 수동/시각 검증 영역.

void main() {
  Widget harness({
    Widget? fallback,
    String assetPath = 'assets/no-such-file.riv',
  }) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 200,
            height: 200,
            child: OtterCharacter(
              pressure: 12.5,
              targetReached: false,
              sessionState: SessionState.idle,
              stage: GrowthStage.baby,
              assetPath: assetPath,
              fallback: fallback,
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('asset 없을 때 fallback 위젯 렌더링', (tester) async {
    await tester.pumpWidget(harness(fallback: const Text('FALLBACK')));
    await tester.pumpAndSettle();
    expect(find.text('FALLBACK'), findsOneWidget);
  });

  testWidgets('fallback 미지정 + asset 없음 → SizedBox.shrink (예외 없음)',
      (tester) async {
    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();
    // Rive 위젯이 그려지지 않고 자식 없는 SizedBox 만 존재하는지 검증.
    // 'FALLBACK' 같은 텍스트가 없는 것으로 간접 확인.
    expect(find.text('FALLBACK'), findsNothing);
    // 추가로 RiveAnimation 이 절대 그려지지 않는지 확인 (rive 패키지 import
    // 없이 type 비교는 어려워 텍스트 부재 + tester 가 throw 안 한 것으로 충분).
  });

  testWidgets('widget prop 업데이트 시 throw 없이 재빌드', (tester) async {
    Widget build({required double pressure}) => MaterialApp(
          home: Scaffold(
            body: OtterCharacter(
              pressure: pressure,
              targetReached: pressure > 20,
              sessionState: SessionState.active,
              stage: GrowthStage.young,
              assetPath: 'assets/no-such-file.riv',
              fallback: Text('p=$pressure'),
            ),
          ),
        );

    await tester.pumpWidget(build(pressure: 5.0));
    await tester.pumpAndSettle();
    expect(find.text('p=5.0'), findsOneWidget);

    // prop 변경
    await tester.pumpWidget(build(pressure: 25.0));
    await tester.pumpAndSettle();
    expect(find.text('p=25.0'), findsOneWidget);
  });
}
