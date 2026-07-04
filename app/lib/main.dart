import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() {
  runApp(const ProviderScope(child: DuoBudgetApp()));
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
