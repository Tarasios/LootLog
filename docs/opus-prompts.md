# Opus prompt playbook — feature-gap overhaul

Run these **in order, one per fresh session**, on a branch per phase. Each phase must end with `./check.sh` green and one conventional commit. Do not skip Prompt 1: later phases change reducer behavior that the current CLAUDE.md forbids, and the workflow rules tell the agent to stop when a prompt conflicts with the spec — Prompt 1 removes that conflict first.

---

## Prompt 1 — Spec revision (CLAUDE.md + ADRs). Everything else depends on this.

```
Revise the project spec before any code changes. Update CLAUDE.md invariants and add ADRs (docs/adr/0008+) for each decision below. Change ONLY docs in this phase. The decisions are final; record them, don't relitigate:

1. FLEXIBLE HOUSEHOLD. Drop "two-person" everywhere. A household has N members: role adult (has income, vault, personal categories, own devices), dependent (display-level, no vault), or pet (display-level party member, never optional metadata on a category). Group costs split by configurable per-adult shares (default even split), not hardcoded 50/50. "Both users approve withdrawals" becomes "any other adult approves; self-approval rejected". Shared-purchase splits and odd-cent rules generalize to the share table (odd cents to purchaser). A single-adult household is valid (approvals auto-satisfied when there is exactly one adult — record this explicitly).
2. TERMINOLOGY. "Slice" is renamed "budget category" in ALL user-facing surfaces and docs (event/class names may keep internal names for wire compatibility; note this). Categories get an optional parent "main category" (e.g. Entertainment, Food, Health) with a color, used for reporting. Add a glossary table mapping internal → Classic UI → Adventure UI terms (e.g. LeftoverAllocated → "Divide monthly leftovers" → "Dividing the spoils"; pool tithe → "shared-savings cut"; dissolution tithe → "cancellation fee to shared savings"; grace period → "auto-divide after N days"). Classic mode must never show jargon like tithe/spoils/dissolution.
3. QUEST TITHING CHANGE. Quests (savings-goal monsters) get a category. Attacking a quest with leftover from a MATCHING main category is untithed; from a NON-matching category the source category's pool tithe applies (tithe portion to war chest, remainder as damage). Update the spoils invariant accordingly.
4. INCOME DEFAULTS. Per-adult default monthly income that carries forward until changed; per-month override still possible. Reducer resolves month income = override ?? default.
5. NET-WORTH LAYER. New tracked (non-budget) accounts: savings (APR + accrual schedule, interest derived at read time since last recorded balance), investments (manual value updates, app nudges on a chosen cadence), debts (APR, optional minimum monthly payment surfaced as a fixed expense). All event-sourced, reducer-derived, no scheduled jobs.
6. ANNUAL EXPENSES. RecurringExpense gains cadence monthly|annual and a due date (day-of-month, or month+day for annual). Annual expenses accrue 1/12 monthly off the top so the budget feels them year-round; the due month shows the real charge against the accrued reserve.
7. VACATION MODE. A vacation is funded by a completed savings quest/fund; entering vacation mode activates a self-contained sub-budget (daily allowance, accommodation, activities categories) drawing on that fund, with its own mini-dashboard. Normal monthly budgets are untouched. Same event/reducer rules.
8. EXPORT INTEGRATIONS (invariant relaxation). Core stays local-first. Add: (a) .xlsx spreadsheet export, fully offline, always available; (b) OPTIONAL Google Sheets sync, off by default, explicit user opt-in with a warning that it leaves the LAN — the only permitted external service. Record as an ADR.
9. AUDIT. Note that event sourcing already provides the undeletable audit trail; commit to a human-readable "budget change log" view derived from events.

Update README.md and docs/architecture.md to match. Do not modify code or tests in this phase.
```

## Prompt 2 — Domain: flexible household membership & shares

```
Implement the flexible-household spec (CLAUDE.md + ADR from the spec-revision commit). TDD in lib/domain/.
- New events: MemberSet {memberId, name, role adult|dependent|pet, active, customSpriteSha256?} (supersedes PetSet for new data; keep reducing PetSet for old events, mapping to a pet member) and GroupShareSet {month, shares: {adultId: permille}} defaulting to even split.
- Reducer: replace every hardcoded 50/50 and two-user assumption — group category funding, shared recurring expenses, shared purchase splits (odd cent to purchaser), shared quest attribution, QuestAbandoned proportional returns, withdrawal approval (any OTHER adult approves; auto-approved household of one).
- Categories and emergency funds may link to a pet member for display; pets are no longer configured via a slice-side option — remove that UI path and add member management (add/retire members) under Settings, plus pet setup as member creation.
- Keep all existing tests passing by seeding two adult members in fixtures. ./check.sh green, one commit.
```

## Prompt 3 — Domain + UI: budget categories, main categories, colors, monthly report

```
Implement the category terminology spec. TDD for domain and report math.
- Extend BudgetSliceSet (internal name kept for wire compat) with mainCategory {id, name, colorArgb}; new event MainCategorySet {id, name, colorArgb, sortOrder}. Ship sensible defaults offered during setup: Housing, Food (Groceries, Dining out), Transport, Health (Healthcare, Hygiene), Entertainment, Pets, Savings, Misc.
- Rename every user-facing "slice" string to "budget category" across Classic UI, tooltips, and docs; Adventure keeps monster flavor. Rename lib/features/slices/ → lib/features/categories/.
- Month-end report screen: pie chart (fl_chart) of spend by main category using category colors, per adult and household toggle, plus a simple table (budgeted vs spent vs leftover). Reachable from dashboard and the month-close ritual summary.
./check.sh green, one commit.
```

## Prompt 4 — Income defaults + fix blank income page

```
Income today is a per-month IncomeSet with no carry-forward, so the desktop income page shows blank months. Implement the income-defaults spec. TDD.
- New event DefaultIncomeSet {forUserId, amountCents, effectiveFromMonth}. Reducer: month income = latest IncomeSet override for that month ?? latest default effective on/before it ?? 0.
- Rework lib/features/settings/income_screen.dart: per adult, show default monthly income (editable), and a month list showing resolved amounts with "default" vs "override" badges; editing a month writes an override; never a blank screen when a default exists.
- Adventure mapping unchanged (income = expedition supplies). ./check.sh green, one commit.
```

## Prompt 5 — Net worth: savings interest, investments, debts

```
Implement the net-worth spec. TDD in lib/domain/. Existing AccountBalanceRecorded + lib/features/networth are the starting point.
- Events: TrackedAccountSet {accountId, name, kind savings|investment|debt, aprBps?, accrualCadence?, updateCadence?, minPaymentCents?}, AccountBalanceRecorded (extend/reuse), AccountTransferRecorded {accountId, amountCents, direction, note} for real-life moves.
- Reducer derives current value at read time: savings = last recorded balance + interest accrued since (no jobs); debts likewise; investments = last recorded value + "stale, update requested" flag once past updateCadence.
- Debt minimum payments surface automatically as shared or personal fixed recurring expenses.
- Net worth screen: assets − debts over time, per-account cards, nudge banner for stale investments, record-balance/transfer sheets. ./check.sh green, one commit.
```

## Prompt 6 — Annual expenses with monthly accrual + due dates

```
Implement the annual-expense spec. TDD.
- RecurringExpenseSet gains cadence monthly|annual and dueDay (day-of-month; for annual also dueMonth). Reducer: annual expenses charge ceil/12 monthly off the top (remainder cents in the due month so the year sums exactly); the due month applies the real amount against the accumulated reserve and surfaces any shortfall/surplus.
- Show due dates on the recurring-expense list and upcoming-payments strip on the dashboard ("Rent — last day of month", "WoW — Feb 10"). Adventure: annual items are "provisioning contracts" with a countdown. ./check.sh green, one commit.
```

## Prompt 7 — Quest category tithing + savings-target visibility

```
Implement the quest-tithe spec change. TDD reducer + game adapter.
- QuestSet gains mainCategoryId. LeftoverAllocated quest allocations: if source category's main category == quest's, untithed (full damage); else apply the source category's pool tithe (tithe to war chest, remainder is damage). Example to encode as a test: $100 hygiene leftover, 50% tithe, attacking an Entertainment console quest → $50 chest, $50 damage; $100 entertainment leftover, 20% tithe, same quest → $100 damage, $0 tithe.
- Make savings targets discoverable: a "Savings goals" entry on dashboard + manage menu listing quests with progress bars and a prominent "New goal" flow (name, target, category, personal/shared, optional sprite); empty state explains goals in plain words. Spoils UI shows the tithe consequence before confirming an attack. ./check.sh green, one commit.
```

## Prompt 8 — Vacation mode

```
Implement the vacation-mode spec. TDD.
- Events: VacationSet {vacationId, name, fundQuestId|emergencyFundId, startDate, endDate, categories:[{name, limitCents}]} , VacationClosed. Purchases may charge VACATION(vacationId, categoryId); reducer tracks per-category and total vs fund balance, days remaining, daily allowance remaining.
- Vacation dashboard (activates while a vacation is open): budget rings per vacation category, daily allowance tracker, overspend warnings; closing returns leftover to the source fund. Quick-entry gains a vacation charge target while active. Adventure: an "expedition abroad" side-floor. ./check.sh green, one commit.
```

## Prompt 9 — Merge-import UX (vacation sync-by-file)

```
Import is already idempotent by eventId, so two paired devices exchanging .dbevents(.zip) files merge without overwriting — verify with an integration test (A and B each add disjoint events offline, exchange exports, both converge; re-import is a no-op).
Then build the UX: import shows a preview ("14 new events, 3 receipts — 210 already present") before applying, a result summary after, and an easy "Export since <last export>" shortcut for the vacation swap workflow. Document the workflow in README ("Syncing without a hub"). Also add a best-effort nearby-sync note: investigate exporting/importing via OS share sheet on Android as the low-effort path; do NOT add new radio/P2P dependencies. ./check.sh green, one commit.
```

## Prompt 10 — First-run onboarding wizard

```
Build the full first-run onboarding per spec (replaces/extends lib/features/setup/). Wizard steps, each skippable-later but validated in-flow:
1. "Join existing household?" → pair with hub (QR/URL) and finish; else continue.
2. Add adults → dependents → pets (MemberSet).
3. Per adult: default monthly income (0 allowed) (DefaultIncomeSet).
4. Current savings accounts (balance, optional APR + accrual), investments (value + update cadence), debts (balance, APR, minimum payment) — TrackedAccountSet + AccountBalanceRecorded.
5. Fixed expenses: group then per-adult; each with cadence monthly|annual and due date; annual ones note the 1/12 monthly accrual.
6. Budget allocation: show total income; walk GROUP categories first (rent, utilities fixed-or-estimate, pet budgets, group long-term savings), show remainder, propose share split (default even, editable), then per-adult categories from the default main-category template until each adult's remainder is fully allocated (running "unallocated" counter must reach 0).
7. Summary → write all events → household ready.
Everything editable later via Settings; note on the summary that all changes are permanently logged. Add an "audit log" screen: human-readable list of budget/rule events. Keep wizard logic in a testable pure model (inputs → events list) with unit tests. ./check.sh green, one commit.
```

## Prompt 11 — Plain-language copy pass + in-app tutorial

```
Apply the glossary from the spec commit across Classic mode: no user-facing "slice", "tithe", "spoils", "dissolution", "grace period" — use the mapped plain terms, with one-line helper text under each setting ("Auto-divide after: if you don't divide a month's leftovers within N days, your default choice is applied automatically"). Adventure mode keeps flavor terms but gets tooltips with the plain meaning.
Add a first-use tutorial: a short skippable/replayable (Settings > Tutorial) overlay tour after onboarding covering: recording a purchase, budget categories, month-close leftover division, savings goals, shared savings/withdrawals, sync. Keep copy in one strings/copy module for auditability. ./check.sh green, one commit.
```

## Prompt 12 — Classic UI redesign

```
Redesign Classic mode; numbers/providers unchanged. Goals: it currently reads as bare default Material — make it feel designed.
- Design system in lib/ui/: typography scale, spacing tokens, light/dark palette keyed to main-category colors, card/list treatments, animated progress rings/bars for category budgets.
- Dashboard: month header with income vs spent vs remaining hero, category grid with color-coded progress, upcoming payments strip, savings-goal progress, net-worth sparkline.
- Consistent empty states, section headers, iconography; responsive layout for desktop (multi-column) vs phone. No new dependencies beyond the stack; fl_chart for charts. Include golden tests for key screens. ./check.sh green, one commit.
```

## Prompt 13 — Spreadsheet export (.xlsx) + optional Google Sheets sync

```
Implement the export ADR. 
- Offline .xlsx export (state the added package and why in the commit body; prefer a pure-Dart xlsx writer): workbook with sheets Transactions, Monthly summary (per category budget/spent/leftover), Members & income, Savings goals, Net worth, Recurring expenses. Money as cents-derived decimals, never floats internally.
- Optional Google Sheets sync: OFF by default; explicit opt-in flow with a clear "data leaves your local network" warning; user supplies OAuth credentials; pushes the same workbook structure to a chosen spreadsheet on demand and optionally after sync. Isolate behind an interface so the app compiles and fully works with it disabled; no other feature may depend on it. Platform-guard like the OCR plugin. Document setup in docs/. ./check.sh green, one commit.
```

## Prompt 14 — Adventure mode: make it a game

```
Rebuild Adventure mode into a pixel-art dungeon-crawler presentation (reference: docs/art-assets.md, to be rewritten first — see below). Domain and adapter numbers unchanged; adapter may be extended (pure, tested).
- First rewrite docs/art-assets.md into a complete commissioning spec: portrait frames for party members (adults, dependents, pets), monster sprites per default main category + custom-sprite slots, dungeon corridor/floor backgrounds per month-theme, UI chrome (ornate frame, HP/AP bars, log panel, minimap), 9-slice panels, fonts, exact pixel dimensions and palette, integer-scale rules.
- Screen layout (desktop + Android): party member frames with HP bars around a central viewport (this month's "floor"), a scrolling event log in game voice ("GROCERIES MONSTER TAKES 42 DMG", "THE WAR CHEST WAS RANSACKED!"), a minimap of the year's floors. Category monsters stand in the corridor sized by budget; overspend = enraged sprite + player HP loss.
- Month close = turn-based battle ritual: pick a personal category's leftover, choose store-in-pouch / carry / attack a quest monster; attacks show damage numbers honoring the category-match tithe rule (mismatch shows the war-chest cut flying off as coins); quest death = trophy celebration.
- All sprites via the existing pixelated pipeline (FilterQuality.none, integer scales), labeled placeholders for missing art so it is fully navigable before assets exist. Golden tests for layout; adapter unit tests for new mappings. ./check.sh green, one commit.
```

## Prompt 15 — Distribution & sharing guide

```
Write docs/distribution.md and link it from README: how a non-developer gets their own party running.
- Reproducible release builds: Android APK (signed, sideloadable), Windows zip/installer, macOS .app/dmg (unsigned caveats), Linux tar/AppImage — exact commands, prerequisites, flutter version pinning.
- GitHub Actions release workflow: on tag, build all four artifacts and attach to a GitHub Release, so "sharing the app" = "send the release link". Include the workflow file.
- End-user setup path: install → onboarding wizard → host a hub on one desktop → pair phones via QR; troubleshooting (firewall ports, LAN discovery).
- Update README.md and docs/setup-guide.md for the post-overhaul feature set (categories, members, onboarding, vacation mode, exports). One commit.
```

---

**Ordering rationale:** 1 unblocks everything; 2–3 change the domain vocabulary everything later uses; 4–8 are independent domain features (any order, but keep before 10); 9 is standalone; 10–11 depend on 2–8 existing; 12 and 14 are visual layers over the finished behavior; 13 and 15 are last since they export/ship whatever the final shape is.
