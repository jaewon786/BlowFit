import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/storage/storage_providers.dart';
import '../../core/storage/user_role_store.dart';
import '../../core/theme/blowfit_colors.dart';

/// 첫 실행 — 사용 역할 선택. 한 번 선택하면 변경할 수 없다.
///   - 디바이스 사용자 : 직접 훈련하는 당사자 → 기존 전체 화면.
///   - 동반자        : 배우자·애인 등, 사용자의 훈련 현황을 보고 응원.
class RoleSelectScreen extends ConsumerStatefulWidget {
  const RoleSelectScreen({super.key});

  @override
  ConsumerState<RoleSelectScreen> createState() => _RoleSelectScreenState();
}

class _RoleSelectScreenState extends ConsumerState<RoleSelectScreen> {
  AppRole? _selected;
  bool _saving = false;

  Future<void> _confirm() async {
    final role = _selected;
    if (role == null || _saving) return;
    setState(() => _saving = true);
    final store = await ref.read(userRoleStoreProvider.future);
    await store.save(role); // appRoleNotifier 갱신 → 라우터 redirect
    if (!mounted) return;
    context.go(role == AppRole.companion ? '/companion' : '/');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 40),
              const Text(
                'BRELOW',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: BlowfitColors.blue500,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 28),
              const Text(
                '어떻게 사용하시나요?',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  height: 1.3,
                  letterSpacing: -0.78,
                  color: BlowfitColors.ink,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                '선택에 따라 화면이 달라져요.\n한 번 선택하면 변경할 수 없어요.',
                style: TextStyle(
                  fontSize: 15,
                  height: 1.5,
                  color: BlowfitColors.ink3,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 28),
              _RoleCard(
                icon: Icons.air,
                title: '디바이스 사용자',
                desc: '직접 호흡 훈련을 하는 분이에요.',
                selected: _selected == AppRole.deviceUser,
                onTap: () => setState(() => _selected = AppRole.deviceUser),
              ),
              const SizedBox(height: 16),
              _RoleCard(
                icon: Icons.favorite_rounded,
                title: '동반자 (배우자·애인)',
                desc: '사용자의 훈련 현황을 보고 응원해요.',
                selected: _selected == AppRole.companion,
                onTap: () => setState(() => _selected = AppRole.companion),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _selected == null || _saving ? null : _confirm,
                  style: FilledButton.styleFrom(
                    backgroundColor: BlowfitColors.blue500,
                    disabledBackgroundColor: BlowfitColors.gray200,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(BlowfitRadius.lg),
                    ),
                  ),
                  child: _saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          '시작하기',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
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

class _RoleCard extends StatelessWidget {
  const _RoleCard({
    required this.icon,
    required this.title,
    required this.desc,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String desc;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: selected ? BlowfitColors.blue50 : Colors.white,
          borderRadius: BorderRadius.circular(BlowfitRadius.lg),
          border: Border.all(
            color: selected ? BlowfitColors.blue500 : BlowfitColors.gray200,
            width: selected ? 2 : 1.5,
          ),
          boxShadow: selected ? null : BlowfitColors.shadowLevel1,
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: selected ? BlowfitColors.blue500 : BlowfitColors.gray100,
                borderRadius: BorderRadius.circular(BlowfitRadius.md),
              ),
              child: Icon(
                icon,
                color: selected ? Colors.white : BlowfitColors.gray400,
                size: 26,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: BlowfitColors.ink,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    desc,
                    style: const TextStyle(
                      fontSize: 13.5,
                      color: BlowfitColors.ink3,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              selected
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
              color: selected ? BlowfitColors.blue500 : BlowfitColors.gray300,
              size: 22,
            ),
          ],
        ),
      ),
    );
  }
}
