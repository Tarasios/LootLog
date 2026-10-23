/// The adventure-skin adapter: a pure `HouseholdState -> DungeonState` projection.
///
/// This is the ONLY bridge between the domain and the game. The domain has zero
/// game knowledge; the adventure widgets read only [DungeonState]. Every monetary
/// number is copied verbatim from the reducer's read-model — the skin never
/// re-derives balances, limits, or leftovers.
///
/// Pure Dart (Flutter-free), so it is unit-tested exactly like the reducer.
library;

import '../domain/event.dart';
import '../domain/money.dart';
import '../domain/state.dart';
import '../domain/time.dart';
import '../domain/value_types.dart';
import '../ui/format.dart';
import 'dungeon_state.dart';

/// Default sprite strips (see `docs/art-assets.md`). Kept here so the mapping
/// and the widgets agree on names without a shared magic-string soup.
abstract final class Sprites {
  static const heroA = 'hero_a_idle_4f.png';
  static const heroB = 'hero_b_idle_4f.png';
  static const monster = 'monster_idle_4f.png';
  static const monsterEnraged = 'monster_enraged_4f.png';
  static const overbudget = 'overbudget_idle_4f.png';
  static const pet = 'pet_idle_4f.png';
  static const questMonster = 'quest_monster_4f.png';
  static const goldPouch = 'gold_pouch_1f.png';
  static const warChest = 'war_chest_1f.png';
  static const reserveCache = 'reserve_cache_1f.png';
  static const coin = 'coin_spin_6f.png';
  static const trophy = 'trophy_1f.png';
  static const campfire = 'campfire_idle_4f.png';
}

/// Builds the adventure [DungeonState] for [meUserId] as of [asOf] (now by
/// default). [userNames] maps user ids to display names.
DungeonState buildDungeonState(
  HouseholdState state, {
  required String meUserId,
  required Map<String, String> userNames,
  DateTime? asOf,
  bool includeOtherAdults = true,
}) {
  final now = (asOf ?? DateTime.now()).toUtc();
  final month = Month.fromInstant(now);

  String? nameOf(String id) => state.members[id]?.name ?? userNames[id];
  String? petNameOf(String? id) => id == null ? null : state.pets[id]?.name;

  // ---- Dungeon floor number (counted from the earliest event month) -------
  final firstMonth = _earliestMonth(state) ?? month;
  final floorNumber = _monthsBetween(firstMonth, month) + 1;

  // ---- Hero & companion avatars (every other active adult) ---------------
  final heroSprite =
      _memberSprite(state, meUserId, Sprites.heroA, nameOf(meUserId) ?? 'You');
  final companionIds = state.adultIds.where((adultId) => adultId != meUserId).toList()
    ..sort((first, second) => (nameOf(first) ?? first).compareTo(nameOf(second) ?? second));
  final companionSprites = [
    for (final id in companionIds)
      _memberSprite(state, id, Sprites.heroB, nameOf(id) ?? 'Companion'),
  ];

  // ---- Monsters (personal slices) & contracts (group slices) -------------
  // Pet-linked ones are set aside to hang under their party member.
  final looseMonsters = <Monster>[];
  final looseContracts = <PartyContract>[];
  final petMonsters = <String, List<Monster>>{};
  final petContracts = <String, List<PartyContract>>{};
  var heroHpLost = 0;

  for (final cfg in state.slices.values) {
    if (cfg.createdMonth.isAfter(month)) continue;
    // Visibility toggle: another adult's personal monsters stay off this
    // device's floor (party contracts and everything shared always render).
    if (!includeOtherAdults &&
        !cfg.isGroup &&
        cfg.ownerUserId != meUserId) {
      continue;
    }
    final sliceMonth = state.sliceMonth(cfg.sliceId, month);
    final maxHp = sliceMonth?.effectiveLimitCents ?? cfg.baseEffectiveLimitCents;
    final damage = sliceMonth?.spentCents ?? 0;
    final excess = sliceMonth?.overspendCents ?? 0;
    heroHpLost += excess;

    // A category owned by pets anchors under its first owning pet; the legacy
    // single-pet link keeps working.
    final petAnchor = cfg.petId ??
        (cfg.petOwnerIds.isNotEmpty ? cfg.petOwnerIds.first : null);
    if (cfg.isGroup) {
      final petNames = [
        for (final id in cfg.petOwnerIds)
          if (petNameOf(id) != null) petNameOf(id)!,
      ];
      final contract = PartyContract(
        sliceId: cfg.sliceId,
        name: cfg.name,
        maxHpCents: maxHp,
        damageCents: damage,
        excessCents: excess,
        petName: petNames.isNotEmpty ? petNames.join(' & ') : petNameOf(petAnchor),
      );
      if (petAnchor != null) {
        (petContracts[petAnchor] ??= []).add(contract);
      } else {
        looseContracts.add(contract);
      }
    } else {
      final mine = cfg.ownerUserId == meUserId;
      final monster = Monster(
        sliceId: cfg.sliceId,
        name: cfg.name,
        sprite: SpriteRef.asset(
          excess > 0 ? Sprites.monsterEnraged : Sprites.monster,
          label: cfg.name,
        ),
        maxHpCents: maxHp,
        damageCents: damage,
        excessCents: excess,
        mine: mine,
        ownerName: nameOf(cfg.ownerUserId ?? ''),
      );
      if (petAnchor != null) {
        (petMonsters[petAnchor] ??= []).add(monster);
      } else {
        looseMonsters.add(monster);
      }
    }
  }

  int monsterRank(Monster monster) => monster.mine ? 0 : 1;
  looseMonsters.sort((first, second) {
    final comparison = monsterRank(first).compareTo(monsterRank(second));
    return comparison != 0 ? comparison : first.name.compareTo(second.name);
  });
  looseContracts.sort((first, second) => first.name.compareTo(second.name));

  // ---- OVERBUDGET debt monsters (outstanding only, mine first) ------------
  final overbudgets = <OverbudgetMonster>[
    for (final debt in state.outstandingOverbudgets)
      if (includeOtherAdults || debt.ownerUserId == meUserId)
        OverbudgetMonster(
        sliceId: debt.sliceId,
        categoryName: state.slices[debt.sliceId]?.name ?? debt.sliceId,
        sprite: SpriteRef.asset(
          Sprites.overbudget,
          label: 'OVERBUDGET — ${state.slices[debt.sliceId]?.name ?? debt.sliceId}',
        ),
        accruedCents: debt.accruedCents,
        outstandingCents: debt.outstandingCents,
        mine: debt.ownerUserId == meUserId,
        ownerName: nameOf(debt.ownerUserId),
        mainCategoryId: state.slices[debt.sliceId]?.mainCategoryId,
      ),
  ]..sort((first, second) {
      final comparison = (first.mine ? 0 : 1).compareTo(second.mine ? 0 : 1);
      return comparison != 0 ? comparison : first.categoryName.compareTo(second.categoryName);
    });

  // ---- Reserve caches (emergency funds), pet-linked ones set aside -------
  final looseCaches = <ReserveCache>[];
  final petCaches = <String, List<ReserveCache>>{};
  for (final fund in state.emergencyFunds.values) {
    final cache = ReserveCache(
      fundId: fund.fundId,
      name: fund.name,
      sprite: SpriteRef.asset(Sprites.reserveCache, label: fund.name),
      balanceCents: fund.balanceCents,
      petName: petNameOf(fund.petId),
    );
    if (fund.petId != null) {
      (petCaches[fund.petId!] ??= []).add(cache);
    } else {
      looseCaches.add(cache);
    }
  }
  looseCaches.sort((first, second) => first.name.compareTo(second.name));

  // ---- Party members (pets) ----------------------------------------------
  final party = <PartyMember>[
    for (final pet in state.pets.values)
      PartyMember(
        petId: pet.petId,
        name: pet.name,
        sprite: pet.customSpriteSha256 != null
            ? SpriteRef.custom(pet.customSpriteSha256, label: pet.name)
            : SpriteRef.asset(Sprites.pet, label: pet.name),
        monsters: (petMonsters[pet.petId] ?? [])
          ..sort((first, second) => first.name.compareTo(second.name)),
        contracts: (petContracts[pet.petId] ?? [])
          ..sort((first, second) => first.name.compareTo(second.name)),
        reserveCaches: (petCaches[pet.petId] ?? [])
          ..sort((first, second) => first.name.compareTo(second.name)),
      ),
  ]..sort((first, second) => first.name.compareTo(second.name));

  // ---- Party roster (all active members, me first) -----------------------
  // Derived from MemberSet state — never from device-local setup — so any
  // household size renders. Adults, then dependents, then pets; me leads.
  final roster = <Adventurer>[
    for (final member in state.members.values)
      if (member.active)
        Adventurer(
          memberId: member.memberId,
          name: member.name,
          role: _roleOf(member.role),
          descriptionText: member.descriptionText,
          isMe: member.memberId == meUserId,
          sprite: member.customSpriteSha256 != null
              ? SpriteRef.custom(member.customSpriteSha256, label: member.name)
              : SpriteRef.asset(_rosterAsset(member.role), label: member.name),
        ),
  ]..sort(_rosterOrder(meUserId));

  // ---- Quest monsters -----------------------------------------------------
  final questMonsters = <QuestMonster>[];
  for (final quest in state.quests.values) {
    if (quest.abandoned) continue;
    final contributors = <Contributor>[
      for (final entry in quest.contributions.entries)
        if (entry.value != 0)
          Contributor(name: nameOf(entry.key) ?? 'Someone', cents: entry.value),
    ]..sort((first, second) => second.cents.compareTo(first.cents));
    questMonsters.add(QuestMonster(
      questId: quest.questId,
      name: quest.name,
      sprite: quest.customSpriteSha256 != null
          ? SpriteRef.custom(quest.customSpriteSha256, label: quest.name)
          : SpriteRef.asset(Sprites.questMonster, label: quest.name),
      targetCents: quest.targetCents,
      contributedCents: quest.totalContributedCents,
      balanceCents: quest.balanceCents,
      completed: quest.completed,
      shared: quest.ownership is SharedParty,
      contributors: contributors,
      mainCategoryId: quest.mainCategoryId,
      descriptionText: quest.descriptionText,
    ));
  }
  questMonsters.sort((first, second) {
    final comparison = (first.completed ? 1 : 0).compareTo(second.completed ? 1 : 0);
    return comparison != 0 ? comparison : first.name.compareTo(second.name);
  });

  // ---- Provisioning (recurring expenses + emergency contributions) -------
  final provisioning = <ProvisionLine>[];
  final closed = month.prev();
  final localNow = now.add(vancouverUtcOffset(now));
  for (final expense in state.recurringExpenses.values) {
    final activeNow = expense.activeIn(month);
    final activeClosed = expense.activeIn(closed);
    if (!activeNow && !activeClosed) continue;
    final actualThis = state.variableActualFor(expense.expenseId, month);
    // An annual contract's floor charge is its 1/12 accrual; the full bill is
    // its face value.
    final amount = expense.isAnnual
        ? expense.amountCents ~/ 12
        : (expense.kind == RecurringKind.variable
            ? (actualThis ?? expense.amountCents)
            : expense.amountCents);
    final awaiting = expense.kind == RecurringKind.variable &&
        activeClosed &&
        state.variableActualFor(expense.expenseId, closed) == null;
    provisioning.add(ProvisionLine(
      name: expense.name,
      kind: expense.kind == RecurringKind.variable
          ? ProvisionKind.variableMaintenance
          : ProvisionKind.fixedMaintenance,
      amountCents: amount,
      shared: expense.isShared,
      awaitingTally: awaiting,
      ownerName: expense.ownerUserId == null ? null : nameOf(expense.ownerUserId!),
      isAnnualContract: expense.isAnnual,
      contractTotalCents: expense.isAnnual ? expense.amountCents : null,
      dueDay: expense.isAnnual ? expense.dueDay : null,
      dueMonth: expense.isAnnual ? expense.dueMonth : null,
      daysUntilDue: expense.isAnnual ? expense.daysUntilDue(localNow) : null,
    ));
  }
  // Emergency-fund contributions designated on slices are provisioning too.
  final emergencyByFund = <String, int>{};
  for (final cfg in state.slices.values) {
    if (cfg.createdMonth.isAfter(month)) continue;
    if (cfg.emergencyFundId == null || cfg.emergencyContributionCents <= 0) {
      continue;
    }
    emergencyByFund[cfg.emergencyFundId!] =
        (emergencyByFund[cfg.emergencyFundId!] ?? 0) +
            cfg.emergencyContributionCents;
  }
  for (final entry in emergencyByFund.entries) {
    provisioning.add(ProvisionLine(
      name: state.emergencyFunds[entry.key]?.name ?? 'Reserve',
      kind: ProvisionKind.emergencyProvision,
      amountCents: entry.value,
      shared: true,
      awaitingTally: false,
    ));
  }
  provisioning.sort((first, second) => first.name.compareTo(second.name));

  // ---- Gold pouch (vault) + projected minting ----------------------------
  var projMint = 0;
  for (final cfg in state.slices.values) {
    if (cfg.isGroup || cfg.ownerUserId != meUserId) continue;
    final sliceMonth = state.sliceMonth(cfg.sliceId, month);
    final leftover = sliceMonth?.leftoverCents ?? 0;
    if (leftover <= 0) continue;
    projMint += Money.titheCents(leftover, cfg.poolTithePct).remainderCents;
  }
  final goldPouch = GoldPouch(
    balanceCents: state.vaultOf(meUserId),
    clampedFlag: state.isVaultInconsistent(meUserId),
    projectedMintCents: projMint,
  );

  // ---- War chest: writs + ransacks + goal --------------------------------
  final writsForMe = <Writ>[];
  final writsForOther = <Writ>[];
  for (final withdrawal in state.withdrawals.values) {
    if (withdrawal.status != WithdrawalStatus.pending) continue;
    final needsMe = withdrawal.byUserId != meUserId;
    final writ = Writ(
      proposalId: withdrawal.proposalId,
      byName: nameOf(withdrawal.byUserId) ?? 'Someone',
      amountCents: withdrawal.amountCents,
      purpose: withdrawal.purpose,
      destinationLabel: switch (withdrawal.destination) {
        UserVaultDestination(:final userId) =>
          '${nameOf(userId) ?? 'a'} pouch',
        ExternalDestination() => 'beyond the walls',
      },
      needsMySignature: needsMe,
    );
    (needsMe ? writsForMe : writsForOther).add(writ);
  }
  final ransacks = <RansackBanner>[
    for (final ransack in state.ransacks)
      RansackBanner(
        cacheName: state.emergencyFunds[ransack.fundId]?.name ?? 'a reserve cache',
        excessCents: ransack.excessCents,
        purpose: ransack.purpose,
        occurredAt: ransack.occurredAt,
      ),
  ]..sort((first, second) => second.occurredAt.compareTo(first.occurredAt));
  final loans = <GuildLoan>[
    for (final advance in state.advances.values)
      if (advance.status == WithdrawalStatus.pending)
        GuildLoan(
          advanceId: advance.advanceId,
          byName: nameOf(advance.byUserId) ?? 'Someone',
          monsterName: state.slices[advance.sliceId]?.name ?? 'a monster',
          amountCents: advance.amountCents,
          months: advance.months,
          needsMySeal: advance.byUserId != meUserId,
        ),
  ]..sort((first, second) {
      final comparison = (first.needsMySeal ? 0 : 1).compareTo(second.needsMySeal ? 0 : 1);
      return comparison != 0 ? comparison : first.advanceId.compareTo(second.advanceId);
    });
  final goal = state.warChest.goal;
  final warChest = WarChest(
    balanceCents: state.warChest.balanceCents,
    targetCents: state.warChest.targetCents,
    pctComplete: goal?.pctComplete,
    estMonthsRemaining: goal?.estMonthsRemaining,
    writsForMe: writsForMe,
    writsForOther: writsForOther,
    ransacks: ransacks,
    loans: loans,
  );

  // ---- Expeditions abroad (open vacation side-floors) --------------------
  final expeditions = <ExpeditionFloor>[
    for (final vacation in state.openVacations)
      ExpeditionFloor(
        vacationId: vacation.vacationId,
        name: vacation.name,
        totalBudgetCents: vacation.totalLimitCents,
        totalSpentCents: vacation.totalSpentCents,
        totalOverspendCents: vacation.totalOverspendCents,
        daysRemaining: vacation.daysRemaining,
        dailyAllowanceRemainingCents: vacation.dailyAllowanceRemainingCents,
        fundBalanceCents: vacation.fundBalanceCents,
        rings: [
          for (final category in vacation.categories)
            ExpeditionRing(
              name: category.name,
              budgetCents: category.limitCents,
              spentCents: category.spentCents,
              overspendCents: category.overspendCents,
            ),
        ],
      ),
  ];

  return DungeonState(
    currentMonth: month,
    floorNumber: floorNumber,
    heroName: nameOf(meUserId) ?? 'You',
    heroSprite: heroSprite,
    companionSprites: companionSprites,
    heroHpLostCents: heroHpLost,
    expeditionSuppliesCents: state.incomeFor(meUserId, month),
    monsters: looseMonsters,
    contracts: looseContracts,
    overbudgets: overbudgets,
    party: party,
    questMonsters: questMonsters,
    provisioning: provisioning,
    goldPouch: goldPouch,
    warChest: warChest,
    reserveCaches: looseCaches,
    roster: roster,
    expeditions: expeditions,
  );
}

/// The party-frame sprite for a member: their uploaded custom sprite when one
/// is set, else the role's default asset.
SpriteRef _memberSprite(
    HouseholdState state, String userId, String fallbackAsset, String label) {
  final sha = state.members[userId]?.customSpriteSha256;
  return sha != null
      ? SpriteRef.custom(sha, label: label)
      : SpriteRef.asset(fallbackAsset, label: label);
}

AdventurerRole _roleOf(MemberRole role) => switch (role) {
      MemberRole.adult => AdventurerRole.adventurer,
      MemberRole.dependent => AdventurerRole.companion,
      MemberRole.pet => AdventurerRole.familiar,
    };

String _rosterAsset(MemberRole role) => switch (role) {
      MemberRole.adult => Sprites.heroA,
      MemberRole.dependent => Sprites.heroB,
      MemberRole.pet => Sprites.pet,
    };

/// Orders the roster: the device owner first, then by role (adults, dependents,
/// pets), then by name — a stable party line-up.
int Function(Adventurer, Adventurer) _rosterOrder(String meUserId) =>
    (first, second) {
      final firstRank = first.isMe ? 0 : 1;
      final secondRank = second.isMe ? 0 : 1;
      if (firstRank != secondRank) return firstRank - secondRank;
      if (first.role != second.role) return first.role.index - second.role.index;
      return first.name.compareTo(second.name);
    };

/// The scrolling adventure log: real events narrated in game voice, newest
/// first. A pure projection — it re-tells what happened and never computes a
/// balance. Ransacks (a derived read-model record) are folded in as their own
/// loud banners. Cosmetic and purely-configurational events stay silent.
List<LogEntry> buildAdventureLog(
  HouseholdState state,
  List<Event> events, {
  required String meUserId,
  required Map<String, String> userNames,
  int limit = 40,
}) {
  String who(String id) => userNames[id] ?? 'Someone';
  String sliceName(String id) => state.slices[id]?.name ?? 'a monster';
  String questName(String id) => state.quests[id]?.name ?? 'a quest boss';
  String fundName(String id) => state.emergencyFunds[id]?.name ?? 'a reserve';
  String vacationName(String id) => state.vacations[id]?.name ?? 'an expedition';

  final entries = <LogEntry>[];

  String purchaseLine(PurchaseAdded purchase) => switch (purchase.target) {
        SliceCharge(:final sliceId) =>
          '${sliceName(sliceId).toUpperCase()} MONSTER TAKES '
              '${money(purchase.amountCents)} DMG',
        VaultCharge() =>
          '${who(purchase.userId)} spends ${money(purchase.amountCents)} from the gold pouch',
        QuestCharge(:final questId) =>
          '${who(purchase.userId)} claims ${money(purchase.amountCents)} from the '
              '${questName(questId)} hoard',
        EmergencyCharge(:final fundId) =>
          '${who(purchase.userId)} breaks open the ${fundName(fundId)} cache for '
              '${money(purchase.amountCents)}',
        VacationCharge(:final vacationId) =>
          '${who(purchase.userId)} spends ${money(purchase.amountCents)} on the '
              '${vacationName(vacationId)} expedition',
      };

  for (final event in events) {
    final mine = event.userId == meUserId;
    LogEntry? entry;
    LogEntry make(String line, LogTone tone, {bool? isMine}) => LogEntry(
          id: event.eventId,
          line: line,
          tone: tone,
          occurredAt: event.occurredAt,
          isMine: isMine ?? mine,
        );
    switch (event) {
      case PurchaseAdded():
        entry = make(purchaseLine(event), LogTone.strike);
      case GiftReceived():
        entry = make(
          'TREASURE FOUND — ${money(event.amountCents)} for ${who(event.forUserId)}',
          LogTone.treasure,
          isMine: event.forUserId == meUserId,
        );
      case IncomeSet():
        entry = make(
          'SUPPLIES ARRIVE — ${money(event.amountCents)} for ${who(event.forUserId)}',
          LogTone.supplies,
          isMine: event.forUserId == meUserId,
        );
      case DefaultIncomeSet():
        entry = make(
          'Standing supplies set for ${who(event.forUserId)} — '
              '${money(event.amountCents)} a floor',
          LogTone.supplies,
          isMine: event.forUserId == meUserId,
        );
      case QuestSet():
        entry = make(
          'A quest boss appears: ${event.name} (${money(event.targetCents)} HP)',
          LogTone.quest,
        );
      case QuestAbandoned():
        entry = make(
          'The hunt for ${questName(event.questId)} is called off',
          LogTone.quest,
        );
      case LeftoverAllocated():
        // One game-voice beat per destination the spoils went to — the log
        // narrates the ritual's outcome, it never re-computes it. Amounts are
        // the event's own gross figures (tithes are the spoils sheet's story).
        final src = sliceName(event.sliceId).toUpperCase();
        final mineAlloc = event.forUserId == meUserId;
        var i = 0;
        for (final allocation in event.allocations) {
          i++;
          if (allocation.amountCents <= 0) continue;
          final (line, tone) = switch (allocation.destination) {
            QuestDestination(:final questId) => (
                '${who(event.forUserId)} hurls ${money(allocation.amountCents)} of $src '
                    'loot at the ${questName(questId).toUpperCase()} '
                    'quest boss',
                LogTone.quest,
              ),
            CarryInSlice() => (
                '${who(event.forUserId)} banks ${money(allocation.amountCents)} in $src '
                    'for the next floor',
                LogTone.ritual,
              ),
            Discretionary() => (
                '${who(event.forUserId)} pockets ${money(allocation.amountCents)} of '
                    '$src loot',
                LogTone.ritual,
              ),
            OverbudgetPayment(:final sliceId) => (
                '${who(event.forUserId)} strikes the '
                    '${sliceName(sliceId).toUpperCase()} OVERBUDGET with '
                    '${money(allocation.amountCents)} of $src loot',
                LogTone.strike,
              ),
          };
          entries.add(LogEntry(
            id: '${event.eventId}#$i',
            line: line,
            tone: tone,
            occurredAt: event.occurredAt,
            isMine: mineAlloc,
          ));
        }
        if (event.allocations.every((allocation) => allocation.amountCents <= 0)) {
          entry = make(
            '${who(event.forUserId)} divides the spoils of ${sliceName(event.sliceId)}',
            LogTone.ritual,
            isMine: mineAlloc,
          );
        }
      case PoolContributionMade():
        entry = make(
          '${who(event.fromUserId)} feeds the war chest ${money(event.amountCents)}',
          LogTone.chest,
          isMine: event.fromUserId == meUserId,
        );
      case TaxRefundRecorded():
        entry = make(
          'A royal rebate reaches the war chest: ${money(event.amountCents)}',
          LogTone.chest,
        );
      case PoolWithdrawalProposed():
        entry = make(
          '${who(event.byUserId)} raises a writ for ${money(event.amountCents)}',
          LogTone.writ,
          isMine: event.byUserId == meUserId,
        );
      case PoolWithdrawalApproved():
        entry = make('${who(event.byUserId)} signs a writ', LogTone.writ,
            isMine: event.byUserId == meUserId);
      case PoolWithdrawalCancelled():
        entry = make('${who(event.userId)} withdraws a writ', LogTone.writ);
      case MemberSet():
        entry = make(
          event.active
              ? '${event.name} joins the party'
              : '${event.name} leaves the party',
          LogTone.muster,
        );
      case PetSet():
        entry = make('${event.name} joins the party', LogTone.muster);
      // Silent: voids, receipts, goals, accounts, settings, cosmetics, tallies,
      // shares, main categories, vacations, budget/recurring/fund config.
      case PurchaseVoided():
      case ReceiptAttached():
      case ReceiptDetached():
      case GoalSet():
      case GroupShareSet():
      case TrackedAccountSet():
      case AccountBalanceRecorded():
      case AccountTransferRecorded():
      case SettingChanged():
      case CosmeticSet():
      case GameRewardGranted():
      case NoSpendCheckedIn():
      case ReconcileCompleted():
      case UnknownEvent():
      case ShortfallCovered():
      case AllowanceAdvanceProposed():
      case AllowanceAdvanceApproved():
      case AllowanceAdvanceCancelled():
      case VariableExpenseRecorded():
      case MainCategorySet():
      case VacationSet():
      case VacationClosed():
      case BudgetSliceSet():
      case RecurringExpenseSet():
      case EmergencyFundSet():
        entry = null;
    }
    if (entry != null) entries.add(entry);
  }

  // Ransacks are a derived record, not an event — fold them in loudly.
  for (final ransack in state.ransacks) {
    entries.add(LogEntry(
      id: 'ransack-${ransack.fundId}-${ransack.occurredAt.toIso8601String()}',
      line: 'THE WAR CHEST WAS RANSACKED! ${money(ransack.excessCents)} taken to '
          'cover the ${state.emergencyFunds[ransack.fundId]?.name ?? 'reserve'} '
          '(${ransack.purpose})',
      tone: LogTone.ransack,
      occurredAt: ransack.occurredAt,
      isMine: false,
    ));
  }

  entries.sort((first, second) {
    final comparison = second.occurredAt.compareTo(first.occurredAt);
    return comparison != 0 ? comparison : second.id.compareTo(first.id);
  });
  return entries.length > limit ? entries.sublist(0, limit) : entries;
}

/// Whole months from [from] to [to] (may be negative if [to] precedes [from]).
int _monthsBetween(Month from, Month to) =>
    (to.year - from.year) * 12 + (to.month - from.month);

/// The earliest month any activity is keyed to, used to number the floor.
/// Scans everything the read-model exposes a month for; null when empty.
Month? _earliestMonth(HouseholdState state) {
  Month? earliest;
  void consider(Month month) {
    if (earliest == null || month.isBefore(earliest!)) earliest = month;
  }

  for (final cfg in state.slices.values) {
    consider(cfg.createdMonth);
  }
  for (final sliceMonth in state.sliceMonths.values) {
    consider(sliceMonth.month);
  }
  for (final expense in state.recurringExpenses.values) {
    consider(expense.startMonth);
  }
  for (final purchase in state.purchases.values) {
    consider(purchase.month);
  }
  for (final key in state.incomeByUserMonth.keys) {
    consider(Month.parse(key.split('|').last));
  }
  return earliest;
}
