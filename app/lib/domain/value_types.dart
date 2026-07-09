/// Small sealed value types shared by events and derived state: charge targets,
/// ownership, leftover destinations, withdrawal destinations and enums. All
/// carry JSON round-trip serialization. Pure Dart, zero Flutter imports.
library;

/// Where a purchase draws its money from.
sealed class ChargeTarget {
  const ChargeTarget();

  Map<String, dynamic> toJson();

  static ChargeTarget fromJson(Map<String, dynamic> json) {
    final kind = json['kind'] as String;
    switch (kind) {
      case 'slice':
        return SliceCharge(json['sliceId'] as String);
      case 'vault':
        return const VaultCharge();
      case 'quest':
        return QuestCharge(json['questId'] as String);
      case 'emergency':
        return EmergencyCharge(json['fundId'] as String);
      case 'vacation':
        return VacationCharge(
          json['vacationId'] as String,
          json['categoryId'] as String,
        );
      default:
        throw FormatException('Unknown charge target kind: $kind');
    }
  }
}

class SliceCharge extends ChargeTarget {
  const SliceCharge(this.sliceId);
  final String sliceId;
  @override
  Map<String, dynamic> toJson() => {'kind': 'slice', 'sliceId': sliceId};
  @override
  bool operator ==(Object other) =>
      other is SliceCharge && other.sliceId == sliceId;
  @override
  int get hashCode => Object.hash('slice', sliceId);
}

class VaultCharge extends ChargeTarget {
  const VaultCharge();
  @override
  Map<String, dynamic> toJson() => {'kind': 'vault'};
  @override
  bool operator ==(Object other) => other is VaultCharge;
  @override
  int get hashCode => 'vault'.hashCode;
}

class QuestCharge extends ChargeTarget {
  const QuestCharge(this.questId);
  final String questId;
  @override
  Map<String, dynamic> toJson() => {'kind': 'quest', 'questId': questId};
  @override
  bool operator ==(Object other) =>
      other is QuestCharge && other.questId == questId;
  @override
  int get hashCode => Object.hash('quest', questId);
}

class EmergencyCharge extends ChargeTarget {
  const EmergencyCharge(this.fundId);
  final String fundId;
  @override
  Map<String, dynamic> toJson() => {'kind': 'emergency', 'fundId': fundId};
  @override
  bool operator ==(Object other) =>
      other is EmergencyCharge && other.fundId == fundId;
  @override
  int get hashCode => Object.hash('emergency', fundId);
}

/// A purchase drawn from an open vacation's sub-budget: a specific
/// [categoryId] within the vacation [vacationId]. The vacation is itself backed
/// by a source fund (a quest or emergency fund); a vacation charge only tracks
/// per-category spend, never touching a normal monthly budget.
class VacationCharge extends ChargeTarget {
  const VacationCharge(this.vacationId, this.categoryId);
  final String vacationId;
  final String categoryId;
  @override
  Map<String, dynamic> toJson() =>
      {'kind': 'vacation', 'vacationId': vacationId, 'categoryId': categoryId};
  @override
  bool operator ==(Object other) =>
      other is VacationCharge &&
      other.vacationId == vacationId &&
      other.categoryId == categoryId;
  @override
  int get hashCode => Object.hash('vacation', vacationId, categoryId);
}

/// The source fund a vacation draws from: an existing savings quest or an
/// emergency fund. Exactly one is chosen when the vacation is created; the
/// vacation reserves its budget off that fund and returns the leftover on close.
sealed class VacationFund {
  const VacationFund();
  Map<String, dynamic> toJson();

  static VacationFund fromJson(Map<String, dynamic> json) {
    final kind = json['kind'] as String;
    switch (kind) {
      case 'quest':
        return VacationFundQuest(json['questId'] as String);
      case 'emergency':
        return VacationFundEmergency(json['fundId'] as String);
      default:
        throw FormatException('Unknown vacation fund kind: $kind');
    }
  }
}

class VacationFundQuest extends VacationFund {
  const VacationFundQuest(this.questId);
  final String questId;
  @override
  Map<String, dynamic> toJson() => {'kind': 'quest', 'questId': questId};
  @override
  bool operator ==(Object other) =>
      other is VacationFundQuest && other.questId == questId;
  @override
  int get hashCode => Object.hash('vacFundQuest', questId);
}

class VacationFundEmergency extends VacationFund {
  const VacationFundEmergency(this.fundId);
  final String fundId;
  @override
  Map<String, dynamic> toJson() => {'kind': 'emergency', 'fundId': fundId};
  @override
  bool operator ==(Object other) =>
      other is VacationFundEmergency && other.fundId == fundId;
  @override
  int get hashCode => Object.hash('vacFundEmergency', fundId);
}

/// One spending category inside a vacation's self-contained sub-budget. The
/// [categoryId] is stable across re-declarations of the vacation so purchases
/// keep referencing the same category even if its name or limit is edited.
class VacationCategory {
  const VacationCategory({
    required this.categoryId,
    required this.name,
    required this.limitCents,
  });

  final String categoryId;
  final String name;
  final int limitCents;

  Map<String, dynamic> toJson() =>
      {'categoryId': categoryId, 'name': name, 'limitCents': limitCents};

  static VacationCategory fromJson(Map<String, dynamic> json) => VacationCategory(
        categoryId: json['categoryId'] as String,
        name: json['name'] as String,
        limitCents: json['limitCents'] as int,
      );

  @override
  bool operator ==(Object other) =>
      other is VacationCategory &&
      other.categoryId == categoryId &&
      other.name == name &&
      other.limitCents == limitCents;

  @override
  int get hashCode => Object.hash(categoryId, name, limitCents);
}

/// Ownership of a budget slice: a single user or the whole household (group).
sealed class SliceOwnership {
  const SliceOwnership();
  Map<String, dynamic> toJson();

  static SliceOwnership fromJson(Map<String, dynamic> json) {
    final kind = json['kind'] as String;
    switch (kind) {
      case 'personal':
        return PersonalSlice(json['userId'] as String);
      case 'group':
        return const GroupSlice();
      default:
        throw FormatException('Unknown slice ownership kind: $kind');
    }
  }
}

class PersonalSlice extends SliceOwnership {
  const PersonalSlice(this.userId);
  final String userId;
  @override
  Map<String, dynamic> toJson() => {'kind': 'personal', 'userId': userId};
  @override
  bool operator ==(Object other) =>
      other is PersonalSlice && other.userId == userId;
  @override
  int get hashCode => Object.hash('personalSlice', userId);
}

class GroupSlice extends SliceOwnership {
  const GroupSlice();
  @override
  Map<String, dynamic> toJson() => {'kind': 'group'};
  @override
  bool operator ==(Object other) => other is GroupSlice;
  @override
  int get hashCode => 'groupSlice'.hashCode;
}

/// Ownership for quests and recurring expenses: a single user or shared by both.
sealed class PartyOwnership {
  const PartyOwnership();
  Map<String, dynamic> toJson();

  static PartyOwnership fromJson(Map<String, dynamic> json) {
    final kind = json['kind'] as String;
    switch (kind) {
      case 'personal':
        return PersonalParty(json['userId'] as String);
      case 'shared':
        return const SharedParty();
      default:
        throw FormatException('Unknown party ownership kind: $kind');
    }
  }
}

class PersonalParty extends PartyOwnership {
  const PersonalParty(this.userId);
  final String userId;
  @override
  Map<String, dynamic> toJson() => {'kind': 'personal', 'userId': userId};
  @override
  bool operator ==(Object other) =>
      other is PersonalParty && other.userId == userId;
  @override
  int get hashCode => Object.hash('personalParty', userId);
}

class SharedParty extends PartyOwnership {
  const SharedParty();
  @override
  Map<String, dynamic> toJson() => {'kind': 'shared'};
  @override
  bool operator ==(Object other) => other is SharedParty;
  @override
  int get hashCode => 'sharedParty'.hashCode;
}

/// A destination for month-close leftover: carry within the slice, attack a
/// quest, or convert to discretionary vault money. Also serves as a slice's
/// default leftover policy.
sealed class LeftoverDestination {
  const LeftoverDestination();
  Map<String, dynamic> toJson();

  static LeftoverDestination fromJson(Map<String, dynamic> json) {
    final kind = json['kind'] as String;
    switch (kind) {
      case 'carryInSlice':
        return const CarryInSlice();
      case 'quest':
        return QuestDestination(json['questId'] as String);
      case 'discretionary':
        return const Discretionary();
      default:
        throw FormatException('Unknown leftover destination kind: $kind');
    }
  }
}

class CarryInSlice extends LeftoverDestination {
  const CarryInSlice();
  @override
  Map<String, dynamic> toJson() => {'kind': 'carryInSlice'};
  @override
  bool operator ==(Object other) => other is CarryInSlice;
  @override
  int get hashCode => 'carryInSlice'.hashCode;
}

class QuestDestination extends LeftoverDestination {
  const QuestDestination(this.questId);
  final String questId;
  @override
  Map<String, dynamic> toJson() => {'kind': 'quest', 'questId': questId};
  @override
  bool operator ==(Object other) =>
      other is QuestDestination && other.questId == questId;
  @override
  int get hashCode => Object.hash('questDest', questId);
}

class Discretionary extends LeftoverDestination {
  const Discretionary();
  @override
  Map<String, dynamic> toJson() => {'kind': 'discretionary'};
  @override
  bool operator ==(Object other) => other is Discretionary;
  @override
  int get hashCode => 'discretionary'.hashCode;
}

/// A single leftover allocation line.
class Allocation {
  const Allocation({required this.destination, required this.amountCents});

  final LeftoverDestination destination;
  final int amountCents;

  Map<String, dynamic> toJson() =>
      {'destination': destination.toJson(), 'amountCents': amountCents};

  static Allocation fromJson(Map<String, dynamic> json) => Allocation(
        destination: LeftoverDestination.fromJson(
          json['destination'] as Map<String, dynamic>,
        ),
        amountCents: json['amountCents'] as int,
      );

  @override
  bool operator ==(Object other) =>
      other is Allocation &&
      other.destination == destination &&
      other.amountCents == amountCents;

  @override
  int get hashCode => Object.hash(destination, amountCents);
}

/// Where an approved pool withdrawal sends its money.
sealed class WithdrawalDestination {
  const WithdrawalDestination();
  Map<String, dynamic> toJson();

  static WithdrawalDestination fromJson(Map<String, dynamic> json) {
    final kind = json['kind'] as String;
    switch (kind) {
      case 'userVault':
        return UserVaultDestination(json['userId'] as String);
      case 'external':
        return const ExternalDestination();
      default:
        throw FormatException('Unknown withdrawal destination kind: $kind');
    }
  }
}

class UserVaultDestination extends WithdrawalDestination {
  const UserVaultDestination(this.userId);
  final String userId;
  @override
  Map<String, dynamic> toJson() => {'kind': 'userVault', 'userId': userId};
  @override
  bool operator ==(Object other) =>
      other is UserVaultDestination && other.userId == userId;
  @override
  int get hashCode => Object.hash('userVaultDest', userId);
}

class ExternalDestination extends WithdrawalDestination {
  const ExternalDestination();
  @override
  Map<String, dynamic> toJson() => {'kind': 'external'};
  @override
  bool operator ==(Object other) => other is ExternalDestination;
  @override
  int get hashCode => 'externalDest'.hashCode;
}

/// A household member's role. Only [adult] carries income, a vault, personal
/// categories and paired devices; [dependent] and [pet] are display-level party
/// members with no ledger of their own. Legacy `PetSet` events reduce as [pet]
/// members.
enum MemberRole { adult, dependent, pet }

/// Kind of a recurring expense.
enum RecurringKind { fixed, variable }

/// Cadence of a recurring expense. A [monthly] expense charges its full amount
/// every active month. An [annual] expense charges 1/12 monthly off the top,
/// with the integer-cents remainder landing in the due month so the twelve
/// charges sum exactly to the annual amount; the due month reconciles the real
/// amount against the accumulated reserve. Legacy events (no cadence) reduce as
/// [monthly].
enum RecurringCadence { monthly, annual }

/// Kind of a tracked net-worth account. `savings`/`debt` accrue interest at read
/// time; `investment` is never auto-changed (it goes stale instead). `cash` is a
/// legacy value retained for wire compatibility and behaves like a
/// non-interest-bearing savings account. Debt contributes negatively.
enum AccountKind { savings, cash, investment, debt }

/// The frequency knobs on a tracked account: how often interest compounds
/// (`accrualCadence`) and how often the user is expected to refresh a manual
/// value (`updateCadence`). Purely a read-time derivation input; no jobs run.
enum AccountCadence { daily, monthly, quarterly, annually }

/// Direction of an [AccountTransferRecorded]: money moved into the account
/// (raising its recorded balance) or out of it (lowering it).
enum TransferDirection { deposit, withdrawal }

/// The flavour of a cosmetic [GameRewardGranted]. A [trophy] marks a defeated
/// quest boss; a [title] and a [badge] are streak/habit unlocks. All three are
/// purely decorative — the money reducer ignores the event entirely.
enum RewardKind { trophy, title, badge }

/// An emergency fund contribution designated on a slice.
class EmergencyContribution {
  const EmergencyContribution({required this.fundId, required this.amountCents});

  final String fundId;
  final int amountCents;

  Map<String, dynamic> toJson() =>
      {'fundId': fundId, 'amountCents': amountCents};

  static EmergencyContribution fromJson(Map<String, dynamic> json) =>
      EmergencyContribution(
        fundId: json['fundId'] as String,
        amountCents: json['amountCents'] as int,
      );

  @override
  bool operator ==(Object other) =>
      other is EmergencyContribution &&
      other.fundId == fundId &&
      other.amountCents == amountCents;

  @override
  int get hashCode => Object.hash(fundId, amountCents);
}
