# lib/game/config/

Tunable numbers for the guild-hall layer. Every balance number (gem caps,
chest contents, build timers, production rates) lives in `balance.dart` here
and nowhere else. Each table carries a doc comment saying what it is for.

`balance.dart` holds:

- **Reward engine** — daily pouch, per-day gem cap, weekly chests, streak
  tokens, the caravan, lookback.
- **Chests** — gems range and freeze-token chance per chest type. Chests are
  earned by budgeting, so they carry gems and tokens only, never materials.
- **Plots** — 3 starting plots, 11 at most (one per building type), gem price
  per further plot.
- **Buildings** — max tier 5; build timers t1 instant / t2 1h / t3 4h /
  t4–t5 12h; cost = the building's `upgradeBase` × the tier multiplier plus
  gems from tier 3; Lumberyard, Quarry, Central Hall and Scribe's Desk are
  free at tier 1 (bootstrap, and the ledger is never gated); hourly
  production per producer and tier; Storehouse capacity by tier (caps the
  pool and each collection); the Central Hall's tier caps everything else.
- **Gear** — three slots (weapon, armor, trinket) with their gear types,
  per-tier costs; gear never outranks the Forge.
- **Expeditions** — the seven themed regions with duration, the Central Hall
  tier that opens them, and loot lines; loot bonus per gear tier.
- **Ritual and boss** — how many closed months a ritual stays open; one boss
  per season with HP and a per-month climb; the fight's damage terms; what a
  win adds (a trophy; the spoils chest comes win or lose).
- **Month-end and Vault** — lookback months, the gold chest's minimum logged
  days, quest milestone percentages and consecutive-saving-month marks.

`narration.dart` holds the game-voice lines commands store in events
(expedition reports). They are not numbers, but they are content, kept beside
the tables so writers can edit them without touching logic.
