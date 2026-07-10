# LootLog household setup guide

A step-by-step guide to getting your household budgeting together on LootLog,
written for non-technical users. It follows the app exactly as it exists today —
every screen name and button label below matches what you will see on screen.

Where the app doesn't yet have something this guide would otherwise tell you to
tap, you'll find a **⚠️ Not built yet** note instead of invented instructions.
Those are real gaps in the current build, not steps you're missing.

> **The one-minute picture.** LootLog runs entirely on your own devices — your
> household's phones and desktops, syncing over your home Wi-Fi. There are no
> accounts, no cloud, and no servers on the internet. One desktop that stays
> powered on acts as the **hub** everyone else syncs through. Everything works
> offline; syncing just catches devices up with each other.

**Contents**

1. [Install on the desktop that stays on](#1-install-on-the-desktop-that-stays-on)
2. [First run: create the household](#2-first-run-create-the-household)
3. [Host a hub and pair your other devices](#3-host-a-hub-and-pair-your-other-devices)
4. [Set up your budget](#4-set-up-your-budget)
5. [Daily use: entering expenses and receipts](#5-daily-use-entering-expenses-and-receipts)
6. [Month close: dividing the spoils](#6-month-close-dividing-the-spoils)
7. [The receipt library (desktop)](#7-the-receipt-library-desktop)
8. [When there's no hub: file backup & restore](#8-when-theres-no-hub-file-backup--restore)
9. [Backup and disaster recovery](#9-backup-and-disaster-recovery)
10. [Troubleshooting sync](#10-troubleshooting-sync)
11. [Fridge sheet (print this)](#fridge-sheet)

---

## 1. Install on the desktop that stays on

LootLog is peer-to-peer, so start on the machine that's awake most often — a
desktop or a laptop that lives at home. That machine will host the hub the phones
sync through.

> **Get it from GitHub Releases.** LootLog is distributed through its
> **[GitHub Releases page](https://github.com/Tarasios/LootLog/releases)** —
> that's the whole "app store". Each release attaches ready-to-run binaries:
> a **Windows** zip, a **macOS** `.app`/`.dmg`, a **Linux** tarball, and an
> **Android** APK (for the phones in [step 3](#3-host-a-hub-and-pair-your-other-devices)).
> Download the one for your platform, unzip it, and run it — there is no
> installer and no account. If a friend sent you a release link, that's all you
> need; skip to [step 2](#2-first-run-create-the-household).
>
> - **Windows:** unzip and run `lootlog.exe`. On first launch SmartScreen may
>   warn (the build is unsigned) — choose **More info → Run anyway**.
> - **macOS:** open the `.dmg` and drag **LootLog** to Applications. The build
>   is un-notarized, so the first time, **right-click the app → Open** to get
>   past Gatekeeper.
> - **Linux:** extract the tarball and run `./lootlog` (needs GTK 3 and
>   `libsqlite3`, present on most distros).

**Building from source instead (optional).** If there's no prebuilt binary for
your platform, or you're developing, build it yourself. Install the pinned
Flutter (see [`docs/distribution.md`](distribution.md)), then from the `app/`
folder:

```bash
cd app
flutter pub get
```

Then build for your platform. **Each platform must be built on that platform** —
Flutter can't cross-compile desktop apps.

### Windows

Requires Visual Studio with the "Desktop development with C++" workload.

```bash
flutter build windows --release
```

The finished app is the whole folder at `build/windows/x64/runner/Release/`
(the `.exe` plus its DLLs and `data/` folder). Copy that entire folder to the PC
and run the `.exe`. To hand it to someone else, zip the `Release/` folder.

### macOS

Requires Xcode.

```bash
flutter build macos --release
```

The app is `build/macos/Build/Products/Release/LootLog.app`. Drag it to
Applications. (Distributing it to another Mac needs code-signing and
notarization — see [`docs/release.md`](release.md).)

### Linux

Requires `clang`, `cmake`, `ninja-build`, `pkg-config`, `libgtk-3-dev`, and
`libsqlite3-dev` (the database uses SQLite).

```bash
flutter build linux --release
```

The app is the whole folder at `build/linux/x64/release/bundle/`. Ship the whole
directory; make sure the target machine has `libsqlite3` installed (most distros
already do).

### Android (for the phones — you'll do this in step 3)

```bash
flutter build apk --release        # a standalone APK you can sideload
```

The APK lands at `build/app/outputs/flutter-apk/app-release.apk`. Copy it to each
phone and open it to install (you'll need "install unknown apps" enabled). See
[`docs/release.md`](release.md) for the signed Play Store path.

---

## 2. First run: create the household

Launch the app on the desktop. Because nothing is set up yet, it opens on the
**Welcome to LootLog** screen, which asks one question first: are you *joining*
a party that already exists on another device, or *starting a new one*?

- **Join an existing party** — for a second device (a phone, or the other
  desktop) joining a household that's already set up elsewhere. This pairs to a
  hub and pulls the party down; it's covered in
  [step 3b](#3b-join-the-party-from-a-phone-or-second-desktop).
- **Start a new party** — the first device. Tap this to build your household.

Tapping **Start a new party** opens a short wizard framed as assembling your
adventuring party. Each step has a **Back**/**Next** bar, and **everything you
enter here can be changed later from Settings** — so don't overthink it.

1. **Your party.** Add the people (and pets) in your household. **Adults** carry
   income and a budget; **dependents** and **pets** ride along as party members
   with no money of their own. For each, give a **Name** and, optionally, a
   **character description** (it feeds the text-mode adventure) and a custom
   **sprite** PNG. If you add more than one adult, pick **which adult is this
   device** at the bottom.
2. **Expedition supplies.** Set each adult's usual **monthly income**. It carries
   forward every month until you change it; `0` is fine.
3. **Treasury.** *Optional.* Add **tracked accounts** — savings, investments,
   debts — for the net-worth screen. These never touch your budget.
4. **Standing obligations.** Add **recurring bills** (rent, subscriptions,
   utilities) that come off the top before the huntable budget — **group**
   (split by the party) or **personal** (one adult), **monthly** or **annual**.
5. **Dividing the coin.** Create your **budget categories**. Fund **group**
   categories first; if you have two or more adults you'll also set the **share
   split** that funds them. Then give each adult **personal** categories until
   their "left" counter reaches zero.
6. **First quest.** *Optional.* Pick a first **savings goal** (a quest boss to
   hunt), and choose whether the app looks **Adventure** (the default dungeon
   skin) or **Classic** (a plain ledger). You can switch modes any time.
7. **Ready to delve.** Review the summary and tap **Begin the adventure**. A
   short celebration confirms your party is ready, and the app opens on the
   dashboard.

Completing the wizard *is* creating the household — everything you entered is
written to the permanent, append-only event log. There is no separate
household-name step.

> **⚠️ Timezone is fixed to America/Vancouver.** LootLog currently computes
> every calendar month in the America/Vancouver timezone, and there is no setting
> to change it. If your household is in another timezone, month boundaries
> (and therefore which month a late-night expense lands in) will follow Vancouver
> time. *(Not built yet: a timezone picker.)*

> **One party, shared across devices.** You only run **Start a new party** on the
> *first* device. Every other device uses **Join an existing party**
> ([step 3b](#3b-join-the-party-from-a-phone-or-second-desktop)) to pair to the
> hub, pull the same event history, and claim which adult it is — so all devices
> show the same members and the same numbers. (If two devices genuinely can't
> reach a hub, moving the data by file import/export in
> [step 8](#8-when-theres-no-hub-file-backup--restore) achieves the same thing.)

---

## 3. Host a hub and pair your other devices

A **hub** is just the desktop from step 1 running a small server on your home
Wi-Fi so the phones (and a second desktop) can catch up with each other. Nothing
leaves your local network.

Everything here lives under **Manage** (the ☰ menu icon in the top-right of the
app bar) → **Sync & hubs**.

### 3a. Start the hub on the desktop

1. On the desktop, open **Manage → Sync & hubs**.
2. In the **Host a hub** card, tap **Start hub**.
3. The card now shows two things you'll need on the phones:
   - **Pairing secret** — a code that proves a device is allowed to join.
   - **Address** — one or more `http://…:8787` addresses (one per network the
     desktop is on). If the app can't detect an address it shows the **Port**
     (`8787`) instead, and you'll pair using the desktop's own LAN IP.

   Use the copy button (📋) next to each to copy it.

Leave the hub running. The pairing secret is stable — it's saved on the desktop,
so it stays the same each time you start the hub; you don't get a new code every
time. Tap **Stop hub** only when you want to take the hub offline.

> **⚠️ No QR-code pairing yet.** The design docs describe scanning a QR code to
> pair, and the **Join an existing party** button wears a QR icon — but there is
> no scanner yet. Both hosting and joining are done by **typing** the address and
> secret (use the desktop's copy buttons). *(Not built yet: QR display on the hub
> and a QR scanner on the joining device.)*

### 3b. Join the party from a phone (or second desktop)

Every other device *joins* the household the first device created — it doesn't
build its own. Make sure the desktop's hub from [3a](#3a-start-the-hub-on-the-desktop)
is running and both devices are on the **same Wi-Fi**, then on the new device:

1. Install and launch LootLog. On the **Welcome to LootLog** screen, tap
   **Join an existing party** (not "Start a new party").
2. Fill in:
   - **This device's name** — e.g. "Robin's phone" (so you can recognise it in
     the hub's device list).
   - **Hub address** — the desktop's `http://…:8787` address.
   - **Pairing secret** — the secret from the desktop.
3. Tap **Pair & sync**. The device pairs and pulls the whole party down.
4. On the **"Paired and synced"** screen, tap **which adult you are** from the
   list of the household's adults. That claims your identity on this device and
   finishes setup — the app opens on the shared dashboard.

From then on the device syncs automatically in the background (about every 20
seconds) and whenever you tap **Sync now**. Because everyone works from the same
event history, all devices show the same members and the same numbers.

**Pairing an extra hub after setup.** To pair a device to *another* hub later
(see [3c](#3c-optional-a-second-hub-for-resilience)), open **Manage → Sync &
hubs**, and in the **Pair with a hub** card enter that hub's **Address** and
**Pairing secret**, then tap **Pair**. The new hub appears in the **Paired hubs**
list; a device can be paired to several at once.

### 3c. (Optional) A second hub for resilience

If you have two desktops, you can have **each** desktop start its own hub, then
pair each machine (and each phone) to *both* hubs. A device keeps a **separate
place-marker for each hub** — think of it as a bookmark that remembers "the last
change I've already picked up from this particular hub." Because every change has
a unique ID, hearing about the same change from two hubs is harmless. The upshot:
whichever desktop happens to be awake, everyone still converges to the same
numbers. A phone can be paired to both hubs at once with no extra fuss.

### What the status chip means

The little cloud chip in the **Sync & hubs** app bar (and elsewhere) tells you
where sync stands, without ever popping up a dialog:

| Chip | Meaning |
| --- | --- |
| **Local only** | No hubs paired. Everything works; nothing is being shared yet. |
| **Synced** | Paired and reachable; the last sync caught everyone up. |
| **Syncing…** | A sync is happening right now. |
| **Offline** | Paired, but the last sync couldn't reach a hub. It'll retry automatically. |

---

## 4. Set up your budget

You already sketched your budget in the first-run wizard
([step 2](#2-first-run-create-the-household), "Dividing the coin"). This section
is for **changing it later** — a new category, a different limit, next month's
income. Open **Manage → Budget setup**; it shows each adult's categories with
group budgets below, for the month shown at the top (use the ‹ › arrows to change
month).

LootLog divides your money into **budget categories**. A category is either:

- **Personal** — belongs to one of you (e.g. "Alice — coffee"). Only its owner
  hunts it down, and its leftover is theirs to divide at month close.
- **Group** — shared by the household (e.g. "Groceries," "Pet care"). Funded
  50/50 off the top, every purchase is inherently shared, and any leftover flows
  automatically and entirely to the shared **war chest**.

### Add a category

In a member's column tap **Add category** (or **Add group category** under
**Group categories**). The category editor opens with these fields:

- **Name** — e.g. "Coffee," "Groceries."
- **Owner** — a three-way switch: *your name*, *partner's name*, or **Group**.
- **Monthly limit** — the dollar cap for the month.
- **Pool tithe %** *(personal categories only)* — the share of any leftover you
  *convert to discretionary* that's skimmed into the war chest. "Taken from
  discretionary leftover into the war chest." Leave it at `0` if you don't want a
  tithe.
- **Default leftover policy** *(personal categories only)* — what happens to
  leftover at month close if you don't decide in time (see [step 6](#6-month-close-dividing-the-spoils)):
  - **Carry in category** — roll it into next month's limit for this category.
  - **Convert to discretionary** — move it to your personal vault (minus the pool
    tithe).
  - **Attack a quest** — pour it into a savings goal (pick which one).
- **Tax-deductible by default** — turn on for categories whose purchases are
  usually deductible. You can override this per purchase later; it never clutters
  quick entry.
- **Emergency fund contribution** — a fixed amount set aside off the top each
  month into an emergency fund. This switch is **disabled until you've created a
  fund** (it reads "Create an emergency fund in Settings first"). Once on, pick
  the **Fund** and a **Monthly contribution**.
- **Pet (optional)** — link the category to a pet, shown as its cute "owner."

Tap **Save category**.

Group categories hide the tithe and leftover-policy fields — they don't apply —
and show a reminder that group categories are funded 50/50 with leftover going to
the war chest.

> **Copy last month.** The **Copy last month** button at the top of Budget setup
> copies the **previous month's income** forward to this month. It does *not* copy
> categories — categories persist from month to month on their own, so you only
> edit them when something changes.

### Income

Budget setup *shows* each member's income but doesn't edit it. To set income:

**Manage → Settings → Income.** Pick the month with the ‹ › arrows, type each
member's amount, and tap **Save** on that row.

### Recurring expenses ("equipment maintenance")

Bills that repeat — rent, subscriptions, utilities — come off the top before your
huntable budget. **Manage → Settings → Recurring expenses**, then the **New**
button:

- **Name** — e.g. "Rent," "Netflix," "Hydro."
- **Owner** — *your name*, *partner's name*, or **Shared** (shared ones split
  50/50 off the top; personal ones off that person's budget).
- **Kind** — **Fixed** (same amount monthly) or **Variable** (an *estimate* now,
  with the real figure recorded at month close — see [step 6](#6-month-close-dividing-the-spoils)).
- **Amount** / **Estimate** — the figure (labelled "Estimate" for variable ones).
- **Start month**, and an optional **End month**.

Tap **Save**. To stop one, open it and tap **Cancel this expense** (it ends at the
current month, keeping this month's charge).

### Emergency funds, pets, and household rules

- **Manage → Settings → Emergency funds** → **New**: name a reserve cache and
  optionally link a pet. Its balance is derived automatically (contributions in,
  emergency spending out). Create a fund here *before* wiring a category's
  emergency contribution to it.
- **Manage → Settings → Pets**: add pets to display as party members.
- **Manage → Settings → Rules**: the **Spoils grace period** (days after month
  close before defaults auto-apply, default 7), the **Dissolution tithe** (% taken
  when a quest is abandoned, default 10), and a **Show net worth** switch that
  reveals an optional net-worth screen.
- **Manage → Settings → Appearance**: switch between the **Classic** and
  **Adventure** themes. Both show identical numbers — it's purely cosmetic.

---

## 5. Daily use: entering expenses and receipts

### Quick entry

Tap the **New** button (the ➕ floating button; on desktop you can also press the
**N** key). The **New expense** screen opens:

1. Type the amount on the big keypad.
2. Optionally tap the chips in the row above the keypad:
   - **Split 50/50** — mark this a shared expense (appears only when it can apply;
     see below).
   - **Merchant** — who you paid.
   - **Note** — a free-text note.
   - **Date** — defaults to **Today**; tap to backdate (you can't post-date — the
     latest allowed date is today).
3. Under **Charge to**, tap the destination. Tapping a chip *is* the save. Chips
   are grouped:
   - **My budgets** — your personal categories (each shows "$X left").
   - **Shared budgets** — group categories.
   - **Vault** — your discretionary pocket money.
   - **Quests** — active savings goals you can spend toward.
   - **Emergency funds** — reserve caches.

**About the shared flag:** "Split 50/50" only applies to **personal categories
and the Vault**. Group categories are *always* shared, so no toggle is shown for
them. When you split a personal-category or vault purchase, your partner's half
is taken from their vault at read time (odd penny goes to the buyer).

### Receipts and on-device OCR

Tap the **Scan a receipt** button (the document-scanner floating button next to
**New**):

- **On Android:** it opens the camera. Photograph the receipt. LootLog runs
  **on-device** text recognition (no internet, no cloud) and opens a confirm
  screen with the amount, date, and merchant **pre-filled but editable**, and the
  photo already attached. Nothing is saved until you **tap a charge chip to
  confirm** — OCR never records anything on its own.
- **On desktop:** OCR isn't available, so it opens a file picker for a receipt
  image and shows the same confirm screen with nothing pre-filled — you file it
  manually. (You can still attach receipts to any purchase; see below.)

### Fixing or annotating a purchase

Open a purchase from the **Ledger** or **Activity** list to get its detail sheet.
There you can:

- **Void** it (it stays in the ledger for audit but stops counting).
- Edit **Merchant**, **Note**, or **Date**.
- Toggle **Split 50/50** (where valid).
- Toggle **Tax deductible** — this shows the category's inherited default and
  lets you override it for this one purchase. This is the *only* place (besides
  category settings) tax appears.
- **Attach** receipts (multiple allowed; images or PDF — camera/gallery on mobile,
  file picker on desktop), tap an image receipt to view it, or detach one. On
  Android, if a freshly scanned receipt's total differs from what you typed,
  you'll get a gentle "Use total?" suggestion you can accept or ignore.

---

## 6. Month close: dividing the spoils

At the end of each month you decide what to do with each personal category's
**leftover** (limit − spending). This is the **spoils** ritual.

When there's something to do, a **Spoils** button appears in the app bar. Tap it
to open the **Divide the spoils** sheet. Its subtitle tells you the month and how
many days remain before defaults kick in (e.g. "defaults apply in 5 days").

The sheet has up to two steps:

1. **Record variable actuals** *(only if you have variable recurring expenses)* —
   tap each one to enter what it actually came to this month. Until you do, the
   estimate stands.
2. **Split each budget's leftover** — for each of your personal categories with
   money left, pick one destination (with a live preview of the result):
   - **Carry in category** — raises next month's limit for that category, 1:1.
   - **Attack a quest** — pours the whole leftover into a savings goal (a matching
     main category is *untithed*; a non-matching one applies the category's pool
     tithe — the preview shows which). Pick which quest if you have more than one.
   - **Discretionary** — moves it to your vault, minus that category's pool tithe
     (the preview shows the split, e.g. "$45 to vault, $5 tithe to war chest").

Below the choices, an **Automatic** section shows what happens on its own and
needs no decision: group-category leftovers flowing to the war chest, and
emergency contributions reserved off the top.

Tap **Confirm the division** to record it, or **Later** (or the ✕) to dismiss and
resume another time — it's never blocking.

> **You can ignore it entirely.** If you never open the ritual, then once the
> **grace period** (default 7 days after month close, in Settings → Rules) passes,
> each category's **default leftover policy** is applied automatically. Nothing
> is lost by not tapping through it.

---

## 7. The receipt library (desktop)

On desktop, LootLog can mirror your receipt images into an ordinary folder you
can browse and back up like any other documents.

**Manage → Settings → Receipt library** (this entry appears on desktop only):

1. Tap **Choose folder** and pick a root folder.
2. The screen tells you how many files will be written.
3. Tap **Project now** to write them. Files are organized as
   `<year>/<category>/<date>_<merchant>_<amount>.<ext>`.

> **⚠️ The folder is disposable — treat it as throwaway output, not storage.** The
> receipt library is a **regenerable projection, never a source of truth**. Any
> file you add, rename, or edit inside that folder will be **overwritten** the next
> time you project. Never keep anything in there you can't afford to lose, and
> never point it at a folder that already contains other files you care about.
> Rebuilding from scratch always reproduces the same files.

> **⚠️ Projection is manual right now.** The design says the library re-mirrors
> after every sync, but in the current build it only rebuilds when you tap
> **Project now**. If you rely on the folder, project it yourself after adding
> receipts. *(Not built yet: automatic projection after each sync.)*

If the folder's drive is unplugged, the screen shows a warning and disables
projection until you reconnect it or pick a new folder — it never fails silently.

---

## 8. When there's no hub: file backup & restore

If two devices genuinely can't reach a hub (you're travelling, the desktop is
off), you can still move everything by file. **Manage → Sync & hubs → Backup &
restore**:

- **Export** writes a `.dbevents.zip` file (its suggested name is
  `lootlog-backup.dbevents.zip`). This contains every recorded change **plus**
  the receipt images they reference.
- **Import** reads a `.dbevents.zip` (or a plain `.dbevents` text file) back in.

Importing is **safe to repeat**: changes are matched by their unique ID and
receipts by their content, so importing the same file twice — or one that overlaps
what a hub already delivered — does nothing extra. You'll see "Imported N events."
A corrupt or tampered file is refused before anything is applied, with a plain
message ("this file isn't a valid LootLog backup," or a warning that a receipt
in it is corrupt).

Get the file between devices however you like — a USB stick, AirDrop, a shared
folder. Nothing about this touches the internet.

---

## 9. Backup and disaster recovery

Everything LootLog knows lives in **two things on the hosting device**, both
inside the app's private application-documents directory:

- **`lootlog.sqlite`** — the event log (every change ever made). This is the
  real record; all balances are recomputed from it.
- **The `blobs/` folder** — your receipt images and any custom sprites, one file
  per item, named by content.

### The simple, supported way to back up

Use **Export** (from [step 8](#8-when-theres-no-hub-file-backup--restore)) to save
a `.dbevents.zip` somewhere safe (an external drive, another computer). That one
file is a complete, self-contained backup — event log *and* receipts — and it's
the officially supported, tested path. Do this periodically, and especially before
reinstalling or moving to a new machine.

### The raw-files way

If you'd rather copy the underlying files, copy **both** `lootlog.sqlite` **and**
the entire `blobs/` folder together, from the app's documents directory. They live
side by side. The exact location depends on the OS (it's the standard
per-application documents folder — e.g. your **Documents** folder on Windows and
macOS, and `~/.local/share`-style app data on Linux); if you're unsure where it
is, prefer the Export method above, which never makes you hunt for a path.

### Bringing a device back / adding a new one

A replacement or brand-new device needs to end up with the same event history.
Two ways:

1. **Via a hub (preferred):** on the new device, complete first-run setup, then
   **pair it to the hub** ([step 3b](#3b-join-the-party-from-a-phone-or-second-desktop)). It
   pulls the whole history and all receipts automatically on the first sync.
2. **Via file:** complete first-run setup, then **Import** your latest
   `.dbevents.zip` ([step 8](#8-when-theres-no-hub-file-backup--restore)).

Either way, because every change is recomputed from the log, the device shows
exactly the same numbers as everyone else once it's caught up.

> Keep at least one recent `.dbevents.zip` off the hosting machine. If that
> machine dies and it was your only copy, that backup is what rebuilds the
> household. (Remember the [identity caveat](#2-first-run-create-the-household):
> the safe way to stand up another device is to give it the *history*, by hub or
> import — not to re-key the household from scratch on it.)

---

## 10. Troubleshooting sync

Sync is deliberately quiet: problems show up as the **Offline** status chip and a
one-line message, never a dialog that stops you. Here's how to clear the common
ones.

**The status chip says "Offline" / a phone won't pick up changes.**

- Make sure the desktop's hub is actually running: **Manage → Sync & hubs**, the
  **Host a hub** card should show the pairing secret and address (not a **Start
  hub** button). If it shows **Start hub**, tap it.
- Confirm both devices are on the **same Wi-Fi network** (not a guest network, and
  not one device on cellular).
- Tap **Sync now** to retry immediately rather than waiting for the next
  automatic cycle.

**Pairing fails ("Pairing failed").**

- Re-check the **Address**. It must be reachable from the phone — use one of the
  `http://…:8787` addresses the hub lists, or the desktop's LAN IP with port
  `8787`. `localhost`/`127.0.0.1` will **not** work from another device.
- Re-check the **Pairing secret** for typos (use the copy button on the desktop
  and paste it).
- The hub must be running at the moment you pair.

**"Hub unreachable" even though it's on.**

- **Firewall:** the hosting desktop must allow **incoming TCP connections on port
  8787**. On the first run your OS may have popped a firewall prompt — if you
  dismissed it, add an allow rule for LootLog (or for port 8787) in Windows
  Defender Firewall / macOS "Firewall" settings / your Linux firewall (`ufw allow
  8787/tcp`).
- **Router "AP isolation" / "client isolation":** some routers block devices from
  talking to each other on the same Wi-Fi. If pairing works over one network but
  not your home one, look for and disable this setting on the router.
- **The desktop's IP changed:** home IP addresses can change after a reboot. If a
  previously-working address stops working, re-open the hub and use the address it
  now shows. (A device remembers where it last synced; it will reconnect once the
  address is right again.)

**An import was rejected.**

- "This file isn't a valid LootLog backup" means the file is malformed or not a
  `.dbevents`/`.dbevents.zip` — re-export it.
- A message that a receipt is "corrupt or tampered" means a receipt's contents
  didn't match its fingerprint. Nothing was imported; re-export a fresh backup
  from the source device.

**Nothing is syncing but everything "looks" fine.**

- Check the chip actually reads **Synced** after a **Sync now**. **Local only**
  means this device has **no hubs paired at all** — pair it
  ([step 3b](#3b-join-the-party-from-a-phone-or-second-desktop)).

Remember: an unreachable hub is never fatal. Every device keeps working fully
offline and catches up on its own the next time the hub is reachable.

---

## Fridge sheet

*Print this page and stick it on the fridge.*

```
DUOBUDGET — QUICK REFERENCE
===========================================================

GETTING STARTED
  • Install: download your platform's build from GitHub Releases.
  • Desktop that stays on = the hub. Set it up first.
  • First run → "Start a new party" → walk the wizard
    (party → income → accounts → bills → budget → goal → begin).
  • Everything is editable later in Settings.

PAIR A PHONE (both devices on the SAME Wi-Fi)
  Desktop:  Manage(☰) → Sync & hubs → Start hub
            → note the Address (http://…:8787) + Pairing secret
  Phone:    first run → "Join an existing party"
            → device name + Address + Pairing secret → Pair & sync
            → tap which adult you are
  (No QR code yet — type them in. Secret stays the same each time.)

STATUS CHIP
  Local only = no hub paired      Syncing… = working
  Synced     = up to date         Offline  = can't reach hub (auto-retries)

EVERY DAY
  New expense:  ➕ New (desktop: press N)
                → type amount → optional Merchant/Note/Date
                → tap a "Charge to" chip (that's the save)
  Split 50/50:  only on personal budgets + Vault
                (group budgets are always shared)
  Receipt:      Scan-a-receipt button → (Android: camera + auto-fill)
                → confirm by tapping a charge chip

MONTH CLOSE ("Spoils" button appears when it's time)
  For each leftover, pick one:
    Carry in category · Attack a quest (untithed if it matches the
    category's main category, else −tithe) · Discretionary (−tithe)
  Group leftovers + emergency set-asides happen automatically.
  Ignore it and defaults apply after the grace period (7 days).

BACKUP (do this regularly!)
  Manage(☰) → Sync & hubs → Backup & restore → Export
    → save lootlog-backup.dbevents.zip somewhere OFF this machine.
  New/replacement device: pair to the hub, OR Import that .zip.

TROUBLESHOOTING
  Offline?  Same Wi-Fi? Hub running? Tap "Sync now".
  Can't pair? Use the LAN address (not localhost); allow port 8787
              through the firewall; disable router "AP isolation".
===========================================================
```

---

*This guide reflects the app as built. Items marked **⚠️ Not built yet** are known
gaps — see the source under `app/lib/features/` if you're extending them.*
