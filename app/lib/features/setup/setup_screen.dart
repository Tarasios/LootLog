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
import '../../game/skin_prefs.dart';
import '../../ui/format.dart';
import '../../ui/theme.dart';
import 'join_party_screen.dart';
import 'onboarding_plan.dart';
import 'setup_controller.dart';

/// The ordered steps of the wizard (after the welcome/join gate).
enum _Step { party, income, accounts, expenses, budget, goal, summary }

const _stepTitles = <_Step, String>{
  _Step.party: 'Your party',
  _Step.income: 'Expedition supplies',
  _Step.accounts: 'Treasury',
  _Step.expenses: 'Standing obligations',
  _Step.budget: 'Dividing the coin',
  _Step.goal: 'First quest',
  _Step.summary: 'Ready to delve',
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
  final _c = SetupController();
  int _index = -1; // -1 == the welcome/join gate
  bool _busy = false;
  String? _finishError;

  @override
  void initState() {
    super.initState();
    _c.addListener(_onChange);
    if (widget.debugJumpToSummary) _index = _Step.summary.index;
  }

  @override
  void dispose() {
    _c.removeListener(_onChange);
    _c.dispose();
    super.dispose();
  }

  void _onChange() => setState(() {});

  _Step get _step => _Step.values[_index];

  bool get _canAdvance {
    if (_index < 0) return true;
    return switch (_step) {
      _Step.party => _c.hasAdult && _c.meLocalId != null,
      // The plan may not exceed anyone's income.
      _Step.budget => !_c.anyOverAllocated,
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
        _Step.party => _PartyStep(c: _c, ref: ref),
        _Step.income => _IncomeStep(c: _c),
        _Step.accounts => _AccountsStep(c: _c),
        _Step.expenses => _ExpensesStep(c: _c),
        _Step.budget => _BudgetStep(c: _c),
        _Step.goal => _GoalStep(c: _c),
        _Step.summary => _SummaryStep(c: _c),
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
                  child: Text(isSummary ? 'Begin the adventure' : 'Next'),
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
                    'Assemble your party and delve a budget together. '
                    'First: are you joining a party that already exists on '
                    'another device?',
                    style: text.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  FilledButton.icon(
                    onPressed: () => JoinPartyScreen.open(context),
                    icon: const Icon(Icons.qr_code_scanner),
                    label: const Text('Join an existing party'),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  OutlinedButton.icon(
                    onPressed: () => setState(() => _index = 0),
                    icon: const Icon(Icons.group_add_outlined),
                    label: const Text('Start a new party'),
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
      final input = _c.buildInput();
      final db = ref.read(appDatabaseProvider);
      final plan = buildOnboardingEvents(
        input,
        deviceId: ref.read(deviceIdProvider),
        startMonth: Month.fromInstant(DateTime.now().toUtc()),
      );
      await db.eventsDao.appendEvents(plan.events);
      await ref.read(appSkinProvider.notifier).select(_c.mode);
      if (mounted) await _celebrate();
      // Saving the local setup flips isSetUpProvider and the router hands off
      // to the main shell.
      await db.localSetupDao.save(plan.localSetup);
    } on Object catch (e) {
      if (mounted) {
        setState(() => _finishError = 'Could not save your setup: $e');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _celebrate() async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.celebration, size: 48),
        title: const Text('Your party is ready!'),
        content: const Text(
          'Every choice you made is now permanently logged and can always be '
          'changed later from Settings. Log a purchase to earn your first '
          'streak — the adventure begins now.',
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Enter the dungeon'),
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
  const _PartyStep({required this.c, required this.ref});

  final SetupController c;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        const _StepIntro(
          'Add the adventurers, dependents, and pets in your household. '
          'Adults carry income and a budget; everyone else joins the party. '
          'A description feeds the text-mode adventure.',
        ),
        for (final role in DraftRole.values) ...[
          _RoleSection(role: role),
          for (final m in c.members.where((m) => m.role == role))
            _MemberTile(c: c, ref: ref, member: m),
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
        if (c.adults.length > 1) ...[
          const Divider(),
          Text('Which adult is this device?',
              style: AppText.sectionLabel(context)),
          const SizedBox(height: AppSpacing.sm),
          for (final a in c.adults)
            RadioListTile<String>(
              contentPadding: EdgeInsets.zero,
              value: a.localId,
              groupValue: c.meLocalId,
              title: Text(a.name),
              onChanged: (v) => v == null ? null : c.setMe(v),
            ),
        ],
      ],
    );
  }

  Future<void> _editMember(BuildContext context, DraftRole role,
      {DraftMember? existing}) async {
    final result = await showMemberEditor(context, ref,
        role: role, existing: existing, adults: c.adults);
    if (result == null) return;
    if (existing == null) {
      c.addMember(role, result.name,
          descriptionText: result.description,
          spriteSha256: result.sprite,
          fundedByUserId: result.fundedBy);
    } else {
      c.updateMember(existing.localId,
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
  const _MemberTile({required this.c, required this.ref, required this.member});
  final SetupController c;
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
                  role: member.role, existing: member, adults: c.adults);
              if (result != null) {
                c.updateMember(member.localId,
                    name: result.name,
                    descriptionText: result.description,
                    spriteSha256: result.sprite,
                    fundedByUserId: result.fundedBy);
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () => c.removeMember(member.localId),
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
  const _IncomeStep({required this.c});
  final SetupController c;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        const _StepIntro(
          'Set each adult\'s usual monthly income. It carries forward every '
          'month until you change it. Zero is fine — enter it and move on.',
        ),
        for (final a in c.adults)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            child: _MoneyField(
              label: '${a.name}\'s monthly income',
              cents: c.incomeOf(a.localId),
              onChanged: (v) => c.setIncome(a.localId, v),
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
  const _AccountsStep({required this.c});
  final SetupController c;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        const _StepIntro(
          'Optional: track savings, investments, and debts for your net-worth '
          'screen. These never touch your budget — they just get watched.',
        ),
        for (var i = 0; i < c.accounts.length; i++)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(_accountIcon(c.accounts[i].kind)),
            title: Text(c.accounts[i].name),
            subtitle: Text(
                '${c.accounts[i].kind.name} · ${money(c.accounts[i].balanceCents)}'),
            trailing: IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: () => c.removeAccount(i),
            ),
          ),
        const SizedBox(height: AppSpacing.sm),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () async {
              final a = await showAccountEditor(context);
              if (a != null) c.addAccount(a);
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
  const _ExpensesStep({required this.c});
  final SetupController c;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        const _StepIntro(
          'Recurring bills that come off the top before you divide the coin. '
          'Group bills split by the party; personal ones sit on one adult.',
        ),
        for (var i = 0; i < c.fixedExpenses.length; i++)
          _expenseTile(context, i),
        const SizedBox(height: AppSpacing.sm),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () async {
              final e = await showExpenseEditor(context, c);
              if (e != null) c.addFixedExpense(e);
            },
            icon: const Icon(Icons.add),
            label: const Text('Add fixed expense'),
          ),
        ),
      ],
    );
  }

  Widget _expenseTile(BuildContext context, int i) {
    final e = c.fixedExpenses[i];
    final owner = e.shared ? 'Group' : (c.memberById(e.ownerLocalId ?? '')?.name ?? 'Personal');
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.autorenew),
      title: Text(e.name),
      subtitle: Text(
        '$owner · ${money(e.amountCents)} · '
        '${e.cadence == RecurringCadence.annual ? 'annual' : 'monthly'}',
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            onPressed: () async {
              final edited =
                  await showExpenseEditor(context, c, existing: e);
              if (edited != null) c.updateFixedExpense(i, edited);
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () => c.removeFixedExpense(i),
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
  const _BudgetStep({required this.c});
  final SetupController c;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        _Banner(
          icon: Icons.savings_outlined,
          text: 'Total monthly income: ${money(c.totalIncomeCents)}',
        ),
        const _StepIntro(
          'Fund group categories first, propose the split, then give each adult '
          'personal categories until their leftover counter reaches zero.',
        ),
        if (c.anyOverAllocated)
          _Banner(
            icon: Icons.warning_amber_outlined,
            text: 'A plan exceeds someone\'s income — trim limits below '
                'until every adult is at or under zero.',
          ),
        _mainCategoriesCard(context),
        Text('Group categories', style: AppText.sectionLabel(context)),
        for (var i = 0; i < c.categories.length; i++)
          if (c.categories[i].group) _categoryTile(context, i),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () async {
              final cat = await showCategoryEditor(context, c, group: true);
              if (cat != null) c.addCategory(cat);
            },
            icon: const Icon(Icons.add),
            label: const Text('Add group category'),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        _Banner(
          icon: Icons.groups_outlined,
          text: 'Group burden (funded by shares): ${money(c.groupBurdenCents)}',
        ),
        if (c.adults.length > 1) _sharesCard(context),
        const Divider(height: AppSpacing.xl),
        Text('Personal categories', style: AppText.sectionLabel(context)),
        for (final a in c.adults) _adultBudget(context, a, scheme),
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
                  onPressed: () => showMainCategoriesEditor(context, c),
                  child: const Text('Customize'),
                ),
              ],
            ),
            Text(
              c.mainCategories.map((m) => m.name).join(' · '),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sharesCard(BuildContext context) {
    final shares = c.effectiveShares();
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
                    final s = await showSharesEditor(context, c);
                    if (s != null) c.setShares(s);
                  },
                  child: Text(c.shares == null ? 'Even (edit)' : 'Custom (edit)'),
                ),
              ],
            ),
            for (final a in c.adults)
              Text(
                  '${a.name}: ${(shares[a.localId] ?? 0) / 10}%'),
          ],
        ),
      ),
    );
  }

  Widget _adultBudget(BuildContext context, DraftMember a, ColorScheme scheme) {
    final alloc = c.allocationFor(a.localId);
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
                    child: Text(a.name,
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
            for (var i = 0; i < c.categories.length; i++)
              if (!c.categories[i].group &&
                  c.categories[i].ownerLocalId == a.localId)
                _categoryTile(context, i, dense: true),
            Wrap(
              spacing: AppSpacing.sm,
              children: [
                TextButton.icon(
                  onPressed: () async {
                    final cat = await showCategoryEditor(context, c,
                        group: false, ownerLocalId: a.localId);
                    if (cat != null) c.addCategory(cat);
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('Add category'),
                ),
                TextButton.icon(
                  onPressed: () => c.splitEvenlyFor(a.localId),
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
    final cat = c.categories[i];
    return ListTile(
      dense: dense,
      contentPadding: EdgeInsets.zero,
      leading: dense ? null : const Icon(Icons.pie_chart_outline),
      title: Text(cat.name),
      subtitle: Text(cat.tithePct > 0
          ? '${money(cat.limitCents)} · ${cat.tithePct}% tithe'
          : money(cat.limitCents)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            onPressed: () async {
              final edited = await showCategoryEditor(context, c,
                  group: cat.group,
                  ownerLocalId: cat.ownerLocalId,
                  existing: cat);
              if (edited != null) c.updateCategory(i, edited);
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () => c.removeCategory(i),
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
  const _GoalStep({required this.c});
  final SetupController c;

  @override
  Widget build(BuildContext context) {
    final q = c.firstQuest;
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        const _StepIntro(
          'Pick a first savings goal — your first quest boss. Optional, but '
          'goals are what make the whole thing sing. Fund it at month close.',
        ),
        if (q == null)
          OutlinedButton.icon(
            onPressed: () async {
              final quest = await showGoalEditor(context, c);
              if (quest != null) c.setFirstQuest(quest);
            },
            icon: const Icon(Icons.flag_outlined),
            label: const Text('Choose a first goal'),
          )
        else
          Card(
            child: ListTile(
              leading: const Icon(Icons.flag),
              title: Text(q.name),
              subtitle: Text(
                  'Target ${money(q.targetCents)} · ${q.shared ? 'shared' : 'personal'}'),
              trailing: IconButton(
                icon: const Icon(Icons.delete_outline),
                onPressed: () => c.setFirstQuest(null),
              ),
            ),
          ),
        const Divider(height: AppSpacing.xl),
        Text('How should the app look?', style: AppText.sectionLabel(context)),
        const SizedBox(height: AppSpacing.sm),
        SegmentedButton<AppSkin>(
          segments: const [
            ButtonSegment(
              value: AppSkin.adventure,
              label: Text('Adventure'),
              icon: Icon(Icons.castle_outlined),
            ),
            ButtonSegment(
              value: AppSkin.classic,
              label: Text('Classic'),
              icon: Icon(Icons.dashboard_outlined),
            ),
          ],
          selected: {c.mode},
          onSelectionChanged: (s) => c.setMode(s.first),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          c.mode == AppSkin.adventure
              ? 'The dungeon-crawler skin (default). Same numbers, more fun.'
              : 'A plain ledger view. You can switch any time in Settings.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Step 8 — summary
// ---------------------------------------------------------------------------

class _SummaryStep extends StatelessWidget {
  const _SummaryStep({required this.c});
  final SetupController c;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        Text('Your party is ready to delve',
            style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: AppSpacing.md),
        _summaryRow(context, Icons.groups_outlined, 'Members',
            '${c.adults.length} adult(s), ${c.members.length - c.adults.length} others'),
        _summaryRow(context, Icons.payments_outlined, 'Total income',
            '${money(c.totalIncomeCents)}/mo'),
        _summaryRow(context, Icons.trending_up, 'Tracked accounts',
            '${c.accounts.length}'),
        _summaryRow(context, Icons.autorenew, 'Fixed expenses',
            '${c.fixedExpenses.length}'),
        _summaryRow(context, Icons.pie_chart_outline, 'Budget categories',
            '${c.categories.length}'),
        _summaryRow(context, Icons.flag_outlined, 'First goal',
            c.firstQuest?.name ?? 'none yet'),
        _summaryRow(
            context,
            Icons.videogame_asset_outlined,
            'Mode',
            c.mode == AppSkin.adventure ? 'Adventure' : 'Classic'),
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
      onChanged: (v) {
        final trimmed = v.trim();
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
  final nameCtrl = TextEditingController(text: existing?.name ?? '');
  final descCtrl = TextEditingController(text: existing?.descriptionText ?? '');
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
        builder: (sheetCtx, setSheet) => SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('${existing == null ? 'New' : 'Edit'} ${_roleWord(role)}',
                  style: Theme.of(sheetCtx).textTheme.titleLarge),
              const SizedBox(height: AppSpacing.lg),
              TextField(
                controller: nameCtrl,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Name'),
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: descCtrl,
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
                        final sha = await _pickSprite(ref, sheetCtx);
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
                    for (final a in adults)
                      DropdownMenuItem(value: a.localId, child: Text(a.name)),
                  ],
                  onChanged: (v) => setSheet(() => fundedBy = v),
                ),
              ],
              const SizedBox(height: AppSpacing.md),
              FilledButton(
                onPressed: () {
                  final name = nameCtrl.text.trim();
                  if (name.isEmpty) return;
                  final desc = descCtrl.text.trim();
                  Navigator.of(sheetCtx).pop(MemberDraftResult(
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
  } on SpriteRejected catch (e) {
    messenger.showSnackBar(SnackBar(content: Text('Sprite rejected: ${e.message}')));
  } on Object {
    messenger.showSnackBar(
        const SnackBar(content: Text('Could not read that image')));
  }
  return null;
}

Future<DraftAccount?> showAccountEditor(BuildContext context) {
  final nameCtrl = TextEditingController();
  final balanceCtrl = TextEditingController();
  final aprCtrl = TextEditingController();
  final minCtrl = TextEditingController();
  var kind = AccountKind.savings;
  const accrual = AccountCadence.monthly;
  var update = AccountCadence.quarterly;

  int centsOf(TextEditingController c) {
    final t = c.text.trim();
    if (t.isEmpty) return 0;
    try {
      return Money.parse(t).cents;
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
        builder: (sheetCtx, setSheet) => SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('New account',
                  style: Theme.of(sheetCtx).textTheme.titleLarge),
              const SizedBox(height: AppSpacing.md),
              SegmentedButton<AccountKind>(
                segments: const [
                  ButtonSegment(value: AccountKind.savings, label: Text('Savings')),
                  ButtonSegment(
                      value: AccountKind.investment, label: Text('Investment')),
                  ButtonSegment(value: AccountKind.debt, label: Text('Debt')),
                ],
                selected: {kind},
                onSelectionChanged: (s) => setSheet(() => kind = s.first),
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: nameCtrl,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'Name'),
              ),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                controller: balanceCtrl,
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
                  controller: aprCtrl,
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
                  controller: minCtrl,
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
                  onChanged: (v) => setSheet(() => update = v),
                ),
              ],
              const SizedBox(height: AppSpacing.lg),
              FilledButton(
                onPressed: () {
                  final name = nameCtrl.text.trim();
                  if (name.isEmpty) return;
                  final aprPct = double.tryParse(aprCtrl.text.trim()) ?? 0;
                  Navigator.of(sheetCtx).pop(DraftAccount(
                    name: name,
                    kind: kind,
                    balanceCents: centsOf(balanceCtrl),
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
                        kind == AccountKind.debt ? centsOf(minCtrl) : null,
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
    BuildContext context, SetupController c,
    {DraftFixedExpense? existing}) {
  final nameCtrl = TextEditingController(text: existing?.name ?? '');
  final amountCtrl = TextEditingController(
      text: existing == null ? '' : Money(existing.amountCents).format());
  final dayCtrl = TextEditingController(text: '${existing?.dueDay ?? 1}');
  var shared = existing?.shared ?? true;
  String? owner = existing?.ownerLocalId ??
      (c.adults.isNotEmpty ? c.adults.first.localId : null);
  var cadence = existing?.cadence ?? RecurringCadence.monthly;
  var dueMonth = existing?.dueMonth ?? 1;

  int centsOf() {
    final t = amountCtrl.text.trim();
    if (t.isEmpty) return 0;
    try {
      return Money.parse(t).cents;
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
        builder: (sheetCtx, setSheet) => SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(existing == null ? 'New fixed expense' : 'Edit fixed expense',
                  style: Theme.of(sheetCtx).textTheme.titleLarge),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: nameCtrl,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'Name'),
              ),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                controller: amountCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                    labelText: 'Amount', prefixText: '\$'),
              ),
              const SizedBox(height: AppSpacing.md),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Group expense'),
                subtitle: const Text('Split by the party; off = one adult'),
                value: shared,
                onChanged: (v) => setSheet(() => shared = v),
              ),
              if (!shared && c.adults.length > 1)
                _OwnerDropdown(
                  adults: c.adults,
                  value: owner,
                  onChanged: (v) => setSheet(() => owner = v),
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
                onSelectionChanged: (s) => setSheet(() => cadence = s.first),
              ),
              if (cadence == RecurringCadence.annual) ...[
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Annual bills accrue 1/12 each month off the top, so the '
                  'year is fully reserved by the time it comes due.',
                  style: Theme.of(sheetCtx).textTheme.bodySmall?.copyWith(
                      color: Theme.of(sheetCtx).colorScheme.onSurfaceVariant),
                ),
                const SizedBox(height: AppSpacing.sm),
                _MonthDropdown(
                  value: dueMonth,
                  onChanged: (v) => setSheet(() => dueMonth = v),
                ),
              ],
              const SizedBox(height: AppSpacing.sm),
              TextField(
                controller: dayCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Due day of month (1–31)',
                  helperText: '31 reads as "last day of month"',
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              FilledButton(
                onPressed: () {
                  final name = nameCtrl.text.trim();
                  if (name.isEmpty) return;
                  final day = (int.tryParse(dayCtrl.text.trim()) ?? 1)
                      .clamp(1, 31);
                  Navigator.of(sheetCtx).pop(DraftFixedExpense(
                    name: name,
                    shared: shared,
                    ownerLocalId: shared ? null : owner,
                    amountCents: centsOf(),
                    cadence: cadence,
                    dueDay: day,
                    dueMonth:
                        cadence == RecurringCadence.annual ? dueMonth : null,
                  ));
                },
                child: Text(existing == null ? 'Add expense' : 'Save'),
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
  SetupController c, {
  required bool group,
  String? ownerLocalId,
  DraftCategory? existing,
}) {
  final nameCtrl = TextEditingController(text: existing?.name ?? '');
  final limitCtrl = TextEditingController(
      text: existing == null ? '' : Money(existing.limitCents).format());
  final titheCtrl = TextEditingController(text: '${existing?.tithePct ?? 0}');
  String mainCat = existing?.mainCategoryId ?? c.mainCategories.first.id;
  final petOwners = <String>{...?existing?.petOwnerIds};

  int centsOf() {
    final t = limitCtrl.text.trim();
    if (t.isEmpty) return 0;
    try {
      return Money.parse(t).cents;
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
        builder: (sheetCtx, setSheet) => SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                  existing == null
                      ? '${group ? 'Group' : 'Personal'} category'
                      : 'Edit category',
                  style: Theme.of(sheetCtx).textTheme.titleLarge),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: nameCtrl,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'Name'),
              ),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                controller: limitCtrl,
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
                  for (final m in c.mainCategories)
                    DropdownMenuItem(value: m.id, child: Text(m.name)),
                ],
                onChanged: (v) => setSheet(() => mainCat = v ?? mainCat),
              ),
              if (!group) ...[
                const SizedBox(height: AppSpacing.sm),
                TextField(
                  controller: titheCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Tithe % (0–100)',
                    helperText:
                        'When month-end leftover from this category converts '
                        'to your own pocket money, this share goes to the '
                        'household war chest instead. 0 keeps it all.',
                    helperMaxLines: 3,
                  ),
                ),
              ],
              if (group && c.pets.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.md),
                Text('Belongs to pets (optional)',
                    style: Theme.of(sheetCtx).textTheme.labelLarge),
                Text(
                  'Pick every pet this budget covers — they share it '
                  'equally, each paid from that pet\'s funding source.',
                  style: Theme.of(sheetCtx).textTheme.bodySmall?.copyWith(
                      color: Theme.of(sheetCtx).colorScheme.onSurfaceVariant),
                ),
                const SizedBox(height: AppSpacing.xs),
                Wrap(
                  spacing: AppSpacing.sm,
                  children: [
                    for (final p in c.pets)
                      FilterChip(
                        label: Text(p.name),
                        selected: petOwners.contains(p.localId),
                        onSelected: (on) => setSheet(() => on
                            ? petOwners.add(p.localId)
                            : petOwners.remove(p.localId)),
                      ),
                  ],
                ),
              ],
              const SizedBox(height: AppSpacing.lg),
              FilledButton(
                onPressed: () {
                  final name = nameCtrl.text.trim();
                  if (name.isEmpty) return;
                  Navigator.of(sheetCtx).pop(DraftCategory(
                    name: name,
                    limitCents: centsOf(),
                    group: group,
                    ownerLocalId: group ? null : ownerLocalId,
                    mainCategoryId: mainCat,
                    petOwnerIds:
                        group ? List.unmodifiable(petOwners) : const [],
                    tithePct: (int.tryParse(titheCtrl.text.trim()) ?? 0)
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
Future<void> showMainCategoriesEditor(BuildContext context, SetupController c) {
  final addCtrl = TextEditingController();
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
        builder: (sheetCtx, setSheet) => SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Main categories',
                  style: Theme.of(sheetCtx).textTheme.titleLarge),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'The big buckets your reports and quests group by. Rename '
                'any of them, or add your own.',
                style: Theme.of(sheetCtx).textTheme.bodySmall?.copyWith(
                    color: Theme.of(sheetCtx).colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: AppSpacing.md),
              for (final m in c.mainCategories)
                _MainCategoryRow(
                  key: ValueKey(m.id),
                  category: m,
                  onRenamed: (name) =>
                      setSheet(() => c.renameMainCategory(m.id, name)),
                ),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: addCtrl,
                      decoration:
                          const InputDecoration(labelText: 'New main category'),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  FilledButton(
                    onPressed: () {
                      final name = addCtrl.text.trim();
                      if (name.isEmpty) return;
                      setSheet(() {
                        c.addMainCategory(name);
                        addCtrl.clear();
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
    BuildContext context, SetupController c) {
  final ctrls = {
    for (final a in c.adults)
      a.localId: TextEditingController(
        text: ((c.effectiveShares()[a.localId] ?? 0) / 10).toStringAsFixed(1),
      ),
  };
  return showModalBottomSheet<Map<String, int>>(
    context: context,
    isScrollControlled: true,
    builder: (sheetCtx) => Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.lg,
        right: AppSpacing.lg,
        top: AppSpacing.lg,
        bottom: MediaQuery.of(sheetCtx).viewInsets.bottom + AppSpacing.lg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Share split (%)',
              style: Theme.of(sheetCtx).textTheme.titleLarge),
          const SizedBox(height: AppSpacing.sm),
          const Text('Shares fund group costs off the top. They should add to '
              '100%.'),
          const SizedBox(height: AppSpacing.md),
          for (final a in c.adults)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
              child: TextField(
                controller: ctrls[a.localId],
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                    labelText: a.name, suffixText: '%'),
              ),
            ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(sheetCtx).pop(<String, int>{}),
                  child: const Text('Reset to even'),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: FilledButton(
                  onPressed: () {
                    final result = <String, int>{
                      for (final a in c.adults)
                        a.localId: ((double.tryParse(
                                        ctrls[a.localId]!.text.trim()) ??
                                    0) *
                                10)
                            .round(),
                    };
                    Navigator.of(sheetCtx).pop(result);
                  },
                  child: const Text('Save'),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  ).then((v) {
    // An empty map is the "reset to even" sentinel.
    if (v == null) return null;
    return v.isEmpty ? null : v;
  });
}

Future<DraftQuest?> showGoalEditor(BuildContext context, SetupController c) {
  final nameCtrl = TextEditingController();
  final targetCtrl = TextEditingController();
  final descCtrl = TextEditingController();
  var shared = true;
  String? owner = c.adults.isNotEmpty ? c.adults.first.localId : null;
  const mainCat = 'savings';

  int centsOf() {
    final t = targetCtrl.text.trim();
    if (t.isEmpty) return 0;
    try {
      return Money.parse(t).cents;
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
        builder: (sheetCtx, setSheet) => SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('First goal',
                  style: Theme.of(sheetCtx).textTheme.titleLarge),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: nameCtrl,
                autofocus: true,
                decoration: const InputDecoration(
                    labelText: 'Goal name', hintText: 'e.g. Canoe'),
              ),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                controller: targetCtrl,
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
                onChanged: (v) => setSheet(() => shared = v),
              ),
              if (!shared && c.adults.length > 1)
                _OwnerDropdown(
                  adults: c.adults,
                  value: owner,
                  onChanged: (v) => setSheet(() => owner = v),
                ),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                controller: descCtrl,
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
                  final name = nameCtrl.text.trim();
                  if (name.isEmpty) return;
                  final desc = descCtrl.text.trim();
                  Navigator.of(sheetCtx).pop(DraftQuest(
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
        for (final a in adults)
          DropdownMenuItem(value: a.localId, child: Text(a.name)),
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
        for (final v in AccountCadence.values)
          DropdownMenuItem(value: v, child: Text(v.name)),
      ],
      onChanged: (v) => v == null ? null : onChanged(v),
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
        for (var m = 1; m <= 12; m++)
          DropdownMenuItem(value: m, child: Text(monthLabel(2026, m).split(' ').first)),
      ],
      onChanged: (v) => v == null ? null : onChanged(v),
    );
  }
}

// ---- role helpers ---------------------------------------------------------

String _roleWord(DraftRole r) => switch (r) {
      DraftRole.adult => 'adult',
      DraftRole.dependent => 'dependent',
      DraftRole.pet => 'pet',
    };

String _rolePlural(DraftRole r) => switch (r) {
      DraftRole.adult => 'Adults',
      DraftRole.dependent => 'Dependents',
      DraftRole.pet => 'Pets',
    };

IconData _roleIcon(DraftRole r) => switch (r) {
      DraftRole.adult => Icons.person_outline,
      DraftRole.dependent => Icons.child_care_outlined,
      DraftRole.pet => Icons.pets_outlined,
    };

IconData _accountIcon(AccountKind k) => switch (k) {
      AccountKind.savings => Icons.savings_outlined,
      AccountKind.investment => Icons.show_chart,
      AccountKind.debt => Icons.credit_card,
      AccountKind.cash => Icons.attach_money,
    };
