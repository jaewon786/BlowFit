import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/ble/ble_providers.dart';
import '../../core/theme/blowfit_colors.dart';
import '../../core/theme/blowfit_widgets.dart';

/// 프로필 + 설정 흡수 화면. 디자인의 09 화면.
///
/// 이전엔 별도 settings 탭이었던 항목들 (목표 압력, 영점 보정, 기기 연결,
/// 앱 정보) 을 이 화면 안의 리스트 행으로 이동.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connected = ref.watch(connectionProvider).valueOrNull ?? false;

    return Scaffold(
      appBar: AppBar(title: const Text('프로필')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // 프로필 카드 (이름, 베이스라인 등 — Phase 5 에서 본격 구현)
            BlowfitCard(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: const BoxDecoration(
                      color: BlowfitColors.blue50,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.person,
                        size: 28, color: BlowfitColors.blue500),
                  ),
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '사용자',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: BlowfitColors.ink,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          '프로필 설정 — 추후 구현',
                          style: TextStyle(
                            fontSize: 13,
                            color: BlowfitColors.ink3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // 설정 섹션
            const _SectionHeader('설정'),
            BlowfitCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  _SettingsRow(
                    icon: Icons.bluetooth,
                    title: '내 기기',
                    subtitle: connected ? '연결됨' : '연결 안 됨',
                    onTap: () => context.push('/connect'),
                  ),
                  const Divider(indent: 56, height: 1),
                  _SettingsRow(
                    icon: Icons.tune,
                    title: '목표 압력 설정',
                    subtitle: '훈련 목표 영역 조정',
                    onTap: () => context.push('/settings/target'),
                  ),
                  const Divider(indent: 56, height: 1),
                  _SettingsRow(
                    icon: Icons.menu_book_outlined,
                    title: '훈련 가이드',
                    subtitle: '올바른 호흡 자세',
                    onTap: () => context.push('/guide'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // 정보 섹션
            const _SectionHeader('정보'),
            BlowfitCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  _SettingsRow(
                    icon: Icons.info_outline,
                    title: '앱 정보',
                    subtitle: 'v0.1 · BlowFit',
                    onTap: () => showAboutDialog(
                      context: context,
                      applicationName: 'BlowFit',
                      applicationVersion: 'v0.1',
                      applicationLegalese: '© 2026 한남대학교 CPD',
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: BlowfitColors.ink3,
        ),
      ),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: BlowfitColors.blue50,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon,
                    size: 18, color: BlowfitColors.blue500),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: BlowfitColors.ink,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 13,
                        color: BlowfitColors.ink3,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right,
                  size: 20, color: BlowfitColors.gray400),
            ],
          ),
        ),
      ),
    );
  }
}
