import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_router.dart';
import 'data/app_runtime.dart';
import 'data/sync/sync_service.dart';
import 'ui/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final overrides = await buildDataLayerOverrides();
  runApp(ProviderScope(overrides: overrides, child: const LootLogApp()));
}

/// Root of the LootLog application. All screens build from the shared
/// [AppTheme]; go_router routes between first-run setup and the main shell.
class LootLogApp extends ConsumerWidget {
  const LootLogApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(goRouterProvider);
    // Kick off background sync once setup exists: reading the service binds it to
    // the store and its idempotent start() begins the periodic cycle. It runs
    // only when hubs are paired and is silent-but-visible via the status chip.
    final syncService = ref.watch(syncServiceProvider);
    if (syncService != null) {
      unawaited(syncService.start());
    }
    return MaterialApp.router(
      title: 'LootLog',
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      routerConfig: router,
    );
  }
}
