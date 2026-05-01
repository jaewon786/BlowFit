import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/ble/ble_providers.dart';
import '../../core/db/db_providers.dart';
import '../../core/models/pressure_sample.dart';
import '../../core/theme/blowfit_colors.dart';
import '../../core/theme/blowfit_widgets.dart';

/// Phase 3 디자인: 인사 → 디바이스 카드 → 그라데이션 CTA → 통계 타일 → 코칭.
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connected = ref.watch(connectionProvider).valueOrNull ?? false;
    final state = ref.watch(deviceStateProvider).valueOrNull;
    final lowBattery = state != null &&
        (state.lowBattery || state.batteryPct < 20);
    final consecutiveDays =
        ref.watch(consecutiveDaysProvider).valueOrNull ?? 0;
    final weekHits = ref.watch(weekHitsProvider).valueOrNull ?? 0;

    return Scaffold(
      // AppBar 는 디자인의 52px 헤더로 직접 그림 — 표준 AppBar 보다 컴팩트.
      body: SafeArea(
        child: Column(
          children: [
            const _TopBar(),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                children: [
                  _Greeting(streakDays: consecutiveDays),
                  const SizedBox(height: 16),
                  _DeviceStatusCard(
                    connected: connected,
                    state: state,
                    onTap: () => context.push('/connect'),
                  ),
                  const SizedBox(height: 14),
                  _TrainingCta(
                    connected: connected,
                    onStart: () => context.push('/training'),
                    onConnect: () => context.push('/connect'),
                  ),
                  const SizedBox(height: 14),
                  _QuickStats(
                    weekHits: weekHits,
                    onTap: () => context.push('/trend'),
                  ),
                  const SizedBox(height: 14),
                  if (lowBattery && connected)
                    _LowBatteryBanner(snapshot: state),
                  if (lowBattery && connected) const SizedBox(height: 14),
                  const _CoachingCard(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Top bar — 52px 컴팩트 헤더 (로고 + 알림 벨)
// ---------------------------------------------------------------------------

class _TopBar extends StatelessWidget {
  const _TopBar();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: BlowfitColors.blue500,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.air, size: 18, color: Colors.white),
          ),
          const SizedBox(width: 8),
          const Text(
            'BlowFit',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.34,
            ),
          ),
          const Spacer(),
          _IconButton(
            icon: Icons.notifications_outlined,
            badge: true,
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('알림 기능은 곧 출시됩니다')),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _IconButton extends StatelessWidget {
  const _IconButton({
    required this.icon,
    required this.onTap,
    this.badge = false,
  });

  final IconData icon;
  final VoidCallback onTap;
  final bool badge;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Stack(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: const BoxDecoration(
                color: BlowfitColors.gray100,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 20, color: BlowfitColors.gray700),
            ),
            if (badge)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: BlowfitColors.red500,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Greeting — 날짜 + 인사 + streak
// ---------------------------------------------------------------------------

class _Greeting extends StatelessWidget {
  const _Greeting({required this.streakDays});
  final int streakDays;

  @override
  Widget build(BuildContext context) {
    final date = DateFormat('M월 d일 EEEE', 'ko').format(DateTime.now());
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            date,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: BlowfitColors.ink3,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Expanded(
                child: Text(
                  '안녕하세요',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.72,
                    height: 1.2,
                    color: BlowfitColors.ink,
                  ),
                ),
              ),
              if (streakDays > 0) StreakBadge(days: streakDays),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Device status card — BLE / 배터리 / 다이얼
// ---------------------------------------------------------------------------

class _DeviceStatusCard extends StatelessWidget {
  const _DeviceStatusCard({
    required this.connected,
    required this.state,
    required this.onTap,
  });

  final bool connected;
  final DeviceSnapshot? state;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final battery = state?.batteryPct ?? 0;
    final charging = state?.charging ?? false;
    return BlowfitCard(
      onTap: onTap,
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: connected ? BlowfitColors.blue50 : BlowfitColors.gray100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              connected ? Icons.bluetooth_connected : Icons.bluetooth_disabled,
              color: connected ? BlowfitColors.blue500 : BlowfitColors.gray500,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      connected ? 'BlowFit 기기' : '기기 연결 안 됨',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: BlowfitColors.ink,
                      ),
                    ),
                    const SizedBox(width: 8),
                    BlowfitChip(
                      label: connected ? '연결됨' : '연결 끊김',
                      tone: connected
                          ? BlowfitChipTone.green
                          : BlowfitChipTone.neutral,
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(
                      charging ? Icons.battery_charging_full : Icons.battery_full,
                      size: 14,
                      color: BlowfitColors.ink3,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      connected ? '$battery%' : '—',
                      style: const TextStyle(
                        fontSize: 12,
                        color: BlowfitColors.ink3,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Icon(Icons.tune, size: 14, color: BlowfitColors.ink3),
                    const SizedBox(width: 4),
                    const Text(
                      '다이얼 2단',
                      style: TextStyle(
                        fontSize: 12,
                        color: BlowfitColors.ink3,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right,
              color: BlowfitColors.gray400, size: 20),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Training CTA — 그라데이션 카드
// ---------------------------------------------------------------------------

class _TrainingCta extends StatelessWidget {
  const _TrainingCta({
    required this.connected,
    required this.onStart,
    required this.onConnect,
  });

  final bool connected;
  final VoidCallback onStart;
  final VoidCallback onConnect;

  @override
  Widget build(BuildContext context) {
    final action = connected ? onStart : onConnect;
    final actionLabel = connected ? '지금 훈련 시작' : '기기 연결';
    final actionIcon = connected ? Icons.play_arrow : Icons.bluetooth_searching;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(BlowfitRadius.xl),
        gradient: const LinearGradient(
          colors: [BlowfitColors.blue500, BlowfitColors.blue700],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color.fromRGBO(0, 102, 255, 0.24),
            blurRadius: 24,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          // Decorative circles.
          Positioned(
            top: -20,
            right: -20,
            child: Container(
              width: 140,
              height: 140,
              decoration: const BoxDecoration(
                color: Color.fromRGBO(255, 255, 255, 0.08),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            bottom: -30,
            right: 30,
            child: Container(
              width: 80,
              height: 80,
              decoration: const BoxDecoration(
                color: Color.fromRGBO(255, 255, 255, 0.06),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '오늘의 훈련',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color.fromRGBO(255, 255, 255, 0.8),
                  letterSpacing: 0.24,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                '5분 호흡 훈련',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  letterSpacing: -0.44,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                '흡기·호기 3세트 · 다이얼 2단',
                style: TextStyle(
                  fontSize: 14,
                  color: Color.fromRGBO(255, 255, 255, 0.85),
                ),
              ),
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: action,
                icon: Icon(actionIcon, size: 18),
                label: Text(actionLabel),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: BlowfitColors.blue600,
                  minimumSize: const Size(0, 48),
                  padding: const EdgeInsets.symmetric(horizontal: 22),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
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
// Quick stats — 이번 주 / 평균 호기 압력
// ---------------------------------------------------------------------------

class _QuickStats extends StatelessWidget {
  const _QuickStats({required this.weekHits, required this.onTap});
  final int weekHits;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ratio = (weekHits / 7).clamp(0.0, 1.0);
    return Row(
      children: [
        Expanded(
          child: BlowfitCard(
            onTap: onTap,
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '이번 주',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: BlowfitColors.ink3,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      '$weekHits',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.48,
                        color: BlowfitColors.ink,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                    const Text(
                      ' / 7회',
                      style: TextStyle(
                        fontSize: 14,
                        color: BlowfitColors.ink3,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: ratio,
                    minHeight: 6,
                    backgroundColor: BlowfitColors.gray150,
                    valueColor: const AlwaysStoppedAnimation<Color>(
                        BlowfitColors.blue500),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: BlowfitCard(
            onTap: onTap,
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '평균 호기 압력',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: BlowfitColors.ink3,
                  ),
                ),
                const SizedBox(height: 6),
                const Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      '23.4',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.48,
                        color: BlowfitColors.ink,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                    SizedBox(width: 4),
                    Text(
                      'cmH₂O',
                      style: TextStyle(
                        fontSize: 13,
                        color: BlowfitColors.ink3,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Row(
                  children: [
                    Icon(Icons.arrow_upward,
                        size: 11, color: BlowfitColors.green500),
                    SizedBox(width: 4),
                    Text(
                      '+3.1 지난주 대비',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: BlowfitColors.green500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Coaching card
// ---------------------------------------------------------------------------

class _CoachingCard extends StatelessWidget {
  const _CoachingCard();

  @override
  Widget build(BuildContext context) {
    return BlowfitCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: BlowfitColors.green100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.emoji_events,
                color: BlowfitColors.greenInk, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '이번 주 코칭',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: BlowfitColors.greenInk,
                    letterSpacing: 0.24,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  '호기 압력이 꾸준히 향상되고 있어요. 다음 주는 다이얼 3단계로 올려보세요.',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    height: 1.45,
                    color: BlowfitColors.ink,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text(
                      '자세히 보기',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    Icon(Icons.chevron_right,
                        size: 14,
                        color: Theme.of(context).colorScheme.primary),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Low battery banner (기존 유지, 톤만 새 토큰으로 맞춤)
// ---------------------------------------------------------------------------

class _LowBatteryBanner extends StatelessWidget {
  const _LowBatteryBanner({required this.snapshot});
  final DeviceSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: BlowfitColors.red100,
        borderRadius: BorderRadius.circular(BlowfitRadius.lg),
      ),
      child: Row(
        children: [
          Icon(
            snapshot.charging
                ? Icons.battery_charging_full
                : Icons.battery_alert,
            color: BlowfitColors.redInk,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              snapshot.charging
                  ? '배터리 부족 — 충전 중입니다 (${snapshot.batteryPct}%)'
                  : '배터리 잔량이 ${snapshot.batteryPct}% 입니다. 곧 충전해주세요.',
              style: const TextStyle(
                color: BlowfitColors.redInk,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
