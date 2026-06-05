import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/pairing/pairing_service.dart';
import '../../core/theme/blowfit_colors.dart';

/// 동반자용 — 디바이스 사용자의 연결 코드를 입력해 연결한다.
class ConnectionCodeScreen extends ConsumerStatefulWidget {
  const ConnectionCodeScreen({super.key});

  @override
  ConsumerState<ConnectionCodeScreen> createState() =>
      _ConnectionCodeScreenState();
}

class _ConnectionCodeScreenState extends ConsumerState<ConnectionCodeScreen> {
  final _controller = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final code = _controller.text.trim().toUpperCase();
    if (code.length != 6) {
      setState(() => _error = '6자리 코드를 입력해주세요.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final link = await ref.read(pairingServiceProvider).linkWithCode(code);
      if (link == null) {
        setState(() {
          _busy = false;
          _error = '코드를 찾을 수 없어요. 다시 확인해주세요.';
        });
        return;
      }
      final store = await ref.read(companionLinkStoreProvider.future);
      await store.save(link);
      ref.invalidate(companionLinkProvider);
      if (mounted) context.pop(); // 동반자 홈으로 — 연결됨 상태로 갱신
    } catch (e) {
      setState(() {
        _busy = false;
        _error = '연결에 실패했어요. 네트워크를 확인해주세요.';
      });
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
        title: const Text('연결 코드 입력',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),),
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 20),
            const Text(
              '디바이스 사용자의\n연결 코드를 입력하세요',
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
              '사용자 앱의 "동반자 연결" 화면에서\n6자리 코드를 확인할 수 있어요.',
              style: TextStyle(
                fontSize: 15,
                height: 1.5,
                color: BlowfitColors.ink3,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 32),
            TextField(
              controller: _controller,
              autofocus: true,
              textCapitalization: TextCapitalization.characters,
              textAlign: TextAlign.center,
              maxLength: 6,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp('[A-Za-z0-9]')),
                _UpperCaseFormatter(),
              ],
              style: const TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w800,
                letterSpacing: 8,
                color: BlowfitColors.ink,
              ),
              decoration: InputDecoration(
                counterText: '',
                hintText: 'ABC123',
                hintStyle: const TextStyle(
                  color: BlowfitColors.gray300,
                  letterSpacing: 8,
                ),
                filled: true,
                fillColor: BlowfitColors.gray100,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(BlowfitRadius.lg),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 18),
              ),
              onSubmitted: (_) => _submit(),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: BlowfitColors.redInk,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _busy ? null : _submit,
                style: FilledButton.styleFrom(
                  backgroundColor: BlowfitColors.blue500,
                  disabledBackgroundColor: BlowfitColors.gray200,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(BlowfitRadius.lg),
                  ),
                ),
                child: _busy
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white,),
                      )
                    : const Text('연결하기',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w700,),),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _UpperCaseFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue,) {
    return newValue.copyWith(text: newValue.text.toUpperCase());
  }
}
