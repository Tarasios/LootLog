/// The guild hall — the Adventure-mode home screen. A placeholder for now.
///
/// Built only behind the Adventure mode gate (`features/shell/home_gate.dart`);
/// Standard mode never constructs it. Navigation back to the ledger is handed
/// in as a callback so the game layer never depends on the app shell.
library;

import 'package:flutter/material.dart';

class GameHome extends StatelessWidget {
  const GameHome({super.key, required this.onOpenLedger});

  /// Opens the budgeting ledger (logging, budgets, settings).
  final VoidCallback onOpenLedger;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Guild hall'),
        automaticallyImplyLeading: false,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.castle_outlined, size: 64),
              const SizedBox(height: 16),
              Text('Guild hall coming soon', style: textTheme.headlineSmall),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: onOpenLedger,
                icon: const Icon(Icons.receipt_long),
                label: const Text('Open the ledger'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
