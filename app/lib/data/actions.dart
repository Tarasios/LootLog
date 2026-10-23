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

import 'dart:async';
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
import 'game_rewards.dart';
import 'providers.dart';

part 'actions/habit_actions.dart';
part 'actions/household_setup_actions.dart';
part 'actions/month_close_actions.dart';
part 'actions/net_worth_actions.dart';
part 'actions/purchase_actions.dart';
part 'actions/quest_actions.dart';
part 'actions/savings_actions.dart';
part 'actions/vacation_actions.dart';
part 'actions/war_chest_actions.dart';

/// Sentinel distinguishing "leave this optional field unchanged" from
/// "explicitly set it to null" in [HouseholdActions.amendPurchase].
const Object _unset = Object();

/// The device identity stamped on every event this device authors. Generated
/// once per session; a durable, synced device id is a concern of the sync phase.
final deviceIdProvider = Provider<String>((ref) => uuidv7());

/// The write-side action surface, bound to the current device and user.
final householdActionsProvider = Provider<HouseholdActions?>(
  (ref) {
    final setup = ref.watch(localSetupProvider).value;
    if (setup == null) return null;
    return HouseholdActions(
      db: ref.watch(appDatabaseProvider),
      blobs: ref.watch(blobStoreProvider),
      deviceId: ref.watch(deviceIdProvider),
      meUserId: setup.meUserId,
      gameRewards: ref.watch(gameRewardRunnerProvider),
    );
  },
  dependencies: [
    localSetupProvider,
    appDatabaseProvider,
    blobStoreProvider,
    deviceIdProvider,
    gameRewardRunnerProvider,
  ],
);

/// The guild hall's reward runner for this device. Shared by local writes and
/// sync merges so their runs coalesce instead of racing.
final gameRewardRunnerProvider = Provider<GameRewardRunner?>(
  (ref) {
    final setup = ref.watch(localSetupProvider).value;
    if (setup == null) return null;
    return GameRewardRunner(
      db: ref.watch(appDatabaseProvider),
      deviceId: ref.watch(deviceIdProvider),
    );
  },
  dependencies: [localSetupProvider, appDatabaseProvider, deviceIdProvider],
);

/// Appends the events behind the entry, detail, and OCR-confirm flows.
///
/// One facade on purpose: every caller holds a single handle bound to this
/// device and adult (see [householdActionsProvider]). Its writes are grouped
/// into cohesive role mixins — one part file each under `actions/` — over
/// [_HouseholdActionsCore], which owns the stores and the commit path.
class HouseholdActions extends _HouseholdActionsCore
    with
        _PurchaseActions,
        _MonthCloseActions,
        _HabitActions,
        _HouseholdSetupActions,
        _QuestActions,
        _WarChestActions,
        _SavingsEconomyActions,
        _NetWorthActions,
        _VacationActions {
  HouseholdActions({
    required super.db,
    required super.blobs,
    required super.deviceId,
    required super.meUserId,
    super.gameRewards,
  });
}

/// What every write needs: the stores, this device's identity, and the
/// commit path that appends events and wakes the guild hall's reward engine.
/// Also holds the few writes the role mixins share (settings, rewards).
abstract class _HouseholdActionsCore {
  _HouseholdActionsCore({
    required this.db,
    required this.blobs,
    required this.deviceId,
    required this.meUserId,
    this.gameRewards,
  });

  final AppDatabase db;
  final BlobStore blobs;
  final String deviceId;
  final String meUserId;

  /// Runs after every write; null leaves game rewards out (tests, tools).
  final GameRewardRunner? gameRewards;

  /// Appends a single [event], stamping nothing — callers build the whole event.
  Future<void> append(Event event) => _commit([event]);

  /// Every local ledger write lands here: append, then start the guild hall's
  /// reward engine catching up (idempotent, game events only). Not awaited:
  /// rewards never slow down or fail a write.
  Future<void> _commit(List<Event> events) async {
    await db.eventsDao.appendEvents(events);
    final rewards = gameRewards;
    if (rewards != null) unawaited(rewards.run());
  }

  /// Changes a household setting. Known keys: `spoilsGraceDays`,
  /// `dissolutionTithePct`, `showNetWorth`.
  Future<void> changeSetting(String key, Object? value) async {
    final now = DateTime.now().toUtc();
    await append(
      SettingChanged(
        eventId: uuidv7(),
        deviceId: deviceId,
        userId: meUserId,
        occurredAt: now,
        createdAt: now,
        key: key,
        value: value,
      ),
    );
  }

  /// Whether this household may record the newer event types (no-spend
  /// check-ins, reconciles). See [householdAcceptsNewEventTypes].
  Future<bool> acceptsNewEventTypes() async =>
      householdAcceptsNewEventTypes(reduce(await db.eventsDao.allEvents()));

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
      for (final pendingReward in pending)
        GameRewardGranted(
          eventId: uuidv7(),
          deviceId: deviceId,
          userId: meUserId,
          occurredAt: now,
          createdAt: now,
          rewardId: pendingReward.rewardId,
          kind: pendingReward.kind,
          sourceRef: pendingReward.sourceRef,
          grantedAt: now,
        ),
    ];
    await db.eventsDao.appendEvents(events);
    return events;
  }
}
