/// Recurring expenses ("equipment maintenance & provisioning"): create, edit,
/// and cancel. Shared ones split by the household share table off the top; personal ones off the top of
/// that member's budget. Variable ones carry an estimate until an actual is
/// recorded at month close. Cancelling sets an end month.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/actions.dart';
import '../../data/providers.dart';
import '../../domain/money.dart';
import '../../domain/state.dart';
import '../../domain/time.dart';
import '../../domain/value_types.dart';
import '../../ui/format.dart';
import '../../ui/money_input.dart';
import '../../ui/theme.dart';
import '../household_context.dart';
import '../shared/owner_picker.dart';
import '../shared/month_field.dart';

class RecurringScreen extends ConsumerWidget {
  const RecurringScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(householdStateProvider).value;
    final names = ref.watch(userNamesProvider);
    if (state == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final items = state.recurringExpenses.values.toList()
      ..sort((first, second) => first.name.compareTo(second.name));
    final nowMonth = Month.fromInstant(DateTime.now());

    return Scaffold(
      appBar: AppBar(title: const Text('Recurring expenses')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => RecurringEditorScreen.open(context),
        icon: const Icon(Icons.add),
        label: const Text('New'),
      ),
      body: items.isEmpty
          ? const _Empty()
          : ListView.separated(
              padding: const EdgeInsets.only(bottom: 96),
              itemCount: items.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final expense = items[i];
                final ended =
                    expense.endMonth != null && expense.endMonth! < nowMonth;
                final owner = expense.isShared
                    ? 'Shared'
                    : (names[expense.ownerUserId] ?? 'Personal');
                final kind = expense.kind == RecurringKind.variable
                    ? 'variable est.'
                    : 'fixed';
                final cadence = expense.isAnnual ? 'annual' : 'monthly';
                final due = recurringDueLabel(
                  isAnnual: expense.isAnnual,
                  dueDay: expense.dueDay,
                  dueMonth: expense.dueMonth,
                );
                return ListTile(
                  title: Text(
                    expense.name,
                    style: ended
                        ? const TextStyle(
                            decoration: TextDecoration.lineThrough,
                          )
                        : null,
                  ),
                  subtitle: Text(
                    '$owner · $kind · $cadence · due $due · '
                    'from ${expense.startMonth.toKey()}'
                    '${expense.endMonth != null ? ' to ${expense.endMonth!.toKey()}' : ''}',
                  ),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        money(expense.amountCents),
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      if (expense.isAnnual)
                        Text(
                          '${money(expense.amountCents ~/ 12)}/mo',
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                        ),
                    ],
                  ),
                  onTap: () =>
                      RecurringEditorScreen.open(context, existing: expense),
                );
              },
            ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty();
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Text(
        'No recurring expenses yet.\nAdd rent, subscriptions, utilities…',
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    ),
  );
}

class RecurringEditorScreen extends ConsumerStatefulWidget {
  const RecurringEditorScreen({super.key, this.existing});

  final RecurringExpenseState? existing;

  static Future<void> open(
    BuildContext context, {
    RecurringExpenseState? existing,
  }) => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => RecurringEditorScreen(existing: existing),
    ),
  );

  @override
  ConsumerState<RecurringEditorScreen> createState() =>
      _RecurringEditorScreenState();
}

class _RecurringEditorScreenState extends ConsumerState<RecurringEditorScreen> {
  late final TextEditingController _name;
  late final TextEditingController _amount;

  /// The owning adult, or null when shared by the household.
  String? _ownerUserId;
  RecurringKind _kind = RecurringKind.fixed;
  RecurringCadence _cadence = RecurringCadence.monthly;
  late int _dueDay;
  late int _dueMonth;
  late Month _start;
  Month? _end;
  bool _ownerInit = false;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _name = TextEditingController(text: existing?.name ?? '');
    _amount = TextEditingController(
      text: existing == null ? '' : Money(existing.amountCents).format(),
    );
    _kind = existing?.kind ?? RecurringKind.fixed;
    _cadence = existing?.cadence ?? RecurringCadence.monthly;
    _dueDay = existing?.dueDay ?? 1;
    _dueMonth = existing?.dueMonth ?? Month.fromInstant(DateTime.now()).month;
    _start = existing?.startMonth ?? Month.fromInstant(DateTime.now());
    _end = existing?.endMonth;
  }

  @override
  void dispose() {
    _name.dispose();
    _amount.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final setup = ref.watch(localSetupProvider).value;
    if (setup == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (!_ownerInit) {
      final ownership = widget.existing?.ownership;
      _ownerUserId = ownership is PersonalParty ? ownership.userId : null;
      _ownerInit = true;
    }
    final variable = _kind == RecurringKind.variable;
    final annual = _cadence == RecurringCadence.annual;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.existing == null ? 'New recurring' : 'Edit recurring',
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          TextField(
            controller: _name,
            decoration: const InputDecoration(labelText: 'Name'),
            textCapitalization: TextCapitalization.words,
          ),
          const SizedBox(height: AppSpacing.lg),
          Text('Owner', style: AppText.sectionLabel(context)),
          const SizedBox(height: AppSpacing.sm),
          OwnerPicker(
            adults: ref.watch(partyAdultsProvider),
            selectedUserId: _ownerUserId,
            householdLabel: 'Shared',
            onChanged: (id) => setState(() => _ownerUserId = id),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text('Kind', style: AppText.sectionLabel(context)),
          const SizedBox(height: AppSpacing.sm),
          SegmentedButton<RecurringKind>(
            segments: const [
              ButtonSegment(value: RecurringKind.fixed, label: Text('Fixed')),
              ButtonSegment(
                value: RecurringKind.variable,
                label: Text('Variable'),
              ),
            ],
            selected: {_kind},
            onSelectionChanged: (selection) =>
                setState(() => _kind = selection.first),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text('Cadence', style: AppText.sectionLabel(context)),
          const SizedBox(height: AppSpacing.sm),
          SegmentedButton<RecurringCadence>(
            segments: const [
              ButtonSegment(
                value: RecurringCadence.monthly,
                label: Text('Monthly'),
              ),
              ButtonSegment(
                value: RecurringCadence.annual,
                label: Text('Annual'),
              ),
            ],
            selected: {_cadence},
            onSelectionChanged: (selection) =>
                setState(() => _cadence = selection.first),
          ),
          const SizedBox(height: AppSpacing.lg),
          TextField(
            controller: _amount,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: annual
                  ? (variable ? 'Annual estimate' : 'Annual amount')
                  : (variable ? 'Estimate' : 'Amount'),
              prefixText: r'$',
              helperText: annual
                  ? 'Accrued 1/12 each month; reconciled when due'
                  : (variable ? 'Actual is recorded at month close' : null),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text('Due date', style: AppText.sectionLabel(context)),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              if (annual) ...[
                Expanded(
                  child: DropdownButtonFormField<int>(
                    initialValue: _dueMonth,
                    decoration: const InputDecoration(labelText: 'Month'),
                    items: [
                      for (
                        var monthNumber = 1;
                        monthNumber <= 12;
                        monthNumber++
                      )
                        DropdownMenuItem(
                          value: monthNumber,
                          child: Text(_monthName(monthNumber)),
                        ),
                    ],
                    onChanged: (value) =>
                        setState(() => _dueMonth = value ?? _dueMonth),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
              ],
              Expanded(
                child: DropdownButtonFormField<int>(
                  initialValue: _dueDay,
                  decoration: const InputDecoration(labelText: 'Day'),
                  items: [
                    for (var day = 1; day <= 31; day++)
                      DropdownMenuItem(
                        value: day,
                        child: Text(day == 31 ? 'Last day' : '$day'),
                      ),
                  ],
                  onChanged: (value) =>
                      setState(() => _dueDay = value ?? _dueDay),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          MonthField(
            label: 'Start month',
            month: _start,
            onChanged: (month) => setState(() => _start = month),
          ),
          const SizedBox(height: AppSpacing.md),
          MonthField(
            label: 'End month (optional)',
            month: _end,
            onChanged: (month) => setState(() => _end = month),
            onClear: () => setState(() => _end = null),
          ),
          const SizedBox(height: AppSpacing.xl),
          FilledButton(onPressed: _save, child: const Text('Save')),
          if (widget.existing != null) ...[
            const SizedBox(height: AppSpacing.md),
            OutlinedButton.icon(
              onPressed: _cancelExpense,
              icon: const Icon(Icons.event_busy_outlined),
              label: const Text('Cancel this expense'),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _save() async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final name = _name.text.trim();
    final amount = tryParseMoneyCents(_amount.text);
    if (name.isEmpty || amount == null) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Enter a name and amount')),
      );
      return;
    }
    if (_end != null && _end! < _start) {
      messenger.showSnackBar(
        const SnackBar(content: Text('End month is before start month')),
      );
      return;
    }
    final owner = _ownerUserId;
    final PartyOwnership ownership = owner == null
        ? const SharedParty()
        : PersonalParty(owner);
    await ref
        .read(householdActionsProvider)
        ?.setRecurringExpense(
          expenseId: widget.existing?.expenseId,
          name: name,
          ownership: ownership,
          kind: _kind,
          cadence: _cadence,
          amountCents: amount,
          dueDay: _dueDay,
          dueMonth: _cadence == RecurringCadence.annual ? _dueMonth : null,
          startMonth: _start,
          endMonth: _end,
        );
    navigator.pop();
  }

  Future<void> _cancelExpense() async {
    final existing = widget.existing!;
    final navigator = Navigator.of(context);
    // Cancel by ending it at the current month (keeps the run through this month).
    final endAt = Month.fromInstant(DateTime.now());
    await ref
        .read(householdActionsProvider)
        ?.setRecurringExpense(
          expenseId: existing.expenseId,
          name: existing.name,
          ownership: existing.ownership,
          kind: existing.kind,
          cadence: existing.cadence,
          amountCents: existing.amountCents,
          dueDay: existing.dueDay,
          dueMonth: existing.dueMonth,
          startMonth: existing.startMonth,
          endMonth: endAt < existing.startMonth ? existing.startMonth : endAt,
        );
    navigator.pop();
  }
}

String _monthName(int month) => const [
  '',
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
][month];
