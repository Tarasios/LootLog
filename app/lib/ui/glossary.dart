/// The glossary: the single source of truth for every user-facing term that
/// has a plain (Classic) and a flavor (Adventure) name.
///
/// The app deliberately runs the same numbers under two vocabularies. Classic
/// mode speaks plain budgeting English — no "slice", "tithe", "spoils",
/// "dissolution", or "grace period" ever reaches the screen. Adventure mode
/// keeps the dungeon flavor, but every flavor word carries a plain-meaning
/// tooltip drawn from the same entry, so nobody is ever left guessing what a
/// term costs them.
///
/// Nothing here computes money — it only names things. Screens ask the glossary
/// for a label given the active skin; settings and tooltips ask for the helper
/// line. Because this is the only place the mapping lives, adding a term or
/// re-wording one is a one-line change that every surface inherits.
///
/// This module is intentionally free of any dependency on the game layer (it
/// takes a plain `adventure` bool, not `AppSkin`) so the whole UI can reach for
/// it without an upward import.
library;

/// One term in three registers plus a plain-meaning helper.
///
/// - [internal] is the wire/domain word (e.g. the event name `LeftoverAllocated`
///   or the field `poolTithe`) — kept only so the glossary can be cross-checked
///   against the code and shown in a developer/debug view. Never rendered to
///   users on its own.
/// - [classic] is the plain-language label used in Classic mode. It must never
///   contain a banned flavor word.
/// - [adventure] is the flavor label used in Adventure mode.
/// - [helper] is a single, plain, non-shaming sentence explaining what the term
///   means. It is shown as helper text under a setting and as the tooltip on the
///   Adventure flavor word.
class GlossaryTerm {
  const GlossaryTerm({
    required this.internal,
    required this.classic,
    required this.adventure,
    required this.helper,
  });

  final String internal;
  final String classic;
  final String adventure;
  final String helper;

  /// The label for the given mode: [adventure] when [isAdventure], else
  /// [classic].
  String label({required bool isAdventure}) => isAdventure ? adventure : classic;
}

/// The full term table. Every entry appears in [Glossary.all] so tests can
/// assert the Classic vocabulary stays clean and a glossary screen can list them.
abstract final class Glossary {
  /// Month close — deciding what happens to each budget's leftover.
  static const leftoverAllocated = GlossaryTerm(
    internal: 'LeftoverAllocated',
    classic: 'Divide monthly leftovers',
    adventure: 'Dividing the spoils',
    helper: 'At month end, decide what happens to the money left in each '
        'budget: keep it there, put it toward a savings goal, or move it to '
        'your personal spending.',
  );

  /// The month-close event, as a short noun for buttons and banners.
  static const monthClose = GlossaryTerm(
    internal: 'month close',
    classic: 'Month wrap-up',
    adventure: 'Dividing the spoils',
    helper: 'The once-a-month step where you settle each budget’s leftover.',
  );

  /// The cut of a category's leftover kept for shared savings.
  static const poolTithe = GlossaryTerm(
    internal: 'poolTithe',
    classic: 'shared-savings cut',
    adventure: 'tithe',
    helper: 'The share of a budget’s leftover kept for shared savings instead '
        'of your personal spending.',
  );

  /// The fee taken when a savings goal is cancelled.
  static const dissolutionTithe = GlossaryTerm(
    internal: 'dissolutionTithe',
    classic: 'cancellation fee',
    adventure: 'dissolution tithe',
    helper: 'A small percentage kept for shared savings when a savings goal is '
        'cancelled; the rest returns to whoever funded it.',
  );

  /// The delay before automatic defaults apply after month close.
  static const gracePeriod = GlossaryTerm(
    internal: 'gracePeriod',
    classic: 'auto-divide delay',
    adventure: 'grace period',
    helper: 'How many days after month end you have to divide leftovers '
        'yourself before the app applies each budget’s default.',
  );

  /// The long-term shared pool.
  static const warChest = GlossaryTerm(
    internal: 'warChest',
    classic: 'shared savings',
    adventure: 'war chest',
    helper: 'The household’s long-term shared pool, built from savings cuts, '
        'group leftovers, and direct contributions.',
  );

  /// An adult's personal discretionary money.
  static const vault = GlossaryTerm(
    internal: 'vault',
    classic: 'personal spending',
    adventure: 'gold pouch',
    helper: 'Your own money to spend freely, separate from the household '
        'budgets and shared savings.',
  );

  /// A savings goal.
  static const quest = GlossaryTerm(
    internal: 'quest',
    classic: 'savings goal',
    adventure: 'quest',
    helper: 'Something you’re saving toward, funded with leftovers at month '
        'close.',
  );

  /// A budget category.
  static const category = GlossaryTerm(
    internal: 'budgetSlice',
    classic: 'budget',
    adventure: 'monster',
    helper: 'A spending category with a monthly limit — for one person or the '
        'whole household.',
  );

  /// Putting leftover toward a savings goal.
  static const attackQuest = GlossaryTerm(
    internal: 'questAttack',
    classic: 'Put toward a savings goal',
    adventure: 'Attack a quest',
    helper: 'Send this leftover to a savings goal instead of keeping it in the '
        'budget or your personal spending.',
  );

  /// A shared-savings withdrawal needing a second adult's approval.
  static const withdrawal = GlossaryTerm(
    internal: 'poolWithdrawal',
    classic: 'shared-savings withdrawal',
    adventure: 'writ',
    helper: 'Taking money out of shared savings — another adult has to approve '
        'it first.',
  );

  /// An emergency purchase that overdraws its fund into shared savings.
  static const ransack = GlossaryTerm(
    internal: 'ransack',
    classic: 'emergency overdraw',
    adventure: 'ransack',
    helper: 'When an emergency costs more than its fund holds, the extra comes '
        'straight from shared savings — no approval needed, but everyone sees it.',
  );

  /// Money kept off the top of a budget into a named emergency fund.
  static const emergencyFund = GlossaryTerm(
    internal: 'emergencyFund',
    classic: 'emergency fund',
    adventure: 'reserve cache',
    helper: 'A named rainy-day fund the household sets aside a fixed amount '
        'into each month.',
  );

  /// Every defined term, for tests and any glossary/help screen.
  static const all = <GlossaryTerm>[
    leftoverAllocated,
    monthClose,
    poolTithe,
    dissolutionTithe,
    gracePeriod,
    warChest,
    vault,
    quest,
    category,
    attackQuest,
    withdrawal,
    ransack,
    emergencyFund,
  ];

  /// Flavor words that must never appear in Classic-mode copy. The glossary is
  /// the guardrail: a test asserts none of the [classic] strings contain any of
  /// these.
  static const bannedInClassic = <String>[
    'slice',
    'tithe',
    'spoils',
    'dissolution',
    'grace period',
  ];

  /// The grace-period label, which reads more naturally with the day count
  /// inlined: Classic "Auto-divide leftovers after 7 days"; Adventure
  /// "Grace period · 7 days".
  static String gracePeriodLabel(int days, {required bool isAdventure}) {
    final unit = days == 1 ? 'day' : 'days';
    return isAdventure
        ? 'Grace period · $days $unit'
        : 'Auto-divide leftovers after $days $unit';
  }

  /// A one-line explanation of a leftover moving into shared savings, shown in
  /// the month-close preview. Classic keeps it plain; Adventure keeps the coins
  /// flying to the war chest.
  static String sharedSavingsCut(
    String amount,
    int pct, {
    required bool isAdventure,
  }) =>
      isAdventure
          ? '$amount tithe to war chest ($pct%)'
          : '$amount to shared savings ($pct% cut)';
}
