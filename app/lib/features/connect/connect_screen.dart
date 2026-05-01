import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/ble/ble_permissions.dart';
import '../../core/ble/ble_providers.dart';
import '../../core/ble/discovered_device.dart';
import '../../core/storage/last_device_store.dart';
import '../../core/storage/storage_providers.dart';

sealed class _ConnectStatus {
  const _ConnectStatus();
}

class _Initializing extends _ConnectStatus { const _Initializing(); }
class _PermissionsNeeded extends _ConnectStatus {
  final bool permanent;
  const _PermissionsNeeded({required this.permanent});
}
class _AutoReconnecting extends _ConnectStatus {
  final LastDevice device;
  const _AutoReconnecting(this.device);
}
class _Scanning extends _ConnectStatus { const _Scanning(); }
class _Results extends _ConnectStatus {
  final List<DiscoveredDevice> devices;
  const _Results(this.devices);
}
class _Empty extends _ConnectStatus { const _Empty(); }
class _Failed extends _ConnectStatus {
  final String message;
  final bool btOff;
  const _Failed(this.message, {this.btOff = false});
}

class ConnectScreen extends ConsumerStatefulWidget {
  const ConnectScreen({super.key});

  @override
  ConsumerState<ConnectScreen> createState() => _ConnectScreenState();
}

class _ConnectScreenState extends ConsumerState<ConnectScreen> {
  _ConnectStatus _status = const _Initializing();
  bool _connecting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  Future<void> _bootstrap() async {
    final perm = await BlePermissions.request();
    switch (perm) {
      case BlePermissionStatus.granted:
      case BlePermissionStatus.notApplicable:
        await _scanAndMaybeAutoConnect();
      case BlePermissionStatus.denied:
        if (mounted) setState(() => _status = const _PermissionsNeeded(permanent: false));
      case BlePermissionStatus.permanentlyDenied:
        if (mounted) setState(() => _status = const _PermissionsNeeded(permanent: true));
    }
  }

  Future<void> _scanAndMaybeAutoConnect() async {
    if (!mounted) return;
    setState(() => _status = const _Scanning());

    final List<DiscoveredDevice> devices;
    try {
      devices = await ref.read(bleManagerProvider).scan();
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString();
      final btOff = msg.toLowerCase().contains('off') ||
          msg.toLowerCase().contains('disabled') ||
          msg.toLowerCase().contains('bluetoothoff');
      setState(() => _status = _Failed(msg, btOff: btOff));
      return;
    }

    if (!mounted) return;

    // Try silent auto-reconnect to the previously paired device.
    final storeAsync = ref.read(lastDeviceStoreProvider);
    final store = storeAsync.valueOrNull;
    final saved = store?.load();
    if (saved != null) {
      final match = devices.where((d) => d.id == saved.id).firstOrNull;
      if (match != null) {
        setState(() => _status = _AutoReconnecting(saved));
        final ok = await _attemptConnect(match, silent: true);
        if (ok) return; // navigation already happened
        if (!mounted) return;
      }
    }

    setState(() {
      _status = devices.isEmpty ? const _Empty() : _Results(devices);
    });
  }

  /// Returns true on success (and navigates away). On failure shows a
  /// snackbar (unless silent) and leaves the user on this screen.
  Future<bool> _attemptConnect(DiscoveredDevice d, {bool silent = false}) async {
    setState(() => _connecting = true);
    try {
      await ref.read(bleManagerProvider).connect(d);
      final store = await ref.read(lastDeviceStoreProvider.future);
      await store.save(LastDevice(id: d.id, name: d.name));
      if (!mounted) return true;
      if (context.canPop()) {
        context.pop();
      } else {
        context.go('/');
      }
      return true;
    } catch (e) {
      if (mounted && !silent) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('연결 실패: $e')),
        );
      }
      return false;
    } finally {
      if (mounted) setState(() => _connecting = false);
    }
  }

  Future<void> _retry() async {
    await _bootstrap();
  }

  Future<void> _forgetDevice() async {
    final store = await ref.read(lastDeviceStoreProvider.future);
    await store.clear();
    if (!mounted) return;
    setState(() {}); // refresh "hasSaved" badge
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('이전 기기 정보를 삭제했습니다.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final canRescan = _status is _Results || _status is _Empty || _status is _Failed;
    final hasSaved = ref.watch(lastDeviceStoreProvider).valueOrNull?.load() != null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('기기 연결'),
        actions: [
          if (hasSaved && canRescan)
            IconButton(
              tooltip: '이전 기기 정보 삭제',
              icon: const Icon(Icons.link_off),
              onPressed: _forgetDevice,
            ),
          IconButton(
            tooltip: '다시 스캔',
            icon: _status is _Scanning || _status is _AutoReconnecting
                ? const SizedBox(
                    width: 20, height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh),
            onPressed: canRescan && !_connecting ? _retry : null,
          ),
        ],
      ),
      body: SafeArea(child: _buildBody()),
    );
  }

  Widget _buildBody() {
    switch (_status) {
      case _Initializing():
        return const Center(child: CircularProgressIndicator());
      case _Scanning():
        return _centeredMessage(
          const CircularProgressIndicator(),
          '주변 기기를 스캔 중...',
        );
      case _AutoReconnecting(:final device):
        return _centeredMessage(
          const CircularProgressIndicator(),
          '이전 기기에 다시 연결 중...\n${device.name}',
        );
      case _PermissionsNeeded(:final permanent):
        return _PermissionsView(
          permanent: permanent,
          onRetry: _retry,
          onOpenSettings: BlePermissions.openSettings,
        );
      case _Failed(:final message, :final btOff):
        return _FailedView(message: message, btOff: btOff, onRetry: _retry);
      case _Empty():
        return _EmptyView(onRetry: _retry);
      case _Results(:final devices):
        return ListView.separated(
          itemCount: devices.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (_, i) {
            final r = devices[i];
            return ListTile(
              leading: const Icon(Icons.bluetooth),
              title: Text(r.name.isNotEmpty ? r.name : r.id),
              subtitle: Text('RSSI ${r.rssi}'),
              trailing: _connecting
                  ? const SizedBox(
                      width: 20, height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.chevron_right),
              onTap: _connecting ? null : () => _attemptConnect(r),
            );
          },
        );
    }
  }

  Widget _centeredMessage(Widget icon, String message) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(width: 48, height: 48, child: icon),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(message, textAlign: TextAlign.center),
            ),
          ],
        ),
      );
}

class _PermissionsView extends StatelessWidget {
  const _PermissionsView({
    required this.permanent,
    required this.onRetry,
    required this.onOpenSettings,
  });

  final bool permanent;
  final VoidCallback onRetry;
  final Future<bool> Function() onOpenSettings;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.bluetooth_disabled, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text(
              '블루투스 권한이 필요합니다',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              permanent
                  ? '시스템 설정에서 블루투스 / 위치 권한을 허용해주세요.'
                  : 'BlowFit 기기를 검색하려면 블루투스 권한을 허용해야 합니다.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.black54),
            ),
            const SizedBox(height: 24),
            if (permanent)
              FilledButton.icon(
                onPressed: onOpenSettings,
                icon: const Icon(Icons.settings),
                label: const Text('설정 열기'),
              )
            else
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.check),
                label: const Text('권한 허용'),
              ),
          ],
        ),
      ),
    );
  }
}

class _FailedView extends StatelessWidget {
  const _FailedView({
    required this.message,
    required this.btOff,
    required this.onRetry,
  });

  final String message;
  final bool btOff;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              btOff ? Icons.bluetooth_disabled : Icons.error_outline,
              size: 64,
              color: Colors.orange,
            ),
            const SizedBox(height: 16),
            Text(
              btOff ? '블루투스가 꺼져 있습니다' : '스캔 중 오류가 발생했습니다',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              btOff
                  ? '시스템 블루투스를 켠 뒤 다시 시도해주세요.'
                  : message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.black54),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('다시 시도'),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyView extends StatelessWidget {
  const _EmptyView({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.search_off, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text(
              '기기를 찾을 수 없습니다',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            const _TroubleshootingTip(
              icon: Icons.power,
              text: 'BlowFit 기기 전원이 켜져 있는지 확인하세요.',
            ),
            const _TroubleshootingTip(
              icon: Icons.bluetooth,
              text: '폰의 블루투스가 활성화되어 있는지 확인하세요.',
            ),
            const _TroubleshootingTip(
              icon: Icons.social_distance,
              text: '기기와 폰을 1m 이내로 가까이 두세요.',
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('다시 스캔'),
            ),
          ],
        ),
      ),
    );
  }
}

class _TroubleshootingTip extends StatelessWidget {
  const _TroubleshootingTip({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: Colors.black54),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text, style: const TextStyle(color: Colors.black54)),
          ),
        ],
      ),
    );
  }
}
