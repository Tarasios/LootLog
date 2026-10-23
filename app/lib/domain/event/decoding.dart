part of '../event.dart';

/// Decodes the type-specific part of an event from its [payload]. A type this
/// version does not know becomes an [UnknownEvent], stored and relayed verbatim.
Event _decodeEvent(
  String type,
  String eventId,
  String deviceId,
  String userId,
  DateTime occurredAt,
  DateTime createdAt,
  Map<String, dynamic> payload,
) {
  switch (type) {
    case 'PurchaseAdded':
      return PurchaseAdded(
        eventId: eventId,
        deviceId: deviceId,
        userId: userId,
        occurredAt: occurredAt,
        createdAt: createdAt,
        purchaseId: payload['purchaseId'] as String,
        target: ChargeTarget.fromJson((payload['target'] as Map).cast()),
        amountCents: payload['amountCents'] as int,
        shared: payload['shared'] as bool? ?? false,
        merchant: payload['merchant'] as String?,
        taxDeductible: payload['taxDeductible'] as bool?,
        note: payload['note'] as String?,
        amendsPurchaseId: payload['amendsPurchaseId'] as String?,
      );
    case 'PurchaseVoided':
      return PurchaseVoided(
        eventId: eventId,
        deviceId: deviceId,
        userId: userId,
        occurredAt: occurredAt,
        createdAt: createdAt,
        purchaseId: payload['purchaseId'] as String,
      );
    case 'BudgetSliceSet':
      return BudgetSliceSet(
        eventId: eventId,
        deviceId: deviceId,
        userId: userId,
        occurredAt: occurredAt,
        createdAt: createdAt,
        sliceId: payload['sliceId'] as String,
        name: payload['name'] as String,
        ownership: SliceOwnership.fromJson(
          (payload['ownership'] as Map).cast(),
        ),
        mainCategoryId: payload['mainCategoryId'] as String?,
        limitCents: payload['limitCents'] as int,
        poolTithePct: payload['poolTithePct'] as int,
        defaultLeftoverPolicy: LeftoverDestination.fromJson(
          (payload['defaultLeftoverPolicy'] as Map).cast(),
        ),
        taxDeductibleByDefault: payload['taxDeductibleByDefault'] as bool,
        emergencyContribution: payload['emergencyContribution'] == null
            ? null
            : EmergencyContribution.fromJson(
                (payload['emergencyContribution'] as Map).cast(),
              ),
        petId: payload['petId'] as String?,
        petOwnerIds:
            (payload['petOwnerIds'] as List?)?.cast<String>() ?? const [],
        priority: SlicePriority.fromName(payload['priority'] as String?),
      );
    case 'RecurringExpenseSet':
      return RecurringExpenseSet(
        eventId: eventId,
        deviceId: deviceId,
        userId: userId,
        occurredAt: occurredAt,
        createdAt: createdAt,
        expenseId: payload['expenseId'] as String,
        name: payload['name'] as String,
        ownership: PartyOwnership.fromJson(
          (payload['ownership'] as Map).cast(),
        ),
        kind: RecurringKind.values.byName(payload['kind'] as String),
        cadence: payload['cadence'] == null
            ? RecurringCadence.monthly
            : RecurringCadence.values.byName(payload['cadence'] as String),
        amountCents: payload['amountCents'] as int,
        dueDay: payload['dueDay'] as int? ?? 1,
        dueMonth: payload['dueMonth'] as int?,
        startMonth: Month.parse(payload['startMonth'] as String),
        endMonth: payload['endMonth'] == null
            ? null
            : Month.parse(payload['endMonth'] as String),
      );
    case 'VariableExpenseRecorded':
      return VariableExpenseRecorded(
        eventId: eventId,
        deviceId: deviceId,
        userId: userId,
        occurredAt: occurredAt,
        createdAt: createdAt,
        expenseId: payload['expenseId'] as String,
        month: Month.parse(payload['month'] as String),
        actualCents: payload['actualCents'] as int,
      );
    case 'IncomeSet':
      return IncomeSet(
        eventId: eventId,
        deviceId: deviceId,
        userId: userId,
        occurredAt: occurredAt,
        createdAt: createdAt,
        forUserId: payload['forUserId'] as String,
        amountCents: payload['amountCents'] as int,
        month: Month.parse(payload['month'] as String),
      );
    case 'DefaultIncomeSet':
      return DefaultIncomeSet(
        eventId: eventId,
        deviceId: deviceId,
        userId: userId,
        occurredAt: occurredAt,
        createdAt: createdAt,
        forUserId: payload['forUserId'] as String,
        amountCents: payload['amountCents'] as int,
        effectiveFromMonth: Month.parse(
          payload['effectiveFromMonth'] as String,
        ),
        estimatedHighCents: payload['estimatedHighCents'] as int?,
      );
    case 'QuestSet':
      return QuestSet(
        eventId: eventId,
        deviceId: deviceId,
        userId: userId,
        occurredAt: occurredAt,
        createdAt: createdAt,
        questId: payload['questId'] as String,
        name: payload['name'] as String,
        targetCents: payload['targetCents'] as int,
        ownership: PartyOwnership.fromJson(
          (payload['ownership'] as Map).cast(),
        ),
        mainCategoryId: payload['mainCategoryId'] as String?,
        sliceHint: payload['sliceHint'] as String?,
        customSpriteSha256: payload['customSpriteSha256'] as String?,
        descriptionText: payload['descriptionText'] as String?,
      );
    case 'QuestAbandoned':
      return QuestAbandoned(
        eventId: eventId,
        deviceId: deviceId,
        userId: userId,
        occurredAt: occurredAt,
        createdAt: createdAt,
        questId: payload['questId'] as String,
      );
    case 'LeftoverAllocated':
      return LeftoverAllocated(
        eventId: eventId,
        deviceId: deviceId,
        userId: userId,
        occurredAt: occurredAt,
        createdAt: createdAt,
        forUserId: payload['forUserId'] as String,
        month: Month.parse(payload['month'] as String),
        sliceId: payload['sliceId'] as String,
        allocations: [
          for (final allocation in payload['allocations'] as List)
            Allocation.fromJson((allocation as Map).cast()),
        ],
      );
    case 'GiftReceived':
      return GiftReceived(
        eventId: eventId,
        deviceId: deviceId,
        userId: userId,
        occurredAt: occurredAt,
        createdAt: createdAt,
        forUserId: payload['forUserId'] as String,
        amountCents: payload['amountCents'] as int,
        note: payload['note'] as String?,
      );
    case 'PoolContributionMade':
      return PoolContributionMade(
        eventId: eventId,
        deviceId: deviceId,
        userId: userId,
        occurredAt: occurredAt,
        createdAt: createdAt,
        fromUserId: payload['fromUserId'] as String,
        amountCents: payload['amountCents'] as int,
      );
    case 'PoolWithdrawalProposed':
      return PoolWithdrawalProposed(
        eventId: eventId,
        deviceId: deviceId,
        userId: userId,
        occurredAt: occurredAt,
        createdAt: createdAt,
        proposalId: payload['proposalId'] as String,
        byUserId: payload['byUserId'] as String,
        amountCents: payload['amountCents'] as int,
        purpose: payload['purpose'] as String,
        destination: WithdrawalDestination.fromJson(
          (payload['destination'] as Map).cast(),
        ),
      );
    case 'PoolWithdrawalApproved':
      return PoolWithdrawalApproved(
        eventId: eventId,
        deviceId: deviceId,
        userId: userId,
        occurredAt: occurredAt,
        createdAt: createdAt,
        proposalId: payload['proposalId'] as String,
        byUserId: payload['byUserId'] as String,
      );
    case 'PoolWithdrawalCancelled':
      return PoolWithdrawalCancelled(
        eventId: eventId,
        deviceId: deviceId,
        userId: userId,
        occurredAt: occurredAt,
        createdAt: createdAt,
        proposalId: payload['proposalId'] as String,
      );
    case 'TaxRefundRecorded':
      return TaxRefundRecorded(
        eventId: eventId,
        deviceId: deviceId,
        userId: userId,
        occurredAt: occurredAt,
        createdAt: createdAt,
        amountCents: payload['amountCents'] as int,
        note: payload['note'] as String?,
      );
    case 'EmergencyFundSet':
      return EmergencyFundSet(
        eventId: eventId,
        deviceId: deviceId,
        userId: userId,
        occurredAt: occurredAt,
        createdAt: createdAt,
        fundId: payload['fundId'] as String,
        name: payload['name'] as String,
        petId: payload['petId'] as String?,
      );
    case 'PetSet':
      return PetSet(
        eventId: eventId,
        deviceId: deviceId,
        userId: userId,
        occurredAt: occurredAt,
        createdAt: createdAt,
        petId: payload['petId'] as String,
        name: payload['name'] as String,
        customSpriteSha256: payload['customSpriteSha256'] as String?,
      );
    case 'MainCategorySet':
      return MainCategorySet(
        eventId: eventId,
        deviceId: deviceId,
        userId: userId,
        occurredAt: occurredAt,
        createdAt: createdAt,
        id: payload['id'] as String,
        name: payload['name'] as String,
        colorArgb: payload['colorArgb'] as int,
        sortOrder: payload['sortOrder'] as int,
      );
    case 'MemberSet':
      return MemberSet(
        eventId: eventId,
        deviceId: deviceId,
        userId: userId,
        occurredAt: occurredAt,
        createdAt: createdAt,
        memberId: payload['memberId'] as String,
        name: payload['name'] as String,
        role: MemberRole.values.byName(payload['role'] as String),
        active: payload['active'] as bool? ?? true,
        customSpriteSha256: payload['customSpriteSha256'] as String?,
        descriptionText: payload['descriptionText'] as String?,
        fundedByUserId: payload['fundedByUserId'] as String?,
      );
    case 'GroupShareSet':
      return GroupShareSet(
        eventId: eventId,
        deviceId: deviceId,
        userId: userId,
        occurredAt: occurredAt,
        createdAt: createdAt,
        month: Month.parse(payload['month'] as String),
        shares: {
          for (final entry in (payload['shares'] as Map).entries)
            entry.key as String: entry.value as int,
        },
      );
    case 'GoalSet':
      return GoalSet(
        eventId: eventId,
        deviceId: deviceId,
        userId: userId,
        occurredAt: occurredAt,
        createdAt: createdAt,
        targetCents: payload['targetCents'] as int,
      );
    case 'ReceiptAttached':
      return ReceiptAttached(
        eventId: eventId,
        deviceId: deviceId,
        userId: userId,
        occurredAt: occurredAt,
        createdAt: createdAt,
        purchaseId: payload['purchaseId'] as String,
        sha256: payload['sha256'] as String,
        mimeType: payload['mimeType'] as String,
        sizeBytes: payload['sizeBytes'] as int,
      );
    case 'ReceiptDetached':
      return ReceiptDetached(
        eventId: eventId,
        deviceId: deviceId,
        userId: userId,
        occurredAt: occurredAt,
        createdAt: createdAt,
        purchaseId: payload['purchaseId'] as String,
        sha256: payload['sha256'] as String,
      );
    case 'TrackedAccountSet':
      return TrackedAccountSet(
        eventId: eventId,
        deviceId: deviceId,
        userId: userId,
        occurredAt: occurredAt,
        createdAt: createdAt,
        accountId: payload['accountId'] as String,
        name: payload['name'] as String,
        kind: AccountKind.values.byName(payload['kind'] as String),
        aprBps: payload['aprBps'] as int?,
        accrualCadence: payload['accrualCadence'] == null
            ? null
            : AccountCadence.values.byName(payload['accrualCadence'] as String),
        updateCadence: payload['updateCadence'] == null
            ? null
            : AccountCadence.values.byName(payload['updateCadence'] as String),
        minPaymentCents: payload['minPaymentCents'] as int?,
      );
    case 'AccountBalanceRecorded':
      return AccountBalanceRecorded(
        eventId: eventId,
        deviceId: deviceId,
        userId: userId,
        occurredAt: occurredAt,
        createdAt: createdAt,
        accountId: payload['accountId'] as String,
        accountName: payload['accountName'] as String,
        kind: AccountKind.values.byName(payload['kind'] as String),
        balanceCents: payload['balanceCents'] as int,
      );
    case 'AccountTransferRecorded':
      return AccountTransferRecorded(
        eventId: eventId,
        deviceId: deviceId,
        userId: userId,
        occurredAt: occurredAt,
        createdAt: createdAt,
        accountId: payload['accountId'] as String,
        amountCents: payload['amountCents'] as int,
        direction: TransferDirection.values.byName(
          payload['direction'] as String,
        ),
        note: payload['note'] as String?,
      );
    case 'SettingChanged':
      return SettingChanged(
        eventId: eventId,
        deviceId: deviceId,
        userId: userId,
        occurredAt: occurredAt,
        createdAt: createdAt,
        key: payload['key'] as String,
        value: payload['value'],
      );
    case 'VacationSet':
      return VacationSet(
        eventId: eventId,
        deviceId: deviceId,
        userId: userId,
        occurredAt: occurredAt,
        createdAt: createdAt,
        vacationId: payload['vacationId'] as String,
        name: payload['name'] as String,
        fund: VacationFund.fromJson((payload['fund'] as Map).cast()),
        startDate: DateTime.parse(payload['startDate'] as String).toUtc(),
        endDate: DateTime.parse(payload['endDate'] as String).toUtc(),
        categories: [
          for (final category in payload['categories'] as List)
            VacationCategory.fromJson((category as Map).cast()),
        ],
      );
    case 'VacationClosed':
      return VacationClosed(
        eventId: eventId,
        deviceId: deviceId,
        userId: userId,
        occurredAt: occurredAt,
        createdAt: createdAt,
        vacationId: payload['vacationId'] as String,
      );
    case 'CosmeticSet':
      return CosmeticSet(
        eventId: eventId,
        deviceId: deviceId,
        userId: userId,
        occurredAt: occurredAt,
        createdAt: createdAt,
        key: payload['key'] as String,
        value: payload['value'],
      );
    case 'GameRewardGranted':
      return GameRewardGranted(
        eventId: eventId,
        deviceId: deviceId,
        userId: userId,
        occurredAt: occurredAt,
        createdAt: createdAt,
        rewardId: payload['rewardId'] as String,
        kind: RewardKind.values.byName(payload['kind'] as String),
        sourceRef: payload['sourceRef'] as String,
        grantedAt: DateTime.parse(payload['grantedAt'] as String).toUtc(),
      );
    case 'ShortfallCovered':
      return ShortfallCovered(
        eventId: eventId,
        deviceId: deviceId,
        userId: userId,
        occurredAt: occurredAt,
        createdAt: createdAt,
        purchaseId: payload['purchaseId'] as String,
        source: CoverSource.fromJson((payload['source'] as Map).cast()),
        amountCents: payload['amountCents'] as int,
      );
    case 'AllowanceAdvanceProposed':
      return AllowanceAdvanceProposed(
        eventId: eventId,
        deviceId: deviceId,
        userId: userId,
        occurredAt: occurredAt,
        createdAt: createdAt,
        advanceId: payload['advanceId'] as String,
        byUserId: payload['byUserId'] as String,
        sliceId: payload['sliceId'] as String,
        amountCents: payload['amountCents'] as int,
        months: payload['months'] as int? ?? 1,
        purchaseId: payload['purchaseId'] as String?,
      );
    case 'AllowanceAdvanceApproved':
      return AllowanceAdvanceApproved(
        eventId: eventId,
        deviceId: deviceId,
        userId: userId,
        occurredAt: occurredAt,
        createdAt: createdAt,
        advanceId: payload['advanceId'] as String,
        byUserId: payload['byUserId'] as String,
      );
    case 'AllowanceAdvanceCancelled':
      return AllowanceAdvanceCancelled(
        eventId: eventId,
        deviceId: deviceId,
        userId: userId,
        occurredAt: occurredAt,
        createdAt: createdAt,
        advanceId: payload['advanceId'] as String,
      );
    case 'NoSpendCheckIn':
      return NoSpendCheckedIn(
        eventId: eventId,
        deviceId: deviceId,
        userId: userId,
        occurredAt: occurredAt,
        createdAt: createdAt,
      );
    case 'ReconcileCompleted':
      return ReconcileCompleted(
        eventId: eventId,
        deviceId: deviceId,
        userId: userId,
        occurredAt: occurredAt,
        createdAt: createdAt,
        weekStart: CalendarDay.parse(payload['weekStart'] as String),
      );
    default:
      // A type this version doesn't know (written by a newer release). Keep
      // it verbatim so it is stored and relayed intact; the reducer ignores
      // it. This is what lets new event types ship without breaking sync.
      return UnknownEvent(
        eventId: eventId,
        deviceId: deviceId,
        userId: userId,
        occurredAt: occurredAt,
        createdAt: createdAt,
        rawType: type,
        rawPayload: payload,
      );
  }
}
