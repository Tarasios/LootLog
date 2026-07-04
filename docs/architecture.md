# DuoBudget Architecture

This is a reference document restating, in our own words, the invariants and
subsystems that govern DuoBudget. It is descriptive: when this document and
`CLAUDE.md` disagree, `CLAUDE.md` wins. Nothing here is a suggestion — the
"non-negotiable invariants" are load-bearing constraints that the whole design
depends on.

DuoBudget is a two-person, local-first shared budgeting app with an optional
"dungeon adventure" presentation skin. It is Flutter only (Android + desktop
Windows/macOS/Linux), with no external services, servers, accounts, or SaaS.
Desktops act as sync hubs on the local network; OCR runs on-device.

## 1. Core invariants

### Money
- Money is **integer cents everywhere**. Never `float`/`double` for money. A
  single `Money` value type carries amounts. "Gold" is only a display unit in
  the adventure skin; the underlying ledger is always cents.

### Event sourcing
- All state changes are **immutable events** appended to a local `events`
  table. Domain rows are never `UPDATE`d or `DELETE`d. Corrections are made by
  appending **compensating events**, not by mutating history.
- All derived state is produced by `lib/domain/reducer.dart`: a **pure
  function** `List<Event> -> HouseholdState`. The UI, sync, game skin, OCR, and
  receipt library never compute balances themselves — they read from the
  reducer's output. This is the single source of truth for "what is true now".
- Everything time-based is computed **in the reducer at read time**. There are
  no scheduled jobs or background cron. "Automatic month-end behavior" means
  "derived when the state is next read", nothing more.
- **Months** are calendar months in the household timezone
  (America/Vancouver), keyed by each event's `occurredAt` (user-editable), not
  by `createdAt`. Event IDs are **UUIDv7** (time-ordered).

## 2. Slices and ownership

A **slice** is a budget category. It is either:
- **personal** — owned by exactly one user, or
- **group** — shared by the household (e.g. groceries, pet care).

A slice may be linked to a pet for display only.

**Group slices**
- The limit is funded **50/50 off the top** of both users' budgets.
- Purchases are inherently shared — there is no "shared?" toggle shown.
- Leftover at month end flows **automatically and entirely to the war chest**.
- There is no allocation decision and no tithe on group slices.

**Personal slices**
- A purchase may be flagged **shared**, in which case it is split 50/50 at read
  time, with the odd cent going to the purchaser.

**Emergency fund contribution**
- Any slice may designate a fixed monthly **emergency fund contribution**: a
  fixed amount taken off the top of its limit each month into a named emergency
  fund, regardless of spending.
- The **effective huntable limit** of such a slice is `limit − contribution`.

## 3. Recurring expenses ("equipment maintenance")

A `RecurringExpenseSet` has:
`{name, ownership: personal(user) | shared, kind: fixed | variable,
amountCents (the amount, or the estimate when variable), startMonth, endMonth?}`

- **Shared** recurring expenses are split 50/50 off the top of both budgets.
  **Personal** ones come off the top of that one user's budget.
- They are modifiable and cancellable at any time (by setting `endMonth`); they
  are otherwise expected to continue every month.
- Examples: rent = shared fixed; a game/Patreon subscription = personal fixed;
  utilities = shared variable.

**Variable expenses.** A `VariableExpenseRecorded {expenseId, month,
actualCents}` supplies the real amount, normally during the month-close ritual.
The reducer uses the recorded actual if present, otherwise the estimate. A late
recording after the grace period is just a normal retroactive correction.

## 4. Quests (savings-goal monsters)

Quests replace any "earmark" concept. A `QuestSet {questId, name, targetCents,
ownership: personal(user) | shared, sliceHint?, customSpriteSha256?}` creates a
savings goal (e.g. "$500 jacket", "$1300 canoe", "house down payment").

- Personal quests are funded by their owner; shared quests by either user.
- Quests are funded **only** by spoils allocations at month close. **Funding a
  quest is untithed.**
- **Buying the goal** is a purchase with `chargeTarget = QUEST(id)`, drawing
  down the quest's balance. Reaching the target = quest complete (celebration).
- `QuestAbandoned` moves the remaining balance back to the funder(s)' vault(s),
  in proportion to their contributions, **minus the household dissolution
  tithe** (a setting, default 10%) which goes to the war chest. This exists so
  that quests cannot be used to dodge slice tithes.

## 5. Month close: dividing the spoils

The month-close ritual first **records actuals** for variable recurring
expenses for the closed month.

For each **personal** slice with leftover — `max(0, effectiveLimit − spent)` —
the owner allocates it via `LeftoverAllocated {userId, month, sliceId,
allocations: [{destination, amountCents}]}`, where each destination is one of:

1. **Carry in-slice 1:1** — raises next month's effective limit for that slice;
   stacks without cap.
2. **Attack a quest** — funds a quest; **untithed**.
3. **Convert to discretionary** — enters the owner's vault, **minus that
   slice's pool tithe** (a per-slice percentage, 0–100). The tithe portion goes
   to the war chest. Rounding **floors to the chest**, with the remainder to the
   user, and the two parts must sum exactly to the converted amount.

**Group-slice leftovers** and **emergency contributions** are automatic and
shown read-only.

**Never blocking.** The ritual is interactive but never blocks. If the grace
period (a setting, default 7 days after month close) passes with no allocation
event, the reducer applies the slice's configured **default policy** at read
time. Nothing waits on the user.

## 6. Vaults, gifts, war chest, emergency funds, ransacks

**Purchase charge targets:** `slice`, `VAULT`, `QUEST(id)`, `EMERGENCY(fundId)`.

**Vault(user)** — derived as:
`Σ discretionary allocations (post-tithe) + gifts + approved withdrawals
directed to them + abandoned-quest returns (post dissolution tithe)
− vault-charged spending − pool contributions`.
Clamped at zero, raising an **inconsistency flag** if it would go negative.

**Gifts.** `GiftReceived {userId, amountCents, note}` credits the vault,
untithed.

**War chest** (the long-term shared pool) =
`slice tithes + dissolution tithes + group-slice leftovers
+ PoolContributionMade + TaxRefundRecorded
− approved withdrawals − ransack overflows`.

**Withdrawals require both users.** A `PoolWithdrawalProposed {byUserId,
amountCents, purpose, destination: userVault(userId) | external}` stays pending
until a `PoolWithdrawalApproved` by the **other** user (the reducer rejects
self-approval) or a `PoolWithdrawalCancelled`. Pending proposals are visible to
both users.

**Emergency funds.** Named household funds, optionally linked to a pet.
`balance = Σ contributions − emergency-charged spending`. Spending from one
needs only a note. **Ransack rule:** an emergency purchase that exceeds its
fund's balance draws the excess from the war chest **without prior approval**,
and the reducer surfaces a prominent **ransack record** `{fund, excess,
purpose}` that both users see. There are no silent overdrafts and no blocked
emergencies.

**War chest goal.** The war chest may carry its own target (`GoalSet`).
`pctComplete = pool / target`; `estMonthsRemaining = remaining / trailing-3-
month average net pool inflow`, and is `null` when that average is `≤ 0`.

## 7. Pets

`PetSet {petId, name, customSpriteSha256?}`. Pets are **display-level party
members**. Slices and emergency funds may reference a `petId`; the pet is then
shown as the "owner" of its micro budget and reserve cache. Pets have **no
ledger of their own** — everything remains household money.

## 8. Tax tracking (stays unobtrusive)

- Per-slice `taxDeductibleByDefault`, with a per-purchase override (`null` =
  inherit from the slice).
- The tax flag is **never on the quick-entry keypad** — it appears only in
  slice settings and the purchase detail sheet.
- **Tax year** = calendar year in the household timezone.
- **Tax package export**: a zip containing `summary.csv` (date, user, slice,
  merchant, amount, shared flag, note, receipt filename) of all deductible
  purchases in a chosen year, plus every referenced receipt file.

## 9. Receipts, OCR, and the receipt library

**Receipts are not events.** Receipt images/PDFs are **content-addressed
blobs** stored at `blobs/<sha256>`, referenced by `ReceiptAttached {purchaseId,
sha256, mimeType, sizeBytes}` and removed (as a reference) by `ReceiptDetached`.
Referenced blobs are never deleted. Images are re-encoded on attach (JPEG ~85,
max dimension 2000px); PDFs are stored as-is. Custom sprites (quests, pets,
avatars) use the **same blob pipeline** via their sha256 references.

**OCR** is **Android-only** and **fully on-device**
(`google_mlkit_text_recognition`, bundled model, no network). It is
**confirm-only**: it may prefill amount, date, and merchant, but may **never**
create or commit an event without explicit user confirmation of at least the
amount. The parsing heuristics live in `lib/data/ocr/receipt_parse.dart` as a
pure, unit-tested function.

**Receipt library (desktop only).** A **regenerable projection**, never a
source of truth. The user picks a root folder; after every sync (and on
demand) the app mirrors receipt blobs into
`<root>/<year>/<slice name>/<yyyy-MM-dd>_<merchant or 'receipt'>_<amount>.<ext>`
(sanitized, de-duplicated with `_2` suffixes), based on each receipt's
purchase. Rebuilding from scratch must produce identical content; any user
edits inside the folder are ignored and overwritten.

## 10. Sync (multi-hub)

No internet services. Any desktop build can host a **hub** (`package:shelf`) on
the LAN. A device may be paired with **multiple hubs**, keeping an independent
pull cursor per hub. Event idempotency by `eventId` makes multi-hub convergence
safe with **no conflict logic**; blobs are content-addressed, so duplication is
harmless. Every device syncs with every reachable paired hub each cycle.

**Hub endpoints**
- `POST /pair {pairingSecret, deviceName} -> deviceToken`
- `POST /events` — batch, idempotent, assigns a per-hub monotonic `hub_seq`
- `GET /events?after=<seq>`
- `PUT /blobs/<sha256>` — idempotent, hash-verified, 20MB cap
- `GET /blobs/<sha256>`

Pairing is via a QR code `{url, pairingSecret}`; device tokens live in
`flutter_secure_storage`.

**Fallback: export/import.** `.dbevents` (JSON lines) or `.dbevents.zip`
(`events.jsonl` + `blobs/`). Import is idempotent.

Everything works **offline indefinitely**. Failures are **silent-but-visible**
via a status indicator — never blocking dialogs.

## 11. Gamification (a pure presentation skin)

The game is a **pure presentation skin**. `lib/game/adapter.dart` maps
`HouseholdState -> GameState`; it is pure and tested, and the domain has **zero
game knowledge**. The theme is toggleable (Classic / Adventure); both render
from the same providers with **identical numbers**. Only cosmetic events
(`CosmeticSet`, sprite references in `QuestSet`/`PetSet`) exist for the skin.

**Mapping**
- personal slice → monster (maxHP = effective limit, damage = spent)
- group slice → party contract with a dual-color banner
- pet-linked slices/funds → shown under the pet party member
- overspend → enraged; the excess shows as player HP loss
- recurring expenses + emergency contributions → "equipment maintenance &
  provisioning" at floor start (variable ones show "awaiting tally" until
  recorded)
- income → expedition supplies
- month close → the dividing-the-spoils ritual
- quest → a quest monster hunted across months (HP = target, allocations =
  damage, completion = trophy; custom sprite if set, else default)
- vault → gold pouch
- war chest → the pool
- withdrawal → a writ needing the other adventurer's signature
- ransack → a loud "the war chest was ransacked" banner
- gift → treasure found
- tax refund → royal rebate
- emergency funds → reserve caches
- tax marker → a small scroll seal, on the purchase detail only
- month → a dungeon floor

**Rendering.** Pixel art renders with `FilterQuality.none` at integer scales;
assets live in `app/assets/game/` per `docs/art-assets.md`. Custom sprite blobs
render through the same pixelated pipeline. Missing assets degrade to labeled
placeholders — they never crash.

## 12. Code structure

- `app/lib/domain/` — pure Dart, **zero Flutter imports**.
- `app/lib/data/` — drift, the multi-hub sync client, the hub server, the blob
  store, `ocr/` (pure parser + a thin plugin wrapper), the receipt-library
  projector, import/export, and tax package export.
- `app/lib/game/` — the `GameState` adapter (pure) and adventure widgets.
- `app/lib/features/<name>/` — classic UI, per feature.
- `app/lib/ui/` — theme and shared widgets.
- `docs/` — architecture, protocol, art specs, and ADRs.

## 13. Workflow rules

- **TDD** for `lib/domain/`, `lib/game/adapter.dart`,
  `lib/data/ocr/receipt_parse.dart`, and the receipt-library path/naming logic:
  tests are written before implementation.
- `./check.sh` (`dart analyze` + `flutter test`) must pass before any commit.
- Conventional commits, one commit per completed task.
- Build only what the current phase prompt asks for. If a phase seems to require
  changing the reducer but the prompt says it should not, **stop and say so**
  instead of proceeding.
