# Giblets — Design Rationale

Every balance decision here has a number behind it in `docs/BALANCE.md`. This
document records *why* those numbers are what they are, so future changes have
a rationale to argue with instead of vibes.

## Core fantasy

Twenty minutes from "one demon is a threat" to "I am a walking meat grinder —
and it is still not enough." The run must end because the *player* ran out of
curve, not because they got bored or because a spike felt arbitrary.

## Progression

**XP curve is quadratic, not exponential.** The original ×1.4/level curve
meant level 19→20 alone cost 33k XP while income grew linearly — every run
plateaued at L12–15 and the level-up dopamine loop died mid-run. Quadratic
(`30 + 45k + 22k²`) keeps late levels arriving at roughly one per minute.
If levels feel too fast late, raise `XP_QUAD` before touching anything else.

**Enemy XP scales at 0.12/min, not 0.40/min.** At 0.40 the XP value of kills
grew faster than the requirement curve, so levels *accelerated* late — the
opposite of a difficulty curve. 0.12 makes late levels come from kill volume,
which the horde caps, which is what makes minute 15+ feel earned.

**Boss XP is level-derived (90 % of a level), not flat.** Flat 500 XP was 16
levels at minute 1 and irrelevant at minute 15. Deriving from
`xp_to_next_level` makes every boss kill worth the same *feeling* all run.

## Difficulty

**`dps_target(m)` is used only to size boss HP, not enemy HP.** Player DPS
compounds exponentially (upgrades stack multiplicatively), so BalanceSim
showed a median build's actual horde DPS running 4–20× above any quadratic
anchor by minute 15–20. Sizing regular-enemy HP off that budget would make
individual enemies unkillable-feeling early or trivial late. Instead, regular
enemy HP scales on its own curve (`HP_SCALE_LIN`, `HP_SCALE_QUAD`) tuned
directly against the death-time distribution: difficulty comes from arrival
*rate* and HP growth outpacing typical DPS growth by minute 12+, not from
sizing every enemy against a hypothetical "ideal" player. Move the curve by
changing `WAVE_SIZE_GROWTH` or `HP_SCALE_*` and re-running BalanceSim — don't
hand-tune individual enemy stats without checking the death-time histogram.

**Enemy speed is capped below sprint speed.** A demon that outruns the player
converts every mistake into an unavoidable death spiral. Caps (90–165 px/s vs
player 200+) mean positioning always matters but is never hopeless. The Wraith's
lunge and the Bone Charger's charge are the *sanctioned* speed violations —
both telegraphed, both dodgeable.

**The overtime ramp is a wall, not a slope** (`(m−18)²` on HP and damage:
×3.4 at 20 min, ×9.4 at 22, ×20 at 24). A slope quietly turns unfair; a wall
reads as "the game is telling me this run is over, take the score". BalanceSim
(100 runs, mid-skill pick model) confirms: 0 survive past minute 25, median
death at 17.1 minutes, with the death-time distribution peaking at 16–20
minutes — the wall does its job without needing to start at exactly minute 20.

**Live enemy cap = 130.** Above that, CharacterBody2D physics cost and visual
noise both degrade; below ~100 the late game loses its wall-of-meat feel.
Spawning simply pauses at the cap — kills make room, which conveniently makes
kill-rate the late-game XP throttle.

## Bosses

Boss HP = 20 s × `dps_target(m)` × 0.85 (focus leak). This *guarantees* the
15–25 s TTK window for an on-curve build at any minute, because the target is
defined in terms of the same curve upgrades are tuned against. An off-curve
player doesn't lose to the boss's HP — they lose to the horde that keeps
spawning during a 40 s+ fight. That is deliberate: the boss is a DPS check,
the horde is the executioner.

Two bosses alternate to break pattern memory: the Skull King chases (a kiting
check), the Butcher orbits and charges (a repositioning check). The Butcher
trades 20 % HP for its charge because dodging the charge costs the player
~20 % fire uptime.

**Fire bombs chunk bosses for 25 % max HP instead of instakilling.** A boss
drops a bomb; if bombs instakilled bosses, each boss trivialised the next.
25 % keeps the bomb a meaningful boss-fight tool without collapsing the check.

## Upgrades

**Rarity is derived from measured power** (docs/BALANCE.md §5 table): each
upgrade got a power score in %-of-current-power terms, and score bands assign
rarity; selection weights (45/30/15/7/3) then price rarity into the draw. The
expected value of one pick ≈ +22 % power — that constant is what makes
`dps_target` and therefore enemy HP and boss HP hang together. If you add an
upgrade, score it and let the band place it; never hand-assign rarity.

**Four archetypes, each with a legendary capstone**: crit (Keen Edge →
Executioner → Deathmark), area (multishot/pierce → Hellfire Rounds), summons
(Sentinel ×3 → Bone Legion), sustain (Regrowth/Vampiric → Gorefeast).
Legendaries at weight 3 appear ~0.9 times per 27-level run on average —
build-defining when they land, not a plan you can rely on.

**Stack caps** exist only where marginal value doesn't naturally decay
(sentries: orbit slots; crit: 60 % cap so the build converges; projectiles: 8
for perf and screen readability). Flat +damage/+HP repeatables are uncapped
because their marginal value halves on its own.

**Sentries deal 50 % player damage** (100 % with Bone Legion): one epic pick
≈ +50 % single-target DPS, in line with the epic band (P≈45), and the orbit
radius means they often shoot the *wrong* target — the gap Bone Legion closes.

## Meta-progression

Deliberately modest: full board ≈ one early level-up per category, ~25 good
runs to complete. It exists to (a) give bad runs a consolation reward and
(b) let weaker players self-serve a small handicap. It must never trivialise
a run — that's why unlocks are additive to *base* stats (which multipliers
then scale from a barely-higher floor) and why there is no meta unlock for
fire rate, projectile count, or anything else on the DPS multiplier path
except +1 flat damage ×3.

Giblets at 1 per 400 score ≈ 3–8 per early run, 25–60 per good run — a full
unlock (`cost × rank`) is always 2+ runs away, so the shop stays a slow drip.

## Juice

**Hit-stop is kill-gated with a 150 ms cooldown.** The old per-hit 35 ms
global freeze consumed >20 % of wall-clock at 6 hits/s and made multishot
feel *worse* (more hits = more stutter). Kills at 25 ms and boss deaths at
80 ms reserve the freeze for moments that mean something; the cooldown makes
a multishot volley read as one impact.

**Damage numbers use a single-`_draw()` pool** (like BloodSmears): 48-entry
FIFO, no per-number nodes. Crits render gold and double-size — the crit
build's feedback loop is the numbers themselves.

**Combo counter** (2 s window, shown from 5+) exists to make the mid-run
horde-mulching phase legible, with a small score bonus (+2 %/step, capped ×2)
so it's felt but never the optimal-play driver.

## Architectural choices made under ambiguity

- **GameState stays the single authority for gameplay stats**; Settings owns
  display/audio persistence and Meta owns cross-run persistence. Meta feeds
  base stats into `GameState._reset()` — GameState remains the only writer of
  in-run values.
- **New enemies copy the Enemy death/XP pattern** rather than extracting an
  EnemyBase class. Three copies existed before this pass; a refactor would
  have touched every enemy while rebalancing them simultaneously. Accepted
  the fourth/fifth copy; extraction is a clean future change once balance
  settles.
- **BalanceSim runs inside the engine with real autoloads** (a scene, not a
  `--script`), so the XP curve, upgrade weighting, and stack caps in the sim
  are the *shipping code*, not a parallel model. Only combat is analytic.
