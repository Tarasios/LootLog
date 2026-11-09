/// Riverpod wiring for the town's ledger figures ([TownLedger]): the quest
/// board, gold pouch, war chest and bills due soon, read from the household
/// state for this device's adult under this device's visibility preference;
/// and the wording of the town's tags.
library;

import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/providers.dart';
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

/// The tags' wording, loaded once. Screens use
/// `.value ?? TownTagLines.defaults`.
final townTagLinesProvider = FutureProvider<TownTagLines>((ref) async {
  final text = await rootBundle.loadString(kTownTagsAsset);
  return TownTagLines.fromJson(jsonDecode(text) as Map<String, dynamic>);
});
