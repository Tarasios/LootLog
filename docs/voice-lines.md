# Voice lines — the writer's guide

Every encouragement line the app speaks lives in JSON files under
`app/assets/game/text/`. They are data, not code: edit the JSON, run
`./check.sh`, and the app picks the new lines up with no code change. This
page lists every current line next to the outcome it is trying to produce, so
you can replace any of them with better writing without guessing at intent.

## How the files work

- `purchase_logged.json` is `{ "lines": [ ... ] }`; the hall and dungeon
  files hold named sets. The app picks one line from the relevant set, seeded
  so it stays stable on screen.
- `{amount}`, `{merchant}`, and `{n}` are placeholders the app fills in.
  `{amount}` and `{merchant}` are optional: when the data is missing the
  placeholder is deleted from the line, so place them mid-sentence where the
  line still reads cleanly without them.
- Every file here is Adventure-only, so game words are fine; Standard mode
  speaks plain language through the glossary instead.
- `./check.sh` must pass after any edit. `app/test/game/ui/hall_voice_test.dart`
  and `app/test/game/ui/dungeon/dungeon_voice_test.dart` guard the hall and
  dungeon files (8+ lines where required, nothing shames or blames), and
  `app/test/game/ui/logged_voice_test.dart` the logged-purchase file.

## `purchase_logged.json` — after a purchase is logged

**Trigger:** in Adventure's text tier, right after this device's adult logs a
purchase (the town's snackbar). The pixel town shows gems flying to the
person's house instead, or a "Logged!" sparkle when the daily gem cap left
the log gem-less. The town has no amount or merchant for the line, so
`{amount}` and `{merchant}` are always dropped there. Checked by
`app/test/game/ui/logged_voice_test.dart`.
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

## Checklist for new lines

1. Read it out loud once. If it sounds like a motivational poster, cut it in
   half.
2. Run the banned-word list in your head (never shame, never blame), then
   let `./check.sh` confirm.
3. Placeholders mid-sentence, never leading, so a missing value degrades
   cleanly.
4. Keep each set at 8+ lines so repeats stay rare.

## Guild hall lines (`hall_lines.json`)

Adventure-only, so game words are fine here. Every set is picked with a
seed (the event being celebrated, or the day) so a line is stable on
screen and the same on every device. `app/test/game/ui/hall_voice_test.dart`
checks each set has 8+ lines and that nothing shames or blames.

> The `ritualStep*`, `ritualMonth*`, `ritualIncomplete` and
> `bossAlreadyFought` rejection lines below belong to the retired four-step
> ritual and seasonal boss: kept because older devices' logs can still raise
> them, not shown by any current screen.

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

### Month-end dungeon entrance (`dungeonCallout`, `dungeonCalloutButton`, `dungeonPlace*`)

Single-line sets for the guild-hall text screens' way into the month-end
dungeon. Placeholders: `{month}` (e.g. "September 2026") and `{n}` (how many
months are waiting). They show only while a month's dungeon is unfinished; a
month is finished once its spoils chest has been granted. Each also has a
built-in copy of its line (`HallVoice.fallbacks`), so a button is never blank
while the file loads or if a set goes missing; change both when rewording.

| Set | Trigger | Intended outcome | Current line |
|-----|---------|------------------|--------------|
| `dungeonCallout` | The home shows the callout for the most recent unfinished month | Invite the person in; leftovers are weapons to aim, not a test | {month}: the dungeon below the town gate is open. Aim each leftover at a goal boss or an OVERBUDGET, then return for the spoils chest. |
| `dungeonCalloutButton` | The callout's button | A plain, inviting action | Enter the dungeon |
| `dungeonPlaceDone` | The "Around the hall" dungeon tile with nothing waiting | Calm: nothing is owed, and say when the next one opens | All done for now. The next one opens when the month ends. |
| `dungeonPlaceReadyOne` | The dungeon tile with one month waiting | Say what is ready, without pressure | {n} month ready for the dungeon |
| `dungeonPlaceReadyMany` | The dungeon tile with several months waiting | Same, plural | {n} months ready for the dungeon |

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

### `reasons`

Plain labels, not narrative: `reasons` names why an inbox reward or chest
was earned (by reward reason code).

| Reason code | Label shown | Trigger |
|---|---|---|
| `log.daily` | Showed up today | The first purchase logged in a day |
| `checkin.no_spend` | Checked in on a quiet day | A "no spend today" check-in |
| `log.extra` | Kept logging | Logging more purchases the same day (gems are capped daily) |
| `log.timely` | Logged it right away | Logging a purchase soon after it happened |
| `week.checkin` | A steady week | The weekly check-in chest |
| `week.reconcile` | Reconciled the week | The weekly reconcile chest |
| `week.party` | The whole party showed up | Everyone in the party logged this week (additive; never names anyone) |
| `streak.token` | Streak milestone | A streak milestone reward (freeze token or decoration) |
| `caravan.supply` | Supply caravan | A Standard-mode partner's budgeting feeding the party |
| `ritual.spoils` | Finished the month's ritual | The month-end dungeon is finished: the spoils chest |
| `ritual.bonus` | Bonus: month-end rituals on time | On-time month-end ritual bonus gems |
| `month.gold` | Bonus: a budget finished on target | A category finished the month on target (bonus only) |
| `vault.quest` | Savings goal milestone | A savings goal reaches a percent milestone |
| `vault.consistency` | Months of saving in a row | Consecutive months with a savings choice |


## Month-end dungeon lines (`dungeon_lines.json`)

Adventure-only: shown in the month-end dungeon below the town gate, where
each category's leftover is a weapon aimed at a goal boss, an OVERBUDGET or
savings. Every amount in a line is the real split, computed by the ledger
and filled in by the screen; the lines only frame it. Picks are seeded by
the category and month so a line is stable on screen. Placeholders:
`{name}` (the category), `{amount}` (a money amount), `{target}` (a goal or
the category carrying an OVERBUDGET), `{gems}` and `{months}` (the bonus).
`app/test/game/ui/dungeon/dungeon_voice_test.dart` checks every set is
present and that nothing shames or blames.

| Set | Trigger | Intended outcome | Current line(s) |
|-----|---------|------------------|-----------------|
| `gateOpen` | The dungeon opens with a month-end ritual waiting | Invite: last month's leftovers are something to use, not a test | The dungeon gate stands open. Last month's leftovers are yours to wield. |
| `gateClosed` | The gate is tapped while no ritual is waiting | Explain when it opens and that logging now fills the next one | The gate is sealed until the month turns. Keep logging — every coin you don't spend becomes a weapon. |
| `upkeep` | The entrance step: recording what variable bills came to | Calm bookkeeping before the fun; differences never punish | The gatekeeper tallies the upkeep before you descend. |
| `weaponReady` | A category's leftover is the next weapon | Make the leftover feel like a reward to aim | {name} gleams with {amount}. Where will you strike? |
| `hitGoal` | A leftover lands on a savings goal | Celebrate progress toward the goal | {amount} lands on {target}! <br> {target} staggers — {amount} closer! |
| `hitDebt` | A leftover strikes an OVERBUDGET | Paying it down is a win, never a scolding | {amount} strikes the OVERBUDGET on {target}! |
| `taxFlies` | Part of a move goes to the war chest on the way | Show the cut plainly, as the party's shared fund growing | {amount} flies to the war chest. |
| `bank` | A leftover goes to the person's own savings | Saving for later is a fine choice | {amount} goes into your pouch for later. |
| `carry` | A leftover stays in its category | Keeping it for next month is a fine choice | {amount} stays with {name} for next month. |
| `bossFalls` | A goal is fully funded | The big celebration: the goal is reached | {target} falls! The goal is yours. |
| `victory` | Every weapon has been used | Wrap up warmly before returning to town | The party climbs back to town with the spoils. |
| `noLeftovers` | No category had anything left over | Reassure: an exactly-spent month is a month that worked | Nothing left over this month — and that's fine. Every budget did its job. |
| `chestWaiting` | Return to town: the spoils chest was granted | Point at the reward waiting in the inbox | A spoils chest waits in your inbox. |
| `bonusOnTime` | The chest came with bonus gems and at least one on-time ritual in a row | Celebrate consistency (a count of months, never dollars) | Bonus: {gems} gems. On-time month-end streak: {months}. |
| `bonusGear` | Bonus gems with no on-time streak (the hero's gear alone) | Name the bonus without implying a streak that isn't there | Bonus: {gems} gems, thanks to your hero's gear. |
| `dividedNoChest` | Return to town on a device with no game service yet | Confirm the leftovers are divided | Your leftovers are divided. |
| `headBack` | Button when nothing was left over | A calm way out, no judgement | Head back to town |
| `saveFailed` | The ledger write failed (nothing was divided) | Reassure and invite a retry, no blame | The spoils couldn't be saved just now. Nothing is lost, so please try again. |
| `chestPending` | The leftovers were saved but the chest failed to arrive | Say plainly the money is done, and invite a retry now (no promise it happens on its own) | Your leftovers are divided and saved. The spoils chest got stuck at the gate; try again now to bring it home. |
| `nothingToDivide` | The dungeon opens for a finished month with nothing left to divide in the ledger (all spent, past the grace period, or divided in the ledger). Placeholder `{month}` | The chest never depends on leftovers: celebrate finishing the month either way | Nothing left to divide for {month} — the party returns with the spoils. |
| `returnPending` | That month's chest failed to arrive | Invite a retry, no blame | The spoils chest got stuck at the gate. Try again now to bring it home. |
