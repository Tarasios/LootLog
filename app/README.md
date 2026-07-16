# LootLog — the Flutter app

This folder is the Flutter project for LootLog, a local-first shared budgeting
app that plays like a pixel-art dungeon crawler. If you just want to use the
app, grab a build from the
[releases page](https://github.com/Tarasios/LootLog/releases/latest) — you
never need to build it yourself. The full introduction lives in the
[top-level README](../README.md).

## Building and running

Requires a recent stable [Flutter SDK](https://docs.flutter.dev/get-started/install).

```bash
flutter pub get
flutter run                # pick a connected device or desktop
../check.sh                # dart analyze + flutter test (must pass before commits)
../tool/e2e.sh             # end-to-end multi-hub sync convergence
```

Targets: Android, Windows, macOS, Linux. There is no iOS or web target.

## Layout

```
lib/domain/    Pure Dart: events, the Money type, and the reducer (no Flutter imports)
lib/data/      Storage (drift), blobs, sync hub + client, OCR, imports/exports
lib/game/      Adventure mode: pure state adapter, cosmetic rewards, text mode, pixel widgets
lib/features/  Classic UI, one folder per feature
lib/ui/        Theme, shared widgets, and the glossary/strings module
assets/game/   Game art and all narrative/encouragement text (data-driven)
```

Two rules matter more than everything else: money is integer cents flowing
through one append-only event log and one pure reducer, and the game layer may
only ever append cosmetic events — a test proves that stripping every cosmetic
event leaves all balances identical. The details are in
[`docs/architecture.md`](../docs/architecture.md).
