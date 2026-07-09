# Opus prompt playbook — game-first overhaul

CLAUDE.md has already been rewritten (game-first, flexible households, categories, firewall, text-mode ladder). Run these prompts **in order, one per fresh session**, on a branch per phase. Each phase must end with `./check.sh` green and one conventional commit. Phases 2–9 are domain/feature work; 10–11 need them done; 12–14 build the game in habit-critical order (playable text game → rewards → pixel art); 15–17 polish and ship.

---

## Prompt 1 — Docs reconciliation

```
CLAUDE.md was just rewritten as the new project constitution (game-first product priorities, flexible N-member households, budget categories, category-match quest tithing, income defaults, net worth, annual accrual, vacation mode, exports, gamification firewall + rewards + Homestead meta-progression + text-mode ladder, GitHub-Releases-only distribution/metrics). Bring the rest of docs/ in line. Docs only — no code.
- Write ADRs docs/adr/0008+ recording each decision and its rationale: flexible membership & shares; slice→category rename with main categories; category-match tithing; game-first with cosmetic-only rewards firewall; text-mode degradation ladder; net-worth tracked accounts; annual accrual; vacation mode; xlsx + opt-in Google Sheets (invariant relaxation); no-telemetry metrics via GitHub Releases stats.
- Update README.md and docs/architecture.md to match (pitch it as the game it is; keep the "How it works" money rules accurate to the new spec). Update docs/setup-guide.md terminology (no "slice"). Note where existing ADRs 0003/0005 are superseded rather than editing history. One commit.
```

## Prompt 2 — Domain: flexible household membership & shares

```
Implement the CLAUDE.md "Household & membership" invariants. TDD in lib/domain/.
- New events: MemberSet {memberId, name, role adult|dependent|pet, active, customSpriteSha256?, descriptionText?} (descriptionText feeds text-mode adventure later) and GroupShareSet {month, shares: {adultId: permille}} defaulting to even split. Keep reducing legacy PetSet as pet members.
- Reducer: replace every hardcoded 50/50 and two-user assumption — group category funding, shared recurring expenses, shared purchase splits (odd cent to purchaser), shared quest attribution, QuestAbandoned proportional returns, withdrawal approval (any OTHER adult approves; auto-approved when exactly one adult).
- Categories and emergency funds may link to a pet member for display; remove the slice-side pet option UI path. Add member management under Settings: add/edit/retire members, roles, description text, custom sprite.
- Keep existing tests passing by seeding two adult members in fixtures. ./check.sh green, one commit.
```

## Prompt 3 — Domain + UI: budget categories, main categories, monthly report

```
Implement the CLAUDE.md "Budget categories" invariants. TDD for domain and report math.
- Extend BudgetSliceSet (internal name kept for wire compat) with mainCategoryId; new event MainCategorySet {id, name, colorArgb, sortOrder} with the default set: Housing, Food, Transport, Health, Entertainment, Pets, Savings, Misc.
- Rename every user-facing "slice" string to "budget category" across UI and docs; rename lib/features/slices/ → lib/features/categories/.
- Month-end report screen: fl_chart pie of spend by main category using its colors, per-adult and household toggle, plus a budgeted/spent/leftover table. Reachable from dashboard and the month-close ritual summary. ./check.sh green, one commit.
```

## Prompt 4 — Income defaults + fix blank income page

```
Implement the CLAUDE.md "Income" invariant. Income today is per-month IncomeSet with no carry-forward, so the desktop income page shows blank months. TDD.
- New event DefaultIncomeSet {forUserId, amountCents, effectiveFromMonth}. Reducer: month income = IncomeSet override ?? latest effective default ?? 0.
- Rework lib/features/settings/income_screen.dart: per adult, editable default monthly income plus a month list of resolved amounts with "default"/"override" badges; editing a month writes an override; never blank when a default exists. ./check.sh green, one commit.
```

## Prompt 5 — Net worth: savings interest, investments, debts

```
Implement the CLAUDE.md "Net worth" invariants. TDD in lib/domain/; existing AccountBalanceRecorded + lib/features/networth are the starting point.
- Events: TrackedAccountSet {accountId, name, kind savings|investment|debt, aprBps?, accrualCadence?, updateCadence?, minPaymentCents?}, AccountTransferRecorded {accountId, amountCents, direction, note}.
- Reducer, all read-time: savings/debt value = last recorded balance + accrued interest since; investments = last value + stale flag past updateCadence; debt minimum payments surface automatically as recurring expenses. Tracked accounts never enter category math.
- Net worth screen: assets − debts over time, per-account cards, stale-investment nudge banner, record-balance/transfer sheets. ./check.sh green, one commit.
```

## Prompt 6 — Annual expenses with monthly accrual + due dates

```
Implement the CLAUDE.md annual-accrual invariant. TDD.
- RecurringExpenseSet gains cadence monthly|annual, dueDay, dueMonth (annual). Reducer: annual charges 1/12 monthly off the top (remainder cents in the due month so the year sums exactly); due month applies the real amount against the accrued reserve and surfaces shortfall/surplus.
- Show due dates on the recurring list and an upcoming-payments strip on the dashboard ("Rent — last day of month", "WoW — Feb 10"). Adventure adapter: annual items = "provisioning contracts" with countdown. ./check.sh green, one commit.
```

## Prompt 7 — Quest category tithing + savings-goal visibility

```
Implement the CLAUDE.md category-match tithing invariant. TDD reducer + game adapter.
- QuestSet gains mainCategoryId + descriptionText. LeftoverAllocated quest allocations: matching main category = untithed full damage; non-matching = source category's pool tithe to the war chest, remainder as damage. Encode the canonical test from CLAUDE.md ($100 hygiene @50% vs $100 entertainment @20% attacking an Entertainment quest).
- Make goals discoverable: "Savings goals" on dashboard + manage menu listing quests with progress bars and a prominent "New goal" flow (name, target, main category, personal/shared, sprite/description); plain-words empty state. Spoils UI shows the tithe split before confirming any attack. ./check.sh green, one commit.
```

## Prompt 8 — Vacation mode

```
Implement the CLAUDE.md "Vacation mode" invariants. TDD.
- Events VacationSet/VacationClosed per spec; purchases may charge VACATION(vacationId, categoryId); reducer tracks per-category and total vs fund balance, days remaining, daily allowance remaining; closing returns leftover to the source fund.
- Vacation dashboard while open: budget rings per vacation category, daily allowance tracker, overspend warnings; quick entry gains a vacation charge target. Adventure adapter: an "expedition abroad" side-floor. ./check.sh green, one commit.
```

## Prompt 9 — Merge-import UX (sync-by-file)

```
Import is already idempotent by eventId, so devices exchanging .dbevents(.zip) files merge without overwriting. Verify with an integration test (A and B each add disjoint events offline, exchange exports, both converge; re-import is a no-op).
Then the UX per CLAUDE.md: preview before applying ("14 new events, 3 receipts — 210 already present"), result summary after, and an "export since last export" shortcut for the vacation-swap workflow. Document "Syncing without a hub" in README. Investigate the Android OS share sheet as the low-effort nearby path; do NOT add radio/P2P dependencies. ./check.sh green, one commit.
```

## Prompt 10 — First-run onboarding: party creation

```
Build the full first-run onboarding (replaces/extends lib/features/setup/), framed as creating your adventuring party. Steps, each editable later via Settings:
1. "Join an existing party?" → pair with hub (QR/URL) and finish; else continue.
2. Create members: adults → dependents → pets (MemberSet), each with name, optional sprite, and an invited free-text character description (feeds text-mode adventure).
3. Per adult: default monthly income (0 allowed).
4. Tracked accounts: savings (balance, APR, accrual), investments (value, update cadence), debts (balance, APR, minimum payment).
5. Fixed expenses: group then per-adult; cadence monthly|annual with due dates; annual ones explain the 1/12 accrual.
6. Budget allocation: show total income; GROUP categories first (rent, utilities fixed-or-estimate, pet budgets, group long-term savings); show remainder; propose the share split (default even, editable); then per-adult categories from the default main-category template until each adult's unallocated counter reaches 0.
7. Pick a first savings goal (optional but encouraged — the first quest boss). Choose mode: Adventure (default) or Classic.
8. Summary → write all events → celebration → hand off to the tutorial.
Note on the summary that all changes are permanently logged; add the "budget change log" (audit) screen derived from events. Wizard logic as a testable pure model (inputs → event list) with unit tests. ./check.sh green, one commit.
```

## Prompt 11 — Glossary, plain-language copy, encouragement voice, tutorial

```
Build the strings/glossary module in lib/ui/ per CLAUDE.md: single source of truth mapping internal → Classic → Adventure terms (LeftoverAllocated → "Divide monthly leftovers" → "Dividing the spoils"; pool tithe → "shared-savings cut"; dissolution tithe → "cancellation fee"; grace period → "auto-divide after N days"; etc.). Sweep Classic mode: no "slice/tithe/spoils/dissolution/grace period" anywhere; one-line helper text under every setting. Adventure keeps flavor terms with plain-meaning tooltips.
The sweep INCLUDES the first-run wizard: its step titles ("Expedition supplies", "Dividing the coin", …) are hardcoded Adventure voice — source them from the glossary so replaying setup steps from Settings respects the chosen mode.
Also finish the N-adult sweep prompt 2 started in the reducer: the category editor, recurring-expense editor, and quest editor still build "Me / Partner / Group" owner pickers from LocalSetup.partner (two-adult only). Replace them with an owner selector listing ALL active adults from HouseholdState.members (no phantom second chip in single-adult households), and remove remaining "partner" strings (e.g. the sync screen). LocalSetup stays as the device pointer; UI must never derive the member list from it.
Create app/assets/game/text/ data files for narrative and encouragement lines (loaded, not hardcoded): purchase-logged acknowledgments, streak celebrations, ritual celebrations, supportive overspend lines (never shaming). 
Add a skippable, replayable (Settings > Tutorial) first-use tour: recording a purchase, categories, month-close division, savings goals, shared savings/withdrawals, sync. Auto-start it once right after the onboarding celebration (the handoff prompt 10 promised). ./check.sh green, one commit.
```

## Prompt 12 — Game core: text-mode adventure becomes the default app

```
Make Adventure mode the default experience per CLAUDE.md, starting at tier 3 (text mode) so it ships before art exists. Adapter stays pure and tested.
Note: lib/game/ already contains an earlier widget skin (adventure_dashboard/adventure_screen/adventure_spoils) and adapter.dart still maps a fixed hero+partner sprite pair. Absorb or replace that skin — do not leave two parallel Adventure UIs — and generalize the adapter's party mapping to the full N-member roster (adults, dependents, pets) before building text mode on top.
- lib/game/text_mode/: the full app as a styled text-adventure — party roster (members with their descriptionText), this month's floor with category monsters (HP bars as text/blocks), quest bosses, gold pouch/war chest/reserve caches, equipment-maintenance report at floor start, and a scrolling adventure log in game voice fed by real events ("GROCERIES MONSTER TAKES 42 DMG", "THE WAR CHEST WAS RANSACKED!", supplies arriving, treasure found), with encouragement lines from app/assets/game/text/.
- Month close as a turn-based text battle: per personal category leftover choose carry / attack a quest boss / pouch; attacks show damage and the tithe split (mismatch narrates the war-chest cut) using reducer numbers only.
- Quick entry ("strike a monster" = log a purchase) reachable in two taps from launch. Adventure default on first run; Classic toggle always visible. Extend adapter.dart (TDD) for log/floor/party mappings. ./check.sh green, one commit.
```

## Prompt 13 — Rewards, streaks & the Homestead (cosmetic only)

```
Implement the CLAUDE.md rewards + meta-progression invariants. TDD in lib/game/rewards/ (pure).
- New cosmetic event GameRewardGranted {rewardId, kind trophy|title|badge, sourceRef, grantedAt}; the money reducer must ignore it. Add the FIREWALL TEST: reduce a rich fixture ledger with and without all cosmetic events — balances identical. This test is permanent.
- Rewards: quest-boss defeat → trophy in a trophy-hall screen; streak detection derived at read time (consecutive days with logged purchases; consecutive on-time rituals) → titles/badges; ritual completion → celebration moment. All granted via cosmetic events so they sync.
- The Homestead: a meta-progression screen visualizing the war chest as a homestead built up in stages as real pool balance crosses configurable thresholds (flavor renameable: town, ward, etc.). Text-mode rendering first, sprite slots for later. Pure visualization — nothing financial gated or modified. ./check.sh green, one commit.
```

## Prompt 14 — Art spec for a first-time pixel artist + pixel dungeon UI (tiers 1–2)

```
First rewrite docs/art-assets.md as a commissioning guide for a hobbyist artist who has never done game art: one small fixed palette (name a specific ~16-color palette), ONE base sprite size (32×32) and one portrait size (48×48), 9-slice panel spec with an annotated example, file naming/format (PNG, transparent), integer-scale rules, and a PRIORITIZED "first ten assets" list (party frame panel, generic adult portrait, generic pet portrait, one category monster, one quest boss, HP bar caps/fill, log panel, coin, trophy, homestead stage 1) followed by the full backlog (default monster per main category, enraged variants, floor backgrounds, minimap tiles, Homestead stages, celebration effects).
Then build the tier-1/2 pixel presentation on top of the text-mode structure: party member frames with HP bars around a central floor viewport, monsters sized by budget, scrolling log, year minimap; per-asset runtime detection — each missing sprite degrades to its labeled placeholder (tier 2), and the global text-mode toggle remains (tier 3). FilterQuality.none, integer scales, custom sprite blobs through the same pipeline. Golden tests for each tier of the main screen. ./check.sh green, one commit.
```

## Prompt 15 — Classic mode redesign

```
Redesign Classic mode (the plain fallback; numbers/providers unchanged). It currently reads as bare default Material — make it feel designed.
- Design system in lib/ui/: typography scale, spacing tokens, light/dark palettes keyed to main-category colors, card/list treatments, animated progress rings for category budgets.
- Dashboard: month hero (income vs spent vs remaining), color-coded category grid, upcoming payments strip, savings-goal progress, net-worth sparkline. Consistent empty states and iconography; responsive multi-column desktop vs phone layouts. No new dependencies; fl_chart for charts. Golden tests for key screens.
- Accessibility pass while restyling: honor system text scaling without overflow on key screens, semantic labels on progress rings/charts/FABs, and sufficient contrast in both light and dark palettes. ./check.sh green, one commit.
```

## Prompt 16 — Spreadsheet export (.xlsx) + optional Google Sheets sync

```
Implement the CLAUDE.md "Exports" invariants.
- Offline .xlsx export (pure-Dart xlsx writer; justify the package in the commit body): sheets Transactions, Monthly summary, Members & income, Savings goals, Net worth, Recurring expenses. Money as cents-derived decimals; never floats internally.
- Optional Google Sheets sync: OFF by default; explicit opt-in with a "data leaves your local network" warning; user supplies OAuth credentials; pushes the same workbook to a chosen spreadsheet on demand and optionally after sync. Isolated behind an interface in lib/data/sheets/ so the app fully works with it absent; platform-guarded like OCR. Document setup in docs/. ./check.sh green, one commit.
```

## Prompt 17 — Distribution, release CI & download metrics

```
Implement the CLAUDE.md "Distribution & metrics" invariants.
- docs/distribution.md, linked from README: reproducible release builds — signed sideloadable Android APK, Windows zip, macOS .app/dmg (unsigned caveats), Linux tar/AppImage — exact commands, prerequisites, Flutter version pinning.
- GitHub Actions workflow: on tag, build all four artifacts and attach to a GitHub Release, so sharing the app = sharing a release link.
- Metrics without telemetry: a small documented script (tool/) that queries the GitHub Releases API and prints cumulative download counts per asset and total — the resume number. Explicitly document that the app itself never phones home.
- End-user path: install → onboarding party creation → host a hub on one desktop → pair phones via QR; troubleshooting (firewall ports, LAN discovery). Refresh README + docs/setup-guide.md for the final feature set. One commit.
```
