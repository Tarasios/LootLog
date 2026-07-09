# Art assets — a commissioning guide

Hello, and welcome. This is your brief. You have never drawn game art before, and
that is fine — this document is written so you never have to guess. Every rule
here exists so that whatever you draw *drops straight into the app and works*,
even if you only ever finish one sprite.

Two things to hold onto before we start:

1. **The art is a skin, never the game's brain.** DuoBudget is a real budgeting
   app wearing a dungeon-crawler costume. Your sprites decorate numbers the app
   already computed; they never change a single cent. Draw freely — you cannot
   break the money.
2. **Every asset is optional.** The app ships and is fun with *zero* art (it
   falls back to a labelled grey card, then to a full text-adventure mode). So
   there is no "you must finish everything" pressure. Draw the highest-priority
   thing, drop it in, see it appear. Then draw the next.

---

## 1. The palette — DawnBringer 16 (DB16)

Use **one** palette for **everything**: **DawnBringer 16**, a famous, beloved
16-colour palette designed for exactly this — a beginner making a cohesive
pixel-art game. Sixteen colours is a feature, not a limit: it forces the whole
game to feel like one world, and it means you never agonise over a colour picker.

Set these sixteen swatches up in your editor as your *only* palette, and pick
every pixel from them:

| # | Name (informal) | Hex |
|---|-----------------|-----|
| 1 | Black | `#140C1C` |
| 2 | Deep maroon | `#442434` |
| 3 | Navy | `#30346D` |
| 4 | Slate grey | `#4E4A4E` |
| 5 | Brown | `#854C30` |
| 6 | Forest green | `#346524` |
| 7 | Red | `#D04648` |
| 8 | Warm grey | `#757161` |
| 9 | Blue | `#597DCE` |
| 10 | Orange | `#D27D2C` |
| 11 | Steel / light grey | `#8595A1` |
| 12 | Leaf green | `#6DAA2C` |
| 13 | Skin / peach | `#D2AA99` |
| 14 | Cyan | `#6DC2CA` |
| 15 | Yellow | `#DAD45E` |
| 16 | Off-white | `#DEEED6` |

Rules of thumb:

- **Outline** with Black (`#140C1C`), not pure `#000000` — it reads softer.
- **Shade** by picking a *different, darker swatch* from the sixteen (e.g. shade
  Skin `#D2AA99` with Brown `#854C30`), not by lowering opacity. Everything is
  100% opaque except the fully-transparent background (see §3).
- **Red (`#D04648`)** is the game's "danger" colour: enraged monsters, lost HP,
  the ransack banner. Reserve it for those so it stays meaningful.
- **Yellow (`#DAD45E`)** and **Orange (`#D27D2C`)** are "treasure": coins,
  trophies, the gold pouch.

---

## 2. Sizes — exactly two

You only ever draw at two canvas sizes. That is the whole size system.

| Purpose | Canvas | Used for |
|---------|--------|----------|
| **Base sprite** | **32 × 32 px** | Monsters, quest bosses, coins, trophies, the pet/familiar on the floor, item icons — everything that lives *in* the dungeon. |
| **Portrait** | **48 × 48 px** | Party-member face frames only (the adventurer/companion/familiar portraits along the edge of the screen). |

That's it. No other sizes. If something feels like it wants to be bigger (a boss,
a homestead), draw it at 32×32 anyway and let the app scale it up in whole steps
(see §4). Backgrounds are the one exception, noted in the backlog.

> **Why 32, not 16?** 32×32 gives a first-timer room to read shapes and add a
> little shading without fighting for every pixel, while still being small enough
> to finish. Every sprite the app references is authored on a 32×32 (or 48×48
> portrait) grid.

---

## 3. File format & naming

- **Format:** PNG, RGBA, with a **fully transparent background** (alpha 0). Do
  not draw a background colour behind the sprite — the dungeon shows through.
- **No compression tricks, no colour profiles.** A plain PNG exported from any
  editor is perfect.
- **Filenames are a contract.** The app looks each file up by *exact name*. Ship
  a sprite by dropping the correctly-named PNG into `app/assets/game/`; the app
  picks it up with no code change. Until then, the labelled placeholder shows.

### Static vs. animated — the `_<N>f` suffix

Most sprites can be a single still frame. Some (an idle monster bobbing, a coin
spinning) look better animated. Animation is **one horizontal strip** of equal
square frames in a single PNG, and the filename says how many frames:

```
<name>_<N>f.png
```

- `N` = number of frames. `monster_idle_4f.png` is a 4-frame strip, so the PNG is
  **128 × 32** (four 32×32 frames left-to-right). `coin_spin_6f.png` is
  **192 × 32**.
- A **still** sprite uses `_1f`, e.g. `trophy_1f.png` (a single 32×32 frame).
- Frames are square and equal: frame width = image width ÷ N = image height.
- You can *always* start with `_1f` and add animation later by widening the strip
  and renaming — nothing else changes.

Custom sprites a *user* supplies (their own quest / pet / avatar art) are always
treated as a single still frame and are decoded from the user's file, but they
render through the exact same pixelated pipeline as your assets.

---

## 4. Integer-scale rule (the one technical rule)

The app **never** blurs your pixels. It draws every sprite with
`FilterQuality.none` and only ever magnifies by **whole numbers** — 2×, 3×, 4× —
never 1.5× or 2.3×. A 32×32 sprite shown at 3× is exactly 96×96 crisp pixels.

What this means for you: **draw at the true 32×32 (or 48×48) grid, one pixel per
pixel.** Do not pre-scale, do not add anti-aliasing / soft edges, do not export at
2×. The app handles all magnification. Soft/feathered edges will look muddy once
magnified; hard single-pixel edges stay sharp.

---

## 5. The 9-slice panel

The boxes that frame things — party frames, the log panel, the floor viewport —
are **9-slice** (a.k.a. 9-patch) sprites. This lets one small drawing stretch to
any size without distorting its corners.

Draw a **small** panel — a **48 × 48** PNG works well — divided by an invisible
3×3 grid into nine regions. A **16px corner inset** is the default the app
assumes:

```
   16px          16px
 ┌──────┬────────┬──────┐
 │  TL  │   TE   │  TR  │   ← top row: corners fixed, TE tiles horizontally   16px
 ├──────┼────────┼──────┤
 │  LE  │   C    │  RE  │   ← middle: LE/RE tile vertically, C fills          16px
 ├──────┼────────┼──────┤
 │  BL  │   BE   │  BR  │   ← bottom row: corners fixed, BE tiles horizontally 16px
 └──────┴────────┴──────┘
   TL,TR,BL,BR = the four corners — drawn once, NEVER stretched.
   TE,BE,LE,RE = the four edges  — repeat/stretch along one axis only.
   C           = the centre      — the panel's fill (can be transparent).
```

Annotated rules for the artist:

- Keep the **corners** (each 16×16) self-contained: a corner should look right
  whether the panel is tiny or huge, because it is never scaled.
- Make the **edges** *tileable*: the left 16px column repeats down the side, so
  its top pixel must meet its own bottom pixel seamlessly. Same for the others.
- The **centre** is usually a flat fill (Slate `#4E4A4E` or Navy `#30346D`) or
  left transparent so the dungeon shows through.
- Name panels `<thing>_panel.png` (still, so no `_Nf`), e.g. `party_frame_panel.png`,
  `log_panel.png`, `viewport_panel.png`.

If a panel PNG is missing, the app draws a plain themed rounded box instead — so a
missing panel is invisible-but-graceful, never a crash.

---

## 6. The first ten assets (draw them in this order)

This is your prioritised worklist. Each one, dropped in, visibly improves the
main screen. Do them top to bottom; stop whenever you like — every sprite above
where you stop is already live in the app.

| # | File | Size / kind | What it is |
|---|------|-------------|------------|
| 1 | `party_frame_panel.png` | 48×48 9-slice | The frame around each party-member portrait. Ships the biggest visual win: it turns every roster card into a "character frame". |
| 2 | `adult_portrait_1f.png` | 48×48 portrait | The generic adventurer (adult) face, used until a member has a custom portrait. Friendly, front-facing. |
| 3 | `pet_portrait_1f.png` | 48×48 portrait | The generic familiar (pet) face. |
| 4 | `monster_idle_4f.png` | 32×32 ×4 strip | One category monster, idle-bobbing. The star of the floor viewport. Start `_1f` if animating is daunting. |
| 5 | `quest_monster_4f.png` | 32×32 ×4 strip | One quest boss (a savings-goal monster), a notch grander than a category monster. |
| 6 | `hp_bar_1f.png` | 32×32 9-slice-ish | The HP-bar chrome: end caps + a 1px-tileable fill segment. Draw an empty bar frame; the app tints the fill by health. |
| 7 | `log_panel.png` | 48×48 9-slice | The frame around the scrolling adventure log. |
| 8 | `coin_spin_6f.png` | 32×32 ×6 strip | A spinning gold coin — the treasure/spoils note. Yellow + Orange. |
| 9 | `trophy_1f.png` | 32×32 still | A won-quest trophy, shown when a boss is felled. |
| 10 | `homestead_stage_1.png` | 32×32 still | The first built stage of the Homestead (the war chest made visible) — "tents pitched". |

Once these ten exist, the main screen renders as real pixel art end to end.

---

## 7. The full backlog (after the first ten)

Pull from here in any order once the top ten are done. Everything remains
optional; each asset that lands upgrades one more surface from placeholder to art.

**One default monster per main category** (so the floor reads at a glance) —
32×32 idle strips:

- `monster_housing_4f.png`, `monster_food_4f.png`, `monster_transport_4f.png`,
  `monster_health_4f.png`, `monster_entertainment_4f.png`, `monster_pets_4f.png`,
  `monster_savings_4f.png`, `monster_misc_4f.png`.

**Enraged variants** (overspent monsters, drenched in Red `#D04648`) — same
sizes, `_enraged_` in the name, e.g. `monster_food_enraged_4f.png`, plus the
generic `monster_enraged_4f.png`.

**Portraits & roster:**

- `companion_portrait_1f.png` (dependent), and alternate adult/pet portraits so a
  party of many doesn't repeat one face.

**Chrome & panels:**

- `viewport_panel.png` (the central floor frame), `minimap_tile_1f.png` sets:
  `minimap_explored_1f.png`, `minimap_current_1f.png`, `minimap_locked_1f.png`
  (the little tiles in the year minimap), `writ_1f.png`, `scroll_seal_1f.png`,
  `gold_pouch_1f.png`, `war_chest_1f.png`, `reserve_cache_1f.png`, `anvil_1f.png`
  (equipment maintenance), `supplies_1f.png` (income), `contract_seal_1f.png`
  (party contracts), `ransack_1f.png`.

**Floor backgrounds** (the one place you may exceed 32×32) — a tileable dungeon
floor/wall the viewport sits on. Author a **tileable** chunk (e.g. 64×64 or
128×128) so it repeats seamlessly; still integer-scaled. `floor_bg_<theme>.png`.

**Homestead stages** (the war chest's meta-progression, 32×32 stills) — the whole
ladder: `homestead_stage_0.png` (bare clearing) through `homestead_stage_5.png`
(grand estate). Each stage should read as a clear step up from the last.

**Celebration effects** (cosmetic flourishes at wins) — short 32×32 strips:
`sparkle_burst_6f.png` (quest felled), `level_flag_4f.png` (floor cleared / ritual
done), `confetti_8f.png` (streak milestone).

---

## 8. How degradation works (why you can't break anything)

Every game surface renders at three tiers, decided **per asset, at runtime**:

1. **Full pixel art** — your PNG exists and is drawn (this guide's target look).
2. **Partial** — a *specific* sprite is missing, so *that one* falls back to a
   labelled grey placeholder card. Everything around it still renders as art.
3. **Text mode** — a first-class text-adventure presentation of the same screens,
   using the household's written character descriptions. Not an error state; the
   app is complete and fun here with no art at all.

So you never have to finish a set. Draw `monster_food_4f.png`, and the Food
monster becomes art while every other monster stays a placeholder — no code
change, no coordination, no risk. That's the whole point of this pipeline: it
lets exactly one beginner artist improve the game one file at a time.
