/// The ledger figures the Adventure town shows around the scene: the quest
/// board, this adult's gold pouch, the household war chest and the bills
/// coming due within a few days (for the town's tags).
///
/// Every figure is read from the same read models the Standard dashboard uses
/// ([QuestBoardView.from], [buildUpcomingPayments], the reducer's vault and
/// war-chest balances), so both modes always show identical numbers; nothing
/// here computes money. Pure Dart, zero Flutter imports.
library;

import '../../../domain/money.dart';
import '../../../domain/state.dart';
import '../../../domain/time.dart';
import '../../../features/dashboard/dashboard_model.dart';
import 'quest_board_view.dart';
import 'town_tags.dart' show TownBill, kTownBillTagDays;

class TownLedger {
  const TownLedger({
    this.board = const QuestBoardView(),
    this.goldPouch,
    this.warChest,
    this.bills = const [],
  });

  /// Nothing known yet (before setup, or while the ledger loads).
  static const TownLedger empty = TownLedger();

  final QuestBoardView board;

  /// This device's adult's vault; null while unknown.
  final Money? goldPouch;

  /// The household's shared savings; null while unknown.
  final Money? warChest;

  /// Bills due within [kTownBillTagDays] days, soonest first.
  final List<TownBill> bills;

  /// Reads the town's figures for [meId] as of [now]. With [showOtherAdults]
  /// off, other adults' personal categories, debts and bills stay off this
  /// device's town (display only; shared ones always show).
  static TownLedger from(
    HouseholdState state, {
    required String meId,
    required Map<String, String> names,
    required bool showOtherAdults,
    required DateTime now,
  }) {
    bool visible(UpcomingPayment payment) {
      final owner = payment.ownerUserId;
      return showOtherAdults || owner == null || owner == meId;
    }

    return TownLedger(
      board: QuestBoardView.from(
        state,
        meId: meId,
        month: Month.fromInstant(now.toUtc()),
        showOtherAdults: showOtherAdults,
        names: names,
      ),
      goldPouch: Money(state.vaultOf(meId)),
      warChest: Money(state.warChest.balanceCents),
      bills: List.unmodifiable([
        for (final payment in buildUpcomingPayments(state, now: now))
          if (payment.daysUntilDue <= kTownBillTagDays && visible(payment))
            (
              name: payment.name,
              daysUntilDue: payment.daysUntilDue,
              ownerId: payment.ownerUserId,
            ),
      ]),
    );
  }
}
