/// The "Manage" hub: a single entry point (from the app bar) to everything that
/// is not day-to-day expense entry — budget setup, quests, the war chest, net
/// worth (flag-gated), and settings. Kept out of the primary navigation so the
/// three main panes stay focused.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../../ui/theme.dart';
import '../budget_setup/budget_setup_screen.dart';
import '../networth/networth_screen.dart';
import '../quests/quests_screen.dart';
import '../settings/settings_screen.dart';
import '../warchest/warchest_screen.dart';

class ManageScreen extends ConsumerWidget {
  const ManageScreen({super.key});

  /// Pushes the manage hub onto the navigator.
  static Future<void> open(BuildContext context) => Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const ManageScreen()),
      );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(householdStateProvider).value;
    final showNetWorth = state?.netWorth.show ?? false;
    return Scaffold(
      appBar: AppBar(title: const Text('Manage')),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        children: [
          _Entry(
            icon: Icons.tune,
            title: 'Budget setup',
            subtitle: "Both members' slices, side by side",
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const BudgetSetupScreen()),
            ),
          ),
          _Entry(
            icon: Icons.flag_outlined,
            title: 'Quests',
            subtitle: 'Savings goals and their progress',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const QuestsScreen()),
            ),
          ),
          _Entry(
            icon: Icons.account_balance_outlined,
            title: 'War chest',
            subtitle: 'The shared pool, writs, gifts and refunds',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const WarChestScreen()),
            ),
          ),
          if (showNetWorth)
            _Entry(
              icon: Icons.trending_up,
              title: 'Net worth',
              subtitle: 'Manual accounts and balances',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const NetWorthScreen()),
              ),
            ),
          const Divider(),
          _Entry(
            icon: Icons.settings_outlined,
            title: 'Settings',
            subtitle: 'Income, recurring expenses, funds, pets, rules',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const SettingsScreen()),
            ),
          ),
        ],
      ),
    );
  }
}

class _Entry extends StatelessWidget {
  const _Entry({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}
