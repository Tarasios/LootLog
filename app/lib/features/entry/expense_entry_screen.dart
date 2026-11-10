/// Provider-wired quick-entry: builds charge groups from the reducer's state and
/// commits an [EntryDraft] as an appended [PurchaseAdded]. When the purchase is
/// bigger than its category (or goal) has available under the savings rules,
/// the shortfall sheet offers to cover the gap; otherwise entry stays two taps.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/actions.dart';
import '../../data/providers.dart';
import '../settings/play_mode_providers.dart';
import 'charge_choice.dart';
import 'commit_entry.dart';
import 'expense_entry_view.dart';

class ExpenseEntryScreen extends ConsumerWidget {
  const ExpenseEntryScreen({super.key, this.initialCents = 0});

  /// The amount the keypad starts on (carried over from the Adventure
  /// log-purchase dialog's "More details").
  final int initialCents;

  /// Quick entry as a full-screen route, starting on [initialCents].
  static Route<void> route({int initialCents = 0}) => MaterialPageRoute<void>(
    builder: (_) => ExpenseEntryScreen(initialCents: initialCents),
  );

  /// Opens quick entry as a full-screen route.
  static Future<void> open(BuildContext context) =>
      Navigator.of(context).push(route());

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final setup = ref.watch(localSetupProvider).value;
    final state = ref.watch(householdStateProvider).value;
    final actions = ref.watch(householdActionsProvider);

    if (setup == null || state == null || actions == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final groups = buildChargeGroups(
      state,
      setup.meUserId,
      isAdventure: ref.watch(isAdventureProvider),
    );

    return ExpenseEntryView(
      groups: groups,
      initialCents: initialCents,
      onCommit: (draft) async {
        await commitEntryDraft(
          context,
          state: state,
          meUserId: setup.meUserId,
          actions: actions,
          draft: draft,
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
