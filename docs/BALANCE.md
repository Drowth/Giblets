# Giblets — Balance Model (Phase 2)

All symbols: `m` = elapsed minutes, `L` = player level. Every formula below is
implemented as a named constant or function; the constant name is given in
`code`. First-pass values here were then tuned by `scripts/BalanceSim.gd`
(Phase 4) — this document records the **final tuned values** and the reasoning.

Design targets:

- A run should last **12–20 minutes** for most players; very few deaths before
  minute 5; almost no runs stall past minute 25.
- **25–30 levels** across a 20-minute run, fast early (level 2 within ~20 s),
  slowing to ~1 level/min by the end.
- Boss dies in **15–25 s** of focused fire from an on-curve build; an off-curve
  build gets overrun while whittling it.

---

## 1. Player DPS budget

The anchor everything else is tuned against. Base kit: 15 damage × 1.5 shots/s
= **22.5 DPS at minute 0** (`GameState` base stats).

Per level the player picks 1 of 3 upgrades. With the rarity weights of §5 the
expected pick is worth ≈ **+22 % of current power**, of which ≈ 55 % of picks
are offensive. Expected DPS multiplier per level ≈ 1.12. With the level curve
of §2 (L(m) below) that compounds to the **target DPS curve**:

```
dps_target(m) = 30 · (1 + 0.16·m)²          # GameState.dps_target()
```

| minute | 1 | 5 | 10 | 15 | 20 |
|---|---|---|---|---|---|
| target DPS | 40 | 97 | 203 | 350 | 537 |
| sanity check: 22.5 · 1.12^L(m) | 35 (L4) | 79 (L11) | 216 (L17)* | 380 (L22)* | 470 (L27)* |

\* multishot/pierce/sentries add area DPS on top of single-target — the check
row is single-target only, which is why it sits slightly under the target at
the end. Close enough to anchor enemy HP.

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

base_xp: spider 8, demon 20, wraith 25, cyclops 60, imp 14, bonecharger 30
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
| Demon | 25 | 55 (140) | 10 | 20 | baseline chaser |
| Wraith | 15 | 80 (165) | 8 | 25 | fast luner, drift |
| Cyclops | 75 | 28 (90) | 12 | 60 | tank wall |
| Imp (new) | 12 | 70 (130) | 7 (bolt) | 14 | ranged pressure |
| Bone Charger (new) | 35 | 40 (100) | 18 | 30 | telegraphed charge + death burst |

Worked example, Demon: HP 25 → 130 (m10) → 295 (m20). Against the DPS budget
that is 0.6 s → 0.55 s of single-target focus — near constant — but arrival
*rate* triples, so total incoming HP/s crosses the player's kill capacity
around minute 12–14.

**Mix schedule** (`Main._spawn_one`): spiders 50 %→0 over the first 2 min;
wraiths ramp 0→50 % over minutes 0.5–1.5; imps ramp to 20 % from minute 2;
cyclops ramp to 25 % from minute 1; bone chargers ramp to 15 % from minute 4;
remainder demons.

**Post-20 death ramp** (`OVERTIME_START = 20 min`, `OVERTIME_QUAD = 0.25`):

```
overtime_mult(m) = 1 + 0.25·max(0, m−20)²        # multiplies enemy HP and dmg
```

+25 % at 21 min, ×2 at 22, ×5 at 24, ×10 at 26. Runs end. This is deliberately
a wall, not a slope — the fantasy is "I finally got overwhelmed", not "the
numbers quietly got unfair".

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

Two bosses alternate on the 60 s `BossTimer` (§Phase 3c): **Skull King**
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

Full pool (32 entries, four archetypes: **crit/burst**, **area**, **summons**,
**sustain**). P shows the score that placed each in its band.

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
| multishot_1 | Twin Barrage | rare | +1 projectile | 35 |
| pierce_1 | Impale | rare | +1 pierce | 30 |
| knockback_1 | Soul Repel | rare | +220 knockback | 26 |
| dash_dist_1 | Ghost Step | rare | +35 % dash distance | 26 |
| damage_mul_1 | Heavy Calibre | rare | +35 % damage (multiplicative) | 35 |
| crit_2 | Executioner | rare | +12 % crit chance | 30 |
| lifesteal_1 | Vampiric Strikes | rare | heal 1 HP per kill | 28 |
| sentry_1 | Osseous Sentinel | epic | summon a Bone Sentry (max 3) | 45 |
| dash_knock_1 | Shockwave | epic | dash knockback ×2 | 42 |
| multishot_2 | Overload | epic | +2 projectiles | 60 |
| fire_rate_3 | Adrenaline | epic | +50 % fire rate | 45 |
| max_hp_3 | Titan's Vigor | epic | +80 max HP, +2 armor | 44 |
| leg_crit | Deathmark | legendary | +25 % crit, crits ×3 | 85 |
| leg_aoe | Hellfire Rounds | legendary | hits explode: 60 % dmg, r=70 | 90 |
| leg_summon | Bone Legion | legendary | +2 sentries, sentries full dmg | 80 |
| leg_sustain | Gorefeast | legendary | heal 3 HP/kill, +25 % move spd | 75 |

Stacking caps (`max_stacks` in the dict): sentries cap at 3 (+2 more from Bone
Legion), armor at 8, crit chance at 60 %, projectile count at 8, pierce at 6.
Repeatables (damage, fire rate, HP…) are uncapped — their marginal value
naturally decays.

Sentry damage = 50 % of player damage (100 % with Bone Legion), firing at
player fire rate: one sentry ≈ +50 % single-target DPS, which is why the epic
costs a level *and* an orbit slot and stays fair at P≈45.

---

## 6. Meta-progression (kept modest by design)

Currency: **Giblets** (icon already in `assets/pickups/giblet.png`), earned
1 per 400 score at death (`GIBLETS_PER_SCORE`). Unlocks are permanent, small,
and *additive to base stats only* — they shift the first two minutes, not the
curve: +10 max HP (×3 ranks), +1 damage (×3), +5 % move speed (×2), +10 %
magnet (×2), +5 % XP (×2). Full board ≈ one free early level-up per category;
total cost ≈ 25 good runs. Persisted in `user://meta.save` beside HighScores.

## 7. Hit-stop and juice budget (why numbers, not vibes)

Old: 35 ms global freeze per projectile *hit* — at 6 hits/s that is 21 % of
wall-clock spent frozen. New: hit-stop **only on kills** (25 ms) and boss
deaths (80 ms), with a 150 ms cooldown (`HITSTOP_COOLDOWN`) so multishot
volleys read as one impact. Screen shake: 4 px on hit stays (it is camera-only,
costs nothing), 70 px boss death, 40 px bomb.
