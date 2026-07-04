import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'data/app_runtime.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final overrides = await buildDataLayerOverrides();
  runApp(ProviderScope(overrides: overrides, child: const DuoBudgetApp()));
}

/// Root of the DuoBudget application.
///
/// This is an intentionally minimal shell created during project
/// initialization. Features are added under `lib/features/`, with all derived
/// state coming from the domain reducer.
class DuoBudgetApp extends StatelessWidget {
  const DuoBudgetApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DuoBudget',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      home: const _Placeholder(),
    );
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('DuoBudget')),
      body: const Center(
        child: Text('DuoBudget — setup complete.'),
      ),
    );
  }
}
