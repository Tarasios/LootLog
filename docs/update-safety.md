# Update safety — what an app update must never lose

LootLog is local-first: every byte of household data lives on the device.
Installing a new version over an old one must therefore preserve **all of
it** — the event log, receipts and sprites, sync pairings, and every
per-device preference. This page lists each persistence surface, the
guarantee it carries, the test that enforces it, and a manual checklist for
verifying a real upgrade on Android.

## The surfaces and their guarantees

### 1. The event log (drift/SQLite, `app.db`)

The household's single source of truth. Append-only: no migration may ever
rewrite, drop, or transform event rows.

- **Guarantee:** a database created by any released schema version opens
  cleanly under the current version; every event row (and its integer-cents
  payload) is bit-identical after the upgrade; device setup, sync cursors,
  and hub pairings survive.
- **How:** `AppDatabase.schemaVersion` (currently 3) with an additive-only
  `MigrationStrategy` — new versions only `createTable` new bookkeeping
  tables. Existing tables have never been altered.
- **Test:** `app/test/data/migration_test.dart` builds a real database file,
  rewinds it to v1 / v2 (dropping the later tables, stamping
  `PRAGMA user_version`), reopens with the current schema and asserts the
  data survived. **When bumping `schemaVersion`, extend
  `_tablesAddedAfter` in that test — the tests then guard the new upgrade
  path automatically.**

Rules for future migrations:

- Additive only. Create tables/columns (with defaults); never drop or
  rewrite domain rows. Corrections are compensating *events*, not schema
  surgery.
- If a derived table must change shape, rebuild it from the event log —
  never the other way round.

### 2. Blobs (`<documents>/blobs/<sha256>`)

Receipts and custom sprites, content-addressed.

- **Guarantee:** the `blobs/<sha256>` layout is a compatibility contract; a
  fresh `BlobStore` over the same directory (the updated app) finds every
  blob by the same name. Referenced blobs are never deleted; blob shas
  nested inside cosmetic values (homestead stage art) count as referenced.
- **Test:** `app/test/data/blob_store_test.dart` — "update safety" group and
  the referenced-blobs suite.

### 3. Sync pairings and tokens

- **Hub-side** (the desktop hosting a hub): `hub_config_rows` keeps the
  stable `hubId` + pairing secret, `hub_device_tokens` the tokens it has
  issued. Both live in the database and are covered by the migration tests
  — a restarted or updated hub keeps serving the same cursors and accepts
  the same bearer tokens.
- **Client-side**: `paired_hubs` holds each hub's URL and this device's
  bearer token; `hub_cursors` the per-hub pull cursor. Covered by the
  migration tests (a v2 pairing survives the v3 upgrade verbatim). No
  re-pairing after an update, no re-pull from zero.
- **Google Sheets (the only external service)**: settings + user-supplied
  OAuth credentials live in `flutter_secure_storage` (the OS keystore, which
  Android/desktop preserve across app updates — note: uninstall/reinstall
  may clear it, which is fine; sync is opt-in). LootLog's contract on top:
  stable keys, JSON round-trip, and **any missing or corrupted value decodes
  to the off-by-default state** — an update can never switch the external
  service on by itself. Test: `app/test/data/sheets/sheets_store_test.dart`.

### 4. Per-device preference files (`<documents>/*.txt`)

Tiny files, one value each. Contract: an updated app reads every value any
older version could have written, and a missing or corrupted file falls back
to a safe default — never a crash, never a surprising flip.

| File | Values (incl. legacy) | Default on missing/garbage |
|------|----------------------|---------------------------|
| `tutorial_seen.txt` | legacy boolean-era `true`; `step:N` | fresh (tour offers itself) |
| `app_skin.txt` | `classic` / `adventure` | Adventure (game first) |
| `adventure_tier.txt` | `pixel` / `text` | `defaultAdventureTier` |
| `show_household_budgets.txt` | `on` / `off` | on (full mutual visibility) |
| `receipt_offload.txt` | legacy `on`/`off`; `keep`-implied, `offload`, `none` | keep (every image stays) |
| `offloaded_receipts.txt` | one sha per line | empty set |
| `receipt_library_root.txt` | a directory path | library off until re-chosen |

**Test:** `app/test/features/update_safety_prefs_test.dart` runs the real
loaders against a faked documents directory for every row above (the library
root is a plain path read, exercised by the receipt-library suite).

Rule for new prefs: parse defensively (unknown value → default), keep old
value spellings parseable forever, and add a case to the update-safety test.

## Manual upgrade checklist (release APK over previous version)

Run before shipping a release that touches the schema, blobs, sync, or any
pref loader. Takes ~10 minutes with one phone and one desktop hub.

1. **Install the PREVIOUS release APK** on the phone (`adb install
   app-release-old.apk`). Complete setup, then create real state:
   - log 2–3 purchases (one with a receipt photo attached),
   - set a member description and a custom member sprite,
   - pair with a desktop hub and let one sync cycle finish,
   - complete (or skip) the tutorial, switch skin to Classic and back,
   - note the war-chest balance and the current dungeon floor.
2. **Install the NEW release APK over it** — `adb install -r
   app-release-new.apk` (no uninstall! `-r` is the update path users take).
3. **Verify, in order:**
   - [ ] App launches straight to the dashboard — no re-setup, no tutorial.
   - [ ] Every purchase, balance, monster HP, and the floor number match
         what you noted (identical numbers, both skins).
   - [ ] The receipt photo still opens from the purchase detail.
   - [ ] The custom sprite still renders in Adventure mode.
   - [ ] Skin / tier / visibility / receipt-mode choices are unchanged.
   - [ ] Sync: log one purchase on the desktop, sync, and see it arrive on
         the phone **without re-pairing** (the old token still works).
   - [ ] Export a `.dbevents.zip` and confirm the event count matches the
         pre-update export ("N already present" on re-import).
4. **Hub upgrade:** update the desktop build too, restart the hub, and
   confirm the phone's next sync succeeds with the same pairing.

Any failure here is a release blocker: data loss on update is the one bug a
local-first app cannot apologise for.
