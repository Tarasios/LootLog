/// The sealed Event hierarchy. Every state change in DuoBudget is an immutable
/// event appended to the local log; derived state comes only from the reducer.
///
/// Every event shares a common envelope: `eventId` (UUIDv7), `deviceId`,
/// `userId`, `occurredAt` (user-editable; keys the month), `createdAt`, `type`
/// and a type-specific `payload`. Pure Dart, zero Flutter imports.
library;

import 'time.dart';
import 'value_types.dart';

/// Base class for every domain event.
sealed class Event {
  const Event({
    required this.eventId,
    required this.deviceId,
    required this.userId,
    required this.occurredAt,
    required this.createdAt,
  });

  /// UUIDv7 identity. Idempotency and total ordering both key off this.
  final String eventId;
  final String deviceId;

  /// The user who authored the event.
  final String userId;

  /// When the event is considered to have happened. User-editable; this is what
  /// keys the calendar month, not [createdAt].
  final DateTime occurredAt;

  /// When the event was actually recorded.
  final DateTime createdAt;

  /// The discriminator string used in JSON.
  String get type;

  /// The type-specific payload (without the envelope).
  Map<String, dynamic> payload();

  /// The household-timezone month this event is keyed to.
  Month get occurredMonth => Month.fromInstant(occurredAt);

  Map<String, dynamic> toJson() => {
        'eventId': eventId,
        'deviceId': deviceId,
        'userId': userId,
        'occurredAt': occurredAt.toUtc().toIso8601String(),
        'createdAt': createdAt.toUtc().toIso8601String(),
        'type': type,
        'payload': payload(),
      };

  /// Reconstructs an event from its JSON envelope.
  static Event fromJson(Map<String, dynamic> json) {
    final type = json['type'] as String;
    final eventId = json['eventId'] as String;
    final deviceId = json['deviceId'] as String;
    final userId = json['userId'] as String;
    final occurredAt = DateTime.parse(json['occurredAt'] as String).toUtc();
    final createdAt = DateTime.parse(json['createdAt'] as String).toUtc();
    final p = (json['payload'] as Map).cast<String, dynamic>();

    switch (type) {
      case 'PurchaseAdded':
        return PurchaseAdded(
          eventId: eventId,
          deviceId: deviceId,
          userId: userId,
          occurredAt: occurredAt,
          createdAt: createdAt,
          purchaseId: p['purchaseId'] as String,
          target: ChargeTarget.fromJson((p['target'] as Map).cast()),
          amountCents: p['amountCents'] as int,
          shared: p['shared'] as bool? ?? false,
          merchant: p['merchant'] as String?,
          taxDeductible: p['taxDeductible'] as bool?,
          note: p['note'] as String?,
        );
      case 'PurchaseVoided':
        return PurchaseVoided(
          eventId: eventId,
          deviceId: deviceId,
          userId: userId,
          occurredAt: occurredAt,
          createdAt: createdAt,
          purchaseId: p['purchaseId'] as String,
        );
      case 'BudgetSliceSet':
        return BudgetSliceSet(
          eventId: eventId,
          deviceId: deviceId,
          userId: userId,
          occurredAt: occurredAt,
          createdAt: createdAt,
          sliceId: p['sliceId'] as String,
          name: p['name'] as String,
          ownership: SliceOwnership.fromJson((p['ownership'] as Map).cast()),
          limitCents: p['limitCents'] as int,
          poolTithePct: p['poolTithePct'] as int,
          defaultLeftoverPolicy: LeftoverDestination.fromJson(
            (p['defaultLeftoverPolicy'] as Map).cast(),
          ),
          taxDeductibleByDefault: p['taxDeductibleByDefault'] as bool,
          emergencyContribution: p['emergencyContribution'] == null
              ? null
              : EmergencyContribution.fromJson(
                  (p['emergencyContribution'] as Map).cast(),
                ),
          petId: p['petId'] as String?,
        );
      case 'RecurringExpenseSet':
        return RecurringExpenseSet(
          eventId: eventId,
          deviceId: deviceId,
          userId: userId,
          occurredAt: occurredAt,
          createdAt: createdAt,
          expenseId: p['expenseId'] as String,
          name: p['name'] as String,
          ownership: PartyOwnership.fromJson((p['ownership'] as Map).cast()),
          kind: RecurringKind.values.byName(p['kind'] as String),
          amountCents: p['amountCents'] as int,
          startMonth: Month.parse(p['startMonth'] as String),
          endMonth: p['endMonth'] == null
              ? null
              : Month.parse(p['endMonth'] as String),
        );
      case 'VariableExpenseRecorded':
        return VariableExpenseRecorded(
          eventId: eventId,
          deviceId: deviceId,
          userId: userId,
          occurredAt: occurredAt,
          createdAt: createdAt,
          expenseId: p['expenseId'] as String,
          month: Month.parse(p['month'] as String),
          actualCents: p['actualCents'] as int,
        );
      case 'IncomeSet':
        return IncomeSet(
          eventId: eventId,
          deviceId: deviceId,
          userId: userId,
          occurredAt: occurredAt,
          createdAt: createdAt,
          forUserId: p['forUserId'] as String,
          amountCents: p['amountCents'] as int,
          month: Month.parse(p['month'] as String),
        );
      case 'QuestSet':
        return QuestSet(
          eventId: eventId,
          deviceId: deviceId,
          userId: userId,
          occurredAt: occurredAt,
          createdAt: createdAt,
          questId: p['questId'] as String,
          name: p['name'] as String,
          targetCents: p['targetCents'] as int,
          ownership: PartyOwnership.fromJson((p['ownership'] as Map).cast()),
          sliceHint: p['sliceHint'] as String?,
          customSpriteSha256: p['customSpriteSha256'] as String?,
        );
      case 'QuestAbandoned':
        return QuestAbandoned(
          eventId: eventId,
          deviceId: deviceId,
          userId: userId,
          occurredAt: occurredAt,
          createdAt: createdAt,
          questId: p['questId'] as String,
        );
      case 'LeftoverAllocated':
        return LeftoverAllocated(
          eventId: eventId,
          deviceId: deviceId,
          userId: userId,
          occurredAt: occurredAt,
          createdAt: createdAt,
          forUserId: p['forUserId'] as String,
          month: Month.parse(p['month'] as String),
          sliceId: p['sliceId'] as String,
          allocations: [
            for (final a in p['allocations'] as List)
              Allocation.fromJson((a as Map).cast()),
          ],
        );
      case 'GiftReceived':
        return GiftReceived(
          eventId: eventId,
          deviceId: deviceId,
          userId: userId,
          occurredAt: occurredAt,
          createdAt: createdAt,
          forUserId: p['forUserId'] as String,
          amountCents: p['amountCents'] as int,
          note: p['note'] as String?,
        );
      case 'PoolContributionMade':
        return PoolContributionMade(
          eventId: eventId,
          deviceId: deviceId,
          userId: userId,
          occurredAt: occurredAt,
          createdAt: createdAt,
          fromUserId: p['fromUserId'] as String,
          amountCents: p['amountCents'] as int,
        );
      case 'PoolWithdrawalProposed':
        return PoolWithdrawalProposed(
          eventId: eventId,
          deviceId: deviceId,
          userId: userId,
          occurredAt: occurredAt,
          createdAt: createdAt,
          proposalId: p['proposalId'] as String,
          byUserId: p['byUserId'] as String,
          amountCents: p['amountCents'] as int,
          purpose: p['purpose'] as String,
          destination:
              WithdrawalDestination.fromJson((p['destination'] as Map).cast()),
        );
      case 'PoolWithdrawalApproved':
        return PoolWithdrawalApproved(
          eventId: eventId,
          deviceId: deviceId,
          userId: userId,
          occurredAt: occurredAt,
          createdAt: createdAt,
          proposalId: p['proposalId'] as String,
          byUserId: p['byUserId'] as String,
        );
      case 'PoolWithdrawalCancelled':
        return PoolWithdrawalCancelled(
          eventId: eventId,
          deviceId: deviceId,
          userId: userId,
          occurredAt: occurredAt,
          createdAt: createdAt,
          proposalId: p['proposalId'] as String,
        );
      case 'TaxRefundRecorded':
        return TaxRefundRecorded(
          eventId: eventId,
          deviceId: deviceId,
          userId: userId,
          occurredAt: occurredAt,
          createdAt: createdAt,
          amountCents: p['amountCents'] as int,
          note: p['note'] as String?,
        );
      case 'EmergencyFundSet':
        return EmergencyFundSet(
          eventId: eventId,
          deviceId: deviceId,
          userId: userId,
          occurredAt: occurredAt,
          createdAt: createdAt,
          fundId: p['fundId'] as String,
          name: p['name'] as String,
          petId: p['petId'] as String?,
        );
      case 'PetSet':
        return PetSet(
          eventId: eventId,
          deviceId: deviceId,
          userId: userId,
          occurredAt: occurredAt,
          createdAt: createdAt,
          petId: p['petId'] as String,
          name: p['name'] as String,
          customSpriteSha256: p['customSpriteSha256'] as String?,
        );
      case 'MemberSet':
        return MemberSet(
          eventId: eventId,
          deviceId: deviceId,
          userId: userId,
          occurredAt: occurredAt,
          createdAt: createdAt,
          memberId: p['memberId'] as String,
          name: p['name'] as String,
          role: MemberRole.values.byName(p['role'] as String),
          active: p['active'] as bool? ?? true,
          customSpriteSha256: p['customSpriteSha256'] as String?,
          descriptionText: p['descriptionText'] as String?,
        );
      case 'GroupShareSet':
        return GroupShareSet(
          eventId: eventId,
          deviceId: deviceId,
          userId: userId,
          occurredAt: occurredAt,
          createdAt: createdAt,
          month: Month.parse(p['month'] as String),
          shares: {
            for (final e in (p['shares'] as Map).entries)
              e.key as String: e.value as int,
          },
        );
      case 'GoalSet':
        return GoalSet(
          eventId: eventId,
          deviceId: deviceId,
          userId: userId,
          occurredAt: occurredAt,
          createdAt: createdAt,
          targetCents: p['targetCents'] as int,
        );
      case 'ReceiptAttached':
        return ReceiptAttached(
          eventId: eventId,
          deviceId: deviceId,
          userId: userId,
          occurredAt: occurredAt,
          createdAt: createdAt,
          purchaseId: p['purchaseId'] as String,
          sha256: p['sha256'] as String,
          mimeType: p['mimeType'] as String,
          sizeBytes: p['sizeBytes'] as int,
        );
      case 'ReceiptDetached':
        return ReceiptDetached(
          eventId: eventId,
          deviceId: deviceId,
          userId: userId,
          occurredAt: occurredAt,
          createdAt: createdAt,
          purchaseId: p['purchaseId'] as String,
          sha256: p['sha256'] as String,
        );
      case 'AccountBalanceRecorded':
        return AccountBalanceRecorded(
          eventId: eventId,
          deviceId: deviceId,
          userId: userId,
          occurredAt: occurredAt,
          createdAt: createdAt,
          accountId: p['accountId'] as String,
          accountName: p['accountName'] as String,
          kind: AccountKind.values.byName(p['kind'] as String),
          balanceCents: p['balanceCents'] as int,
        );
      case 'SettingChanged':
        return SettingChanged(
          eventId: eventId,
          deviceId: deviceId,
          userId: userId,
          occurredAt: occurredAt,
          createdAt: createdAt,
          key: p['key'] as String,
          value: p['value'],
        );
      case 'CosmeticSet':
        return CosmeticSet(
          eventId: eventId,
          deviceId: deviceId,
          userId: userId,
          occurredAt: occurredAt,
          createdAt: createdAt,
          key: p['key'] as String,
          value: p['value'],
        );
      default:
        throw FormatException('Unknown event type: $type');
    }
  }
}

/// A purchase. `chargeTarget` may be a slice, the vault, a quest, or an
/// emergency fund. The optional `shared` flag is valid only for personal-slice
/// and vault targets.
class PurchaseAdded extends Event {
  PurchaseAdded({
    required super.eventId,
    required super.deviceId,
    required super.userId,
    required super.occurredAt,
    required super.createdAt,
    required this.purchaseId,
    required this.target,
    required this.amountCents,
    this.shared = false,
    this.merchant,
    this.taxDeductible,
    this.note,
  }) {
    if (shared && (target is QuestCharge || target is EmergencyCharge)) {
      throw ArgumentError(
        'shared is only valid for personal-slice and vault charge targets',
      );
    }
  }

  final String purchaseId;
  final ChargeTarget target;
  final int amountCents;
  final bool shared;
  final String? merchant;

  /// Per-purchase tax override; `null` means inherit from the slice default.
  final bool? taxDeductible;
  final String? note;

  @override
  String get type => 'PurchaseAdded';

  @override
  Map<String, dynamic> payload() => {
        'purchaseId': purchaseId,
        'target': target.toJson(),
        'amountCents': amountCents,
        'shared': shared,
        if (merchant != null) 'merchant': merchant,
        if (taxDeductible != null) 'taxDeductible': taxDeductible,
        if (note != null) 'note': note,
      };
}

class PurchaseVoided extends Event {
  const PurchaseVoided({
    required super.eventId,
    required super.deviceId,
    required super.userId,
    required super.occurredAt,
    required super.createdAt,
    required this.purchaseId,
  });

  final String purchaseId;

  @override
  String get type => 'PurchaseVoided';

  @override
  Map<String, dynamic> payload() => {'purchaseId': purchaseId};
}

class BudgetSliceSet extends Event {
  const BudgetSliceSet({
    required super.eventId,
    required super.deviceId,
    required super.userId,
    required super.occurredAt,
    required super.createdAt,
    required this.sliceId,
    required this.name,
    required this.ownership,
    required this.limitCents,
    required this.poolTithePct,
    required this.defaultLeftoverPolicy,
    required this.taxDeductibleByDefault,
    this.emergencyContribution,
    this.petId,
  });

  final String sliceId;
  final String name;
  final SliceOwnership ownership;
  final int limitCents;
  final int poolTithePct;
  final LeftoverDestination defaultLeftoverPolicy;
  final bool taxDeductibleByDefault;
  final EmergencyContribution? emergencyContribution;
  final String? petId;

  @override
  String get type => 'BudgetSliceSet';

  @override
  Map<String, dynamic> payload() => {
        'sliceId': sliceId,
        'name': name,
        'ownership': ownership.toJson(),
        'limitCents': limitCents,
        'poolTithePct': poolTithePct,
        'defaultLeftoverPolicy': defaultLeftoverPolicy.toJson(),
        'taxDeductibleByDefault': taxDeductibleByDefault,
        if (emergencyContribution != null)
          'emergencyContribution': emergencyContribution!.toJson(),
        if (petId != null) 'petId': petId,
      };
}

class RecurringExpenseSet extends Event {
  const RecurringExpenseSet({
    required super.eventId,
    required super.deviceId,
    required super.userId,
    required super.occurredAt,
    required super.createdAt,
    required this.expenseId,
    required this.name,
    required this.ownership,
    required this.kind,
    required this.amountCents,
    required this.startMonth,
    this.endMonth,
  });

  final String expenseId;
  final String name;
  final PartyOwnership ownership;
  final RecurringKind kind;
  final int amountCents;
  final Month startMonth;
  final Month? endMonth;

  @override
  String get type => 'RecurringExpenseSet';

  @override
  Map<String, dynamic> payload() => {
        'expenseId': expenseId,
        'name': name,
        'ownership': ownership.toJson(),
        'kind': kind.name,
        'amountCents': amountCents,
        'startMonth': startMonth.toKey(),
        if (endMonth != null) 'endMonth': endMonth!.toKey(),
      };
}

class VariableExpenseRecorded extends Event {
  const VariableExpenseRecorded({
    required super.eventId,
    required super.deviceId,
    required super.userId,
    required super.occurredAt,
    required super.createdAt,
    required this.expenseId,
    required this.month,
    required this.actualCents,
  });

  final String expenseId;
  final Month month;
  final int actualCents;

  @override
  String get type => 'VariableExpenseRecorded';

  @override
  Map<String, dynamic> payload() => {
        'expenseId': expenseId,
        'month': month.toKey(),
        'actualCents': actualCents,
      };
}

class IncomeSet extends Event {
  const IncomeSet({
    required super.eventId,
    required super.deviceId,
    required super.userId,
    required super.occurredAt,
    required super.createdAt,
    required this.forUserId,
    required this.amountCents,
    required this.month,
  });

  final String forUserId;
  final int amountCents;
  final Month month;

  @override
  String get type => 'IncomeSet';

  @override
  Map<String, dynamic> payload() => {
        'forUserId': forUserId,
        'amountCents': amountCents,
        'month': month.toKey(),
      };
}

class QuestSet extends Event {
  const QuestSet({
    required super.eventId,
    required super.deviceId,
    required super.userId,
    required super.occurredAt,
    required super.createdAt,
    required this.questId,
    required this.name,
    required this.targetCents,
    required this.ownership,
    this.sliceHint,
    this.customSpriteSha256,
  });

  final String questId;
  final String name;
  final int targetCents;
  final PartyOwnership ownership;
  final String? sliceHint;
  final String? customSpriteSha256;

  @override
  String get type => 'QuestSet';

  @override
  Map<String, dynamic> payload() => {
        'questId': questId,
        'name': name,
        'targetCents': targetCents,
        'ownership': ownership.toJson(),
        if (sliceHint != null) 'sliceHint': sliceHint,
        if (customSpriteSha256 != null) 'customSpriteSha256': customSpriteSha256,
      };
}

class QuestAbandoned extends Event {
  const QuestAbandoned({
    required super.eventId,
    required super.deviceId,
    required super.userId,
    required super.occurredAt,
    required super.createdAt,
    required this.questId,
  });

  final String questId;

  @override
  String get type => 'QuestAbandoned';

  @override
  Map<String, dynamic> payload() => {'questId': questId};
}

class LeftoverAllocated extends Event {
  const LeftoverAllocated({
    required super.eventId,
    required super.deviceId,
    required super.userId,
    required super.occurredAt,
    required super.createdAt,
    required this.forUserId,
    required this.month,
    required this.sliceId,
    required this.allocations,
  });

  final String forUserId;
  final Month month;
  final String sliceId;
  final List<Allocation> allocations;

  @override
  String get type => 'LeftoverAllocated';

  @override
  Map<String, dynamic> payload() => {
        'forUserId': forUserId,
        'month': month.toKey(),
        'sliceId': sliceId,
        'allocations': [for (final a in allocations) a.toJson()],
      };
}

class GiftReceived extends Event {
  const GiftReceived({
    required super.eventId,
    required super.deviceId,
    required super.userId,
    required super.occurredAt,
    required super.createdAt,
    required this.forUserId,
    required this.amountCents,
    this.note,
  });

  final String forUserId;
  final int amountCents;
  final String? note;

  @override
  String get type => 'GiftReceived';

  @override
  Map<String, dynamic> payload() => {
        'forUserId': forUserId,
        'amountCents': amountCents,
        if (note != null) 'note': note,
      };
}

class PoolContributionMade extends Event {
  const PoolContributionMade({
    required super.eventId,
    required super.deviceId,
    required super.userId,
    required super.occurredAt,
    required super.createdAt,
    required this.fromUserId,
    required this.amountCents,
  });

  final String fromUserId;
  final int amountCents;

  @override
  String get type => 'PoolContributionMade';

  @override
  Map<String, dynamic> payload() =>
      {'fromUserId': fromUserId, 'amountCents': amountCents};
}

class PoolWithdrawalProposed extends Event {
  const PoolWithdrawalProposed({
    required super.eventId,
    required super.deviceId,
    required super.userId,
    required super.occurredAt,
    required super.createdAt,
    required this.proposalId,
    required this.byUserId,
    required this.amountCents,
    required this.purpose,
    required this.destination,
  });

  final String proposalId;
  final String byUserId;
  final int amountCents;
  final String purpose;
  final WithdrawalDestination destination;

  @override
  String get type => 'PoolWithdrawalProposed';

  @override
  Map<String, dynamic> payload() => {
        'proposalId': proposalId,
        'byUserId': byUserId,
        'amountCents': amountCents,
        'purpose': purpose,
        'destination': destination.toJson(),
      };
}

class PoolWithdrawalApproved extends Event {
  const PoolWithdrawalApproved({
    required super.eventId,
    required super.deviceId,
    required super.userId,
    required super.occurredAt,
    required super.createdAt,
    required this.proposalId,
    required this.byUserId,
  });

  final String proposalId;
  final String byUserId;

  @override
  String get type => 'PoolWithdrawalApproved';

  @override
  Map<String, dynamic> payload() =>
      {'proposalId': proposalId, 'byUserId': byUserId};
}

class PoolWithdrawalCancelled extends Event {
  const PoolWithdrawalCancelled({
    required super.eventId,
    required super.deviceId,
    required super.userId,
    required super.occurredAt,
    required super.createdAt,
    required this.proposalId,
  });

  final String proposalId;

  @override
  String get type => 'PoolWithdrawalCancelled';

  @override
  Map<String, dynamic> payload() => {'proposalId': proposalId};
}

class TaxRefundRecorded extends Event {
  const TaxRefundRecorded({
    required super.eventId,
    required super.deviceId,
    required super.userId,
    required super.occurredAt,
    required super.createdAt,
    required this.amountCents,
    this.note,
  });

  final int amountCents;
  final String? note;

  @override
  String get type => 'TaxRefundRecorded';

  @override
  Map<String, dynamic> payload() =>
      {'amountCents': amountCents, if (note != null) 'note': note};
}

class EmergencyFundSet extends Event {
  const EmergencyFundSet({
    required super.eventId,
    required super.deviceId,
    required super.userId,
    required super.occurredAt,
    required super.createdAt,
    required this.fundId,
    required this.name,
    this.petId,
  });

  final String fundId;
  final String name;
  final String? petId;

  @override
  String get type => 'EmergencyFundSet';

  @override
  Map<String, dynamic> payload() =>
      {'fundId': fundId, 'name': name, if (petId != null) 'petId': petId};
}

class PetSet extends Event {
  const PetSet({
    required super.eventId,
    required super.deviceId,
    required super.userId,
    required super.occurredAt,
    required super.createdAt,
    required this.petId,
    required this.name,
    this.customSpriteSha256,
  });

  final String petId;
  final String name;
  final String? customSpriteSha256;

  @override
  String get type => 'PetSet';

  @override
  Map<String, dynamic> payload() => {
        'petId': petId,
        'name': name,
        if (customSpriteSha256 != null) 'customSpriteSha256': customSpriteSha256,
      };
}

/// Declares or amends a household member (last-writer-wins by [memberId]).
/// Only `adult` members carry income, a vault and personal categories;
/// `dependent` and `pet` members are display-level party members. Retiring a
/// member is `active: false`. [descriptionText] is the user-written character
/// description used by text-mode adventure.
class MemberSet extends Event {
  const MemberSet({
    required super.eventId,
    required super.deviceId,
    required super.userId,
    required super.occurredAt,
    required super.createdAt,
    required this.memberId,
    required this.name,
    required this.role,
    this.active = true,
    this.customSpriteSha256,
    this.descriptionText,
  });

  final String memberId;
  final String name;
  final MemberRole role;
  final bool active;
  final String? customSpriteSha256;
  final String? descriptionText;

  @override
  String get type => 'MemberSet';

  @override
  Map<String, dynamic> payload() => {
        'memberId': memberId,
        'name': name,
        'role': role.name,
        'active': active,
        if (customSpriteSha256 != null) 'customSpriteSha256': customSpriteSha256,
        if (descriptionText != null) 'descriptionText': descriptionText,
      };
}

/// Sets the per-adult share table for [month]: a map of adult id to permille
/// weight. Carries forward until a later month overrides it; absent entirely,
/// shared costs split evenly. Odd cents on a shared cost go to the purchaser.
class GroupShareSet extends Event {
  const GroupShareSet({
    required super.eventId,
    required super.deviceId,
    required super.userId,
    required super.occurredAt,
    required super.createdAt,
    required this.month,
    required this.shares,
  });

  final Month month;
  final Map<String, int> shares;

  @override
  String get type => 'GroupShareSet';

  @override
  Map<String, dynamic> payload() => {
        'month': month.toKey(),
        'shares': {for (final e in shares.entries) e.key: e.value},
      };
}

/// Sets the war chest's savings target.
class GoalSet extends Event {
  const GoalSet({
    required super.eventId,
    required super.deviceId,
    required super.userId,
    required super.occurredAt,
    required super.createdAt,
    required this.targetCents,
  });

  final int targetCents;

  @override
  String get type => 'GoalSet';

  @override
  Map<String, dynamic> payload() => {'targetCents': targetCents};
}

class ReceiptAttached extends Event {
  const ReceiptAttached({
    required super.eventId,
    required super.deviceId,
    required super.userId,
    required super.occurredAt,
    required super.createdAt,
    required this.purchaseId,
    required this.sha256,
    required this.mimeType,
    required this.sizeBytes,
  });

  final String purchaseId;
  final String sha256;
  final String mimeType;
  final int sizeBytes;

  @override
  String get type => 'ReceiptAttached';

  @override
  Map<String, dynamic> payload() => {
        'purchaseId': purchaseId,
        'sha256': sha256,
        'mimeType': mimeType,
        'sizeBytes': sizeBytes,
      };
}

class ReceiptDetached extends Event {
  const ReceiptDetached({
    required super.eventId,
    required super.deviceId,
    required super.userId,
    required super.occurredAt,
    required super.createdAt,
    required this.purchaseId,
    required this.sha256,
  });

  final String purchaseId;
  final String sha256;

  @override
  String get type => 'ReceiptDetached';

  @override
  Map<String, dynamic> payload() =>
      {'purchaseId': purchaseId, 'sha256': sha256};
}

class AccountBalanceRecorded extends Event {
  const AccountBalanceRecorded({
    required super.eventId,
    required super.deviceId,
    required super.userId,
    required super.occurredAt,
    required super.createdAt,
    required this.accountId,
    required this.accountName,
    required this.kind,
    required this.balanceCents,
  });

  final String accountId;
  final String accountName;
  final AccountKind kind;
  final int balanceCents;

  @override
  String get type => 'AccountBalanceRecorded';

  @override
  Map<String, dynamic> payload() => {
        'accountId': accountId,
        'accountName': accountName,
        'kind': kind.name,
        'balanceCents': balanceCents,
      };
}

/// Changes a household setting. Known keys: `spoilsGraceDays` (int, default 7),
/// `dissolutionTithePct` (int, default 10), `showNetWorth` (bool).
class SettingChanged extends Event {
  const SettingChanged({
    required super.eventId,
    required super.deviceId,
    required super.userId,
    required super.occurredAt,
    required super.createdAt,
    required this.key,
    required this.value,
  });

  final String key;
  final Object? value;

  @override
  String get type => 'SettingChanged';

  @override
  Map<String, dynamic> payload() => {'key': key, 'value': value};
}

/// A cosmetic setting for the adventure skin. Domain-inert.
class CosmeticSet extends Event {
  const CosmeticSet({
    required super.eventId,
    required super.deviceId,
    required super.userId,
    required super.occurredAt,
    required super.createdAt,
    required this.key,
    required this.value,
  });

  final String key;
  final Object? value;

  @override
  String get type => 'CosmeticSet';

  @override
  Map<String, dynamic> payload() => {'key': key, 'value': value};
}
