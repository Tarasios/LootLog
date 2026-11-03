import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_router.dart';
import 'data/app_runtime.dart';
import 'data/sync/sync_service.dart';
import 'features/settings/play_mode_providers.dart';
import 'game/ui/kit/adventure_theme.dart';
import 'ui/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final overrides = await buildDataLayerOverrides();
  runApp(ProviderScope(overrides: overrides, child: const LootLogApp()));
}

/// The theme this device's adult sees: the [AdventureTheme] (one look for
/// both brightnesses) when they play Adventure, otherwise the Standard
/// [AppTheme] for [brightness], untouched.
ThemeData appThemeFor({required bool adventure, required Brightness brightness}) {
  if (adventure) return AdventureTheme.build();
  return brightness == Brightness.dark ? AppTheme.dark() : AppTheme.light();
}

/// Root of the LootLog application. Screens build from the shared [AppTheme]
/// for a Standard adult and from the [AdventureTheme] for an Adventure one;
/// go_router routes between first-run setup and the main shell.
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
    final adventure = ref.watch(isAdventureProvider);
    return MaterialApp.router(
      title: 'LootLog',
      theme: appThemeFor(adventure: adventure, brightness: Brightness.light),
      darkTheme: appThemeFor(adventure: adventure, brightness: Brightness.dark),
      routerConfig: router,
    );
  }
}
