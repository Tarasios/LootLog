import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_router.dart';
import 'data/app_runtime.dart';
import 'ui/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final overrides = await buildDataLayerOverrides();
  runApp(ProviderScope(overrides: overrides, child: const DuoBudgetApp()));
}

/// Root of the DuoBudget application. All screens build from the shared
/// [AppTheme]; go_router routes between first-run setup and the main shell.
class DuoBudgetApp extends ConsumerWidget {
  const DuoBudgetApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(goRouterProvider);
    return MaterialApp.router(
      title: 'DuoBudget',
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      routerConfig: router,
    );
  }
}
