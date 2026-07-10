# LootLog

LootLog is a rigorous shared budgeting app that plays like a pixel art
dungeon crawler. Your household is a party of adventurers. Budget categories
are monsters, savings goals are quest bosses, and closing out the month is a
battle ritual where you divide the spoils. Underneath the game sits a strict,
local-first ledger: every amount is integer cents, every change is a permanent
event, and the game layer can read those numbers but can never change them.

Everything runs on your own devices. Phones and desktops sync over your home
network, receipt scanning happens on the phone itself, and there are no
accounts, servers, or subscriptions. LootLog used to be called DuoBudget;
households of any size work fine.

Built with Flutter for Android and desktop (Windows, macOS, Linux).

> **The firewall.** The whole app renders from one pure reducer over an
> append-only event log. The game may only ever append cosmetic events, and a
> test proves that stripping every cosmetic event leaves the balances
> identical. Adventure mode and Classic mode always show the same numbers.

## Download

Grab the latest release from the
[releases page](https://github.com/Tarasios/LootLog/releases/latest). These
direct links always point at the newest version:

- [Android APK](https://github.com/Tarasios/LootLog/releases/latest/download/lootlog-android.apk)
- [Windows](https://github.com/Tarasios/LootLog/releases/latest/download/lootlog-windows-x64.zip)
- [Linux](https://github.com/Tarasios/LootLog/releases/latest/download/lootlog-linux-x64.tar.gz)

The phone app is fully self-sufficient. You can budget on a single phone
forever. Installing the desktop app on a machine that stays home gives you a
sync hub, automatic backups of every device, and the receipt library.

## Screenshots

_Placeholders. Drop real captures in `docs/screenshots/`._

| Adventure dungeon | Classic dashboard | Sync & hubs |
| --- | --- | --- |
| ![Adventure](docs/screenshots/adventure.png) | ![Classic dashboard](docs/screenshots/dashboard.png) | ![Sync & hubs](docs/screenshots/sync.png) |

| Spoils ritual | Quests | Receipt capture |
| --- | --- | --- |
| ![Spoils](docs/screenshots/spoils.png) | ![Quests](docs/screenshots/quests.png) | ![Receipt](docs/screenshots/receipt.png) |

## Two modes, one set of numbers

**Adventure mode** is the default. Categories are monsters you whittle down as
you spend, a savings goal is a quest boss you hunt across months, and the
month-close ritual is where you divide the spoils. The game exists to build a
habit: come back daily to log purchases, come back monthly for the ritual, and
watch your streaks, trophies, and Homestead (the visualization of your shared
pool) grow. The app cheers you on and refuses to scold. Overspending enrages a
monster on screen, and the words you actually read stay kind: they say what
happened, keep your dignity intact, and point at next month.

**Classic mode** is a clean, plain dashboard that is always one tap away. It
uses everyday language ("shared savings" instead of "war chest") and shows
identical numbers.

**It always renders.** Art is scarce, so every game screen works at three
tiers: full pixel art, labeled placeholder cards for any missing sprites, and
a complete text-adventure presentation built from character descriptions you
write yourself. A missing sprite can never crash or block a screen, and the
app is fully playable in text mode alone.

## Quick start

> New here? The [household setup guide](docs/setup-guide.md) walks through the
> whole thing: install, pairing, budgets, daily use, month close, backup, and
> troubleshooting, with a printable fridge sheet at the end.

The easiest setup starts on the machine that stays on, a desktop:

1. **First run (desktop).** Launch the app and set up your household members
   (adults have income and budgets; dependents and pets ride along as party
   members) and which member this device belongs to. Then tap **Set up
   budgets** and carve your month into categories.
2. **Start a hub.** Open **Manage → Sync & hubs → Start hub**. The desktop now
   hosts a small server on your LAN and shows a QR code with the address and
   pairing secret.
3. **Pair your phones.** On each phone, go to **Manage → Sync & hubs → Pair
   with a hub** and scan the QR code (or type the address and secret). The
   phone syncs immediately and keeps syncing in the background.
4. **(Optional) Add a second hub.** A second desktop can start its own hub and
   pair with the first. Devices sync with every reachable hub and converge no
   matter which machine happens to be awake.

Phone only? That works too. Everything runs offline on the phone, and you can
move data between phones with export files or the share sheet. When you want
an always-on backup and the receipt folder, install the desktop build from the
[releases page](https://github.com/Tarasios/LootLog/releases/latest) and
pair with it.

## How the money works

**Members and shares.** A household has any number of members: adults (who
have income, a personal vault, personal categories, and paired devices),
dependents, and pets. Only adults hold money. Shared costs split by a
per-adult share table, with odd cents going to the purchaser. A single-adult
household is fully valid; approvals that would need a second adult are
auto-satisfied.

**Categories.** Each budget category is personal (one adult) or group (the
household), and files under a main category (Housing, Food, Transport, and so
on) whose colors drive the monthly report. Group categories fund from shares
off the top, their purchases are inherently shared, and their leftovers flow
automatically to the war chest. Personal categories can flag any purchase as
shared. Any category can skim a fixed emergency-fund contribution off the top
each month.

**Dividing the spoils.** At month close you decide what happens to each
personal category's leftover: carry it forward in the same category, attack a
savings quest with it, or convert it to discretionary money in your vault
(minus that category's pool tithe, which goes to the shared war chest). The
ritual is interactive and never blocking; past a grace period the app applies
each category's default policy.

**Quests and category-match tithing.** A quest is a savings goal: a $500
jacket, a $1,300 canoe, a house down payment. Attacking it with leftover from
a category under the same main category counts in full. From a different main
category, the source category's tithe is skimmed first. The app always shows
the split before you confirm. Reaching the target completes the quest and
hangs a trophy in the party's trophy hall. Abandoning a quest returns its
balance to whoever funded it, minus a small cancellation cut, so quests can't
be used to dodge tithes.

**Going over budget: the OVERBUDGET.** Overspending has real consequences,
delivered kindly. When a month closes, any overflow on a personal category is
taken from that adult's discretionary vault first. If the vault can't cover
it, the shortfall becomes the OVERBUDGET: an intimidating debt monster
attached to that category. During the ritual you attack it with leftovers
from your other categories (tithed by the usual category-match rule), and you
choose which leftovers to spend on it and which to hold back. Whatever
survives the ritual locks the category: from then on its monthly funding is
withheld and pays the debt down at each close, until the OVERBUDGET falls and
the budget unlocks. Nothing is hidden and nothing is shamed; every adult sees
the same banner, and the fix is always one ritual away.

**The war chest.** The household's long-term shared pool collects tithes,
group leftovers, gifts, tax refunds, and direct contributions, and is
visualized as your growing Homestead. Spending from it takes two adults: one
proposes a withdrawal (a "writ"), a different adult approves it, and the app
rejects self-approval. The one exception is a ransack: an emergency purchase
that exceeds its fund draws the excess straight from the war chest with no
approval and a very loud, shared banner. Emergencies are never blocked and
overdrafts are never silent.

**Recurring expenses.** Rent, subscriptions, and utilities come off the top
before the huntable budget. Variable ones get their actuals recorded at month
close. Annual bills accrue a twelfth each month and reconcile in their due
month, with the due dates shown all year.

**Net worth.** Optionally track savings, investments, and debts. You record
balances, interest accrues at read time, and a debt's minimum payment can
surface as a recurring expense. Tracked accounts live on their own screen and
stay out of the category math.

**Vacation mode.** Spin up a self-contained trip budget drawn from a savings
quest or emergency fund, with its own categories and a daily allowance. Your
normal monthly budget is untouched, and closing the trip returns the leftover
to its fund.

**Receipts, OCR, and taxes.** Attach a receipt photo or PDF to any purchase.
On Android, fully on-device OCR can prefill the amount, date, and merchant; it
is confirm-only and commits nothing without your approval. Any category can be
tax-deductible by default with per-purchase overrides, kept off the quick
entry keypad on purpose. At year end, export a tax package: a zip with a
summary CSV and every referenced receipt.

**The receipt library.** On desktop, point LootLog at a folder and it files
your receipts as ordinary documents:
`<year>/<category>/<date>_<merchant>_<amount>.jpg`. The app only ever adds and
refreshes its own mirrored copies there, and the originals live in
content-addressed storage where referenced receipts are kept forever. Phones
can automatically clear their local copies of receipt images once every paired
hub holds them (a setting, off by default); the files stay in the library and
re-download on demand.

**Sync and merge-import.** Desktop hubs serve the LAN. Events are idempotent
by id and receipts are content-addressed, so merging never conflicts and
never overwrites; it only adds what's missing. No hub around? Export a
`.dbevents.zip` and import it on the other device. You get a preview before
anything applies ("14 new events, 3 receipts, 210 already present") and a
summary after. On Android the export opens the share sheet, so Quick Share to
a nearby phone works in one tap.

**Exports.** A fully offline .xlsx workbook (transactions, monthly summary,
members and income, goals, net worth, recurring expenses) is always available.
An optional Google Sheets sync is the single permitted external service: off
by default, opt-in behind a clear "your data leaves your local network"
warning, using your own credentials, and isolated so nothing else depends on
it.

## Distribution

LootLog ships through GitHub Releases only. Pushing a `v*` tag runs
[`.github/workflows/release.yml`](.github/workflows/release.yml), which builds
a signed Android APK plus Windows, macOS, and Linux bundles and attaches them
to one release. Sharing the app means sharing a release link.

There is no telemetry, no analytics, no crash reporter, and no phone-home of
any kind. User counts come from the public GitHub download statistics:

```bash
dart run tool/release_downloads.dart   # cumulative downloads per asset + total
```

The full build, signing, and metrics guide is
[`docs/distribution.md`](docs/distribution.md), with the keystore and store
details in [`docs/release.md`](docs/release.md).

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

Domain logic, the game adapter and rewards, the OCR parser, and the receipt
library naming are all developed test-first. Money is integer cents
everywhere. Domain rows are never updated or deleted; corrections are
compensating events. The firewall test (cosmetic-stripped ledger produces
identical balances) has to pass from the first rewards commit onward. See
[`CLAUDE.md`](CLAUDE.md) for the full invariants, plus the
[setup guide](docs/setup-guide.md), [sync protocol](docs/protocol.md),
[distribution guide](docs/distribution.md), [release guide](docs/release.md),
and the [ADRs](docs/adr/).
