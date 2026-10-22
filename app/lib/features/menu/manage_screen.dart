/// The "Manage" menu (from the app bar): setup and housekeeping — budget setup,
/// net worth (flag-gated), sync, the change log and settings. Everyday money
/// places (goals, the war chest, emergency funds, vacations, the trophy hall,
/// the homestead) are first-class in the navigation bar; they are also listed
/// here under "Also in the navigation bar" so nothing is hard to find.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../../ui/glossary.dart';
import '../../ui/theme.dart';
import '../budget_setup/budget_setup_screen.dart';
import '../homestead/homestead_screen.dart';
import '../ledger/change_log_screen.dart';
import '../networth/networth_screen.dart';
import '../quests/quests_screen.dart';
import '../rewards/trophy_hall_screen.dart';
import '../settings/emergency_funds_screen.dart';
import '../settings/play_mode_providers.dart';
import '../settings/settings_screen.dart';
import '../sync/sync_hubs_screen.dart';
import '../vacation/vacation_screen.dart';
import '../warchest/warchest_screen.dart';

class ManageScreen extends ConsumerWidget {
  const ManageScreen({super.key});

  /// Pushes the manage hub onto the navigator.
  static Future<void> open(BuildContext context) => Navigator.of(
    context,
  ).push(MaterialPageRoute<void>(builder: (_) => const ManageScreen()));

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(householdStateProvider).value;
    final showNetWorth = state?.netWorth.show ?? false;
    final funds = Glossary.funds.label(
      isAdventure: ref.watch(isAdventureProvider),
    );
    return Scaffold(
      appBar: AppBar(title: const Text('Manage')),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        children: [
          _Entry(
            icon: Icons.tune,
            title: 'Budget setup',
            subtitle: "Everyone's categories, side by side",
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const BudgetSetupScreen(),
              ),
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
          const Divider(),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.sm,
              AppSpacing.lg,
              AppSpacing.xs,
            ),
            child: Text(
              'Also in the navigation bar',
              style: AppText.sectionLabel(context),
            ),
          ),
          _Entry(
            icon: Icons.flag_outlined,
            title: 'Savings goals',
            subtitle: 'Goals tab — your goals and their progress',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const QuestsScreen()),
            ),
          ),
          _Entry(
            icon: Icons.account_balance_outlined,
            title: 'War chest',
            subtitle:
                '$funds tab — shared savings, withdrawals, gifts, '
                'refunds and borrowing requests',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const WarChestScreen()),
            ),
          ),
          _Entry(
            icon: Icons.medical_services_outlined,
            title: 'Emergency funds',
            subtitle: '$funds tab — named reserves for the unexpected',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const EmergencyFundsScreen(),
              ),
            ),
          ),
          _Entry(
            icon: Icons.beach_access_outlined,
            title: 'Vacations',
            subtitle: '$funds tab — trip budgets drawn from a goal or fund',
            onTap: () => VacationScreen.open(context),
          ),
          _Entry(
            icon: Icons.cottage_outlined,
            title: 'Homestead',
            subtitle: '$funds tab — the war chest building up, stage by stage',
            onTap: () => HomesteadScreen.open(context),
          ),
          _Entry(
            icon: Icons.emoji_events_outlined,
            title: 'Trophy hall',
            subtitle:
                'Goals tab (trophy button) — trophies, titles, badges '
                'and streaks',
            onTap: () => TrophyHallScreen.open(context),
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
