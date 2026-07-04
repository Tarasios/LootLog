/// Provider-wired quick-entry: builds charge groups from the reducer's state and
/// commits an [EntryDraft] as an appended [PurchaseAdded].
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/actions.dart';
import '../../data/providers.dart';
import '../entry/charge_choice.dart';
import '../entry/expense_entry_view.dart';

class ExpenseEntryScreen extends ConsumerWidget {
  const ExpenseEntryScreen({super.key});

  /// Opens quick entry as a full-screen route.
  static Future<void> open(BuildContext context) => Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const ExpenseEntryScreen()),
      );

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
        await actions.addPurchase(
          target: draft.choice.target,
          amountCents: draft.amountCents,
          shared: draft.shared,
          merchant: draft.merchant,
          note: draft.note,
          occurredAt: draft.occurredAt,
        );
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
