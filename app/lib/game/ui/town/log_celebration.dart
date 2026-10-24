/// What the town celebrates when its adult logs: the gems their logging
/// rewards just brought (read off the projected game state) and the fact of
/// a logged purchase itself (read off the ledger, so a log the daily gem cap
/// left gem-less is still celebrated). Read-only: nothing here grants,
/// changes or claims anything.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/providers.dart';
import '../../../domain/event.dart';
import '../../../features/household_context.dart';
import '../../domain/game_state.dart';
import '../../domain/reason_codes.dart';

/// The rewards that come from logging (or the no-spend check-in).
const Set<String> kLoggingReasonCodes = {
  GameReasonCodes.dailyLog,
  GameReasonCodes.noSpendCheckIn,
  GameReasonCodes.extraLog,
  GameReasonCodes.timely,
};

/// The gems of [personId]'s logging rewards that are in [next] but were not
/// yet granted in [previous].
int newLoggingGems(GameState previous, GameState next, String personId) {
  final before = previous.person(personId);
  var gems = 0;
  for (final reward in next.person(personId).unclaimedRewards.values) {
    if (!kLoggingReasonCodes.contains(reward.reasonCode)) continue;
    if (before.unclaimedRewards.containsKey(reward.rewardId) ||
        before.seenRewardIds.contains(reward.rewardId)) {
      continue;
    }
    gems += reward.loot.gems;
  }
  return gems;
}

/// How many purchases this device's adult has in the ledger, or null while
/// it loads. The town celebrates each time it goes up.
final loggedPurchaseCountProvider = Provider<int?>((ref) {
  final log = ref.watch(eventLogProvider).value;
  final meId = ref.watch(meUserIdProvider);
  if (log == null || meId == null) return null;
  return log.whereType<PurchaseAdded>().where((event) => event.userId == meId).length;
});
