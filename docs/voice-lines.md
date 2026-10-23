# Voice lines — the writer's guide

Every encouragement line the app speaks lives in JSON files under
`app/assets/game/text/`. They are data, not code: edit the JSON, run
`./check.sh`, and the app picks the new lines up with no code change. This
page lists every current line next to the outcome it is trying to produce, so
you can replace any of them with better writing without guessing at intent.

## How the files work

- Each file is `{ "lines": [ ... ] }` (streaks use tiers, see below). The app
  picks one line at random from the relevant set each time.
- `{amount}`, `{merchant}`, and `{n}` are placeholders the app fills in.
  `{amount}` and `{merchant}` are optional: when the data is missing the
  placeholder is deleted from the line, so place them mid-sentence where the
  line still reads cleanly without them.
- Lines are shown in BOTH Classic and Adventure mode, so avoid vocabulary
  that only works in one (no "tithe", "war chest", or "floor" here; the
  glossary handles mode-specific wording elsewhere).
- `app/test/game/narrative_test.dart` guards the rules below; `./check.sh`
  must pass after any edit.

## 1. `purchase_logged.json` — after a purchase is logged

**Trigger:** immediately after any purchase is recorded.
**Intended outcome:** a tiny hit of acknowledgment that makes logging feel
quick and worth doing again tomorrow. Fast to read (one glance), warm, and
proud of the *habit* rather than the spending itself. Never comment on
whether the purchase was wise.

| Current line |
|---|
| Logged. The streak lives on. |
| Recorded {amount} in a blink. On you go. |
| Noted {merchant} before the receipt hit your pocket. |
| In the book. Small entries, honest totals. |
| Logged {amount} clean and quick. |
| Done. Ten seconds now, a clear picture later. |
| Tracked. Nothing slips past you. |
| Got it. Future-you keeps the benefit. |
| Counted {amount} toward the month. Steady as ever. |
| On the record. Showing up is the whole skill. |

## 2. `overspend_support.json` — a budget is over its limit

**Trigger:** shown when a budget has gone past its monthly limit (the monster
is enraged on screen; these words are what the person reads).
**Intended outcome:** the user keeps logging honestly instead of hiding or
quitting. Acknowledge plainly, protect their dignity, and point at the next
concrete step (the month wrap-up). HARD RULE: never shame. The test rejects
these words outright: failed, failure, bad, shame, guilt, irresponsible,
wasted, should have, stupid, lazy, never.

| Current line |
|---|
| Over the limit here. It happens in every honest budget, and this is an honest budget. |
| This one ran hot. You caught it, you logged it, and that is the hard part handled. |
| The limit slipped past. Writing it down anyway was exactly the right move. |
| A rough month for this budget. The plan is still standing, and so are you. |
| You spent more than planned, and every cent of it is on the record. That is the whole job, done right. |
| Past the line, and nothing is on fire. Settle it at the month wrap-up and keep going. |
| Budgets bend in real life. Yours bent where you could see it, which is the version you can fix. |
| Over budget this month. Next month opens with a clean page and a smarter plan. |
| The numbers got away from you a little. They are still your numbers, and you are still the one holding the pen. |

## 3. `ritual_celebrations.json` — the month wrap-up is confirmed

**Trigger:** once, when the user confirms the monthly leftover division.
**Intended outcome:** the wrap-up feels like a finish line worth returning to
every month. Congratulate the *completed decision*, gesture at the goals
moving, and land on forward momentum. This is the biggest moment in the app's
loop, so these can be a touch grander than the purchase lines.

| Current line |
|---|
| Month closed, and every coin knows where it lives. Well done. |
| Wrapped, settled, squared away. See you next month. |
| You closed the month on your terms. That is the whole game, played well. |
| Leftovers divided, plans carried forward. A clean finish. |
| Another month settled with intention. It adds up, and you get to watch it add up. |
| All decided. The goals inch closer and the plan rolls on. |
| Closed out and counted. Take the moment, you earned it. |
| That is a wrap. Next month starts with a clear board and a better map. |

## 4. `streak_celebrations.json` — consecutive days logged

**Trigger:** when a purchase extends a run of consecutive logging days. The
app picks the highest tier whose `minDays` the streak reaches, then a random
line from it; `{n}` is the day count.
**Intended outcome:** each tier should feel meaningfully bigger than the
last. Tier 1 plants the habit ("come back tomorrow"), tier 2 names it a
routine, tier 3 hands the habit over to them as an identity, tier 4 is pure
legend. Add tiers freely (e.g. 365) — keep `minDays` ascending.

| Tier (minDays) | Current lines |
|---|---|
| 2 | Two days running. This is how it starts. |
| 2 | {n} in a row. Come back tomorrow and keep it alive. |
| 2 | {n}-day streak. Showing up is the skill, and you just showed up. |
| 7 | A full week, every day logged. That is a routine now. |
| 7 | Seven straight days. Steady hands. |
| 7 | {n} days without a gap. The ledger is lucky to have you. |
| 30 | A whole month of showing up. The habit belongs to you now. |
| 30 | {n} straight days. At this point the streak keeps you. |
| 30 | Thirty days of small entries and steady resolve. Remarkable. |
| 100 | {n} days. Triple digits. Legendary is the correct word. |
| 100 | One hundred days of showing up. Few ever get here, and you did. |
| 100 | {n}-day streak. Whatever you are guarding, it is well guarded. |

## 5. `camp_ambience.json` — the campfire scene-setter

**Trigger:** shown once a day (seeded by the date, so it doesn't flicker
between rebuilds) at the top of the Adventure camp screen, under "The Camp".
**Intended outcome:** the dashboard opens like a game, not a report — a
single line of scene-setting that rewards coming back daily (a new line each
day). Adventure-only, so game vocabulary (floors, war chest, HP, quest
bosses) is welcome here — this file is the exception to the both-modes rule.
Keep every line cozy and safe: the camp is the app's home screen, so no
tension, no urgency, nothing that reads as a warning.

| Current line |
|---|
| The fire crackles. Somewhere below, a monster counts its hoard. |
| Sparks drift toward the stars. The ledger sleeps under a bedroll. |
| The kettle whistles over the coals. The dungeon can wait a moment. |
| A quiet night at camp. The war chest sits heavy and content. |
| The party trades tales of monsters felled and coin well spent. |
| An owl calls. The next floor's monsters shuffle in their sleep. |
| The campfire pops. Fresh supplies are stacked and counted twice. |
| Boots dry by the fire. Tomorrow's delve is planned over stew. |
| The banner flutters. Every pouch is exactly where its owner left it. |
| Embers rise. Far below, a quest boss grumbles about its dwindling HP. |

## Checklist for new lines

1. Read it out loud once. If it sounds like a motivational poster, cut it in
   half.
2. Overspend lines: run the banned-word list in your head, then let
   `./check.sh` confirm.
3. Placeholders mid-sentence, never leading, so a missing value degrades
   cleanly.
4. Keep each set at 8+ lines so repeats stay rare.

## Month-end encounter lines (`encounter_lines.json`)

Shown once per monster in the floor-cleared walkthrough before dividing the
spoils. Placeholders: `{name}` `{spent}` `{leftover}` `{limit}` `{over}`.

| Group | Trigger | Intended outcome |
|-------|---------|------------------|
| `flawless` | Category with a limit and zero spend | Celebrate that NOT spending is the strongest win |
| `victory` | Spent under the limit | Frame leftover as effort saved, feeding the spoils |
| `exact` | Spent exactly the limit | Neutral, satisfied close — no shame, no reward inflation |
| `enraged` | Spent over the limit | Supportive, forward-looking; never blames |

## Guild hall lines (`hall_lines.json`)

Adventure-only, so game words are fine here. Every set is picked with a
seed (the event being celebrated, or the day) so a line is stable on
screen and the same on every device. `app/test/game/ui/hall_voice_test.dart`
checks each set has 8+ lines, that nothing shames or blames, and that every
losing boss line still promises the spoils.

### `greetings`

**Trigger:** Opening the guild hall (one line per day).  
**Intended outcome:** Set the scene and welcome the person back; make showing up feel like part of the adventure.

| Current line |
|---|
| The hall lamps are lit. Every honest entry keeps them burning. |
| Smoke curls from the chimneys. The guild is open for business. |
| The banner snaps in the wind. Today's ledger awaits its scribe. |
| Hammers ring in the yard. Small entries build big halls. |
| A quiet morning in the hall. The scribe's quill is already inked. |
| The hearth is warm and the doors are open. Welcome back, adventurer. |
| Carts rattle through the gate. The guild grows a little every day you show up. |
| Lanterns glow over the plots. What will the hall become next? |

### `noSpendDone`

**Trigger:** After a "No spend today" check-in.  
**Intended outcome:** Make an honest quiet day feel as worthwhile as a logged purchase (rule 5).

| Current line |
|---|
| Nothing spent, and you said so. Today counts. |
| A quiet day on the books, honestly marked. The streak holds. |
| No coin left the pouch today. The scribe notes it with a nod. |
| Checked in. Showing up on a quiet day is still showing up. |
| Today is covered. Rest easy, adventurer. |
| A blank page, signed and dated. That is good bookkeeping. |
| The day is marked. The guild remembers who keeps the ledger honest. |
| Nothing to log, and you logged that. Well kept. |

### `reconcileDone`

**Trigger:** After the weekly reconcile is marked done.  
**Intended outcome:** Reward the care of checking the books; hint at the iron chest.

| Current line |
|---|
| The week is reconciled. The iron chest is on its way. |
| Every entry checked against the receipts. A tidy week. |
| Books balanced for the week. The quartermaster salutes you. |
| Reconciled. Nothing hides in this ledger. |
| The week's accounts are squared. Onward. |
| Checked, matched, done. That is a week well kept. |
| Another week settled with care. The guild grows stronger for it. |
| The scribe closes the week's pages with a satisfied stamp. |

### `chestOpened`

**Trigger:** Headline of the chest-opening celebration; `{chest}`.  
**Intended outcome:** Anticipation and a small thrill; the rolled contents follow underneath.

| Current line |
|---|
| The lid creaks open... |
| Treasure! The {chest} gives up its hoard. |
| A gleam inside the {chest}! |
| Hinges groan, gems glitter. |
| You pry open the {chest}. A fine find. |
| The {chest} was heavier than it looked. |
| Loot spills across the table. |
| The guild gathers round as the {chest} opens. |

### `rewardClaimed`

**Trigger:** Snackbar after claiming a reward (or all of them).  
**Intended outcome:** A quick, satisfied acknowledgment.

| Current line |
|---|
| Added to the pouch. |
| Claimed and counted. |
| Into the coffers it goes. |
| Earned fair and square. |
| The quartermaster logs your haul. |
| Yours now. Well earned. |
| A fine addition to the stores. |
| Pocketed with a grin. |

### `buildStarted`

**Trigger:** A new building is started; `{building}`.  
**Intended outcome:** Progress you can see; the hall is growing.

| Current line |
|---|
| Foundations laid for the {building}. |
| The builders get to work on the {building}. |
| Scaffolding rises around the {building}. |
| The {building} takes shape. |
| Stone by stone, the {building} grows. |
| The {building} breaks ground. |
| Plans unrolled, the {building} begins. |
| The yard bustles: a {building} is going up. |

### `upgradeStarted`

**Trigger:** A building upgrade is started; `{building}` `{tier}`.  
**Intended outcome:** Same, for upgrades.

| Current line |
|---|
| The {building} is being raised to tier {tier}. |
| Builders swarm the {building}. Tier {tier} is coming. |
| New beams for the {building}: tier {tier} under way. |
| The {building} grows taller. Tier {tier} on the way. |
| Hammers ring at the {building}. Tier {tier} soon. |
| The {building} is getting a makeover to tier {tier}. |
| The {building} expands toward tier {tier}. |
| Fresh mortar for the {building}. Tier {tier} is near. |

### `collected`

**Trigger:** Materials collected from a producer; `{building}`.  
**Intended outcome:** Small tactile satisfaction; never tied to logging (rule 10).

| Current line |
|---|
| The carts roll into the storehouse. |
| Stacked, counted and stored. |
| A fine haul from the {building}. |
| The {building} delivers. |
| Fresh materials for the party pool. |
| The yard is cleared and the stores are fuller. |
| Collected. The {building} hums back to work. |
| Hauled in from the {building}. |

### `expeditionSent`

**Trigger:** The hero sets out; `{region}`.  
**Intended outcome:** Send-off energy; the hero will come back with something.

| Current line |
|---|
| The hero sets out for {region}. |
| Boots laced, map folded: off to {region}. |
| The gate swings open. {region} awaits. |
| Into {region} the hero goes. |
| A wave from the walls as the hero heads for {region}. |
| Pack full of rations, the hero marches toward {region}. |
| The road to {region} calls. The hero answers. |
| Adventure awaits in {region}. |

### `ritualStepDone`

**Trigger:** A spoils-ritual step is marked done.  
**Intended outcome:** Momentum toward the boss; each step matters.

| Current line |
|---|
| One more rune lit on the ritual circle. |
| Step done. The spoils draw closer. |
| The ritual hums a little brighter. |
| Marked. The seasonal beast stirs. |
| A careful step, well taken. |
| The circle glows. Onward to the next step. |
| The month's pages settle into place. |
| Done. The boss can sense you coming. |

### `bossIntro`

**Trigger:** The seasonal boss fight opens; `{boss}`.  
**Intended outcome:** Drama and stakes, all of it on the monster.

| Current line |
|---|
| {boss} rises from the month's shadows! |
| The ritual is complete. {boss} answers the call! |
| The ground trembles. {boss} has arrived. |
| {boss} blocks the way to the spoils. Steel yourself! |
| A roar shakes the hall. It is {boss}! |
| The circle flares and {boss} steps through. |
| {boss} has come to test the guild. |
| Out of the season's storm strides {boss}. |

### `bossTurns`

**Trigger:** One per revealed turn of the fight; `{boss}`.  
**Intended outcome:** Pacing; reinforce that gear and a well-logged month help.

| Current line |
|---|
| The hero strikes true! |
| A clash of steel and claw. |
| The hero dodges and counters. |
| Gear gleams as the hero presses on. |
| A well-logged month lends the hero strength. |
| {boss} reels from the blow. |
| The hero finds an opening. |
| Sparks fly as the hero lands a hit. |

### `bossWin`

**Trigger:** The boss falls; `{boss}`.  
**Intended outcome:** Triumph; a trophy for the mantel.

| Current line |
|---|
| {boss} falls! A trophy for the mantel. |
| Victory! {boss} is felled and the spoils are yours. |
| {boss} is vanquished. The guild cheers. |
| The beast is down. The month is won. |
| {boss} crumbles. Raise the banners! |
| A clean victory over {boss}. Glory to the guild. |
| {boss} is defeated. Another month conquered. |
| The hall will sing of the fall of {boss}. |

### `bossLoss`

**Trigger:** The boss slips away; `{boss}`.  
**Intended outcome:** Supportive, never a punishment: every line says the spoils chest is still earned (a test checks).

| Current line |
|---|
| {boss} retreats into the mist. The spoils are yours all the same. |
| {boss} lives to fight another season, but the ritual is done and the chest is earned. |
| A hard fight. {boss} slips away, and the spoils chest arrives anyway. |
| {boss} withdraws, wounded. Your ritual earned the spoils regardless. |
| The beast escapes this time. The month's work still earns the spoils in full. |
| {boss} limps off. Better gear next month, and the chest is yours now. |
| No trophy today, but the ritual was the real victory. Open your chest. |
| {boss} holds the field for now. The spoils chest is already on its way. |

### `spoilsChest`

**Trigger:** Closing line of every boss fight.  
**Intended outcome:** Point at the spoils chest waiting in the inbox.

| Current line |
|---|
| The spoils chest awaits in your inbox. |
| A spoils chest arrives at the hall. |
| The month's spoils are packed and delivered. |
| Your spoils chest is ready to open. |
| The quartermaster sets a spoils chest at your feet. |
| A spoils chest, earned by the ritual. |
| Spoils delivered. Go see what's inside. |
| The ritual's reward is waiting in the inbox. |

### `caravan`

**Trigger:** Under a Standard-mode partner in the party header.  
**Intended outcome:** Celebrate the supply caravan's support; never name or blame anyone for not playing (rule 7).

| Current line |
|---|
| The supply caravan keeps the party's stores stocked. |
| Supply carts roll in, courtesy of the caravan. |
| The caravan backs the party from the road. |
| Wagons of lumber and stone, sent by the caravan. |
| The caravan keeps the hall supplied. |
| The caravan's wheels never stop turning. |
| Fresh supplies from the caravan reach the yard. |
| The caravan is the backbone of the party's stores. |

### `rejections`

**Trigger:** a hall action that can't happen yet (a button's gate, or a
refused command), keyed by `GameRejection`.  
**Intended outcome:** say plainly what's missing and how to get it, in an
encouraging voice. Gem shortfalls point back at logging; material
shortfalls at buildings and expeditions.

| Rejection | Line |
|---|---|
| `notEnoughGems` | A few more gems needed. They come from logging, so every entry brings this closer. |
| `notEnoughMaterials` | The stores are a little short. Collect from your buildings or send the hero on an expedition. |
| `invalidPlot` | That plot isn't part of the hall. |
| `plotAlreadyUnlocked` | That plot is already open. |
| `plotLocked` | Unlock this plot first. |
| `plotOccupied` | Another building already stands here. |
| `buildingAlreadyInHall` | The hall already has one of these. Each building gets one plot. |
| `underConstruction` | The builders are still at work. It'll be ready soon. |
| `maxTierReached` | This is already at its finest. Nothing left to add. |
| `needsCentralHall` | Raise the Central Hall first. It sets how high everything else can go. |
| `noBuilding` | Nothing stands here yet. |
| `notAProducer` | This building doesn't produce materials. |
| `nothingToCollect` | Nothing ready yet. Check back in a little while. |
| `storehouseFull` | The Storehouse is full. Spend some materials or upgrade the Storehouse to make room. |
| `unknownChest` | That chest has already been opened. |
| `catalogNotReady` | The chest is still being unpacked. Give it a moment and try again. |
| `unknownReward` | That reward has already been claimed. |
| `unknownGearSlot` | That gear slot doesn't exist. |
| `unknownGearType` | That slot doesn't take that kind of gear. |
| `needsForge` | The Forge needs to be built or upgraded first. |
| `invalidCustomization` | Keep it short and not blank. |
| `noChange` | Your hero already looks like that. |
| `regionLocked` | This region opens as the Central Hall grows. |
| `expeditionActive` | The hero is already out on the road. |
| `noActiveExpedition` | The hero is home. |
| `expeditionNotFinished` | The hero is still travelling. Not long now. |
| `ritualMonthNotClosed` | The month isn't over yet. The ritual opens once it ends. |
| `ritualMonthExpired` | That month's ritual has closed. A fresh one opens every month. |
| `ritualStepDone` | That step is already done. |
| `ritualStepOutOfOrder` | Take the steps in order. One at a time. |
| `ritualIncomplete` | Finish all four ritual steps to summon the boss. |
| `bossAlreadyFought` | This month's boss has already been faced. |
| `ritualAlreadyFinished` | This month's spoils are already home. |
| `alreadyInParty` | Already in the party. |
| `notInParty` | Not in the party right now. |
| `unknownItem` | That item isn't in the catalogue. |
| `notInShopToday` | That one has left the shop. A new set arrives tomorrow. |
| `itemNotOwned` | You don't have a spare one of those yet. The shop or a chest might. |
| `cellOccupied` | Something's already there. Try a free spot. |
| `outOfBounds` | That doesn't quite fit there. Try a spot with a bit more room. |
| `wrongSpace` | That one belongs somewhere else. Rooms take furniture, the town takes garden pieces and statues. |
| `unknownPlacement` | That piece isn't on display any more. |
| `notYourRoom` | This is someone else's room. Yours is waiting for you. |
| `notEquippable` | Only outfits and titles can be worn. |
| `starterAlreadyClaimed` | Your starter set is already home. |

### `reasons` and `bossNames`

Plain labels, not narrative: `reasons` names why an inbox reward or chest
was earned (by reward reason code), and `bossNames` names each seasonal
boss key.

## Month-end dungeon lines (`dungeon_lines.json`)

Adventure-only: shown in the month-end dungeon below the town gate, where
each category's leftover is a weapon aimed at a goal boss, an OVERBUDGET or
savings. Every amount in a line is the real split, computed by the ledger
and filled in by the screen; the lines only frame it. Picks are seeded by
the category and month so a line is stable on screen. Placeholders:
`{name}` (the category), `{amount}` (a money amount), `{target}` (a goal or
the category carrying an OVERBUDGET).
`app/test/game/ui/dungeon/dungeon_voice_test.dart` checks every set is
present and that nothing shames or blames.

| Set | Trigger | Intended outcome |
|-----|---------|------------------|
| `gateOpen` | The dungeon opens with a month-end ritual waiting | Invite: last month's leftovers are something to use, not a test |
| `gateClosed` | The gate is tapped while no ritual is waiting | Explain when it opens and that logging now fills the next one |
| `upkeep` | The entrance step: recording what variable bills came to | Calm bookkeeping before the fun; differences never punish |
| `weaponReady` | A category's leftover is the next weapon | Make the leftover feel like a reward to aim |
| `hitGoal` | A leftover lands on a savings goal | Celebrate progress toward the goal |
| `hitDebt` | A leftover strikes an OVERBUDGET | Paying it down is a win, never a scolding |
| `taxFlies` | Part of a move goes to the war chest on the way | Show the cut plainly, as the party's shared fund growing |
| `bank` | A leftover goes to the person's own savings | Saving for later is a fine choice |
| `carry` | A leftover stays in its category | Keeping it for next month is a fine choice |
| `bossFalls` | A goal is fully funded | The big celebration: the goal is reached |
| `victory` | Every weapon has been used | Wrap up warmly before returning to town |
| `noLeftovers` | No category had anything left over | Reassure: an exactly-spent month is a month that worked |
