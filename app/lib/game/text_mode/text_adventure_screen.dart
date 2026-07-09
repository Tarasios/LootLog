/// The text-adventure entry point (tier 3, the shipping default before art
/// exists). Composes [TextAdventureView] from the same providers the classic
/// dashboard reads — identical numbers — and wires the few actions: strike a
/// monster (quick entry), enter the month-close battle, sign/decline writs, and
/// drop to Classic.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/actions.dart';
import '../../data/providers.dart';
import '../../features/entry/expense_entry_screen.dart';
import '../../features/household_context.dart';
import '../../features/report/report_screen.dart';
import '../../features/spoils/spoils_model.dart';
import '../../features/spoils/spoils_sheet.dart';
import '../adapter.dart';
import '../narrative.dart';
import '../skin_prefs.dart';
import 'text_adventure_view.dart';
import 'text_battle.dart';

/// The narrative/encouragement asset bundle (loaded once). Cosmetic strings
/// only — they decorate the log, never the numbers.
final narrativeProvider = FutureProvider<Narrative>((ref) => loadNarrative());

class TextAdventureScreen extends ConsumerWidget {
  const TextAdventureScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(householdStateProvider).value;
    final events = ref.watch(eventLogProvider).value ?? const [];
    final meUserId = ref.watch(meUserIdProvider);
    final names = ref.watch(userNamesProvider);
    final narrative = ref.watch(narrativeProvider).value;

    if (state == null || meUserId == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final game = buildGameState(state, meUserId: meUserId, userNames: names);
    final log = buildAdventureLog(state, events,
        meUserId: meUserId, userNames: names, limit: 40);
    final ritual =
        buildSpoilsRitual(state, meUserId: meUserId, userNames: names);

    // A supportive line surfaces only where it fits: when the party is wounded,
    // an encouraging, never-shaming word from the narrative assets.
    final encouragement = (game.heroWounded && narrative != null)
        ? narrative.overspendLine()
        : null;

    final actions = ref.read(householdActionsProvider);
    return TextAdventureView(
      game: game,
      log: log,
      encouragement: encouragement,
      spoilsPending: ritual != null,
      callbacks: TextAdventureCallbacks(
        onStrikeMonster: () => ExpenseEntryScreen.open(context),
        onOpenSpoils: () => unawaited(openTextBattle(context, ref)),
        onSwitchToClassic: () =>
            unawaited(ref.read(appSkinProvider.notifier).select(AppSkin.classic)),
        onSignWrit: (id) {
          if (actions != null) unawaited(actions.approveWithdrawal(id));
        },
        onDeclineWrit: (id) {
          if (actions != null) unawaited(actions.cancelWithdrawal(id));
        },
      ),
    );
  }
}

/// Opens the turn-based text battle for the pending month close, applies the
/// player's chosen moves as events (via the same actions the classic sheet
/// uses), and closes the floor with its report. A no-op when nothing is due.
Future<void> openTextBattle(BuildContext context, WidgetRef ref) async {
  final state = ref.read(householdStateProvider).value;
  final meUserId = ref.read(meUserIdProvider);
  final names = ref.read(userNamesProvider);
  final actions = ref.read(householdActionsProvider);
  if (state == null || meUserId == null || actions == null) return;

  final ritual =
      buildSpoilsRitual(state, meUserId: meUserId, userNames: names);
  if (ritual == null) return;

  final navigator = Navigator.of(context);
  await navigator.push<void>(MaterialPageRoute(
    builder: (context) => TextBattleView(
      ritual: ritual,
      onDismiss: () => Navigator.of(context).maybePop(),
      onConfirm: (result) async {
        Navigator.of(context).pop();
        await _apply(actions, ritual, result);
        if (navigator.mounted) {
          await ReportScreen.open(navigator.context, initialMonth: ritual.month);
        }
      },
    ),
  ));
}

Future<void> _apply(
  HouseholdActions actions,
  SpoilsRitual ritual,
  SpoilsResult result,
) async {
  for (final t in result.tallies) {
    await actions.recordVariableActual(
      expenseId: t.expenseId,
      month: ritual.month,
      actualCents: t.actualCents,
    );
  }
  for (final a in result.allocations) {
    await actions.allocateLeftover(
      forUserId: ritual.forUserId,
      month: ritual.month,
      sliceId: a.sliceId,
      allocations: a.allocations,
    );
  }
}
