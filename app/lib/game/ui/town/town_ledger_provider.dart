/// Riverpod wiring for the town's ledger figures ([TownLedger]): the quest
/// board, gold pouch and war chest, and the bills due soon as of a given day,
/// read from the household state for this device's adult under this device's
/// visibility preference; and the wording of the town's tags.
library;

import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/providers.dart';
import '../../../domain/time.dart';
import '../../../features/household_context.dart';
import '../../../features/settings/visibility_prefs.dart';
import '../../data/game_providers.dart';
import '../../domain/town/town_ledger.dart';
import '../../domain/town/town_tags.dart';

/// The writers' file of tag wording.
const String kTownTagsAsset = 'assets/game/text/town_tags.json';

/// The town's ledger figures; [TownLedger.empty] until the household loads.
final townLedgerProvider = Provider<TownLedger>((ref) {
  final household = ref.watch(householdStateProvider).value;
  final meId = ref.watch(meUserIdProvider);
  if (household == null || meId == null) return TownLedger.empty;
  return TownLedger.from(
    household,
    meId: meId,
    names: ref.watch(userNamesProvider),
    showOtherAdults: ref.watch(showHouseholdBudgetsProvider),
    now: ref.watch(gameClockProvider).now(),
  );
});

/// The bills due within a few days as of [today] (a household date), for
/// the town's tags. The town reads it with the day from its ticker, so the
/// countdowns move on when the date does, not only when the ledger changes.
final townBillsProvider = Provider.autoDispose.family<List<TownBill>, CalendarDay>((ref, today) {
  final household = ref.watch(householdStateProvider).value;
  final meId = ref.watch(meUserIdProvider);
  if (household == null || meId == null) return const [];
  return townBillsDueSoon(
    household,
    meId: meId,
    showOtherAdults: ref.watch(showHouseholdBudgetsProvider),
    // The clock's instant is on [today]: the ticker read the day from it.
    now: ref.watch(gameClockProvider).now(),
  );
});

/// The tags' wording, loaded once. Screens use
/// `.value ?? TownTagLines.defaults`.
final townTagLinesProvider = FutureProvider<TownTagLines>((ref) async {
  final text = await rootBundle.loadString(kTownTagsAsset);
  return TownTagLines.fromJson(jsonDecode(text) as Map<String, dynamic>);
});
