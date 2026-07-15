# Giblets — Gap Analysis (Phase 1)

Audit date: 2026-07-15. Every script in `scripts/`, `ui/`, and `shaders/` was read.
Gaps ranked by impact on player experience: **P0** (breaks or stalls a run),
**P1** (missing table-stakes for a shippable roguelite), **P2** (polish/robustness).

## What already exists (more than CLAUDE.md admits)

- Full loop skeleton: MainMenu → Main → death → name entry → leaderboard → restart/menu.
- Main menu with start / high scores / options / scrolling credits (`scripts/MainMenu.gd`).
- In-game Esc menu (`ui/OptionsScreen.gd`) — CRT toggles + resume only.
- Four enemy archetypes: Demon, Wraith (lunge), Spider (web-slow projectile — ranged debuff),
  Cyclops (tanky reskin of Enemy), plus a repeating 60 s boss (scaled Enemy).
- Hit-stop (`GameState.hitstop`), screen shake (`shake_requested` → Player camera),
  dash with knockback shockwave, bone sentry companion, blood smears/trail, CRT shader.
- High-score persistence (top 10, `user://highscores.save`).

## P0 — Breaks or stalls a run

1. **No rarity weighting at all.** `UpgradeData.get_random_choices()` is
   `pool.shuffle(); slice(0,3)` — an epic is exactly as likely as a common. Rarity is
   currently pure cosmetics. The legendary tier has a colour but **zero legendary
   upgrades exist**.
2. **XP curve stalls.** `xp_to_next_level *= 1.4` from a base of 40. Level 20 needs
   ≈ 33k XP for that single level; total XP to 25 ≈ 325k. Income (orb value × kill
   rate) grows roughly linearly. Runs plateau around level 12–15 and levels stop —
   the core dopamine loop dies exactly when the game should peak.
3. **Unbounded spawn count.** Wave size `1 + elapsed/18` with a 0.35 s floor interval
   ⇒ ~190 spawns/sec at minute 20. No live-enemy cap. Perf collapse before design
   collapse. Conversely there is **no difficulty end-state** — a strong build stalls
   forever (score keeps ticking, nothing can kill you).
4. **InputMap events duplicate on every restart.** `Main._setup_inputs()` calls
   `InputMap.action_add_event` unconditionally in `_ready()`; each
   `reload_current_scene()` appends another copy of WASD/Space to the actions.
   Harmless today, but breaks any future rebinding UI and grows without bound.
5. **Per-hit hit-stop is global and constant.** Every projectile hit freezes
   `Engine.time_scale` for 35 ms. At late-game fire rates (5–10 shots/s × multishot)
   the game spends >30 % of wall time frozen. Hit-stop must be reserved for kills
   and gated by a cooldown.

## P1 — Missing table-stakes

6. **No settings persistence.** `crt_enabled` lives in GameState and resets every
   launch. No master/music/SFX volume, no fullscreen toggle, no screen-shake toggle.
   Needs `user://settings.cfg` via ConfigFile and a Settings autoload.
7. **Pause menu is not a pause menu.** Esc opens CRT options; there is no
   Resume / Restart / Quit-to-menu.
8. **Run summary is thin.** Death screen shows score/level/kills/time but no DPS,
   no kills-per-minute, no explicit "NEW HIGH SCORE — rank N" moment.
9. **No meta-progression.** Nothing persists between runs except the leaderboard.
   (Asset `assets/pickups/giblet.png` is unused — obvious currency icon.)
10. **Boss variety = 1.** Same scaled Demon every 60 s, same behaviour. No second
    pattern, no alternation. Boss also dies instantly to a carried fire bomb
    (`fire_kill()` ignores boss status and drops no XP).
11. **Enemy roster lacks pressure types.** Spider slows but nothing *forces
    movement*: no charger with a windup, no exploder, no ranged *damage* threat.
12. **Upgrade pool: 18 entries, no build identity.** No crit, no AoE, no regen/
    lifesteal/armor, no sentry scaling beyond stacking copies, no build-defining
    legendaries. Sentry count is uncapped but orbit spacing assumes ≤3.
13. **No controller support, no rebinding.** Movement reuses `ui_*` actions (which
    also drive menu focus — moving in menus moves selection), dash is hardcoded
    Space/LMB. Needs dedicated `move_*`/`dash`/`pause` actions defined in
    project.godot with joypad events, and a rebind UI.
14. **No damage numbers, no combo counter.** Kills feel identical at minute 1 and
    minute 15.
15. **No export presets** (`export_presets.cfg` absent) — the game cannot ship.

## P2 — Structural fragility

16. `project.godot` declares `config/features="4.7"` but the pinned binary is 4.6.3.
    Should match the shipping engine.
17. `GameState.hitstop` awaits with `Engine.time_scale = 0`; the depth counter
    handles overlap but a game-over during hit-stop leaves a dangling await. Safe
    today, but the kill-gated redesign (item 5) should also clamp duration.
18. `Enemy._merge_smallest` runs O(n²)-ish per drop past 75 orbs — fine, but orb cap
    and smear cap are the only object caps in the game; enemies/projectiles have none.
19. `BoneSentry` reads `GameState.sentry_count` at spawn for spacing; upgrades can
    push count past 3 and overlap orbits. Cap or re-space dynamically.
20. `MainMenu` and `Main` both build their own CRT layer with duplicated code; the
    options logic exists twice (`MainMenu._show_options` vs `OptionsScreen`). A
    Settings autoload should be the single owner.
21. Wraith `fire_kill()`/`_die()` duplicate Enemy's logic (as does Spider) — three
    copies of the same death/XP/blood code. Acceptable per project style ("shares
    the same interface"), but any new enemy multiplies the copy count. A shared
    `EnemyBase` would help; deferred to keep churn low — new enemies follow the
    established copy pattern.
22. Uncommitted WIP in tree (player sprite swap, DashDust, dash tweaks) — committed
    as baseline before Phase 2 work begins.

## Existing balance levers (Phase 2 inputs)

| Lever | Where | Current value |
|---|---|---|
| Spawn interval | `Main._process` | `max(0.35, 2.0 − t·0.012)` s |
| Wave size | `Main._spawn_wave` | `1 + t/18` |
| Enemy mix | `Main._spawn_one` | cyclops ≤25 %, wraith ≤50 %, spider fades 50 %→0 |
| Demon stats | `_spawn_demon` | HP `25(1+1.2m)`, spd `55+35m`, dmg `10(1+0.5m)`, XP `20(1+0.4m)` (m = minutes) |
| Wraith stats | `_spawn_wraith` | HP `15(1+m)`, spd `80+30m`, dmg `8(1+0.5m)`, XP `25(1+0.4m)` |
| Spider stats | `_spawn_spider` | HP `10(1+0.8m)`, spd `95+30m`, dmg `6(1+0.4m)`, XP `8(1+0.3m)` |
| Cyclops stats | `_spawn_cyclops` | HP `75(1+1.2m)`, spd `28+12m`, dmg `12(1+0.5m)`, XP `60(1+0.4m)` |
| Boss | `_spawn_boss` | every 60 s; HP `500(1+0.8m)`, dmg `25(1+0.5m)`, XP 500 flat |
| XP curve | `GameState._do_level_up` | base 40, ×1.4/level |
| Player base | `GameState._reset` | 100 HP, 200 spd, 15 dmg, 1.5 shots/s, 400 proj spd, magnet 120 |
| Dash | `Player.gd` consts | 1200 spd, 0.20 s, 3.0 s CD, knockback 550 in r=65 |
| Sentry | `BoneSentry.gd` | player fire rate, damage/2, orbit 90 |
| Upgrades | `UpgradeData.ALL_UPGRADES` | 18 entries, unweighted |

## Plan of attack (Phases 2–5)

Phase 2 rebuilds the XP curve, enemy scaling, spawn curve, and upgrade weights from
an explicit model in `docs/BALANCE.md`, hoisting every magic number above into named
constants. Phase 3 fills P1 items. Phase 4 tunes via `scripts/BalanceSim.gd`
(100 synthetic runs). Phase 5 ships (export preset, CLAUDE.md, DESIGN.md).
