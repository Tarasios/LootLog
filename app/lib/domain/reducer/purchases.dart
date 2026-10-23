part of '../reducer.dart';

/// Accumulates a purchase and its live receipt references.
class _PurchaseAccumulator {
  _PurchaseAccumulator(this.event);

  final PurchaseAdded event;
  bool voided = false;
  final Map<String, ReceiptRef> receipts = {};
}

/// Spending derived from the live (non-voided) purchases, bucketed by what
/// each purchase was charged to.
class _PurchaseSpending {
  /// Personal-category spend, keyed "sliceId|yyyy-MM".
  final Map<String, int> personalSpent = {};

  /// Group-category spend, keyed "sliceId|yyyy-MM".
  final Map<String, int> groupSpent = {};

  /// Quest drawdowns by questId: purchases of the goal itself, plus vacation
  /// reservations against a quest-backed vacation.
  final Map<String, int> questDrawdown = {};

  final List<PurchaseAdded> emergencyPurchases = [];

  /// Vacation spend, keyed "vacationId|categoryId".
  final Map<String, int> vacationCategorySpent = {};

  /// Vacation spend per vacationId.
  final Map<String, int> vacationTotalSpent = {};
}

/// Purchases: receipt binding, the per-target spend tally, and the purchase
/// read-models (purchase states, tax-deductible lists).
extension _PurchaseDerivation on _HouseholdStateBuilder {
  /// Binds buffered receipt attach/detach events onto their purchases. Events
  /// arrive here in canonical `(occurredAt, eventId)` order, so a later detach
  /// correctly cancels a prior attach, and an attach that sorted ahead of its
  /// purchase now finds it. Receipts referencing an unknown purchase are ignored.
  void _applyReceipts() {
    for (final event in _receiptEvents) {
      switch (event) {
        case ReceiptAttached():
          purchases[event.purchaseId]?.receipts[event.sha256] = ReceiptRef(
            sha256: event.sha256,
            mimeType: event.mimeType,
            sizeBytes: event.sizeBytes,
          );
        case ReceiptDetached():
          purchases[event.purchaseId]?.receipts.remove(event.sha256);
        default:
          break;
      }
    }
  }

  /// Per-category, per-month spending derived from purchases. Shared
  /// purchases charge every co-adult's share straight to their vault.
  _PurchaseSpending _tallyPurchaseSpending() {
    final spending = _PurchaseSpending();
    for (final accumulator in purchases.values) {
      if (accumulator.voided) {
        continue;
      }
      final purchase = accumulator.event;
      final target = purchase.target;
      switch (target) {
        case SliceCharge():
          final config = slices[target.sliceId];
          final spentKey =
              '${target.sliceId}|${purchase.occurredMonth.toKey()}';
          if (config != null && config.isGroup) {
            spending.groupSpent[spentKey] =
                (spending.groupSpent[spentKey] ?? 0) + purchase.amountCents;
          } else if (purchase.shared) {
            // Split across the adults by their share table; the purchaser's
            // share lands on this personal category, every co-adult's share is
            // charged to their vault. Odd cents go to the purchaser.
            final parts = _splitShares(
              purchase.amountCents,
              _sharesFor(purchase.occurredMonth),
              oddTo: purchase.userId,
            );
            parts.forEach((adultId, shareCents) {
              if (adultId == purchase.userId) {
                spending.personalSpent[spentKey] =
                    (spending.personalSpent[spentKey] ?? 0) + shareCents;
              } else {
                _addVault(adultId, -shareCents);
                _recordVaultFlow(adultId, purchase.occurredMonth, -shareCents);
              }
            });
          } else {
            spending.personalSpent[spentKey] =
                (spending.personalSpent[spentKey] ?? 0) + purchase.amountCents;
          }
        case VaultCharge():
          if (purchase.shared) {
            // Each adult's share is charged to their own vault; odd cents to
            // the purchaser.
            final parts = _splitShares(
              purchase.amountCents,
              _sharesFor(purchase.occurredMonth),
              oddTo: purchase.userId,
            );
            parts.forEach((adultId, shareCents) {
              _addVault(adultId, -shareCents);
              _recordVaultFlow(adultId, purchase.occurredMonth, -shareCents);
            });
          } else {
            _addVault(purchase.userId, -purchase.amountCents);
            _recordVaultFlow(
              purchase.userId,
              purchase.occurredMonth,
              -purchase.amountCents,
            );
          }
        case QuestCharge():
          spending.questDrawdown[target.questId] =
              (spending.questDrawdown[target.questId] ?? 0) +
              purchase.amountCents;
        case EmergencyCharge():
          spending.emergencyPurchases.add(purchase);
        case VacationCharge():
          // Vacation spend is tracked per category; the money is already
          // reserved off the source fund, so it never hits a vault or a normal
          // budget. Charges to an unknown vacation are ignored.
          if (vacationConfigs.containsKey(target.vacationId)) {
            final spentKey = '${target.vacationId}|${target.categoryId}';
            spending.vacationCategorySpent[spentKey] =
                (spending.vacationCategorySpent[spentKey] ?? 0) +
                purchase.amountCents;
            spending.vacationTotalSpent[target.vacationId] =
                (spending.vacationTotalSpent[target.vacationId] ?? 0) +
                purchase.amountCents;
          }
      }
    }
    return spending;
  }

  /// Tax-deductible purchases per calendar year. A purchase's own flag wins;
  /// absent one it inherits its category's default.
  Map<int, List<DeductiblePurchase>> _deductiblePurchasesByYear() {
    final deductibleByYear = <int, List<DeductiblePurchase>>{};
    for (final accumulator in purchases.values) {
      if (accumulator.voided) {
        continue;
      }
      final purchase = accumulator.event;
      final target = purchase.target;
      final sliceConfig = target is SliceCharge ? slices[target.sliceId] : null;
      final sliceDefault = sliceConfig?.taxDeductibleByDefault ?? false;
      final deductible = purchase.taxDeductible ?? sliceDefault;
      if (!deductible) {
        continue;
      }
      final year = purchase.occurredMonth.year;
      deductibleByYear
          .putIfAbsent(year, () => [])
          .add(
            DeductiblePurchase(
              purchaseId: purchase.purchaseId,
              userId: purchase.userId,
              sliceName: sliceConfig?.name ?? _chargeTargetLabel(target),
              amountCents: purchase.amountCents,
              shared: purchase.shared,
              occurredAt: purchase.occurredAt,
              receiptShas: accumulator.receipts.keys.toList(),
              merchant: purchase.merchant,
              note: purchase.note,
            ),
          );
    }
    return deductibleByYear;
  }

  /// Every purchase (voided ones included, flagged) with its live receipts.
  Map<String, PurchaseState> _purchaseStates() {
    return <String, PurchaseState>{
      for (final accumulator in purchases.values)
        accumulator.event.purchaseId: PurchaseState(
          purchaseId: accumulator.event.purchaseId,
          userId: accumulator.event.userId,
          target: accumulator.event.target,
          amountCents: accumulator.event.amountCents,
          month: accumulator.event.occurredMonth,
          occurredAt: accumulator.event.occurredAt,
          shared: accumulator.event.shared,
          voided: accumulator.voided,
          receipts: accumulator.receipts.values.toList(),
          merchant: accumulator.event.merchant,
          taxDeductible: accumulator.event.taxDeductible,
          note: accumulator.event.note,
        ),
    };
  }
}

/// A fallback display label for a purchase's charge target.
String _chargeTargetLabel(ChargeTarget target) => switch (target) {
  SliceCharge() => target.sliceId,
  VaultCharge() => 'vault',
  QuestCharge() => target.questId,
  EmergencyCharge() => target.fundId,
  VacationCharge() => target.vacationId,
};
