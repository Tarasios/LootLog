/// What the month-end dungeon reads from and writes to the ledger, behind
/// providers so tests can replace them. The only ledger write is the shared
/// spoils path ([applySpoilsResult]); everything else here only reads.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/actions.dart';
import '../../../data/providers.dart';
import '../../../features/household_context.dart';
import '../../../features/spoils/spoils_model.dart';
import '../../../features/spoils/spoils_move.dart';
import '../../../features/spoils/spoils_screen.dart' show applySpoilsResult;
import '../../battle/month_end_battle.dart';
import '../../data/game_providers.dart';
import '../../rewards/rewards.dart';

/// This device's adult's month-end battle, or null when no ritual is open.
final monthEndBattleProvider = Provider<MonthEndBattle?>((ref) {
  final household = ref.watch(householdStateProvider).value;
  final meId = ref.watch(meUserIdProvider);
  if (household == null || meId == null) return null;
  final ritual = buildSpoilsRitual(household, meUserId: meId, userNames: ref.watch(userNamesProvider));
  return MonthEndBattle.from(ritual, household);
});

/// Writes a confirmed month-end result to the ledger.
typedef SpoilsWriter = Future<void> Function(SpoilsRitual ritual, SpoilsResult result);

/// Writes a confirmed battle through the one shared spoils path. Throws when
/// the household is not set up, so the screen never reports a write that did
/// not happen.
final spoilsWriterProvider = Provider<SpoilsWriter>((ref) => (ritual, result) async {
      final actions = ref.read(householdActionsProvider);
      if (actions == null) throw StateError('The household is not set up yet.');
      await applySpoilsResult(actions, ritual, result);
    });

/// Consecutive on-time month-end rituals, for the spoils bonus.
final onTimeRitualMonthsProvider = FutureProvider<int>((ref) async {
  final household = ref.watch(householdStateProvider).value;
  if (household == null) return 0;
  final ledger = await ref.watch(appDatabaseProvider).eventsDao.allEvents();
  return onTimeRitualStreak(
    ledger,
    asOf: ref.watch(gameClockProvider).now().toUtc(),
    graceDays: household.settings.spoilsGraceDays,
  );
});
