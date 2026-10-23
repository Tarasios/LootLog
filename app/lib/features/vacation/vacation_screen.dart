/// Vacation mode: a dashboard of the household's trips and a create/edit editor.
///
/// Each open vacation is a self-contained sub-budget drawn from a source fund (a
/// savings goal or an emergency fund). The dashboard shows budget rings per
/// category, a daily-allowance tracker and overspend warnings; the normal
/// monthly budget is never touched. Closing a trip returns its unspent budget to
/// the source fund. All numbers are copied from the reducer's read-model.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/actions.dart';
import '../../data/providers.dart';
import '../../domain/state.dart';
import '../../domain/value_types.dart';
import '../../ui/format.dart';
import '../../ui/money_input.dart';
import '../../ui/theme.dart';
import '../../ui/widgets/progress_ring.dart';
import 'vacation_dashboard.dart';

class VacationScreen extends ConsumerWidget {
  const VacationScreen({super.key});

  static Future<void> open(BuildContext context) => Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const VacationScreen()),
      );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(householdStateProvider).value;
    if (state == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final vacations = state.vacations.values.toList()
      ..sort((first, second) {
        // Open trips first, then by name.
        final byOpen = (first.isOpen ? 0 : 1).compareTo(second.isOpen ? 0 : 1);
        return byOpen != 0 ? byOpen : first.name.compareTo(second.name);
      });

    final canCreate = _fundOptions(state).isNotEmpty;

    return Scaffold(
      appBar: AppBar(title: const Text('Vacations')),
      floatingActionButton: canCreate
          ? FloatingActionButton.extended(
              onPressed: () => VacationEditorScreen.open(context),
              icon: const Icon(Icons.add),
              label: const Text('New vacation'),
            )
          : null,
      body: vacations.isEmpty
          ? _EmptyState(canCreate: canCreate)
          : ListView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              children: [
                for (final vacation in vacations)
                  _VacationCard(vacation: vacation),
              ],
            ),
    );
  }
}

/// The fund sources a vacation may draw from: active savings goals and every
/// emergency fund.
List<({VacationFund fund, String label})> _fundOptions(HouseholdState state) {
  final options = <({VacationFund fund, String label})>[];
  for (final quest in state.quests.values) {
    if (quest.completed || quest.abandoned) continue;
    options.add((
      fund: VacationFundQuest(quest.questId),
      label: 'Goal · ${quest.name} (${money(quest.balanceCents)})',
    ));
  }
  for (final fund in state.emergencyFunds.values) {
    options.add((
      fund: VacationFundEmergency(fund.fundId),
      label: 'Fund · ${fund.name} (${money(fund.balanceCents)})',
    ));
  }
  options.sort((first, second) => first.label.compareTo(second.label));
  return options;
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.canCreate});

  final bool canCreate;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.beach_access_outlined, size: 48),
            const SizedBox(height: AppSpacing.md),
            Text(
              canCreate
                  ? 'No vacations yet.'
                  : 'Add a savings goal or emergency fund first.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              canCreate
                  ? 'Plan a trip as a self-contained sub-budget drawn from one '
                      'of your funds. Your monthly budget stays untouched.'
                  : 'A vacation draws its budget from a savings goal or an '
                      'emergency fund.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}

class _VacationCard extends ConsumerWidget {
  const _VacationCard({required this.vacation});

  final VacationState vacation;

  Future<void> _close(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Close ${vacation.name}?'),
        content: Text(
          'The unspent budget (${money(vacation.totalLeftoverCents)}) returns '
          'to the source fund. Closed trips no longer accept charges.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Close trip'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(householdActionsProvider)?.closeVacation(vacation.vacationId);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final trip = vacation;
    final warnings = vacationWarnings(trip);
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(trip.name,
                          style: Theme.of(context).textTheme.titleLarge),
                      Text(
                        '${isoDay(trip.startDate)} → ${isoDay(trip.endDate)}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                if (trip.isOpen)
                  TextButton.icon(
                    onPressed: () => _close(context, ref),
                    icon: const Icon(Icons.flag_outlined, size: 18),
                    label: const Text('Close'),
                  )
                else
                  Chip(
                    label: const Text('Closed'),
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              '${money(trip.totalSpentCents)} of ${money(trip.totalLimitCents)} spent',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            if (trip.isOpen)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.xxs),
                child: Text(
                  dailyAllowanceLabel(trip),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: scheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
            for (final warning in warnings)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.xs),
                child: Row(
                  children: [
                    Icon(Icons.warning_amber_rounded,
                        size: 18, color: scheme.error),
                    const SizedBox(width: AppSpacing.xs),
                    Expanded(
                      child: Text(
                        warning,
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: scheme.error),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.lg,
              runSpacing: AppSpacing.md,
              children: [
                for (final category in trip.categories)
                  _CategoryRing(category: category),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryRing extends StatelessWidget {
  const _CategoryRing({required this.category});

  final VacationCategoryState category;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final current = category;
    final fraction = current.limitCents <= 0
        ? (current.spentCents > 0 ? 1.0 : 0.0)
        : current.spentCents / current.limitCents;
    return SizedBox(
      width: 96,
      child: Column(
        children: [
          ProgressRing(
            fraction: fraction,
            color: scheme.primary,
            trackColor: scheme.surfaceContainerHighest,
            overColor: scheme.error,
            overspent: current.overspent,
            center: Text(
              '${(fraction * 100).round()}%',
              style: Theme.of(context).textTheme.labelMedium,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            current.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelLarge,
          ),
          Text(
            current.overspent
                ? 'over ${money(current.overspendCents)}'
                : '${money(current.leftoverCents)} left',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: current.overspent ? scheme.error : null,
                ),
          ),
        ],
      ),
    );
  }
}

/// A minimal create form for a vacation: name, source fund, date range and one
/// or more spending categories.
class VacationEditorScreen extends ConsumerStatefulWidget {
  const VacationEditorScreen({super.key});

  static Future<void> open(BuildContext context) => Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const VacationEditorScreen()),
      );

  @override
  ConsumerState<VacationEditorScreen> createState() =>
      _VacationEditorScreenState();
}

class _CategoryDraft {
  _CategoryDraft();
  final TextEditingController name = TextEditingController();
  final TextEditingController limit = TextEditingController();
}

class _VacationEditorScreenState extends ConsumerState<VacationEditorScreen> {
  final _name = TextEditingController();
  VacationFund? _fund;
  DateTime? _start;
  DateTime? _end;
  final List<_CategoryDraft> _categories = [_CategoryDraft()];
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    for (final category in _categories) {
      category.name.dispose();
      category.limit.dispose();
    }
    super.dispose();
  }

  bool get _valid {
    if (_name.text.trim().isEmpty) return false;
    if (_fund == null || _start == null || _end == null) return false;
    if (_end!.isBefore(_start!)) return false;
    final cats = _validCategories();
    return cats.isNotEmpty;
  }

  List<VacationCategory> _validCategories() {
    final out = <VacationCategory>[];
    for (var i = 0; i < _categories.length; i++) {
      final draft = _categories[i];
      final name = draft.name.text.trim();
      final cents = tryParseMoneyCents(draft.limit.text);
      if (name.isEmpty || cents == null || cents <= 0) continue;
      out.add(VacationCategory(
        categoryId: 'c${i + 1}',
        name: name,
        limitCents: cents,
      ));
    }
    return out;
  }

  Future<void> _pickDate({required bool isStart}) async {
    final now = DateTime.now();
    final initial = (isStart ? _start : _end) ?? now;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _start = picked;
          if (_end != null && _end!.isBefore(picked)) _end = picked;
        } else {
          _end = picked;
        }
      });
    }
  }

  Future<void> _save() async {
    if (!_valid) return;
    setState(() => _saving = true);
    await ref.read(householdActionsProvider)?.setVacation(
          name: _name.text.trim(),
          fund: _fund!,
          startDate: DateTime.utc(_start!.year, _start!.month, _start!.day),
          endDate: DateTime.utc(_end!.year, _end!.month, _end!.day),
          categories: _validCategories(),
        );
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(householdStateProvider).value;
    final options = state == null
        ? <({VacationFund fund, String label})>[]
        : _fundOptions(state);
    return Scaffold(
      appBar: AppBar(
        title: const Text('New vacation'),
        actions: [
          TextButton(
            onPressed: _valid && !_saving ? _save : null,
            child: const Text('Save'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          TextField(
            controller: _name,
            decoration: const InputDecoration(labelText: 'Trip name'),
            textCapitalization: TextCapitalization.words,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text('Drawn from', style: AppText.sectionLabel(context)),
          for (final option in options)
            RadioListTile<VacationFund>(
              value: option.fund,
              groupValue: _fund,
              onChanged: (fund) => setState(() => _fund = fund),
              title: Text(option.label),
              contentPadding: EdgeInsets.zero,
              visualDensity: VisualDensity.compact,
            ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _pickDate(isStart: true),
                  child: Text(_start == null ? 'Start date' : isoDay(_start!)),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _pickDate(isStart: false),
                  child: Text(_end == null ? 'End date' : isoDay(_end!)),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Text('Categories', style: AppText.sectionLabel(context)),
          for (var i = 0; i < _categories.length; i++)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.sm),
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: TextField(
                      controller: _categories[i].name,
                      decoration: const InputDecoration(labelText: 'Name'),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    flex: 2,
                    child: TextField(
                      controller: _categories[i].limit,
                      decoration: const InputDecoration(
                        labelText: 'Limit',
                        prefixText: '\$',
                      ),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Remove',
                    icon: const Icon(Icons.remove_circle_outline),
                    onPressed: _categories.length == 1
                        ? null
                        : () => setState(() {
                              _categories.removeAt(i)
                                ..name.dispose()
                                ..limit.dispose();
                            }),
                  ),
                ],
              ),
            ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () =>
                  setState(() => _categories.add(_CategoryDraft())),
              icon: const Icon(Icons.add),
              label: const Text('Add category'),
            ),
          ),
        ],
      ),
    );
  }
}
