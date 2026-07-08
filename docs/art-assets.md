# Art assets — the adventure skin

The adventure skin is a **pure presentation layer**. It renders the same numbers
as the classic UI (`lib/game/adapter.dart` maps `HouseholdState -> GameState`);
the sprites here are cosmetics only. Missing art never crashes: `GameSprite`
degrades any absent file or undecodable blob to a labelled grey placeholder.

## Pixel-art rules

- All art is pixel art, drawn on a **16×16 base grid** per frame.
- Sprites render with `FilterQuality.none` at **integer scale factors** only
  (2×, 3×, 4×, …). Never fractional — that would blur the pixels.
- Colours come from the sprite, not the theme; the surrounding chrome
  (cards, banners, HP bars) is themed.

## File naming — sprite-sheet strips

Animated sprites are a **single horizontal strip** of uniform square frames in
one PNG. The frame count is encoded in the filename suffix `_<N>f`:

```
<name>_<N>f.png        e.g. hero_a_idle_4f.png  → 4 frames, 64×16 px
```

- `N` is the number of frames; frame width = image width ÷ N; frames are square
  (frame width == image height == 16 at 1× authoring).
- A **single-frame** (static) sprite uses `_1f`, e.g. `gold_pouch_1f.png`.
- `GameSprite` parses `N` from the suffix. A filename with no valid `_<N>f`
  suffix is treated as a single frame.

Custom sprites supplied by the user (quest / pet / avatar blobs, referenced by
`customSpriteSha256`) are always treated as **single-frame** and are decoded
from the content-addressed blob, not from `assets/`. They render through the
exact same pixelated pipeline.

## Asset manifest — `app/assets/game/`

Referenced by exact name from the adventure widgets. All are 16×16-per-frame.

| File                       | Frames | Used for                                   |
| -------------------------- | -----: | ------------------------------------------ |
| `hero_a_idle_4f.png`       |      4 | The device owner's idle avatar             |
| `hero_b_idle_4f.png`       |      4 | The partner's idle avatar                  |
| `monster_idle_4f.png`      |      4 | A personal-category monster (default)      |
| `monster_enraged_4f.png`   |      4 | An overspent (enraged) monster             |
| `contract_seal_1f.png`     |      1 | Group-category party-contract seal         |
| `pet_idle_4f.png`          |      4 | A pet party member (default sprite)        |
| `quest_monster_4f.png`     |      4 | A savings-goal quest monster (default)     |
| `trophy_1f.png`            |      1 | A completed quest's trophy                 |
| `gold_pouch_1f.png`        |      1 | The vault (gold pouch)                     |
| `war_chest_1f.png`         |      1 | The war chest (shared pool)                |
| `writ_1f.png`              |      1 | A pending withdrawal writ                  |
| `ransack_1f.png`           |      1 | The "war chest was ransacked" banner mark  |
| `reserve_cache_1f.png`     |      1 | An emergency fund (reserve cache)          |
| `anvil_1f.png`             |      1 | Equipment maintenance & provisioning       |
| `supplies_1f.png`          |      1 | Expedition supplies (income)               |
| `coin_spin_6f.png`         |      6 | Coin-burst minting & coin arcs (spoils)    |
| `scroll_seal_1f.png`       |      1 | Tax-deductible marker (purchase detail)    |

Ship real art by dropping correctly-named PNGs into `app/assets/game/`; the
widgets pick them up with no code change. Until then the placeholders render.
