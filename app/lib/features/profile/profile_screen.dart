import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/ble/ble_providers.dart';
import '../../core/db/db_providers.dart';
import '../../core/storage/storage_providers.dart';
import '../../core/storage/user_profile_store.dart';
import '../../core/theme/blowfit_colors.dart';
import '../../core/theme/blowfit_widgets.dart';

/// 프로필 + 설정 흡수 화면. 디자인의 09 화면.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connected = ref.watch(connectionProvider).valueOrNull ?? false;

    return Scaffold(
      appBar: AppBar(
        title: const Text('프로필'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: IconButton(
              onPressed: () => context.push('/settings/target'),
              icon: const Icon(Icons.settings_outlined,
                  color: BlowfitColors.gray700),
              style: IconButton.styleFrom(
                backgroundColor: BlowfitColors.gray100,
                shape: const CircleBorder(),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          children: [
            const _ProfileHeader(),
            const SizedBox(height: 14),
            const _BaselineCard(),
            const SizedBox(height: 14),
            _SectionHeader('설정'),
            BlowfitCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  _SettingsRow(
                    icon: Icons.notifications_outlined,
                    title: '훈련 알림',
                    subtitle: '매일 오전 8시',
                    onTap: () => _comingSoon(context),
                  ),
                  const Divider(indent: 60, height: 1),
                  _SettingsRow(
                    icon: Icons.bluetooth,
                    title: '기기 관리',
                    subtitle: connected ? 'BlowFit 연결됨' : '연결 안 됨',
                    onTap: () => context.push('/connect'),
                  ),
                  const Divider(indent: 60, height: 1),
                  _SettingsRow(
                    icon: Icons.tune,
                    title: '목표 압력 설정',
                    subtitle: '훈련 목표 영역 조정',
                    onTap: () => context.push('/settings/target'),
                  ),
                  const Divider(indent: 60, height: 1),
                  _SettingsRow(
                    icon: Icons.trending_up,
                    title: '훈련 강도 자동 추천',
                    subtitle: '켜짐',
                    onTap: () => _comingSoon(context),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            _SectionHeader('지원'),
            BlowfitCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  _SettingsRow(
                    icon: Icons.person_outline,
                    title: '개인 정보 수정',
                    subtitle: null,
                    onTap: () => context.push('/profile-setup'),
                  ),
                  const Divider(indent: 60, height: 1),
                  _SettingsRow(
                    icon: Icons.menu_book_outlined,
                    title: '첫 사용 가이드 다시 보기',
                    subtitle: null,
                    onTap: () => context.push('/onboarding'),
                  ),
                  const Divider(indent: 60, height: 1),
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

  void _comingSoon(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('곧 출시될 기능입니다')),
    );
  }
}

// ---------------------------------------------------------------------------
// Profile header — avatar + name + chips
// ---------------------------------------------------------------------------

class _ProfileHeader extends ConsumerWidget {
  const _ProfileHeader();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final storeAsync = ref.watch(userProfileStoreProvider);
    final firstDateAsync = ref.watch(firstSessionDateProvider);
    final streak = ref.watch(consecutiveDaysProvider).valueOrNull ?? 0;

    final profile = storeAsync.valueOrNull?.load();
    final isEmpty = profile == null;

    return BlowfitCard(
      onTap: isEmpty ? () => context.push('/profile-setup') : null,
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          _Avatar(profile: profile),
          const SizedBox(width: 14),
          Expanded(
            child: isEmpty
                ? const _EmptyHeaderBody()
                : _FilledHeaderBody(
                    profile: profile,
                    firstSessionDate: firstDateAsync.valueOrNull,
                    streak: streak,
                  ),
          ),
          if (isEmpty)
            const Icon(Icons.chevron_right,
                size: 20, color: BlowfitColors.gray400),
        ],
      ),
    );
  }
}

/// 64×64 그라데이션 원형 아바타 — 이름 첫 글자 또는 placeholder.
class _Avatar extends StatelessWidget {
  const _Avatar({required this.profile});
  final UserProfile? profile;

  @override
  Widget build(BuildContext context) {
    final initial = profile != null && profile!.name.isNotEmpty
        ? profile!.name.characters.first.toString()
        : '?';
    return Container(
      width: 64,
      height: 64,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [BlowfitColors.blue400, BlowfitColors.blue500],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          initial,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

class _EmptyHeaderBody extends StatelessWidget {
  const _EmptyHeaderBody();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: const [
        Text(
          '이름을 설정해주세요',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: BlowfitColors.ink,
            letterSpacing: -0.32,
          ),
        ),
        SizedBox(height: 4),
        Text(
          '맞춤 훈련을 위해\n프로필 정보를 입력해주세요',
          style: TextStyle(
            fontSize: 13,
            color: BlowfitColors.ink3,
            height: 1.4,
          ),
        ),
      ],
    );
  }
}

class _FilledHeaderBody extends StatelessWidget {
  const _FilledHeaderBody({
    required this.profile,
    required this.firstSessionDate,
    required this.streak,
  });
  final UserProfile profile;
  final DateTime? firstSessionDate;
  final int streak;

  /// firstSessionDate 기준 N주차 계산. 데이터 없으면 null.
  int? get _weekIndex {
    final start = firstSessionDate ?? profile.startedAt;
    if (start == null) return null;
    final days = DateTime.now().difference(start).inDays;
    if (days < 0) return null;
    return (days ~/ 7) + 1; // 0~6일 = 1주차
  }

  @override
  Widget build(BuildContext context) {
    final week = _weekIndex;
    final isActive = streak >= 3;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          profile.name,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: BlowfitColors.ink,
            letterSpacing: -0.36,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          '${profile.age}세 · ${profile.gender.label}',
          style: const TextStyle(
            fontSize: 13,
            color: BlowfitColors.ink3,
          ),
        ),
        if (week != null || isActive) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              if (week != null)
                BlowfitChip(label: '$week주차', tone: BlowfitChipTone.blue),
              if (week != null && isActive) const SizedBox(width: 6),
              if (isActive)
                const BlowfitChip(
                    label: '활성 사용자', tone: BlowfitChipTone.green),
            ],
          ),
        ],
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Baseline card — 시작 시점 호기 / 흡기
// ---------------------------------------------------------------------------

class _BaselineCard extends ConsumerWidget {
  const _BaselineCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(firstSessionStatsProvider).valueOrNull;
    // 호기: 첫 세션 avgPressure. 없으면 "—".
    // 흡기: 하드웨어 미지원 — 항상 "—".
    final exhaleLabel = stats != null
        ? stats.avgPressure.toStringAsFixed(1)
        : '—';
    return BlowfitCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '나의 베이스라인',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: BlowfitColors.ink,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _BaselineTile(
                  label: '시작 시점 호기',
                  value: exhaleLabel,
                  unit: 'cmH₂O',
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: _BaselineTile(
                  label: '시작 시점 흡기',
                  value: '—',
                  unit: 'cmH₂O',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BaselineTile extends StatelessWidget {
  const _BaselineTile({
    required this.label,
    required this.value,
    required this.unit,
  });
  final String label;
  final String value;
  final String unit;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      decoration: BoxDecoration(
        color: BlowfitColors.gray50,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: BlowfitColors.ink3,
            ),
          ),
          const SizedBox(height: 2),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: BlowfitColors.ink,
                  letterSpacing: -0.36,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(width: 4),
              Text(
                unit,
                style: const TextStyle(
                  fontSize: 11,
                  color: BlowfitColors.ink3,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Section header
// ---------------------------------------------------------------------------

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: BlowfitColors.ink3,
          letterSpacing: 0.48,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Settings row
// ---------------------------------------------------------------------------

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
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
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: BlowfitColors.blue50,
                  borderRadius: BorderRadius.circular(10),
                ),
                child:
                    Icon(icon, size: 18, color: BlowfitColors.blue500),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: BlowfitColors.ink,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 1),
                      Text(
                        subtitle!,
                        style: const TextStyle(
                          fontSize: 12,
                          color: BlowfitColors.ink3,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const Icon(Icons.chevron_right,
                  size: 16, color: BlowfitColors.gray400),
            ],
          ),
        ),
      ),
    );
  }
}
