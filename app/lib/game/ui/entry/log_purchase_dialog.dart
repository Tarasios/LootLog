/// Logging a purchase in Adventure: a framed game dialog over the town instead
/// of the plain full-screen entry. One tap opens it, two taps (amount, then
/// where it came from) log it. It builds the same charge groups as the
/// Standard quick entry and commits through the same [commitEntryDraft], so
/// vacation targets and the shortfall follow-up behave exactly as there; no
/// new ledger call, no money logic. "More details" swaps it for the full
/// [ExpenseEntryScreen] (merchant, note, date, shared) carrying the amount.
///
/// After a purchase lands the dialog closes and the town's log celebration
/// plays (it listens to the ledger's purchase count).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/actions.dart';
import '../../../data/providers.dart';
import '../../../features/entry/charge_choice.dart';
import '../../../features/entry/commit_entry.dart';
import '../../../features/entry/expense_entry_screen.dart';
import '../../../features/settings/play_mode_providers.dart';
import '../kit/kit.dart';
import 'log_purchase_view.dart';

/// What the dialog closed with when the person asked for the full entry
/// screen: the amount typed so far.
class _MoreDetails {
  const _MoreDetails(this.cents);

  final int cents;
}

class LogPurchaseDialog extends ConsumerWidget {
  const LogPurchaseDialog({super.key, this.now});

  /// Injectable clock for the charge groups and the purchase date.
  final DateTime? now;

  /// Opens the dialog over [context] (the town). Its "More details" closes it
  /// and pushes the full entry screen from [context] with the typed amount.
  static Future<void> open(BuildContext context) async {
    final moreDetails = await showGameDialog<_MoreDetails>(
      context,
      builder: (_) => const LogPurchaseDialog(),
    );
    if (moreDetails == null || !context.mounted) return;
    await Navigator.of(
      context,
    ).push(ExpenseEntryScreen.route(initialCents: moreDetails.cents));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final setup = ref.watch(localSetupProvider).value;
    final state = ref.watch(householdStateProvider).value;
    final actions = ref.watch(householdActionsProvider);
    void close() => Navigator.of(context).pop();

    if (setup == null || state == null || actions == null) {
      return GameDialog(
        title: 'Log a purchase',
        onClose: close,
        body: const Text('Opening the ledger…'),
      );
    }

    return LogPurchaseView(
      groups: buildChargeGroups(
        state,
        setup.meUserId,
        isAdventure: ref.watch(isAdventureProvider),
        asOf: now,
      ),
      now: now,
      onClose: close,
      onMoreDetails: (cents) => Navigator.of(context).pop(_MoreDetails(cents)),
      onCommit: (draft) => commitEntryDraft(
        context,
        state: state,
        meUserId: setup.meUserId,
        actions: actions,
        draft: draft,
      ),
    );
  }
}
