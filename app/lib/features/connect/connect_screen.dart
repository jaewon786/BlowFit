import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/ble/ble_error_translator.dart';
import '../../core/ble/ble_permissions.dart';
import '../../core/ble/ble_providers.dart';
import '../../core/ble/discovered_device.dart';
import '../../core/storage/last_device_store.dart';
import '../../core/storage/storage_providers.dart';
import '../../core/theme/blowfit_colors.dart';
import '../../core/theme/blowfit_widgets.dart';

/// Phase 5e+ — 디자인 시안의 02 화면 (`screens/onboarding.jsx` PairingScreen)
/// 비주얼로 풀 리라이트. 기존 권한 / 스캔 / 자동 재연결 로직은 그대로 유지.

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
  final BleErrorMessage error;
  const _Failed(this.error);
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

  // ---------------------------------------------------------------------------
  // Logic — 기존 동작 그대로 유지.
  // ---------------------------------------------------------------------------

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
      setState(() => _status = _Failed(BleErrorTranslator.translate(e)));
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
        if (ok) return;
        if (!mounted) return;
      }
    }

    setState(() {
      _status = devices.isEmpty ? const _Empty() : _Results(devices);
    });
  }

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

  Future<void> _retry() async => await _bootstrap();

  Future<void> _forgetDevice() async {
    final store = await ref.read(lastDeviceStoreProvider.future);
    await store.clear();
    if (!mounted) return;
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('이전 기기 정보를 삭제했습니다.')),
    );
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final canRescan =
        _status is _Results || _status is _Empty || _status is _Failed;
    final hasSaved =
        ref.watch(lastDeviceStoreProvider).valueOrNull?.load() != null;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: const Text('기기 연결'),
        actions: [
          if (hasSaved && canRescan)
            IconButton(
              tooltip: '이전 기기 정보 삭제',
              icon: const Icon(Icons.link_off,
                  color: BlowfitColors.gray700),
              onPressed: _forgetDevice,
            ),
          if (canRescan)
            IconButton(
              tooltip: '다시 스캔',
              icon: const Icon(Icons.refresh,
                  color: BlowfitColors.gray700),
              onPressed: _connecting ? null : _retry,
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
        return _PairingHero(
          state: _HeroState.scanning,
          title: '기기를 찾고 있어요',
          desc: '디바이스의 전원 버튼을 3초간\n눌러주세요.',
          buttonLabel: '기기를 검색 중...',
          buttonEnabled: false,
        );
      case _AutoReconnecting(:final device):
        return _PairingHero(
          state: _HeroState.found,
          title: '이전 기기에 다시 연결 중',
          desc: '${device.name}',
          buttonLabel: '연결 중...',
          buttonEnabled: false,
        );
      case _PermissionsNeeded(:final permanent):
        return _PermissionsView(
          permanent: permanent,
          onRetry: _retry,
          onOpenSettings: BlePermissions.openSettings,
        );
      case _Failed(:final error):
        return _FailedView(error: error, onRetry: _retry);
      case _Empty():
        return _EmptyView(onRetry: _retry);
      case _Results(:final devices):
        return _ResultsView(
          devices: devices,
          connecting: _connecting,
          onTap: _attemptConnect,
        );
    }
  }
}

// ---------------------------------------------------------------------------
// Shared layout — 온보딩 화면과 동일 (80 top spacer + 220×220 frame +
// 32 gap + 140 minHeight 텍스트). Pairing / Permissions / Failed / Empty
// 모두 이 레이아웃을 따라 로고와 텍스트가 같은 Y 위치에서 시작한다.
// ---------------------------------------------------------------------------

class _OnboardingStateLayout extends StatelessWidget {
  const _OnboardingStateLayout({
    required this.illustration,
    required this.title,
    required this.desc,
    required this.bottom,
  });

  /// 220×220 frame 안에 들어갈 일러스트 (보통 140×140 circle).
  final Widget illustration;
  final String title;
  final String desc;

  /// 화면 하단 — 버튼 / 도움말 카드 등.
  final Widget bottom;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          // ListView 로 감싸서 작은 화면에서 스크롤 보호. 기본은 스크롤 잠김.
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
            physics: const ClampingScrollPhysics(),
            children: [
              const SizedBox(height: 80),
              SizedBox(
                width: double.infinity,
                height: 220,
                child: Center(child: illustration),
              ),
              const SizedBox(height: 32),
              ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 140),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        height: 1.3,
                        letterSpacing: -0.84,
                        color: BlowfitColors.ink,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      desc,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 16,
                        color: BlowfitColors.ink2,
                        fontWeight: FontWeight.w500,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: bottom,
        ),
      ],
    );
  }
}

/// 140×140 원형 아이콘 컨테이너 — _OnboardingStateLayout 의 illustration
/// 슬롯에 들어가 220×220 frame 의 정중앙에 위치.
class _StateCircle extends StatelessWidget {
  const _StateCircle({
    required this.icon,
    required this.color,
    this.iconColor = Colors.white,
    this.iconSize = 56,
    this.glow,
  });

  final IconData icon;
  final Color color;
  final Color iconColor;
  final double iconSize;
  final Color? glow;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 140,
      height: 140,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        boxShadow: glow != null
            ? [
                BoxShadow(
                  color: glow!,
                  blurRadius: 40,
                  offset: const Offset(0, 16),
                ),
              ]
            : null,
      ),
      child: Icon(icon, size: iconSize, color: iconColor),
    );
  }
}

// ---------------------------------------------------------------------------
// Pairing hero — big BLE icon + ping rings + title/desc + bottom button
// ---------------------------------------------------------------------------

enum _HeroState { scanning, found, connected }

class _PairingHero extends StatelessWidget {
  const _PairingHero({
    required this.state,
    required this.title,
    required this.desc,
    required this.buttonLabel,
    required this.buttonEnabled,
  });

  final _HeroState state;
  final String title;
  final String desc;
  final String buttonLabel;
  final bool buttonEnabled;

  @override
  Widget build(BuildContext context) {
    final connected = state == _HeroState.connected;
    return _OnboardingStateLayout(
      illustration: SizedBox(
        width: 220,
        height: 220,
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (state == _HeroState.scanning) ...[
              _PingRing(delayMs: 0),
              _PingRing(delayMs: 700),
              _PingRing(delayMs: 1400),
            ],
            _StateCircle(
              icon: connected ? Icons.check : Icons.bluetooth,
              color: connected
                  ? BlowfitColors.green500
                  : BlowfitColors.blue500,
              iconSize: 64,
              glow: connected
                  ? const Color.fromRGBO(0, 191, 64, 0.30)
                  : const Color.fromRGBO(0, 102, 255, 0.30),
            ),
          ],
        ),
      ),
      title: title,
      desc: desc,
      bottom: SizedBox(
        width: double.infinity,
        child: FilledButton(
          // Hero button is informational-only in scanning / auto-reconnecting
          // states. Action buttons live on Permissions / Failed / Empty
          // views which have their own dedicated render path.
          onPressed: buttonEnabled ? () {} : null,
          child: Text(buttonLabel),
        ),
      ),
    );
  }
}

/// 스캐닝 중 hero 주위에서 펴져나가는 ring 펄스 애니메이션.
class _PingRing extends StatefulWidget {
  const _PingRing({required this.delayMs});
  final int delayMs;

  @override
  State<_PingRing> createState() => _PingRingState();
}

class _PingRingState extends State<_PingRing>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2100),
    );
    Future.delayed(Duration(milliseconds: widget.delayMs), () {
      if (!mounted) return;
      _controller.repeat();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (_, __) {
        // scale 0.5 → 1.2, opacity 1 → 0
        final t = _controller.value;
        final scale = 0.5 + t * 0.7;
        final opacity = 1 - t;
        return Transform.scale(
          scale: scale,
          child: Opacity(
            opacity: opacity,
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: BlowfitColors.blue300,
                  width: 2,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Results — found device list using BlowfitCard
// ---------------------------------------------------------------------------

class _ResultsView extends StatelessWidget {
  const _ResultsView({
    required this.devices,
    required this.connecting,
    required this.onTap,
  });

  final List<DiscoveredDevice> devices;
  final bool connecting;
  final Future<bool> Function(DiscoveredDevice) onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
      child: Column(
        children: [
          // 헤더 영역 — found 상태로 hero 사용.
          SizedBox(
            height: 200,
            child: Center(
              child: SizedBox(
                width: 140,
                height: 140,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: BlowfitColors.blue500,
                        boxShadow: const [
                          BoxShadow(
                            color: Color.fromRGBO(0, 102, 255, 0.30),
                            blurRadius: 40,
                            offset: Offset(0, 16),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.bluetooth,
                        size: 56,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const Text(
            '기기를 발견했어요',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.72,
              color: BlowfitColors.ink,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            devices.length == 1
                ? '아래 기기를 탭하여 연결하세요'
                : '${devices.length}개의 기기가 발견됨',
            style: const TextStyle(
              fontSize: 14,
              color: BlowfitColors.ink2,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ListView.separated(
              padding: EdgeInsets.zero,
              itemCount: devices.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (_, i) {
                final d = devices[i];
                return _DeviceCard(
                  device: d,
                  connecting: connecting,
                  onTap: () => onTap(d),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _DeviceCard extends StatelessWidget {
  const _DeviceCard({
    required this.device,
    required this.connecting,
    required this.onTap,
  });

  final DiscoveredDevice device;
  final bool connecting;
  final VoidCallback onTap;

  String get _signal {
    final r = device.rssi;
    if (r >= -60) return '신호 강함';
    if (r >= -80) return '신호 보통';
    return '신호 약함';
  }

  @override
  Widget build(BuildContext context) {
    return BlowfitCard(
      onTap: connecting ? null : onTap,
      padding: const EdgeInsets.all(14),
      color: BlowfitColors.blue50,
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: BlowfitColors.blue500,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.air, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  device.name.isNotEmpty ? device.name : 'BlowFit',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: BlowfitColors.ink,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  '${device.id} · $_signal',
                  style: const TextStyle(
                    fontSize: 12,
                    color: BlowfitColors.ink3,
                  ),
                ),
              ],
            ),
          ),
          if (connecting)
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            const Icon(Icons.chevron_right,
                size: 20, color: BlowfitColors.gray400),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Permissions / Failed / Empty — same hero structure with state-specific
// content.
// ---------------------------------------------------------------------------

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
    return _OnboardingStateLayout(
      illustration: const _StateCircle(
        icon: Icons.bluetooth_disabled,
        color: BlowfitColors.gray100,
        iconColor: BlowfitColors.gray500,
      ),
      title: '블루투스 권한이 필요합니다',
      desc: permanent
          ? '시스템 설정에서 블루투스 / 위치 권한을\n허용해주세요.'
          : 'BlowFit 기기를 검색하려면 블루투스 권한을\n허용해야 합니다.',
      bottom: SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          onPressed: permanent
              ? () async {
                  await onOpenSettings();
                }
              : onRetry,
          icon: Icon(permanent ? Icons.settings : Icons.check),
          label: Text(permanent ? '설정 열기' : '권한 허용'),
        ),
      ),
    );
  }
}

class _FailedView extends StatefulWidget {
  const _FailedView({required this.error, required this.onRetry});

  final BleErrorMessage error;
  final VoidCallback onRetry;

  @override
  State<_FailedView> createState() => _FailedViewState();
}

class _FailedViewState extends State<_FailedView> {
  bool _showDetails = false;

  IconData get _icon {
    return switch (widget.error.category) {
      BleErrorCategory.btOff => Icons.bluetooth_disabled,
      BleErrorCategory.permission => Icons.lock_outline,
      BleErrorCategory.locationOff => Icons.location_off_outlined,
      BleErrorCategory.scanThrottled => Icons.timer_outlined,
      BleErrorCategory.timeout => Icons.hourglass_empty,
      BleErrorCategory.generic => Icons.error_outline,
    };
  }

  @override
  Widget build(BuildContext context) {
    final err = widget.error;
    return _OnboardingStateLayout(
      illustration: _StateCircle(
        icon: _icon,
        color: BlowfitColors.amberBg,
        iconColor: BlowfitColors.amber500,
      ),
      title: err.title,
      desc: err.desc,
      bottom: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 디버그용 raw 메시지 expandable — 진단을 위해 위치만 옮기고 유지.
          TextButton(
            onPressed: () =>
                setState(() => _showDetails = !_showDetails),
            child: Text(
              _showDetails ? '자세히 닫기' : '자세히',
              style: const TextStyle(
                fontSize: 12,
                color: BlowfitColors.ink3,
              ),
            ),
          ),
          if (_showDetails) ...[
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: BlowfitColors.gray100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: SelectableText(
                err.details,
                style: const TextStyle(
                  fontSize: 11,
                  color: BlowfitColors.ink3,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 8),
          ],
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: widget.onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('다시 시도'),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyView extends StatelessWidget {
  const _EmptyView({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return _OnboardingStateLayout(
      illustration: const _StateCircle(
        icon: Icons.search_off,
        color: BlowfitColors.gray100,
        iconColor: BlowfitColors.gray500,
      ),
      title: '기기를 찾을 수 없습니다',
      desc: '아래 사항을 확인하고 다시 시도해주세요.',
      bottom: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          BlowfitCard(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: const [
                _Tip(icon: Icons.power, text: 'BlowFit 기기 전원이 켜져 있는지 확인하세요.'),
                SizedBox(height: 8),
                _Tip(icon: Icons.bluetooth, text: '폰의 블루투스가 활성화되어 있는지 확인하세요.'),
                SizedBox(height: 8),
                _Tip(icon: Icons.social_distance, text: '기기와 폰을 1m 이내로 가까이 두세요.'),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('다시 스캔'),
            ),
          ),
        ],
      ),
    );
  }
}

class _Tip extends StatelessWidget {
  const _Tip({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: BlowfitColors.blue500),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 13,
              color: BlowfitColors.ink2,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}
