part of '../state.dart';

/// A tracked net-worth account, derived at read time. [balanceCents] is the
/// last recorded balance; [currentValueCents] adds any transfers since and any
/// interest accrued from the recording instant (savings/debt only). Investments
/// are never auto-changed — their current value equals the last recording — but
/// go [stale] once their update cadence has lapsed.
class AccountBalance {
  const AccountBalance({
    required this.accountId,
    required this.name,
    required this.kind,
    required this.balanceCents,
    required this.currentValueCents,
    this.accruedInterestCents = 0,
    this.aprBps,
    this.accrualCadence,
    this.updateCadence,
    this.minPaymentCents,
    this.lastRecordedAt,
    this.stale = false,
  });

  final String accountId;
  final String name;
  final AccountKind kind;

  /// The last recorded balance (raw, before transfers or interest).
  final int balanceCents;

  /// Recorded balance + transfers since + accrued interest.
  final int currentValueCents;

  /// The interest portion of [currentValueCents] (0 when none accrues).
  final int accruedInterestCents;

  final int? aprBps;
  final AccountCadence? accrualCadence;
  final AccountCadence? updateCadence;
  final int? minPaymentCents;

  /// When the last balance was recorded, or null if the account has only ever
  /// been declared (a [TrackedAccountSet] with no balance yet).
  final DateTime? lastRecordedAt;

  /// True for an investment whose [updateCadence] has lapsed since the last
  /// recording — a "stale, update requested" nudge, never an auto-change.
  final bool stale;

  bool get isDebt => kind == AccountKind.debt;

  /// Debt contributes negatively to net worth.
  int get signedCents => isDebt ? -currentValueCents : currentValueCents;
}

/// Net-worth summary derived from the latest balance per account.
class NetWorthState {
  const NetWorthState({
    required this.accounts,
    required this.totalCents,
    required this.show,
  });

  final Map<String, AccountBalance> accounts;

  /// Signed household total: assets − debts, using each account's current value.
  final int totalCents;
  final bool show;

  /// Sum of non-debt current values.
  int get assetsCents => accounts.values
      .where((account) => !account.isDebt)
      .fold(0, (sum, account) => sum + account.currentValueCents);

  /// Sum of debt current values (a positive magnitude of what is owed).
  int get debtsCents => accounts.values
      .where((account) => account.isDebt)
      .fold(0, (sum, account) => sum + account.currentValueCents);

  /// Investments past their update cadence, needing a refresh nudge.
  List<AccountBalance> get staleAccounts =>
      accounts.values.where((account) => account.stale).toList()
        ..sort((first, second) => first.name.compareTo(second.name));
}
