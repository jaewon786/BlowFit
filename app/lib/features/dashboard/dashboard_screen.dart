import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/ble/ble_providers.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connected = ref.watch(connectionProvider).valueOrNull ?? false;
    final state = ref.watch(deviceStateProvider).valueOrNull;

    return Scaffold(
      appBar: AppBar(
        title: const Text('풍선 운동 디바이스'),
        actions: [
          IconButton(
            tooltip: '훈련 기록',
            icon: const Icon(Icons.show_chart),
            onPressed: () => context.go('/history'),
          ),
          IconButton(
            tooltip: '기기 연결',
            icon: Icon(connected ? Icons.bluetooth_connected : Icons.bluetooth_disabled),
            onPressed: () => context.go('/connect'),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('오늘의 목표',
                        style: TextStyle(fontSize: 14, color: Colors.white70)),
                    const SizedBox(height: 8),
                    const Text('20분 훈련 · 15초 × 10회 유지',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    LinearProgressIndicator(
                      value: 0.0,  // wire up to session history
                      minHeight: 8,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _StatCard(label: '연속 일수', value: '0', unit: '일'),
                const SizedBox(width: 8),
                _StatCard(label: '주간 달성', value: '0', unit: '/7'),
                const SizedBox(width: 8),
                _StatCard(label: '배터리',
                  value: '${state?.batteryPct ?? 0}', unit: '%',),
              ],
            ),
            const Spacer(),
            FilledButton.icon(
              onPressed: connected ? () => context.go('/training') : null,
              icon: const Icon(Icons.play_arrow),
              label: const Text('훈련 시작'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 20),
                textStyle: const TextStyle(fontSize: 18),
              ),
            ),
            if (!connected) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () => context.go('/connect'),
                icon: const Icon(Icons.bluetooth_searching),
                label: const Text('기기 연결'),
              ),
            ],
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
  const _StatCard({required this.label, required this.value, required this.unit});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              Text(label, style: const TextStyle(fontSize: 12, color: Colors.white70)),
              const SizedBox(height: 6),
              RichText(
                text: TextSpan(
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  children: [
                    TextSpan(text: value),
                    TextSpan(text: unit,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.normal),),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
