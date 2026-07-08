#!/usr/bin/env bash
# One-time environment bootstrap for DuoBudget.
#
# Purpose: install the Flutter SDK ONCE so it is baked into the container
# snapshot and every later session (and ./check.sh) finds it already present —
# instead of each session re-cloning Flutter from scratch.
#
# Wire this up as the environment SETUP command (Claude Code on the web:
# environment settings -> setup script), NOT a per-session hook. The setup
# script's filesystem is snapshotted; per-session hooks are not.
#
# Idempotent: a warm snapshot re-runs this as a fast no-op.
set -euo pipefail

FLUTTER_VERSION="${FLUTTER_VERSION:-3.44.5}"   # provides Dart >=3.12.2 (see app/pubspec.yaml)
FLUTTER_HOME="${FLUTTER_HOME:-/opt/flutter}"
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if [ ! -x "$FLUTTER_HOME/bin/flutter" ]; then
  echo "==> Installing Flutter $FLUTTER_VERSION -> $FLUTTER_HOME"
  git clone --depth 1 -b "$FLUTTER_VERSION" \
    https://github.com/flutter/flutter.git "$FLUTTER_HOME"
else
  echo "==> Flutter already present at $FLUTTER_HOME (skipping clone)"
fi

export PATH="$FLUTTER_HOME/bin:$PATH"

# Persist PATH for future shells (they source the user profile), so neither the
# agent nor ./check.sh has to rediscover or reinstall Flutter.
if ! grep -q "$FLUTTER_HOME/bin" "$HOME/.bashrc" 2>/dev/null; then
  echo "export PATH=\"$FLUTTER_HOME/bin:\$PATH\"" >> "$HOME/.bashrc"
fi

git config --global --add safe.directory "$FLUTTER_HOME" 2>/dev/null || true

echo "==> flutter precache (bake tool artifacts into the snapshot)"
flutter precache --universal >/dev/null

echo "==> flutter pub get"
( cd "$repo_root/app" && flutter pub get )

flutter --version
echo "==> Environment ready. Flutter on PATH at $FLUTTER_HOME/bin"
