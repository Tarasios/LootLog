/// `GameState` and its parts: the adventure skin's read-model. The adapter
/// (`adapter.dart`) maps the domain's [HouseholdState] into this shape; the
/// adventure widgets render only from here. Nothing in the domain knows this
/// file exists, and nothing here computes money — every number is copied
/// straight from the reducer's output.
///
/// Pure Dart, zero Flutter imports (so it is unit-testable like the domain).
library;

import '../domain/time.dart';

/// The sprite a widget should try to draw. Either a named sprite-sheet strip
/// from `assets/game/` (with a parsed frame count) or a single-frame custom
/// blob referenced by its content-addressed sha256. The [label] is what the
/// grey placeholder shows when the art is missing.
class SpriteRef {
  const SpriteRef.asset(this.assetName, {required this.label})
      : customSpriteSha256 = null;

  const SpriteRef.custom(this.customSpriteSha256, {required this.label})
      : assetName = null;

  /// A named strip in `assets/game/`, e.g. `monster_idle_4f.png`.
  final String? assetName;

  /// A single-frame custom sprite blob (quest / pet / avatar), or null.
  final String? customSpriteSha256;

  /// Human-readable fallback shown on the placeholder.
  final String label;

  bool get isCustom => customSpriteSha256 != null;

  @override
  bool operator ==(Object other) =>
      other is SpriteRef &&
      other.assetName == assetName &&
      other.customSpriteSha256 == customSpriteSha256 &&
      other.label == label;

  @override
  int get hashCode => Object.hash(assetName, customSpriteSha256, label);
}

/// A generic depletable bar (monster HP, quest HP, goal progress).
class HpBar {
  const HpBar({required this.currentCents, required this.maxCents});

  /// For a monster this is *damage dealt* (spent); for a quest it is
  /// *damage dealt* (contributed). Read the owning type's doc.
  final int currentCents;
  final int maxCents;

  /// Consumed fraction in 0..1. A zero-max bar reads full once anything lands.
  double get fraction {
    if (maxCents <= 0) return currentCents > 0 ? 1 : 0;
    final f = currentCents / maxCents;
    return f < 0 ? 0 : (f > 1 ? 1 : f);
  }

  int get pct => (fraction * 100).round();
}

/// A personal-slice monster. `maxHP` = the slice's effective limit; damage =
/// spend. Overspend makes it [enraged] and the excess is dealt to the hero.
class Monster {
  const Monster({
    required this.sliceId,
    required this.name,
    required this.sprite,
    required this.maxHpCents,
    required this.damageCents,
    required this.excessCents,
    required this.mine,
    this.ownerName,
  });

  final String sliceId;
  final String name;
  final SpriteRef sprite;

  /// The effective monthly limit — the monster's total HP.
  final int maxHpCents;

  /// Spend so far — damage dealt to the monster.
  final int damageCents;

  /// Overspend beyond `maxHP` — dealt to the hero instead.
  final int excessCents;

  /// Whether this monster belongs to the device owner.
  final bool mine;
  final String? ownerName;

  bool get enraged => excessCents > 0;

  /// A freshly-defeated monster: fully damaged but not overspent.
  bool get defeated => !enraged && damageCents >= maxHpCents && maxHpCents > 0;

  HpBar get hp => HpBar(currentCents: damageCents, maxCents: maxHpCents);
}

/// A group-slice party contract: a shared undertaking with a dual-colour
/// banner. Overspend enrages it and bleeds the party's shared HP.
class PartyContract {
  const PartyContract({
    required this.sliceId,
    required this.name,
    required this.maxHpCents,
    required this.damageCents,
    required this.excessCents,
    this.petName,
  });

  final String sliceId;
  final String name;
  final int maxHpCents;
  final int damageCents;
  final int excessCents;

  /// A pet-linked contract is displayed under that pet party member.
  final String? petName;

  bool get enraged => excessCents > 0;

  HpBar get hp => HpBar(currentCents: damageCents, maxCents: maxHpCents);
}

/// A pet party member. Owns the monsters (micro budgets) and reserve caches
/// whose slices/funds reference it.
class PartyMember {
  const PartyMember({
    required this.petId,
    required this.name,
    required this.sprite,
    required this.monsters,
    required this.contracts,
    required this.reserveCaches,
  });

  final String petId;
  final String name;
  final SpriteRef sprite;

  /// Personal-slice monsters linked to this pet.
  final List<Monster> monsters;

  /// Group-slice contracts linked to this pet.
  final List<PartyContract> contracts;

  /// Reserve caches (emergency funds) linked to this pet.
  final List<ReserveCache> reserveCaches;
}

/// A savings-goal quest monster, hunted across months. HP = target; damage =
/// total contributed. At full damage it is [completed] and drops a trophy.
class QuestMonster {
  const QuestMonster({
    required this.questId,
    required this.name,
    required this.sprite,
    required this.targetCents,
    required this.contributedCents,
    required this.balanceCents,
    required this.completed,
    required this.shared,
    required this.contributors,
    this.mainCategoryId,
    this.descriptionText,
  });

  final String questId;
  final String name;
  final SpriteRef sprite;

  /// The main category this goal rolls up to; an attack from a matching category
  /// is untithed (full damage), a non-matching one pays the source's pool tithe.
  final String? mainCategoryId;

  /// The user-written description, rendered by text-mode adventure.
  final String? descriptionText;

  /// The goal amount — the quest monster's total HP.
  final int targetCents;

  /// Total funded toward the goal — cumulative damage dealt.
  final int contributedCents;

  /// Remaining spendable balance (contributed less quest-charged purchases).
  final int balanceCents;
  final bool completed;
  final bool shared;

  /// Per-adventurer damage, for the dual-banner shared quests.
  final List<Contributor> contributors;

  HpBar get hp => HpBar(currentCents: contributedCents, maxCents: targetCents);
}

/// One adventurer's damage to a shared quest monster.
class Contributor {
  const Contributor({required this.name, required this.cents});
  final String name;
  final int cents;
}

/// The kind of a provisioning line (drives the sub-label & tally state).
enum ProvisionKind { fixedMaintenance, variableMaintenance, emergencyProvision }

/// One "equipment maintenance & provisioning" line, resolved at floor start.
///
/// An annual recurring expense reads as a "provisioning contract" — a big
/// bill reserved 1/12 each floor, with a countdown to when it comes due.
class ProvisionLine {
  const ProvisionLine({
    required this.name,
    required this.kind,
    required this.amountCents,
    required this.shared,
    required this.awaitingTally,
    this.ownerName,
    this.isAnnualContract = false,
    this.contractTotalCents,
    this.dueDay,
    this.dueMonth,
    this.daysUntilDue,
  });

  final String name;
  final ProvisionKind kind;

  /// The charge this floor (actual if a variable one has been tallied, else the
  /// estimate / fixed amount / contribution). For an annual contract this is
  /// the 1/12 monthly accrual, not the full bill.
  final int amountCents;
  final bool shared;

  /// A variable maintenance line whose closed-floor actual is not yet recorded.
  final bool awaitingTally;
  final String? ownerName;

  /// True for an annual recurring expense: a provisioning contract with a
  /// countdown to its due date.
  final bool isAnnualContract;

  /// The full annual bill (the contract's face value); null for monthly lines.
  final int? contractTotalCents;

  /// Due-date components for a contract: day of month, and (for annual) the
  /// calendar month it comes due.
  final int? dueDay;
  final int? dueMonth;

  /// Whole days until the contract next comes due; null for non-contract lines.
  final int? daysUntilDue;

  bool get isVariable => kind == ProvisionKind.variableMaintenance;
}

/// The gold pouch (the device owner's vault).
class GoldPouch {
  const GoldPouch({
    required this.balanceCents,
    required this.clampedFlag,
    required this.projectedMintCents,
  });

  final int balanceCents;

  /// The vault was clamped at zero — an inconsistency the skin surfaces quietly.
  final bool clampedFlag;

  /// What this floor's still-open spoils would mint into the pouch.
  final int projectedMintCents;
}

/// A pending withdrawal writ awaiting the *other* adventurer's signature.
class Writ {
  const Writ({
    required this.proposalId,
    required this.byName,
    required this.amountCents,
    required this.purpose,
    required this.destinationLabel,
    required this.needsMySignature,
  });

  final String proposalId;
  final String byName;
  final int amountCents;
  final String purpose;
  final String destinationLabel;

  /// True when the other adventurer raised it and it awaits my signature.
  final bool needsMySignature;
}

/// A "the war chest was ransacked" banner.
class RansackBanner {
  const RansackBanner({
    required this.cacheName,
    required this.excessCents,
    required this.purpose,
    required this.occurredAt,
  });

  final String cacheName;
  final int excessCents;
  final String purpose;
  final DateTime occurredAt;
}

/// The war chest (shared pool), its optional long-term goal, its pending writs
/// and any ransack banners.
class WarChest {
  const WarChest({
    required this.balanceCents,
    required this.writsForMe,
    required this.writsForOther,
    required this.ransacks,
    this.targetCents,
    this.pctComplete,
    this.estMonthsRemaining,
  });

  final int balanceCents;
  final int? targetCents;
  final double? pctComplete;
  final double? estMonthsRemaining;
  final List<Writ> writsForMe;
  final List<Writ> writsForOther;
  final List<RansackBanner> ransacks;

  bool get hasGoal => targetCents != null;

  int? get monthsToGo => estMonthsRemaining == null
      ? null
      : (estMonthsRemaining!.isFinite ? estMonthsRemaining!.ceil() : null);
}

/// A reserve cache (emergency fund) not attached to a pet party member.
class ReserveCache {
  const ReserveCache({
    required this.fundId,
    required this.name,
    required this.sprite,
    required this.balanceCents,
    this.petName,
  });

  final String fundId;
  final String name;
  final SpriteRef sprite;
  final int balanceCents;
  final String? petName;
}

/// The whole adventure read-model for one dungeon floor.
class GameState {
  const GameState({
    required this.currentMonth,
    required this.floorNumber,
    required this.heroName,
    required this.heroSprite,
    required this.partnerSprite,
    required this.heroHpLostCents,
    required this.expeditionSuppliesCents,
    required this.monsters,
    required this.contracts,
    required this.party,
    required this.questMonsters,
    required this.provisioning,
    required this.goldPouch,
    required this.warChest,
    required this.reserveCaches,
  });

  /// The month this floor represents.
  final Month currentMonth;

  /// 1-based dungeon floor number, counted from the first event's month.
  final int floorNumber;

  final String heroName;
  final SpriteRef heroSprite;
  final SpriteRef partnerSprite;

  /// Total overspend across all monsters & contracts — HP the hero has lost.
  final int heroHpLostCents;

  /// The device owner's income this floor — expedition supplies.
  final int expeditionSuppliesCents;

  /// Personal-slice monsters NOT linked to a pet (pet-linked ones live in
  /// [party]).
  final List<Monster> monsters;

  /// Group-slice contracts NOT linked to a pet.
  final List<PartyContract> contracts;

  /// Pet party members, each owning their linked monsters / contracts / caches.
  final List<PartyMember> party;

  final List<QuestMonster> questMonsters;
  final List<ProvisionLine> provisioning;
  final GoldPouch goldPouch;
  final WarChest warChest;

  /// Reserve caches NOT linked to a pet.
  final List<ReserveCache> reserveCaches;

  bool get heroWounded => heroHpLostCents > 0;
}
