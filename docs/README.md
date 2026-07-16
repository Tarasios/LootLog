# LootLog documentation

Start with the [top-level README](../README.md) for what LootLog is and how to
install it. This folder holds everything deeper.

## For users

- **[Household setup guide](setup-guide.md)** — the full walkthrough for
  non-technical users: installing, pairing devices, setting up budgets, daily
  logging, the month-close ritual, backups, and troubleshooting, ending with a
  printable fridge sheet.
- **[Update safety](update-safety.md)** — what an app update is guaranteed
  never to lose (your event log, receipts, pairings, preferences) and how to
  verify an upgrade by hand.
- **[Exports](exports.md)** — the offline .xlsx workbook, the tax package, and
  the optional opt-in Google Sheets sync.

## For contributors

- **[Architecture](architecture.md)** — the reference for every invariant and
  subsystem: the integer-cents event-sourced ledger, the pure reducer, the
  game/money firewall, sync, receipts, and more. Read this first.
- **[ADRs](adr/)** — one short record per major design decision and why it was
  made, from event sourcing (0001) to telemetry-free metrics (0017).
- **[Sync protocol](protocol.md)** — the LAN hub endpoints, pairing, event
  idempotency, and blob transfer.
- **[Art assets](art-assets.md)** — the pixel-art spec, written for a
  first-time pixel artist: one palette, two sprite sizes, and a prioritized
  "first ten assets" list. Every asset is optional; the app fully works as a
  text adventure without any art.
- **[Voice lines](voice-lines.md)** — every narrative and encouragement string
  beside its trigger, so writers can contribute without touching code.
- **[Distribution](distribution.md)** — how releases are built and shipped
  (GitHub Releases only) and the telemetry-free download metrics.
- **[Release guide](release.md)** — the one-time Android keystore setup and
  the optional Play Store path.
- **[Screenshots](screenshots/)** — captures referenced by the top-level
  README.
