# Critical bugs — release-blocker fix pass

**Date:** 2026-07-10
**Status:** Approved design, pending implementation plan
**Scope:** Six defects that currently make LootLog unusable for its core multi-device purpose. No reducer changes; no new features. Larger workstreams (domain-model changes, UX overhaul, Adventure redesign) are deliberately out of scope and get their own specs.

## Approach

Root-cause-first, one branch. The Android sqlite foundation is fixed before anything else because two of the six reported symptoms (setup hang, sync failure) almost certainly share it as a root cause. Independent bugs follow in order. Each fix carries its own acceptance criterion; Android-only items get a manual device checklist since CI cannot run the phone.

## Bug 1 — Android database initialization (root cause)

**Symptom:** Sync from the phone fails with "invalid arguments" from `sqlite3_initialize` (and cascading errors). Observed on Android 17.

**Diagnosis:** `app/pubspec.yaml` contains a comment admitting the gap: Android native-lib provisioning (`sqlite3_flutter_libs`) was deferred "until the data layer lands" and never added. Android ships no usable bundled sqlite3, so drift cannot open the database on the phone at all.

**Fix:**
- Add `sqlite3_flutter_libs` (current release, which ships 16 KB-page-aligned `.so` files required on Android 15+).
- Verify Gradle/NDK configuration is compatible (ABI filters, page-size alignment).
- Confirm drift's `NativeDatabase` setup follows the drift-recommended Android bootstrap (temp directory workaround where applicable).

**Acceptance:** A fresh install on the Android 17 device completes onboarding, writes events, and completes a pair + pull cycle against a Windows hub.

## Bug 2 — Silent failures ("Begin the adventure" dead button)

**Symptom:** On mobile, tapping "Begin the adventure" at the end of setup does nothing — no spinner, no error, no navigation.

**Diagnosis:** The setup-completion path swallows exceptions. With Bug 1 present, the initial event writes fail and the failure is invisible. This violates the project invariant that failures are "silent-but-visible via a status indicator, never blocking dialogs" — currently they are silent-and-invisible.

**Fix:**
- Setup completion and sync paths must never swallow exceptions. Surface failures as a visible, non-blocking error state (inline error text / status indicator, not a modal).
- The button shows a progress state while the write is in flight.

**Acceptance:** With a deliberately broken database, tapping "Begin the adventure" shows a visible error instead of doing nothing. With Bug 1 fixed, setup completes and navigates forward on the Android 17 device.

## Bug 3 — QR scan missing from "Join an existing party"

**Symptom:** The join screen offers only manual URL + pairing-secret text fields. Typing the secret by hand is impractical.

**Diagnosis:** `mobile_scanner` is already a dependency and the QR payload format `{url, pairingSecret}` is already specified and emitted by the hub side; the scanner was never wired into `app/lib/features/setup/join_party_screen.dart`.

**Fix:**
- On platforms with a camera (Android), the join screen offers a scan view that parses the existing QR payload and prefills both fields, then proceeds to pairing.
- Manual entry remains available as fallback everywhere; desktop keeps manual entry as primary.
- Camera-permission denial degrades gracefully back to manual entry.

**Acceptance:** Scanning the QR shown by a Windows hub fills both fields and pairs successfully with no typing.

## Bug 4 — Activity log mislabels member edits

**Symptom:** Editing an existing member logs "added to the party." Opening the editor and saving without changes also appends an event. Uploading a portrait logs the same wrong line.

**Diagnosis:** Two defects: (a) the activity-log derivation renders every `MemberSet` as a join; (b) the member editor appends a `MemberSet` even when nothing changed, polluting the append-only audit log with no-op events.

**Fix:**
- Derivation: a `MemberSet` for a memberId not present in prior state renders as "joined the party"; a subsequent `MemberSet` renders as "was updated" (with a portrait-specific line when only `customSpriteSha256` changed).
- Editor: saving with no field changes appends no event at all.
- The derivation logic is pure and unit-tested (TDD, per workflow rules).

**Acceptance:** No-op edit → no event in the log. Name edit → "updated" entry. Portrait upload → portrait-updated entry. New member → "joined" entry. Existing historical events render correctly (first-occurrence rule needs no event-schema change).

## Bug 5 — Custom member sprite never renders in Adventure

**Symptom:** On desktop, pixel tier, an adult member with an uploaded PNG portrait shows the initials placeholder instead of the sprite.

**Diagnosis (confirmed in code):**
- `customSpriteBlobsProvider` (`app/lib/game/adventure_screen.dart:31-36`) preloads blob bytes only for quests and pets — member sprites are never loaded, so the resolver returns null and `GameSprite` falls back to the placeholder.
- The hero party frames (`app/lib/game/adapter.dart:59-61`) hardcode `Sprites.heroA`/`heroB` asset refs for "me"/"partner", ignoring `customSpriteSha256` entirely — also a lingering two-adult assumption. The general roster path (`adapter.dart:201-203`) is already correct.

**Fix:**
- Preloader collects `customSpriteSha256` from `state.members` alongside quests and pets.
- Hero/party-frame sprite refs derive from the member's `customSpriteSha256` when set, falling back to role-appropriate assets; derive from `MemberSet` state rather than the me/partner pair.
- Adapter change is pure and unit-tested (TDD, per workflow rules).
- Member editor shows a preview of the uploaded sprite.

**Acceptance:** Uploaded PNG visible in the member-edit preview and in the pixel-tier party frames and roster on desktop.

## Bug 6 — Desktop tutorial breaks after one step

**Symptom:** On Windows, the tutorial shows a single misshapen popup mentioning "+ New", closes entirely on "Next", and never reappears.

**Fix:**
- Overlay layout renders correctly across desktop window sizes (no clipped/misshapen popup).
- "Next" advances to the following step; completing or dismissing is recorded; an explicit "Restart tutorial" entry in settings brings it back.
- Closing mid-way resumes from the same step on next launch.

**Acceptance:** Full tutorial walkthrough completes step-by-step on Windows; restart-from-settings works.

## Testing & verification

- TDD for pure logic: activity-log derivation (Bug 4), adapter sprite refs (Bug 5).
- `./check.sh` (dart analyze + flutter test) green before every commit.
- Manual Android 17 device checklist: fresh-install onboarding (Bugs 1, 2), QR pair + sync cycle (Bugs 1, 3).
- Manual Windows checklist: tutorial walkthrough (Bug 6), pixel-tier sprite rendering (Bug 5).

## Out of scope (tracked for later specs)

Setup-wizard improvements; pet-owned budgets and other domain-model changes; month-close multi-device concurrency; UX/IA overhaul; Adventure-mode redesign; Gemini art prompts; update/migration safety.
