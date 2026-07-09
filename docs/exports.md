# Exports

DuoBudget ships two export paths. One is fully offline and always available; the
other is an explicit, off-by-default opt-in — the *only* feature in the app that
ever sends data outside your local network.

## Offline spreadsheet (`.xlsx`)

**Settings → Data → Export → Export .xlsx** writes an Excel workbook to a file
you choose. It works everywhere, needs no network, and never contacts an outside
service.

The workbook has one sheet per the documented export contents:

| Sheet | Contents |
| --- | --- |
| **Transactions** | Every recorded purchase: date, month, member, what it was charged to, merchant, amount, shared/tax/voided flags, note. |
| **Monthly summary** | Per budget category, per month: budgeted, spent, leftover, with its main category and owner. |
| **Members & income** | Each household member (name, role, active) and each adult's current monthly income. |
| **Savings goals** | Each quest: main category, owner, target, balance, remaining, percent complete, status. |
| **Net worth** | Each tracked account's current value, recorded balance, accrued interest, APR, staleness and minimum payment, plus a signed net-worth total. |
| **Recurring expenses** | Each recurring bill: owner, kind, cadence, amount, and due/start/end dates. |

### How it is built

`buildBudgetWorkbook` (in `app/lib/data/export/budget_workbook.dart`) is a pure
projection over the reducer's `HouseholdState` — it groups and labels numbers the
reducer already computed and never does money math itself. `encodeXlsx` (in
`app/lib/data/export/xlsx.dart`) is a tiny, dependency-free OOXML writer: it zips
the handful of XML parts a spreadsheet needs using `package:archive` (already a
dependency).

**Money never touches a float.** Every amount is emitted as a *decimal string*
derived straight from integer cents via `Money.format()` (`1234 → "12.34"`), and
that literal is written verbatim into the sheet. No value passes through a
`double`, so no cent can be created or destroyed by binary-float rounding. This
is why we hand-write the format rather than pulling in a spreadsheet package that
would store cells as doubles.

## Google Sheets sync (optional, off by default)

This is the single permitted external service. It is **off until you turn it on**,
you supply **your own Google credentials**, and no other feature depends on it —
the app builds and works completely without it.

### Turning it on

1. Open **Settings → Data → Export → Google Sheets sync**.
2. Flip **Enable Google Sheets sync**. You must acknowledge the warning that
   *your data leaves your local network and this device* before it turns on.
3. Paste the **Spreadsheet ID** of the Google Sheet you want the workbook written
   to (the long id in its URL: `.../spreadsheets/d/<SPREADSHEET_ID>/edit`).
4. Paste your **OAuth client ID, client secret, and refresh token** (below).
5. Use **Push now** to send the workbook on demand. Optionally tick **Also push
   after each sync** to push automatically after every successful hub/merge sync.

Settings and credentials are stored on the device in `flutter_secure_storage` —
never in the event log, so they never sync to other devices and never enter the
budget ledger.

### Supplying your own credentials

DuoBudget bundles no Google client secret; you bring your own so your data goes to
*your* account under *your* control:

1. In the [Google Cloud console](https://console.cloud.google.com/), create a
   project and enable the **Google Sheets API**.
2. Configure an OAuth consent screen and create an **OAuth client ID** (Desktop
   app). Note the client ID and client secret.
3. Obtain a **refresh token** for the `https://www.googleapis.com/auth/spreadsheets`
   scope using your preferred OAuth flow (e.g. the OAuth 2.0 Playground with your
   own client), then paste all three values into the Export screen.
4. Create the target spreadsheet in Google Sheets and copy its id.

### Why it is isolated

The rest of the app talks to Google only through the `SheetsClient` interface and
the pure `SheetsSyncService` gate (`app/lib/data/sheets/`). The gate refuses to
send anything unless sync is enabled, a spreadsheet and complete credentials are
present, and a supported client is bound. The core app binds
`UnavailableSheetsClient` — no Google client ships in it — so the feature is
absent by default and the app is fully functional and shippable without it,
exactly like the on-device OCR plugin. A concrete client can be dropped in behind
the same interface by overriding `sheetsClientProvider`, with no change to any
other feature. This keeps the firewall intact: nothing about budgeting depends on
an outside service.
