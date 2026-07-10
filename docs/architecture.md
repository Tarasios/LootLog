# LootLog Architecture

This is a reference document restating, in our own words, the invariants and
subsystems that govern LootLog. It is descriptive: when this document and
`CLAUDE.md` disagree, `CLAUDE.md` wins. Nothing here is a suggestion — the
"non-negotiable invariants" are load-bearing constraints that the whole design
depends on.

LootLog is a **pixel-art dungeon-crawler that happens to be a rigorous shared
budgeting app.** The game is the product: the household is a party of
adventurers delving a dungeon, budget categories are monsters, savings goals are
quest bosses, and month close is a battle ritual. Underneath sits a local-first,
event-sourced, integer-cents ledger that the game layer can read but **never
alter.** It is Flutter only (Android + desktop Windows/macOS/Linux), with no
external services, servers, accounts, or SaaS beyond one opt-in exception
(Google Sheets, §14). Desktops act as sync hubs on the local network; OCR runs
on-device. (LootLog was renamed from DuoBudget (the repository keeps the old name); households are any size.)

## 0. Product priorities (in order)

1. **Game first.** Adventure mode is the primary, default experience on every
   platform. Classic mode is the plain fallback view, always available, always
   showing identical numbers.
2. **Habit formation.** The app succeeds if users come back daily to log
   purchases and monthly for the ritual. Streaks, celebrations, and an
   encouraging voice are core features. The app never shames: overspending makes
   a monster *enraged* (drama), but the copy stays supportive.
3. **Goals-orientation.** Savings quests and progress are front-and-center;
   recording a purchase is never more than two taps/keys from launch.
4. **The firewall.** No game mechanic ever changes a cent. Rewards are cosmetic
   only (see §11).

## 1. Core invariants

### Money
- Money is **integer cents everywhere**. Never `float`/`double` for money. A
  single `Money` value type carries amounts. "Gold" is only a display unit in
  the adventure presentation; the underlying ledger is always cents.

### Event sourcing
- All state changes are **immutable events** appended to a local `events`
  table. Domain rows are never `UPDATE`d or `DELETE`d. Corrections are made by
  appending **compensating events**, not by mutating history. Event sourcing IS
  the audit log: a human-readable "budget change log" view derives from it, and
  nothing is deletable.
- All derived state is produced by `lib/domain/reducer.dart`: a **pure
  function** `List<Event> -> HouseholdState`. The UI, sync, game layer, OCR, and
  receipt library never compute balances themselves — they read from the
  reducer's output. This is the single source of truth for "what is true now".
- Everything time-based (interest, accruals, grace periods, month-end behavior)
  is computed **in the reducer at read time**. There are no scheduled jobs or
  background cron.
- **Months** are calendar months in the household timezone
  (America/Vancouver), keyed by each event's `occurredAt` (user-editable), not
  by `createdAt`. Event IDs are **UUIDv7** (time-ordered).

## 2. Household and membership

A household has **N members**, each with a role
(`MemberSet {memberId, name, role, active, customSpriteSha256?,
descriptionText?}`):

- **adult** — has income, a vault, personal categories, and paired devices (a
  member may pair any number of phones/desktops).
- **dependent** — a display-level party member with no ledger of their own.
- **pet** — likewise display-level; categories and emergency funds may *link* to
  a pet member so the pet "owns" that micro-budget or reserve cache on screen.
  Pets are members, never metadata on a category.

`descriptionText` is the user-written character description that drives
text-mode adventure (§11).

**Shares.** Group costs split by a per-adult **share table**
(`GroupShareSet {month, shares: {adultId: permille}}`), default even split. Every
former 50/50 rule generalizes to these shares; **odd cents go to the
purchaser.** A **single-adult household is valid**: approvals requiring "another
adult" are auto-satisfied when exactly one adult exists.

Legacy `PetSet` events still reduce (as pet members) for wire compatibility.

## 3. Budget categories

The user-facing name is **category**; the internal event names (e.g.
`BudgetSliceSet`) are kept for wire compatibility. **The word "slice" never
appears in UI or docs.** A category is either:

- **personal** — owned by exactly one adult, or
- **group** — shared by the household.

Every category belongs to a **main category**
(`MainCategorySet {id, name, colorArgb, sortOrder}`; defaults: Housing, Food,
Transport, Health, Entertainment, Pets, Savings, Misc). Main-category **colors
drive reports** (a monthly pie chart of spend by main category) and are the key
for **quest-tithe matching** (§4).

**Group categories**
- The limit is funded **by shares off the top**.
- Purchases are inherently shared — there is no "shared?" toggle shown.
- Leftover at month end flows **automatically and entirely to the war chest**.
- There is no allocation decision and no tithe on group categories.

**Personal categories**
- A purchase may be flagged **shared**, in which case it is split by shares at
  read time, with the odd cent going to the purchaser.

**Emergency fund contribution**
- Any category may designate a fixed monthly **emergency fund contribution**: a
  fixed amount taken off the top of its limit each month into a named emergency
  fund, regardless of spending.
- The **effective limit** of such a category is `limit − contribution`.

## 3a. Income

- `DefaultIncomeSet {forUserId, amountCents, effectiveFromMonth}` carries
  forward until changed.
- `IncomeSet {forUserId, month, amountCents}` overrides a single month.
- Resolved month income = `override ?? latest effective default ?? 0`. The
  income screen must never show a blank month when a default exists.

## 4. Recurring expenses ("equipment maintenance")

`RecurringExpenseSet {name, ownership: personal(user) | shared, kind: fixed |
variable, cadence: monthly | annual, amountCents, dueDay, dueMonth? (annual),
startMonth, endMonth?}`.

- **Shared** recurring expenses split by shares off the top; **personal** ones
  come off the top of that adult's budget. Modifiable and cancellable at any
  time.
- **Annual accrual.** An annual expense charges **1/12 monthly off the top**,
  with the integer-cents **remainder landing in the due month so the year sums
  exactly.** The due month applies the real amount against the accumulated
  reserve and surfaces any shortfall/surplus. Due dates are shown ("Rent — last
  day of month", "WoW — Feb 10").
- **Variable expenses.** `VariableExpenseRecorded {expenseId, month,
  actualCents}` supplies the real amount, normally during the month-close
  ritual. The reducer uses the recorded actual if present, otherwise the
  estimate. Late recording is a normal retroactive correction.

## 5. Quests (savings-goal monsters) — the goals system

`QuestSet {questId, name, targetCents, mainCategoryId, ownership:
personal(user) | shared, customSpriteSha256?, descriptionText?}` creates a
savings goal (e.g. "$500 jacket", "$1300 canoe", a house down payment, a
vacation fund).

- Personal quests are funded by their owner; shared quests by any adult.
- Quests are funded **only** by spoils allocations at month close (§6).
- **Category-match tithing.** An attack funded from a category whose main
  category **matches** the quest's `mainCategoryId` is **untithed** (full
  damage). From a **non-matching** category, the source category's **pool tithe
  applies**: the tithe portion goes to the war chest, the remainder is damage.
  Canonical cases: $100 Hygiene leftover, 50% tithe, attacking an Entertainment
  console quest → **$50 chest + $50 damage**; $100 Entertainment leftover, 20%
  tithe, same quest → **$100 damage, $0 tithe**. The UI always shows the split
  before confirming.
- **Buying the goal** is a purchase with `chargeTarget = QUEST(id)`, drawing
  down its balance. Reaching the target = quest complete (trophy celebration).
- `QuestAbandoned` returns the remaining balance to funders' vaults in
  proportion to contributions, **minus the household dissolution tithe** (a
  setting, default 10%) to the war chest.

## 6. Month close: dividing the spoils

The month-close ritual first **records actuals** for variable recurring
expenses for the closed month.

For each **personal** category with leftover — `max(0, effectiveLimit − spent)`
— the owner allocates it via `LeftoverAllocated` among:

1. **Carry in-category 1:1** — raises next month's effective limit for that
   category; stacks without cap.
2. **Attack a quest** — funds a quest; tithe follows the **category-match rule**
   (§5).
3. **Convert to discretionary** — enters the owner's vault **minus that
   category's pool tithe** (a per-category percentage, 0–100). The tithe portion
   goes to the war chest. Rounding **floors to the chest**, with the remainder
   to the user, and the two parts must sum exactly to the converted amount.

**Group-category leftovers** and **emergency contributions** are automatic and
shown read-only.

**Never blocking.** The ritual is interactive but never blocks. If the grace
period (a setting, default 7 days after month close) passes with no allocation
event, the reducer applies the category's configured **default policy** at read
time. Nothing waits on the user.

## 7. Vaults, gifts, war chest, emergency funds, ransacks

**Purchase charge targets:** `category`, `VAULT`, `QUEST(id)`,
`EMERGENCY(fundId)`, `VACATION(vacationId, categoryId)`.

**Vault(adult)** — derived as:
`Σ discretionary allocations (post-tithe) + gifts + approved withdrawals
directed to them + abandoned-quest returns (post dissolution tithe)
− vault-charged spending − pool contributions`.
Clamped at zero, raising an **inconsistency flag** if it would go negative.

**Gifts.** `GiftReceived` credits the vault, untithed.

**War chest** (the long-term shared pool) =
`category tithes + dissolution tithes + group-category leftovers
+ PoolContributionMade + TaxRefundRecorded
− approved withdrawals − ransack overflows`.

**Withdrawals require another adult.** A `PoolWithdrawalProposed` stays pending
until a `PoolWithdrawalApproved` by a **different** adult (the reducer rejects
self-approval; auto-approved in single-adult households) or a
`PoolWithdrawalCancelled`. Pending proposals are visible to all adults.

**Emergency funds.** Named household funds, optionally linked to a pet member.
`balance = Σ contributions − emergency-charged spending`. Spending from one
needs only a note. **Ransack rule:** an emergency purchase that exceeds its
fund's balance draws the excess from the war chest **without prior approval**,
and the reducer surfaces a prominent **ransack record** all adults see. There
are no silent overdrafts and no blocked emergencies.

**War chest goal.** The war chest may carry its own target (`GoalSet`).
`pctComplete = pool / target`; `estMonthsRemaining = remaining / trailing-3-
month average net inflow`, and is `null` when that average is `≤ 0`.

## 8. Net worth (tracked accounts — never budget money)

`TrackedAccountSet {accountId, name, kind: savings | investment | debt, aprBps?,
accrualCadence?, updateCadence?, minPaymentCents?}` + `AccountBalanceRecorded` +
`AccountTransferRecorded`.

- **Savings / debt** current value = last recorded balance **+ interest accrued
  since**, derived at read time.
- **Investments** show a **"stale — update requested"** nudge past their
  `updateCadence`; they are never auto-changed.
- **Debt minimum payments** surface automatically as recurring expenses.

Tracked accounts **never enter category math** — they exist only for the
net-worth screen and onboarding, behind a "Show net worth" setting.

## 9. Vacation mode

`VacationSet {vacationId, name, fundQuestId | emergencyFundId, startDate,
endDate, categories: [{name, limitCents}]}` / `VacationClosed`.

A vacation is a **self-contained sub-budget drawn from its fund** (a savings
quest or an emergency fund): per-category tracking, daily-allowance math, and
overspend warnings, all scoped to the trip. **Normal monthly budgets are
untouched** while it runs. Quick entry gains a **vacation charge target**
(`VACATION(vacationId, categoryId)`) while a vacation is open. **Closing returns
leftover to the source fund.** The adventure skin renders it as an "expedition
abroad" side-floor.

## 10. Tax tracking (stays unobtrusive)

- Per-category `taxDeductibleByDefault`, with a per-purchase override (`null` =
  inherit from the category).
- The tax flag is **never on the quick-entry keypad** — it appears only in
  category settings and the purchase detail sheet.
- **Tax year** = calendar year in the household timezone.
- **Tax package export**: a zip containing `summary.csv` (date, user, category,
  merchant, amount, shared flag, note, receipt filename) of all deductible
  purchases in a chosen year, plus every referenced receipt file.

## 11. The game IS the app, but it never touches the money

The game is not a skin bolted on — it is the primary experience (§0). But it
never moves a cent.

**The firewall.** `lib/game/` maps `HouseholdState -> GameState` via
`lib/game/adapter.dart` (pure, tested) and may append **only cosmetic events**
(`CosmeticSet`, `GameRewardGranted`, sprite/description references). The money
reducer **ignores cosmetic events entirely** — a ledger with all cosmetic events
stripped produces identical balances, and **a test asserts exactly that** from
the first rewards commit onward. No reward, streak, story beat, or homestead
threshold may alter any cent, limit, tithe, share, or allocation. **The
spoils/tithe math IS the combat math** — the game displays it, never redefines
it.

**Core mapping.**
- personal category → monster (maxHP = effective limit, damage = spent;
  overspend = enraged + player HP loss)
- group category → party contract with a multi-color banner
- pet-linked categories/funds → shown under the pet party member
- recurring expenses + emergency contributions → "equipment maintenance &
  provisioning" at floor start (variable = "awaiting tally"; annual =
  provisioning contracts with a countdown)
- income → expedition supplies
- month → a dungeon floor
- month close → the dividing-the-spoils battle ritual (attacks show damage
  numbers; a mismatch tithe shows the war-chest cut flying off as coins)
- quest → a quest boss hunted across months (HP = target, allocations = damage,
  completion = trophy)
- vault → gold pouch
- withdrawal → a writ needing another adventurer's signature
- ransack → a loud "the war chest was ransacked" banner
- gift → treasure found; tax refund → royal rebate
- emergency funds → reserve caches; tax marker → a small scroll seal, on the
  purchase detail only

**Rewards & the habit loop (all cosmetic).** Defeating a quest boss grants a
trophy in the party's trophy hall. Streaks — consecutive days with purchases
logged, consecutive on-time month-close rituals — earn cosmetic titles and
badges. Every ritual completion gets a celebration. Rewards are recorded as
cosmetic events so they sync like everything else.

**Meta-progression: the Homestead.** The war chest is visualized as something
built/cared for outside the dungeon — default flavor a homestead under
construction that gains visible stages as the real pool balance crosses
configurable thresholds (flavor selectable/renameable). Pure visualization of
real numbers; it never gates or modifies anything financial.

**Story.** A light frame narrative delivered through the adventure log in game
voice ("GROCERIES MONSTER TAKES 42 DMG", "THE WAR CHEST WAS RANSACKED!"). All
narrative/encouragement strings are **data-driven** (asset files under
`app/assets/game/text/`, not hardcoded) so writers can contribute without
touching code.

**The asset-degradation ladder.** Art is scarce (one beginner artist), so every
game surface must render fully at **three tiers, decided per-asset at runtime**:

1. **Full pixel art** — the target look: party frames with HP bars around a
   central floor viewport, a scrolling log, and a minimap of the year's floors.
2. **Partial** — available sprites render; missing ones degrade to **labeled
   placeholder cards.** Never crash, never block a screen.
3. **Text mode** — a **first-class text-adventure presentation, not an error
   state**: the same screens rendered as styled text panels using the
   member/pet/quest `descriptionText`. The app must be complete, shippable, and
   fun in text mode alone.

Pixel art renders with `FilterQuality.none` at integer scales; assets live in
`app/assets/game/` per `docs/art-assets.md` (one small palette, one 32×32 base
sprite size, one 48×48 portrait size, a 9-slice panel spec, a prioritized
"first ten assets" list — every asset individually optional). Custom sprite
blobs render through the same pixelated pipeline.

**Modes.** Adventure (default) / Classic, toggleable; both render from the same
providers with identical numbers. Classic uses plain language only — no "slice",
"tithe", "spoils", "dissolution", or "grace period" in Classic UI. A **glossary
module** (single source of truth for strings) maps internal → Classic →
Adventure terms, with helper text under every setting.

## 12. Receipts, OCR, and the receipt library

**Receipts are not events.** Receipt images/PDFs are **content-addressed
blobs** stored at `blobs/<sha256>`, referenced by `ReceiptAttached {purchaseId,
sha256, mimeType, sizeBytes}` and removed (as a reference) by `ReceiptDetached`.
Referenced blobs are never deleted. Images are re-encoded on attach (JPEG ~85,
max dimension 2000px); PDFs are stored as-is. Custom sprites (quests, members,
avatars) use the **same blob pipeline** via their sha256 references.

**OCR** is **Android-only** and **fully on-device**
(`google_mlkit_text_recognition`, bundled model, no network). It is
**confirm-only**: it may prefill amount, date, and merchant, but may **never**
create or commit an event without explicit user confirmation of at least the
amount. The parsing heuristics live in `lib/data/ocr/receipt_parse.dart` as a
pure, unit-tested function.

**Receipt library (desktop only).** A **regenerable projection**, never a
source of truth. The user picks a root folder; the app mirrors receipt blobs
into
`<root>/<year>/<category name>/<yyyy-MM-dd>_<merchant or 'receipt'>_<amount>.<ext>`
(sanitized, de-duplicated with `_2` suffixes). Rebuilding from scratch must
produce identical content; any user edits inside the folder are ignored and
overwritten.

## 13. Sync (multi-hub) and merge-import

No internet services. Any desktop build can host a **hub** (`package:shelf`) on
the LAN. A device may be paired with **multiple hubs**, keeping an independent
pull cursor per hub. Event idempotency by `eventId` makes multi-hub convergence
safe with **no conflict logic**; blobs are content-addressed. Every device syncs
with every reachable paired hub each cycle.

**Hub endpoints** (full wire format in [`protocol.md`](protocol.md))
- `POST /pair {pairingSecret, deviceName} -> deviceToken`
- `POST /events` — batch, idempotent, assigns a per-hub monotonic `hub_seq`
- `GET /events?after=<seq>` — a page plus the `seq` cursor to resume from
- `PUT /blobs/<sha256>` — idempotent, hash-verified, 20MB cap
- `GET`/`HEAD /blobs/<sha256>`

Pairing carries `{url, pairingSecret}` (a QR payload, also enterable by hand on
desktop); tokens are held in `flutter_secure_storage`.

**Merge-import is a first-class flow** (the "vacation swap"). Export/import
`.dbevents` (JSON lines) or `.dbevents.zip` (`events.jsonl` + `blobs/`). Import
is **idempotent** — it only adds missing events, never overwrites — and shows a
**preview** ("14 new events, 3 receipts — 210 already present") before applying
and a **summary** after. An "export since last export" shortcut supports
exchanging files between devices with no hub.

Everything works **offline indefinitely**. Failures are **silent-but-visible**
via a status indicator — never blocking dialogs. `tool/e2e.sh` exercises the
whole sync path end to end.

## 14. Exports

- **.xlsx export** — fully offline, always available. Workbook sheets:
  Transactions, Monthly summary (per category budgeted/spent/leftover),
  Members & income, Savings goals, Net worth, Recurring expenses.
- **Google Sheets sync** — the **only permitted external service**, and a
  deliberate, contained relaxation of the no-external-services rule. **OFF by
  default**; explicit opt-in with a clear "your data leaves your local network"
  warning; user supplies their own credentials; **isolated behind an interface**
  so the app builds and fully functions with it absent; **no other feature may
  depend on it**; platform-guarded like the OCR plugin.

## 15. Distribution and metrics

- **Distribution is GitHub Releases only.** Tagged CI builds attach a signed
  Android APK and Windows/macOS/Linux desktop bundles. Sharing the app = sharing
  a release link.
- **User counts come from the GitHub Releases download-statistics API — never
  from the app.** No telemetry, no analytics SDKs, no phone-home of any kind. A
  documented script fetches cumulative download counts (the resume number).

## 16. Code structure

- `app/lib/domain/` — pure Dart, **zero Flutter imports**.
- `app/lib/data/` — drift, the multi-hub sync client, the hub server, the blob
  store, `ocr/` (pure parser + a thin plugin wrapper), the receipt-library
  projector, import/export (+ merge preview), xlsx export, `sheets/` (optional,
  isolated), and tax package export.
- `app/lib/game/` — `adapter.dart` (pure `GameState` mapping) + `rewards/`
  (cosmetic reward logic, pure) + `text_mode/` + pixel widgets;
  narrative/encouragement strings under `app/assets/game/text/`.
- `app/lib/features/<name>/` — classic UI, per feature.
- `app/lib/ui/` — theme, shared widgets, and the glossary/strings module.
- `docs/` — architecture, protocol, art specs, distribution, and ADRs.

## 17. Workflow rules

- **TDD** for `lib/domain/`, `lib/game/adapter.dart`, `lib/game/rewards/`,
  `lib/data/ocr/receipt_parse.dart`, and the receipt-library path/naming logic:
  tests are written before implementation.
- **The firewall test** (cosmetic-stripped ledger ⇒ identical balances) must
  exist and pass from the first rewards commit onward.
- `./check.sh` (`dart analyze` + `flutter test`) must pass before any commit.
- Conventional commits, one commit per completed task.
- Build only what the current phase prompt asks for. If a phase seems to require
  changing the reducer but the prompt says it should not, **stop and say so**
  instead of proceeding.

## Decision records

The [ADRs](adr/) record the rationale behind these invariants. Note that
[ADR 0003](adr/0003-gamification-as-skin.md) (gamification as an optional skin)
is **superseded** by [ADR 0011](adr/0011-game-first-with-cosmetic-firewall.md)
(game-first), and [ADR 0005](adr/0005-spoils-economy-and-quests.md) (the spoils
economy) is **amended** by [ADR 0008](adr/0008-flexible-membership-and-shares.md)
(shares), [ADR 0009](adr/0009-categories-and-main-categories.md) (categories),
and [ADR 0010](adr/0010-category-match-tithing.md) (category-match tithing).
