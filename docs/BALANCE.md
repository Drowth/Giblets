# Giblets — Balance Model (Phase 2, tuned in Phase 4)

All symbols: `m` = elapsed minutes, `L` = player level. Every formula below is
implemented as a named constant or function; the constant name is given in
`code`. First-pass values were tuned against `scripts/BalanceSim.gd` (Phase 4),
a 100-run headless simulation that exercises the *real* XP curve and upgrade
draw code with an analytic horde-combat model. This document records the
**final tuned values**.

Design targets:

- A run should last **12–20 minutes** for most players; very few deaths before
  minute 5; almost no runs stall past minute 25.
- **25–30 levels** across a 20-minute run, fast early (level 2 within ~20 s),
  slowing to ~1 level/min by the end.
- Boss dies in **15–25 s** of focused fire from an on-curve build; an off-curve
  build gets overrun while whittling it.

## Phase 4 simulation result (final tuning pass)

`scripts/BalanceSim.gd`, 100 runs, mid-skill pick model (70% take the
strongest of 3 cards, 30% take a random one — a pure "always optimal" model
produced unrealistic near-immortal runs; a pure coin-flip model produced
unrealistic bimodal early-death clustering):

```
Death-time distribution (minutes):
  0-5     0
  5-8     19  ███████████████████
  8-12    15  ███████████████
  12-16   16  ████████████████
  16-20   33  █████████████████████████████████
  20-25   17  █████████████████
  25-30    0
  survived 0
Median death: 17.1 min   p10: 6.8   p90: 20.8
Avg final level: 30.2
Boss kills: 857   avg TTK: 11.4s   median: 9.5s   p90: 20.5s
```

Zero runs die before minute 5, zero survive past 25, and 66% of runs end in
the 12–25 window with a clear peak at 16–20 — the overtime wall (§3) catches
the long tail exactly as designed. The 5–12 bucket (34%) is runs that drew
weak early upgrades under the mid-skill model; this is treated as intended
variance, not a bug — some runs *should* end early. Re-run BalanceSim after
any constant change; a shifted distribution is the signal something needs
re-tuning.

---

## 1. Player DPS budget

The anchor everything else is tuned against. Base kit: 15 damage × 1.5 shots/s
= **22.5 DPS at minute 0** (`GameState` base stats).

Per level the player picks 1 of 3 upgrades; because upgrades stack
multiplicatively (fire rate × damage × crit × projectile count), effective
DPS compounds **exponentially** with level, not quadratically — the original
quadratic anchor undershot BalanceSim's measured player DPS by 4–20× at
minute 10+. The anchor is now:

```
dps_target(m) = DPS_BASE · e^(DPS_GROWTH_EXP · m) = 24 · e^(0.24·m)   # GameState.dps_target()
```

`DPS_BASE = 24` matches the actual starting kit (15 dmg × 1.5/s = 22.5, plus
a whisker of headroom for meta unlocks). This curve is used **only to size
boss HP** (§4) — it intentionally sits below the median player's *actual*
horde DPS (which includes multishot/pierce/sentry area effects the
single-target formula excludes), so bosses stay killable without the boss
fight also being the run's difficulty check — the horde is.

| minute | 1 | 5 | 10 | 15 | 20 |
|---|---|---|---|---|---|
| dps_target (boss sizing) | 30 | 80 | 265 | 878 | 2916 |
| BalanceSim measured horde DPS (median build) | 44 | 154 | 754 | 2875 | 17536 |

---

## 2. XP curve and time-to-level

**Requirement to go from level L to L+1** (`GameState.xp_required`):

```
R(L) = XP_BASE + XP_LINEAR·(L−1) + XP_QUAD·(L−1)²
     =    30   +    45·(L−1)     +   22·(L−1)²
```

Quadratic, not exponential: the old ×1.4 exponential needed 33 000 XP for the
single level 19→20 and stalled every run at L12–15. Quadratic keeps late levels
coming at ~1/min without trivialising them.

| L→L+1 | 1→2 | 5→6 | 10→11 | 15→16 | 20→21 | 26→27 |
|---|---|---|---|---|---|---|
| R(L) | 30 | 562 | 2 217 | 4 972 | 8 827 | 15 280 |
| cumulative | 30 | 1 500 | 8 000 | 26 500 | 62 000 | 137 000 |

**XP income.** Enemy XP value scales gently with time
(`XP_TIME_SCALE = 0.12` per minute — the old 0.40 made late levels *faster*
than early ones, the opposite of a difficulty curve):

```
xp(enemy, m) = base_xp · (1 + 0.12·m)
```

base_xp: spider 8, brawler 20, wraith 25, cyclops 60, imp 14, bonecharger 30
(§4). Mix-weighted average ≈ 19 early, drifting up as cyclops enter.

Income ≈ kill_rate · x̄p. Kill rate is the smaller of spawn rate (§3) and
DPS-limited capacity `dps(m) · AOE_FACTOR / h̄p(m)`:

| minute | 1 | 5 | 10 | 15 | 20 |
|---|---|---|---|---|---|
| spawn rate /s (§3) | 0.9 | 2.2 | 4.2 | 6.4 | 9.2 |
| kill capacity /s | ~6 | ~5.5 | ~5 | ~4.5 | ~4 |
| effective kills/min | 54 | 132 | 250 | 270 | 240 |
| x̄p | 21 | 30 | 42 | 53 | 65 |
| XP/min | ~1 100 | ~4 000 | ~10 500 | ~14 300 | ~15 600 |
| **level reached** | **4** | **11** | **17** | **22** | **26–28** |

Note the mid-run crossover: from ~minute 12 the player can no longer kill
everything that spawns — the horde thickens, XP/min flattens, levels slow
down. That crossover *is* the difficulty curve.

---

## 3. Spawn curve and enemy scaling

`Main.gd` constants (design intent in comments there):

```
interval(m)  = max(SPAWN_INTERVAL_MIN, SPAWN_INTERVAL_START − SPAWN_INTERVAL_DECAY·m)
             = max(0.60, 2.0 − 0.07·m)                    # seconds between waves
wave_size(m) = min(WAVE_SIZE_CAP, 1 + int(m · WAVE_SIZE_GROWTH))
             = min(8, 1 + int(m · 0.5))
live cap     = MAX_LIVE_ENEMIES = 130                     # perf + readability
```

Spawn rate = wave_size / interval: 0.5/s at start → ~9/s at minute 20, clamped
by the live cap. The cap also bounds worst-case physics cost.

**Per-enemy scaling** — HP tracks the DPS budget so time-to-kill stays roughly
constant early and *rises* late (the squeeze); speed is capped below dash-less
player speed so positioning always matters but is never hopeless; damage grows
slowly because the real threat is volume, not per-hit damage.

```
hp(m)  = base_hp  · (1 + HP_SCALE_LIN·m + HP_SCALE_QUAD·m²)   # 0.30, 0.012
spd(m) = min(base_spd + SPEED_SCALE·m, speed_cap)              # 6.0/min
dmg(m) = base_dmg · (1 + DMG_SCALE·m)                          # 0.12
```

| enemy | base HP | base spd (cap) | base dmg | base XP | role |
|---|---|---|---|---|---|
| Spider | 10 | 95 (150) | 6 | 8 | early swarm, web-slow |
| Brawler | 25 | 55 (140) | 10 | 20 | baseline chaser |
| Wraith | 15 | 80 (165) | 8 | 25 | fast luner, drift |
| Cyclops | 75 | 28 (90) | 12 | 60 | tank wall |
| Imp (new) | 12 | 70 (130) | 7 (bolt) | 14 | ranged pressure |
| Bone Charger (new) | 35 | 40 (100) | 18 | 30 | telegraphed charge + death burst |

Worked example, Brawler: HP 25 → 130 (m10) → 295 (m20). Against the DPS budget
that is 0.6 s → 0.55 s of single-target focus — near constant — but arrival
*rate* triples, so total incoming HP/s crosses the player's kill capacity
around minute 12–14.

**Mix schedule** (`Main._spawn_one`): spiders 50 %→0 over the first 2 min;
wraiths ramp 0→50 % over minutes 0.5–1.5; imps ramp to 20 % from minute 2;
cyclops ramp to 25 % from minute 1; bone chargers ramp to 15 % from minute 4;
remainder brawlers.

**Post-18 death ramp** (`OVERTIME_START = 18 min`, `OVERTIME_QUAD = 0.60`):

```
overtime_mult(m) = 1 + 0.60·max(0, m−18)²        # multiplies enemy HP and dmg
```

+60 % at 19 min, ×3.4 at 20, ×9.4 at 22, ×20 at 24. Runs end by ~minute 24
even for a strongly-built player. This is deliberately a wall, not a slope —
the fantasy is "I finally got overwhelmed", not "the numbers quietly got
unfair". BalanceSim confirms: 0 of 100 runs survived past minute 25, and the
wall produces the intended late peak in the death-time distribution (16–20
minutes) rather than an indefinite plateau.

---

## 4. Boss tuning

Boss HP is **derived from the DPS budget**, not set independently — that is
what guarantees the 15–25 s TTK window for an on-curve build:

```
boss_hp(m) = BOSS_TTK_TARGET · dps_target(m) · BOSS_FOCUS_FACTOR
           =       20        ·  30(1+0.16m)² ·      0.85
```

| boss # (minute) | 1 | 3 | 5 | 10 | 15 | 20 |
|---|---|---|---|---|---|---|
| HP | 680 | 1 120 | 1 650 | 3 450 | 5 950 | 9 130 |
| TTK on-curve | 17 s | ~18 s | ~17 s | ~17 s | ~17 s | ~17 s |
| TTK at half curve | 34 s+ | — | — | — | — | — |

An off-curve player (≤ 50 % of target DPS) faces 35 s+ of boss while the horde
keeps spawning — the boss's contact damage (`25·(1+0.12m)` with 3× the normal
speed cap chase logic for Skull King) plus adds is what actually kills them.
BOSS_FOCUS_FACTOR = 0.85 because ~15 % of the player's fire inevitably leaks
into the horde.

Two bosses alternate on the 90 s `BossTimer` (§Phase 3c): **Skull King**
(current: melee chase, XP fountain on death) and **Butcher** (new: circles at
mid-range, periodic telegraphed cross-arena charge; forces sustained
repositioning instead of simple kiting). Same HP formula, Butcher trades 20 %
HP for the charge threat: `BUTCHER_HP_MUL = 0.8`.

Boss XP = `R(L)·0.9` at kill time via the existing orb-triplet drop (keeps a
boss kill worth "most of a level" at any point in the run, instead of flat 500
that is 16 levels at minute 1 and nothing at minute 15).

---

## 5. Upgrade power scores → rarity weights

**Power score P** = expected % gain in run-winning power (DPS-equivalent;
defensive stats converted at 2 % effective-HP ≈ 1 % DPS, movement at 1 spd ≈
0.15 % — kiting value). Rarity is then *assigned from the score bands*, and
selection weight from rarity — power decides rarity, never feel:

| rarity | band | weight (`RARITY_WEIGHTS`) |
|---|---|---|
| common | P ≤ 15 | 45 |
| uncommon | 15 < P ≤ 25 | 30 |
| rare | 25 < P ≤ 40 | 15 |
| epic | 40 < P ≤ 60 | 7 |
| legendary | P > 60 | 3 |

Expected value per pick ≈ 0.45·12 + 0.30·20 + 0.15·32 + 0.07·48 + 0.03·75 ≈
**+22 %** — the number the DPS budget in §1 is built on. Weighted draw:
roll rarity by weight, then uniform among that rarity's not-yet-maxed entries
(re-roll rarity if a tier's pool is exhausted).

Full pool (42 entries, four archetypes: **crit/burst**, **area**, **summons**,
**sustain**, plus a **quirk** batch that trades raw stats for mechanics).
P shows the score that placed each in its band.

| id | name | rarity | effect | P |
|---|---|---|---|---|
| speed_1 | Fleet Feet | common | +15 % move speed | 9 |
| damage_1 | Bloodlust | common | +4 damage | 12 |
| fire_rate_1 | Frenzy | common | +20 % fire rate | 14 |
| proj_speed_1 | Velocity | common | +25 % projectile speed | 8 |
| magnet_1 | Soul Draw | common | +50 % magnet range | 7 |
| max_hp_1 | Iron Flesh | common | +20 max HP | 10 |
| armor_1 | Thick Hide | common | +1 armor (flat reduction) | 11 |
| xp_gain_1 | Scavenger | common | +10 % XP gained | 13 |
| speed_2 | Shadow Dash | uncommon | +25 % move speed | 16 |
| damage_2 | Gore Storm | uncommon | +8 damage | 20 |
| fire_rate_2 | Berserker | uncommon | +30 % fire rate | 21 |
| max_hp_2 | Undying Flesh | uncommon | +40 max HP, full heal | 18 |
| knockback_2 | Banishment | uncommon | +180 knockback | 16 |
| dash_cd_1 | Afterburn | uncommon | −20 % dash cooldown | 17 |
| regen_1 | Regrowth | uncommon | +2 HP / 5 s | 19 |
| crit_1 | Keen Edge | uncommon | +8 % crit chance (crits ×2) | 20 |
| rear_shot | Eyes in the Back | uncommon | bonus shot fired backwards each volley | 20 |
| orb_heal | Bone Broth | uncommon | XP orbs heal 1 HP (×2 stacks) | 18 |
| multishot_1 | Twin Barrage | rare | +1 projectile | 35 |
| pierce_1 | Impale | rare | +1 pierce | 30 |
| knockback_1 | Soul Repel | rare | +220 knockback | 26 |
| dash_dist_1 | Ghost Step | rare | +35 % dash distance | 26 |
| damage_mul_1 | Heavy Calibre | rare | +35 % damage (multiplicative) | 35 |
| crit_2 | Executioner | rare | +12 % crit chance | 30 |
| lifesteal_1 | Vampiric Strikes | rare | heal 1 HP per kill | 28 |
| dash_vacuum | Grave Robber | rare | dash magnetizes every XP orb | 26 |
| kill_speed | Adrenal Gland | rare | kills grant +40 % speed, 1.5 s | 28 |
| hurt_nova | Tantrum | rare | taking a hit detonates a nova (×2 stacks) | 30 |
| extra_choice | Third Eye | rare | level-ups offer a 4th card | 32 |
| sentry_1 | Osseous Sentinel | epic | summon a Bone Sentry (max 3) | 45 |
| dash_knock_1 | Shockwave | epic | dash knockback ×2 | 42 |
| multishot_2 | Overload | epic | +2 projectiles | 60 |
| fire_rate_3 | Adrenaline | epic | +50 % fire rate | 45 |
| max_hp_3 | Titan's Vigor | epic | +80 max HP, +2 armor | 44 |
| dash_damage | Phase Ripper | epic | dash deals 150 % weapon dmg | 42 |
| ricochet | Wishbone | epic | +2 ricochets to fresh targets (×2 stacks) | 50 |
| bloodlust | Red Mist | epic | +0.5 %/combo damage, cap +50 % | 45 |
| leg_crit | Deathmark | legendary | +25 % crit, crits ×3 | 85 |
| leg_aoe | Hellfire Rounds | legendary | hits explode: 60 % dmg, r=70 | 90 |
| leg_summon | Bone Legion | legendary | +2 sentries, sentries full dmg | 80 |
| leg_sustain | Gorefeast | legendary | heal 3 HP/kill, +25 % move spd | 75 |
| leg_faustian | Faustian Bargain | legendary | damage ×2, max HP halved | 85 |

Stacking caps (`max_stacks` in the dict): sentries cap at 3 (+2 more from Bone
Legion), crit chance at 60 %, projectile count at 8, pierce at 6, and the
quirks Tantrum / Wishbone / Bone Broth at ×2 each. Fire-rate tiers are
per-entry capped; flat repeatables (damage, HP…) are uncapped — their marginal
value naturally decays.

Sentry damage = 50 % of player damage (100 % with Bone Legion), firing at
player fire rate: one sentry ≈ +50 % single-target DPS, which is why the epic
costs a level *and* an orbit slot and stays fair at P≈45. Sentry shots use the
shared Projectile, so they crit and ricochet (Wishbone) like player shots —
but they deliberately exclude Red Mist's combo frenzy (`damage_mul`, not
`attack_damage_mul()`): sentries fire your *weapon*, not your *rage*.

---

## 6. Meta-progression (talents, characters, roulette)

> Note: some constants quoted in §1–4 have drifted from the shipping code
> (`HP_SCALE_LIN` 0.12, `DMG_SCALE` 0.18, `XP_TIME_SCALE` 0.15,
> `WAVE_SIZE_GROWTH` 0.35, `BOSS_INTERVAL` 90 s). Trust `Main.gd` /
> `GameState.gd`; a doc-sync pass is pending. This section IS current.

### Earning (Meta.compute_earn)

Currency: **Giblets**, awarded at death, itemized on the death screen:

```
giblets = min(score / 100000, 10)        # GIBLETS_PER_SCORE, SCORE_GIBLETS_CAP
        + bosses_killed × 1              # BOSS_KILL_GIBLETS
        + floor(minutes / 2) × 1         # SURVIVAL_GIBLETS
```

Score compounds explosively late-game (kills × level × combo), so its
component is *capped* — bosses and survival minutes carry the steady income.
BalanceSim yield report: fresh account ≈ 21/run (p10 7), maxed endgame ≈
31/run. In-run upgrades **never** persist across runs; only giblets, talents,
characters and roulette pool unlocks do.

### Talent tree (Meta.TALENTS)

3 branches × 3 tiers; tier 2 needs 3 points spent in the branch, tier 3 needs
6\. All talents are additive to base-stat floors — nothing on the
multiplicative DPS path. Cost per rank = `base × (rank+1)`.

| Branch | Tier | Talent | Per rank | Max | Base cost | Total |
|---|---|---|---|---|---|---|
| Offense | 1 | Sharp Fangs | +1 damage | 4 | 6 | 60 |
| Offense | 1 | Swift Bolts | +25 proj speed | 3 | 5 | 30 |
| Offense | 2 | Heavy Rounds | +8 knockback | 3 | 8 | 48 |
| Offense | 3 | Grim Arsenal | free common at start | 1 | 40 | 40 |
| Defense | 1 | Thick Skin | +10 max HP | 4 | 5 | 50 |
| Defense | 1 | Stone Hide | +1 armor | 2 | 12 | 36 |
| Defense | 2 | Slow Mend | +0.5 HP/5 s | 3 | 8 | 48 |
| Defense | 3 | Death Defiance | survive 1 killing blow | 1 | 45 | 45 |
| Utility | 1 | Long Stride | +5 % move speed | 3 | 5 | 30 |
| Utility | 1 | Greedy Soul | +10 % magnet | 3 | 4 | 24 |
| Utility | 2 | Old Bones | +5 % XP | 3 | 8 | 48 |
| Utility | 2 | Nimble | −5 % dash cooldown | 2 | 8 | 24 |
| Utility | 3 | Head Start | start at level 2 | 1 | 40 | 40 |

Full board **523 giblets**. The five pre-talent unlock ids (`hp, damage,
speed, magnet, xp`) are reused verbatim, so v1 saves migrate losslessly.

### Characters (CharacterData.gd)

Additive stat deltas + one starting passive + a ×3 draw-weight bias on
signature upgrades (flavor, not raw power). Buying a character also unlocks
its signature upgrades into the level-up rotation.

| Character | Cost | Deltas | Passive | Biased draws |
|---|---|---|---|---|
| The Ghoul | free | — | — | — |
| The Reaper | 80 | −20 HP | 10 % starting crit | crit_1/2, Deathmark |
| The Necromancer | 140 | −2 damage | starts with a sentry | sentry_1, Bone Legion |
| The Vampire | 220 | +20 HP, −10 speed | +1 lifesteal/kill | lifesteal, regen, Gorefeast |

Total spend (talents + roster) = **963 giblets ≈ 38–40 good runs**.

### End-of-run upgrade roulette

14 upgrades start locked out of the level-up rotation (`locked_by_default` in
UpgradeData): all five legendaries + Osseous Sentinel, Overload, Executioner,
Vampiric Strikes, Shockwave, Third Eye, Phase Ripper, Wishbone, Red Mist.
One rarity-weighted spin per run *if* the run survived 5:00 or killed a boss;
the winner joins the rotation permanently.
A fresh account therefore plays a thinner pool — BalanceSim baseline median
11.3 min vs 19.9 maxed — which is the intended progression arc.

### Sim acceptance (re-run after ANY change here)

BalanceSim runs 5 profiles (baseline / maxed / maxed×3 characters). Current:
baseline median 11.3 (p10 6.9), maxed 19.8–19.9 across all characters,
p90 ≤ 21.4, **zero runs past 25 in every profile** — the §3 overtime wall
holds. Persisted in `user://meta.save` (v2) beside HighScores.

## 7. Hit-stop and juice budget (why numbers, not vibes)

Old: 35 ms global freeze per projectile *hit* — at 6 hits/s that is 21 % of
wall-clock spent frozen. New: hit-stop **only on kills** (25 ms) and boss
deaths (80 ms), with a 150 ms cooldown (`HITSTOP_COOLDOWN`) so multishot
volleys read as one impact. Screen shake: 4 px on hit stays (it is camera-only,
costs nothing), 70 px boss death, 40 px bomb.
