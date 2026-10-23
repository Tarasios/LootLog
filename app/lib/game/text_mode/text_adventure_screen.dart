/// The text-adventure entry point (tier 3, the shipping default before art
/// exists). Composes [TextAdventureView] from the same providers the classic
/// dashboard reads — identical numbers — and wires the few actions: strike a
/// monster (quick entry), enter the month-close battle, and sign/decline writs.
/// Switching to Standard is the app bar's shared Adventure / Standard switch.
library;

import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/actions.dart';
import '../../data/providers.dart';
import '../../features/entry/expense_entry_screen.dart';
import '../../features/household_context.dart';
import '../../features/settings/visibility_prefs.dart';
import '../../features/spoils/spoils_model.dart';
import '../adapter.dart';
import '../narrative.dart';
import '../skin_prefs.dart';
import '../ui/dungeon/dungeon_screen.dart' show textTierBattle;
import 'text_adventure_view.dart';

/// The narrative/encouragement asset bundle (loaded once). Cosmetic strings
/// only — they decorate the log, never the numbers.
final narrativeProvider = FutureProvider<Narrative>((ref) => loadNarrative());

/// A day-seeded RNG for the camp ambience line: the same line all day (no
/// flicker across rebuilds), a fresh one tomorrow.
Random campAmbienceRng() {
  final now = DateTime.now();
  return Random(now.year * 10000 + now.month * 100 + now.day);
}

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

    final game = buildDungeonState(state,
        meUserId: meUserId,
        userNames: names,
        includeOtherAdults: ref.watch(showHouseholdBudgetsProvider));
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
      campAmbience: narrative?.campLine(rng: campAmbienceRng()),
      spoilsPending: ritual != null,
      callbacks: TextAdventureCallbacks(
        onStrikeMonster: () => ExpenseEntryScreen.open(context),
        onOpenSpoils: () => unawaited(openTextBattle(context, ref)),
        onSwitchToPixels: () => unawaited(ref
            .read(adventureTierProvider.notifier)
            .select(AdventureTier.pixel)),
        onSignWrit: (id) {
          if (actions != null) unawaited(actions.approveWithdrawal(id));
        },
        onDeclineWrit: (id) {
          if (actions != null) unawaited(actions.cancelWithdrawal(id));
        },
        onSealLoan: (id) {
          if (actions != null) unawaited(actions.approveAdvance(id));
        },
        onCancelLoan: (id) {
          if (actions != null) unawaited(actions.cancelAdvance(id));
        },
      ),
    );
  }
}

/// Opens the turn-based text battle for the pending month close. The battle
/// and its commit (the shared spoils path, then the spoils chest and the
/// month's report) live with the dungeon: [textTierBattle]. A no-op when
/// nothing is due.
Future<void> openTextBattle(BuildContext context, WidgetRef ref) async {
  final state = ref.read(householdStateProvider).value;
  final meUserId = ref.read(meUserIdProvider);
  final names = ref.read(userNamesProvider);
  if (state == null || meUserId == null || ref.read(householdActionsProvider) == null) return;

  final ritual =
      buildSpoilsRitual(state, meUserId: meUserId, userNames: names);
  if (ritual == null) return;

  await Navigator.of(context).push<void>(MaterialPageRoute(
    builder: (routeContext) => textTierBattle(routeContext, ritual),
  ));
}
