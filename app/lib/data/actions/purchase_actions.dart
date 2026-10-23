part of '../actions.dart';

/// Recording purchases and their receipts, and correcting them the
/// event-sourced way (void + corrected copy).
mixin _PurchaseActions on _HouseholdActionsCore {
  /// `shared` is only meaningful for personal-slice and vault charges; force it
  /// off elsewhere so [PurchaseAdded]'s invariant is never violated.
  static bool _sharedAllowed(ChargeTarget target) =>
      target is SliceCharge || target is VaultCharge;

  /// Records a new purchase (the quick-entry commit). Returns its purchaseId.
  Future<String> addPurchase({
    required ChargeTarget target,
    required int amountCents,
    bool shared = false,
    String? merchant,
    String? note,
    bool? taxDeductible,
    DateTime? occurredAt,
  }) async {
    final now = DateTime.now().toUtc();
    final purchaseId = uuidv7();
    final event = PurchaseAdded(
      eventId: uuidv7(),
      deviceId: deviceId,
      userId: meUserId,
      occurredAt: occurredAt ?? now,
      createdAt: now,
      purchaseId: purchaseId,
      target: target,
      amountCents: amountCents,
      shared: shared && _sharedAllowed(target),
      merchant: merchant,
      taxDeductible: taxDeductible,
      note: note,
    );
    await _commit([event]);
    // Logging a purchase can extend a daily streak — grant any newly-earned
    // cosmetic rewards (idempotent, cosmetic-only).
    await grantPendingRewards();
    return purchaseId;
  }

  /// Voids a purchase (a correction that keeps the original for audit).
  Future<void> voidPurchase(String purchaseId) async {
    final now = DateTime.now().toUtc();
    await _commit([
      PurchaseVoided(
        eventId: uuidv7(),
        deviceId: deviceId,
        userId: meUserId,
        occurredAt: now,
        createdAt: now,
        purchaseId: purchaseId,
      ),
    ]);
  }

  /// Edits a purchase by voiding it and appending a corrected copy, re-attaching
  /// every receipt to the new purchase. Only the named fields change; pass
  /// `null` for [merchant]/[note]/[taxDeductible] to clear them. Returns the new
  /// purchaseId.
  Future<String> amendPurchase(
    PurchaseState old, {
    int? amountCents,
    ChargeTarget? target,
    Object? merchant = _unset,
    Object? note = _unset,
    Object? taxDeductible = _unset,
    bool? shared,
    DateTime? occurredAt,
  }) async {
    final now = DateTime.now().toUtc();
    final newId = uuidv7();
    final newTarget = target ?? old.target;
    final newShared = (shared ?? old.shared) && _sharedAllowed(newTarget);
    final newAt = occurredAt ?? old.occurredAt;
    // The reducer orders by (occurredAt, eventId) and drops a ReceiptAttached
    // whose purchase does not yet exist. Guarantee the re-attach sorts strictly
    // after the corrected purchase so no receipt is ever lost on an edit.
    final receiptAt = now.isAfter(newAt)
        ? now
        : newAt.add(const Duration(milliseconds: 1));

    final events = <Event>[
      PurchaseVoided(
        eventId: uuidv7(),
        deviceId: deviceId,
        userId: meUserId,
        occurredAt: now,
        createdAt: now,
        purchaseId: old.purchaseId,
      ),
      PurchaseAdded(
        eventId: uuidv7(),
        deviceId: deviceId,
        userId: meUserId,
        occurredAt: newAt,
        createdAt: now,
        purchaseId: newId,
        target: newTarget,
        amountCents: amountCents ?? old.amountCents,
        shared: newShared,
        merchant: identical(merchant, _unset)
            ? old.merchant
            : merchant as String?,
        note: identical(note, _unset) ? old.note : note as String?,
        taxDeductible: identical(taxDeductible, _unset)
            ? old.taxDeductible
            : taxDeductible as bool?,
        amendsPurchaseId: old.purchaseId,
      ),
      for (final receipt in old.receipts)
        ReceiptAttached(
          eventId: uuidv7(),
          deviceId: deviceId,
          userId: meUserId,
          occurredAt: receiptAt,
          createdAt: now,
          purchaseId: newId,
          sha256: receipt.sha256,
          mimeType: receipt.mimeType,
          sizeBytes: receipt.sizeBytes,
        ),
    ];
    await _commit(events);
    return newId;
  }

  /// Ingests receipt [bytes] into the blob store and attaches the blob to
  /// [purchaseId]. Images are re-encoded (JPEG ~85, ≤2000px); PDFs stored as-is.
  Future<ReceiptRef> attachReceiptBytes(
    String purchaseId,
    Uint8List bytes, {
    required bool isPdf,
  }) async {
    final ingested = isPdf
        ? await ingestReceiptPdf(bytes, blobs)
        : await ingestReceiptImage(bytes, blobs);
    final now = DateTime.now().toUtc();
    await _commit([
      ReceiptAttached(
        eventId: uuidv7(),
        deviceId: deviceId,
        userId: meUserId,
        occurredAt: now,
        createdAt: now,
        purchaseId: purchaseId,
        sha256: ingested.sha256,
        mimeType: ingested.mimeType,
        sizeBytes: ingested.sizeBytes,
      ),
    ]);
    return ReceiptRef(
      sha256: ingested.sha256,
      mimeType: ingested.mimeType,
      sizeBytes: ingested.sizeBytes,
    );
  }

  /// Removes a receipt reference from a purchase (the blob itself is retained
  /// until garbage collection finds it unreferenced).
  Future<void> detachReceipt(String purchaseId, String sha256) async {
    final now = DateTime.now().toUtc();
    await _commit([
      ReceiptDetached(
        eventId: uuidv7(),
        deviceId: deviceId,
        userId: meUserId,
        occurredAt: now,
        createdAt: now,
        purchaseId: purchaseId,
        sha256: sha256,
      ),
    ]);
  }
}
