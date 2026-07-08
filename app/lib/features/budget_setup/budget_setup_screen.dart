/// Budget setup: both members' personal categories side by side, group
/// categories below, income per member, and a "copy from last month" that
/// carries the previous month's income forward. Categories themselves persist
/// across months, so setup edits them in place via the shared category editor.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/actions.dart';
import '../../data/providers.dart';
import '../../domain/state.dart';
import '../../domain/time.dart';
import '../../domain/value_types.dart';
import '../../ui/format.dart';
import '../../ui/theme.dart';
import '../categories/category_editor_screen.dart';
import '../household_context.dart';
import '../shell/app_shell.dart' show kWideBreakpoint;
import 'budget_setup_model.dart';

class BudgetSetupScreen extends ConsumerStatefulWidget {
  const BudgetSetupScreen({super.key});

  @override
  ConsumerState<BudgetSetupScreen> createState() => _BudgetSetupScreenState();
}

class _BudgetSetupScreenState extends ConsumerState<BudgetSetupScreen> {
  Month _month = Month.fromInstant(DateTime.now());

  @override
  Widget build(BuildContext context) {
    final setup = ref.watch(localSetupProvider).value;
    final state = ref.watch(householdStateProvider).value;
    final names = ref.watch(userNamesProvider);
    if (setup == null || state == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final order = setup.profiles.map((p) => p.userId).toList();
    final model =
        buildBudgetSetupModel(state, month: _month, orderedUserIds: order);
    final wide = MediaQuery.of(context).size.width >= kWideBreakpoint;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Budget setup'),
        actions: [
          TextButton.icon(
            onPressed: () => _copyLastMonth(state, order),
            icon: const Icon(Icons.content_copy, size: 18),
            label: const Text('Copy last month'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                onPressed: () => setState(() => _month = _month.prev()),
                icon: const Icon(Icons.chevron_left),
              ),
              Text(monthLabel(_month.year, _month.month),
                  style: Theme.of(context).textTheme.titleMedium),
              IconButton(
                onPressed: () => setState(() => _month = _month.next()),
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          if (wide)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < model.columns.length; i++) ...[
                  if (i > 0) const SizedBox(width: AppSpacing.lg),
                  Expanded(
                    child: _MemberColumn(
                      column: model.columns[i],
                      name: names[model.columns[i].userId] ?? 'Member',
                    ),
                  ),
                ],
              ],
            )
          else
            for (final col in model.columns)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.lg),
                child: _MemberColumn(
                  column: col,
                  name: names[col.userId] ?? 'Member',
                ),
              ),
          const SizedBox(height: AppSpacing.lg),
          _GroupSection(slices: model.groupSlices),
        ],
      ),
    );
  }

  Future<void> _copyLastMonth(HouseholdState state, List<String> order) async {
    final actions = ref.read(householdActionsProvider);
    if (actions == null) return;
    final prev = _month.prev();
    for (final u in order) {
      final prior = state.incomeFor(u, prev);
      if (prior > 0) {
        await actions.setIncome(
            forUserId: u, month: _month, amountCents: prior);
      }
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Copied last month\'s income')),
      );
    }
  }
}

class _MemberColumn extends ConsumerWidget {
  const _MemberColumn({required this.column, required this.name});

  final SetupColumn column;
  final String name;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(name, style: Theme.of(context).textTheme.titleMedium),
            Text(
              'Income ${money(column.incomeCents)} · '
              'Budgeted ${money(column.totalLimitCents)}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
            ),
            const Divider(),
            for (final s in column.slices)
              _SliceRow(sliceId: s.sliceId, slice: s),
            if (column.slices.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                child: Text('No personal categories',
                    style: Theme.of(context).textTheme.bodySmall),
              ),
            const SizedBox(height: AppSpacing.sm),
            OutlinedButton.icon(
              onPressed: () => CategoryEditorScreen.open(
                context,
                defaultOwnership: PersonalSlice(column.userId),
              ),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add category'),
            ),
          ],
        ),
      ),
    );
  }
}

class _GroupSection extends StatelessWidget {
  const _GroupSection({required this.slices});

  final List<SetupSlice> slices;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Group categories',
                style: Theme.of(context).textTheme.titleMedium),
            const Divider(),
            for (final s in slices) _SliceRow(sliceId: s.sliceId, slice: s),
            if (slices.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                child: Text('No group categories',
                    style: Theme.of(context).textTheme.bodySmall),
              ),
            const SizedBox(height: AppSpacing.sm),
            OutlinedButton.icon(
              onPressed: () => CategoryEditorScreen.open(
                context,
                defaultOwnership: const GroupSlice(),
              ),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add group category'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SliceRow extends ConsumerWidget {
  const _SliceRow({required this.sliceId, required this.slice});

  final String sliceId;
  final SetupSlice slice;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(householdStateProvider).value;
    final cfg = state?.slices[sliceId];
    return ListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      title: Text(slice.name),
      subtitle: Text(
        'Spent ${money(slice.spentCents)} of ${money(slice.effectiveLimitCents)}'
        '${slice.petName != null ? ' · ${slice.petName}' : ''}',
      ),
      trailing: const Icon(Icons.edit_outlined, size: 18),
      onTap: cfg == null
          ? null
          : () => CategoryEditorScreen.open(context, existing: cfg),
    );
  }
}
