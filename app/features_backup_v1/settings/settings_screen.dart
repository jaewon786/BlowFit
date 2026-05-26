import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/ble/ble_providers.dart';
import '../../core/storage/last_device_store.dart';
import '../../core/storage/storage_providers.dart';

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
