# ADR 0012: The asset-degradation ladder and first-class text mode

- Status: Accepted
- Date: 2026-07-07

## Context

The game is now the primary experience (ADR 0011), but art is the scarcest
resource on this project: a single beginner pixel artist. A game-first app that
crashes, blocks a screen, or looks broken whenever a sprite is missing would be
worse than no game at all. We need every game surface to render fully no matter
how much art actually exists — from a complete pixel dungeon down to no sprites
at all — without treating "art missing" as an error.

## Decision

Every game surface must render fully at **three tiers, decided per-asset at
runtime**:

1. **Full pixel art** — the target look: a pixel dungeon crawler with party
   frames and HP bars around a central floor viewport, a scrolling log, and a
   minimap of the year's floors.
2. **Partial** — available sprites render; each missing one degrades to a
   **labeled placeholder card**. Never crash, never block a screen on a missing
   asset.
3. **Text mode** — a **first-class text-adventure presentation, not an error
   state**: the same screens rendered as styled text panels driven by the
   member/pet/quest `descriptionText` the user wrote. **The app must be
   complete, shippable, and fun in text mode alone.**

Art constraints are pinned to make the artist's job finite: `docs/art-assets.md`
specifies one small fixed palette, **one** base sprite size (32×32) plus one
portrait size (48×48), a 9-slice panel spec, and a prioritized "first ten
assets" list. Every asset is individually optional. Pixel art renders with
`FilterQuality.none` at integer scales; custom sprite blobs use the same
pixelated pipeline.

## Consequences

- Development is unblocked by art: features ship in text mode and light up
  visually as sprites arrive, one asset at a time.
- The `descriptionText` fields on members, pets, and quests are load-bearing —
  they are the content of text mode, not decoration — which is why they live in
  the member/quest events.
- "First-class text mode" is a testable bar: a build with an empty
  `app/assets/game/` must still present every screen as styled text and be
  playable.
- No screen can be taken down by a missing or malformed asset; the worst case is
  a labeled placeholder.
