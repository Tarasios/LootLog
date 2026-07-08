/// The adventure-skin adapter: a pure `HouseholdState -> GameState` projection.
///
/// This is the ONLY bridge between the domain and the game. The domain has zero
/// game knowledge; the adventure widgets read only [GameState]. Every monetary
/// number is copied verbatim from the reducer's read-model — the skin never
/// re-derives balances, limits, or leftovers.
///
/// Pure Dart (Flutter-free), so it is unit-tested exactly like the reducer.
library;

import '../domain/money.dart';
import '../domain/state.dart';
import '../domain/time.dart';
import '../domain/value_types.dart';
import 'game_state.dart';

/// Default sprite strips (see `docs/art-assets.md`). Kept here so the mapping
/// and the widgets agree on names without a shared magic-string soup.
abstract final class Sprites {
  static const heroA = 'hero_a_idle_4f.png';
  static const heroB = 'hero_b_idle_4f.png';
  static const monster = 'monster_idle_4f.png';
  static const monsterEnraged = 'monster_enraged_4f.png';
  static const pet = 'pet_idle_4f.png';
  static const questMonster = 'quest_monster_4f.png';
  static const goldPouch = 'gold_pouch_1f.png';
  static const warChest = 'war_chest_1f.png';
  static const reserveCache = 'reserve_cache_1f.png';
}

/// Builds the adventure [GameState] for [meUserId] as of [asOf] (now by
/// default). [userNames] maps user ids to display names.
GameState buildGameState(
  HouseholdState state, {
  required String meUserId,
  required Map<String, String> userNames,
  DateTime? asOf,
}) {
  final now = (asOf ?? DateTime.now()).toUtc();
  final month = Month.fromInstant(now);

  String? nameOf(String id) => userNames[id];
  String? petNameOf(String? id) => id == null ? null : state.pets[id]?.name;

  // ---- Dungeon floor number (counted from the earliest event month) -------
  final firstMonth = _earliestMonth(state) ?? month;
  final floorNumber = _monthsBetween(firstMonth, month) + 1;

  // ---- Hero / partner avatars --------------------------------------------
  final partnerId =
      state.userIds.firstWhere((u) => u != meUserId, orElse: () => meUserId);
  final heroSprite =
      SpriteRef.asset(Sprites.heroA, label: nameOf(meUserId) ?? 'You');
  final partnerSprite =
      SpriteRef.asset(Sprites.heroB, label: nameOf(partnerId) ?? 'Partner');

  // ---- Monsters (personal slices) & contracts (group slices) -------------
  // Pet-linked ones are set aside to hang under their party member.
  final looseMonsters = <Monster>[];
  final looseContracts = <PartyContract>[];
  final petMonsters = <String, List<Monster>>{};
  final petContracts = <String, List<PartyContract>>{};
  var heroHpLost = 0;

  for (final cfg in state.slices.values) {
    if (cfg.createdMonth.isAfter(month)) continue;
    final sm = state.sliceMonth(cfg.sliceId, month);
    final maxHp = sm?.effectiveLimitCents ?? cfg.baseEffectiveLimitCents;
    final damage = sm?.spentCents ?? 0;
    final excess = sm?.overspendCents ?? 0;
    heroHpLost += excess;

    if (cfg.isGroup) {
      final contract = PartyContract(
        sliceId: cfg.sliceId,
        name: cfg.name,
        maxHpCents: maxHp,
        damageCents: damage,
        excessCents: excess,
        petName: petNameOf(cfg.petId),
      );
      if (cfg.petId != null) {
        (petContracts[cfg.petId!] ??= []).add(contract);
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
      if (cfg.petId != null) {
        (petMonsters[cfg.petId!] ??= []).add(monster);
      } else {
        looseMonsters.add(monster);
      }
    }
  }

  int monsterRank(Monster m) => m.mine ? 0 : 1;
  looseMonsters.sort((a, b) {
    final c = monsterRank(a).compareTo(monsterRank(b));
    return c != 0 ? c : a.name.compareTo(b.name);
  });
  looseContracts.sort((a, b) => a.name.compareTo(b.name));

  // ---- Reserve caches (emergency funds), pet-linked ones set aside -------
  final looseCaches = <ReserveCache>[];
  final petCaches = <String, List<ReserveCache>>{};
  for (final f in state.emergencyFunds.values) {
    final cache = ReserveCache(
      fundId: f.fundId,
      name: f.name,
      sprite: SpriteRef.asset(Sprites.reserveCache, label: f.name),
      balanceCents: f.balanceCents,
      petName: petNameOf(f.petId),
    );
    if (f.petId != null) {
      (petCaches[f.petId!] ??= []).add(cache);
    } else {
      looseCaches.add(cache);
    }
  }
  looseCaches.sort((a, b) => a.name.compareTo(b.name));

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
          ..sort((a, b) => a.name.compareTo(b.name)),
        contracts: (petContracts[pet.petId] ?? [])
          ..sort((a, b) => a.name.compareTo(b.name)),
        reserveCaches: (petCaches[pet.petId] ?? [])
          ..sort((a, b) => a.name.compareTo(b.name)),
      ),
  ]..sort((a, b) => a.name.compareTo(b.name));

  // ---- Quest monsters -----------------------------------------------------
  final questMonsters = <QuestMonster>[];
  for (final q in state.quests.values) {
    if (q.abandoned) continue;
    final contributors = <Contributor>[
      for (final e in q.contributions.entries)
        if (e.value != 0)
          Contributor(name: nameOf(e.key) ?? 'Someone', cents: e.value),
    ]..sort((a, b) => b.cents.compareTo(a.cents));
    questMonsters.add(QuestMonster(
      questId: q.questId,
      name: q.name,
      sprite: q.customSpriteSha256 != null
          ? SpriteRef.custom(q.customSpriteSha256, label: q.name)
          : SpriteRef.asset(Sprites.questMonster, label: q.name),
      targetCents: q.targetCents,
      contributedCents: q.totalContributedCents,
      balanceCents: q.balanceCents,
      completed: q.completed,
      shared: q.ownership is SharedParty,
      contributors: contributors,
    ));
  }
  questMonsters.sort((a, b) {
    final c = (a.completed ? 1 : 0).compareTo(b.completed ? 1 : 0);
    return c != 0 ? c : a.name.compareTo(b.name);
  });

  // ---- Provisioning (recurring expenses + emergency contributions) -------
  final provisioning = <ProvisionLine>[];
  final closed = month.prev();
  final localNow = now.add(vancouverUtcOffset(now));
  for (final r in state.recurringExpenses.values) {
    final activeNow = r.activeIn(month);
    final activeClosed = r.activeIn(closed);
    if (!activeNow && !activeClosed) continue;
    final actualThis = state.variableActualFor(r.expenseId, month);
    // An annual contract's floor charge is its 1/12 accrual; the full bill is
    // its face value.
    final amount = r.isAnnual
        ? r.amountCents ~/ 12
        : (r.kind == RecurringKind.variable
            ? (actualThis ?? r.amountCents)
            : r.amountCents);
    final awaiting = r.kind == RecurringKind.variable &&
        activeClosed &&
        state.variableActualFor(r.expenseId, closed) == null;
    provisioning.add(ProvisionLine(
      name: r.name,
      kind: r.kind == RecurringKind.variable
          ? ProvisionKind.variableMaintenance
          : ProvisionKind.fixedMaintenance,
      amountCents: amount,
      shared: r.isShared,
      awaitingTally: awaiting,
      ownerName: r.ownerUserId == null ? null : nameOf(r.ownerUserId!),
      isAnnualContract: r.isAnnual,
      contractTotalCents: r.isAnnual ? r.amountCents : null,
      dueDay: r.isAnnual ? r.dueDay : null,
      dueMonth: r.isAnnual ? r.dueMonth : null,
      daysUntilDue: r.isAnnual ? r.daysUntilDue(localNow) : null,
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
  for (final e in emergencyByFund.entries) {
    provisioning.add(ProvisionLine(
      name: state.emergencyFunds[e.key]?.name ?? 'Reserve',
      kind: ProvisionKind.emergencyProvision,
      amountCents: e.value,
      shared: true,
      awaitingTally: false,
    ));
  }
  provisioning.sort((a, b) => a.name.compareTo(b.name));

  // ---- Gold pouch (vault) + projected minting ----------------------------
  var projMint = 0;
  for (final cfg in state.slices.values) {
    if (cfg.isGroup || cfg.ownerUserId != meUserId) continue;
    final sm = state.sliceMonth(cfg.sliceId, month);
    final leftover = sm?.leftoverCents ?? 0;
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
  for (final w in state.withdrawals.values) {
    if (w.status != WithdrawalStatus.pending) continue;
    final needsMe = w.byUserId != meUserId;
    final writ = Writ(
      proposalId: w.proposalId,
      byName: nameOf(w.byUserId) ?? 'Someone',
      amountCents: w.amountCents,
      purpose: w.purpose,
      destinationLabel: switch (w.destination) {
        UserVaultDestination(:final userId) =>
          '${nameOf(userId) ?? 'a'} pouch',
        ExternalDestination() => 'beyond the walls',
      },
      needsMySignature: needsMe,
    );
    (needsMe ? writsForMe : writsForOther).add(writ);
  }
  final ransacks = <RansackBanner>[
    for (final r in state.ransacks)
      RansackBanner(
        cacheName: state.emergencyFunds[r.fundId]?.name ?? 'a reserve cache',
        excessCents: r.excessCents,
        purpose: r.purpose,
        occurredAt: r.occurredAt,
      ),
  ]..sort((a, b) => b.occurredAt.compareTo(a.occurredAt));
  final goal = state.warChest.goal;
  final warChest = WarChest(
    balanceCents: state.warChest.balanceCents,
    targetCents: state.warChest.targetCents,
    pctComplete: goal?.pctComplete,
    estMonthsRemaining: goal?.estMonthsRemaining,
    writsForMe: writsForMe,
    writsForOther: writsForOther,
    ransacks: ransacks,
  );

  return GameState(
    currentMonth: month,
    floorNumber: floorNumber,
    heroName: nameOf(meUserId) ?? 'You',
    heroSprite: heroSprite,
    partnerSprite: partnerSprite,
    heroHpLostCents: heroHpLost,
    expeditionSuppliesCents: state.incomeFor(meUserId, month),
    monsters: looseMonsters,
    contracts: looseContracts,
    party: party,
    questMonsters: questMonsters,
    provisioning: provisioning,
    goldPouch: goldPouch,
    warChest: warChest,
    reserveCaches: looseCaches,
  );
}

/// Whole months from [a] to [b] (may be negative if [b] precedes [a]).
int _monthsBetween(Month a, Month b) =>
    (b.year - a.year) * 12 + (b.month - a.month);

/// The earliest month any activity is keyed to, used to number the floor.
/// Scans everything the read-model exposes a month for; null when empty.
Month? _earliestMonth(HouseholdState state) {
  Month? earliest;
  void consider(Month m) {
    if (earliest == null || m.isBefore(earliest!)) earliest = m;
  }

  for (final cfg in state.slices.values) {
    consider(cfg.createdMonth);
  }
  for (final sm in state.sliceMonths.values) {
    consider(sm.month);
  }
  for (final r in state.recurringExpenses.values) {
    consider(r.startMonth);
  }
  for (final p in state.purchases.values) {
    consider(p.month);
  }
  for (final key in state.incomeByUserMonth.keys) {
    consider(Month.parse(key.split('|').last));
  }
  return earliest;
}
