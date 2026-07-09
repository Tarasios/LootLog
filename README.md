# DuoBudget

A **pixel-art dungeon-crawler that happens to be a rigorous shared budgeting
app.** Your household is a party of adventurers delving a dungeon: budget
categories are monsters, savings goals are quest bosses, month close is a battle
ritual, and the shared pool is a homestead you build up over time. Underneath
the game sits a **local-first, event-sourced, integer-cents ledger** — so the
numbers are dead serious even while the presentation is a game.

Built for households of any size who want one honest picture of their money
without handing it to a bank, a server, or a subscription. Everything runs on
your own devices — a few phones and desktops, syncing over your home Wi-Fi. No
accounts, no cloud, no SaaS. Receipt OCR runs on-device; desktops act as sync
hubs on the local network. (The name "DuoBudget" is historical — households
aren't limited to two.)

Flutter only — **Android + desktop** (Windows, macOS, Linux).

> **The firewall.** The game never touches the money. The whole app renders from
> one pure reducer over an append-only event log, in integer cents; the game
> layer can *read* that state but may only ever append **cosmetic** events. Strip
> every cosmetic event and the balances are identical — there's a test that
> proves it. Adventure mode and the plain **Classic** mode always show the same
> numbers.

## Screenshots

_Placeholders — drop real captures in `docs/screenshots/`._

| Adventure dungeon | Classic dashboard | Sync & hubs |
| --- | --- | --- |
| ![Adventure](docs/screenshots/adventure.png) | ![Classic dashboard](docs/screenshots/dashboard.png) | ![Sync & hubs](docs/screenshots/sync.png) |

| Spoils ritual | Quests | Receipt capture |
| --- | --- | --- |
| ![Spoils](docs/screenshots/spoils.png) | ![Quests](docs/screenshots/quests.png) | ![Receipt](docs/screenshots/receipt.png) |

## The game, and why it's serious

**Adventure mode is the default, primary experience** on every platform.
Categories are monsters you whittle down as you spend; a savings goal is a quest
boss you hunt across months; the month-close ritual is where you divide the
spoils. The point isn't decoration — it's **habit**: the app succeeds if you come
back daily to log a purchase and monthly for the ritual, so streaks,
celebrations, trophies and a growing **Homestead** (the visualization of your
shared pool) are core features. The voice is encouraging and **never shames** —
overspending just makes a monster *enraged*.

**Classic mode** is the plain fallback view, always one tap away, using plain
language only (no "tithe" or "spoils") and showing identical numbers.

**It always renders.** Art is scarce, so every screen degrades gracefully across
three tiers: full pixel art → labeled placeholders for missing sprites → a
**first-class text-adventure mode** built from character descriptions you write.
The app is complete and fun even with no art at all — a missing sprite never
crashes or blocks a screen.

## Quick start — a new household

> New here? The **[household setup guide](docs/setup-guide.md)** walks you
> through the whole thing step by step — install, pairing, budgets, daily use,
> month close, backup, and troubleshooting — with a printable one-page fridge
> sheet at the end.

DuoBudget is peer-to-peer, so start on the machine that stays on: a desktop.

1. **First run (desktop).** Launch the app and complete first-run setup: your
   household's members (adults have income and budgets; dependents and pets ride
   along as party members) and which member *this* device is. The dashboard
   opens on a "Welcome" empty state — tap **Set up budgets** and carve your month
   into categories (personal ones per adult, plus shared/group ones like
   groceries).
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
Import** (`.dbevents.zip`) to move data by file — see below. Nothing ever blocks
on the network — the status chip shows sync state without dialogs.

## Syncing without a hub

Sometimes there's no hub to reach — you're travelling, on separate networks, or
just want to hand your budget to another device once. DuoBudget's event log is
built for exactly this: every change is an immutable event with a stable id, and
receipts are content-addressed blobs, so **merging two logs never conflicts and
never overwrites** — it only ever *adds what's missing*. Move the file however
you like; the maths is the same.

**On both devices:** open **Manage → Sync & hubs → Backup & restore**.

1. **Export.** Choose **Export all** for the whole log, or **Export new** to send
   only what's changed since your last export — the incremental "vacation swap"
   that keeps files small when you exchange back and forth over a few days.
   *Export new* tracks everything that has arrived since, whether you logged it
   here or merged it in from the other device, so you can even relay changes on
   through a third device. Both produce a `.dbevents.zip` (events plus their
   receipt images); a plain-text `.dbevents` without receipts is also accepted on
   import.
2. **Import.** Pick the file on the other device. Before anything is written you
   get a **preview** — *"14 new events, 3 receipts — 210 already present"* — so
   you always know what a file will add. Confirm, and a matching **summary**
   reports what was merged. Importing the same file twice is a safe no-op, and a
   corrupt or tampered file is rejected before a single event is applied.

**Getting the file across — Android.** On a phone, **Export** and **Export new**
open the OS **share sheet** directly, so you can send the file to a nearby phone
with the built-in **Nearby Share / Quick Share** (or Bluetooth, or any messaging
app) in one tap. That's the Android platform share intent doing the transport —
DuoBudget bundles **no Wi-Fi Direct, Bluetooth, or other radio/P2P code of its
own**; it just hands the OS a file and lets the system's nearby-share picker move
it. Like the on-device OCR, this stays a thin, platform-guarded seam. On desktop,
export saves the file and you copy it over however you already move files (USB
stick, shared folder, chat).

## How it works

**Members & shares.** A household has any number of **members**: *adults* (who
have income, a vault, personal categories, and paired devices), *dependents*,
and *pets*. Only adults hold money; dependents and pets are display-level party
members — everything stays household money. Shared costs split by a per-adult
**share table** (default even split; odd cents go to the purchaser). A
single-adult household is fully valid — approvals that would need "another adult"
are auto-satisfied.

**Categories.** Your money is divided into budget **categories**, each **personal**
(one adult) or **group** (household), and each filed under a **main category**
(Housing, Food, Transport, …) whose colors drive the monthly spend pie chart.
Group categories are funded by shares off the top, purchases are inherently
shared, and any leftover flows automatically and entirely to the war chest.
Personal categories can flag a purchase as shared. Any category can skim a fixed
**emergency-fund contribution** off the top each month.

**The spoils economy and tithes.** Each personal category has a monthly limit.
At month close you divide the *leftover* (effective limit − spending) three ways,
per category: **carry it forward** in the same category 1:1 (raising next
month's limit), **attack a savings quest**, or **convert to discretionary** money
in your personal **vault** — with that category's **pool tithe** skimmed into the
shared **war chest**. The ritual is interactive but never blocking — past a grace
period the reducer just applies each category's default policy.

**Quests and category-match tithing.** A quest is a savings-goal "boss" — a $500
jacket, a $1,300 canoe, a house down payment — filed under a main category.
Funding it from a category whose main category **matches** the quest's is
**untithed** (full damage); from a **non-matching** category, that category's
pool tithe applies (part to the war chest, the rest as damage). The app always
shows the split before you confirm. Buying the goal draws the quest down; hitting
the target completes it with a trophy. Abandon a quest and its balance returns to
whoever funded it, proportionally, minus a small dissolution tithe — so quests
can't be used to dodge tithes.

**The war chest and its governance.** The war chest is the household's long-term
shared pool: category tithes, group-category leftovers, gifts, tax refunds and
manual contributions all flow in, and it's visualized as your growing
**Homestead**. Spending *from* it requires **another adult** — one proposes a
withdrawal (a "writ"), a different adult approves it; the reducer rejects
self-approval (and auto-approves in single-adult households), and pending
proposals are visible to all adults. The one exception is a **ransack**: an
emergency purchase that exceeds its fund's balance draws the excess straight from
the war chest with no prior approval, and surfaces a loud, shared "the war chest
was ransacked" record. No silent overdrafts, no blocked emergencies.

**Recurring fixed, variable & annual expenses.** Recurring expenses ("equipment
maintenance") come off the top before the huntable budget: rent is a shared fixed
expense, a subscription is a personal fixed one, utilities are a shared *variable*
expense recorded at month close. **Annual** bills accrue **1/12 each month** (the
odd cents land in the due month so the year sums exactly), then reconcile against
the real amount when due. Modify or cancel any of them at any time.

**Net worth.** Optionally track savings, investments, and debts as **tracked
accounts** — you record balances, and interest on savings/debt accrues at read
time. These live on a separate net-worth screen and **never** enter category
math; a debt's minimum payment can surface as a recurring expense.

**Vacation mode.** Spin up a self-contained trip sub-budget drawn from a savings
quest or emergency fund, with its own categories and daily-allowance pacing. Your
normal monthly budget is untouched; closing the trip returns any leftover to its
fund.

**Taxes, receipts & OCR.** Any category can be tax-deductible by default, and any
purchase can override that — but the tax marker never clutters quick entry; it
lives only in category settings and the purchase detail sheet. Attach a receipt
(image or PDF) to any purchase; on Android, fully **on-device** OCR can prefill
the amount, date and merchant — but it is **confirm-only** and never creates
anything without you approving at least the amount. At year end, export a tax
package: a zip with `summary.csv` of every deductible purchase plus each
referenced receipt file.

**The receipt library.** On desktop you can point DuoBudget at a folder and it
mirrors your receipts into ordinary files —
`<year>/<category>/<date>_<merchant>_<amount>.<ext>` — that you can browse and
back up like any other documents. It's a **regenerable projection, never a source
of truth**: rebuilding from scratch produces identical files, and any edits you
make inside the folder are simply overwritten on the next projection.

**Sync & merge-import.** Desktops host LAN **hubs**; a device can pair with
several and converges no matter which is awake, because events are idempotent by
id and blobs are content-addressed. When two devices genuinely can't reach a hub,
move data by file: export a `.dbevents` / `.dbevents.zip` and import it — a
first-class **merge-import** that only adds missing events (never overwrites),
shows a preview before applying and a summary after. A corrupt file or tampered
blob is rejected before anything is applied.

**Exports.** A fully offline **.xlsx** workbook (transactions, monthly summary,
members & income, savings goals, net worth, recurring expenses) is always
available. An **optional, opt-in Google Sheets sync** is the one permitted
external service — off by default, behind a clear "your data leaves your local
network" warning, using your own credentials, isolated so nothing else depends on
it.

**Two modes, one set of numbers.** The whole app renders from the same reducer in
two presentations — **Classic** (clean cards and rings, plain language) and
**Adventure** (the pixel dungeon) — and you can switch at any time. The game is a
pure presentation of real numbers; it can never change a cent.

## Distribution

DuoBudget is distributed through **GitHub Releases only**. Pushing a `v*` tag
runs [`.github/workflows/release.yml`](.github/workflows/release.yml), which
builds all four artifacts on native runners and attaches them to one Release: a
**signed, sideloadable Android APK**, a **Windows** zip, a **macOS** `.app`/`.dmg`,
and a **Linux** tarball (optional AppImage). Sharing the app means sharing a
release link — there is no store account, no server, and no auto-updater.

There is **no telemetry and no phone-home of any kind** — no analytics SDK, no
crash reporter, no usage ping. When we cite user counts they come from the public
GitHub Releases download-statistics API, never from the app. The documented
script prints the cumulative tally (the "resume number"):

```bash
dart run tool/release_downloads.dart      # cumulative downloads per asset + total
```

The full build, signing, reproducibility, and metrics guide is
**[`docs/distribution.md`](docs/distribution.md)** (with the keystore/Play-Store
deep-dive in [`docs/release.md`](docs/release.md)).

## Project layout

```
app/lib/domain/   Pure Dart: events, the Money type, and the reducer (no Flutter)
app/lib/data/     Store (drift), blobs, sync (hub + client), OCR, exports, sheets
app/lib/game/     The game: pure HouseholdState -> GameState adapter, rewards, text mode, pixel widgets
app/lib/features/ Classic UI, one folder per feature
app/lib/ui/       Theme, shared widgets, and the glossary/strings module
docs/             Architecture, sync protocol, art spec, ADRs, release guide
```

## Development

```bash
cd app
flutter pub get
../check.sh        # dart analyze + flutter test (must pass before every commit)
../tool/e2e.sh     # end-to-end multi-hub sync convergence
```

Domain logic, the game adapter and its rewards, the OCR parser, and the
receipt-library naming are developed test-first. Money is integer cents
everywhere; domain rows are never updated or deleted — corrections are
compensating events. The **firewall test** (cosmetic-stripped ledger ⇒ identical
balances) must pass from the first rewards commit onward. See
[`CLAUDE.md`](CLAUDE.md) for the full invariants and [`docs/`](docs/) for
architecture, the [household setup guide](docs/setup-guide.md), the
[sync protocol](docs/protocol.md), the
[distribution & metrics guide](docs/distribution.md), the
[release guide](docs/release.md), and the [ADRs](docs/adr/).
