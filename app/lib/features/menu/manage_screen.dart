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
import '../homestead/homestead_screen.dart';
import '../ledger/change_log_screen.dart';
import '../networth/networth_screen.dart';
import '../quests/quests_screen.dart';
import '../rewards/trophy_hall_screen.dart';
import '../settings/emergency_funds_screen.dart';
import '../settings/settings_screen.dart';
import '../sync/sync_hubs_screen.dart';
import '../vacation/vacation_screen.dart';
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
            subtitle: "Both members' categories, side by side",
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const BudgetSetupScreen()),
            ),
          ),
          _Entry(
            icon: Icons.flag_outlined,
            title: 'Savings goals',
            subtitle: 'Your goals and their progress',
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
          _Entry(
            icon: Icons.medical_services_outlined,
            title: 'Emergency funds',
            subtitle: 'Named reserves for the unexpected, pet-linkable',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                  builder: (_) => const EmergencyFundsScreen()),
            ),
          ),
          _Entry(
            icon: Icons.beach_access_outlined,
            title: 'Vacations',
            subtitle: 'Trip sub-budgets drawn from a goal or fund',
            onTap: () => VacationScreen.open(context),
          ),
          _Entry(
            icon: Icons.emoji_events_outlined,
            title: 'Trophy hall',
            subtitle: 'Trophies, titles, badges and your streaks',
            onTap: () => TrophyHallScreen.open(context),
          ),
          _Entry(
            icon: Icons.cottage_outlined,
            title: 'Homestead',
            subtitle: 'Watch the war chest build up, stage by stage',
            onTap: () => HomesteadScreen.open(context),
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
            icon: Icons.sync,
            title: 'Sync & hubs',
            subtitle: 'Host a hub, pair devices, sync over the LAN',
            onTap: () => SyncHubsScreen.open(context),
          ),
          _Entry(
            icon: Icons.history,
            title: 'Budget change log',
            subtitle: 'Every change, permanently logged — the audit trail',
            onTap: () => ChangeLogScreen.open(context),
          ),
          _Entry(
            icon: Icons.settings_outlined,
            title: 'Settings',
            subtitle: 'Members, income, recurring expenses, funds, rules',
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
