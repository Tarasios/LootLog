# DuoBudget

Two-person local-first shared budgeting app with an optional "dungeon adventure" presentation skin, receipt storage with on-device OCR, quest-based savings goals, pets as party members, and tax-deduction tracking. Flutter only: Android + desktop (Windows/macOS/Linux). No external services, servers, accounts, or SaaS — desktops act as sync hubs on the local network, and OCR runs on-device.

## Non-negotiable invariants

### Money & domain
- Money is integer cents everywhere. Never float/double for money. `Money` value type only. ("Gold" is a display unit; the ledger is cents.)
- All state changes are immutable events appended to the local `events` table. Never UPDATE/DELETE domain rows. Corrections = compensating events.
- All derived state comes from `lib/domain/reducer.dart` — a pure function `List<Event> -> HouseholdState`. UI, sync, game, OCR, and the receipt library never compute balances themselves.
- Everything time-based is computed in the reducer at read time. No scheduled jobs. "Automatic" month-end behavior means: derived when read.
- Months are calendar months in the household timezone (America/Vancouver), keyed by `occurredAt` (user-editable), not `createdAt`. Event IDs are UUIDv7.

### Slices & ownership
- A slice is **personal** (one user) or **group** (household: groceries, pet care). A slice may be linked to a pet for display.
- Group slices: limit funded 50/50 off the top; purchases inherently shared (no toggle shown); leftover flows automatically and entirely to the war chest; no allocation decision, no tithe.
- Personal slices: purchases may be flagged shared (50/50 split at read time, odd cent to purchaser).
- A slice may designate an **emergency fund contribution**: fixed amount off the top of its limit monthly into a named emergency fund, regardless of spending. Effective huntable limit = limit − contribution.

### Recurring expenses ("equipment maintenance")
- `RecurringExpenseSet {name, ownership personal(user)|shared, kind fixed|variable, amountCents (the amount, or the estimate if variable), startMonth, endMonth?}`. Shared ones split 50/50 off the top; personal ones off the top of that user's budget. Modifiable and cancellable any time (endMonth); expected to continue monthly otherwise. Examples: rent = shared fixed; a game/Patreon subscription = personal fixed; utilities = shared variable.
- Variable expenses: `VariableExpenseRecorded {expenseId, month, actualCents}` supplies the actual, normally during the month-close ritual. Reducer uses actual if recorded, else the estimate; a late recording after grace is a normal retroactive correction.

### Quests (savings-goal monsters) — replaces any earmark concept
- `QuestSet {questId, name, targetCents, ownership personal(user)|shared, sliceHint?, customSpriteSha256?}` creates a savings goal ("$500 jacket", "$1300 canoe", "house down payment"). Personal quests are funded by their owner; shared quests by either user.
- Quests are funded ONLY by spoils allocations at month close. Funding a quest is untithed.
- Buying the goal = a purchase with chargeTarget QUEST(id), drawing down its balance; reaching target = quest complete (celebration).
- `QuestAbandoned` moves the remaining balance to the funder(s)' vault(s) in proportion to their contributions, minus the household **dissolution tithe** (setting, default 10%) which goes to the war chest. This prevents quests being used to dodge slice tithes.

### Month close: dividing the spoils
- For each **personal** slice with leftover (max(0, effectiveLimit − spent)), the owner allocates via `LeftoverAllocated {userId, month, sliceId, allocations:[{destination carryInSlice | quest(id) | discretionary, amountCents}]}`:
  1. **Carry in-slice 1:1** — raises next month's effective limit; stacks without cap.
  2. **Attack a quest** — untithed.
  3. **Convert to discretionary** — enters the owner's vault minus that slice's **pool tithe** (per-slice %, 0–100, tithe portion to the war chest; floor rounding to the chest, remainder to the user, must sum exactly).
- The ritual also opens with recording actuals for variable recurring expenses for the closed month.
- Interactive but never blocking: past the grace period (setting, default 7 days after month close) with no allocation event, the reducer applies the slice's configured default policy at read time. Group-slice leftovers and emergency contributions are automatic and shown read-only.

### Vaults, gifts, war chest, emergency funds, ransacks
- Purchase charge targets: slice, VAULT, QUEST(id), EMERGENCY(fundId).
- Vault(user), derived = Σ discretionary allocations (post-tithe) + gifts + approved withdrawals directed to them + abandoned-quest returns (post dissolution tithe) − vault-charged spending − pool contributions. Clamp at zero with an inconsistency flag.
- `GiftReceived {userId, amountCents, note}` credits the vault, untithed.
- War chest (long-term pool) = slice tithes + dissolution tithes + group-slice leftovers + `PoolContributionMade` + `TaxRefundRecorded` − approved withdrawals − ransack overflows.
- **Withdrawals require both users**: `PoolWithdrawalProposed {byUserId, amountCents, purpose, destination userVault(userId)|external}` pending until `PoolWithdrawalApproved` by the OTHER user (reducer rejects self-approval) or `PoolWithdrawalCancelled`. Pending proposals visible to both.
- Emergency funds: named household funds, optionally linked to a pet; balance = Σ contributions − emergency-charged spending. Spending needs only a note. **Ransack rule:** an emergency purchase exceeding its fund's balance draws the excess from the war chest WITHOUT prior approval, and the reducer surfaces a prominent ransack record {fund, excess, purpose} that both users see. No silent overdrafts, no blocked emergencies.
- The war chest may also carry its own target (`GoalSet`); pctComplete = pool/target; estMonthsRemaining = remaining / trailing-3-month average net pool inflow, null when ≤ 0.

### Pets
- `PetSet {petId, name, customSpriteSha256?}`; pets are display-level party members. Slices and emergency funds may reference a petId; the pet is shown as the "owner" of its micro budget and reserve cache. Pets have no ledger of their own — everything remains household money.

### Tax tracking (must stay unobtrusive)
- Per-slice `taxDeductibleByDefault`; per-purchase override (null = inherit). Never on the quick-entry keypad — only slice settings and the purchase detail sheet.
- Tax year = calendar year, household timezone. Tax package export: zip with summary.csv (date, user, slice, merchant, amount, shared flag, note, receipt filename) of all deductible purchases in a chosen year plus every referenced receipt file.

### Receipts, OCR & the receipt library
- Purchases carry an optional `merchant` string (OCR prefills it; user-editable).
- Receipt images/PDFs are NOT events: content-addressed blobs at `blobs/<sha256>`, referenced by `ReceiptAttached {purchaseId, sha256, mimeType, sizeBytes}` / removed by `ReceiptDetached`. Referenced blobs never deleted. Images re-encoded on attach: JPEG ~85, max dimension 2000px; PDFs as-is. Custom sprites (quests, pets, avatars) use the same blob pipeline via their sha256 references.
- OCR: Android-only, fully on-device (google_mlkit_text_recognition, bundled model, no network). **Confirm-only**: may prefill amount, date, merchant; may NEVER create or commit an event without explicit user confirmation of at least the amount. Heuristics live in `lib/data/ocr/receipt_parse.dart` as a pure, unit-tested function.
- **Receipt library (desktop only): a regenerable projection, never a source of truth.** The user picks a root folder; after every sync (and on demand) the app mirrors receipt blobs into `<root>/<year>/<slice name>/<yyyy-MM-dd>_<merchant or 'receipt'>_<amount>.<ext>` (sanitized, de-duplicated with _2 suffixes), based on each receipt's purchase. Rebuilding from scratch must produce identical content; user edits inside the folder are ignored and overwritten.

### Sync (multi-hub)
- No internet services. Any desktop build can host a hub (package:shelf) on the LAN; a device may be paired with MULTIPLE hubs, keeping an independent pull cursor per hub. Event idempotency by eventId makes multi-hub convergence safe with no conflict logic; blobs are content-addressed so duplication is harmless. Every device syncs with every reachable paired hub each cycle.
- Hub endpoints: POST /pair {pairingSecret, deviceName} -> deviceToken; POST /events (batch, idempotent, assigns per-hub monotonic hub_seq); GET /events?after=<seq>; PUT /blobs/<sha256> (idempotent, hash-verified, 20MB cap); GET /blobs/<sha256>. Pairing via QR {url, pairingSecret}; tokens in flutter_secure_storage.
- Fallback: export/import — `.dbevents` (JSON lines) or `.dbevents.zip` (events.jsonl + blobs/). Import idempotent.
- Everything works offline indefinitely; failures are silent-but-visible via a status indicator, never blocking dialogs.

### Gamification
- Pure presentation skin: `lib/game/adapter.dart` maps `HouseholdState -> GameState`; pure, tested; domain has zero game knowledge.
- Mapping: personal slice = monster (maxHP = effective limit, damage = spent); group slice = party contract with dual-color banner; pet-linked slices/funds shown under the pet party member; overspend = enraged, excess as player HP loss; recurring expenses + emergency contributions = "equipment maintenance & provisioning" at floor start (variable ones show 'awaiting tally' until recorded); income = expedition supplies; month close = dividing-the-spoils ritual; quest = quest monster hunted across months (HP = target, allocations = damage, completion = trophy; custom sprite if set, else default); vault = gold pouch; war chest = pool; withdrawal = writ needing the other adventurer's signature; ransack = a loud "the war chest was ransacked" banner; gift = treasure found; tax refund = royal rebate; emergency funds = reserve caches; tax marker = small scroll seal on purchase detail only; month = dungeon floor.
- Theme toggleable (Classic / Adventure); both render from the same providers with identical numbers. Only cosmetic events (CosmeticSet, sprite references in QuestSet/PetSet) exist for the skin.
- Pixel art renders with FilterQuality.none at integer scales; assets in `app/assets/game/` per `docs/art-assets.md`; custom sprite blobs render through the same pixelated pipeline; missing assets degrade to labeled placeholders, never crash.

## Stack
Flutter stable + Riverpod (codegen) + drift + go_router + fl_chart + shelf + mobile_scanner + flutter_secure_storage + image_picker + file_selector + crypto + archive + an image re-encoding package + google_mlkit_text_recognition (Android only, platform-guarded). No other dependencies without stating why in the commit body. No paid or account-based services.

## Structure
- `app/lib/domain/` pure Dart, zero Flutter imports.
- `app/lib/data/` drift, sync client (multi-hub), hub server, blob store, ocr/ (pure parser + thin plugin wrapper), receipt library projector, import/export, tax package export.
- `app/lib/game/` GameState adapter (pure) + adventure widgets.
- `app/lib/features/<name>/` classic UI per feature.
- `app/lib/ui/` theme + shared widgets.
- `docs/` architecture, protocol, art specs, ADRs.

## Workflow rules
- TDD for `lib/domain/`, `lib/game/adapter.dart`, `lib/data/ocr/receipt_parse.dart`, and the receipt-library path/naming logic: tests before implementation. `./check.sh` (dart analyze + flutter test) must pass before any commit.
- Conventional commits, one commit per completed task.
- Build only what the current phase prompt asks. If a phase seems to require changing the reducer and the prompt says it should not, stop and say so instead of proceeding.
