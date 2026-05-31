import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/ble/ble_providers.dart';
import '../../core/storage/last_device_store.dart';
import '../../core/storage/storage_providers.dart';
import '../../core/storage/train_duration_store.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  // pubspec.yaml `version` 과 동기화. 릴리즈마다 갱신.
  static const _appVersion = '0.1.0';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connected = ref.watch(connectionProvider).valueOrNull ?? false;
    final state = ref.watch(deviceStateProvider).valueOrNull;
    final lastDevice = ref.watch(lastDeviceStoreProvider).valueOrNull?.load();
    final targetZone = ref.watch(targetSettingsStoreProvider).valueOrNull?.load();
    final trainMinutes = ref.watch(trainDurationStoreProvider).valueOrNull?.loadMinutes() ??
        TrainDurationStore.defaultMinutes;
    // 펌웨어 버전은 BLE Device Information characteristic 으로 보고되지만 현재
    // 미파싱 상태. 연결됐을 때만 placeholder 를 보여주고, 미연결이면 공란.
    final fwVersion = connected && state != null ? '확인 중' : '—';

    return Scaffold(
      appBar: AppBar(title: const Text('설정')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: 8),
          children: [
            _SectionGap(),
            _DeviceCard(
              connected: connected,
              device: lastDevice,
              onTap: () => context.push('/connect'),
            ),
            const _SectionGap(),
            _SettingsTile(
              icon: Icons.tune,
              label: '목표 압력 설정',
              trailing: targetZone == null
                  ? '— cmH₂O'
                  : '${targetZone.low}-${targetZone.high} cmH₂O',
              onTap: () => context.push('/settings/target'),
            ),
            _SettingsTile(
              icon: Icons.timer_outlined,
              label: '훈련 시간',
              trailing: '$trainMinutes분',
              onTap: () => _pickDuration(context, ref, trainMinutes),
            ),
            _SettingsTile(
              icon: Icons.notifications_none,
              label: '훈련 알림',
              trailing: '꺼짐',
              onTap: () => _comingSoon(context, '훈련 알림'),
            ),
            _SettingsTile(
              icon: Icons.swap_horiz,
              label: '오리피스 단계 관리',
              onTap: () => _comingSoon(context, '오리피스 단계 관리'),
            ),
            const _SectionGap(),
            _SettingsTile(
              icon: Icons.system_update_alt,
              label: '펌웨어 업데이트',
              trailing: fwVersion,
              onTap: () => _comingSoon(context, '펌웨어 업데이트'),
            ),
            _SettingsTile(
              icon: Icons.replay_outlined,
              label: '제품 소개 다시 보기',
              onTap: () => context.push('/onboarding'),
            ),
            _SettingsTile(
              icon: Icons.menu_book_outlined,
              label: '훈련 가이드 다시 보기',
              onTap: () => context.push('/guide'),
            ),
            _SettingsTile(
              icon: Icons.help_outline,
              label: '도움말',
              onTap: () => _comingSoon(context, '도움말'),
            ),
            _SettingsTile(
              icon: Icons.info_outline,
              label: '앱 정보',
              trailing: 'v$_appVersion',
              onTap: () => _showAbout(context),
            ),
            const _SectionGap(),
            _SettingsTile(
              icon: Icons.bedtime_outlined,
              label: '수면 효과',
              trailing: '베타',
              onTap: () => context.push('/sleep-effect'),
            ),
            // 개발용 — Samsung Health Data SDK 연동 검증.
            _SettingsTile(
              icon: Icons.watch_outlined,
              label: 'Samsung Health 연동 테스트',
              trailing: '개발용',
              onTap: () => context.push('/shealth-test'),
            ),
          ],
        ),
      ),
    );
  }

  void _comingSoon(BuildContext context, String label) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$label 기능은 곧 출시됩니다')),
    );
  }

  /// 훈련 시간(분) 선택 바텀시트. 선택 시 저장 + (연결됐으면) 기기로 전송.
  Future<void> _pickDuration(
    BuildContext context,
    WidgetRef ref,
    int current,
  ) async {
    final primary = Theme.of(context).colorScheme.primary;
    final selected = await showModalBottomSheet<int>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '훈련 시간 선택',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
            ),
            for (final m in TrainDurationStore.options)
              ListTile(
                title: Text('$m분'),
                trailing: m == current
                    ? Icon(Icons.check, color: primary)
                    : null,
                onTap: () => Navigator.of(ctx).pop(m),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (selected == null || selected == current) return;
    final store = await ref.read(trainDurationStoreProvider.future);
    await store.save(selected);
    ref.invalidate(trainDurationStoreProvider);
    // 연결돼 있으면 기기로 즉시 전송 (초 단위).
    final connected = ref.read(connectionProvider).valueOrNull ?? false;
    if (connected) {
      try {
        await ref.read(bleManagerProvider).setTrainDuration(selected * 60);
      } catch (_) {
        // 실패해도 다음 connect 때 targetSyncProvider 가 재전송.
      }
    }
  }

  void _showAbout(BuildContext context) {
    showAboutDialog(
      context: context,
      applicationName: 'BlowFit',
      applicationVersion: 'v$_appVersion',
      applicationIcon: const Icon(Icons.air, size: 32),
      applicationLegalese: '© 2026 한남대학교 디자인팩토리 CPD',
      children: const [
        SizedBox(height: 12),
        Text(
          '수면무호흡 개선용 호기 저항 훈련 스마트 기기의 컴패니언 앱입니다.',
          style: TextStyle(fontSize: 13),
        ),
      ],
    );
  }
}

class _DeviceCard extends StatelessWidget {
  const _DeviceCard({
    required this.connected,
    required this.device,
    required this.onTap,
  });

  final bool connected;
  final LastDevice? device;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final statusColor = connected ? Colors.green : Colors.grey;
    final deviceName = device?.name ?? '연결된 기기 없음';
    final deviceSubtitle = connected
        ? '연결됨'
        : (device == null ? '기기 연결을 시작하세요' : '연결 끊김');

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                color: primary.withOpacity(0.10),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.bluetooth, color: primary, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '내 기기',
                    style: TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    deviceName,
                    style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w600, color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Container(
                        width: 6, height: 6,
                        decoration: BoxDecoration(
                          color: statusColor, shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        deviceSubtitle,
                        style: TextStyle(fontSize: 12, color: statusColor),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.black38),
          ],
        ),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.label,
    this.trailing,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String? trailing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(icon, color: Colors.black54, size: 22),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(fontSize: 15, color: Colors.black87),
              ),
            ),
            if (trailing != null) ...[
              Text(
                trailing!,
                style: const TextStyle(fontSize: 13, color: Colors.black54),
              ),
              const SizedBox(width: 6),
            ],
            const Icon(Icons.chevron_right, color: Colors.black38, size: 20),
          ],
        ),
      ),
    );
  }
}

class _SectionGap extends StatelessWidget {
  const _SectionGap();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 8,
      color: const Color(0xFFF7F8FA),
    );
  }
}
