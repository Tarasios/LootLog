/// The one commit path for quick entry, shared by the full-screen entry and
/// the Adventure log-purchase dialog: append the [EntryDraft] as a purchase
/// and, when it is bigger than its category (or goal) has available under the
/// savings rules, offer the shortfall sheet and record what was picked.
library;

import 'package:flutter/material.dart';

import '../../data/actions.dart';
import '../../domain/state.dart';
import '../../domain/value_types.dart';
import 'expense_entry_view.dart';
import 'shortfall.dart';
import 'shortfall_sheet.dart';

/// Thrown by [commitEntryDraft] when the purchase was written but the
/// shortfall follow-up (the sheet, or the cover or advance chosen in it)
/// failed. The purchase stands, so retrying the entry would log it twice.
class ShortfallFollowUpFailed implements Exception {
  const ShortfallFollowUpFailed({required this.purchaseId, required this.cause});

  /// The purchase that was written.
  final String purchaseId;

  /// What went wrong after it was written.
  final Object cause;

  @override
  String toString() =>
      'ShortfallFollowUpFailed(purchase $purchaseId was written): $cause';
}

/// Appends [draft] for [meUserId] through [actions], judged against [state]
/// (the household before this purchase lands), then runs the shortfall
/// follow-up over [context]. Completes once everything chosen is written.
/// A failure writing the purchase propagates as is; a failure after it is
/// wrapped in [ShortfallFollowUpFailed] (with the original stack trace).
Future<void> commitEntryDraft(
  BuildContext context, {
  required HouseholdState state,
  required String meUserId,
  required HouseholdActions actions,
  required EntryDraft draft,
}) async {
  // A shared purchase only charges the buyer's share, so it isn't checked.
  final short = draft.shared
      ? null
      : shortfallFor(
          state,
          meUserId: meUserId,
          target: draft.choice.target,
          amountCents: draft.amountCents,
          at: draft.occurredAt,
        );
  final purchaseId = await actions.addPurchase(
    target: draft.choice.target,
    amountCents: draft.amountCents,
    shared: draft.shared,
    merchant: draft.merchant,
    note: draft.note,
    occurredAt: draft.occurredAt,
  );
  if (short == null || !context.mounted) return;
  try {
    await _followUpShortfall(context, actions, short, purchaseId);
  } catch (error, stackTrace) {
    Error.throwWithStackTrace(
      ShortfallFollowUpFailed(purchaseId: purchaseId, cause: error),
      stackTrace,
    );
  }
}

/// Offers the shortfall sheet for [purchaseId] and records what was picked.
Future<void> _followUpShortfall(
  BuildContext context,
  HouseholdActions actions,
  ShortfallOptions short,
  String purchaseId,
) async {
  final choice = await showShortfallSheet(context, short);
  switch (choice) {
    case CoverFromGeneral(:final amountCents):
      await actions.coverShortfall(
        purchaseId: purchaseId,
        source: const GeneralCover(),
        amountCents: amountCents,
      );
    case BorrowAhead(:final months):
      await actions.proposeAdvance(
        sliceId: short.sliceId!,
        amountCents: short.shortCents,
        months: months,
        purchaseId: purchaseId,
      );
    case CoverFromSavings(:final sliceId, :final moveCents):
      await actions.coverShortfall(
        purchaseId: purchaseId,
        source: CategorySavingsCover(sliceId),
        amountCents: moveCents,
      );
    case LeaveIt():
    case null:
      break;
  }
}
