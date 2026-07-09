/// The first-run onboarding as a **pure model**: a set of collected inputs
/// (the party, incomes, tracked accounts, fixed expenses, the budget, an
/// optional first goal) mapped to the exact list of domain events the wizard
/// appends when it finishes — plus the device-local [LocalSetup] pointer.
///
/// This mirrors the `budget_setup_model` pattern: Flutter-free, deterministic,
/// unit-tested. The UI in `setup_screen.dart` only collects [OnboardingInput]
/// and lays it out; this function decides which events are written, so the
/// wizard's behaviour is testable inputs → event list with no widget in sight.
library;

import '../../data/setup/local_setup.dart';
import '../../domain/event.dart';
import '../../domain/ids.dart';
import '../../domain/time.dart';
import '../../domain/value_types.dart';

/// Which party role a drafted member takes. Mirrors [MemberRole]; kept separate
/// only so the collecting UI can order the flow (adults → dependents → pets).
enum DraftRole { adult, dependent, pet }

MemberRole _roleOf(DraftRole r) => switch (r) {
      DraftRole.adult => MemberRole.adult,
      DraftRole.dependent => MemberRole.dependent,
      DraftRole.pet => MemberRole.pet,
    };

/// One party member being created. [localId] is assigned while collecting and
/// becomes the member's permanent `memberId`, so incomes, category ownership and
/// the share table can all reference it before any event exists.
class DraftMember {
  const DraftMember({
    required this.localId,
    required this.role,
    required this.name,
    this.descriptionText,
    this.spriteSha256,
  });

  final String localId;
  final DraftRole role;
  final String name;

  /// The invited free-text character description that feeds text-mode adventure.
  final String? descriptionText;
  final String? spriteSha256;

  bool get isAdult => role == DraftRole.adult;
}

/// One tracked net-worth account drafted during onboarding. The [kind] decides
/// which optional fields are meaningful (savings/debt accrue; investments go
/// stale; debts carry a minimum payment).
class DraftAccount {
  const DraftAccount({
    required this.name,
    required this.kind,
    required this.balanceCents,
    this.aprBps,
    this.accrualCadence,
    this.updateCadence,
    this.minPaymentCents,
  });

  final String name;
  final AccountKind kind;

  /// The recorded balance (for a debt, the amount owed).
  final int balanceCents;
  final int? aprBps;
  final AccountCadence? accrualCadence;
  final AccountCadence? updateCadence;
  final int? minPaymentCents;
}

/// One fixed recurring expense drafted during onboarding. Group ones split by
/// shares off the top; personal ones come off one adult's budget.
class DraftFixedExpense {
  const DraftFixedExpense({
    required this.name,
    required this.shared,
    required this.amountCents,
    this.ownerLocalId,
    this.cadence = RecurringCadence.monthly,
    this.dueDay = 1,
    this.dueMonth,
  });

  final String name;

  /// True for a group (household) expense; false for a single adult's.
  final bool shared;

  /// The owning adult's [DraftMember.localId] when not [shared].
  final String? ownerLocalId;
  final int amountCents;
  final RecurringCadence cadence;
  final int dueDay;

  /// The due calendar month (1..12) for an annual expense; null for monthly.
  final int? dueMonth;
}

/// One budget category drafted during onboarding — group (household) or
/// personal (a single adult's).
class DraftCategory {
  const DraftCategory({
    required this.name,
    required this.limitCents,
    required this.group,
    this.ownerLocalId,
    this.mainCategoryId,
    this.petId,
  });

  final String name;
  final int limitCents;

  /// True for a group category; false for a personal one owned by [ownerLocalId].
  final bool group;
  final String? ownerLocalId;
  final String? mainCategoryId;

  /// A pet member this category is displayed under (its micro-budget), if any.
  final String? petId;
}

/// The optional first savings goal (the first quest boss).
class DraftQuest {
  const DraftQuest({
    required this.name,
    required this.targetCents,
    required this.shared,
    this.ownerLocalId,
    this.mainCategoryId,
    this.descriptionText,
  });

  final String name;
  final int targetCents;

  /// True for a shared goal; false for a personal one owned by [ownerLocalId].
  final bool shared;
  final String? ownerLocalId;
  final String? mainCategoryId;
  final String? descriptionText;
}

/// Everything the wizard collected. Feeds [buildOnboardingEvents] verbatim.
class OnboardingInput {
  const OnboardingInput({
    required this.members,
    required this.meLocalId,
    this.timezone = 'America/Vancouver',
    this.defaultIncomeByAdult = const {},
    this.accounts = const [],
    this.fixedExpenses = const [],
    this.categories = const [],
    this.shares,
    this.firstQuest,
  });

  final String timezone;

  /// The whole party, in the order the wizard built them (adults, then
  /// dependents, then pets). At least one adult is required.
  final List<DraftMember> members;

  /// Which adult this device is (a [DraftMember.localId] with an adult role).
  final String meLocalId;

  /// Default monthly income per adult localId (0 is allowed and explicit).
  final Map<String, int> defaultIncomeByAdult;

  final List<DraftAccount> accounts;
  final List<DraftFixedExpense> fixedExpenses;
  final List<DraftCategory> categories;

  /// Per-adult share weights in permille (localId → permille). When null, an
  /// even split is written; supply this only to record a custom split.
  final Map<String, int>? shares;

  final DraftQuest? firstQuest;

  List<DraftMember> get adults =>
      members.where((m) => m.isAdult).toList(growable: false);
}

/// The events to append plus the device-local setup to persist, produced from an
/// [OnboardingInput]. Applying [events] and saving [localSetup] completes setup.
class OnboardingPlan {
  const OnboardingPlan({required this.events, required this.localSetup});

  final List<Event> events;
  final LocalSetup localSetup;
}

/// Default pool-tithe percent seeded on a personal category at onboarding. Zero
/// keeps leftover fully with the owner until they tune it later in Settings.
const int _defaultPoolTithePct = 0;

/// An even permille split across [n] adults that always sums to exactly 1000;
/// the remainder cents land on the earliest adults.
Map<String, int> evenShares(List<String> adultIds) {
  final n = adultIds.length;
  if (n == 0) return const {};
  final base = 1000 ~/ n;
  var remainder = 1000 - base * n;
  return {
    for (final id in adultIds) id: base + (remainder-- > 0 ? 1 : 0),
  };
}

/// Maps a completed [OnboardingInput] to the ordered event list the wizard
/// appends, plus the [LocalSetup] this device stores.
///
/// [idGen] supplies event/entity ids (defaults to real UUIDv7; tests inject a
/// counter for determinism); [now] stamps `occurredAt`/`createdAt`; [startMonth]
/// keys the income defaults, category limits, share table and recurring
/// expenses to the household's first month.
OnboardingPlan buildOnboardingEvents(
  OnboardingInput input, {
  required String deviceId,
  required Month startMonth,
  DateTime? now,
  String Function()? idGen,
}) {
  final adults = input.adults;
  if (adults.isEmpty) {
    throw ArgumentError('Onboarding needs at least one adult member.');
  }
  if (!adults.any((a) => a.localId == input.meLocalId)) {
    throw ArgumentError('meLocalId must be one of the adult members.');
  }

  final at = (now ?? DateTime.now()).toUtc();
  final nextId = idGen ?? uuidv7;
  final me = input.meLocalId;

  Event stamp(Event Function(String eventId) build) => build(nextId());

  final events = <Event>[];

  // 1. The party: adults, then dependents, then pets (MemberSet).
  for (final m in input.members) {
    events.add(stamp((eventId) => MemberSet(
          eventId: eventId,
          deviceId: deviceId,
          userId: me,
          occurredAt: at,
          createdAt: at,
          memberId: m.localId,
          name: m.name,
          role: _roleOf(m.role),
          descriptionText: m.descriptionText,
          customSpriteSha256: m.spriteSha256,
        )));
  }

  // 2. Per-adult default monthly income (0 is written explicitly).
  for (final a in adults) {
    events.add(stamp((eventId) => DefaultIncomeSet(
          eventId: eventId,
          deviceId: deviceId,
          userId: me,
          occurredAt: at,
          createdAt: at,
          forUserId: a.localId,
          amountCents: input.defaultIncomeByAdult[a.localId] ?? 0,
          effectiveFromMonth: startMonth,
        )));
  }

  // 3. Tracked accounts: config + first recorded balance. Any account turns on
  // the net-worth screen so what was just entered is visible.
  if (input.accounts.isNotEmpty) {
    events.add(stamp((eventId) => SettingChanged(
          eventId: eventId,
          deviceId: deviceId,
          userId: me,
          occurredAt: at,
          createdAt: at,
          key: 'showNetWorth',
          value: true,
        )));
  }
  for (final acc in input.accounts) {
    final accountId = nextId();
    events.add(stamp((eventId) => TrackedAccountSet(
          eventId: eventId,
          deviceId: deviceId,
          userId: me,
          occurredAt: at,
          createdAt: at,
          accountId: accountId,
          name: acc.name,
          kind: acc.kind,
          aprBps: acc.aprBps,
          accrualCadence: acc.accrualCadence,
          updateCadence: acc.updateCadence,
          minPaymentCents: acc.minPaymentCents,
        )));
    events.add(stamp((eventId) => AccountBalanceRecorded(
          eventId: eventId,
          deviceId: deviceId,
          userId: me,
          occurredAt: at,
          createdAt: at,
          accountId: accountId,
          accountName: acc.name,
          kind: acc.kind,
          balanceCents: acc.balanceCents,
        )));
  }

  // 4. Fixed expenses: group first, then per-adult (RecurringExpenseSet).
  final orderedExpenses = [
    ...input.fixedExpenses.where((e) => e.shared),
    ...input.fixedExpenses.where((e) => !e.shared),
  ];
  for (final e in orderedExpenses) {
    final ownership = e.shared
        ? const SharedParty()
        : PersonalParty(e.ownerLocalId ?? me);
    events.add(stamp((eventId) => RecurringExpenseSet(
          eventId: eventId,
          deviceId: deviceId,
          userId: me,
          occurredAt: at,
          createdAt: at,
          expenseId: nextId(),
          name: e.name,
          ownership: ownership,
          kind: RecurringKind.fixed,
          cadence: e.cadence,
          amountCents: e.amountCents,
          dueDay: e.dueDay,
          dueMonth: e.dueMonth,
          startMonth: startMonth,
        )));
  }

  // 5. Budget: group categories first, then personal (BudgetSliceSet).
  final orderedCategories = [
    ...input.categories.where((c) => c.group),
    ...input.categories.where((c) => !c.group),
  ];
  for (final c in orderedCategories) {
    final ownership = c.group
        ? const GroupSlice()
        : PersonalSlice(c.ownerLocalId ?? me);
    events.add(stamp((eventId) => BudgetSliceSet(
          eventId: eventId,
          deviceId: deviceId,
          userId: me,
          occurredAt: at,
          createdAt: at,
          sliceId: nextId(),
          name: c.name,
          ownership: ownership,
          mainCategoryId: c.mainCategoryId,
          limitCents: c.limitCents,
          poolTithePct: _defaultPoolTithePct,
          defaultLeftoverPolicy: const CarryInSlice(),
          taxDeductibleByDefault: false,
          petId: c.petId,
        )));
  }

  // 6. Share table for the first month (only meaningful with ≥2 adults).
  if (adults.length >= 2) {
    final adultIds = [for (final a in adults) a.localId];
    final shares = input.shares ?? evenShares(adultIds);
    events.add(stamp((eventId) => GroupShareSet(
          eventId: eventId,
          deviceId: deviceId,
          userId: me,
          occurredAt: at,
          createdAt: at,
          month: startMonth,
          shares: shares,
        )));
  }

  // 7. The optional first goal (QuestSet).
  final quest = input.firstQuest;
  if (quest != null) {
    final ownership = quest.shared
        ? const SharedParty()
        : PersonalParty(quest.ownerLocalId ?? me);
    events.add(stamp((eventId) => QuestSet(
          eventId: eventId,
          deviceId: deviceId,
          userId: me,
          occurredAt: at,
          createdAt: at,
          questId: nextId(),
          name: quest.name,
          targetCents: quest.targetCents,
          ownership: ownership,
          mainCategoryId: quest.mainCategoryId,
          descriptionText: quest.descriptionText,
        )));
  }

  return OnboardingPlan(
    events: events,
    localSetup: _localSetupFor(input),
  );
}

/// Builds the device-local pointer. The reducer derives the whole party from
/// [MemberSet] events; [LocalSetup] only stores this device's timezone and which
/// adult it is, keeping the legacy two-profile shape for backward compatibility
/// (a single-adult household points both profiles at that adult).
LocalSetup _localSetupFor(OnboardingInput input) {
  final adults = input.adults;
  final meAdult = adults.firstWhere((a) => a.localId == input.meLocalId);
  final other = adults.firstWhere(
    (a) => a.localId != input.meLocalId,
    orElse: () => meAdult,
  );
  return LocalSetup(
    timezone: input.timezone,
    user1: UserProfile(userId: meAdult.localId, name: meAdult.name),
    user2: UserProfile(userId: other.localId, name: other.name),
    meUserId: meAdult.localId,
  );
}
