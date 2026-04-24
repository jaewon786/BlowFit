import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:permission_handler/permission_handler.dart';

import 'core/db/db_providers.dart';
import 'features/connect/connect_screen.dart';
import 'features/dashboard/dashboard_screen.dart';
import 'features/history/history_screen.dart';
import 'features/training/training_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('ko');
  await _requestBlePermissions();
  runApp(const ProviderScope(child: BlowfitApp()));
}

Future<void> _requestBlePermissions() async {
  await [
    Permission.bluetoothScan,
    Permission.bluetoothConnect,
    Permission.location,
  ].request();
}

final _router = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(path: '/',         builder: (_, __) => const DashboardScreen()),
    GoRoute(path: '/connect',  builder: (_, __) => const ConnectScreen()),
    GoRoute(path: '/training', builder: (_, __) => const TrainingScreen()),
    GoRoute(path: '/history',  builder: (_, __) => const HistoryScreen()),
  ],
);

class BlowfitApp extends ConsumerWidget {
  const BlowfitApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Wire BLE session summaries into the local DB for the lifetime of the app.
    ref.watch(sessionPersistenceProvider);
    return MaterialApp.router(
      title: 'BlowFit',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0F766E),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      routerConfig: _router,
    );
  }
}
