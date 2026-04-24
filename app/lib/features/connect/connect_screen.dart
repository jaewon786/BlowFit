import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/ble/ble_providers.dart';

class ConnectScreen extends ConsumerStatefulWidget {
  const ConnectScreen({super.key});

  @override
  ConsumerState<ConnectScreen> createState() => _ConnectScreenState();
}

class _ConnectScreenState extends ConsumerState<ConnectScreen> {
  List<ScanResult> _results = [];
  bool _scanning = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scan());
  }

  Future<void> _scan() async {
    setState(() { _scanning = true; _error = null; });
    try {
      final ble = ref.read(bleManagerProvider);
      final r = await ble.scan();
      setState(() => _results = r);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _scanning = false);
    }
  }

  Future<void> _connect(BluetoothDevice d) async {
    try {
      await ref.read(bleManagerProvider).connect(d);
      if (mounted) context.go('/');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('연결 실패: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('기기 연결'),
        actions: [
          IconButton(
            icon: _scanning
                ? const SizedBox(width: 20, height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),)
                : const Icon(Icons.refresh),
            onPressed: _scanning ? null : _scan,
          ),
        ],
      ),
      body: _error != null
          ? Center(child: Text('오류: $_error'))
          : _results.isEmpty && !_scanning
              ? const Center(child: Text('기기를 찾을 수 없습니다.\n\n'
                  '기기 전원이 켜져 있고 블루투스가 활성화되어 있는지 확인하세요.'))
              : ListView.separated(
                  itemCount: _results.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final r = _results[i];
                    final name = r.device.platformName.isNotEmpty
                        ? r.device.platformName
                        : r.device.remoteId.str;
                    return ListTile(
                      leading: const Icon(Icons.bluetooth),
                      title: Text(name),
                      subtitle: Text('RSSI ${r.rssi}'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _connect(r.device),
                    );
                  },
                ),
    );
  }
}
