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
      ..sort((a, b) {
        // Open trips first, then by name.
        final r = (a.isOpen ? 0 : 1).compareTo(b.isOpen ? 0 : 1);
        return r != 0 ? r : a.name.compareTo(b.name);
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
                for (final v in vacations)
                  _VacationCard(vacation: v),
              ],
            ),
    );
  }
}

/// The fund sources a vacation may draw from: active savings goals and every
/// emergency fund.
List<({VacationFund fund, String label})> _fundOptions(HouseholdState state) {
  final options = <({VacationFund fund, String label})>[];
  for (final q in state.quests.values) {
    if (q.completed || q.abandoned) continue;
    options.add((
      fund: VacationFundQuest(q.questId),
      label: 'Goal · ${q.name} (${money(q.balanceCents)})',
    ));
  }
  for (final f in state.emergencyFunds.values) {
    options.add((
      fund: VacationFundEmergency(f.fundId),
      label: 'Fund · ${f.name} (${money(f.balanceCents)})',
    ));
  }
  options.sort((a, b) => a.label.compareTo(b.label));
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
    final v = vacation;
    final warnings = vacationWarnings(v);
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
                      Text(v.name,
                          style: Theme.of(context).textTheme.titleLarge),
                      Text(
                        '${isoDay(v.startDate)} → ${isoDay(v.endDate)}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                if (v.isOpen)
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
              '${money(v.totalSpentCents)} of ${money(v.totalLimitCents)} spent',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            if (v.isOpen)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.xxs),
                child: Text(
                  dailyAllowanceLabel(v),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: scheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
            for (final w in warnings)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.xs),
                child: Row(
                  children: [
                    Icon(Icons.warning_amber_rounded,
                        size: 18, color: scheme.error),
                    const SizedBox(width: AppSpacing.xs),
                    Expanded(
                      child: Text(
                        w,
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
                for (final c in v.categories)
                  _CategoryRing(category: c),
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
    final c = category;
    final fraction = c.limitCents <= 0
        ? (c.spentCents > 0 ? 1.0 : 0.0)
        : c.spentCents / c.limitCents;
    return SizedBox(
      width: 96,
      child: Column(
        children: [
          ProgressRing(
            fraction: fraction,
            color: scheme.primary,
            trackColor: scheme.surfaceContainerHighest,
            overColor: scheme.error,
            overspent: c.overspent,
            center: Text(
              '${(fraction * 100).round()}%',
              style: Theme.of(context).textTheme.labelMedium,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            c.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelLarge,
          ),
          Text(
            c.overspent
                ? 'over ${money(c.overspendCents)}'
                : '${money(c.leftoverCents)} left',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: c.overspent ? scheme.error : null,
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
    for (final c in _categories) {
      c.name.dispose();
      c.limit.dispose();
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
      final d = _categories[i];
      final name = d.name.text.trim();
      final cents = tryParseMoneyCents(d.limit.text);
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
          for (final o in options)
            RadioListTile<VacationFund>(
              value: o.fund,
              groupValue: _fund,
              onChanged: (f) => setState(() => _fund = f),
              title: Text(o.label),
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
