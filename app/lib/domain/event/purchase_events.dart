part of '../event.dart';

/// A purchase. `chargeTarget` may be a slice, the vault, a quest, or an
/// emergency fund. The optional `shared` flag is valid only for personal-slice
/// and vault targets.
class PurchaseAdded extends Event {
  PurchaseAdded({
    required super.eventId,
    required super.deviceId,
    required super.userId,
    required super.occurredAt,
    required super.createdAt,
    required this.purchaseId,
    required this.target,
    required this.amountCents,
    this.shared = false,
    this.merchant,
    this.taxDeductible,
    this.note,
    this.amendsPurchaseId,
  }) {
    if (shared &&
        (target is QuestCharge ||
            target is EmergencyCharge ||
            target is VacationCharge)) {
      throw ArgumentError(
        'shared is only valid for personal-slice and vault charge targets',
      );
    }
  }

  final String purchaseId;
  final ChargeTarget target;
  final int amountCents;
  final bool shared;
  final String? merchant;

  /// Per-purchase tax override; `null` means inherit from the slice default.
  final bool? taxDeductible;
  final String? note;

  /// Set when this purchase is the corrected copy written by an edit (the
  /// purchase it replaces is voided alongside). Money-inert: the reducer reads
  /// nothing from it. It lets readers tell an edit from a newly logged purchase.
  final String? amendsPurchaseId;

  @override
  String get type => 'PurchaseAdded';

  @override
  Map<String, dynamic> payload() => {
    'purchaseId': purchaseId,
    'target': target.toJson(),
    'amountCents': amountCents,
    'shared': shared,
    if (merchant != null) 'merchant': merchant,
    if (taxDeductible != null) 'taxDeductible': taxDeductible,
    if (note != null) 'note': note,
    if (amendsPurchaseId != null) 'amendsPurchaseId': amendsPurchaseId,
  };
}

class PurchaseVoided extends Event {
  const PurchaseVoided({
    required super.eventId,
    required super.deviceId,
    required super.userId,
    required super.occurredAt,
    required super.createdAt,
    required this.purchaseId,
  });

  final String purchaseId;

  @override
  String get type => 'PurchaseVoided';

  @override
  Map<String, dynamic> payload() => {'purchaseId': purchaseId};
}

class ReceiptAttached extends Event {
  const ReceiptAttached({
    required super.eventId,
    required super.deviceId,
    required super.userId,
    required super.occurredAt,
    required super.createdAt,
    required this.purchaseId,
    required this.sha256,
    required this.mimeType,
    required this.sizeBytes,
  });

  final String purchaseId;
  final String sha256;
  final String mimeType;
  final int sizeBytes;

  @override
  String get type => 'ReceiptAttached';

  @override
  Map<String, dynamic> payload() => {
    'purchaseId': purchaseId,
    'sha256': sha256,
    'mimeType': mimeType,
    'sizeBytes': sizeBytes,
  };
}

class ReceiptDetached extends Event {
  const ReceiptDetached({
    required super.eventId,
    required super.deviceId,
    required super.userId,
    required super.occurredAt,
    required super.createdAt,
    required this.purchaseId,
    required this.sha256,
  });

  final String purchaseId;
  final String sha256;

  @override
  String get type => 'ReceiptDetached';

  @override
  Map<String, dynamic> payload() => {
    'purchaseId': purchaseId,
    'sha256': sha256,
  };
}
