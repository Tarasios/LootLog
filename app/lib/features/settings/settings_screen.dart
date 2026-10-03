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
import '../../data/blobs/receipt_offload.dart';
import '../../data/providers.dart';
import '../../game/skin_prefs.dart';
import '../../ui/glossary.dart';
import '../../ui/theme.dart';
import '../categories/category_list_screen.dart';
import '../export/export_screen.dart';
import '../ledger/change_log_screen.dart';
import '../library/receipt_library_screen.dart';
import '../tax/tax_center_screen.dart';
import '../tutorial/tutorial.dart';
import 'emergency_funds_screen.dart';
import 'income_screen.dart';
import 'members_screen.dart';
import 'play_mode.dart';
import 'play_mode_providers.dart';
import 'recurring_screen.dart';
import 'savings_rules_card.dart';
import 'visibility_prefs.dart';

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
          _nav(
            context,
            Icons.groups_outlined,
            'Members',
            'Adults, dependents, and pets',
            const MembersScreen(),
          ),
          _nav(
            context,
            Icons.payments_outlined,
            'Income',
            'Each member\'s monthly income',
            const IncomeScreen(),
          ),
          _nav(
            context,
            Icons.autorenew,
            'Recurring expenses',
            'Regular bills and subscriptions, charged off the top',
            const RecurringScreen(),
          ),
          _nav(
            context,
            Icons.pie_chart_outline,
            'Budget categories',
            'Limits, savings cut, and how leftovers are handled',
            const CategoryListScreen(),
          ),
          _nav(
            context,
            Icons.emergency_outlined,
            'Emergency funds',
            'Named rainy-day funds for unexpected costs',
            const EmergencyFundsScreen(),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.visibility_outlined),
            title: const Text('Show other adults\' budgets'),
            subtitle: const Text(
              'Display everyone\'s budgets and repayments on this device. '
              'Turning this off only tidies the view here — the household '
              'data still syncs in full and shared savings always show.',
            ),
            value: ref.watch(showHouseholdBudgetsProvider),
            onChanged: (v) => unawaited(
              ref.read(showHouseholdBudgetsProvider.notifier).select(v),
            ),
          ),
          const _SectionHeader('Play mode'),
          const _PlayModeSection(),
          if (ref.watch(isAdventureProvider))
            SwitchListTile(
              secondary: const Icon(Icons.text_fields),
              title: const Text('Text mode'),
              subtitle: const Text(
                'Render the adventure as a text adventure '
                'instead of pixel art — works with no artwork at all',
              ),
              value: ref.watch(adventureTierProvider) == AdventureTier.text,
              onChanged: (v) => unawaited(
                ref
                    .read(adventureTierProvider.notifier)
                    .select(v ? AdventureTier.text : AdventureTier.pixel),
              ),
            ),
          const _SectionHeader('Rules'),
          const SavingsRulesCard(),
          ListTile(
            leading: const Icon(Icons.hourglass_bottom),
            title: Text(
              Glossary.gracePeriodLabel(
                settings.spoilsGraceDays,
                isAdventure: false,
              ),
            ),
            subtitle: Text(Glossary.gracePeriod.helper),
            onTap: () => _editInt(
              context,
              ref,
              title: 'Auto-divide delay (days)',
              current: settings.spoilsGraceDays,
              min: 0,
              max: 60,
              key: 'spoilsGraceDays',
            ),
          ),
          ListTile(
            leading: const Icon(Icons.percent),
            title: const Text('Savings-goal cancellation fee'),
            subtitle: Text(
              '${settings.dissolutionTithePct}% kept for shared savings when '
              'a goal is cancelled',
            ),
            onTap: () => _editInt(
              context,
              ref,
              title: 'Cancellation fee (%)',
              current: settings.dissolutionTithePct,
              min: 0,
              max: 100,
              key: 'dissolutionTithePct',
            ),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.trending_up),
            title: const Text('Show net worth'),
            subtitle: const Text(
              'Track savings, investments and debts on a '
              'separate net-worth screen',
            ),
            value: settings.showNetWorth,
            onChanged: (v) {
              final actions = ref.read(householdActionsProvider);
              unawaited(
                actions?.changeSetting('showNetWorth', v) ??
                    Future<void>.value(),
              );
            },
          ),
          const _SectionHeader('Help'),
          ListTile(
            leading: const Icon(Icons.school_outlined),
            title: const Text('Tutorial'),
            subtitle: const Text('Replay the guided tour of how LootLog works'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => unawaited(TutorialTour.show(context, ref)),
          ),
          const _SectionHeader('Data'),
          ListTile(
            leading: const Icon(Icons.history),
            title: const Text('Budget change log'),
            subtitle: const Text('Every change, permanently logged'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => ChangeLogScreen.open(context),
          ),
          if (!isDesktop) ...[
            ListTile(
              leading: const Icon(Icons.receipt_long_outlined),
              title: const Text('Receipt images on this phone'),
              subtitle: const Text('How scanned receipts are stored'),
            ),
            RadioGroup<ReceiptStorageMode>(
              groupValue:
                  ref.watch(receiptStorageModeProvider).value ??
                  ReceiptStorageMode.keep,
              onChanged: (v) => unawaited(
                ref
                    .read(receiptStorageModeProvider.notifier)
                    .set(v ?? ReceiptStorageMode.keep),
              ),
              child: const Column(
                children: [
                  RadioListTile<ReceiptStorageMode>(
                    value: ReceiptStorageMode.keep,
                    dense: true,
                    title: Text('Keep them here'),
                    subtitle: Text('Every receipt image stays on this phone'),
                  ),
                  RadioListTile<ReceiptStorageMode>(
                    value: ReceiptStorageMode.offload,
                    dense: true,
                    title: Text('Free up space after syncing'),
                    subtitle: Text(
                      'Images are removed once every paired '
                      'desktop hub holds a copy; they stay in your budget '
                      'and download again when viewed',
                    ),
                  ),
                  RadioListTile<ReceiptStorageMode>(
                    value: ReceiptStorageMode.none,
                    dense: true,
                    title: Text('Scan only, never save'),
                    subtitle: Text(
                      'The camera fills in the amount, date, and '
                      'store, then the image is discarded',
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (isDesktop)
            _nav(
              context,
              Icons.folder_copy_outlined,
              'Receipt library',
              'Mirror receipts to a folder',
              const ReceiptLibraryScreen(),
            ),
          _nav(
            context,
            Icons.receipt_long_outlined,
            'Tax center',
            'Deductible totals and package export',
            const TaxCenterScreen(),
          ),
          _nav(
            context,
            Icons.table_view_outlined,
            'Export',
            'Spreadsheet (.xlsx) and Google Sheets sync',
            const ExportScreen(),
          ),
        ],
      ),
    );
  }

  Widget _nav(
    BuildContext context,
    IconData icon,
    String title,
    String subtitle,
    Widget page,
  ) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => Navigator.of(
        context,
      ).push(MaterialPageRoute<void>(builder: (_) => page)),
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
/// This person's Standard / Adventure choice, plus — for Adventure — which
/// screen opens at launch. Saved per person (it follows them to every paired
/// device); switching never deletes any game progress.
class _PlayModeSection extends ConsumerWidget {
  const _PlayModeSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(playPrefsProvider) ?? PlayPrefs.defaults;
    final actions = ref.watch(householdActionsProvider);
    final helper = Theme.of(context).textTheme.bodySmall?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        );

    Widget choice<T>({
      required IconData icon,
      required String title,
      required String subtitle,
      required List<ButtonSegment<T>> segments,
      required T selected,
      required Future<void> Function(HouseholdActions, T) save,
    }) =>
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.sm,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
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
              ]),
              const SizedBox(height: AppSpacing.sm),
              SegmentedButton<T>(
                segments: segments,
                selected: {selected},
                onSelectionChanged: actions == null
                    ? null
                    : (s) => unawaited(save(actions, s.first)),
              ),
            ],
          ),
        );

    return Column(children: [
      choice<PlayMode>(
        icon: Icons.sports_esports_outlined,
        title: 'Mode',
        subtitle: 'Adventure turns your budget into a game. Standard is the '
            'plain budgeting app — your logging still helps the household. '
            'Your choice follows you to every device, and switching back '
            'never loses progress.',
        segments: const [
          ButtonSegment(value: PlayMode.standard, label: Text('Standard')),
          ButtonSegment(value: PlayMode.adventure, label: Text('Adventure')),
        ],
        selected: prefs.mode,
        save: setPlayMode,
      ),
      if (prefs.mode == PlayMode.adventure)
        choice<AdventureHome>(
          icon: Icons.home_outlined,
          title: 'Home screen',
          subtitle: 'What opens when you launch the app. The other is always '
              'one tap away.',
          segments: const [
            ButtonSegment(value: AdventureHome.hall, label: Text('Hall')),
            ButtonSegment(value: AdventureHome.ledger, label: Text('Ledger')),
          ],
          selected: prefs.home,
          save: setAdventureHome,
        ),
    ]);
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.sm,
      ),
      child: Text(label, style: AppText.sectionLabel(context)),
    );
  }
}
