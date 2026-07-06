# DuoBudget

A two-person, **local-first** shared budgeting app with an optional "dungeon
adventure" skin. Built for couples who want one honest picture of their money
without handing it to a bank, a server, or a subscription. Everything runs on
your own devices: two people, a few phones and desktops, syncing over your home
Wi-Fi. No accounts, no cloud, no SaaS. Receipt OCR runs on-device; desktops act
as sync hubs on the local network.

Flutter only — **Android + desktop** (Windows, macOS, Linux).

> Money is always integer cents. Every change is an immutable event appended to
> a local log, and all balances are derived by a single pure reducer — so every
> device that has seen the same events shows exactly the same numbers.

## Screenshots

_Placeholders — drop real captures in `docs/screenshots/`._

| Classic dashboard | Adventure skin | Sync & hubs |
| --- | --- | --- |
| ![Classic dashboard](docs/screenshots/dashboard.png) | ![Adventure skin](docs/screenshots/adventure.png) | ![Sync & hubs](docs/screenshots/sync.png) |

| Spoils ritual | Quests | Receipt capture |
| --- | --- | --- |
| ![Spoils](docs/screenshots/spoils.png) | ![Quests](docs/screenshots/quests.png) | ![Receipt](docs/screenshots/receipt.png) |

## Quick start — a new household

> New here? The **[household setup guide](docs/setup-guide.md)** walks two people
> through the whole thing step by step — install, pairing, budgets, daily use,
> month close, backup, and troubleshooting — with a printable one-page fridge
> sheet at the end.

DuoBudget is peer-to-peer, so start on the machine that stays on: a desktop.

1. **First run (desktop).** Launch the app and complete first-run setup: the
   household timezone, the two members' names, and which member *this* device is.
   The dashboard opens on a "Welcome" empty state — tap **Set up budgets** and
   carve your month into slices (one each for the two of you, plus shared ones
   like groceries).
2. **Start a hub.** Open **Manage → Sync & hubs → Start hub**. The desktop now
   hosts a small server on your LAN and shows an address and a pairing secret.
3. **Pair your phones.** On each phone, complete first-run setup, then go to
   **Manage → Sync & hubs → Pair with a hub** and enter the desktop's address and
   pairing secret. The phone syncs immediately and keeps syncing in the
   background.
4. **(Optional) Pair the second desktop as another hub.** Have the second desktop
   start its *own* hub too, and pair each machine to the other's hub. Now either
   desktop can be the one that's awake — devices sync with every reachable hub and
   converge regardless of which is up. A phone can be paired to both hubs at once.

No hub reachable? Every device still works fully offline; use **Export /
Import** (`.dbevents.zip`) to move data by file. Nothing ever blocks on the
network — the status chip shows sync state without dialogs.

## How it works

**The spoils economy and tithes.** Each personal slice has a monthly limit. At
month close you divide the *leftover* (limit − spending) three ways, per slice:
carry it forward in the same slice 1:1 (raising next month's limit), throw it at
a savings **quest**, or convert it to your personal **vault** (discretionary
money) — with that slice's **pool tithe** (a per-slice %) skimmed off the top
into the shared **war chest**. Group slices (groceries, pet care) are simpler:
funded 50/50 off the top, purchases are inherently shared, and any leftover flows
automatically and entirely to the war chest. The ritual is interactive but never
blocking — past a grace period the reducer just applies each slice's default
policy.

**Quests.** A quest is a savings-goal "monster" — a $500 jacket, a $1,300 canoe,
a house down payment. Personal quests are funded by their owner, shared ones by
either of you, and funding a quest is **untithed** (it's already earmarked
saving). Buying the goal draws the quest down; hitting the target completes it
with a celebration. Abandon a quest and its balance returns to whoever funded it,
proportionally, minus a small dissolution tithe to the war chest — so quests can't
be used to dodge slice tithes.

**The war chest and its governance.** The war chest is the household's long-term
shared pool: slice tithes, group-slice leftovers, gifts, tax refunds and manual
contributions all flow in. Spending *from* it requires **both** of you — one
proposes a withdrawal (a "writ"), the other approves it; the reducer rejects
self-approval, and pending proposals are visible to both. The one exception is a
**ransack**: an emergency purchase that exceeds its fund's balance draws the
excess straight from the war chest with no prior approval, and surfaces a loud,
shared "the war chest was ransacked" record. No silent overdrafts, and no blocked
emergencies.

**Pets.** Pets are display-level party members. A slice or an emergency fund can
be linked to a pet, which is then shown as the "owner" of that little budget or
reserve cache. Pets hold no money of their own — everything stays household
money; they just make the shared budget feel like a party you're outfitting.

**Recurring fixed & variable expenses.** Recurring expenses ("equipment
maintenance") come off the top before the huntable budget: rent is a shared fixed
expense, a Patreon subscription is a personal fixed one, utilities are a shared
*variable* expense. Fixed ones use their set amount every month; variable ones use
an estimate until you record the actual (normally during the month-close ritual),
after which the reducer uses the real figure. Modify or cancel any of them at any
time.

**Taxes, receipts & OCR.** Any slice can be tax-deductible by default, and any
purchase can override that — but the tax marker never clutters quick entry; it
lives only in slice settings and the purchase detail sheet. Attach a receipt
(image or PDF) to any purchase; on Android, fully **on-device** OCR can prefill
the amount, date and merchant — but it is **confirm-only** and never creates
anything without you approving at least the amount. At year end, export a tax
package: a zip with `summary.csv` of every deductible purchase plus each
referenced receipt file.

**The receipt library.** On desktop you can point DuoBudget at a folder and it
mirrors your receipts into ordinary files —
`<year>/<slice>/<date>_<merchant>_<amount>.<ext>` — that you can browse and back
up like any other documents. It's a **regenerable projection, never a source of
truth**: rebuilding from scratch produces byte-identical files, and any edits you
make inside the folder are simply overwritten on the next projection.

**File-fallback sync.** When two devices genuinely can't reach a hub, move data
by file: export a `.dbevents` (JSON lines) or `.dbevents.zip` (events plus receipt
blobs) and import it on the other device. Import is idempotent — events match by
id, blobs by content hash — so importing the same file twice, or one that overlaps
what a hub already delivered, changes nothing. A corrupt file or a tampered blob
is rejected before anything is applied.

**The theme toggle.** The whole app renders from the same numbers in two skins:
**Classic** (clean cards and rings) and **Adventure** (a pixel-art dungeon where
slices are monsters, quests are boss fights, the vault is a gold pouch and month
close is a spoils ritual). It's a pure presentation layer — both themes show
identical figures — and you can switch at any time. Missing art degrades to
labelled placeholders, never a crash.

## Project layout

```
app/lib/domain/   Pure Dart: events, the Money type, and the reducer (no Flutter)
app/lib/data/     Store (drift), blobs, sync (hub + client), OCR, exports
app/lib/game/     The adventure skin — a pure HouseholdState -> GameState adapter
app/lib/features/ Classic UI, one folder per feature
app/lib/ui/       Theme and shared widgets
docs/             Architecture, sync protocol, art spec, ADRs, release guide
```

## Development

```bash
cd app
flutter pub get
../check.sh        # dart analyze + flutter test (must pass before every commit)
../tool/e2e.sh     # end-to-end multi-hub sync convergence
```

Domain logic, the game adapter, the OCR parser and the receipt-library naming are
developed test-first. Money is integer cents everywhere; domain rows are never
updated or deleted — corrections are compensating events. See
[`CLAUDE.md`](CLAUDE.md) for the full invariants and [`docs/`](docs/) for
architecture, the [household setup guide](docs/setup-guide.md), the
[sync protocol](docs/protocol.md), the [release guide](docs/release.md), and the
[ADRs](docs/adr/).
