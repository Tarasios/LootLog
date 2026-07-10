# Gemini prompts for placeholder-quality art

Companion to `art-assets.md`. AI generators cannot reliably output true 32×32 PNGs
on an exact 16-color palette, so the workflow is: generate BIG, then post-process.

## Post-processing every image (do this once per output)

1. Crop to a square around the subject.
2. Downscale to the target grid (32×32 or 48×48) with **nearest-neighbor**.
3. Quantize to the DB16 palette (Aseprite: Sprite → Color Mode → Indexed with a
   loaded DB16 palette; or any "apply palette" tool).
4. Erase the background to full transparency; save as plain PNG with the exact
   filename from `art-assets.md`.
5. For animation strips: generate each frame as its own image with the frame
   note appended, then lay frames left-to-right in one strip PNG.

## Shared style preamble (paste at the start of EVERY prompt)

> Retro 16-color pixel art in the DawnBringer 16 palette (#140C1C black outlines,
> #442434, #30346D, #4E4A4E, #854C30, #346524, #D04648 red, #757161, #597DCE,
> #D27D2C orange, #8595A1, #6DAA2C, #D2AA99, #6DC2CA, #DAD45E yellow, #DEEED6),
> hard pixel edges, no anti-aliasing, no gradients, flat shading with darker
> palette swatches, single centered subject on a plain solid magenta background,
> SNES-era dungeon-crawler sprite style, drawn as if on a 32x32 pixel grid.

(For portraits say "48x48 pixel grid" instead. The magenta background makes
step 4 trivial.)

## The first ten

1. **party_frame_panel.png** — "…an ornate square dungeon UI frame border, empty
   transparent center, carved stone and dark wood with brass corner rivets, each
   corner decoration self-contained in the outer 1/3 of each side, edges plain
   and repeatable, drawn as a 48x48 UI 9-slice panel."
2. **adult_portrait_1f.png** — "…a friendly front-facing fantasy adventurer bust
   portrait, simple hood and tunic, warm confident smile, gender-neutral, head
   and shoulders filling the frame, 48x48 pixel grid."
3. **pet_portrait_1f.png** — "…a cute front-facing animal familiar bust portrait,
   round eyes, could read as cat or small beast, head filling the frame, 48x48
   pixel grid."
4. **monster_idle_4f.png** — 4 prompts, same base: "…a small round goofy dungeon
   slime-imp monster, stubby arms, mischievous but not scary, full body." Append
   per frame: "frame 1 of a 4-frame idle bob: standing neutral" / "frame 2:
   squashed slightly down" / "frame 3: standing neutral" / "frame 4: stretched
   slightly up".
5. **quest_monster_4f.png** — same technique: "…a grander armored ogre-knight
   boss monster with a banner on its back, imposing but cartoonish, full body,"
   with the same 4-frame bob suffixes.
6. **hp_bar_1f.png** — "…an empty horizontal health bar frame with decorated
   metal end caps and a plain 1-pixel-tileable middle section, no fill inside,
   dungeon UI chrome style."
7. **log_panel.png** — "…a parchment-and-wood rectangular UI panel border for a
   scrolling text log, quill-and-scroll corner motif, empty center, drawn as a
   48x48 UI 9-slice panel."
8. **coin_spin_6f.png** — 6 prompts: "…a single gold coin with an embossed
   dragon head, yellow #DAD45E with orange #D27D2C shading, frame N of a 6-frame
   spin: coin rotated {0|30|60|90|120|150} degrees around its vertical axis"
   (frame 4, 90°, is the edge-on sliver).
9. **trophy_1f.png** — "…a gleaming golden trophy cup on a small stone base,
   yellow and orange treasure tones, one white sparkle glint."
10. **homestead_stage_1.png** — "…a tiny campsite in a forest clearing: one
    pitched canvas tent, a small campfire, a log, seen from a 3/4 top-down RPG
    overworld angle."

## High-value backlog prompts

- **overbudget_idle_4f.png** — "…a hulking shadow demon debt-collector monster,
  near-black #140C1C silhouette with glowing red #D04648 eyes and cracks of red
  light, chains around its wrists, the most intimidating silhouette in the set,
  full body," + the 4-frame bob suffixes.
- **monster_food_4f.png** — "…a round gluttonous pantry-mimic monster made of a
  picnic basket with teeth, a sausage tongue," + bob suffixes. (Clone this
  pattern for housing = brick golem with a door mouth; transport = wheeled
  cart-beast; health = potion-bottle sprite; entertainment = jester imp with a
  lute; pets = ball-of-yarn beast; savings = piggy-bank golem; misc = mystery
  crate mimic.)
- **Enraged variants** — reuse the matching monster prompt + "enraged variant:
  drenched in red #D04648, furious eyes, steam bursts, aggressive pose."
- **gold_pouch_1f.png** — "…a plump drawstring leather coin pouch overflowing
  with gold coins."
- **war_chest_1f.png** — "…a heavy iron-banded treasure war chest, closed, with
  a proud brass lock."
- **reserve_cache_1f.png** — "…a small hidden supply cache: a crate with a
  rolled blanket and a stashed lantern."
- **anvil_1f.png** — "…a blacksmith anvil with a hammer resting on it."
- **supplies_1f.png** — "…an adventurer's supply bundle: bedroll, rope, and a
  full satchel."
- **writ_1f.png** — "…an official parchment writ with a wax seal and a quill."
- **ransack_1f.png** — "…a burst-open treasure chest with coins scattering and
  a torn lock."
- **floor_bg_stone.png** — drop the "single centered subject" clause: "…a
  seamlessly tileable dark dungeon stone floor texture, subtle cracked flagstone
  pattern in #4E4A4E and #140C1C, no objects, tileable in all directions, 64x64
  pixel grid."
- **Campfire home scene (future homepage)** — "…a cozy dungeon-entrance camp at
  dusk: a crackling campfire with a log bench beside it, a tent behind, the dark
  dungeon doorway in the background, no characters (they are composited from
  sprites), wide 128x64 pixel grid scene, tileable sky." Plus per-member idle
  strips reusing the adult portrait character: "…full-body version of the hooded
  adventurer sitting on a log, frame N of 2: hands toward the fire / hands on
  knees."

## Tips

- Generate 4+ candidates per prompt and pick the one whose silhouette survives
  the downscale; detail vanishes at 32×32 — silhouette is everything.
- If Gemini ignores the palette, don't fight it in the prompt; the quantize step
  fixes color exactly.
- Keep every monster's feet on the same baseline so the floor lineup reads well.
