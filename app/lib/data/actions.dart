/// Write-side helpers: the small set of mutations the entry / detail / OCR flows
/// need, expressed strictly as **appended events**.
///
/// Nothing here computes balances — that is the reducer's job. Purchases are
/// recorded as [PurchaseAdded]; corrections (editing merchant/note/date/shared/
/// tax, or the amount) are done the event-sourced way: the old purchase is
/// [PurchaseVoided] and a corrected [PurchaseAdded] is appended, carrying its
/// receipts across. Receipts are content-addressed blobs referenced by
/// [ReceiptAttached] / [ReceiptDetached].
library;

import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/event.dart';
import '../domain/ids.dart';
import '../domain/state.dart';
import '../domain/value_types.dart';
import 'blobs/blob_store.dart';
import 'blobs/media_ingest.dart';
import 'db/database.dart';
import 'providers.dart';

/// Sentinel distinguishing "leave this optional field unchanged" from
/// "explicitly set it to null" in [HouseholdActions.amendPurchase].
const Object _unset = Object();

/// The device identity stamped on every event this device authors. Generated
/// once per session; a durable, synced device id is a concern of the sync phase.
final deviceIdProvider = Provider<String>((ref) => uuidv7());

/// The write-side action surface, bound to the current device and user.
final householdActionsProvider = Provider<HouseholdActions?>((ref) {
  final setup = ref.watch(localSetupProvider).value;
  if (setup == null) return null;
  return HouseholdActions(
    db: ref.watch(appDatabaseProvider),
    blobs: ref.watch(blobStoreProvider),
    deviceId: ref.watch(deviceIdProvider),
    meUserId: setup.meUserId,
  );
}, dependencies: [
  localSetupProvider,
  appDatabaseProvider,
  blobStoreProvider,
  deviceIdProvider,
]);

/// Appends the events behind the entry, detail, and OCR-confirm flows.
class HouseholdActions {
  HouseholdActions({
    required this.db,
    required this.blobs,
    required this.deviceId,
    required this.meUserId,
  });

  final AppDatabase db;
  final BlobStore blobs;
  final String deviceId;
  final String meUserId;

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
    await db.eventsDao.appendEvents([event]);
    return purchaseId;
  }

  /// Voids a purchase (a correction that keeps the original for audit).
  Future<void> voidPurchase(String purchaseId) async {
    final now = DateTime.now().toUtc();
    await db.eventsDao.appendEvents([
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
    final receiptAt =
        now.isAfter(newAt) ? now : newAt.add(const Duration(milliseconds: 1));

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
        merchant: identical(merchant, _unset) ? old.merchant : merchant as String?,
        note: identical(note, _unset) ? old.note : note as String?,
        taxDeductible: identical(taxDeductible, _unset)
            ? old.taxDeductible
            : taxDeductible as bool?,
      ),
      for (final r in old.receipts)
        ReceiptAttached(
          eventId: uuidv7(),
          deviceId: deviceId,
          userId: meUserId,
          occurredAt: receiptAt,
          createdAt: now,
          purchaseId: newId,
          sha256: r.sha256,
          mimeType: r.mimeType,
          sizeBytes: r.sizeBytes,
        ),
    ];
    await db.eventsDao.appendEvents(events);
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
    await db.eventsDao.appendEvents([
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
    await db.eventsDao.appendEvents([
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
