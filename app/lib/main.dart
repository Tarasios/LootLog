import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() {
  runApp(const ProviderScope(child: DuoBudgetApp()));
}

/// Root of the DuoBudget application.
///
/// Feature screens (expense entry, status, goals, net worth) are added in
/// later phases; this shell only establishes the Material + Riverpod wiring.
class DuoBudgetApp extends StatelessWidget {
  const DuoBudgetApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DuoBudget',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      home: const _PlaceholderHome(),
    );
  }
}

class _PlaceholderHome extends StatelessWidget {
  const _PlaceholderHome();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('DuoBudget')),
      body: const Center(child: Text('Setup complete.')),
    );
  }
}
