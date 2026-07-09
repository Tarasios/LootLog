# Distributing DuoBudget

DuoBudget is distributed through **GitHub Releases only**. A release is a set of
tagged, reproducible binaries attached to a Release page:

- a **signed, sideloadable Android APK**,
- a **Windows** zip (portable, no installer),
- a **macOS** `.app` (zipped) and a `.dmg`,
- a **Linux** x64 tarball (with an optional AppImage).

There is no app store account, no server, and no auto-updater. **Sharing the app
is sharing a release link.** Nothing here uploads anything about a user — see
[Metrics without telemetry](#metrics-without-telemetry) for how we count usage
without the app ever phoning home.

> This document is the authoritative distribution guide. For the one-time
> **upload-keystore creation** and the **Play Store `.aab`** path, see
> [`release.md`](release.md); everything else lives here.

**Contents**

1. [Reproducibility & the pinned toolchain](#reproducibility--the-pinned-toolchain)
2. [Versioning](#versioning)
3. [The CI release pipeline](#the-ci-release-pipeline)
4. [Building each artifact by hand](#building-each-artifact-by-hand)
   - [Android APK (signed, sideloadable)](#android-apk-signed-sideloadable)
   - [Windows (zip)](#windows-zip)
   - [macOS (.app / .dmg)](#macos-app--dmg)
   - [Linux (tar / AppImage)](#linux-tar--appimage)
5. [Metrics without telemetry](#metrics-without-telemetry)
6. [Cutting a release: checklist](#cutting-a-release-checklist)

---

## Reproducibility & the pinned toolchain

Every DuoBudget build — CI or local — uses **one pinned Flutter version** so a
given tag produces the same binaries anywhere. The pin lives in three places
that must stay in lockstep:

| Where | What it pins |
| --- | --- |
| `tool/setup-env.sh` | `FLUTTER_VERSION` for the dev/container environment |
| `.github/workflows/release.yml` | `FLUTTER_VERSION` used by every CI build job |
| This document (below) | the human-readable record |

**Pinned Flutter: `3.44.5`** (Dart ≥ 3.12.2, matching `app/pubspec.yaml`).

To build locally with the same toolchain:

```bash
# The container already has Flutter on PATH via tool/setup-env.sh.
# On your own machine, install exactly the pinned version, e.g. with fvm:
fvm install 3.44.5 && fvm use 3.44.5
flutter --version        # confirm 3.44.5 before building anything
```

Dependencies are locked by `app/pubspec.lock` (committed). Do **not** run
`flutter pub upgrade` as part of cutting a release — build from the lockfile.

Before packaging anything, from the repo root:

```bash
./check.sh          # dart analyze + flutter test
./tool/e2e.sh       # multi-hub sync convergence end-to-end
```

Desktop binaries are **not** cross-compiled: each desktop platform must be built
**on that platform** (that is why CI fans out to Windows, macOS, and Linux
runners).

---

## Versioning

The single source of truth is `version:` in `app/pubspec.yaml`
(`<name>+<build>`, e.g. `1.0.0+1`). Android `versionName`/`versionCode` and the
desktop bundle versions all derive from it.

Release **tags are `v<name>`** — e.g. `v1.0.0` for `version: 1.0.0+1`. Pushing a
`v*` tag is what triggers the CI pipeline. Bump `pubspec.yaml`, commit, then tag:

```bash
git tag v1.0.0
git push origin v1.0.0
```

Artifacts are named `duobudget-<version>-<platform>.<ext>` (the CI strips the
leading `v` from the tag), so the Release page reads cleanly and the metrics
script can bucket downloads by platform.

---

## The CI release pipeline

`.github/workflows/release.yml` runs on every pushed `v*` tag (and can be
re-run manually via **workflow_dispatch** with a tag input). It:

1. resolves `version` from the tag,
2. builds all four artifacts in parallel on native runners
   (`ubuntu-latest` for Android + Linux, `windows-latest`, `macos-latest`),
3. uploads each as a workflow artifact, and
4. gathers them into a single **GitHub Release** for the tag
   (`softprops/action-gh-release`, with auto-generated release notes).

### Android signing secrets

The Android job produces a **signed** APK only when these repository secrets are
set (Settings → Secrets and variables → Actions); otherwise it falls back to
Flutter's debug signing and emits a CI warning — installable for testing, **not**
fit for public distribution.

| Secret | Value |
| --- | --- |
| `ANDROID_KEYSTORE_BASE64` | your upload keystore, base64-encoded (`base64 -w0 upload.jks`) |
| `ANDROID_STORE_PASSWORD` | keystore store password |
| `ANDROID_KEY_ALIAS` | key alias (e.g. `upload`) |
| `ANDROID_KEY_PASSWORD` | key password |

The workflow writes `android/key.properties` + the keystore at build time and
**scrubs both afterwards** (`if: always()`); nothing secret is ever committed.
See [`release.md`](release.md) for how to create the keystore in the first place.

> Desktop bundles are shipped **unsigned** by CI. Optional per-platform
> code-signing/notarization is documented [below](#building-each-artifact-by-hand)
> as a manual step — it needs certificates that shouldn't live in this repo.

---

## Building each artifact by hand

Everything below is exactly what CI runs, so you can reproduce or debug a release
locally. Run from `app/` after `flutter pub get`.

### Android APK (signed, sideloadable)

Prerequisites: JDK 17, Android SDK (bundled with Flutter tooling), and an
`android/key.properties` pointing at your upload keystore (see
[`release.md`](release.md)). Without it the build falls back to debug signing.

```bash
cd app
flutter build apk --release
# -> build/app/outputs/flutter-apk/app-release.apk
```

Verify the signature, then rename for the Release page:

```bash
jarsigner -verify -verbose -certs \
  build/app/outputs/flutter-apk/app-release.apk
cp build/app/outputs/flutter-apk/app-release.apk \
   duobudget-1.0.0-android.apk
```

Users sideload it by copying the APK to the phone and opening it (they enable
"install unknown apps" once). This is the primary Android channel; the Play
Store `.aab` path is optional and covered in [`release.md`](release.md).

### Windows (zip)

Prerequisites: Visual Studio with the **Desktop development with C++** workload.

```bash
cd app
flutter build windows --release
# -> build/windows/x64/runner/Release/  (the .exe plus DLLs and data/)
```

Ship the **whole** `Release/` folder, zipped:

```powershell
Compress-Archive -Path build/windows/x64/runner/Release/* `
  -DestinationPath duobudget-1.0.0-windows-x64.zip
```

Optional signing: `signtool sign /fd SHA256 /a <artifact>` with an Authenticode
certificate. Unsigned, SmartScreen will warn on first run.

### macOS (.app / .dmg)

Prerequisites: Xcode.

```bash
cd app
flutter build macos --release
# -> build/macos/Build/Products/Release/duobudget.app
```

Package both a zip (preserves the bundle exactly) and a `.dmg`:

```bash
app="build/macos/Build/Products/Release/duobudget.app"
ditto -c -k --keepParent "$app" duobudget-1.0.0-macos.app.zip
hdiutil create -volname DuoBudget -srcfolder "$app" \
  -ov -format UDZO duobudget-1.0.0-macos.dmg
```

**Unsigned caveat:** CI ships these unsigned/un-notarized. Gatekeeper will block
them on first open — a user must right-click → **Open** (or
`xattr -dr com.apple.quarantine duobudget.app`). For frictionless distribution,
sign and notarize with a Developer ID (needs a paid Apple Developer account):

```bash
codesign --deep --force --options runtime \
  --sign "Developer ID Application: <Your Name> (<TEAMID>)" "$app"
xcrun notarytool submit duobudget-1.0.0-macos.dmg \
  --apple-id <you@example.com> --team-id <TEAMID> --wait
xcrun stapler staple duobudget-1.0.0-macos.dmg
```

### Linux (tar / AppImage)

Prerequisites: `clang cmake ninja-build pkg-config libgtk-3-dev liblzma-dev
libsqlite3-dev`.

```bash
cd app
flutter build linux --release
# -> build/linux/x64/release/bundle/  (executable plus lib/ and data/)
```

Tarball the whole bundle (this is what CI ships):

```bash
tar -czf duobudget-1.0.0-linux-x64.tar.gz \
  -C build/linux/x64/release/bundle .
```

Ensure the target machine has `libsqlite3` and GTK 3 (present on most distros).

**Optional AppImage** for a single-file download. Assemble an AppDir from the
bundle, add a `.desktop` file and an icon, then run
[`appimagetool`](https://github.com/AppImage/AppImageKit):

```bash
appdir=DuoBudget.AppDir
mkdir -p "$appdir/usr/bin"
cp -r build/linux/x64/release/bundle/* "$appdir/usr/bin/"
cat > "$appdir/duobudget.desktop" <<'EOF'
[Desktop Entry]
Type=Application
Name=DuoBudget
Exec=duobudget
Icon=duobudget
Categories=Office;Finance;
EOF
cp path/to/duobudget.png "$appdir/duobudget.png"   # 256x256 icon
ln -sf usr/bin/duobudget "$appdir/AppRun"
appimagetool "$appdir" duobudget-1.0.0-linux-x86_64.AppImage
```

---

## Metrics without telemetry

**The app never phones home.** There is no analytics SDK, no crash reporter, no
usage ping, and no network call you didn't initiate: sync is LAN-only between
your own paired devices, and the optional Google Sheets integration is off by
default, isolated behind an interface, and uses your own credentials. Strip that
one opt-in seam and DuoBudget makes **zero** outbound connections.

So we count usage the only honest way available: **how many times the release
binaries were downloaded from GitHub.** GitHub records `download_count` for every
Release asset and exposes it on the public Releases API, with no cooperation from
the running app. The documented script:

```bash
dart run tool/release_downloads.dart            # defaults to tarasios/duobudget
dart run tool/release_downloads.dart owner/repo # any repo
```

It prints per-asset and per-release counts, a per-platform summary, and the
grand **TOTAL DOWNLOADS** — the "resume number". It imports only the Dart SDK
(no `pub get` needed). Set `GITHUB_TOKEN` in the environment to raise the API
rate limit (60 → 5000 requests/hour) or to read a private repo. Example:

```
========================================================
By platform (summed across all releases):
       412  Android (APK)
        88  Linux
       167  Windows
       133  macOS
========================================================
       800  TOTAL DOWNLOADS (resume number)
```

Caveats worth stating when you cite the number: it counts **downloads, not
installs or active users** (we deliberately can't measure those without
telemetry), and GitHub's auto-generated source zip/tarball is not an asset and is
not counted — only the binaries we upload are.

---

## Cutting a release: checklist

1. `./check.sh` and `./tool/e2e.sh` pass on `main`.
2. Bump `version:` in `app/pubspec.yaml`; commit (`pubspec.lock` unchanged).
3. Confirm the four signing secrets exist if you want a signed Android APK.
4. Tag and push: `git tag v<version> && git push origin v<version>`.
5. Watch the **Release** workflow build all four platforms and create the
   Release. Confirm each artifact is attached and named
   `duobudget-<version>-<platform>.<ext>`.
6. Smoke-test at least one desktop build and the APK:
   first-run party creation → start a hub → pair a second device → export a
   `.dbevents.zip` and re-import it on a fresh install (state matches).
7. Share the Release link. Later, `dart run tool/release_downloads.dart` for the
   download tally.
