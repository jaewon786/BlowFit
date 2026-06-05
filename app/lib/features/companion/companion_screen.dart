import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/blowfit_colors.dart';

/// 동반자(배우자·애인) 홈 — Phase A.
///
/// 아직 Firebase 연동/페어링 전이라 "연결된 사용자 없음" 빈 상태만 표시한다.
/// Phase B 에서 연결 코드 입력 → Phase D 에서 Figma(node 88:2) 의 훈련 현황
/// (오늘 요약 / 달력 / 추이 차트) + 눈치주기 버튼을 채운다.
class CompanionScreen extends ConsumerWidget {
  const CompanionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 헤더 — BRELOW 로고.
              const Row(
                children: [
                  Text(
                    'BRELOW',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: BlowfitColors.blue500,
                      letterSpacing: -0.4,
                    ),
                  ),
                  Spacer(),
                ],
              ),
              const Spacer(),
              // 빈 상태 — 연결 안내.
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  color: BlowfitColors.blue50,
                  borderRadius: BorderRadius.circular(28),
                ),
                child: const Icon(
                  Icons.link_rounded,
                  size: 44,
                  color: BlowfitColors.blue500,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                '아직 연결된 사용자가 없어요',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: BlowfitColors.ink,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                '디바이스 사용자의 연결 코드를 입력하면\n훈련 현황을 보고 응원할 수 있어요.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  height: 1.5,
                  color: BlowfitColors.ink3,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  // Phase B 에서 연결 코드 입력 화면으로 이동하도록 연결 예정.
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('연결 코드 기능은 다음 단계에서 제공됩니다.'),
                      ),
                    );
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: BlowfitColors.blue500,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(BlowfitRadius.lg),
                    ),
                  ),
                  child: const Text(
                    '연결 코드 입력',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
