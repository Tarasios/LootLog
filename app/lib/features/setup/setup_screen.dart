/// First-run onboarding, framed as assembling your adventuring party. A stepped
/// wizard collects the household — members, incomes, tracked accounts, fixed
/// expenses, the budget, and a first savings goal — then hands the drafts to the
/// pure [buildOnboardingEvents] model, appends the events, and hands off to the
/// main app. Every step is editable later via Settings; the summary says so.
///
/// The wizard owns only layout and draft state ([SetupController]); it decides
/// nothing about which events get written — that lives in `onboarding_plan.dart`.
///
/// This file is the wizard shell (step order, navigation, finishing). Each step
/// lives in `steps/`, each bottom-sheet editor in `editors/`, and the small
/// shared widgets in `widgets/` — all parts of this one library, so they share
/// its private widgets and imports.
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

part 'editors/account_editor.dart';
part 'editors/category_editor.dart';
part 'editors/expense_editor.dart';
part 'editors/goal_editor.dart';
part 'editors/main_categories_editor.dart';
part 'editors/member_editor.dart';
part 'editors/shares_editor.dart';
part 'steps/accounts_step.dart';
part 'steps/budget_step.dart';
part 'steps/expenses_step.dart';
part 'steps/goal_step.dart';
part 'steps/income_step.dart';
part 'steps/party_step.dart';
part 'steps/summary_step.dart';
part 'widgets/setup_widgets.dart';

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
