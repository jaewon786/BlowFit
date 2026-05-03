import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/ble/ble_providers.dart';
import '../../core/coach/coaching_engine.dart';
import '../../core/db/db_providers.dart';
import '../../core/models/pressure_sample.dart';
import '../../core/storage/storage_providers.dart';
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
    final pressurePair =
        ref.watch(weekAvgPressureProvider).valueOrNull;
    final profile =
        ref.watch(userProfileStoreProvider).valueOrNull?.load();
    final health = ref.watch(bleHealthProvider).valueOrNull;

    return Scaffold(
      // AppBar 는 디자인의 52px 헤더로 직접 그림 — 표준 AppBar 보다 컴팩트.
      body: SafeArea(
        child: Column(
          children: [
            const _TopBar(),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
                children: [
                  _Greeting(
                    streakDays: consecutiveDays,
                    userName: profile?.name,
                  ),
                  const SizedBox(height: 14),
                  _DeviceStatusCard(
                    connected: connected,
                    state: state,
                    healthDegraded: health?.isDegraded ?? false,
                    onTap: () => context.push('/connect'),
                  ),
                  const SizedBox(height: 12),
                  _TrainingCta(
                    connected: connected,
                    orificeLevel: state?.orificeLevel,
                    onStart: () => context.push('/training-intro'),
                    onConnect: () => context.push('/connect'),
                  ),
                  const SizedBox(height: 12),
                  _QuickStats(
                    weekHits: weekHits,
                    thisWeekAvg: pressurePair?.thisWeek,
                    lastWeekAvg: pressurePair?.lastWeek,
                    onTap: () => context.push('/trend'),
                  ),
                  const SizedBox(height: 12),
                  if (lowBattery && connected)
                    _LowBatteryBanner(snapshot: state),
                  if (lowBattery && connected) const SizedBox(height: 12),
                  _CoachingCard(
                    tip: CoachingEngine.dashboardWeekly(
                      weekHits: weekHits,
                      currentStreak: consecutiveDays,
                      thisWeekAvg: pressurePair?.thisWeek,
                      lastWeekAvg: pressurePair?.lastWeek,
                    ),
                    onTap: () => context.push('/trend'),
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
  const _Greeting({required this.streakDays, this.userName});
  final int streakDays;
  final String? userName;

  @override
  Widget build(BuildContext context) {
    final date = DateFormat('M월 d일 EEEE', 'ko').format(DateTime.now());
    final greeting = (userName != null && userName!.isNotEmpty)
        ? '안녕하세요, $userName님'
        : '안녕하세요';
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
          const SizedBox(height: 3),
          Row(
            children: [
              Expanded(
                child: Text(
                  greeting,
                  style: const TextStyle(
                    fontSize: 23,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.7,
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
    required this.healthDegraded,
    required this.onTap,
  });

  final bool connected;
  final DeviceSnapshot? state;
  final bool healthDegraded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final battery = state?.batteryPct ?? 0;
    final orificeLevel = state?.orificeLevel ?? 0;
    final lowBattery = state?.lowBattery ?? (connected && battery < 20);

    return BlowfitCard(
      onTap: onTap,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ---- top row: avatar + 기기명/연결 상태 + chevron ----
          Row(
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: BlowfitColors.blue50,
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(
                  connected
                      ? Icons.bluetooth_connected
                      : Icons.bluetooth_disabled,
                  size: 29,
                  color: connected
                      ? BlowfitColors.blue500
                      : BlowfitColors.gray500,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      connected ? 'BlowFit Pro' : '기기 연결 안 됨',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: BlowfitColors.ink,
                        letterSpacing: -0.16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: connected
                                ? BlowfitColors.green500
                                : BlowfitColors.gray400,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          connected ? '연결됨' : '연결 끊김',
                          style: const TextStyle(
                            fontSize: 13,
                            color: BlowfitColors.ink2,
                            fontWeight: FontWeight.w500,
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
          const SizedBox(height: 12),
          // ---- metrics grid: 배터리 / 저항 다이얼 / 신호 ----
          Container(
            decoration: BoxDecoration(
              color: BlowfitColors.gray50,
              borderRadius: BorderRadius.circular(13),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
            child: IntrinsicHeight(
              child: Row(
                children: [
                  Expanded(
                    child: _Metric(
                      label: '배터리',
                      value: connected ? '$battery%' : '—',
                      icon: connected
                          ? _batteryIcon(battery, state?.charging ?? false)
                          : Icons.battery_unknown,
                      warn: connected && lowBattery,
                    ),
                  ),
                  const _MetricDivider(),
                  Expanded(
                    child: _Metric(
                      label: '저항 다이얼',
                      value: connected ? '${orificeLevel + 1}단' : '—',
                    ),
                  ),
                  const _MetricDivider(),
                  Expanded(
                    child: _Metric(
                      label: '신호',
                      value: connected
                          ? (healthDegraded ? '약함' : '강함')
                          : '—',
                      icon: Icons.bluetooth,
                      warn: connected && healthDegraded,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  IconData _batteryIcon(int pct, bool charging) {
    if (charging) return Icons.battery_charging_full;
    if (pct >= 90) return Icons.battery_full;
    if (pct >= 60) return Icons.battery_5_bar;
    if (pct >= 40) return Icons.battery_4_bar;
    if (pct >= 20) return Icons.battery_2_bar;
    return Icons.battery_alert;
  }
}

class _Metric extends StatelessWidget {
  const _Metric({
    required this.label,
    required this.value,
    this.icon,
    this.warn = false,
  });

  final String label;
  final String value;
  final IconData? icon;
  final bool warn;

  @override
  Widget build(BuildContext context) {
    final valueColor =
        warn ? BlowfitColors.red500 : BlowfitColors.ink;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: BlowfitColors.gray500,
          ),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 14, color: BlowfitColors.blue500),
              const SizedBox(width: 4),
            ],
            Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: valueColor,
                letterSpacing: -0.32,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _MetricDivider extends StatelessWidget {
  const _MetricDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      color: BlowfitColors.gray150,
      margin: const EdgeInsets.symmetric(horizontal: 4),
    );
  }
}

// ---------------------------------------------------------------------------
// Training CTA — 그라데이션 카드
// ---------------------------------------------------------------------------

class _TrainingCta extends StatelessWidget {
  const _TrainingCta({
    required this.connected,
    required this.orificeLevel,
    required this.onStart,
    required this.onConnect,
  });

  final bool connected;

  /// 0/1/2 (저/중/고) — 연결됐을 때만 의미 있음. null 이면 미표기.
  final int? orificeLevel;
  final VoidCallback onStart;
  final VoidCallback onConnect;

  @override
  Widget build(BuildContext context) {
    final action = connected ? onStart : onConnect;
    final actionLabel = connected ? '지금 훈련 시작' : '기기 연결';
    final actionIcon = connected ? Icons.play_arrow : Icons.bluetooth_searching;
    final subtitle = (connected && orificeLevel != null)
        ? '흡기·호기 3세트 · 다이얼 ${orificeLevel! + 1}단'
        : '흡기·호기 3세트';

    return Container(
      padding: const EdgeInsets.all(16),
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
              width: 130,
              height: 130,
              decoration: const BoxDecoration(
                color: Color.fromRGBO(255, 255, 255, 0.08),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            bottom: -28,
            right: 28,
            child: Container(
              width: 75,
              height: 75,
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
              const SizedBox(height: 5),
              const Text(
                '5분 호흡 훈련',
                style: TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  letterSpacing: -0.42,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 14,
                  color: Color.fromRGBO(255, 255, 255, 0.85),
                ),
              ),
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: action,
                icon: Icon(actionIcon, size: 18),
                label: Text(actionLabel),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: BlowfitColors.blue600,
                  minimumSize: const Size(0, 46),
                  padding: const EdgeInsets.symmetric(horizontal: 22),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(13),
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
  const _QuickStats({
    required this.weekHits,
    required this.thisWeekAvg,
    required this.lastWeekAvg,
    required this.onTap,
  });
  final int weekHits;

  /// 이번 주 평균 호기. 세션 없으면 null.
  final double? thisWeekAvg;

  /// 지난 주 평균 호기. 비교 기준.
  final double? lastWeekAvg;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ratio = (weekHits / 7).clamp(0.0, 1.0);
    final delta = (thisWeekAvg != null && lastWeekAvg != null)
        ? thisWeekAvg! - lastWeekAvg!
        : null;
    // IntrinsicHeight + stretch 로 두 카드의 높이를 가장 높은 카드 기준으로
    // 통일. 이번 주 카드의 진행바는 Spacer 로 카드 하단에 정렬.
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: BlowfitCard(
              onTap: onTap,
              padding: const EdgeInsets.all(13),
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
                  const SizedBox(height: 5),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        '$weekHits',
                        style: const TextStyle(
                          fontSize: 23,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.46,
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
                  const Spacer(),
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
              padding: const EdgeInsets.all(13),
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
                  const SizedBox(height: 5),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        thisWeekAvg != null
                            ? thisWeekAvg!.toStringAsFixed(1)
                            : '—',
                        style: const TextStyle(
                          fontSize: 23,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.46,
                          color: BlowfitColors.ink,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Text(
                        'cmH₂O',
                        style: TextStyle(
                          fontSize: 13,
                          color: BlowfitColors.ink3,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  _DeltaRow(delta: delta),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 평균 호기 압력 카드의 델타 줄.
/// 비교 데이터 부족하면 안내 텍스트.
class _DeltaRow extends StatelessWidget {
  const _DeltaRow({required this.delta});
  final double? delta;

  @override
  Widget build(BuildContext context) {
    if (delta == null) {
      return const Text(
        '비교 데이터 더 필요',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: BlowfitColors.ink3,
        ),
      );
    }
    final positive = delta! > 0;
    final negative = delta! < 0;
    final color = positive
        ? BlowfitColors.green500
        : negative
            ? BlowfitColors.red500
            : BlowfitColors.ink3;
    final sign = positive ? '+' : '';
    return Row(
      children: [
        if (positive)
          Icon(Icons.arrow_upward, size: 11, color: color)
        else if (negative)
          Icon(Icons.arrow_downward, size: 11, color: color),
        if (positive || negative) const SizedBox(width: 4),
        Text(
          '$sign${delta!.toStringAsFixed(1)} 지난주 대비',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: color,
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
  const _CoachingCard({required this.tip, required this.onTap});
  final CoachingTip tip;
  final VoidCallback onTap;

  /// 톤별 색상/아이콘 — positive 초록, info 파랑, warning 주황.
  ({Color bg, Color ink, IconData icon}) get _styleTokens {
    switch (tip.tone) {
      case CoachingTone.positive:
        return (
          bg: BlowfitColors.green100,
          ink: BlowfitColors.greenInk,
          icon: Icons.emoji_events,
        );
      case CoachingTone.info:
        return (
          bg: BlowfitColors.blue50,
          ink: BlowfitColors.blue700,
          icon: Icons.lightbulb_outline,
        );
      case CoachingTone.warning:
        return (
          bg: BlowfitColors.amberBg,
          ink: BlowfitColors.amberInk,
          icon: Icons.warning_amber_outlined,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = _styleTokens;
    return BlowfitCard(
      onTap: onTap,
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: t.bg,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(t.icon, color: t.ink, size: 19),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tip.eyebrow,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: t.ink,
                    letterSpacing: 0.24,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  tip.body,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    height: 1.42,
                    color: BlowfitColors.ink,
                  ),
                ),
                const SizedBox(height: 7),
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
