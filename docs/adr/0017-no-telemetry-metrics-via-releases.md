# ADR 0017: User metrics from GitHub Releases stats, never from the app

- Status: Accepted
- Date: 2026-07-07

## Context

We want to know roughly how many people use LootLog — the kind of "resume
number" any project likes to cite. The usual way to get it, an analytics SDK or
a phone-home ping, is flatly incompatible with this app's promise: everything
runs on the user's own devices and nothing leaves their network without an
explicit, warned opt-in (ADR 0016). A privacy-first budgeting app that quietly
counts its users would be lying.

## Decision

**Distribution is GitHub Releases only.** Tagged CI builds attach a signed
Android APK and Windows/macOS/Linux desktop bundles; sharing the app means
sharing a release link.

**User counts come from the GitHub Releases download-statistics API — never from
the app.** There is **no telemetry, no analytics SDK, and no phone-home of any
kind.** A documented script fetches cumulative download counts and reports the
resume number.

## Consequences

- The "runs entirely on your devices, no phone-home" promise is kept literally —
  the app ships zero measurement code, so there is nothing to audit away.
- The metric is coarse (downloads, not active users) and external (GitHub's
  numbers, reproducible by anyone with the script), which we accept as the
  honest price of collecting nothing from users.
- Distribution and metrics are coupled by design: because releases are the only
  channel, the download count is a meaningful proxy, and there is exactly one
  place to look.
