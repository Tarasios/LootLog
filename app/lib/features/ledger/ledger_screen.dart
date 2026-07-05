/// The ledger: a reverse-chronological list of purchases. Tapping one opens its
/// detail sheet. This is the body only — the responsive shell supplies the
/// scaffold, app bar, and the quick-entry / scan actions.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../../domain/state.dart';
import '../../domain/value_types.dart';
import '../../ui/format.dart';
import '../../ui/theme.dart';
import '../entry/expense_entry_view.dart' show formatMoney;
import '../purchase/purchase_detail_sheet.dart';

class LedgerScreen extends ConsumerWidget {
  const LedgerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(householdStateProvider).value;
    if (state == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return _PurchaseList(state: state);
  }
}

class _PurchaseList extends StatelessWidget {
  const _PurchaseList({required this.state});

  final HouseholdState state;

  @override
  Widget build(BuildContext context) {
    final purchases = state.purchases.values.toList()
      ..sort((a, b) => b.occurredAt.compareTo(a.occurredAt));

    if (purchases.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Text(
            'No expenses yet.\nTap New to record one.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.only(bottom: 96),
      itemCount: purchases.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, i) {
        final p = purchases[i];
        return ListTile(
          title: Text(
            p.merchant ?? _targetName(state, p.target),
            style: p.voided
                ? const TextStyle(decoration: TextDecoration.lineThrough)
                : null,
          ),
          subtitle: Text(isoDay(p.occurredAt)),
          trailing: Text(
            formatMoney(p.amountCents),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  decoration: p.voided ? TextDecoration.lineThrough : null,
                ),
          ),
          onTap: () =>
              showPurchaseDetailSheet(context, purchaseId: p.purchaseId),
        );
      },
    );
  }

  static String _targetName(HouseholdState state, ChargeTarget target) {
    switch (target) {
      case SliceCharge(:final sliceId):
        return state.slices[sliceId]?.name ?? 'Budget';
      case VaultCharge():
        return 'Vault';
      case QuestCharge(:final questId):
        return state.quests[questId]?.name ?? 'Quest';
      case EmergencyCharge(:final fundId):
        return state.emergencyFunds[fundId]?.name ?? 'Emergency fund';
    }
  }
}
