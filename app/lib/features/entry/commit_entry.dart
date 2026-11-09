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

/// Appends [draft] for [meUserId] through [actions], judged against [state]
/// (the household before this purchase lands), then runs the shortfall
/// follow-up over [context]. Completes once everything chosen is written.
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
