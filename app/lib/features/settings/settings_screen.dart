/// Settings: the household's configuration surface. Lists the editable areas
/// (members, income, recurring expenses, budget categories, emergency funds) and holds
/// the household rules that don't warrant their own page — spoils grace period,
/// dissolution tithe, and the net-worth feature flag. Receipt library (desktop)
/// and the tax center hang off here too.
library;

import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/actions.dart';
import '../../data/providers.dart';
import '../../game/skin_prefs.dart';
import '../../ui/theme.dart';
import '../categories/category_list_screen.dart';
import '../library/receipt_library_screen.dart';
import '../tax/tax_center_screen.dart';
import 'emergency_funds_screen.dart';
import 'income_screen.dart';
import 'members_screen.dart';
import 'recurring_screen.dart';

/// Whether this build runs on a desktop OS (where the receipt library applies).
bool get isDesktop =>
    !kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux);

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(householdStateProvider).value;
    if (state == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final settings = state.settings;
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          const _SectionHeader('Household'),
          _nav(context, Icons.groups_outlined, 'Members',
              'Adults, dependents, and pets', const MembersScreen()),
          _nav(context, Icons.payments_outlined, 'Income',
              'Each member\'s monthly income', const IncomeScreen()),
          _nav(context, Icons.autorenew, 'Recurring expenses',
              'Equipment maintenance & provisioning', const RecurringScreen()),
          _nav(context, Icons.pie_chart_outline, 'Budget categories',
              'Limits, tithes, leftover policies', const CategoryListScreen()),
          _nav(context, Icons.emergency_outlined, 'Emergency funds',
              'Reserve caches', const EmergencyFundsScreen()),
          const _SectionHeader('Appearance'),
          _SkinTile(
            skin: ref.watch(appSkinProvider),
            onChanged: (s) =>
                unawaited(ref.read(appSkinProvider.notifier).select(s)),
          ),
          const _SectionHeader('Rules'),
          ListTile(
            leading: const Icon(Icons.hourglass_bottom),
            title: const Text('Spoils grace period'),
            subtitle: Text('${settings.spoilsGraceDays} days after month close'),
            onTap: () => _editInt(
              context,
              ref,
              title: 'Spoils grace period (days)',
              current: settings.spoilsGraceDays,
              min: 0,
              max: 60,
              key: 'spoilsGraceDays',
            ),
          ),
          ListTile(
            leading: const Icon(Icons.percent),
            title: const Text('Dissolution tithe'),
            subtitle: Text('${settings.dissolutionTithePct}% on abandoned quests'),
            onTap: () => _editInt(
              context,
              ref,
              title: 'Dissolution tithe (%)',
              current: settings.dissolutionTithePct,
              min: 0,
              max: 100,
              key: 'dissolutionTithePct',
            ),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.trending_up),
            title: const Text('Show net worth'),
            subtitle: const Text('Enables the net-worth feature and its screen'),
            value: settings.showNetWorth,
            onChanged: (v) {
              final actions = ref.read(householdActionsProvider);
              unawaited(actions?.changeSetting('showNetWorth', v) ??
                  Future<void>.value());
            },
          ),
          const _SectionHeader('Data'),
          if (isDesktop)
            _nav(context, Icons.folder_copy_outlined, 'Receipt library',
                'Mirror receipts to a folder', const ReceiptLibraryScreen()),
          _nav(context, Icons.receipt_long_outlined, 'Tax center',
              'Deductible totals and package export', const TaxCenterScreen()),
        ],
      ),
    );
  }

  Widget _nav(BuildContext context, IconData icon, String title,
      String subtitle, Widget page) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => page),
      ),
    );
  }

  Future<void> _editInt(
    BuildContext context,
    WidgetRef ref, {
    required String title,
    required int current,
    required int min,
    required int max,
    required String key,
  }) async {
    final controller = TextEditingController(text: current.toString());
    final result = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(helperText: 'Between $min and $max'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final n = int.tryParse(controller.text.trim());
              if (n != null && n >= min && n <= max) {
                Navigator.of(context).pop(n);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (result != null) {
      await ref.read(householdActionsProvider)?.changeSetting(key, result);
    }
  }
}

/// The Classic / Adventure skin chooser. Both render identical numbers; the
/// choice only swaps the dashboard's presentation widgets.
class _SkinTile extends StatelessWidget {
  const _SkinTile({required this.skin, required this.onChanged});

  final AppSkin skin;
  final ValueChanged<AppSkin> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.videogame_asset_outlined),
              const SizedBox(width: AppSpacing.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Theme'),
                    Text(
                      'Classic ledger or the dungeon adventure skin',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          SegmentedButton<AppSkin>(
            segments: const [
              ButtonSegment(
                value: AppSkin.classic,
                label: Text('Classic'),
                icon: Icon(Icons.dashboard_outlined),
              ),
              ButtonSegment(
                value: AppSkin.adventure,
                label: Text('Adventure'),
                icon: Icon(Icons.castle_outlined),
              ),
            ],
            selected: {skin},
            onSelectionChanged: (s) => onChanged(s.first),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.sm),
      child: Text(label, style: AppText.sectionLabel(context)),
    );
  }
}
