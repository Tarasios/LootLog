/// Month-end and Vault rewards: what closed months and savings progress earn
/// each Adventure adult. Run by the reward engine on every evaluation.
///
/// Everything here is read from the reducer's [HouseholdState] and a few
/// money-free ledger facts (`ledger_inputs.dart`); nothing writes the ledger
/// or changes a cent. The rules it keeps:
/// - The gold chest is a bonus (rule 2): a personal category that ended a
///   closed month at or under its limit, for a person who logged on at least
///   [Balance.goldChestMinLoggedDays] days that month — so skipping the log
///   never looks like staying under budget (rule 1).
/// - Savings rewards (rule 8) read shares of a quest's goal and runs of
///   consecutive saving months, never dollar amounts.
/// - Ids are `<reasonCode>:<person>:<period>`; anything the game state has
///   seen is never granted again, and nothing is ever taken back (rule 3).
/// - Only Adventure adults earn these; a Standard partner's absence never
///   changes anyone else's (rule 7).
///
/// The spoils chest is not granted here: finishing the ritual's boss fight
/// grants it (`GameCommands.fightBoss`).
///
/// Pure Dart, zero Flutter imports.
library;

import '../../../domain/event.dart';
import '../../../domain/reducer.dart';
import '../../../domain/state.dart';
import '../../../domain/time.dart';
import '../../../domain/value_types.dart';
import '../../config/balance.dart';
import '../clock.dart';
import '../game_event.dart';
import '../game_state.dart';
import '../game_values.dart';
import '../ledger_inputs.dart';
import '../reason_codes.dart';
import 'reward_engine.dart';

class LedgerMonthEndRewards implements MonthEndRewards {
  const LedgerMonthEndRewards({
    this.lookbackMonths = Balance.monthEndLookbackMonths,
  });

  /// How many closed months back are still rewarded.
  final int lookbackMonths;

  @override
  List<GameEvent> evaluate(
    List<Event> newLedgerEvents,
    GameState state,
    Clock clock, {
    required Party party,
    required GameEventStamp stamp,
    HouseholdState? household,
  }) {
    final now = clock.now();
    final ledger = newLedgerEvents;
    final hh = household ?? reduce(ledger, asOf: now);
    final current = Month.fromInstant(now);
    final closed = <Month>[];
    for (var m = current.prev(); closed.length < lookbackMonths; m = m.prev()) {
      closed.add(m);
    }
    final oldest = closed.isEmpty ? current : closed.last;

    final out = <GameEvent>[];
    for (final adult in party.adventurers) {
      final who = adult.memberId;
      final grants = _Grants(state.person(who), stamp, now, out);

      // Gold chest, oldest month first.
      for (final month in closed.reversed) {
        if (loggedDaysInMonth(ledger, who, month) <
            Balance.goldChestMinLoggedDays) {
          continue;
        }
        if (_anyUnderLimit(hh, who, month)) {
          grants.chest(
              '${GameReasonCodes.monthGold}:$who:${month.toKey()}',
              ChestType.gold,
              GameReasonCodes.monthGold);
        }
      }

      // Vault: quest milestones.
      final quests = hh.quests.values.toList()
        ..sort((a, b) => a.questId.compareTo(b.questId));
      for (final q in quests) {
        if (q.abandoned || q.targetCents <= 0) continue;
        final funds = switch (q.ownership) {
          PersonalParty(:final userId) => userId == who,
          SharedParty() => (q.contributions[who] ?? 0) > 0,
        };
        if (!funds) continue;
        final pct = q.completed
            ? 100
            : (q.totalContributedCents * 100 ~/ q.targetCents).clamp(0, 100);
        for (final mark in Balance.questMilestoneGems.keys.toList()..sort()) {
          if (pct < mark) continue;
          grants.gems(
            '${GameReasonCodes.vaultQuest}:$who:${q.questId}:$mark',
            Balance.questMilestoneGems[mark]!,
            GameReasonCodes.vaultQuest,
          );
        }
      }

      // Vault: consecutive saving months. Only a run still alive within the
      // lookback is paid, so an old ledger's history isn't paid out at once.
      final saved = savingsAllocationMonths(ledger, who)
          .where((m) => m.isBefore(current))
          .toList()
        ..sort();
      if (saved.isNotEmpty && !saved.last.isBefore(oldest)) {
        var start = saved.last;
        var length = 1;
        final set = saved.toSet();
        while (set.contains(start.prev())) {
          start = start.prev();
          length++;
        }
        for (final mark in Balance.savingsStreakGems.keys.toList()..sort()) {
          if (length < mark) continue;
          grants.gems(
            '${GameReasonCodes.vaultSavingsStreak}:$who:${start.toKey()}:$mark',
            Balance.savingsStreakGems[mark]!,
            GameReasonCodes.vaultSavingsStreak,
          );
        }
      }
    }
    return out;
  }

  /// Whether one of [who]'s personal categories spent something in [month]
  /// and ended at or under its effective limit.
  static bool _anyUnderLimit(HouseholdState hh, String who, Month month) =>
      hh.sliceMonths.values.any((sm) =>
          sm.month == month &&
          !sm.isGroup &&
          sm.ownerUserId == who &&
          sm.effectiveLimitCents > 0 &&
          sm.spentCents > 0 &&
          sm.spentCents <= sm.effectiveLimitCents);
}

/// Emits one person's grants, skipping anything already seen.
class _Grants {
  _Grants(PersonState p, this.stamp, this.now, this.out)
      : _seenRewards = {...p.seenRewardIds},
        _seenChests = {...p.seenChestIds},
        _who = p.personId;

  final GameEventStamp stamp;
  final DateTime now;
  final List<GameEvent> out;
  final Set<String> _seenRewards;
  final Set<String> _seenChests;
  final String _who;

  void chest(String chestId, ChestType type, String reasonCode) {
    if (!_seenChests.add(chestId)) return;
    out.add(ChestGranted(
      eventId: stamp.newEventId(),
      deviceId: stamp.deviceId,
      actorId: _who,
      occurredAt: now,
      createdAt: now,
      chestId: chestId,
      chestType: type,
      reasonCode: reasonCode,
    ));
  }

  void gems(String rewardId, int gems, String reasonCode) {
    if (!_seenRewards.add(rewardId)) return;
    out.add(RewardGranted(
      eventId: stamp.newEventId(),
      deviceId: stamp.deviceId,
      actorId: _who,
      occurredAt: now,
      createdAt: now,
      rewardId: rewardId,
      kind: 'gems',
      gems: gems,
      materials: const MaterialBundle.empty(),
      tokens: 0,
      reasonCode: reasonCode,
      sourceLedgerEventIds: const [],
    ));
  }
}
