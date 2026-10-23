/// First-run onboarding, framed as assembling your adventuring party. A stepped
/// wizard collects the household — members, incomes, tracked accounts, fixed
/// expenses, the budget, and a first savings goal — then hands the drafts to the
/// pure [buildOnboardingEvents] model, appends the events, and hands off to the
/// main app. Every step is editable later via Settings; the summary says so.
///
/// The wizard owns only layout and draft state ([SetupController]); it decides
/// nothing about which events get written — that lives in `onboarding_plan.dart`.
library;

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/actions.dart';
import '../../data/blobs/media_ingest.dart';
import '../../data/providers.dart';
import '../../domain/money.dart';
import '../../domain/state.dart' show MainCategory;
import '../../domain/time.dart';
import '../../domain/value_types.dart';
import '../../ui/format.dart';
import '../../ui/glossary.dart';
import '../../ui/theme.dart';
import '../settings/play_mode.dart';
import 'join_party_screen.dart';
import 'onboarding_plan.dart';
import 'setup_controller.dart';

/// The ordered steps of the wizard (after the welcome/join gate).
enum _Step { party, income, accounts, expenses, budget, goal, summary }

const _stepTitles = <_Step, String>{
  _Step.party: 'Your household',
  _Step.income: 'Income',
  _Step.accounts: 'Accounts',
  _Step.expenses: 'Recurring bills',
  _Step.budget: 'Budgets',
  _Step.goal: 'First savings goal',
  _Step.summary: 'Ready to go',
};

class SetupScreen extends ConsumerStatefulWidget {
  const SetupScreen({super.key, this.debugJumpToSummary = false});

  /// Test-only: start at the summary step so the finish path is reachable
  /// without driving every wizard form.
  @visibleForTesting
  final bool debugJumpToSummary;

  @override
  ConsumerState<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends ConsumerState<SetupScreen> {
  final _controller = SetupController();
  int _index = -1; // -1 == the welcome/join gate
  bool _busy = false;
  String? _finishError;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onChange);
    if (widget.debugJumpToSummary) _index = _Step.summary.index;
  }

  @override
  void dispose() {
    _controller.removeListener(_onChange);
    _controller.dispose();
    super.dispose();
  }

  void _onChange() => setState(() {});

  _Step get _step => _Step.values[_index];

  bool get _canAdvance {
    if (_index < 0) return true;
    return switch (_step) {
      _Step.party => _controller.hasAdult && _controller.meLocalId != null,
      // The plan may not exceed anyone's income.
      _Step.budget => !_controller.anyOverAllocated,
      _ => true,
    };
  }

  void _next() {
    if (_index < _Step.values.length - 1) {
      setState(() => _index++);
    }
  }

  void _back() {
    if (_index >= 0) setState(() => _index--);
  }

  @override
  Widget build(BuildContext context) {
    if (_index < 0) return _welcome(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(_stepTitles[_step]!),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _back,
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: LinearProgressIndicator(
            value: (_index + 1) / _Step.values.length,
          ),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: _stepBody(),
          ),
        ),
      ),
      bottomNavigationBar: _bottomBar(),
    );
  }

  Widget _stepBody() => switch (_step) {
        _Step.party => _PartyStep(controller: _controller, ref: ref),
        _Step.income => _IncomeStep(controller: _controller),
        _Step.accounts => _AccountsStep(controller: _controller),
        _Step.expenses => _ExpensesStep(controller: _controller),
        _Step.budget => _BudgetStep(controller: _controller),
        _Step.goal => _GoalStep(controller: _controller),
        _Step.summary => _SummaryStep(controller: _controller),
      };

  Widget _bottomBar() {
    final isSummary = _step == _Step.summary;
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_finishError != null)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Text(
                _finishError!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _busy ? null : _back,
                  child: const Text('Back'),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                flex: 2,
                child: FilledButton(
                  onPressed: !_canAdvance || _busy
                      ? null
                      : isSummary
                          ? _finish
                          : _next,
                  child: Text(
                    isSummary
                        ? (_meAdventure ? 'Begin the adventure' : 'Finish setup')
                        : 'Next',
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ---- Welcome / join gate -------------------------------------------------

  Widget _welcome(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(Icons.castle_outlined,
                      size: 72,
                      color: Theme.of(context).colorScheme.primary),
                  const SizedBox(height: AppSpacing.lg),
                  Text('Welcome to LootLog',
                      style: text.headlineSmall, textAlign: TextAlign.center),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'Set up your household’s budget together. '
                    'First: are you joining a household that already exists '
                    'on another device?',
                    style: text.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  FilledButton.icon(
                    onPressed: () => JoinPartyScreen.open(context),
                    icon: const Icon(Icons.qr_code_scanner),
                    label: const Text('Join an existing household'),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  OutlinedButton.icon(
                    onPressed: () => setState(() => _index = 0),
                    icon: const Icon(Icons.group_add_outlined),
                    label: const Text('Start a new household'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ---- Finish --------------------------------------------------------------

  Future<void> _finish() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _finishError = null;
    });
    try {
      final input = _controller.buildInput();
      final db = ref.read(appDatabaseProvider);
      final plan = buildOnboardingEvents(
        input,
        deviceId: ref.read(deviceIdProvider),
        startMonth: Month.fromInstant(DateTime.now().toUtc()),
      );
      await db.eventsDao.appendEvents(plan.events);
      if (mounted) await _celebrate();
      // Saving the local setup flips isSetUpProvider and the router hands off
      // to the main shell.
      await db.localSetupDao.save(plan.localSetup);
    } on Object catch (error) {
      if (mounted) {
        setState(() => _finishError = 'Could not save your setup: $error');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Whether this device's adult picked Adventure. The wizard is worded
  /// neutrally until a mode is chosen; the finish speaks that mode.
  bool get _meAdventure =>
      // No adult yet reads as the default mode (Adventure).
      _controller.modeOf(_controller.meLocalId ?? '') == PlayMode.adventure;

  Future<void> _celebrate() async {
    final adventure = _meAdventure;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.celebration, size: 48),
        title: Text(
          adventure ? 'Your party is ready!' : 'Your household is ready!',
        ),
        content: Text(
          'Every choice you made is now permanently logged and can always be '
          'changed later from Settings. Log a purchase to start your first '
          'streak${adventure ? ' — the adventure begins now' : ''}.',
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(adventure ? 'Enter the dungeon' : 'Get started'),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Step 2 — the party
// ---------------------------------------------------------------------------

class _PartyStep extends StatelessWidget {
  const _PartyStep({required this.controller, required this.ref});

  final SetupController controller;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        const _StepIntro(
          'Add the adults, dependents, and pets in your household. '
          'Adults carry income and a budget; everyone else is shown with them. '
          'A description feeds the text-mode adventure.',
        ),
        for (final role in DraftRole.values) ...[
          _RoleSection(role: role),
          for (final member in controller.members.where((member) => member.role == role))
            _MemberTile(controller: controller, ref: ref, member: member),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => _editMember(context, role),
              icon: const Icon(Icons.add),
              label: Text('Add ${_roleWord(role)}'),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
        if (controller.adults.length > 1) ...[
          const Divider(),
          Text('Which adult is this device?',
              style: AppText.sectionLabel(context)),
          const SizedBox(height: AppSpacing.sm),
          for (final adult in controller.adults)
            RadioListTile<String>(
              contentPadding: EdgeInsets.zero,
              value: adult.localId,
              groupValue: controller.meLocalId,
              title: Text(adult.name),
              onChanged: (value) => value == null ? null : controller.setMe(value),
            ),
        ],
      ],
    );
  }

  Future<void> _editMember(BuildContext context, DraftRole role,
      {DraftMember? existing}) async {
    final result = await showMemberEditor(context, ref,
        role: role, existing: existing, adults: controller.adults);
    if (result == null) return;
    if (existing == null) {
      controller.addMember(role, result.name,
          descriptionText: result.description,
          spriteSha256: result.sprite,
          fundedByUserId: result.fundedBy);
    } else {
      controller.updateMember(existing.localId,
          name: result.name,
          descriptionText: result.description,
          spriteSha256: result.sprite,
          fundedByUserId: result.fundedBy);
    }
  }
}

class _RoleSection extends StatelessWidget {
  const _RoleSection({required this.role});
  final DraftRole role;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.md, bottom: AppSpacing.xs),
      child: Text(_rolePlural(role), style: AppText.sectionLabel(context)),
    );
  }
}

class _MemberTile extends StatelessWidget {
  const _MemberTile({required this.controller, required this.ref, required this.member});
  final SetupController controller;
  final WidgetRef ref;
  final DraftMember member;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(_roleIcon(member.role)),
      title: Text(member.name),
      subtitle: member.descriptionText == null
          ? null
          : Text(member.descriptionText!, maxLines: 1,
              overflow: TextOverflow.ellipsis),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (member.spriteSha256 != null)
            const Icon(Icons.image_outlined, size: 18),
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            onPressed: () async {
              final result = await showMemberEditor(context, ref,
                  role: member.role, existing: member, adults: controller.adults);
              if (result != null) {
                controller.updateMember(member.localId,
                    name: result.name,
                    descriptionText: result.description,
                    spriteSha256: result.sprite,
                    fundedByUserId: result.fundedBy);
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () => controller.removeMember(member.localId),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Step 3 — income
// ---------------------------------------------------------------------------

class _IncomeStep extends StatelessWidget {
  const _IncomeStep({required this.controller});
  final SetupController controller;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        const _StepIntro(
          'Set each adult\'s usual monthly income. It carries forward every '
          'month until you change it. Zero is fine — enter it and move on.',
        ),
        for (final adult in controller.adults)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            child: _MoneyField(
              label: '${adult.name}\'s monthly income',
              cents: controller.incomeOf(adult.localId),
              onChanged: (value) => controller.setIncome(adult.localId, value),
            ),
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Step 4 — tracked accounts
// ---------------------------------------------------------------------------

class _AccountsStep extends StatelessWidget {
  const _AccountsStep({required this.controller});
  final SetupController controller;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        const _StepIntro(
          'Optional: track savings, investments, and debts for your net-worth '
          'screen. These never touch your budget — they just get watched.',
        ),
        for (var i = 0; i < controller.accounts.length; i++)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(_accountIcon(controller.accounts[i].kind)),
            title: Text(controller.accounts[i].name),
            subtitle: Text(
                '${controller.accounts[i].kind.name} · ${money(controller.accounts[i].balanceCents)}'),
            trailing: IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: () => controller.removeAccount(i),
            ),
          ),
        const SizedBox(height: AppSpacing.sm),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () async {
              final account = await showAccountEditor(context);
              if (account != null) controller.addAccount(account);
            },
            icon: const Icon(Icons.add),
            label: const Text('Add account'),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Step 5 — fixed expenses
// ---------------------------------------------------------------------------

class _ExpensesStep extends StatelessWidget {
  const _ExpensesStep({required this.controller});
  final SetupController controller;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        const _StepIntro(
          'Recurring bills that come off the top before budgets are funded. '
          'Group bills split across the household; personal ones sit on one '
          'adult. Bills that change month to month (like utilities) can use an '
          'estimate — you enter the real amount at month end.',
        ),
        for (var i = 0; i < controller.fixedExpenses.length; i++)
          _expenseTile(context, i),
        const SizedBox(height: AppSpacing.sm),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () async {
              final expense = await showExpenseEditor(context, controller);
              if (expense != null) controller.addFixedExpense(expense);
            },
            icon: const Icon(Icons.add),
            label: const Text('Add bill'),
          ),
        ),
      ],
    );
  }

  Widget _expenseTile(BuildContext context, int i) {
    final expense = controller.fixedExpenses[i];
    final owner = expense.shared ? 'Group' : (controller.memberById(expense.ownerLocalId ?? '')?.name ?? 'Personal');
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.autorenew),
      title: Text(expense.name),
      subtitle: Text(
        '$owner · ${money(expense.amountCents)}'
        '${expense.kind == RecurringKind.variable ? ' est.' : ''} · '
        '${expense.cadence == RecurringCadence.annual ? 'annual' : 'monthly'}',
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            onPressed: () async {
              final edited =
                  await showExpenseEditor(context, controller, existing: expense);
              if (edited != null) controller.updateFixedExpense(i, edited);
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () => controller.removeFixedExpense(i),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Step 6 — budget allocation
// ---------------------------------------------------------------------------

class _BudgetStep extends StatelessWidget {
  const _BudgetStep({required this.controller});
  final SetupController controller;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        _Banner(
          icon: Icons.savings_outlined,
          text: 'Total monthly income: ${money(controller.totalIncomeCents)}',
        ),
        const _StepIntro(
          'Fund group categories first, propose the split, then give each adult '
          'personal categories until their leftover counter reaches zero.',
        ),
        if (controller.anyOverAllocated)
          _Banner(
            icon: Icons.warning_amber_outlined,
            text: 'A plan exceeds someone\'s income — trim limits below '
                'until every adult is at or under zero.',
          ),
        _mainCategoriesCard(context),
        Text('Group categories', style: AppText.sectionLabel(context)),
        for (var i = 0; i < controller.categories.length; i++)
          if (controller.categories[i].group) _categoryTile(context, i),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () async {
              final category = await showCategoryEditor(context, controller, group: true);
              if (category != null) controller.addCategory(category);
            },
            icon: const Icon(Icons.add),
            label: const Text('Add group category'),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        _Banner(
          icon: Icons.groups_outlined,
          text: 'Group burden (funded by shares): ${money(controller.groupBurdenCents)}',
        ),
        if (controller.adults.length > 1) _sharesCard(context),
        const Divider(height: AppSpacing.xl),
        Text('Personal categories', style: AppText.sectionLabel(context)),
        for (final adult in controller.adults) _adultBudget(context, adult, scheme),
      ],
    );
  }

  Widget _mainCategoriesCard(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('Main categories',
                      style: Theme.of(context).textTheme.titleSmall),
                ),
                TextButton(
                  onPressed: () => showMainCategoriesEditor(context, controller),
                  child: const Text('Customize'),
                ),
              ],
            ),
            Text(
              controller.mainCategories.map((mainCategory) => mainCategory.name).join(' · '),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sharesCard(BuildContext context) {
    final shares = controller.effectiveShares();
    return Card(
      margin: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('Share split',
                      style: Theme.of(context).textTheme.titleSmall),
                ),
                TextButton(
                  onPressed: () async {
                    final editedShares = await showSharesEditor(context, controller);
                    if (editedShares != null) controller.setShares(editedShares);
                  },
                  child: Text(controller.shares == null ? 'Even (edit)' : 'Custom (edit)'),
                ),
              ],
            ),
            for (final adult in controller.adults)
              Text(
                  '${adult.name}: ${(shares[adult.localId] ?? 0) / 10}%'),
          ],
        ),
      ),
    );
  }

  Widget _adultBudget(BuildContext context, DraftMember adult, ColorScheme scheme) {
    final alloc = controller.allocationFor(adult.localId);
    final left = alloc.unallocatedCents;
    final color = left == 0
        ? scheme.primary
        : (left < 0 ? scheme.error : scheme.onSurfaceVariant);
    return Card(
      margin: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                    child: Text(adult.name,
                        style: Theme.of(context).textTheme.titleMedium)),
                Text(
                  left == 0
                      ? 'All allocated'
                      : '${signedMoney(left)} left',
                  style: Theme.of(context)
                      .textTheme
                      .labelLarge
                      ?.copyWith(color: color, fontWeight: FontWeight.w600),
                ),
              ],
            ),
            Text(
              'Income ${money(alloc.incomeCents)} · group ${money(alloc.groupShareCents)} '
              '· fixed ${money(alloc.personalFixedCents)}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: AppSpacing.xs),
            for (var i = 0; i < controller.categories.length; i++)
              if (!controller.categories[i].group &&
                  controller.categories[i].ownerLocalId == adult.localId)
                _categoryTile(context, i, dense: true),
            Wrap(
              spacing: AppSpacing.sm,
              children: [
                TextButton.icon(
                  onPressed: () async {
                    final category = await showCategoryEditor(context, controller,
                        group: false, ownerLocalId: adult.localId);
                    if (category != null) controller.addCategory(category);
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('Add category'),
                ),
                TextButton.icon(
                  onPressed: () => controller.splitEvenlyFor(adult.localId),
                  icon: const Icon(Icons.balance_outlined),
                  label: const Text('Split evenly'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _categoryTile(BuildContext context, int i, {bool dense = false}) {
    final category = controller.categories[i];
    return ListTile(
      dense: dense,
      contentPadding: EdgeInsets.zero,
      leading: dense ? null : const Icon(Icons.pie_chart_outline),
      title: Text(category.name),
      subtitle: Text(category.tithePct > 0
          ? '${money(category.limitCents)} · ${category.tithePct}% '
              '${Glossary.carryTax.classic}'
          : money(category.limitCents)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            onPressed: () async {
              final edited = await showCategoryEditor(context, controller,
                  group: category.group,
                  ownerLocalId: category.ownerLocalId,
                  existing: category);
              if (edited != null) controller.updateCategory(i, edited);
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () => controller.removeCategory(i),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Step 7 — first goal + mode
// ---------------------------------------------------------------------------

class _GoalStep extends StatelessWidget {
  const _GoalStep({required this.controller});
  final SetupController controller;

  @override
  Widget build(BuildContext context) {
    final firstQuest = controller.firstQuest;
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        const _StepIntro(
          'Pick a first savings goal. Optional, but '
          'goals are what make the whole thing sing. Fund it at month close.',
        ),
        if (firstQuest == null)
          OutlinedButton.icon(
            onPressed: () async {
              final quest = await showGoalEditor(context, controller);
              if (quest != null) controller.setFirstQuest(quest);
            },
            icon: const Icon(Icons.flag_outlined),
            label: const Text('Choose a first goal'),
          )
        else
          Card(
            child: ListTile(
              leading: const Icon(Icons.flag),
              title: Text(firstQuest.name),
              subtitle: Text(
                  'Target ${money(firstQuest.targetCents)} · ${firstQuest.shared ? 'shared' : 'personal'}'),
              trailing: IconButton(
                icon: const Icon(Icons.delete_outline),
                onPressed: () => controller.setFirstQuest(null),
              ),
            ),
          ),
        const Divider(height: AppSpacing.xl),
        Text(controller.adults.length > 1 ? 'Who wants to play?' : 'Play the game?',
            style: AppText.sectionLabel(context)),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Adventure turns the budget into a game (the default). Standard is '
          'the plain budgeting app — their logging still helps the household. '
          'Anyone can switch any time in Settings.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
        for (final adult in controller.adults) ...[
          const SizedBox(height: AppSpacing.sm),
          if (controller.adults.length > 1) Text(adult.name),
          SegmentedButton<PlayMode>(
            segments: const [
              ButtonSegment(
                value: PlayMode.adventure,
                label: Text('Adventure'),
                icon: Icon(Icons.castle_outlined),
              ),
              ButtonSegment(
                value: PlayMode.standard,
                label: Text('Standard'),
                icon: Icon(Icons.dashboard_outlined),
              ),
            ],
            selected: {controller.modeOf(adult.localId)},
            onSelectionChanged: (selection) => controller.setModeFor(adult.localId, selection.first),
          ),
        ],
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Step 8 — summary
// ---------------------------------------------------------------------------

class _SummaryStep extends StatelessWidget {
  const _SummaryStep({required this.controller});
  final SetupController controller;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        Text('Your household is ready',
            style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: AppSpacing.md),
        _summaryRow(context, Icons.groups_outlined, 'Members',
            '${controller.adults.length} adult(s), ${controller.members.length - controller.adults.length} others'),
        _summaryRow(context, Icons.payments_outlined, 'Total income',
            '${money(controller.totalIncomeCents)}/mo'),
        _summaryRow(context, Icons.trending_up, 'Tracked accounts',
            '${controller.accounts.length}'),
        _summaryRow(context, Icons.autorenew, 'Fixed expenses',
            '${controller.fixedExpenses.length}'),
        _summaryRow(context, Icons.pie_chart_outline, 'Budget categories',
            '${controller.categories.length}'),
        _summaryRow(context, Icons.flag_outlined, 'First goal',
            controller.firstQuest?.name ?? 'none yet'),
        _summaryRow(
            context,
            Icons.videogame_asset_outlined,
            'Mode',
            [
              for (final adult in controller.adults)
                [
                  if (controller.adults.length > 1) '${adult.name}:',
                  if (controller.modeOf(adult.localId) == PlayMode.adventure)
                    'Adventure'
                  else
                    'Standard',
                ].join(' '),
            ].join(' · ')),
        const SizedBox(height: AppSpacing.lg),
        Card(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: const Padding(
            padding: EdgeInsets.all(AppSpacing.md),
            child: Row(
              children: [
                Icon(Icons.lock_clock, size: 20),
                SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    'Everything you set up here is written to a permanent, '
                    'append-only log. Nothing is ever deleted — later changes '
                    'and corrections are recorded as new entries you can review '
                    'any time in the budget change log.',
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _summaryRow(
      BuildContext context, IconData icon, String label, String value) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon),
      title: Text(label),
      trailing: Text(value, style: Theme.of(context).textTheme.labelLarge),
    );
  }
}

// ---------------------------------------------------------------------------
// Shared little widgets
// ---------------------------------------------------------------------------

class _StepIntro extends StatelessWidget {
  const _StepIntro(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Text(
        text,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant),
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: scheme.secondaryContainer,
        borderRadius: AppRadii.card,
      ),
      child: Row(
        children: [
          Icon(icon, color: scheme.onSecondaryContainer, size: 20),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(text,
                style: TextStyle(color: scheme.onSecondaryContainer)),
          ),
        ],
      ),
    );
  }
}

/// A money text field bound to a cents value, tolerant of `$`, commas, decimals.
class _MoneyField extends StatefulWidget {
  const _MoneyField({
    required this.label,
    required this.cents,
    required this.onChanged,
  });

  final String label;
  final int cents;
  final ValueChanged<int> onChanged;

  @override
  State<_MoneyField> createState() => _MoneyFieldState();
}

class _MoneyFieldState extends State<_MoneyField> {
  late final TextEditingController _ctrl =
      TextEditingController(text: widget.cents == 0 ? '' : Money(widget.cents).format());

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _ctrl,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'[0-9.,$ ]')),
      ],
      decoration: InputDecoration(
        labelText: widget.label,
        prefixText: '\$',
      ),
      onChanged: (value) {
        final trimmed = value.trim();
        if (trimmed.isEmpty) {
          widget.onChanged(0);
          return;
        }
        try {
          widget.onChanged(Money.parse(trimmed).cents);
        } on FormatException {
          // Ignore partial input; the last valid value stands.
        }
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Editors (bottom sheets) — returned via typed results
// ---------------------------------------------------------------------------

class MemberDraftResult {
  const MemberDraftResult(
      {required this.name, this.description, this.sprite, this.fundedBy});
  final String name;
  final String? description;
  final String? sprite;

  /// Pet only: the adult localId funding this pet's budgets (null = group).
  final String? fundedBy;
}

Future<MemberDraftResult?> showMemberEditor(
  BuildContext context,
  WidgetRef ref, {
  required DraftRole role,
  DraftMember? existing,
  List<DraftMember> adults = const [],
}) {
  final nameController = TextEditingController(text: existing?.name ?? '');
  final descriptionController = TextEditingController(text: existing?.descriptionText ?? '');
  String? sprite = existing?.spriteSha256;
  String? fundedBy = existing?.fundedByUserId;

  return showModalBottomSheet<MemberDraftResult>(
    context: context,
    isScrollControlled: true,
    builder: (sheetCtx) => Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.lg,
        right: AppSpacing.lg,
        top: AppSpacing.lg,
        bottom: MediaQuery.of(sheetCtx).viewInsets.bottom + AppSpacing.lg,
      ),
      child: StatefulBuilder(
        builder: (sheetContext, setSheet) => SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('${existing == null ? 'New' : 'Edit'} ${_roleWord(role)}',
                  style: Theme.of(sheetContext).textTheme.titleLarge),
              const SizedBox(height: AppSpacing.lg),
              TextField(
                controller: nameController,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Name'),
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: descriptionController,
                minLines: 2,
                maxLines: 4,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Character description (optional)',
                  helperText: 'Invited free text — feeds text-mode adventure',
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.image_outlined),
                title: Text(sprite == null ? 'Default sprite' : 'Custom sprite'),
                trailing: Wrap(
                  spacing: AppSpacing.xs,
                  children: [
                    if (sprite != null)
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => setSheet(() => sprite = null),
                      ),
                    TextButton(
                      onPressed: () async {
                        final sha = await _pickSprite(ref, sheetContext);
                        if (sha != null) setSheet(() => sprite = sha);
                      },
                      child: const Text('Choose PNG'),
                    ),
                  ],
                ),
              ),
              if (role == DraftRole.pet && adults.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.sm),
                DropdownButtonFormField<String?>(
                  initialValue: fundedBy,
                  decoration: const InputDecoration(
                    labelText: 'Whose budget funds this pet?',
                    helperText:
                        'The group splits pet costs by shares unless one '
                        'adult takes them on.',
                    helperMaxLines: 2,
                  ),
                  items: [
                    const DropdownMenuItem(
                        value: null, child: Text('The group')),
                    for (final adult in adults)
                      DropdownMenuItem(value: adult.localId, child: Text(adult.name)),
                  ],
                  onChanged: (value) => setSheet(() => fundedBy = value),
                ),
              ],
              const SizedBox(height: AppSpacing.md),
              FilledButton(
                onPressed: () {
                  final name = nameController.text.trim();
                  if (name.isEmpty) return;
                  final desc = descriptionController.text.trim();
                  Navigator.of(sheetContext).pop(MemberDraftResult(
                    name: name,
                    description: desc.isEmpty ? null : desc,
                    sprite: sprite,
                    fundedBy: fundedBy,
                  ));
                },
                child: const Text('Save'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

/// Onboarding-time sprite ingest: the household actions provider is still null
/// (no member exists yet), so ingest straight through the blob store.
Future<String?> _pickSprite(WidgetRef ref, BuildContext context) async {
  final messenger = ScaffoldMessenger.of(context);
  const typeGroup = XTypeGroup(label: 'PNG image', extensions: ['png']);
  final file = await openFile(acceptedTypeGroups: const [typeGroup]);
  if (file == null) return null;
  try {
    final bytes = await file.readAsBytes();
    final ingested = await ingestSprite(bytes, ref.read(blobStoreProvider));
    return ingested.sha256;
  } on SpriteRejected catch (error) {
    messenger.showSnackBar(SnackBar(content: Text('Sprite rejected: ${error.message}')));
  } on Object {
    messenger.showSnackBar(
        const SnackBar(content: Text('Could not read that image')));
  }
  return null;
}

Future<DraftAccount?> showAccountEditor(BuildContext context) {
  final nameController = TextEditingController();
  final balanceController = TextEditingController();
  final aprController = TextEditingController();
  final minimumPaymentController = TextEditingController();
  var kind = AccountKind.savings;
  const accrual = AccountCadence.monthly;
  var update = AccountCadence.quarterly;

  int centsOf(TextEditingController textController) {
    final trimmed = textController.text.trim();
    if (trimmed.isEmpty) return 0;
    try {
      return Money.parse(trimmed).cents;
    } on FormatException {
      return 0;
    }
  }

  return showModalBottomSheet<DraftAccount>(
    context: context,
    isScrollControlled: true,
    builder: (sheetCtx) => Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.lg,
        right: AppSpacing.lg,
        top: AppSpacing.lg,
        bottom: MediaQuery.of(sheetCtx).viewInsets.bottom + AppSpacing.lg,
      ),
      child: StatefulBuilder(
        builder: (sheetContext, setSheet) => SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('New account',
                  style: Theme.of(sheetContext).textTheme.titleLarge),
              const SizedBox(height: AppSpacing.md),
              SegmentedButton<AccountKind>(
                segments: const [
                  ButtonSegment(value: AccountKind.savings, label: Text('Savings')),
                  ButtonSegment(
                      value: AccountKind.investment, label: Text('Investment')),
                  ButtonSegment(value: AccountKind.debt, label: Text('Debt')),
                ],
                selected: {kind},
                onSelectionChanged: (selection) => setSheet(() => kind = selection.first),
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: nameController,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'Name'),
              ),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                controller: balanceController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: kind == AccountKind.debt
                      ? 'Amount owed'
                      : kind == AccountKind.investment
                          ? 'Current value'
                          : 'Balance',
                  prefixText: '\$',
                ),
              ),
              if (kind == AccountKind.savings || kind == AccountKind.debt) ...[
                const SizedBox(height: AppSpacing.sm),
                TextField(
                  controller: aprController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'APR %',
                    helperText: 'Interest accrues at read time',
                  ),
                ),
              ],
              if (kind == AccountKind.debt) ...[
                const SizedBox(height: AppSpacing.sm),
                TextField(
                  controller: minimumPaymentController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Minimum payment',
                    helperText: 'Surfaces automatically as a recurring expense',
                    prefixText: '\$',
                  ),
                ),
              ],
              if (kind == AccountKind.investment) ...[
                const SizedBox(height: AppSpacing.sm),
                _CadenceDropdown(
                  label: 'Update cadence',
                  value: update,
                  onChanged: (value) => setSheet(() => update = value),
                ),
              ],
              const SizedBox(height: AppSpacing.lg),
              FilledButton(
                onPressed: () {
                  final name = nameController.text.trim();
                  if (name.isEmpty) return;
                  final aprPct = double.tryParse(aprController.text.trim()) ?? 0;
                  Navigator.of(sheetContext).pop(DraftAccount(
                    name: name,
                    kind: kind,
                    balanceCents: centsOf(balanceController),
                    aprBps: (kind == AccountKind.savings ||
                            kind == AccountKind.debt)
                        ? (aprPct * 100).round()
                        : null,
                    accrualCadence: (kind == AccountKind.savings ||
                            kind == AccountKind.debt)
                        ? accrual
                        : null,
                    updateCadence:
                        kind == AccountKind.investment ? update : null,
                    minPaymentCents:
                        kind == AccountKind.debt ? centsOf(minimumPaymentController) : null,
                  ));
                },
                child: const Text('Add account'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

Future<DraftFixedExpense?> showExpenseEditor(
    BuildContext context, SetupController controller,
    {DraftFixedExpense? existing}) {
  final nameController = TextEditingController(text: existing?.name ?? '');
  final amountController = TextEditingController(
      text: existing == null ? '' : Money(existing.amountCents).format());
  final dueDayController = TextEditingController(text: '${existing?.dueDay ?? 1}');
  var shared = existing?.shared ?? true;
  String? owner = existing?.ownerLocalId ??
      (controller.adults.isNotEmpty ? controller.adults.first.localId : null);
  var kind = existing?.kind ?? RecurringKind.fixed;
  var cadence = existing?.cadence ?? RecurringCadence.monthly;
  var dueMonth = existing?.dueMonth ?? 1;
  // Labels follow this device's adult's chosen mode (Adventure by default).
  final meLocalId = controller.meLocalId;
  final adventure = meLocalId == null || controller.modeOf(meLocalId) == PlayMode.adventure;

  int centsOf() {
    final trimmed = amountController.text.trim();
    if (trimmed.isEmpty) return 0;
    try {
      return Money.parse(trimmed).cents;
    } on FormatException {
      return 0;
    }
  }

  return showModalBottomSheet<DraftFixedExpense>(
    context: context,
    isScrollControlled: true,
    builder: (sheetCtx) => Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.lg,
        right: AppSpacing.lg,
        top: AppSpacing.lg,
        bottom: MediaQuery.of(sheetCtx).viewInsets.bottom + AppSpacing.lg,
      ),
      child: StatefulBuilder(
        builder: (sheetContext, setSheet) => SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(existing == null ? 'New bill' : 'Edit bill',
                  style: Theme.of(sheetContext).textTheme.titleLarge),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: nameController,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'Name'),
              ),
              const SizedBox(height: AppSpacing.sm),
              SegmentedButton<RecurringKind>(
                segments: [
                  ButtonSegment(
                    value: RecurringKind.fixed,
                    label: Text(
                        Glossary.fixedBill.label(isAdventure: adventure)),
                  ),
                  ButtonSegment(
                    value: RecurringKind.variable,
                    label: Text(
                        Glossary.variableBill.label(isAdventure: adventure)),
                  ),
                ],
                selected: {kind},
                onSelectionChanged: (selection) => setSheet(() => kind = selection.first),
              ),
              if (kind == RecurringKind.variable) ...[
                const SizedBox(height: AppSpacing.xs),
                Text(
                  Glossary.variableBill.helper,
                  style: Theme.of(sheetContext).textTheme.bodySmall?.copyWith(
                      color: Theme.of(sheetContext).colorScheme.onSurfaceVariant),
                ),
              ],
              const SizedBox(height: AppSpacing.sm),
              TextField(
                controller: amountController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                    labelText:
                        kind == RecurringKind.variable ? 'Estimate' : 'Amount',
                    prefixText: '\$'),
              ),
              const SizedBox(height: AppSpacing.md),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Group expense'),
                subtitle: const Text('Split across the household; off = one adult'),
                value: shared,
                onChanged: (value) => setSheet(() => shared = value),
              ),
              if (!shared && controller.adults.length > 1)
                _OwnerDropdown(
                  adults: controller.adults,
                  value: owner,
                  onChanged: (value) => setSheet(() => owner = value),
                ),
              const SizedBox(height: AppSpacing.sm),
              SegmentedButton<RecurringCadence>(
                segments: const [
                  ButtonSegment(
                      value: RecurringCadence.monthly, label: Text('Monthly')),
                  ButtonSegment(
                      value: RecurringCadence.annual, label: Text('Annual')),
                ],
                selected: {cadence},
                onSelectionChanged: (selection) => setSheet(() => cadence = selection.first),
              ),
              if (cadence == RecurringCadence.annual) ...[
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Annual bills accrue 1/12 each month off the top, so the '
                  'year is fully reserved by the time it comes due.',
                  style: Theme.of(sheetContext).textTheme.bodySmall?.copyWith(
                      color: Theme.of(sheetContext).colorScheme.onSurfaceVariant),
                ),
                const SizedBox(height: AppSpacing.sm),
                _MonthDropdown(
                  value: dueMonth,
                  onChanged: (value) => setSheet(() => dueMonth = value),
                ),
              ],
              const SizedBox(height: AppSpacing.sm),
              TextField(
                controller: dueDayController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Due day of month (1–31)',
                  helperText: '31 reads as "last day of month"',
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              FilledButton(
                onPressed: () {
                  final name = nameController.text.trim();
                  if (name.isEmpty) return;
                  final day = (int.tryParse(dueDayController.text.trim()) ?? 1)
                      .clamp(1, 31);
                  Navigator.of(sheetContext).pop(DraftFixedExpense(
                    name: name,
                    shared: shared,
                    ownerLocalId: shared ? null : owner,
                    amountCents: centsOf(),
                    kind: kind,
                    cadence: cadence,
                    dueDay: day,
                    dueMonth:
                        cadence == RecurringCadence.annual ? dueMonth : null,
                  ));
                },
                child: Text(existing == null ? 'Add bill' : 'Save'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

Future<DraftCategory?> showCategoryEditor(
  BuildContext context,
  SetupController controller, {
  required bool group,
  String? ownerLocalId,
  DraftCategory? existing,
}) {
  final nameController = TextEditingController(text: existing?.name ?? '');
  final limitController = TextEditingController(
      text: existing == null ? '' : Money(existing.limitCents).format());
  final titheController = TextEditingController(text: '${existing?.tithePct ?? 0}');
  String mainCat = existing?.mainCategoryId ?? controller.mainCategories.first.id;
  final petOwners = <String>{...?existing?.petOwnerIds};

  int centsOf() {
    final trimmed = limitController.text.trim();
    if (trimmed.isEmpty) return 0;
    try {
      return Money.parse(trimmed).cents;
    } on FormatException {
      return 0;
    }
  }

  return showModalBottomSheet<DraftCategory>(
    context: context,
    isScrollControlled: true,
    builder: (sheetCtx) => Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.lg,
        right: AppSpacing.lg,
        top: AppSpacing.lg,
        bottom: MediaQuery.of(sheetCtx).viewInsets.bottom + AppSpacing.lg,
      ),
      child: StatefulBuilder(
        builder: (sheetContext, setSheet) => SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                  existing == null
                      ? '${group ? 'Group' : 'Personal'} category'
                      : 'Edit category',
                  style: Theme.of(sheetContext).textTheme.titleLarge),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: nameController,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'Name'),
              ),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                controller: limitController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                    labelText: 'Monthly limit', prefixText: '\$'),
              ),
              const SizedBox(height: AppSpacing.md),
              DropdownButtonFormField<String>(
                initialValue: mainCat,
                decoration: const InputDecoration(labelText: 'Main category'),
                items: [
                  for (final mainCategory in controller.mainCategories)
                    DropdownMenuItem(value: mainCategory.id, child: Text(mainCategory.name)),
                ],
                onChanged: (value) => setSheet(() => mainCat = value ?? mainCat),
              ),
              if (!group) ...[
                const SizedBox(height: AppSpacing.sm),
                TextField(
                  controller: titheController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Carry tax % (0–100)',
                    helperText: '${Glossary.carryTax.helper} 0 keeps it all.',
                    helperMaxLines: 3,
                  ),
                ),
              ],
              if (group && controller.pets.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.md),
                Text('Belongs to pets (optional)',
                    style: Theme.of(sheetContext).textTheme.labelLarge),
                Text(
                  'Pick every pet this budget covers — they share it '
                  'equally, each paid from that pet\'s funding source.',
                  style: Theme.of(sheetContext).textTheme.bodySmall?.copyWith(
                      color: Theme.of(sheetContext).colorScheme.onSurfaceVariant),
                ),
                const SizedBox(height: AppSpacing.xs),
                Wrap(
                  spacing: AppSpacing.sm,
                  children: [
                    for (final pet in controller.pets)
                      FilterChip(
                        label: Text(pet.name),
                        selected: petOwners.contains(pet.localId),
                        onSelected: (selected) => setSheet(() => selected
                            ? petOwners.add(pet.localId)
                            : petOwners.remove(pet.localId)),
                      ),
                  ],
                ),
              ],
              const SizedBox(height: AppSpacing.lg),
              FilledButton(
                onPressed: () {
                  final name = nameController.text.trim();
                  if (name.isEmpty) return;
                  Navigator.of(sheetContext).pop(DraftCategory(
                    name: name,
                    limitCents: centsOf(),
                    group: group,
                    ownerLocalId: group ? null : ownerLocalId,
                    mainCategoryId: mainCat,
                    petOwnerIds:
                        group ? List.unmodifiable(petOwners) : const [],
                    tithePct: (int.tryParse(titheController.text.trim()) ?? 0)
                        .clamp(0, 100),
                  ));
                },
                child: Text(existing == null ? 'Add category' : 'Save'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

/// Rename existing main categories or add new ones. Changes live in the
/// controller and become `MainCategorySet` events at finish.
Future<void> showMainCategoriesEditor(BuildContext context, SetupController controller) {
  final newNameController = TextEditingController();
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (sheetCtx) => Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.lg,
        right: AppSpacing.lg,
        top: AppSpacing.lg,
        bottom: MediaQuery.of(sheetCtx).viewInsets.bottom + AppSpacing.lg,
      ),
      child: StatefulBuilder(
        builder: (sheetContext, setSheet) => SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Main categories',
                  style: Theme.of(sheetContext).textTheme.titleLarge),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'The big buckets your reports and savings goals group by. Rename '
                'any of them, or add your own.',
                style: Theme.of(sheetContext).textTheme.bodySmall?.copyWith(
                    color: Theme.of(sheetContext).colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: AppSpacing.md),
              for (final mainCategory in controller.mainCategories)
                _MainCategoryRow(
                  key: ValueKey(mainCategory.id),
                  category: mainCategory,
                  onRenamed: (name) =>
                      setSheet(() => controller.renameMainCategory(mainCategory.id, name)),
                ),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: newNameController,
                      decoration:
                          const InputDecoration(labelText: 'New main category'),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  FilledButton(
                    onPressed: () {
                      final name = newNameController.text.trim();
                      if (name.isEmpty) return;
                      setSheet(() {
                        controller.addMainCategory(name);
                        newNameController.clear();
                      });
                    },
                    child: const Text('Add'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

/// One rename row: a text field seeded with the category's name that commits
/// on every change (the controller ignores empty names).
class _MainCategoryRow extends StatefulWidget {
  const _MainCategoryRow(
      {super.key, required this.category, required this.onRenamed});

  final MainCategory category;
  final ValueChanged<String> onRenamed;

  @override
  State<_MainCategoryRow> createState() => _MainCategoryRowState();
}

class _MainCategoryRowState extends State<_MainCategoryRow> {
  late final TextEditingController _ctrl =
      TextEditingController(text: widget.category.name);

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        children: [
          Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(
              color: Color(widget.category.colorArgb),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: TextField(
              controller: _ctrl,
              decoration: const InputDecoration(isDense: true),
              onChanged: widget.onRenamed,
            ),
          ),
        ],
      ),
    );
  }
}

Future<Map<String, int>?> showSharesEditor(
    BuildContext context, SetupController controller) {
  final ctrls = {
    for (final adult in controller.adults)
      adult.localId: TextEditingController(
        text: ((controller.effectiveShares()[adult.localId] ?? 0) / 10).toStringAsFixed(1),
      ),
  };
  return showModalBottomSheet<Map<String, int>>(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) => Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.lg,
        right: AppSpacing.lg,
        top: AppSpacing.lg,
        bottom: MediaQuery.of(sheetContext).viewInsets.bottom + AppSpacing.lg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Share split (%)',
              style: Theme.of(sheetContext).textTheme.titleLarge),
          const SizedBox(height: AppSpacing.sm),
          const Text('Shares fund group costs off the top. They should add to '
              '100%.'),
          const SizedBox(height: AppSpacing.md),
          for (final adult in controller.adults)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
              child: TextField(
                controller: ctrls[adult.localId],
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                    labelText: adult.name, suffixText: '%'),
              ),
            ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(sheetContext).pop(<String, int>{}),
                  child: const Text('Reset to even'),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: FilledButton(
                  onPressed: () {
                    final result = <String, int>{
                      for (final adult in controller.adults)
                        adult.localId: ((double.tryParse(
                                        ctrls[adult.localId]!.text.trim()) ??
                                    0) *
                                10)
                            .round(),
                    };
                    Navigator.of(sheetContext).pop(result);
                  },
                  child: const Text('Save'),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  ).then((shares) {
    // An empty map is the "reset to even" sentinel.
    if (shares == null) return null;
    return shares.isEmpty ? null : shares;
  });
}

Future<DraftQuest?> showGoalEditor(BuildContext context, SetupController controller) {
  final nameController = TextEditingController();
  final targetController = TextEditingController();
  final descriptionController = TextEditingController();
  var shared = true;
  String? owner = controller.adults.isNotEmpty ? controller.adults.first.localId : null;
  const mainCat = 'savings';

  int centsOf() {
    final trimmed = targetController.text.trim();
    if (trimmed.isEmpty) return 0;
    try {
      return Money.parse(trimmed).cents;
    } on FormatException {
      return 0;
    }
  }

  return showModalBottomSheet<DraftQuest>(
    context: context,
    isScrollControlled: true,
    builder: (sheetCtx) => Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.lg,
        right: AppSpacing.lg,
        top: AppSpacing.lg,
        bottom: MediaQuery.of(sheetCtx).viewInsets.bottom + AppSpacing.lg,
      ),
      child: StatefulBuilder(
        builder: (sheetContext, setSheet) => SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('First goal',
                  style: Theme.of(sheetContext).textTheme.titleLarge),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: nameController,
                autofocus: true,
                decoration: const InputDecoration(
                    labelText: 'Goal name', hintText: 'e.g. Canoe'),
              ),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                controller: targetController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                    labelText: 'Target amount', prefixText: '\$'),
              ),
              const SizedBox(height: AppSpacing.md),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Shared goal'),
                subtitle: const Text('Any adult can fund it'),
                value: shared,
                onChanged: (value) => setSheet(() => shared = value),
              ),
              if (!shared && controller.adults.length > 1)
                _OwnerDropdown(
                  adults: controller.adults,
                  value: owner,
                  onChanged: (value) => setSheet(() => owner = value),
                ),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                controller: descriptionController,
                minLines: 2,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Description (optional)',
                  helperText: 'Feeds text-mode adventure',
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              FilledButton(
                onPressed: () {
                  final name = nameController.text.trim();
                  if (name.isEmpty) return;
                  final desc = descriptionController.text.trim();
                  Navigator.of(sheetContext).pop(DraftQuest(
                    name: name,
                    targetCents: centsOf(),
                    shared: shared,
                    ownerLocalId: shared ? null : owner,
                    mainCategoryId: mainCat,
                    descriptionText: desc.isEmpty ? null : desc,
                  ));
                },
                child: const Text('Set goal'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _OwnerDropdown extends StatelessWidget {
  const _OwnerDropdown({
    required this.adults,
    required this.value,
    required this.onChanged,
  });

  final List<DraftMember> adults;
  final String? value;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      decoration: const InputDecoration(labelText: 'Owner'),
      items: [
        for (final adult in adults)
          DropdownMenuItem(value: adult.localId, child: Text(adult.name)),
      ],
      onChanged: onChanged,
    );
  }
}

class _CadenceDropdown extends StatelessWidget {
  const _CadenceDropdown({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final AccountCadence value;
  final ValueChanged<AccountCadence> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<AccountCadence>(
      initialValue: value,
      decoration: InputDecoration(labelText: label),
      items: [
        for (final cadence in AccountCadence.values)
          DropdownMenuItem(value: cadence, child: Text(cadence.name)),
      ],
      onChanged: (value) => value == null ? null : onChanged(value),
    );
  }
}

class _MonthDropdown extends StatelessWidget {
  const _MonthDropdown({required this.value, required this.onChanged});
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<int>(
      initialValue: value,
      decoration: const InputDecoration(labelText: 'Due month'),
      items: [
        for (var monthNumber = 1; monthNumber <= 12; monthNumber++)
          DropdownMenuItem(value: monthNumber, child: Text(monthLabel(2026, monthNumber).split(' ').first)),
      ],
      onChanged: (value) => value == null ? null : onChanged(value),
    );
  }
}

// ---- role helpers ---------------------------------------------------------

String _roleWord(DraftRole role) => switch (role) {
      DraftRole.adult => 'adult',
      DraftRole.dependent => 'dependent',
      DraftRole.pet => 'pet',
    };

String _rolePlural(DraftRole role) => switch (role) {
      DraftRole.adult => 'Adults',
      DraftRole.dependent => 'Dependents',
      DraftRole.pet => 'Pets',
    };

IconData _roleIcon(DraftRole role) => switch (role) {
      DraftRole.adult => Icons.person_outline,
      DraftRole.dependent => Icons.child_care_outlined,
      DraftRole.pet => Icons.pets_outlined,
    };

IconData _accountIcon(AccountKind kind) => switch (kind) {
      AccountKind.savings => Icons.savings_outlined,
      AccountKind.investment => Icons.show_chart,
      AccountKind.debt => Icons.credit_card,
      AccountKind.cash => Icons.attach_money,
    };
