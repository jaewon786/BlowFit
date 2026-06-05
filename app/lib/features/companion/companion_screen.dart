import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/pairing/companion_link_store.dart';
import '../../core/pairing/pairing_service.dart';
import '../../core/theme/blowfit_colors.dart';

/// 동반자(배우자·애인) 홈.
///
/// Phase B: 연결 코드로 디바이스 사용자와 페어링. 연결 전이면 빈 상태,
/// 연결되면 "○○님과 연결됨" 상태. 훈련 현황(Figma node 88:2) + 눈치주기는
/// Phase D/E 에서 채운다.
class CompanionScreen extends ConsumerWidget {
  const CompanionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final linkAsync = ref.watch(companionLinkProvider);
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
              Expanded(
                child: linkAsync.when(
                  loading: () => const Center(
                    child: CircularProgressIndicator(
                        color: BlowfitColors.blue500,),
                  ),
                  error: (_, __) => const _Empty(),
                  data: (link) =>
                      link == null ? const _Empty() : _Linked(link: link),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 연결 전 — 연결 코드 입력 안내.
class _Empty extends StatelessWidget {
  const _Empty();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Spacer(),
        Center(
          child: Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              color: BlowfitColors.blue50,
              borderRadius: BorderRadius.circular(28),
            ),
            child: const Icon(Icons.link_rounded,
                size: 44, color: BlowfitColors.blue500,),
          ),
        ),
        const SizedBox(height: 24),
        const Text(
          '아직 연결된 사용자가 없어요',
          textAlign: TextAlign.center,
          style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: BlowfitColors.ink,),
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
            onPressed: () => context.push('/companion/link'),
            style: FilledButton.styleFrom(
              backgroundColor: BlowfitColors.blue500,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(BlowfitRadius.lg),
              ),
            ),
            child: const Text('연결 코드 입력',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),),
          ),
        ),
      ],
    );
  }
}

/// 연결됨 — 사용자 이름 표시 (훈련 현황은 Phase D 에서).
class _Linked extends StatelessWidget {
  const _Linked({required this.link});
  final CompanionLink link;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 16),
        Text(
          '${link.userName}님과 연결됐어요',
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
            color: BlowfitColors.ink,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          '훈련 현황은 곧 여기에 표시됩니다.',
          style: TextStyle(
            fontSize: 15,
            color: BlowfitColors.ink3,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: BlowfitColors.green100,
            borderRadius: BorderRadius.circular(BlowfitRadius.lg),
          ),
          child: Row(
            children: [
              const Icon(Icons.check_circle_rounded,
                  color: BlowfitColors.green500, size: 28,),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '연결 완료\n${link.userName}님의 훈련 현황을 받아올 준비가 됐어요.',
                  style: const TextStyle(
                    fontSize: 14.5,
                    height: 1.45,
                    color: BlowfitColors.greenInk,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        const Spacer(),
        // 눈치주기 — Phase E 에서 푸시 전송 연결 예정.
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('눈치주기(알림)는 다음 단계에서 제공됩니다.')),
              );
            },
            style: FilledButton.styleFrom(
              backgroundColor: BlowfitColors.ink,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(BlowfitRadius.lg),
              ),
            ),
            child: const Text('눈치주기',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),),
          ),
        ),
      ],
    );
  }
}
