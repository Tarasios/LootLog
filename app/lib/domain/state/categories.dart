part of '../state.dart';

/// A **main category** — the coarse grouping every budget category belongs to.
/// Its [colorArgb] is the single source of colour for the monthly spend report
/// (a pie by main category) and is the key used for quest-tithe matching. The
/// eight documented defaults are [defaultMainCategories]; households may rename,
/// recolour, or add to them via `MainCategorySet` events (last-writer-wins).
class MainCategory {
  const MainCategory({
    required this.id,
    required this.name,
    required this.colorArgb,
    required this.sortOrder,
  });

  final String id;
  final String name;

  /// A 32-bit ARGB colour (e.g. `0xFF4E79A7`).
  final int colorArgb;
  final int sortOrder;

  MainCategory copyWith({String? name, int? colorArgb, int? sortOrder}) =>
      MainCategory(
        id: id,
        name: name ?? this.name,
        colorArgb: colorArgb ?? this.colorArgb,
        sortOrder: sortOrder ?? this.sortOrder,
      );

  @override
  bool operator ==(Object other) =>
      other is MainCategory &&
      other.id == id &&
      other.name == name &&
      other.colorArgb == colorArgb &&
      other.sortOrder == sortOrder;

  @override
  int get hashCode => Object.hash(id, name, colorArgb, sortOrder);
}

/// The eight documented default main categories, in display order. Their colours
/// (a colourblind-friendly qualitative palette) drive the spend report. The
/// reducer always seeds these, so every household has them even with no
/// `MainCategorySet` events on the log.
const List<MainCategory> defaultMainCategories = [
  MainCategory(
    id: 'housing',
    name: 'Housing',
    colorArgb: 0xFF4E79A7,
    sortOrder: 0,
  ),
  MainCategory(id: 'food', name: 'Food', colorArgb: 0xFFF28E2B, sortOrder: 1),
  MainCategory(
    id: 'transport',
    name: 'Transport',
    colorArgb: 0xFFE15759,
    sortOrder: 2,
  ),
  MainCategory(
    id: 'health',
    name: 'Health',
    colorArgb: 0xFF76B7B2,
    sortOrder: 3,
  ),
  MainCategory(
    id: 'entertainment',
    name: 'Entertainment',
    colorArgb: 0xFF59A14F,
    sortOrder: 4,
  ),
  MainCategory(id: 'pets', name: 'Pets', colorArgb: 0xFFEDC948, sortOrder: 5),
  MainCategory(
    id: 'savings',
    name: 'Savings',
    colorArgb: 0xFFB07AA1,
    sortOrder: 6,
  ),
  MainCategory(id: 'misc', name: 'Misc', colorArgb: 0xFF9C755F, sortOrder: 7),
];

/// The configuration of a budget category (internal type name retained;
/// `BudgetSliceSet` stays on the wire), plus the month it first appeared.
class SliceConfig {
  const SliceConfig({
    required this.sliceId,
    required this.name,
    required this.ownership,
    required this.limitCents,
    required this.poolTithePct,
    required this.defaultLeftoverPolicy,
    required this.taxDeductibleByDefault,
    required this.createdMonth,
    this.mainCategoryId,
    this.emergencyFundId,
    this.emergencyContributionCents = 0,
    this.petId,
    this.petOwnerIds = const [],
    this.priority = SlicePriority.important,
  });

  final String sliceId;
  final String name;
  final SliceOwnership ownership;
  final int limitCents;
  final int poolTithePct;
  final LeftoverDestination defaultLeftoverPolicy;
  final bool taxDeductibleByDefault;
  final Month createdMonth;

  /// The [MainCategory] this budget category rolls up to, or null when
  /// unassigned (older categories, or ones created before a main category was
  /// picked). Reports bucket unassigned spend under "Uncategorized".
  final String? mainCategoryId;
  final String? emergencyFundId;
  final int emergencyContributionCents;
  final String? petId;

  /// The pet members this category belongs to (a shared pet budget). Empty
  /// for non-pet categories. Planning surfaces attribute the limit to each
  /// pet's funding source ([MemberState.fundedByUserId]) in equal parts.
  final List<String> petOwnerIds;

  /// How essential this category is (advisory; orders default OVERBUDGET
  /// payments and drives "spend the fun money first" suggestions).
  final SlicePriority priority;

  bool get isGroup => ownership is GroupSlice;

  String? get ownerUserId =>
      ownership is PersonalSlice ? (ownership as PersonalSlice).userId : null;

  /// The limit less any monthly emergency contribution.
  int get baseEffectiveLimitCents => limitCents - emergencyContributionCents;
}

/// Derived per-slice, per-month figures.
class SliceMonth {
  const SliceMonth({
    required this.sliceId,
    required this.month,
    required this.isGroup,
    required this.ownerUserId,
    required this.effectiveLimitCents,
    required this.spentCents,
    required this.leftoverCents,
    required this.carryInCents,
    required this.carryOutCents,
    required this.overspendCents,
    required this.resolved,
    this.lockedCents = 0,
    this.fromSavingsCents = 0,
    this.savingsCents = 0,
    this.savingsTaxPaidCents = 0,
    this.coveredCents = 0,
    this.trimmedCents = 0,
  });

  final String sliceId;
  final Month month;
  final bool isGroup;
  final String? ownerUserId;

  /// `limit − emergency contribution + carry-in`.
  final int effectiveLimitCents;
  final int spentCents;
  final int leftoverCents;
  final int carryInCents;
  final int carryOutCents;
  final int overspendCents;

  /// Whether the month's leftover has been resolved (an allocation event
  /// exists, or the grace period has lapsed and the default policy applied).
  final bool resolved;

  /// Funding withheld this month to cover an outstanding OVERBUDGET debt: the
  /// category is locked for this portion of its budget (fully locked when the
  /// whole limit is eaten). Recognised as debt payment once the month closes.
  final int lockedCents;

  /// Savings rules only: spending this month that the category's savings paid
  /// for (after the monthly allowance ran out).
  final int fromSavingsCents;

  /// Savings rules only: the category savings balance after this month's
  /// spending, before this month's month-end moves.
  final int savingsCents;

  /// Savings rules only: the tax [savingsCents] has already paid, so moving it
  /// at month end only charges the difference.
  final int savingsTaxPaidCents;

  /// Savings rules only: spending covered from elsewhere (the general pool or
  /// an approved advance), so it never counted against this category.
  final int coveredCents;

  /// Savings rules only: allowance withheld this month to repay an advance.
  final int trimmedCents;

  bool get overspent => overspendCents > 0;

  bool get locked => lockedCents > 0;
}

/// The OVERBUDGET: unsettled overspending of a personal category. Created at
/// month close for whatever the owner's vault could not cover, paid down by
/// leftover attacks (`OverbudgetPayment`, category-match tithed) and by the
/// locked category's own funding at each subsequent close, until cleared.
class OverbudgetState {
  const OverbudgetState({
    required this.sliceId,
    required this.ownerUserId,
    required this.accruedCents,
    required this.outstandingCents,
    this.kind = DebtKind.overbudget,
  });

  /// The indebted category — or `provisions:<expenseId>` for a bill top-up.
  final String sliceId;
  final String ownerUserId;

  /// An overspent category (the OVERBUDGET) or a variable bill's top-up.
  final DebtKind kind;

  /// Total overflow that ever became debt on this category.
  final int accruedCents;

  /// What still has to be paid; the category stays locked while > 0.
  final int outstandingCents;

  int get paidCents => accruedCents - outstandingCents;

  bool get settled => outstandingCents == 0;
}
