import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'data/app_runtime.dart';
import 'data/providers.dart';
import 'features/home/home_screen.dart';
import 'features/setup/setup_screen.dart';
import 'ui/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final overrides = await buildDataLayerOverrides();
  runApp(ProviderScope(overrides: overrides, child: const DuoBudgetApp()));
}

/// Root of the DuoBudget application. All screens build from the shared
/// [AppTheme]; derived state comes from the domain reducer via providers.
class DuoBudgetApp extends StatelessWidget {
  const DuoBudgetApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DuoBudget',
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      home: const _Root(),
    );
  }
}

/// Shows first-run setup until the device is configured, then the home screen.
class _Root extends ConsumerWidget {
  const _Root();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final setup = ref.watch(localSetupProvider);
    return setup.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(body: Center(child: Text('$e'))),
      data: (value) =>
          value == null ? const SetupScreen() : const HomeScreen(),
    );
  }
}
