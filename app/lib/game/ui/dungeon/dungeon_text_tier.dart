/// The month-end dungeon in the text tier: the turn-based text battle, fed by
/// the same ritual and written through the same shared spoils path as the
/// pixel battle, then the spoils chest, the celebration and the month's
/// report.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../features/report/report_screen.dart';
import '../../../features/spoils/spoils_model.dart';
import '../../../features/spoils/spoils_move.dart';
import '../../text_mode/text_battle.dart';
import 'dungeon_commit.dart';

/// The text tier's battle: the turn-based text view for [ritual].
Widget textTierBattle(BuildContext context, SpoilsRitual ritual) => TextBattleView(
      ritual: ritual,
      onDismiss: () => Navigator.of(context).maybePop(),
      onConfirm: (result) => unawaited(_finishTextBattle(context, ritual, result)),
    );

/// The text battle pops on confirm (so it can't be confirmed twice), writes
/// the ledger once, then brings the chest home. A failed chest never undoes
/// or repeats the ledger write: a dialog says the leftovers are saved and
/// offers to retry the chest alone.
Future<void> _finishTextBattle(BuildContext context, SpoilsRitual ritual, SpoilsResult result) async {
  final navigator = Navigator.of(context);
  final container = ProviderScope.containerOf(context, listen: false);
  navigator.pop();
  try {
    await writeMonthEndLedger(container, ritual, result);
  } on Object {
    if (navigator.mounted) showMonthEndSaveFailed(navigator.context, container);
    return;
  }
  MonthEndGameOutcome? outcome;
  while (outcome == null && navigator.mounted) {
    try {
      outcome = await finishMonthEndGame(container, ritual.month);
    } on Object {
      if (!navigator.mounted || !await askRetryChest(navigator.context, container)) break;
    }
  }
  if (!navigator.mounted) return;
  if (outcome != null) {
    await showMonthEndCelebration(navigator.context, container, outcome, seed: '${ritual.month.toKey()}:victory');
  }
  if (navigator.mounted) await ReportScreen.open(navigator.context, initialMonth: ritual.month);
}
