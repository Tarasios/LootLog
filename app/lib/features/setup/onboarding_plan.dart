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
import '../../domain/state.dart'
    show MainCategory, defaultMainCategories, kDefaultGeneralTithePct;
import '../../domain/time.dart';
import '../../domain/value_types.dart';
import '../settings/play_mode.dart';

/// Which party role a drafted member takes. Mirrors [MemberRole]; kept separate
/// only so the collecting UI can order the flow (adults → dependents → pets).
enum DraftRole { adult, dependent, pet }

MemberRole _roleOf(DraftRole role) => switch (role) {
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
    this.fundedByUserId,
  });

  final String localId;
  final DraftRole role;
  final String name;

  /// The invited free-text character description that feeds text-mode adventure.
  final String? descriptionText;
  final String? spriteSha256;

  /// For a pet: the adult (localId) whose budget funds this pet's categories;
  /// null means the group funds them (the common case).
  final String? fundedByUserId;

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

/// One recurring bill drafted during onboarding. Group ones split by shares off
/// the top; personal ones come off one adult's budget. (The name predates
/// variable bills: a draft may be [RecurringKind.fixed] or
/// [RecurringKind.variable].)
class DraftFixedExpense {
  const DraftFixedExpense({
    required this.name,
    required this.shared,
    required this.amountCents,
    this.ownerLocalId,
    this.kind = RecurringKind.fixed,
    this.cadence = RecurringCadence.monthly,
    this.dueDay = 1,
    this.dueMonth,
  });

  final String name;

  /// True for a group (household) expense; false for a single adult's.
  final bool shared;

  /// The owning adult's [DraftMember.localId] when not [shared].
  final String? ownerLocalId;

  /// Fixed (the same every time) or variable (an estimate; the actual is
  /// recorded at month close and the difference flows through savings).
  final RecurringKind kind;

  /// The amount — for a variable bill, the estimate used for planning.
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
    this.petOwnerIds = const [],
    this.tithePct = 0,
  });

  final String name;
  final int limitCents;

  /// True for a group category; false for a personal one owned by [ownerLocalId].
  final bool group;
  final String? ownerLocalId;
  final String? mainCategoryId;

  /// A pet member this category is displayed under (its micro-budget), if any.
  final String? petId;

  /// The pet members that own this category (a shared pet budget). Group
  /// categories only; each pet's equal share is planned against its funding
  /// source.
  final List<String> petOwnerIds;

  /// Pool tithe % (0–100) applied when leftover converts to discretionary.
  final int tithePct;

  DraftCategory copyWith({String? name, int? limitCents}) => DraftCategory(
    name: name ?? this.name,
    limitCents: limitCents ?? this.limitCents,
    group: group,
    ownerLocalId: ownerLocalId,
    mainCategoryId: mainCategoryId,
    petId: petId,
    petOwnerIds: petOwnerIds,
    tithePct: tithePct,
  );
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
    this.mainCategories = const [],
    this.shares,
    this.firstQuest,
    this.playModes = const {},
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

  /// The wizard's (possibly customized) main-category list. Entries that match
  /// [defaultMainCategories] byte-for-byte write no event; renames and
  /// additions become `MainCategorySet` events.
  final List<MainCategory> mainCategories;

  /// Per-adult share weights in permille (localId → permille). When null, an
  /// even split is written; supply this only to record a custom split.
  final Map<String, int>? shares;

  final DraftQuest? firstQuest;

  /// Each adult's play mode (localId → mode), recorded per person so it
  /// follows them to every device. Adults left out get the default.
  final Map<String, PlayMode> playModes;

  List<DraftMember> get adults =>
      members.where((member) => member.isAdult).toList(growable: false);
}

/// The events to append plus the device-local setup to persist, produced from an
/// [OnboardingInput]. Applying [events] and saving [localSetup] completes setup.
class OnboardingPlan {
  const OnboardingPlan({required this.events, required this.localSetup});

  final List<Event> events;
  final LocalSetup localSetup;
}

/// An even permille split across [n] adults that always sums to exactly 1000;
/// the remainder cents land on the earliest adults.
Map<String, int> evenShares(List<String> adultIds) {
  final adultCount = adultIds.length;
  if (adultCount == 0) return const {};
  final base = 1000 ~/ adultCount;
  var remainder = 1000 - base * adultCount;
  return {for (final id in adultIds) id: base + (remainder-- > 0 ? 1 : 0)};
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
  if (!adults.any((adult) => adult.localId == input.meLocalId)) {
    throw ArgumentError('meLocalId must be one of the adult members.');
  }

  final occurredAt = (now ?? DateTime.now()).toUtc();
  final nextId = idGen ?? uuidv7;
  final meLocalId = input.meLocalId;

  Event stamp(Event Function(String eventId) build) => build(nextId());

  final events = <Event>[];

  // 1. The party: adults, then dependents, then pets (MemberSet).
  for (final member in input.members) {
    events.add(
      stamp(
        (eventId) => MemberSet(
          eventId: eventId,
          deviceId: deviceId,
          userId: meLocalId,
          occurredAt: occurredAt,
          createdAt: occurredAt,
          memberId: member.localId,
          name: member.name,
          role: _roleOf(member.role),
          descriptionText: member.descriptionText,
          customSpriteSha256: member.spriteSha256,
          fundedByUserId: member.role == DraftRole.pet
              ? member.fundedByUserId
              : null,
        ),
      ),
    );
  }

  // 2. Per-adult default monthly income (0 is written explicitly).
  for (final adult in adults) {
    events.add(
      stamp(
        (eventId) => DefaultIncomeSet(
          eventId: eventId,
          deviceId: deviceId,
          userId: meLocalId,
          occurredAt: occurredAt,
          createdAt: occurredAt,
          forUserId: adult.localId,
          amountCents: input.defaultIncomeByAdult[adult.localId] ?? 0,
          effectiveFromMonth: startMonth,
        ),
      ),
    );
  }

  // 3. Tracked accounts: config + first recorded balance. Any account turns on
  // the net-worth screen so what was just entered is visible.
  if (input.accounts.isNotEmpty) {
    events.add(
      stamp(
        (eventId) => SettingChanged(
          eventId: eventId,
          deviceId: deviceId,
          userId: meLocalId,
          occurredAt: occurredAt,
          createdAt: occurredAt,
          key: 'showNetWorth',
          value: true,
        ),
      ),
    );
  }
  for (final account in input.accounts) {
    final accountId = nextId();
    events.add(
      stamp(
        (eventId) => TrackedAccountSet(
          eventId: eventId,
          deviceId: deviceId,
          userId: meLocalId,
          occurredAt: occurredAt,
          createdAt: occurredAt,
          accountId: accountId,
          name: account.name,
          kind: account.kind,
          aprBps: account.aprBps,
          accrualCadence: account.accrualCadence,
          updateCadence: account.updateCadence,
          minPaymentCents: account.minPaymentCents,
        ),
      ),
    );
    events.add(
      stamp(
        (eventId) => AccountBalanceRecorded(
          eventId: eventId,
          deviceId: deviceId,
          userId: meLocalId,
          occurredAt: occurredAt,
          createdAt: occurredAt,
          accountId: accountId,
          accountName: account.name,
          kind: account.kind,
          balanceCents: account.balanceCents,
        ),
      ),
    );
  }

  // 4. Recurring bills (fixed or variable): group first, then per-adult
  // (RecurringExpenseSet).
  final orderedExpenses = [
    ...input.fixedExpenses.where((expense) => expense.shared),
    ...input.fixedExpenses.where((expense) => !expense.shared),
  ];
  for (final expense in orderedExpenses) {
    final ownership = expense.shared
        ? const SharedParty()
        : PersonalParty(expense.ownerLocalId ?? meLocalId);
    events.add(
      stamp(
        (eventId) => RecurringExpenseSet(
          eventId: eventId,
          deviceId: deviceId,
          userId: meLocalId,
          occurredAt: occurredAt,
          createdAt: occurredAt,
          expenseId: nextId(),
          name: expense.name,
          ownership: ownership,
          kind: expense.kind,
          cadence: expense.cadence,
          amountCents: expense.amountCents,
          dueDay: expense.dueDay,
          dueMonth: expense.dueMonth,
          startMonth: startMonth,
        ),
      ),
    );
  }

  // 5a. Main-category customizations: only entries that differ from the
  // built-in defaults (renames, recolors) or are brand new write an event.
  final defaultsById = {
    for (final defaultCategory in defaultMainCategories)
      defaultCategory.id: defaultCategory,
  };
  for (final mainCategory in input.mainCategories) {
    final defaults = defaultsById[mainCategory.id];
    if (defaults != null &&
        defaults.name == mainCategory.name &&
        defaults.colorArgb == mainCategory.colorArgb &&
        defaults.sortOrder == mainCategory.sortOrder) {
      continue;
    }
    events.add(
      stamp(
        (eventId) => MainCategorySet(
          eventId: eventId,
          deviceId: deviceId,
          userId: meLocalId,
          occurredAt: occurredAt,
          createdAt: occurredAt,
          id: mainCategory.id,
          name: mainCategory.name,
          colorArgb: mainCategory.colorArgb,
          sortOrder: mainCategory.sortOrder,
        ),
      ),
    );
  }

  // 5. Budget: group categories first, then personal (BudgetSliceSet).
  final orderedCategories = [
    ...input.categories.where((category) => category.group),
    ...input.categories.where((category) => !category.group),
  ];
  for (final category in orderedCategories) {
    final ownership = category.group
        ? const GroupSlice()
        : PersonalSlice(category.ownerLocalId ?? meLocalId);
    events.add(
      stamp(
        (eventId) => BudgetSliceSet(
          eventId: eventId,
          deviceId: deviceId,
          userId: meLocalId,
          occurredAt: occurredAt,
          createdAt: occurredAt,
          sliceId: nextId(),
          name: category.name,
          ownership: ownership,
          mainCategoryId: category.mainCategoryId,
          limitCents: category.limitCents,
          poolTithePct: category.tithePct,
          defaultLeftoverPolicy: const CarryInSlice(),
          taxDeductibleByDefault: false,
          petId: category.petId,
          petOwnerIds: category.petOwnerIds,
        ),
      ),
    );
  }

  // 6. Share table for the first month (only meaningful with ≥2 adults).
  if (adults.length >= 2) {
    final adultIds = [for (final adult in adults) adult.localId];
    final shares = input.shares ?? evenShares(adultIds);
    events.add(
      stamp(
        (eventId) => GroupShareSet(
          eventId: eventId,
          deviceId: deviceId,
          userId: meLocalId,
          occurredAt: occurredAt,
          createdAt: occurredAt,
          month: startMonth,
          shares: shares,
        ),
      ),
    );
  }

  // 7. The optional first goal (QuestSet).
  final quest = input.firstQuest;
  if (quest != null) {
    final ownership = quest.shared
        ? const SharedParty()
        : PersonalParty(quest.ownerLocalId ?? meLocalId);
    events.add(
      stamp(
        (eventId) => QuestSet(
          eventId: eventId,
          deviceId: deviceId,
          userId: meLocalId,
          occurredAt: occurredAt,
          createdAt: occurredAt,
          questId: nextId(),
          name: quest.name,
          targetCents: quest.targetCents,
          ownership: ownership,
          mainCategoryId: quest.mainCategoryId,
          descriptionText: quest.descriptionText,
        ),
      ),
    );
  }

  // New households start on the savings rules from their first month.
  events.add(
    stamp(
      (eventId) => SettingChanged(
        eventId: eventId,
        deviceId: deviceId,
        userId: meLocalId,
        occurredAt: occurredAt,
        createdAt: occurredAt,
        key: 'savingsRules',
        value: {
          'fromMonth': startMonth.toKey(),
          'generalTithePct': kDefaultGeneralTithePct,
        },
      ),
    ),
  );

  // Each adult's play mode (cosmetic; the money reducer ignores it).
  for (final adult in input.adults) {
    final mode = input.playModes[adult.localId];
    if (mode == null) continue;
    events.add(
      stamp(
        (eventId) => CosmeticSet(
          eventId: eventId,
          deviceId: deviceId,
          userId: meLocalId,
          occurredAt: occurredAt,
          createdAt: occurredAt,
          key: playModeKey(adult.localId),
          value: mode.name,
        ),
      ),
    );
  }

  return OnboardingPlan(events: events, localSetup: _localSetupFor(input));
}

/// Builds the device-local pointer. The reducer derives the whole party from
/// [MemberSet] events; [LocalSetup] only stores this device's timezone and which
/// adult it is, keeping the legacy two-profile shape for backward compatibility
/// (a single-adult household points both profiles at that adult).
LocalSetup _localSetupFor(OnboardingInput input) {
  final adults = input.adults;
  final meAdult = adults.firstWhere(
    (adult) => adult.localId == input.meLocalId,
  );
  final other = adults.firstWhere(
    (adult) => adult.localId != input.meLocalId,
    orElse: () => meAdult,
  );
  return LocalSetup(
    timezone: input.timezone,
    user1: UserProfile(userId: meAdult.localId, name: meAdult.name),
    user2: UserProfile(userId: other.localId, name: other.name),
    meUserId: meAdult.localId,
  );
}
