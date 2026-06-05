import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/pairing/pairing_service.dart';
import '../../core/storage/storage_providers.dart';
import '../../core/theme/blowfit_colors.dart';

/// 디바이스 사용자용 — 동반자에게 알려줄 "연결 코드"를 생성·표시.
/// 동반자가 이 코드를 입력하면 내 훈련 현황을 볼 수 있다.
class MyCodeScreen extends ConsumerStatefulWidget {
  const MyCodeScreen({super.key});

  @override
  ConsumerState<MyCodeScreen> createState() => _MyCodeScreenState();
}

class _MyCodeScreenState extends ConsumerState<MyCodeScreen> {
  String? _code;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final profileStore = await ref.read(userProfileStoreProvider.future);
      final name = profileStore.load()?.name ?? '사용자';
      final code = await ref.read(pairingServiceProvider).ensureMyCode(name);
      if (mounted) setState(() => _code = code);
    } catch (e) {
      if (mounted) {
        setState(() => _error = '연결 코드를 불러오지 못했어요.\n네트워크를 확인해주세요.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: BlowfitColors.ink,
        title: const Text('동반자 연결',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),),
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 20),
            const Text(
              '배우자·애인에게\n이 코드를 알려주세요',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                height: 1.3,
                letterSpacing: -0.6,
                color: BlowfitColors.ink,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              '동반자 앱에서 이 코드를 입력하면\n내 훈련 현황을 보고 응원할 수 있어요.',
              style: TextStyle(
                fontSize: 15,
                height: 1.5,
                color: BlowfitColors.ink3,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 40),
            _codeBox(),
            const Spacer(),
          ],
        ),
      ),
    );
  }

  Widget _codeBox() {
    if (_error != null) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: BlowfitColors.red100,
          borderRadius: BorderRadius.circular(BlowfitRadius.lg),
        ),
        child: Text(
          _error!,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: BlowfitColors.redInk,
            fontSize: 15,
            fontWeight: FontWeight.w600,
            height: 1.5,
          ),
        ),
      );
    }
    if (_code == null) {
      return Container(
        height: 120,
        decoration: BoxDecoration(
          color: BlowfitColors.blue50,
          borderRadius: BorderRadius.circular(BlowfitRadius.lg),
        ),
        child: const Center(
          child: CircularProgressIndicator(color: BlowfitColors.blue500),
        ),
      );
    }
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 28),
          decoration: BoxDecoration(
            color: BlowfitColors.blue50,
            borderRadius: BorderRadius.circular(BlowfitRadius.lg),
            border: Border.all(color: BlowfitColors.blue100, width: 1.5),
          ),
          child: Text(
            _code!,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 44,
              fontWeight: FontWeight.w800,
              letterSpacing: 8,
              color: BlowfitColors.blue500,
            ),
          ),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () {
            Clipboard.setData(ClipboardData(text: _code!));
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('연결 코드를 복사했어요.')),
            );
          },
          icon: const Icon(Icons.copy_rounded, size: 18),
          label: const Text('코드 복사'),
          style: OutlinedButton.styleFrom(
            foregroundColor: BlowfitColors.blue500,
            side: const BorderSide(color: BlowfitColors.blue200),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          ),
        ),
      ],
    );
  }
}
