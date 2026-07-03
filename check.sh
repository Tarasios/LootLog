#!/usr/bin/env bash
#
# CI-style check for DuoBudget. Runs the same gates locally that CI enforces:
#   - dart analyze   (strict lints, zero warnings)
#   - flutter test   (reducer + widget tests)
#   - gofmt          (server formatting)
#   - go vet         (server static checks)
#   - go test        (server tests)
#
# Exits non-zero on the first failing gate. Run from the repo root: ./check.sh
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FAIL=0

section() { printf '\n\033[1m==> %s\033[0m\n' "$1"; }

# ---- Flutter / Dart -------------------------------------------------------
if command -v flutter >/dev/null 2>&1; then
  section "dart analyze (app)"
  (cd "$ROOT/app" && flutter pub get >/dev/null && dart analyze --fatal-infos --fatal-warnings)

  section "flutter test (app)"
  (cd "$ROOT/app" && flutter test)
else
  echo "ERROR: flutter not found on PATH" >&2
  FAIL=1
fi

# ---- Go server ------------------------------------------------------------
if command -v go >/dev/null 2>&1; then
  section "gofmt (server)"
  UNFORMATTED="$(gofmt -l "$ROOT/server")"
  if [ -n "$UNFORMATTED" ]; then
    echo "gofmt needs to be run on:" >&2
    echo "$UNFORMATTED" >&2
    FAIL=1
  fi

  section "go vet (server)"
  (cd "$ROOT/server" && go vet ./...)

  section "go test (server)"
  (cd "$ROOT/server" && go test ./...)
else
  echo "ERROR: go not found on PATH" >&2
  FAIL=1
fi

if [ "$FAIL" -ne 0 ]; then
  printf '\n\033[31mchecks failed\033[0m\n'
  exit 1
fi
printf '\n\033[32mall checks passed\033[0m\n'
