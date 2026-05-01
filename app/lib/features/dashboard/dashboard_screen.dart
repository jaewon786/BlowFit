import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/ble/ble_providers.dart';
import '../../core/db/db_providers.dart';
import '../../core/models/pressure_sample.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  static const _dailyTargetMinutes = 20;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connected = ref.watch(connectionProvider).valueOrNull ?? false;
    final state = ref.watch(deviceStateProvider).valueOrNull;
    final lowBattery = state != null && (state.lowBattery || state.batteryPct < 20);
    final consecutiveDays = ref.watch(consecutiveDaysProvider).valueOrNull ?? 0;
    final weekHits = ref.watch(weekHitsProvider).valueOrNull ?? 0;
    final weekRatePct = (weekHits / 7 * 100).round();
    final todayDuration = ref.watch(todayDurationProvider).valueOrNull ?? Duration.zero;
    final todayMinutes = todayDuration.inSeconds / 60.0;
    final progress = (todayMinutes / _dailyTargetMinutes).clamp(0.0, 1.0);
    final isGoalReached = todayMinutes >= _dailyTargetMinutes;

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          children: [
            const _Header(),
            const SizedBox(height: 16),
            if (lowBattery && connected) ...[
              _LowBatteryBanner(snapshot: state),
              const SizedBox(height: 12),
            ],
            _GoalCard(
              progress: progress,
              todayMinutes: todayMinutes,
              targetMinutes: _dailyTargetMinutes,
              isGoalReached: isGoalReached,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _StatCard(
                    label: '연속 사용일',
                    value: '$consecutiveDays',
                    unit: '일',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatCard(
                    label: '주간 달성률',
                    value: '$weekRatePct',
                    unit: '%',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            const Text(
              '빠른 시작',
              style: TextStyle(fontSize: 14, color: Colors.black54),
            ),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: connected ? () => context.push('/training') : null,
              icon: const Icon(Icons.play_arrow),
              label: const Text('훈련 시작'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 18),
                textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
            if (!connected) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () => context.push('/connect'),
                icon: const Icon(Icons.bluetooth_searching),
                label: const Text('기기 연결'),
              ),
              const SizedBox(height: 4),
              const Text(
                '기기를 먼저 연결해주세요',
                style: TextStyle(fontSize: 12, color: Colors.black45),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(Icons.air, color: primary, size: 24),
          const SizedBox(width: 6),
          Text(
            'BlowFit',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: primary,
            ),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.notifications_none, color: Colors.black54),
            onPressed: () {
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

class _GoalCard extends StatelessWidget {
  const _GoalCard({
    required this.progress,
    required this.todayMinutes,
    required this.targetMinutes,
    required this.isGoalReached,
  });

  final double progress;
  final double todayMinutes;
  final int targetMinutes;
  final bool isGoalReached;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final goalColor = isGoalReached ? Colors.green : primary;

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 24),
        child: Column(
          children: [
            const Text(
              '오늘 목표',
              style: TextStyle(fontSize: 14, color: Colors.black54),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: 160,
              height: 160,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox.expand(
                    child: CircularProgressIndicator(
                      value: progress,
                      strokeWidth: 14,
                      strokeCap: StrokeCap.round,
                      backgroundColor: Colors.grey.shade200,
                      valueColor: AlwaysStoppedAnimation<Color>(goalColor),
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      RichText(
                        text: TextSpan(
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                          children: [
                            TextSpan(text: todayMinutes.toStringAsFixed(0)),
                            TextSpan(
                              text: ' / $targetMinutes분',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                color: Colors.black54,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              isGoalReached ? '목표 달성!' : '오늘도 화이팅!',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: goalColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final String unit;
  const _StatCard({
    required this.label,
    required this.value,
    required this.unit,
  });

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
        child: Column(
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 12, color: Colors.black54),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                const SizedBox(width: 2),
                Text(
                  unit,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: color,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _LowBatteryBanner extends StatelessWidget {
  const _LowBatteryBanner({required this.snapshot});
  final DeviceSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        border: Border.all(color: Colors.redAccent),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            snapshot.charging ? Icons.battery_charging_full : Icons.battery_alert,
            color: Colors.redAccent,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              snapshot.charging
                  ? '배터리 부족 — 충전 중입니다 (${snapshot.batteryPct}%)'
                  : '배터리 잔량이 ${snapshot.batteryPct}% 입니다. 곧 충전해주세요.',
              style: const TextStyle(
                color: Colors.redAccent,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
