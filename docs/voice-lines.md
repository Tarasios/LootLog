# Voice lines — the writer's guide

Every encouragement line the app speaks lives in four JSON files under
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
