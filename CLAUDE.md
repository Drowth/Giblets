# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Running the Game

Godot is installed at `D:\GoDot\Godot_v4.6.3-stable_win64.exe`.

- **Run from CLI:** `"D:\GoDot\Godot_v4.6.3-stable_win64.exe" --path "C:\Claude\REPOS\Games\Giblets"`
- **Run in editor:** Open `project.godot` in Godot, press F5
- **Force asset import (CLI):** `"D:\GoDot\Godot_v4.6.3-stable_win64.exe" --path "C:\Claude\REPOS\Games\Giblets" --headless --import`
- **Balance simulation:** `"D:\GoDot\Godot_v4.6.3-stable_win64.exe" --path "C:\Claude\REPOS\Games\Giblets" --headless res://scenes/BalanceSim.tscn` — 100 synthetic runs, prints death-time distribution, boss TTK, and DPS-vs-budget checkpoints. Run it after any balance change.
- **Export:** `export_presets.cfg` defines a Windows Desktop preset (embedded PCK → `build/windows/Giblets.exe`). Requires export templates installed.
- **No build step** — Godot parses GDScript at runtime; errors surface in the editor Output/Debugger panel

There are no tests beyond BalanceSim. Parser errors appear as red messages in the Godot debugger on launch.

## Balance model — read this before changing any number

`docs/BALANCE.md` is the mathematical model (XP curve, DPS budget, enemy/boss
scaling, upgrade power scores); `docs/DESIGN.md` is the rationale. Every
balance value in code is a named constant pointing back at those docs:
spawn/scaling/boss constants at the top of `scripts/Main.gd`, XP-curve and
hit-stop constants in `scripts/GameState.gd`, rarity weights in
`scripts/UpgradeData.gd`. Change the constant, re-run BalanceSim, check the
death-time distribution (target: most runs end minute 12–20, few before 5,
none past ~26).

## Architecture

**Autoloads** (registration order matters — GameState reads Meta at reset):

- **Settings** (`scripts/Settings.gd`) — display/audio/input config, persisted to `user://settings.cfg` via ConfigFile. Owns volumes (creates `Music`/`SFX` buses at runtime), CRT toggles, screen-shake toggle, fullscreen, and keyboard rebinds. Emits `crt_settings_changed`. Never holds gameplay state.
- **Sfx** (`scripts/Sfx.gd`) — central one-shot SFX player: a pool of 12 `AudioStreamPlayer`s on the `SFX` bus so several sounds (e.g. multishot kills) never cut each other off. `Sfx.play(path, volume_db, pitch_variance)`, `Sfx.play_random(paths, ...)` for hit/kill/card-draw variation, `Sfx.play_pitched(path, volume_db, pitch_scale)` for deterministic pitch (combo escalation). Every UI/game sound routes through this instead of scenes managing their own players — see "Sound" below.
- **Meta** (`scripts/Meta.gd`) — cross-run progression: giblets currency (1 per 400 score, awarded on the death screen) and permanent small unlocks, persisted to `user://meta.save`. Feeds *base* stats into `GameState._reset()`.
- **GameState** (`scripts/GameState.gd`) — the single source of truth for all mutable gameplay values: stats, XP, level, score, combo, and every upgrade-driven stat (`damage_mul`, `crit_chance`, `armor`, `regen_per_5s`, `explosive_pct`, `sentry_damage_mul`, …). Emits the signals that drive UI. Also owns the XP curve (`xp_required`), the DPS budget (`dps_target`), and kill-gated hit-stop (`kill_hitstop` — never call `hitstop` per hit). Never modify player stats directly on the player node.
- **HighScores** (`scripts/HighScores.gd`) — top 10 runs to `user://highscores.save`.

**Main** (`scripts/Main.gd`, `scenes/Main.tscn`) owns the game loop. All balance constants live at its top. Named containers (`Enemies`, `Projectiles`, `XPOrbs`) are exposed via groups (`"enemies_container"`, `"projectiles_container"`, `"xp_orbs_container"`). Wave spawning via `SpawnTimer` (interval + wave size from the spawn-curve constants, hard-capped at `MAX_LIVE_ENEMIES`); bosses via `BossTimer` (60 s), **alternating** Skull King (boss-flagged Enemy) and Butcher. `_ready()` instantiates BloodSmears, DamageNumbers (on the enemies canvas), the CRT layer, and the PauseScreen programmatically.

**Enemy roster** — all share the `take_hit()` / `fire_kill()` / `apply_knockback()` interface; stats are applied by `Main._apply_stats()` from per-archetype constant tables:

| Script | Role |
|---|---|
| `Enemy.gd` | Demon (baseline chaser), Cyclops (tank reskin via texture swap), Skull King boss (`is_boss = true` **before** `add_child()`) |
| `Wraith.gd` | Fast, sinusoidal drift + periodic lunge |
| `Spider.gd` | Early swarm; fires `WebProjectile` (slow debuff) |
| `Imp.gd` | Ranged: hovers at mid-range, strafes, fires `ImpBolt` |
| `BoneCharger.gd` | Telegraphed charge (flash windup, direction locks at windup end) + death burst after a 0.5 s fuse. Fully procedural `_draw()` |
| `Butcher.gd` | Boss 2: orbits, telegraphed cross-arena charge (draws its aim line). 80% HP of Skull King |

`fire_kill()` on bosses chunks 25% max HP instead of instakilling (a boss drops the bomb — see docs/DESIGN.md). Enemies call `GameState.kill_hitstop()` in `_die()`.

**Upgrade system** — `UpgradeData` (`scripts/UpgradeData.gd`, plain class): 32 upgrades across four archetypes (crit, area, summons, sustain) with 4 legendaries. Each entry has a documented `power` score; rarity is assigned from the score band and drawn via `RARITY_WEIGHTS` (45/30/15/7/3). `max_stacks` caps non-decaying upgrades; per-run counts live in `GameState.upgrade_stacks`. Adding an upgrade = dict in `ALL_UPGRADES` (with `power` + band-correct rarity) + match arm in `apply_upgrade()` + a row in docs/BALANCE.md §5.

**UI flow** — MainMenu (start / high scores / unlocks shop / options / credits) → Main. Esc/controller-Start opens **PauseScreen** (`ui/PauseScreen.gd`, layer 210): resume, options, restart, quit. **OptionsPanel** (`ui/OptionsPanel.gd`) is the shared options UI (volume sliders, toggles, key rebinding) embedded by both PauseScreen and MainMenu; it talks only to Settings. **LevelUpScreen** rebuilds its child tree each `show_choices()`. **HUD** shows bars, combo counter, and the death screen (score, DPS, giblets earned, name entry, leaderboard with rank callout).

**Pickup pattern** — XPOrb and BombPickup use manual distance checks in `_process()` against `get_first_node_in_group("player")`, not Area2D signals (sidesteps collision-layer mismatches). ImpBolt and WebProjectile hit the player the same way. Follow this pattern for any new pickups or enemy projectiles.

**BoneSentry** (`scripts/BoneSentry.gd`) — companion turret, no scene file (`Node2D.new(); set_script(...)`). Fires at `GameState.sentry_damage_mul` × player damage (0.5 base, 1.0 with Bone Legion legendary). Capped at 3 via upgrade `max_stacks` (+2 from Bone Legion).

**Single-draw pools** — BloodSmears (150 cap, group `"blood_smears"`) and DamageNumbers (48 cap, group `"damage_numbers"`, `pop(pos, amount, is_crit)`) both draw their whole pool in one `_draw()` pass with FIFO eviction. Use this pattern for any new high-frequency transient visual.

**BalanceSim** (`scripts/BalanceSim.gd` + `scenes/BalanceSim.tscn`) — runs as a scene so the real autoloads load: XP, level-ups, and upgrade draws go through the shipping code; combat is an analytic horde model reading Main.gd's constants. Sim-only coefficients are marked as such at the top.

## Key Patterns

**Sound** — All one-shot SFX go through the `Sfx` autoload (never build a scene-local `AudioStreamPlayer` for a one-shot). Files live under `assets/sfx/` grouped by purpose: `ui/` (hover, select, select_big, cancel, disallow, toggle_on/off, pause_open/close), `cards/` (card_draw_1-3, card_fan — LevelUpScreen only), `combat/` (hit_1-3, kill_1-2, player_hurt), `game/` (boss_warning, game_over, new_high_score, bomb_explosion, coin, combo_pop, dash). High-frequency sounds (projectile hits, kills) are rate-limited through `GameState.play_hit_sfx()` / the cooldown inside `add_kill_score()` rather than playing unconditionally, so a horde of simultaneous deaths reads as one crunch instead of a wall of overlapping samples — follow that pattern for any new frequent trigger. Menu buttons built via a shared `_make_button(text, color, sound)` helper (MainMenu, OptionsPanel, PauseScreen each have their own copy) take a `sound` param: `"select"` (default confirm), `"cancel"` (softer, for BACK/quit), or `"none"` (caller plays its own, e.g. toggles use `toggle_on`/`toggle_off` instead).

**Pause-safe nodes** — When the game pauses (level-up or pause menu), any node that must keep running needs `process_mode = Node.PROCESS_MODE_ALWAYS`. The LevelUpScreen, PauseScreen, OptionsPanel, their buttons, and particle effects added during pause all set this.

**Drawing** — Most game objects draw themselves via `_draw()` / `queue_redraw()`. Player and most enemies use sprites; BoneCharger, projectiles, orbs, rings, and HUD overlays are procedural. New visuals without an existing sprite must be procedural.

**Screen-flash overlays** — Temporary CanvasLayers at layer 10–20, tweened to alpha 0, then freed (see `BombPickup._explode()`, `Main._show_boss_warning()`). Layer <128 so the CRT effect applies.

**CanvasLayer ordering** — 0–127: world + world-space effects (flashes at 10–20). 128: CRT. 150: enemies canvas (drops to 50 when "CRT affects enemies" is on) — DamageNumbers lives here too. 200: `UI` (HUD + LevelUpScreen). 210: PauseScreen. Do not add gameplay overlays above 128 (escapes CRT) or move UI below 200 (darkened by vignette).

**Collision layers** — Enemies are CharacterBody2D on layer 2 / mask 2. Projectile (Area2D) uses `body_entered`. Player on default layer. Do not modify the shared enemy `CircleShape2D` resource; create a new `CircleShape2D.new()` when overriding (as the boss does).

**Input** — Actions `move_left/right/up/down`, `dash`, `pause` are defined in `project.godot` with keyboard + joypad events. Menus use the built-in `ui_*` actions (controller works by default). Keyboard rebinds go through `Settings.rebind()` which preserves joypad events. Never add InputMap events in scene `_ready()` — they duplicate on scene reload.

**Audio** — `Music` and `SFX` buses are created by Settings at startup; AudioStreamPlayers in Main.tscn are assigned to them so the volume sliders work. New audio players must set `bus`.

**Adding new image/audio assets** — Godot requires a `.import` file and a compiled `.ctex` / `.sample` in `.godot/imported/` before a texture or audio file can be loaded at runtime. Run `--headless --import` to compile the asset, then manually write the `.import` file in the asset's directory mirroring the hash Godot placed in `.godot/imported/`. See `assets/enemies/wraith.png.import` for a template. Opening the project in the editor also auto-generates both files.

## Scene / Script Map

| Scene | Script | Role |
|---|---|---|
| `scenes/Main.tscn` | `scripts/Main.gd` | Game loop, spawning, bosses, audio, level-up flow, balance constants |
| `scenes/MainMenu.tscn` | `scripts/MainMenu.gd` | Start, high scores, unlocks shop, options, credits |
| `scenes/Enemy.tscn` | `scripts/Enemy.gd` | Demon / Cyclops / Skull King boss |
| `scenes/Wraith.tscn` | `scripts/Wraith.gd` | Drift + lunge enemy |
| `scenes/Spider.tscn` | `scripts/Spider.gd` | Web-slow enemy |
| `scenes/Imp.tscn` | `scripts/Imp.gd` | Ranged enemy |
| `scenes/BoneCharger.tscn` | `scripts/BoneCharger.gd` | Charge + death-burst enemy (procedural) |
| `scenes/Butcher.tscn` | `scripts/Butcher.gd` | Second boss (orbit + charge) |
| `scenes/Player.tscn` | `scripts/Player.gd` | Movement, firing, dash, damage, trail |
| `scenes/Projectile.tscn` | `scripts/Projectile.gd` | Bullet: pierce, crit roll, Hellfire splash |
| `scenes/XPOrb.tscn` | `scripts/XPOrb.gd` | XP pickup with magnet |
| `scenes/BombPickup.tscn` | `scripts/BombPickup.gd` | Screen-clear; chunks bosses 25% |
| `scenes/BloodSplatter.tscn` | `scripts/BloodSplatter.gd` | One-shot death particles |
| `scenes/BalanceSim.tscn` | `scripts/BalanceSim.gd` | Headless 100-run balance harness |
| `ui/LevelUpScreen.tscn` | `ui/LevelUpScreen.gd` | Upgrade card selection |
| `ui/HUD.tscn` | `ui/HUD.gd` | Bars, combo, death screen + leaderboard |
| `ui/UpgradeCard.tscn` | `ui/UpgradeCard.gd` | Card button (legacy; LevelUpScreen builds its own) |
| *(no scene)* | `scripts/Settings.gd` | Autoload — settings.cfg persistence |
| *(no scene)* | `scripts/Sfx.gd` | Autoload — pooled one-shot SFX player |
| *(no scene)* | `scripts/Meta.gd` | Autoload — giblets + permanent unlocks |
| *(no scene)* | `scripts/GameState.gd` | Autoload — all in-run state, XP curve, hit-stop |
| *(no scene)* | `scripts/HighScores.gd` | Autoload — top-10 persistence |
| *(no scene)* | `scripts/UpgradeData.gd` | Upgrade pool, power scores, weighted draw |
| *(no scene)* | `ui/PauseScreen.gd` | Pause menu CanvasLayer (built by Main) |
| *(no scene)* | `ui/OptionsPanel.gd` | Shared options UI (pause + main menu) |
| *(no scene)* | `scripts/BoneSentry.gd` | Companion turret |
| *(no scene)* | `scripts/ImpBolt.gd`, `scripts/WebProjectile.gd` | Enemy projectiles (manual distance checks) |
| *(no scene)* | `scripts/BloodSmears.gd`, `scripts/DamageNumbers.gd` | Single-draw capped pools |
| *(no scene)* | `scripts/BloodTrailDrop.gd`, `scripts/DashDust.gd`, `scripts/HellfireRing.gd` | Transient procedural effects |
| *(no scene)* | `scripts/Background.gd` | Procedural stone floor |
| *(no scene)* | `shaders/crt_effect.gdshader` | Full-screen post-process |
