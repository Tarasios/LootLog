part of '../state.dart';

/// An attached receipt reference.
class ReceiptRef {
  const ReceiptRef({
    required this.sha256,
    required this.mimeType,
    required this.sizeBytes,
  });

  final String sha256;
  final String mimeType;
  final int sizeBytes;
}

/// A recorded purchase (non-voided ones drive spending; voided ones are kept
/// for auditability).
class PurchaseState {
  const PurchaseState({
    required this.purchaseId,
    required this.userId,
    required this.target,
    required this.amountCents,
    required this.month,
    required this.occurredAt,
    required this.shared,
    required this.voided,
    required this.receipts,
    this.merchant,
    this.taxDeductible,
    this.note,
  });

  final String purchaseId;
  final String userId;
  final ChargeTarget target;
  final int amountCents;
  final Month month;
  final DateTime occurredAt;
  final bool shared;
  final bool voided;
  final List<ReceiptRef> receipts;
  final String? merchant;
  final bool? taxDeductible;
  final String? note;
}

/// A tax-deductible purchase, for the per-year deductible list.
class DeductiblePurchase {
  const DeductiblePurchase({
    required this.purchaseId,
    required this.userId,
    required this.sliceName,
    required this.amountCents,
    required this.shared,
    required this.occurredAt,
    required this.receiptShas,
    this.merchant,
    this.note,
  });

  final String purchaseId;
  final String userId;
  final String sliceName;
  final int amountCents;
  final bool shared;
  final DateTime occurredAt;
  final List<String> receiptShas;
  final String? merchant;
  final String? note;
}
