# Art assets — a commissioning guide

Hello, and welcome. This is your brief. You have never drawn game art before, and
that is fine — this document is written so you never have to guess. Every rule
here exists so that whatever you draw *drops straight into the app and works*,
even if you only ever finish one sprite.

**Where things stand.** LootLog ships with real, free art: three CC0 packs by
Kenney (Tiny Town, Tiny Dungeon and Roguelike Indoors, see §10) draw the town,
the rooms and the month-end dungeon, so new devices open on pixel art. Your
work *replaces or adds to* that art one key at a time: drop a PNG named after a
key (§3) and it overrides the pack's picture for that key. Nothing here is
required.

Two things to hold onto before we start:

1. **The art is a skin, never the game's brain.** LootLog is a real budgeting
   app wearing a dungeon-crawler costume. Your sprites decorate numbers the app
   already computed; they never change a single cent. Draw freely — you cannot
   break the money.
2. **Every asset is optional.** The app ships and is fun with *zero* art (each
   missing sprite falls back to a small text/ASCII card, and the whole game
   has a full text-adventure mode). So
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

## 2. Sizes — one tile, one portrait

| Purpose | Canvas | Used for |
|---------|--------|----------|
| **Base tile** | **16 × 16 px** | Everything in the town, rooms and dungeon: ground, trees, buildings, furniture, characters, monsters, chests, items. |
| **Portrait** | **48 × 48 px** | Party-member face frames only (the adventurer/companion/familiar portraits). |

Bigger things are whole multiples of the tile: a house or a bed is a
**2 × 2** or **1 × 2** block of tiles (32×32, 16×32), exactly as the Kenney
packs draw them. Draw those as one PNG of the full size. Backgrounds and
9-slice panels are the other exceptions (§5, backlog).

> **Why 16?** The bundled packs are 16×16 tile sets, so art you draw on the
> same grid sits next to them without looking out of scale. (Older notes in
> this guide said 32×32; the guild-hall and legacy dungeon files in §6–§9 that
> are already 32×32 keep working and are scaled by the same whole-number rule.)

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

- `N` = number of frames. A 4-frame strip of 16×16 tiles is **64 × 16**; the
  legacy `monster_idle_4f.png` is 4 frames of 32×32 (**128 × 32**).
- A **still** sprite uses `_1f`, e.g. `trophy_1f.png` (a single frame).
- Frames are square and equal: frame width = image width ÷ N = image height.
- You can *always* start with `_1f` and add animation later by widening the strip
  and renaming — nothing else changes.

### Asset keys — how new art is named

Every visual in the game has an **asset key**: four lower-case words joined by
dots, `category.subject.variant.state`. For example:

| Key | Means |
|-----|-------|
| `building.lumberyard.t2.idle` | the Lumberyard at tier 2, standing still |
| `chest.gold.open.idle` | an opened gold chest |
| `material.ore.icon.idle` | the ore icon |
| `region.subscription_swamp.banner.idle` | the Subscription Swamp's banner |

To ship art for a key, **name the PNG exactly after the key, plus the frame
suffix**, and drop it straight into `app/assets/game/` (not a subfolder). If the
key is also mapped in a pack (§10), your PNG wins: an artist's file overrides
the pack picture for that key.

```
building.lumberyard.t2.idle_4f.png     (a 4-frame strip)
chest.gold.open.idle_1f.png            (a still)
```

The app finds it on its own — no code change. Words inside a segment use
underscores (`subscription_swamp`); only the three separators are dots.

**You rarely need every variant.** If a key has no file, the app tries simpler
keys before giving up:

1. the same thing at `idle` (`building.forge.t3.constructing` → `building.forge.t3.idle`),
2. the `default` variant (`building.forge.t3.idle` → `building.forge.default.idle`).

So one `building.forge.default.idle_1f.png` covers every Forge tier until you
draw the tiers. If nothing on that list exists, the key shows its text card.
§9 lists every key.

The older files in §6–§7 (`monster_idle_4f.png` and friends) predate keys and
keep their names; they also answer to `dungeon.*` keys (see §9).

Custom sprites a *user* supplies (their own quest / pet / avatar art) are always
treated as a single still frame and are decoded from the user's file, but they
render through the exact same pixelated pipeline as your assets.

---

## 4. Integer-scale rule (the one technical rule)

The app **never** blurs your pixels. It draws every sprite with
`FilterQuality.none` and only ever magnifies by **whole numbers** — 2×, 3×, 4× —
never 1.5× or 2.3×. A 16×16 tile shown at 3× is exactly 48×48 crisp pixels.

What this means for you: **draw at the true 16×16 tile grid (or 48×48 for
portraits), one pixel per pixel.** Do not pre-scale, do not add anti-aliasing / soft edges, do not export at
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

> **Legacy list.** These are the original dungeon-dashboard priorities, drawn at
> 32×32. The pack art now covers the town, rooms and dungeon, so a better first
> list today is the distinctive things in §10: `hero.portrait.default.idle`
> (48×48), `building.central_hall.t1.idle`, `town.house.default.idle`,
> `boss.overbudget.default.idle`, `chest.wood.closed.idle` and
> `furniture.bed.default.idle`.

This is the original prioritised worklist. Each one, dropped in, visibly improves
the main screen. Do them top to bottom; stop whenever you like — every sprite above
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

**The OVERBUDGET** — `overbudget_idle_4f.png`, 32×32 ×4 strip. The debt
monster that appears when a month's overspending outlives the gold pouch. It
should look genuinely intimidating (the scariest silhouette in the set — think
a hulking shadow with glowing eyes), because until it falls, the category it
came from is locked. One asset covers every OVERBUDGET.

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

**The camp** (the main screen's framing scene) — `campfire_idle_4f.png`, 32×32
×4 strip: a crackling campfire the party gathers around at the top of the
Adventure home. Until it lands, a labelled placeholder slot marks its spot.

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

1. **Full pixel art** — your PNG or a pack region exists and is drawn (the
   default look).
2. **Partial** — a *specific* sprite is missing, so *that one* falls back to its
   text card (a tiny ASCII emblem with its name, e.g. a `/\` roof over
   "Lumberyard T2"); older dungeon sprites fall back to a labelled grey card.
   Everything around it still renders as art.
3. **Text mode** — a first-class text-adventure presentation of the same screens,
   using the household's written character descriptions. Not an error state; the
   app is complete and fun here with no art at all.

So you never have to finish a set. Draw `monster_food_4f.png`, and the Food
monster becomes art while every other monster stays a placeholder — no code
change, no coordination, no risk. That's the whole point of this pipeline: it
lets exactly one beginner artist improve the game one file at a time.

---

## 9. Every asset key (the guild hall and beyond)

Each key below is **individually optional**: with no file it renders as its text
card, and the moment `<key>_<N>f.png` lands in `app/assets/game/` it renders as
art. Sizes follow §2 (32×32, portraits 48×48, panels per §5). The source of truth
is `app/lib/game/assets/asset_catalog.dart`; keep this list in step with it.

**Buildings** — `building.<building>.t<1-5>.idle`, 32×32. Draw
`building.<building>.default.idle` first: it covers every tier until you draw
them. A `constructing` state (`building.forge.t3.constructing`) is optional and
falls back to `idle`.

| Building | Subject |
|----------|---------|
| Central Hall | `central_hall` |
| Scribe's Desk | `scribes_desk` |
| Storehouse | `storehouse` |
| Forge | `forge` |
| Vault | `vault` |
| Lumberyard | `lumberyard` |
| Quarry | `quarry` |
| Mine | `mine` |
| Herb Garden | `herb_garden` |
| Hunter's Lodge | `hunters_lodge` |
| Arcane Well | `arcane_well` |

**Materials** — `material.<material>.icon.idle`, 32×32: `lumber`, `stone`,
`ore`, `herbs`, `hide`, `crystal`, `essence`, `trophy`.

**Currency** — `currency.gem.icon.idle` (gems), `currency.freeze_token.icon.idle`
(streak-freeze token).

**Chests** — `chest.<chest>.closed.idle` and `chest.<chest>.open.idle`, 32×32,
for `wood`, `iron`, `gold`, `party`, `spoils`. A `chest.<chest>.default.idle`
covers both until you draw the pair.

**Regions** — `region.<region>.banner.idle`, 32×32: `market_catacombs`,
`tavern_cellars`, `old_roads`, `hearthstone_keep`, `bazaar_of_whims`,
`subscription_swamp`, `the_wilds`.

**Heroes** — `hero.portrait.default.idle` (48×48, the generic adventurer face),
`hero.caravan.default.idle` (32×32, the supply caravan a Standard-mode adult
appears as).

**Gear** — `gear.<slot>.default.idle`, optionally per tier `gear.<slot>.t<N>.idle`,
32×32. Starter slots: `weapon`, `armor`, `helm`, `trinket`.

**Bosses** — `boss.<boss>.default.idle`, 32×32 (a `defeated` state is optional).
Starter seasonal bosses: `winter`, `spring`, `summer`, `autumn`.

**UI panels** — `ui.panel.<panel>.idle`, 48×48 9-slice (§5). Draw
`ui.panel.default.idle` first; every other panel falls back to it:
`party_frame`, `log`, `viewport`, `hall_plot`, `chest`, `ritual`.

**Homestead** — `homestead.stage.s<0-5>.idle`, 32×32, stage 0 (bare clearing)
to stage 5 (grand estate).

**Dungeon (drawn today as script-generated placeholders)** — these keys point at
the §6–§7 files: `dungeon.hero.a.idle`, `dungeon.hero.b.idle`,
`dungeon.monster.default.idle`, `dungeon.monster.default.enraged`,
`dungeon.pet.default.idle`, `dungeon.quest_monster.default.idle`,
`dungeon.gold_pouch.default.idle`, `dungeon.war_chest.default.idle`,
`dungeon.reserve_cache.default.idle`, `dungeon.coin.default.idle`,
`dungeon.trophy.default.idle`, `dungeon.anvil.default.idle`,
`dungeon.contract_seal.default.idle`, `dungeon.ransack.default.idle`,
`dungeon.scroll_seal.default.idle`, `dungeon.supplies.default.idle`,
`dungeon.writ.default.idle`. Not yet drawn: `dungeon.overbudget.default.idle`,
`dungeon.campfire.default.idle`.

---

## 10. Packs, regions and the town, room and dungeon keys

### The bundled packs (all CC0)

Three sprite sheets by Kenney (kenney.nl), released under Creative Commons Zero
(public domain; credit is appreciated but not required). Each lives in
`app/assets/game/packs/<pack>/` with its `License.txt`:

| Pack | Folder | Draws |
|------|--------|-------|
| Tiny Town | `tiny_town` | The town: ground, trees, buildings, plots, the dungeon gate, townsfolk, town decorations. |
| Tiny Dungeon | `tiny_dungeon` | The month-end dungeon: floor, walls, torches, goal bosses, the OVERBUDGET, heroes, chests. |
| Roguelike Indoors | `roguelike_indoors` | The decoratable rooms: floors, walls, furniture. |

### `regions.json` — keys to sheet cells

Every pack folder holds a `regions.json` that maps asset keys to cells of its
sheet:

```json
{
  "sheet": "tilemap_packed.png",
  "cellSize": 16,
  "spacing": 0,
  "regions": {
    "town.tree.default.idle": [4, 0],
    "town.house.default.idle": [0, 6, 2, 2]
  }
}
```

- `cellSize` is the tile size in pixels (16) and `spacing` the gap between
  neighbouring tiles on the sheet (0 for Tiny Town and Tiny Dungeon, 1 for
  Roguelike Indoors).
- A region is `[column, row]` for one tile, or `[column, row, columns, rows]`
  for a block of tiles (the 2×2 house above). Columns and rows count from 0 at
  the top left.
- A malformed entry is skipped, so one typo never hides the whole pack.

To find a cell, run the grid helper. It writes a 4× copy of the sheet with every
cell labelled `column,row`:

```
cd app
dart run tool/pack_grid.dart assets/game/packs/tiny_town/tilemap_packed.png 16 0 grid.png
```

(arguments: sheet, cell size, spacing, output image). Read the labels off
`grid.png` and add or change a line in `regions.json`; no code change is
needed.

### An artist's PNG overrides the pack

Lookup for a key walks the usual fallback chain (§3). At each step a PNG named
after the key (`town.tree.default.idle_1f.png` in `app/assets/game/`) beats the
pack region for the same key, and a region beats nothing. If neither exists, the
key renders as its text card, and text tier never decodes any image.

### Key list — town (Tiny Town)

`town.ground.grass.idle`, `town.ground.path.idle`, `town.ground.water.idle`,
`town.ground.square.idle`, `town.tree.default.idle`, `town.bush.default.idle`,
`town.fence.default.idle`, `town.gate.dungeon.idle` (the month-end dungeon
gate), `town.house.default.idle` (your house), `town.wagon.default.idle` (the
supply caravan), `town.scaffold.default.idle` (a building under construction),
`town.plot.empty.idle`, `town.plot.locked.idle`.

Town decorations (placed in the town): `town_decor.flowerbed.default.idle`,
`town_decor.lamp_post.default.idle`, `town_decor.bench.default.idle`,
`town_decor.well.default.idle`, `town_decor.well.fountain.idle`,
`town_decor.statue.default.idle` (a completed goal becomes a statue).

Buildings: `building.<building>.t<1-5>.idle` for every building in §9
(Central Hall, Scribe's Desk, Storehouse, Forge, Vault, Lumberyard, Quarry,
Mine, Herb Garden, Hunter's Lodge, Arcane Well), typically 2×2 tiles.

People: `npc.villager.a.idle`, `npc.villager.b.idle`, `npc.pet.default.idle`,
`hero.body.default.idle` and the outfit bodies `hero.body.knight.idle`,
`hero.body.ranger.idle`, `hero.body.rogue.idle`, `hero.body.wizard.idle`.

### Key list — rooms (Roguelike Indoors)

Room shell: `room.floor.wood.idle`, `room.wall.default.idle`.

Furniture and decorations (each is a catalogue item, see below):
`furniture.armchair.default.idle`, `furniture.bed.default.idle`,
`furniture.bed.canopy.idle`, `furniture.bookshelf.default.idle`,
`furniture.chair.default.idle`, `furniture.clock.default.idle`,
`furniture.desk.default.idle`, `furniture.lamp.default.idle`,
`furniture.lamp.crown.idle`, `furniture.lamp.ember.idle`,
`furniture.painting.default.idle`, `furniture.painting.banner.idle`,
`furniture.plant.default.idle`, `furniture.rug.default.idle`,
`furniture.rug.dragon.idle`, `furniture.table.default.idle`,
`furniture.trophy_stand.default.idle`, `furniture.wardrobe.default.idle`.

The shop, chests and starter set draw from `app/assets/game/catalog.json`
(item id, name, rarity, price, `asset` key, footprint in tiles). To add a
decoration, add a catalogue entry and either a pack region or a key-named PNG
for its `asset` key.

### Key list — month-end dungeon (Tiny Dungeon)

`dungeon.floor.default.idle`, `dungeon.wall.default.idle`,
`dungeon.torch.default.idle`, `boss.goal.default.idle` (a savings goal as a
boss; `boss.goal.<main_category>.idle` for housing, food, transport and
entertainment), `boss.overbudget.default.idle` (the OVERBUDGET monster),
`item.weapon.default.idle` (the leftover as a weapon),
`chest.wood.closed.idle`, `chest.wood.open.idle`, `chest.gold.closed.idle`.

Goal trophies in rooms use `furniture.trophy_stand.default.idle`, and a
completed goal's town statue uses `town_decor.statue.default.idle`.

### Still keyed the old way

The guild-hall keys of §9 (materials, currency, gear, regions, panels,
homestead) and the legacy `dungeon.*` keys keep working exactly as described
there. Where a key has neither a pack region nor a file it shows its text card.
