part of '../reducer.dart';

/// Days in one period of each account cadence.
const Map<AccountCadence, int> _cadenceDays = {
  AccountCadence.daily: 1,
  AccountCadence.monthly: 30,
  AccountCadence.quarterly: 91,
  AccountCadence.annually: 365,
};

/// Periods per year of each account cadence.
const Map<AccountCadence, int> _cadencePerYear = {
  AccountCadence.daily: 365,
  AccountCadence.monthly: 12,
  AccountCadence.quarterly: 4,
  AccountCadence.annually: 1,
};

/// Net worth from tracked accounts — never budget money. Savings and debt
/// accounts accrue interest since the last recording; investments are never
/// auto-changed but go stale past their update cadence.
extension _NetWorthDerivation on _HouseholdStateBuilder {
  /// Every account with either a config declaration or at least one recorded
  /// balance surfaces. Transfers adjust the balance from the last recording.
  NetWorthState _netWorth() {
    final accountIds = <String>{
      ...accountConfigs.keys,
      ...latestAccountBalances.keys,
    };
    final transfersByAccount = <String, List<AccountTransferRecorded>>{};
    for (final transfer in accountTransfers) {
      transfersByAccount
          .putIfAbsent(transfer.accountId, () => [])
          .add(transfer);
    }
    final accountBalances = <String, AccountBalance>{
      for (final accountId in accountIds)
        accountId: _accountBalance(
          accountId,
          transfersByAccount[accountId] ?? const <AccountTransferRecorded>[],
        ),
    };
    final netWorthTotal = accountBalances.values.fold(
      0,
      (sum, account) => sum + account.signedCents,
    );
    return NetWorthState(
      accounts: accountBalances,
      totalCents: netWorthTotal,
      show: settings.showNetWorth,
    );
  }

  AccountBalance _accountBalance(
    String accountId,
    List<AccountTransferRecorded> transfers,
  ) {
    final config = accountConfigs[accountId];
    final latest = latestAccountBalances[accountId];
    // Config wins for name/kind; fall back to the latest balance's inline
    // fields (legacy AccountBalanceRecorded carried both).
    final kind = config?.kind ?? latest?.kind ?? AccountKind.savings;
    final name = config?.name ?? latest?.accountName ?? accountId;
    final recordedCents = latest?.balanceCents ?? 0;
    final recordedAt = latest?.occurredAt;

    // Transfers after the last recording adjust the base value.
    var netTransfers = 0;
    for (final transfer in transfers) {
      if (recordedAt == null || transfer.occurredAt.isAfter(recordedAt)) {
        netTransfers += transfer.direction == TransferDirection.deposit
            ? transfer.amountCents
            : -transfer.amountCents;
      }
    }
    final baseCents = recordedCents + netTransfers;

    final interest = kind == AccountKind.investment
        ? 0
        : _accruedInterest(
            baseCents,
            config?.aprBps,
            config?.accrualCadence,
            recordedAt,
          );
    final stale =
        kind == AccountKind.investment &&
        _isStale(config?.updateCadence, recordedAt);

    return AccountBalance(
      accountId: accountId,
      name: name,
      kind: kind,
      balanceCents: recordedCents,
      currentValueCents: baseCents + interest,
      accruedInterestCents: interest,
      aprBps: config?.aprBps,
      accrualCadence: config?.accrualCadence,
      updateCadence: config?.updateCadence,
      minPaymentCents: config?.minPaymentCents,
      lastRecordedAt: recordedAt,
      stale: stale,
    );
  }

  /// Interest accrued on [baseCents] from [since] to [now] for the given rate
  /// and cadence, by completed compounding periods (no partial-period
  /// accrual). Zero when any input is missing or no full period has elapsed.
  int _accruedInterest(
    int baseCents,
    int? aprBps,
    AccountCadence? cadence,
    DateTime? since,
  ) {
    if (aprBps == null || aprBps == 0 || cadence == null || since == null) {
      return 0;
    }
    final elapsedDays = now.difference(since).inDays;
    if (elapsedDays <= 0) {
      return 0;
    }
    final completedPeriods = elapsedDays ~/ _cadenceDays[cadence]!;
    if (completedPeriods <= 0) {
      return 0;
    }
    final yearFraction = completedPeriods / _cadencePerYear[cadence]!;
    return (baseCents * (aprBps / 10000.0) * yearFraction).round();
  }

  /// Whether a manual value recorded at [since] has gone stale relative to its
  /// [cadence] (one full cadence has lapsed with no fresh recording).
  bool _isStale(AccountCadence? cadence, DateTime? since) {
    if (cadence == null || since == null) {
      return false;
    }
    return now.difference(since).inDays > _cadenceDays[cadence]!;
  }
}
