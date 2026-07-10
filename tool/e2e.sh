#!/usr/bin/env bash
# LootLog end-to-end multi-hub sync convergence test.
#
# Stands up two desktop instances (each hosting a LAN hub) and a third client
# paired to both, over real loopback HTTP, and drives every convergence scenario
# on the release checklist: offline convergence, shared/group purchases,
# retroactive months, spoils allocation, pool withdrawals (incl. self-approval
# rejection), emergency ransacks, receipt propagation + library placement,
# surviving a hub outage, export-into-a-fresh-instance parity, tax-package
# parity, and defensive import handling. Exits nonzero on any failure.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root/app"

echo "==> dart run tool/e2e.dart"
dart run tool/e2e.dart

echo "==> e2e passed."
