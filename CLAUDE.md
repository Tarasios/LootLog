# LootLog

A pixel-art dungeon-crawler that happens to be a rigorous shared budgeting app. The game is the product: budgeting is presented as a party of adventurers (the household — adults, dependents, pets) delving a dungeon where budget categories are monsters, savings goals are quest bosses, and month close is a battle ritual. Underneath sits a local-first, event-sourced, integer-cents ledger that the game layer can read but never alter. Flutter only: Android + desktop (Windows/macOS/Linux). No external services, servers, accounts, or SaaS — desktops act as sync hubs on the local network and OCR runs on-device. (LootLog was renamed from DuoBudget before first release, and the repository, package, and storage names all follow; households are any size.)

## Product priorities (in order)

1. **Game first.** Adventure mode is the primary, default experience on every platform. Classic mode is the plain fallback view, always available, always showing identical numbers.
2. **Habit formation.** The app succeeds if users come back daily to log purchases and monthly for the ritual. Streaks, celebrations, and an encouraging voice are core features, not polish. The app never shames: overspending makes a monster *enraged* (drama), but the copy stays supportive and forward-looking.
3. **Goals-orientation.** Savings quests and progress are front-and-center on the main screen; recording a purchase is never more than two taps/keys from launch.
4. **The firewall (see Gamification invariants).** No game mechanic ever changes a cent. Rewards are cosmetic only.

## Non-negotiable invariants

### Money & domain
- Money is integer cents everywhere. Never float/double for money. `Money` value type only. ("Gold" is a display unit; the ledger is cents.)
- All state changes are immutable events appended to the local `events` table. Never UPDATE/DELETE domain rows. Corrections = compensating events. Event sourcing IS the audit log: a human-readable "budget change log" view derives from it; nothing is deletable.
- All derived state comes from `lib/domain/reducer.dart` — a pure function `List<Event> -> HouseholdState`. UI, sync, game, OCR, and the receipt library never compute balances themselves.
- Everything time-based (interest, accruals, grace periods, month-end behavior) is computed in the reducer at read time. No scheduled jobs.
- Months are calendar months in the household timezone (America/Vancouver), keyed by `occurredAt` (user-editable), not `createdAt`. Event IDs are UUIDv7.

### Household & membership
- A household has N **members**: role `adult` | `dependent` | `pet` (`MemberSet {memberId, name, role, active, customSpriteSha256?, descriptionText?}`). `descriptionText` is the user-written character description used by text-mode adventure.
- Adults have income, a vault, personal categories, and their own paired devices (a member may pair any number of phones/desktops). Dependents and pets are display-level party members with no ledger of their own — everything remains household money. Pets are members, never optional metadata on a category; categories and emergency funds may *link* to a pet member for display (the pet "owns" its micro-budget and reserve cache on screen).
- Group costs split by a per-adult **share table** (`GroupShareSet {month, shares: {adultId: permille}}`), default even split. All former 50/50 rules generalize to shares; odd cents go to the purchaser.
- A single-adult household is valid: approvals requiring "another adult" are auto-satisfied when exactly one adult exists.
- **Full mutual visibility by default:** every adult sees the live state of every other adult's budgets, contributions, vault balance, quests, and OVERBUDGETs. The shared event log is the household's single honest picture; there are no private ledgers. A per-device DISPLAY toggle ("Show other adults' budgets", `lib/features/settings/visibility_prefs.dart`, default on) may hide other adults' personal categories and debts from this device's dashboards — it never affects what syncs, and shared surfaces (group categories, war chest, writs, ransacks) always show.
- Legacy `PetSet` events still reduce (as pet members) for wire compatibility.
- Device-local setup (`LocalSetup`) identifies only this device's adult and the timezone; its legacy two-profile storage shape is compatibility baggage. UI must derive member lists, owner pickers, and party rosters from `MemberSet` state — never from `LocalSetup` — so no screen re-introduces a two-adult assumption.

### Budget categories (user-facing name; internal event names like `BudgetSliceSet` are kept for wire compatibility)
- A category is **personal** (one adult) or **group** (household). The word "slice" never appears in UI or docs.
- Categories belong to a **main category** (`MainCategorySet {id, name, colorArgb, sortOrder}`; defaults: Housing, Food, Transport, Health, Entertainment, Pets, Savings, Misc). Main-category colors drive reports (monthly pie chart of spend by main category) and quest-tithe matching.
- Group categories: limit funded by shares off the top; purchases inherently shared (no toggle); leftover flows automatically and entirely to the war chest; no allocation decision, no tithe.
- Personal categories: purchases may be flagged shared (split by shares at read time, odd cent to purchaser).
- A category may designate an **emergency fund contribution**: fixed amount off the top of its limit monthly into a named emergency fund, regardless of spending. Effective limit = limit − contribution.
- Each category carries an advisory **priority** tag: `necessity` | `important` (default) | `fun`. It never changes a cent by itself; it orders grace-expired ritual resolution (fun categories resolve first, so default OVERBUDGET payments spend fun money before necessities) and drives "take it from a fun budget" suggestions in the ritual UI.

### Income
- `DefaultIncomeSet {forUserId, amountCents, effectiveFromMonth, estimatedHighCents?}` carries forward until changed; `IncomeSet {forUserId, month, amountCents}` overrides a single month. Resolved month income = override ?? latest effective default ?? 0. The income screen must never show blank months when a default exists.
- **Variable earners plan at the low end:** `amountCents` is always the planning figure; `estimatedHighCents` (optional) is the optimistic top of the range, for display only — nothing budget-side may ever plan on it. Job loss, overtime, or short hours in a specific month are recorded as plain single-month overrides; a new default handles a lasting change.

### Recurring expenses ("equipment maintenance")
- `RecurringExpenseSet {name, ownership personal(user)|shared, kind fixed|variable, cadence monthly|annual, amountCents, dueDay, dueMonth? (annual), startMonth, endMonth?}`. Shared ones split by shares off the top; personal ones off the top of that adult's budget. Modifiable and cancellable any time.
- **Annual accrual:** annual expenses charge 1/12 monthly off the top (remainder cents land in the due month so the year sums exactly); the due month applies the real amount against the accumulated reserve and surfaces shortfall/surplus. Due dates are shown ("Rent — last day of month", "WoW — Feb 10").
- Variable expenses: `VariableExpenseRecorded {expenseId, month, actualCents}` supplies the actual, normally during the month-close ritual. Reducer uses actual if recorded, else the estimate; late recording is a normal retroactive correction.

### Quests (savings-goal monsters) — the goals system
- `QuestSet {questId, name, targetCents, mainCategoryId, ownership personal(user)|shared, customSpriteSha256?, descriptionText?}` creates a savings goal ("$500 jacket", "$1300 canoe", house down payment, vacation fund). Personal quests funded by their owner; shared quests by any adult.
- Quests are funded ONLY by spoils allocations at month close.
- **Category-match tithing:** an attack funded from a category whose main category MATCHES the quest's is untithed (full damage). From a NON-matching category, the source category's pool tithe applies: tithe portion to the war chest, remainder is damage. (Canonical test: $100 hygiene leftover, 50% tithe, attacking an Entertainment console quest → $50 chest + $50 damage; $100 entertainment leftover, 20% tithe, same quest → $100 damage, $0 tithe.) The UI always shows the split before confirming.
- Buying the goal = a purchase with chargeTarget QUEST(id), drawing down its balance; reaching target = quest complete (trophy celebration).
- `QuestAbandoned` returns the remaining balance to funders' vaults in proportion to contributions, minus the household **dissolution tithe** (setting, default 10%) to the war chest.

### Month close: dividing the spoils
- For each **personal** category with leftover (max(0, effectiveLimit − spent)), the owner allocates via `LeftoverAllocated` among: **carry in-category 1:1** (raises next month's effective limit, stacks uncapped) | **attack a quest** (category-match tithe rule above) | **convert to discretionary** (enters the owner's vault minus that category's **pool tithe** %, tithe to war chest; floor rounding to the chest, must sum exactly).
- The ritual opens with recording actuals for variable recurring expenses.
- Interactive but never blocking: past the grace period (setting, default 7 days) with no allocation event, the reducer applies the category's configured default policy at read time. Group-category leftovers and emergency contributions are automatic and shown read-only.

### Overspending settlement — the OVERBUDGET
- When a month **closes**, each personal category's overflow (spent − effective limit) is **seized from the owner's vault** automatically, using only funds available by that month (later gifts never retroactively cover an old overflow). Whatever the vault cannot cover becomes an **OVERBUDGET debt** on that category. The still-open month shows overspend (enraged monster) but creates no debt yet.
- Debts are paid by **`OverbudgetPayment` leftover allocations** (a fourth `LeftoverDestination`): category-match tithing applies exactly as for quests, against the indebted category's main category. The UI sends the WHOLE leftover as one payment; the OVERBUDGET never takes more post-tithe funds than it needs. Canonical example: $40 debt, $50 non-matching leftover at 10% → $5 tithe to the chest, $40 pays the debt, $5 to discretionary (already tithed, no second cut). A matched attack pays at full value and only its excess beyond the debt converts to discretionary with the usual tithe, so overpaying never dodges the cut.
- Past grace with no allocation, the **default attacks the owner's outstanding OVERBUDGETs first** (gross amounts sized so post-tithe damage covers each debt, sliceId order), then falls back to the configured policy. Explicit allocations may skip the debt (a deliberate choice; the UI pre-selects paying it).
- **Lock:** the debt stands at full HP through each month's ritual window (month start + grace days) so leftovers can attack it. Once the window passes, the indebted category's monthly funding immediately pays whatever remains (effective limit = max(0, funding − debt)) and the monster leaves if covered. Debts self-liquidate, so a locked category always frees itself eventually.
- Group-category overflow draws from the war chest at close (the mirror of leftovers flowing in).
- OVERBUDGETs are household-visible: every adult sees every debt (dashboard banner, game monster). All of this is reducer math — the game only renders it.

### Vaults, gifts, war chest, emergency funds, ransacks
- Purchase charge targets: category, VAULT, QUEST(id), EMERGENCY(fundId), VACATION(vacationId, categoryId).
- Vault(adult), derived = Σ discretionary allocations (post-tithe) + gifts + approved withdrawals directed to them + abandoned-quest returns (post dissolution tithe) − vault-charged spending − pool contributions. Clamp at zero with an inconsistency flag.
- `GiftReceived` credits the vault, untithed.
- War chest (long-term pool) = category tithes + dissolution tithes + group-category leftovers + `PoolContributionMade` + `TaxRefundRecorded` − approved withdrawals − ransack overflows.
- **Withdrawals require another adult**: `PoolWithdrawalProposed` pending until `PoolWithdrawalApproved` by a DIFFERENT adult (reducer rejects self-approval; auto-approved in single-adult households) or cancelled. Pending proposals visible to all adults.
- Emergency funds: named household funds, optionally pet-linked; balance = Σ contributions − emergency-charged spending. Spending needs only a note. **Ransack rule:** an emergency purchase exceeding its fund draws the excess from the war chest WITHOUT prior approval; the reducer surfaces a prominent ransack record all adults see. No silent overdrafts, no blocked emergencies.
- The war chest may carry a target (`GoalSet`); pctComplete = pool/target; estMonthsRemaining = remaining / trailing-3-month average net inflow, null when ≤ 0.

### Net worth (tracked accounts — never budget money)
- `TrackedAccountSet {accountId, name, kind savings|investment|debt, aprBps?, accrualCadence?, updateCadence?, minPaymentCents?}` + `AccountBalanceRecorded` + `AccountTransferRecorded`. Savings/debt current value = last recorded balance + interest accrued since, derived at read time. Investments show a "stale — update requested" nudge past their cadence; never auto-changed.
- Debt minimum payments surface automatically as recurring expenses. Tracked accounts never enter category math; they exist for the net-worth screen and onboarding.

### Vacation mode
- `VacationSet {vacationId, name, fundQuestId|emergencyFundId, startDate, endDate, categories:[{name, limitCents}]}` / `VacationClosed`. A self-contained sub-budget drawn from its fund: per-category tracking, daily-allowance math, overspend warnings. Normal monthly budgets untouched. Closing returns leftover to the source fund. Quick entry gains a vacation charge target while one is open. Adventure skin: an "expedition abroad" side-floor.

### Tax tracking (must stay unobtrusive)
- Per-category `taxDeductibleByDefault`; per-purchase override (null = inherit). Never on the quick-entry keypad — only category settings and the purchase detail sheet.
- Tax year = calendar year, household timezone. Tax package export: zip with summary.csv (date, user, category, merchant, amount, shared flag, note, receipt filename) of all deductible purchases in a chosen year plus every referenced receipt file.

### Receipts, OCR & the receipt library
- Purchases carry an optional `merchant` string (OCR prefills; user-editable).
- Receipt images/PDFs are NOT events: content-addressed blobs at `blobs/<sha256>`, referenced by `ReceiptAttached`/`ReceiptDetached`. Referenced blobs never deleted. Images re-encoded on attach: JPEG ~85, max dimension 2000px; PDFs as-is. Custom sprites (quests, members, avatars) use the same blob pipeline.
- OCR: Android-only, fully on-device (google_mlkit_text_recognition, bundled model, no network). **Confirm-only**: may prefill amount, date, merchant; may NEVER create or commit an event without explicit user confirmation of at least the amount. Heuristics live in `lib/data/ocr/receipt_parse.dart` as a pure, unit-tested function.
- **Receipt library (desktop only): a regenerable projection, never a source of truth.** Mirrors receipt blobs into `<root>/<year>/<category name>/<yyyy-MM-dd>_<merchant or 'receipt'>_<amount>.<ext>` (sanitized, de-duplicated with _2 suffixes). Rebuilding from scratch must produce identical content. A file already holding the exact receipt bytes is left untouched (never rewritten); only a file whose content drifted from the canonical receipt is restored.
- **Receipt storage modes (per device, phones):** `keep` (default — every image stays), `offload` (after a clean sync cycle, receipt blobs that EVERY paired hub confirms holding are deleted locally; offloaded hashes are remembered so pulls don't re-fetch them, and viewing fetches the bytes back on demand; confirmation is conservative — any unreachable hub keeps the copy), or `none` (scan-only: OCR prefills the purchase and the image is discarded, never attached). Sprites are never offloaded. "Referenced blobs never deleted" still holds household-wide — only a device's cached copy goes.

### Sync (multi-hub) & merge-import
- No internet services. Any desktop build can host a hub (package:shelf) on the LAN; a device may pair with MULTIPLE hubs with independent pull cursors. Event idempotency by eventId makes multi-hub convergence safe with no conflict logic; blobs are content-addressed. Every device syncs with every reachable paired hub each cycle.
- Hub endpoints: POST /pair {pairingSecret, deviceName} -> deviceToken; POST /events (batch, idempotent, per-hub monotonic hub_seq); GET /events?after=<seq>; PUT /blobs/<sha256> (idempotent, hash-verified, 20MB cap); GET /blobs/<sha256>. Pairing via QR {url, pairingSecret}; tokens in flutter_secure_storage.
- **Merge-import is a first-class flow** (the "vacation swap"): export/import `.dbevents` (JSON lines) or `.dbevents.zip` (events.jsonl + blobs/). Import is idempotent — it only adds missing events, never overwrites — and shows a preview ("14 new events, 3 receipts — 210 already present") before applying and a summary after. An "export since last export" shortcut supports exchanging files between devices with no hub.
- Everything works offline indefinitely; failures are silent-but-visible via a status indicator, never blocking dialogs.

### Exports
- **.xlsx export**: fully offline, always available. Workbook sheets: Transactions, Monthly summary (per category budgeted/spent/leftover), Members & income, Savings goals, Net worth, Recurring expenses.
- **Google Sheets sync**: the ONLY permitted external service. OFF by default; explicit opt-in with a clear "your data leaves your local network" warning; user supplies their own credentials; isolated behind an interface so the app builds and fully functions with it absent; no other feature may depend on it. Platform-guarded like the OCR plugin.

### Gamification — the game IS the app, but it never touches the money

**The firewall.** `lib/game/` maps `HouseholdState -> GameState` via `lib/game/adapter.dart` (pure, tested) and may append ONLY cosmetic events (`CosmeticSet`, `GameRewardGranted`, sprite/description references). The money reducer ignores cosmetic events entirely — a ledger with all cosmetic events stripped produces identical balances (keep a test asserting this). No reward, streak, story beat, or game mechanic may alter any cents amount, limit, tithe, share, or allocation. The spoils/tithe math IS the combat math — the game displays it, never redefines it.

**Core mapping.** Personal category = monster (maxHP = effective limit, damage = spent; overspend = enraged + player HP loss); group category = party contract with a multi-color banner; pet-linked categories/funds sit under the pet party member; recurring expenses + emergency contributions = "equipment maintenance & provisioning" at floor start (variable = 'awaiting tally'; annual = provisioning contracts with countdown); income = expedition supplies; month = dungeon floor; month close = dividing-the-spoils battle ritual (attacks show damage numbers; a mismatch tithe shows the war-chest cut flying off as coins); quest = quest boss hunted across months (HP = target, allocations = damage, completion = trophy); vault = gold pouch; withdrawal = writ needing another adventurer's signature; ransack = a loud "the war chest was ransacked" banner; gift = treasure found; tax refund = royal rebate; emergency funds = reserve caches; tax marker = small scroll seal on purchase detail only; unsettled overspending = the **OVERBUDGET**, an intimidating debt monster (HP = outstanding debt) that locks its category until felled.

**Rewards & habit loop (all cosmetic).** Defeating a quest boss grants a trophy displayed in the party's trophy hall. Streaks — consecutive days with purchases logged, consecutive on-time month-close rituals — earn cosmetic titles and badges. Every ritual completion gets a celebration. Rewards are recorded as cosmetic events so they sync like everything else.

**Meta-progression: the Homestead.** The war chest is visualized as something being built/cared for outside the dungeon — default flavor: a homestead under construction that gains visible stages as the real pool balance crosses thresholds (flavor selectable/renameable; e.g. a town, a ward being cared for). Pure visualization of real numbers; thresholds configurable; never gates or modifies anything financial.

**Story.** A light frame narrative delivered through the adventure log in game voice ("GROCERIES MONSTER TAKES 42 DMG", "THE WAR CHEST WAS RANSACKED!"). All narrative/encouragement strings are data-driven (asset files, not hardcoded) so writers can contribute without touching code; `docs/voice-lines.md` lists every line beside its trigger and intended outcome for exactly that purpose.

**Asset degradation ladder (art is scarce: one beginner artist).** Every game surface must render fully at three tiers, decided per-asset at runtime:
  1. **Full pixel art** — the target look: a pixel dungeon crawler (party frames with HP bars around a central floor viewport, scrolling log, minimap of the year's floors).
  2. **Partial** — available sprites render; missing ones degrade to labeled placeholder cards. Never crash, never block a screen on a missing asset.
  3. **Text mode** — a first-class text-adventure presentation (not an error state): the same screens rendered as styled text panels using member/pet/quest `descriptionText` written by the user. The app must be complete, shippable, and fun in text mode alone.
- **Default tier:** Adventure reads as the text RPG unless real art is provided. While the bundled sprites are script-generated placeholders, new devices default to text mode (`defaultAdventureTier` in `lib/game/skin_prefs.dart`); when the commissioned art lands, flip that constant to pixel. An explicit per-device choice always wins.
- Pixel art renders with FilterQuality.none at integer scales; assets in `app/assets/game/` per `docs/art-assets.md`; custom sprite blobs use the same pixelated pipeline.
- `docs/art-assets.md` is written for a first-time pixel artist: one small fixed palette, ONE base sprite size (32×32) plus one portrait size (48×48), 9-slice panel spec, and a prioritized "first ten assets" list. Every asset is individually optional.

**Modes.** Adventure (default) / Classic, toggleable; both render from the same providers with identical numbers. Classic uses plain language only — no "slice", "tithe", "spoils", "dissolution", "grace period" in Classic UI; a glossary module (single source of truth for strings) maps internal → Classic → Adventure terms, with helper text under every setting.

### Distribution & metrics
- Distribution is GitHub Releases only: tagged CI builds attach a signed Android APK and Windows/macOS/Linux desktop bundles. Sharing the app = sharing a release link.
- **User counts come from the GitHub Releases download statistics API — never from the app.** No telemetry, no analytics SDKs, no phone-home of any kind. A documented script fetches cumulative download counts (the resume number).

## Stack
Flutter stable + Riverpod (codegen) + drift + go_router + fl_chart + shelf + mobile_scanner + flutter_secure_storage + image_picker + file_selector + crypto + archive + an image re-encoding package + google_mlkit_text_recognition (Android only, platform-guarded) + a pure-Dart xlsx writer + (optional, isolated) Google Sheets client. No other dependencies without stating why in the commit body. No paid or account-based services in the core app.

## Structure
- `app/lib/domain/` pure Dart, zero Flutter imports.
- `app/lib/data/` drift, sync client (multi-hub), hub server, blob store, ocr/ (pure parser + thin plugin wrapper), receipt library projector, import/export (+ merge preview), xlsx export, sheets/ (optional, isolated), tax package export.
- `app/lib/game/` adapter.dart (pure GameState mapping) + rewards/ (cosmetic reward logic, pure) + text_mode/ + pixel widgets; narrative/encouragement strings under `app/assets/game/text/`.
- `app/lib/features/<name>/` classic UI per feature.
- `app/lib/ui/` theme + shared widgets + the glossary/strings module.
- `docs/` architecture, protocol, art specs, distribution, ADRs.

## Environment
- The Flutter SDK is provisioned once by `tool/setup-env.sh` (run as the environment setup command, snapshotted). It installs Flutter to `/opt/flutter` and adds `/opt/flutter/bin` to PATH. Do NOT clone or reinstall Flutter inside a session — if `flutter` is not on PATH, run `export PATH="/opt/flutter/bin:$PATH"` (or `source tool/setup-env.sh`) rather than re-installing.

## Workflow rules
- TDD for `lib/domain/`, `lib/game/adapter.dart`, `lib/game/rewards/`, `lib/data/ocr/receipt_parse.dart`, and the receipt-library path/naming logic: tests before implementation. `./check.sh` (dart analyze + flutter test) must pass before any commit.
- The firewall test (cosmetic-stripped ledger ⇒ identical balances) must exist and pass from the first rewards commit onward.
- Conventional commits, one commit per completed task.
- Build only what the current phase prompt asks. If a phase seems to require changing the reducer and the prompt says it should not, stop and say so instead of proceeding.
