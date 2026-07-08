/// Month-end spend report math: a pure projection over [HouseholdState] that the
/// report screen renders. Two products: a per-budget-category budgeted/spent/
/// leftover table, and spend aggregated by **main category** (the pie). Both can
/// be scoped to the whole household or a single adult. Pure Dart, zero Flutter
/// imports — the reducer already did the money math; this only groups it.
library;

import 'state.dart';
import 'time.dart';

/// The synthetic bucket for spend on categories with no (or an unknown) main
/// category. Kept out of [defaultMainCategories] so it never appears as a
/// pickable option, only as a report grouping.
const MainCategory uncategorizedMainCategory = MainCategory(
  id: '',
  name: 'Uncategorized',
  colorArgb: 0xFF9E9E9E,
  sortOrder: 1 << 30,
);

/// One row of the budgeted/spent/leftover table: a single budget category in a
/// given month.
class ReportCategoryRow {
  const ReportCategoryRow({
    required this.categoryId,
    required this.name,
    required this.mainCategoryId,
    required this.isGroup,
    required this.ownerUserId,
    required this.budgetedCents,
    required this.spentCents,
    required this.leftoverCents,
  });

  final String categoryId;
  final String name;
  final String? mainCategoryId;
  final bool isGroup;
  final String? ownerUserId;

  /// The month's effective limit (limit − emergency contribution + carry-in).
  final int budgetedCents;
  final int spentCents;

  /// `max(0, budgeted − spent)`.
  final int leftoverCents;

  bool get overspent => spentCents > budgetedCents;
}

/// A slice of the spend pie: total spend rolled up to one main category.
class MainCategorySpend {
  const MainCategorySpend({
    required this.mainCategory,
    required this.spentCents,
  });

  final MainCategory mainCategory;
  final int spentCents;

  String get id => mainCategory.id;
  String get name => mainCategory.name;
  int get colorArgb => mainCategory.colorArgb;
}

/// The full month report for a scope (household or one adult).
class MonthReport {
  const MonthReport({
    required this.month,
    required this.userId,
    required this.categories,
    required this.byMainCategory,
  });

  final Month month;

  /// The adult this report is scoped to, or null for the whole household.
  final String? userId;

  /// The budgeted/spent/leftover rows, sorted by name.
  final List<ReportCategoryRow> categories;

  /// Spend rolled up by main category, sorted by the main category's sort order.
  /// Only main categories with non-zero spend appear (an empty slice is not
  /// drawn on the pie).
  final List<MainCategorySpend> byMainCategory;

  bool get isHousehold => userId == null;

  int get totalBudgetedCents =>
      categories.fold(0, (a, r) => a + r.budgetedCents);
  int get totalSpentCents => categories.fold(0, (a, r) => a + r.spentCents);
  int get totalLeftoverCents =>
      categories.fold(0, (a, r) => a + r.leftoverCents);
}

/// Builds the [MonthReport] for [month]. Household scope (default) includes every
/// budget category active that month; passing [userId] scopes it to that adult's
/// personal categories (group categories are household-level and excluded).
MonthReport buildMonthReport(
  HouseholdState state,
  Month month, {
  String? userId,
}) {
  final rows = <ReportCategoryRow>[];
  final spendByMain = <String, int>{}; // resolved main-category id -> cents

  for (final cfg in state.slices.values) {
    if (cfg.createdMonth.isAfter(month)) continue;
    if (userId != null && (cfg.isGroup || cfg.ownerUserId != userId)) {
      continue;
    }

    final sm = state.sliceMonth(cfg.sliceId, month);
    final budgeted = sm?.effectiveLimitCents ?? cfg.baseEffectiveLimitCents;
    final spent = sm?.spentCents ?? 0;
    final leftover = sm?.leftoverCents ?? (budgeted > spent ? budgeted - spent : 0);

    rows.add(ReportCategoryRow(
      categoryId: cfg.sliceId,
      name: cfg.name,
      mainCategoryId: cfg.mainCategoryId,
      isGroup: cfg.isGroup,
      ownerUserId: cfg.ownerUserId,
      budgetedCents: budgeted,
      spentCents: spent,
      leftoverCents: leftover,
    ));

    if (spent > 0) {
      final resolved = _resolveMain(state, cfg.mainCategoryId).id;
      spendByMain[resolved] = (spendByMain[resolved] ?? 0) + spent;
    }
  }

  rows.sort((a, b) => a.name.compareTo(b.name));

  final byMain = <MainCategorySpend>[
    for (final entry in spendByMain.entries)
      MainCategorySpend(
        mainCategory: _resolveMainById(state, entry.key),
        spentCents: entry.value,
      ),
  ]..sort((a, b) {
      final c = a.mainCategory.sortOrder.compareTo(b.mainCategory.sortOrder);
      return c != 0 ? c : a.name.compareTo(b.name);
    });

  return MonthReport(
    month: month,
    userId: userId,
    categories: rows,
    byMainCategory: byMain,
  );
}

/// Resolves a category's `mainCategoryId` to a [MainCategory], falling back to
/// [uncategorizedMainCategory] for null or unknown ids.
MainCategory _resolveMain(HouseholdState state, String? id) {
  if (id == null) return uncategorizedMainCategory;
  return state.mainCategories[id] ?? uncategorizedMainCategory;
}

MainCategory _resolveMainById(HouseholdState state, String resolvedId) =>
    resolvedId.isEmpty
        ? uncategorizedMainCategory
        : (state.mainCategories[resolvedId] ?? uncategorizedMainCategory);
