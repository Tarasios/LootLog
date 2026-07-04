/// The home screen: recent purchases, the quick-entry FAB (keyboard shortcut
/// `N` on desktop), and a camera button beside it for the receipt-first OCR
/// flow. Tapping a purchase opens its detail sheet.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../../domain/state.dart';
import '../../domain/value_types.dart';
import '../../ui/theme.dart';
import '../entry/expense_entry_screen.dart';
import '../entry/expense_entry_view.dart' show formatMoney;
import '../ocr/ocr_confirm_screen.dart';
import '../purchase/purchase_detail_sheet.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(householdStateProvider).value;

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyN): () =>
            ExpenseEntryScreen.open(context),
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          appBar: AppBar(title: const Text('DuoBudget')),
          body: state == null
              ? const Center(child: CircularProgressIndicator())
              : _PurchaseList(state: state),
          floatingActionButton: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              FloatingActionButton(
                heroTag: 'scan',
                onPressed: () => captureReceiptAndConfirm(context, ref),
                tooltip: 'Scan a receipt',
                child: const Icon(Icons.document_scanner_outlined),
              ),
              const SizedBox(width: AppSpacing.md),
              FloatingActionButton.extended(
                heroTag: 'new',
                onPressed: () => ExpenseEntryScreen.open(context),
                icon: const Icon(Icons.add),
                label: const Text('New'),
              ),
            ],
          ),
        ),
      ),
    );
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
          subtitle: Text(_dateLabel(p.occurredAt)),
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

  static String _dateLabel(DateTime at) =>
      '${at.year}-${at.month.toString().padLeft(2, '0')}-'
      '${at.day.toString().padLeft(2, '0')}';

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
