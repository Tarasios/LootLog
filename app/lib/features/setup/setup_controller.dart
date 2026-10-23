/// Mutable draft state for the first-run onboarding wizard. Collects the party,
/// incomes, accounts, expenses, budget and first goal as the user steps through,
/// then hands an immutable [OnboardingInput] to the pure [buildOnboardingEvents]
/// model. Keeping the widget-facing mutable state here keeps `setup_screen.dart`
/// about layout, and the money math (each adult's remaining-to-allocate counter)
/// unit-checkable through the pure model it feeds.
library;

import 'package:flutter/foundation.dart';

import '../../domain/ids.dart';
import '../../domain/state.dart' show MainCategory, defaultMainCategories;
import '../settings/play_mode.dart';
import 'onboarding_plan.dart';

/// A live per-adult allocation summary shown on the budget step: income minus
/// this adult's share of the group burden and their own personal burden.
class AdultAllocation {
  const AdultAllocation({
    required this.adultId,
    required this.incomeCents,
    required this.groupShareCents,
    required this.personalBudgetCents,
    required this.personalFixedCents,
  });

  final String adultId;
  final int incomeCents;

  /// This adult's share of group category limits + shared fixed expenses.
  final int groupShareCents;

  /// Their personal category limits this month.
  final int personalBudgetCents;

  /// Their personal fixed expenses this month.
  final int personalFixedCents;

  int get committedCents =>
      groupShareCents + personalBudgetCents + personalFixedCents;

  /// What remains to allocate. The wizard nudges each adult toward zero.
  int get unallocatedCents => incomeCents - committedCents;
}

/// Holds every draft the wizard collects and rebuilds the derived helpers as the
/// user edits. A [ChangeNotifier] so steps rebuild on change.
class SetupController extends ChangeNotifier {
  String timezone = 'America/Vancouver';
  final List<DraftMember> members = [];
  String? meLocalId;

  /// Adult localId → default monthly income in cents (0 allowed).
  final Map<String, int> income = {};

  final List<DraftAccount> accounts = [];
  final List<DraftFixedExpense> fixedExpenses = [];
  final List<DraftCategory> categories = [];

  /// The editable main-category list, seeded from the app defaults. Renames
  /// and additions here become `MainCategorySet` events at finish.
  final List<MainCategory> mainCategories = [...defaultMainCategories];

  /// Adult localId → permille. Null means "even split" (written as such).
  Map<String, int>? shares;

  DraftQuest? firstQuest;
  /// Each adult's play mode (localId → mode); unset adults are Adventure.
  final Map<String, PlayMode> playModes = {};

  /// [localId]'s chosen play mode (Adventure unless set otherwise).
  PlayMode modeOf(String localId) =>
      playModes[localId] ?? PlayPrefs.defaults.mode;

  List<DraftMember> get adults =>
      members.where((member) => member.isAdult).toList(growable: false);
  List<DraftMember> get pets =>
      members.where((member) => member.role == DraftRole.pet).toList(growable: false);

  bool get hasAdult => adults.isNotEmpty;

  DraftMember? memberById(String id) {
    for (final member in members) {
      if (member.localId == id) return member;
    }
    return null;
  }

  // ---- Party ---------------------------------------------------------------

  String addMember(
    DraftRole role,
    String name, {
    String? descriptionText,
    String? spriteSha256,
    String? fundedByUserId,
  }) {
    final id = uuidv7();
    members.add(DraftMember(
      localId: id,
      role: role,
      name: name,
      descriptionText: descriptionText,
      spriteSha256: spriteSha256,
      fundedByUserId: role == DraftRole.pet ? fundedByUserId : null,
    ));
    // The first adult becomes "me" until the user chooses otherwise.
    if (role == DraftRole.adult && meLocalId == null) meLocalId = id;
    notifyListeners();
    return id;
  }

  void updateMember(
    String localId, {
    required String name,
    String? descriptionText,
    String? spriteSha256,
    String? fundedByUserId,
  }) {
    final i = members.indexWhere((member) => member.localId == localId);
    if (i < 0) return;
    final old = members[i];
    members[i] = DraftMember(
      localId: old.localId,
      role: old.role,
      name: name,
      descriptionText: descriptionText,
      spriteSha256: spriteSha256,
      fundedByUserId: old.role == DraftRole.pet ? fundedByUserId : null,
    );
    notifyListeners();
  }

  void removeMember(String localId) {
    members.removeWhere((member) => member.localId == localId);
    income.remove(localId);
    if (meLocalId == localId) {
      meLocalId = adults.isEmpty ? null : adults.first.localId;
    }
    // Drop personal items owned by the removed member.
    fixedExpenses.removeWhere((expense) => !expense.shared && expense.ownerLocalId == localId);
    categories.removeWhere((category) => !category.group && category.ownerLocalId == localId);
    notifyListeners();
  }

  void setMe(String adultId) {
    if (memberById(adultId)?.isAdult ?? false) {
      meLocalId = adultId;
      notifyListeners();
    }
  }

  // ---- Income --------------------------------------------------------------

  void setIncome(String adultId, int cents) {
    income[adultId] = cents;
    notifyListeners();
  }

  int incomeOf(String adultId) => income[adultId] ?? 0;

  int get totalIncomeCents =>
      adults.fold(0, (sum, adult) => sum + incomeOf(adult.localId));

  // ---- Accounts / expenses / categories ------------------------------------

  void addAccount(DraftAccount account) {
    accounts.add(account);
    notifyListeners();
  }

  void removeAccount(int index) {
    accounts.removeAt(index);
    notifyListeners();
  }

  void addFixedExpense(DraftFixedExpense expense) {
    fixedExpenses.add(expense);
    notifyListeners();
  }

  void updateFixedExpense(int index, DraftFixedExpense expense) {
    fixedExpenses[index] = expense;
    notifyListeners();
  }

  void removeFixedExpense(int index) {
    fixedExpenses.removeAt(index);
    notifyListeners();
  }

  void addCategory(DraftCategory category) {
    categories.add(category);
    notifyListeners();
  }

  void updateCategory(int index, DraftCategory category) {
    categories[index] = category;
    notifyListeners();
  }

  void removeCategory(int index) {
    categories.removeAt(index);
    notifyListeners();
  }

  // ---- Main categories -------------------------------------------------------

  void renameMainCategory(String id, String name) {
    final i = mainCategories.indexWhere((mainCategory) => mainCategory.id == id);
    if (i < 0 || name.trim().isEmpty) return;
    mainCategories[i] = mainCategories[i].copyWith(name: name.trim());
    notifyListeners();
  }

  /// Adds a new main category with a color cycled from the default palette.
  String addMainCategory(String name) {
    final id = uuidv7();
    final color =
        defaultMainCategories[mainCategories.length % defaultMainCategories.length]
            .colorArgb;
    mainCategories.add(MainCategory(
      id: id,
      name: name.trim(),
      colorArgb: color,
      sortOrder: mainCategories.length,
    ));
    notifyListeners();
    return id;
  }

  void setShares(Map<String, int>? newShares) {
    shares = newShares;
    notifyListeners();
  }

  void setFirstQuest(DraftQuest? quest) {
    firstQuest = quest;
    notifyListeners();
  }

  void setModeFor(String localId, PlayMode mode) {
    playModes[localId] = mode;
    notifyListeners();
  }

  // ---- Derived money guidance (display only) -------------------------------

  /// The monthly-equivalent amount of a fixed expense (annual bills spread over
  /// twelve months for the counter; the ledger accrues them precisely).
  static int _monthlyEquivalent(DraftFixedExpense expense) => switch (expense.cadence.name) {
        'annual' => expense.amountCents ~/ 12,
        _ => expense.amountCents,
      };

  /// The permille split in effect (custom if set, else an even split).
  Map<String, int> effectiveShares() {
    final ids = [for (final adult in adults) adult.localId];
    return shares ?? evenShares(ids);
  }

  /// The slice of a pet-owned category's limit funded by [adultId]: each
  /// owning pet takes an equal share; a pet funded by an adult moves its
  /// share off that adult's budget instead of the group's.
  int _petShareFundedBy(DraftCategory category, String adultId) {
    if (category.petOwnerIds.isEmpty) return 0;
    final perOwnerCents = category.limitCents ~/ category.petOwnerIds.length;
    var total = 0;
    for (final petId in category.petOwnerIds) {
      if (memberById(petId)?.fundedByUserId == adultId) total += perOwnerCents;
    }
    return total;
  }

  int _petAdultFundedTotal(DraftCategory category) =>
      adults.fold(0, (sum, adult) => sum + _petShareFundedBy(category, adult.localId));

  /// Total group burden = group category limits + shared fixed expenses
  /// (monthly-equivalent), funded by shares off the top. Pet shares funded by
  /// a specific adult are carved out and land on that adult instead.
  int get groupBurdenCents {
    var total = 0;
    for (final category in categories.where((category) => category.group)) {
      total += category.limitCents - _petAdultFundedTotal(category);
    }
    for (final expense in fixedExpenses.where((expense) => expense.shared)) {
      total += _monthlyEquivalent(expense);
    }
    return total;
  }

  /// Per-adult live allocation summary for the budget step.
  AdultAllocation allocationFor(String adultId) {
    final sharesMap = effectiveShares();
    final permille = sharesMap[adultId] ?? 0;
    final groupShare = adults.length <= 1
        ? groupBurdenCents
        : (groupBurdenCents * permille) ~/ 1000;
    var personalBudget = categories
        .where((category) => !category.group && category.ownerLocalId == adultId)
        .fold(0, (sum, category) => sum + category.limitCents);
    // Pet shares this adult personally funds (pets assigned to them).
    for (final category in categories.where((category) => category.group)) {
      personalBudget += _petShareFundedBy(category, adultId);
    }
    final personalFixed = fixedExpenses
        .where((expense) => !expense.shared && expense.ownerLocalId == adultId)
        .fold(0, (sum, expense) => sum + _monthlyEquivalent(expense));
    return AdultAllocation(
      adultId: adultId,
      incomeCents: incomeOf(adultId),
      groupShareCents: groupShare,
      personalBudgetCents: personalBudget,
      personalFixedCents: personalFixed,
    );
  }

  /// Whether any adult's plan exceeds their income (budgets + fixed + group
  /// share > income). The wizard blocks finishing while this is true.
  bool get anyOverAllocated =>
      adults.any((adult) => allocationFor(adult.localId).unallocatedCents < 0);

  /// Replaces [adultId]'s personal category limits with an even division of
  /// whatever their income leaves after the group share and personal fixed
  /// expenses — so each category's limit IS the amount they may spend.
  void splitEvenlyFor(String adultId) {
    final indexes = [
      for (var i = 0; i < categories.length; i++)
        if (!categories[i].group && categories[i].ownerLocalId == adultId) i,
    ];
    if (indexes.isEmpty) return;
    final alloc = allocationFor(adultId);
    final available = (alloc.incomeCents -
            alloc.groupShareCents -
            alloc.personalFixedCents)
        .clamp(0, 1 << 62);
    final base = available ~/ indexes.length;
    var remainder = available - base * indexes.length;
    for (final i in indexes) {
      categories[i] =
          categories[i].copyWith(limitCents: base + (remainder-- > 0 ? 1 : 0));
    }
    notifyListeners();
  }

  // ---- Hand-off to the pure model ------------------------------------------

  OnboardingInput buildInput() => OnboardingInput(
        timezone: timezone,
        members: List.unmodifiable(members),
        meLocalId: meLocalId!,
        defaultIncomeByAdult: Map.unmodifiable(income),
        accounts: List.unmodifiable(accounts),
        fixedExpenses: List.unmodifiable(fixedExpenses),
        categories: List.unmodifiable(categories),
        mainCategories: List.unmodifiable(mainCategories),
        shares: shares == null ? null : Map.unmodifiable(shares!),
        firstQuest: firstQuest,
        playModes: {for (final adult in adults) adult.localId: modeOf(adult.localId)},
      );
}
