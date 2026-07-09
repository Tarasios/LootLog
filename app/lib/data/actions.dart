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
import '../domain/reducer.dart';
import '../domain/state.dart';
import '../domain/time.dart';
import '../domain/value_types.dart';
import '../game/rewards/rewards.dart';
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
    // Logging a purchase can extend a daily streak — grant any newly-earned
    // cosmetic rewards (idempotent, cosmetic-only).
    await grantPendingRewards();
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

  /// Records a variable recurring expense's actual for [month] (spoils step 1).
  Future<void> recordVariableActual({
    required String expenseId,
    required Month month,
    required int actualCents,
  }) async {
    final now = DateTime.now().toUtc();
    await db.eventsDao.appendEvents([
      VariableExpenseRecorded(
        eventId: uuidv7(),
        deviceId: deviceId,
        userId: meUserId,
        occurredAt: now,
        createdAt: now,
        expenseId: expenseId,
        month: month,
        actualCents: actualCents,
      ),
    ]);
  }

  /// Records one slice's month-close allocation (spoils step 2). The
  /// [allocations] must sum to that slice's leftover; the reducer validates
  /// nothing beyond replaying them, so callers build them from the ritual.
  Future<void> allocateLeftover({
    required String forUserId,
    required Month month,
    required String sliceId,
    required List<Allocation> allocations,
  }) async {
    final now = DateTime.now().toUtc();
    await db.eventsDao.appendEvents([
      LeftoverAllocated(
        eventId: uuidv7(),
        deviceId: deviceId,
        userId: meUserId,
        occurredAt: now,
        createdAt: now,
        forUserId: forUserId,
        month: month,
        sliceId: sliceId,
        allocations: allocations,
      ),
    ]);
    // Closing a category can defeat a quest boss (a trophy) and extend the
    // on-time-ritual streak (a badge) — grant any newly-earned cosmetic rewards.
    await grantPendingRewards();
  }

  /// Signs a pending war-chest writ. The reducer rejects self-approval, so this
  /// is only meaningful when [meUserId] is not the proposer.
  Future<void> approveWithdrawal(String proposalId) async {
    final now = DateTime.now().toUtc();
    await db.eventsDao.appendEvents([
      PoolWithdrawalApproved(
        eventId: uuidv7(),
        deviceId: deviceId,
        userId: meUserId,
        occurredAt: now,
        createdAt: now,
        proposalId: proposalId,
        byUserId: meUserId,
      ),
    ]);
  }

  /// Cancels (declines) a pending war-chest writ.
  Future<void> cancelWithdrawal(String proposalId) async {
    final now = DateTime.now().toUtc();
    await db.eventsDao.appendEvents([
      PoolWithdrawalCancelled(
        eventId: uuidv7(),
        deviceId: deviceId,
        userId: meUserId,
        occurredAt: now,
        createdAt: now,
        proposalId: proposalId,
      ),
    ]);
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

  // ---- Configuration & governance (settings / setup / quests / chest) -----

  /// Appends a single [event], stamping nothing — callers build the whole event.
  Future<void> append(Event event) => db.eventsDao.appendEvents([event]);

  /// Records any cosmetic rewards the household has newly earned — defeated-quest
  /// trophies and habit-streak titles/badges — as [GameRewardGranted] events so
  /// they sync like everything else. Idempotent: rewards already granted (by any
  /// device) are skipped, so this is safe to call after every state change.
  ///
  /// This is on the display side of the firewall: it only ever appends cosmetic
  /// events. It never moves a cent.
  Future<List<GameRewardGranted>> grantPendingRewards({DateTime? asOf}) async {
    final now = (asOf ?? DateTime.now()).toUtc();
    final log = await db.eventsDao.allEvents();
    final state = reduce(log, asOf: now);
    final earned = computeEarnedRewards(state, log, asOf: now);
    final pending = ungrantedRewards(earned, log);
    if (pending.isEmpty) return const [];
    final events = [
      for (final r in pending)
        GameRewardGranted(
          eventId: uuidv7(),
          deviceId: deviceId,
          userId: meUserId,
          occurredAt: now,
          createdAt: now,
          rewardId: r.rewardId,
          kind: r.kind,
          sourceRef: r.sourceRef,
          grantedAt: now,
        ),
    ];
    await db.eventsDao.appendEvents(events);
    return events;
  }

  /// Sets a user's income for [month] (last-writer-wins in the reducer).
  Future<void> setIncome({
    required String forUserId,
    required Month month,
    required int amountCents,
  }) async {
    final now = DateTime.now().toUtc();
    await append(IncomeSet(
      eventId: uuidv7(),
      deviceId: deviceId,
      userId: meUserId,
      occurredAt: now,
      createdAt: now,
      forUserId: forUserId,
      amountCents: amountCents,
      month: month,
    ));
  }

  /// Sets a user's default monthly income, effective from [effectiveFromMonth]
  /// and carried forward until a later default supersedes it.
  Future<void> setDefaultIncome({
    required String forUserId,
    required int amountCents,
    required Month effectiveFromMonth,
  }) async {
    final now = DateTime.now().toUtc();
    await append(DefaultIncomeSet(
      eventId: uuidv7(),
      deviceId: deviceId,
      userId: meUserId,
      occurredAt: now,
      createdAt: now,
      forUserId: forUserId,
      amountCents: amountCents,
      effectiveFromMonth: effectiveFromMonth,
    ));
  }

  /// Creates or amends a recurring expense. Reuse [expenseId] to edit; pass
  /// [endMonth] to schedule a cancellation.
  Future<String> setRecurringExpense({
    String? expenseId,
    required String name,
    required PartyOwnership ownership,
    required RecurringKind kind,
    required int amountCents,
    required Month startMonth,
    Month? endMonth,
    RecurringCadence cadence = RecurringCadence.monthly,
    int dueDay = 1,
    int? dueMonth,
  }) async {
    final now = DateTime.now().toUtc();
    final id = expenseId ?? uuidv7();
    await append(RecurringExpenseSet(
      eventId: uuidv7(),
      deviceId: deviceId,
      userId: meUserId,
      occurredAt: now,
      createdAt: now,
      expenseId: id,
      name: name,
      ownership: ownership,
      kind: kind,
      cadence: cadence,
      amountCents: amountCents,
      dueDay: dueDay,
      dueMonth: dueMonth,
      startMonth: startMonth,
      endMonth: endMonth,
    ));
    return id;
  }

  /// Creates or amends a budget category (last-writer-wins by [sliceId]; the
  /// wire event stays `BudgetSliceSet`).
  Future<String> setSlice({
    String? sliceId,
    required String name,
    required SliceOwnership ownership,
    required int limitCents,
    required int poolTithePct,
    required LeftoverDestination defaultLeftoverPolicy,
    required bool taxDeductibleByDefault,
    String? mainCategoryId,
    EmergencyContribution? emergencyContribution,
    String? petId,
  }) async {
    final now = DateTime.now().toUtc();
    final id = sliceId ?? uuidv7();
    await append(BudgetSliceSet(
      eventId: uuidv7(),
      deviceId: deviceId,
      userId: meUserId,
      occurredAt: now,
      createdAt: now,
      sliceId: id,
      name: name,
      ownership: ownership,
      mainCategoryId: mainCategoryId,
      limitCents: limitCents,
      poolTithePct: poolTithePct,
      defaultLeftoverPolicy: defaultLeftoverPolicy,
      taxDeductibleByDefault: taxDeductibleByDefault,
      emergencyContribution: emergencyContribution,
      petId: petId,
    ));
    return id;
  }

  /// Creates or amends a main category (last-writer-wins by [id]).
  Future<String> setMainCategory({
    required String id,
    required String name,
    required int colorArgb,
    required int sortOrder,
  }) async {
    final now = DateTime.now().toUtc();
    await append(MainCategorySet(
      eventId: uuidv7(),
      deviceId: deviceId,
      userId: meUserId,
      occurredAt: now,
      createdAt: now,
      id: id,
      name: name,
      colorArgb: colorArgb,
      sortOrder: sortOrder,
    ));
    return id;
  }

  /// Creates or renames an emergency fund (last-writer-wins by [fundId]).
  Future<String> setEmergencyFund({
    String? fundId,
    required String name,
    String? petId,
  }) async {
    final now = DateTime.now().toUtc();
    final id = fundId ?? uuidv7();
    await append(EmergencyFundSet(
      eventId: uuidv7(),
      deviceId: deviceId,
      userId: meUserId,
      occurredAt: now,
      createdAt: now,
      fundId: id,
      name: name,
      petId: petId,
    ));
    return id;
  }

  /// Creates or renames a pet party member (last-writer-wins by [petId]).
  Future<String> setPet({
    String? petId,
    required String name,
    String? customSpriteSha256,
  }) async {
    final now = DateTime.now().toUtc();
    final id = petId ?? uuidv7();
    await append(PetSet(
      eventId: uuidv7(),
      deviceId: deviceId,
      userId: meUserId,
      occurredAt: now,
      createdAt: now,
      petId: id,
      name: name,
      customSpriteSha256: customSpriteSha256,
    ));
    return id;
  }

  /// Creates, amends, or retires a household member (last-writer-wins by
  /// [memberId]). Pass `active: false` to retire without deleting history.
  Future<String> setMember({
    String? memberId,
    required String name,
    required MemberRole role,
    bool active = true,
    String? customSpriteSha256,
    String? descriptionText,
  }) async {
    final now = DateTime.now().toUtc();
    final id = memberId ?? uuidv7();
    await append(MemberSet(
      eventId: uuidv7(),
      deviceId: deviceId,
      userId: meUserId,
      occurredAt: now,
      createdAt: now,
      memberId: id,
      name: name,
      role: role,
      active: active,
      customSpriteSha256: customSpriteSha256,
      descriptionText: descriptionText,
    ));
    return id;
  }

  /// Sets the per-adult share table for [month] (permille per adult id). Absent,
  /// shared costs split evenly.
  Future<void> setGroupShares({
    required Month month,
    required Map<String, int> shares,
  }) async {
    final now = DateTime.now().toUtc();
    await append(GroupShareSet(
      eventId: uuidv7(),
      deviceId: deviceId,
      userId: meUserId,
      occurredAt: now,
      createdAt: now,
      month: month,
      shares: shares,
    ));
  }

  /// Creates or amends a savings-goal quest (last-writer-wins by [questId]).
  Future<String> setQuest({
    String? questId,
    required String name,
    required int targetCents,
    required PartyOwnership ownership,
    String? mainCategoryId,
    String? sliceHint,
    String? customSpriteSha256,
    String? descriptionText,
  }) async {
    final now = DateTime.now().toUtc();
    final id = questId ?? uuidv7();
    await append(QuestSet(
      eventId: uuidv7(),
      deviceId: deviceId,
      userId: meUserId,
      occurredAt: now,
      createdAt: now,
      questId: id,
      name: name,
      targetCents: targetCents,
      ownership: ownership,
      mainCategoryId: mainCategoryId,
      sliceHint: sliceHint,
      customSpriteSha256: customSpriteSha256,
      descriptionText: descriptionText,
    ));
    return id;
  }

  /// Abandons a quest, returning its balance to funders (post dissolution tithe).
  Future<void> abandonQuest(String questId) async {
    final now = DateTime.now().toUtc();
    await append(QuestAbandoned(
      eventId: uuidv7(),
      deviceId: deviceId,
      userId: meUserId,
      occurredAt: now,
      createdAt: now,
      questId: questId,
    ));
  }

  /// Records a gift into a user's vault (untithed).
  Future<void> recordGift({
    required String forUserId,
    required int amountCents,
    String? note,
  }) async {
    final now = DateTime.now().toUtc();
    await append(GiftReceived(
      eventId: uuidv7(),
      deviceId: deviceId,
      userId: meUserId,
      occurredAt: now,
      createdAt: now,
      forUserId: forUserId,
      amountCents: amountCents,
      note: note,
    ));
  }

  /// Moves discretionary money from a user's vault into the war chest.
  Future<void> contributeToPool({
    required String fromUserId,
    required int amountCents,
  }) async {
    final now = DateTime.now().toUtc();
    await append(PoolContributionMade(
      eventId: uuidv7(),
      deviceId: deviceId,
      userId: meUserId,
      occurredAt: now,
      createdAt: now,
      fromUserId: fromUserId,
      amountCents: amountCents,
    ));
  }

  /// Proposes a war-chest withdrawal (pending the other user's signature).
  Future<String> proposeWithdrawal({
    required int amountCents,
    required String purpose,
    required WithdrawalDestination destination,
  }) async {
    final now = DateTime.now().toUtc();
    final id = uuidv7();
    await append(PoolWithdrawalProposed(
      eventId: uuidv7(),
      deviceId: deviceId,
      userId: meUserId,
      occurredAt: now,
      createdAt: now,
      proposalId: id,
      byUserId: meUserId,
      amountCents: amountCents,
      purpose: purpose,
      destination: destination,
    ));
    return id;
  }

  /// Records a tax refund into the war chest.
  Future<void> recordTaxRefund({required int amountCents, String? note}) async {
    final now = DateTime.now().toUtc();
    await append(TaxRefundRecorded(
      eventId: uuidv7(),
      deviceId: deviceId,
      userId: meUserId,
      occurredAt: now,
      createdAt: now,
      amountCents: amountCents,
      note: note,
    ));
  }

  /// Sets the war chest's savings target.
  Future<void> setGoal(int targetCents) async {
    final now = DateTime.now().toUtc();
    await append(GoalSet(
      eventId: uuidv7(),
      deviceId: deviceId,
      userId: meUserId,
      occurredAt: now,
      createdAt: now,
      targetCents: targetCents,
    ));
  }

  /// Records a net-worth account balance (latest value wins).
  Future<String> recordAccountBalance({
    String? accountId,
    required String accountName,
    required AccountKind kind,
    required int balanceCents,
    DateTime? occurredAt,
  }) async {
    final now = DateTime.now().toUtc();
    final id = accountId ?? uuidv7();
    await append(AccountBalanceRecorded(
      eventId: uuidv7(),
      deviceId: deviceId,
      userId: meUserId,
      occurredAt: occurredAt ?? now,
      createdAt: now,
      accountId: id,
      accountName: accountName,
      kind: kind,
      balanceCents: balanceCents,
    ));
    return id;
  }

  /// Declares or amends a tracked net-worth account (last-writer-wins by
  /// [accountId]). Interest and staleness inputs live here; balances are
  /// recorded separately with [recordAccountBalance].
  Future<String> setTrackedAccount({
    String? accountId,
    required String name,
    required AccountKind kind,
    int? aprBps,
    AccountCadence? accrualCadence,
    AccountCadence? updateCadence,
    int? minPaymentCents,
  }) async {
    final now = DateTime.now().toUtc();
    final id = accountId ?? uuidv7();
    await append(TrackedAccountSet(
      eventId: uuidv7(),
      deviceId: deviceId,
      userId: meUserId,
      occurredAt: now,
      createdAt: now,
      accountId: id,
      name: name,
      kind: kind,
      aprBps: aprBps,
      accrualCadence: accrualCadence,
      updateCadence: updateCadence,
      minPaymentCents: minPaymentCents,
    ));
    return id;
  }

  /// Records a deposit into or withdrawal out of a tracked account.
  Future<void> recordAccountTransfer({
    required String accountId,
    required int amountCents,
    required TransferDirection direction,
    String? note,
    DateTime? occurredAt,
  }) async {
    final now = DateTime.now().toUtc();
    await append(AccountTransferRecorded(
      eventId: uuidv7(),
      deviceId: deviceId,
      userId: meUserId,
      occurredAt: occurredAt ?? now,
      createdAt: now,
      accountId: accountId,
      amountCents: amountCents,
      direction: direction,
      note: note,
    ));
  }

  /// Changes a household setting. Known keys: `spoilsGraceDays`,
  /// `dissolutionTithePct`, `showNetWorth`.
  Future<void> changeSetting(String key, Object? value) async {
    final now = DateTime.now().toUtc();
    await append(SettingChanged(
      eventId: uuidv7(),
      deviceId: deviceId,
      userId: meUserId,
      occurredAt: now,
      createdAt: now,
      key: key,
      value: value,
    ));
  }

  /// Opens or amends a vacation (last-writer-wins by [vacationId]). Reuse the id
  /// to edit; categories keep their ids so in-progress spending stays attributed.
  Future<String> setVacation({
    String? vacationId,
    required String name,
    required VacationFund fund,
    required DateTime startDate,
    required DateTime endDate,
    required List<VacationCategory> categories,
  }) async {
    final now = DateTime.now().toUtc();
    final id = vacationId ?? uuidv7();
    await append(VacationSet(
      eventId: uuidv7(),
      deviceId: deviceId,
      userId: meUserId,
      occurredAt: now,
      createdAt: now,
      vacationId: id,
      name: name,
      fund: fund,
      startDate: startDate,
      endDate: endDate,
      categories: categories,
    ));
    return id;
  }

  /// Closes a vacation, returning its unspent budget to the source fund.
  Future<void> closeVacation(String vacationId) async {
    final now = DateTime.now().toUtc();
    await append(VacationClosed(
      eventId: uuidv7(),
      deviceId: deviceId,
      userId: meUserId,
      occurredAt: now,
      createdAt: now,
      vacationId: vacationId,
    ));
  }

  /// Ingests a custom sprite PNG into the blob store, returning its sha256 for
  /// reference from a [PetSet] / [QuestSet]. Throws [SpriteRejected] if invalid.
  Future<String> ingestSpriteBytes(Uint8List pngBytes) async {
    final ingested = await ingestSprite(pngBytes, blobs);
    return ingested.sha256;
  }
}
