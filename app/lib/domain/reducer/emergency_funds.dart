part of '../reducer.dart';

/// A scheduled monthly emergency-fund contribution.
class _FundContribution {
  _FundContribution(this.instant, this.amount, this.month);

  final DateTime instant;
  final int amount;
  final Month month;
}

/// A merged item on a fund's contribution/spend timeline. Contributions sort
/// before purchases at the same instant so a same-month contribution funds a
/// purchase before it can ransack the war chest.
class _FundTimelineItem implements Comparable<_FundTimelineItem> {
  _FundTimelineItem.contribution(this.instant, this.amount)
    : isContribution = true,
      purchase = null;

  _FundTimelineItem.purchase(PurchaseAdded emergencyPurchase)
    : isContribution = false,
      instant = emergencyPurchase.occurredAt,
      amount = emergencyPurchase.amountCents,
      purchase = emergencyPurchase;

  final DateTime instant;
  final int amount;
  final bool isContribution;
  final PurchaseAdded? purchase;

  @override
  int compareTo(_FundTimelineItem other) {
    final byInstant = instant.compareTo(other.instant);
    if (byInstant != 0) {
      return byInstant;
    }
    if (isContribution == other.isContribution) {
      return 0;
    }
    return isContribution ? -1 : 1;
  }
}

/// Emergency funds (reserve caches): the contribution schedule, spending,
/// and the ransack rule.
extension _EmergencyFunds on _HouseholdStateBuilder {
  /// Emergency-contribution schedule (accrues off the top every active month
  /// that has already started, regardless of spending). Months whose start
  /// instant is still in the future — reached only because the sweep extends
  /// to a recurring expense's future endMonth or a future-dated purchase —
  /// must not accrue yet.
  void _scheduleEmergencyContribution(
    SliceConfig config,
    Month month,
    Map<String, List<_FundContribution>> fundSchedule,
  ) {
    if (config.emergencyFundId != null &&
        config.emergencyContributionCents > 0 &&
        !month.startInstantUtc().isAfter(now)) {
      fundSchedule
          .putIfAbsent(config.emergencyFundId!, () => [])
          .add(
            _FundContribution(
              month.startInstantUtc(),
              config.emergencyContributionCents,
              month,
            ),
          );
    }
  }

  /// Emergency funds and ransacks (chronological per fund). An emergency
  /// purchase exceeding its fund draws the excess from the war chest without
  /// approval and records a ransack all adults see.
  Map<String, EmergencyFundState> _settleEmergencyFunds(
    Map<String, List<_FundContribution>> fundSchedule,
    Map<String, int> vacationDrawByFund,
    List<PurchaseAdded> emergencyPurchases,
  ) {
    final fundStates = <String, EmergencyFundState>{};
    final allFundIds = {
      ...fundConfigs.keys,
      ...fundSchedule.keys,
      ...vacationDrawByFund.keys,
    };
    for (final purchase in emergencyPurchases) {
      allFundIds.add((purchase.target as EmergencyCharge).fundId);
    }
    for (final fundId in allFundIds) {
      final timeline = <_FundTimelineItem>[
        ...(fundSchedule[fundId] ?? []).map(
          (contribution) => _FundTimelineItem.contribution(
            contribution.instant,
            contribution.amount,
          ),
        ),
        ...emergencyPurchases
            .where(
              (purchase) =>
                  (purchase.target as EmergencyCharge).fundId == fundId,
            )
            .map(_FundTimelineItem.purchase),
      ]..sort();

      var balance = 0;
      for (final item in timeline) {
        if (item.isContribution) {
          balance += item.amount;
        } else {
          final purchase = item.purchase!;
          if (purchase.amountCents <= balance) {
            balance -= purchase.amountCents;
          } else {
            final excess = purchase.amountCents - balance;
            balance = 0;
            ransacks.add(
              RansackRecord(
                fundId: fundId,
                excessCents: excess,
                purpose: purchase.note ?? purchase.merchant ?? '',
                occurredAt: purchase.occurredAt,
              ),
            );
            _addChest(-excess, purchase.occurredMonth);
          }
        }
      }

      // A vacation drawn from this fund reserves its budget off the top (the
      // leftover is returned on close); this can push the balance negative,
      // which the vacation dashboard surfaces as an over-reservation warning.
      balance -= vacationDrawByFund[fundId] ?? 0;

      final config = fundConfigs[fundId];
      fundStates[fundId] = EmergencyFundState(
        fundId: fundId,
        name: config?.name ?? fundId,
        balanceCents: balance,
        petId: config?.petId,
      );
    }
    return fundStates;
  }
}
