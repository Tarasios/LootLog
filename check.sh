#!/usr/bin/env bash
# LootLog pre-commit gate: static analysis + tests must both pass.
# Exits nonzero if either step fails. Run from anywhere; it operates on app/.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$repo_root/app"

echo "==> dart analyze"
dart analyze

echo "==> flutter test"
flutter test

echo "==> All checks passed."
