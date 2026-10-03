/// Provider-wired quick-entry: builds charge groups from the reducer's state and
/// commits an [EntryDraft] as an appended [PurchaseAdded]. When the purchase is
/// bigger than its category (or goal) has available under the savings rules,
/// the shortfall sheet offers to cover the gap; otherwise entry stays two taps.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/actions.dart';
import '../../data/providers.dart';
import '../../domain/value_types.dart';
import '../entry/charge_choice.dart';
import '../entry/expense_entry_view.dart';
import 'shortfall.dart';
import 'shortfall_sheet.dart';

class ExpenseEntryScreen extends ConsumerWidget {
  const ExpenseEntryScreen({super.key});

  /// Opens quick entry as a full-screen route.
  static Future<void> open(BuildContext context) => Navigator.of(
    context,
  ).push(MaterialPageRoute<void>(builder: (_) => const ExpenseEntryScreen()));

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final setup = ref.watch(localSetupProvider).value;
    final state = ref.watch(householdStateProvider).value;
    final actions = ref.watch(householdActionsProvider);

    if (setup == null || state == null || actions == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final groups = buildChargeGroups(state, setup.meUserId);

    return ExpenseEntryView(
      groups: groups,
      onCommit: (draft) async {
        // Judged against the state before this purchase lands. A shared
        // purchase only charges the buyer's share, so it isn't checked.
        final short = draft.shared
            ? null
            : shortfallFor(
                state,
                meUserId: setup.meUserId,
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
        if (short != null && context.mounted) {
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
        if (context.mounted) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Saved ${formatMoney(draft.amountCents)}')),
          );
        }
      },
    );
  }
}
