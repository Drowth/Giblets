# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Running the Game

Godot is installed at `C:\Claude\REPOS\Games\Giblets\Godot_v4.7-stable_win64.exe`.

- **Run from CLI:** `"C:\Claude\REPOS\Games\Giblets\Godot_v4.7-stable_win64.exe" --path "C:\Claude\REPOS\Games\Giblets"`
- **Run in editor:** Open `project.godot` in Godot, press F5
- **Force asset import (CLI):** `"C:\Claude\REPOS\Games\Giblets\Godot_v4.7-stable_win64.exe" --path "C:\Claude\REPOS\Games\Giblets" --headless --import`
- **Balance simulation:** `"C:\Claude\REPOS\Games\Giblets\Godot_v4.7-stable_win64.exe" --path "C:\Claude\REPOS\Games\Giblets" --headless res://scenes/BalanceSim.tscn` — 5 meta profiles × 100 synthetic runs (fresh account + maxed talents per character); prints death-time distribution, boss TTK, DPS-vs-budget checkpoints, and giblet yields. Run it after any balance change.
- **Physics/AI soak test:** set env `GIBLETS_SOAK=1` and run the game headless (`res://scenes/Main.tscn`) — god-modes the player, auto-picks level-ups, runs 5×, and reports any body whose position/velocity goes non-finite; clean pass = 12 game-minutes at the enemy cap with zero warnings. Run it after touching enemy movement or physics.
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

- **Settings** (`scripts/Settings.gd`) — display/audio/input config, persisted to `user://settings.cfg` via ConfigFile. Owns volumes (creates `Music`/`SFX` buses at runtime), CRT toggles, screen-shake toggle, reduce-flash toggle (de-strobes BoneCharger/Butcher windup flashes), rumble toggle (`rumble_enabled`, gates `GameState.rumble()`), fullscreen, and keyboard rebinds. Emits `crt_settings_changed`. Never holds gameplay state.
- **Sfx** (`scripts/Sfx.gd`) — central one-shot SFX player: a pool of 12 `AudioStreamPlayer`s on the `SFX` bus so several sounds (e.g. multishot kills) never cut each other off. `Sfx.play(path, volume_db, pitch_variance)`, `Sfx.play_random(paths, ...)` for hit/kill/card-draw variation, `Sfx.play_pitched(path, volume_db, pitch_scale)` for deterministic pitch (combo escalation). Every UI/game sound routes through this instead of scenes managing their own players — see "Sound" below.
- **Meta** (`scripts/Meta.gd`) — cross-run progression: giblets currency (itemized on the death screen: capped score component + per-boss + per-2-minutes survived, see `compute_earn`), the 3-branch talent tree (`TALENTS`, tier-gated, with per-rank refunds at `REFUND_RATE` — `refund_value()` prices the *current top* rank, never `cost()`'s next-rank price, so refunding can't farm giblets; `refund_blocker()` blocks refunds that would strand an owned higher-tier talent), character unlock/selection state, and the end-of-run roulette's `unlocked_upgrades` pool — all persisted to `user://meta.save` (v2). Feeds *base* stats into `GameState._reset()`.
- **GameState** (`scripts/GameState.gd`) — the single source of truth for all mutable gameplay values: stats, XP, level, score, combo, and every upgrade-driven stat (`damage_mul`, `crit_chance`, `armor`, `regen_per_5s`, `explosive_pct`, `sentry_damage_mul`, …). Emits the signals that drive UI. Also owns the XP curve (`xp_required`), the DPS budget (`dps_target`), and kill-gated hit-stop (`kill_hitstop` — never call `hitstop` per hit). Never modify player stats directly on the player node.
- **HighScores** (`scripts/HighScores.gd`) — top 10 runs to `user://highscores.save`.

**Main** (`scripts/Main.gd`, `scenes/Main.tscn`) owns the game loop. All balance constants live at its top. Named containers (`Enemies`, `Projectiles`, `XPOrbs`) are exposed via groups (`"enemies_container"`, `"projectiles_container"`, `"xp_orbs_container"`). Wave spawning via `SpawnTimer` (interval + wave size from the spawn-curve constants, hard-capped at `MAX_LIVE_ENEMIES`); bosses via `BossTimer` (90 s), **alternating** Skull King (boss-flagged Enemy) and Butcher. `_ready()` instantiates BloodSmears, DamageNumbers (on the enemies canvas), the CRT layer, and the PauseScreen programmatically.

**Enemy roster** — all share the `take_hit()` / `fire_kill()` / `apply_knockback()` interface; stats are applied by `Main._apply_stats()` from per-archetype constant tables:

| Script | Role |
|---|---|
| `Enemy.gd` | Brawler (baseline chaser, animated 8-dir sprite via `WizardFrames.build` on `res://assets/enemies/brawler`), Cyclops (tank variant, `is_cyclops = true` **before** `add_child()`, its own animated frame set on `res://assets/enemies/cyclops`), Skull King boss (`is_boss = true` **before** `add_child()`, its own animated frame set on `res://assets/enemies/boss` at `BOSS_ANIM_SCALE` — deliberately larger than the player/regular enemies — plus a dedicated `attack` animation triggered on every landed contact hit via `_attack_anim_timer`) — all three variants are animated now, no static Sprite2D path remains |
| `Wraith.gd` | Fast, sinusoidal drift + periodic lunge; animated 8-dir sprite via `WizardFrames.build` on `res://assets/enemies/wraith` |
| `Spider.gd` | Early swarm; fires `WebProjectile` (slow debuff) |
| `Imp.gd` | Ranged: hovers at mid-range, strafes, fires `ImpBolt`; animated 8-dir sprite via `WizardFrames.build` on `res://assets/enemies/imp` |
| `BoneCharger.gd` | Telegraphed charge (flash windup, direction locks at windup end) + death burst after a 0.5 s fuse. Animated 8-dir sprite via `WizardFrames.build` on `res://assets/enemies/bonecharger` — `run`/`windup`/`charge` animations driven by its WALK/WINDUP/CHARGE state machine; `_draw()` keeps only the health bar and the post-death burst-radius telegraph (procedural) |
| `Butcher.gd` | Boss 2: orbits, telegraphed cross-arena charge (draws its aim line). 80% HP of Skull King. Animated 8-dir sprite via `WizardFrames.build` on `res://assets/enemies/butcher` — `run`/`windup`/`charge` animations driven by its ORBIT/WINDUP/CHARGE state machine, sized (`ANIM_SCALE`) slightly larger than the Skull King boss, matching its original size lead |

`fire_kill()` on bosses chunks 25% max HP instead of instakilling (a boss drops the bomb — see docs/DESIGN.md). Enemies call `GameState.kill_hitstop()` in `_die()`.

**Upgrade system** — `UpgradeData` (`scripts/UpgradeData.gd`, plain class): 42 upgrades across four archetypes (crit, area, summons, sustain) plus a quirk batch (mechanic-flag stats on GameState: rear_shot, orb_heal, dash_vacuum, kill_speed_burst, hurt_nova, extra_choice/4th card, dash_damage, ricochet, bloodlust), with 5 legendaries. Each entry has a documented `power` score; rarity is assigned from the score band and drawn via `RARITY_WEIGHTS` (45/30/15/7/3), then weighted within rarity by the selected character's `draw_bias`. `max_stacks` caps non-decaying upgrades; per-run counts live in `GameState.upgrade_stacks`. 14 entries carry `locked_by_default: true` — out of the rotation until won from the end-of-run roulette (or bundled with a character purchase). Adding an upgrade = dict in `ALL_UPGRADES` (with `power` + band-correct rarity, `locked_by_default` if roulette-gated) + match arm in `apply_upgrade()` + a row in docs/BALANCE.md §5.

**UI flow** — MainMenu (start / characters / talents / high scores / options / credits) → Main. Esc/controller-Start opens **PauseScreen** (`ui/PauseScreen.gd`, layer 210): resume, options, restart, quit. **OptionsPanel** (`ui/OptionsPanel.gd`) is the shared options UI (two columns: audio/display + key rebinding) embedded by both PauseScreen and MainMenu; it talks only to Settings. **LevelUpScreen** rebuilds its child tree each `show_choices()` (3 cards, 4 with Third Eye). **HUD** shows bars, combo counter, and the two-phase death screen (run summary + itemized giblets + roulette spin + name entry, then a compacted header + leaderboard — both phases must fit the 216-unit viewport; see `_compact_death_header`).

**Pickup pattern** — XPOrb, BombPickup, and Pickup use manual distance checks in `_process()` against `get_first_node_in_group("player")`, not Area2D signals (sidesteps collision-layer mismatches). ImpBolt and WebProjectile hit the player the same way. Follow this pattern for any new pickups or enemy projectiles. `Pickup` (`scripts/Pickup.gd`, no scene — built via `Pickup.maybe_drop(pos, is_boss)` from every enemy `_die()`) is a `kind`-parameterized field consumable (`"heal"` / `"magnet"`); non-boss drops are run-clock gated in `GameState.try_reserve_pickup_drop()` (rescue-not-sustain, docs/BALANCE.md §8), bosses drop a guaranteed heal.

**On-hit flash / muzzle flash** — `HitFlash` (`scripts/HitFlash.gd`, static `flash(sprite, base)` / `is_flashing(sprite)`) is the shared enemy impact-blink every `take_hit()` calls; it tweens the sprite's modulate from an over-bright pop back to its resting colour and honors `Settings.reduce_flash`. Enemies that rewrite modulate every physics frame (BoneCharger WALK, Butcher ORBIT) guard that write with `HitFlash.is_flashing()`. `MuzzleFlash` (`scripts/MuzzleFlash.gd`) is a one-per-volley procedural fire flash spawned by `Player._fire()`. Both are procedural, no assets.

**BoneSentry** (`scripts/BoneSentry.gd`) — companion turret, no scene file (`Node2D.new(); set_script(...)`). Fires at `GameState.sentry_damage_mul` × player damage (0.5 base, 1.0 with Bone Legion legendary). Capped at 3 via upgrade `max_stacks` (+2 from Bone Legion).

**Single-draw pools** — BloodSmears (group `"blood_smears"`, `add_smear(pos, dir, scale_mul, tint)`) and DamageNumbers (48 cap, group `"damage_numbers"`, `pop(pos, amount, is_crit)`) both draw their whole pool in one `_draw()` pass. Use this pattern for any new high-frequency transient visual. BloodSmears draws sprite splats from `assets/blood/<variant 1-5>/<001-015>.png`: each kill plays the 15-frame splatter animation once (0.75 s), then the final frame persists as a floor decal; at 40 decals the oldest fades out over 1 s (`MAX_SPLATS`/`FADE_TIME`). `_process` is disabled whenever nothing is animating or fading, so settled decals cost zero per-frame CPU. A green tint request (Wraith) uses a channel-swapped recolor of variant 1, built lazily and cached. It replaced both the old procedural smears and the per-kill BloodSplatter CPUParticles2D burst — enemies spawn blood only via `add_smear`.

**BalanceSim** (`scripts/BalanceSim.gd` + `scenes/BalanceSim.tscn`) — runs as a scene so the real autoloads load: XP, level-ups, and upgrade draws go through the shipping code; combat is an analytic horde model reading Main.gd's constants. Sim-only coefficients are marked as such at the top.

## Key Patterns

**Sound** — All one-shot SFX go through the `Sfx` autoload (never build a scene-local `AudioStreamPlayer` for a one-shot). Files live under `assets/sfx/` grouped by purpose: `ui/` (hover, select, select_big, cancel, disallow, toggle_on/off, pause_open/close), `cards/` (card_draw_1-3, card_fan — LevelUpScreen only), `combat/` (hit_1-3, kill_1-2, player_hurt), `game/` (boss_warning, game_over, new_high_score, bomb_explosion, coin, combo_pop, dash). High-frequency sounds (projectile hits, kills) are rate-limited through `GameState.play_hit_sfx()` / the cooldown inside `add_kill_score()` rather than playing unconditionally, so a horde of simultaneous deaths reads as one crunch instead of a wall of overlapping samples — follow that pattern for any new frequent trigger. Menu buttons built via a shared `_make_button(text, color, sound)` helper (MainMenu, OptionsPanel, PauseScreen each have their own copy) take a `sound` param: `"select"` (default confirm), `"cancel"` (softer, for BACK/quit), or `"none"` (caller plays its own, e.g. toggles use `toggle_on`/`toggle_off` instead).

**Pause-safe nodes** — When the game pauses (level-up or pause menu), any node that must keep running needs `process_mode = Node.PROCESS_MODE_ALWAYS`. The LevelUpScreen, PauseScreen, OptionsPanel, their buttons, and particle effects added during pause all set this.

**Drawing** — Most game objects draw themselves via `_draw()` / `queue_redraw()`. Most enemies use sprites; orbs, rings, and HUD overlays are procedural. Player/sentry projectiles draw animated spell frames from `assets/projectiles/` inside their `_draw()` (see the Projectile row below); enemy projectiles stay procedural. New visuals without an existing sprite must be procedural. Animated 8-directional characters (the Wizard, Reaper, Necromancer, and Paladin player characters; the Brawler, Cyclops, Skull King boss, Butcher, Wraith, Imp, and BoneCharger enemies) use an `AnimatedSprite2D` built by `WizardFrames.build(base_path, anims)` (`scripts/WizardFrames.gd`, cached per `base_path`) from `<base_path>/<anim>/<dir>/NNN.png`; animations named `run_NE` etc., driven by a per-script `_play_anim` + `_facing` pair (`Player._apply_character_visuals` / `Enemy._ready`). Everything else — the Cyclops texture-swap, the Skull King boss — uses the `Sprite2D` + code-built bob/hurt/death `AnimationPlayer` path.

**Screen-flash overlays** — Temporary CanvasLayers at layer 10–20, tweened to alpha 0, then freed (see `BombPickup._explode()`, `Main._show_boss_warning()`). Layer <128 so the CRT effect applies.

**CanvasLayer ordering** — 0–127: world + world-space effects (flashes at 10–20). 128: CRT. 150: enemies canvas (drops to 50 when "CRT affects enemies" is on) — DamageNumbers lives here too. 200: `UI` (HUD + LevelUpScreen). 210: PauseScreen. Do not add gameplay overlays above 128 (escapes CRT) or move UI below 200 (darkened by vignette).

**Collision layers** — Enemies are CharacterBody2D on layer 2 / mask 2. Projectile (Area2D) uses `body_entered`. Player on default layer. Do not modify the shared enemy `CircleShape2D` resource; create a new `CircleShape2D.new()` when overriding (as the boss does). Every CharacterBody2D sets `motion_mode = MOTION_MODE_FLOATING` in `_ready()` — grounded mode's floor/platform tracking causes NaN warning spam + wasted solve time in a top-down game; new bodies must do the same.

**Input** — Actions `move_left/right/up/down`, `dash`, `pause` are defined in `project.godot` with keyboard + joypad events. Menus use the built-in `ui_*` actions (controller works by default). Keyboard rebinds go through `Settings.rebind()` which preserves joypad events. Never add InputMap events in scene `_ready()` — they duplicate on scene reload.

**Audio** — `Music` and `SFX` buses are created by Settings at startup; AudioStreamPlayers in Main.tscn are assigned to them so the volume sliders work. New audio players must set `bus`.

**Adding new image/audio assets** — Godot requires a `.import` file and a compiled `.ctex` / `.sample` in `.godot/imported/` before a texture or audio file can be loaded at runtime. Run `--headless --import` to compile the asset, then manually write the `.import` file in the asset's directory mirroring the hash Godot placed in `.godot/imported/`. See `assets/enemies/wraith.png.import` for a template. Opening the project in the editor also auto-generates both files.

## Scene / Script Map

| Scene | Script | Role |
|---|---|---|
| `scenes/Main.tscn` | `scripts/Main.gd` | Game loop, spawning, bosses, audio, level-up flow, balance constants |
| `scenes/MainMenu.tscn` | `scripts/MainMenu.gd` | Start, characters, talents, high scores, options, credits |
| `scenes/Enemy.tscn` | `scripts/Enemy.gd` | Brawler / Cyclops / Skull King boss |
| `scenes/Wraith.tscn` | `scripts/Wraith.gd` | Drift + lunge enemy |
| `scenes/Spider.tscn` | `scripts/Spider.gd` | Web-slow enemy |
| `scenes/Imp.tscn` | `scripts/Imp.gd` | Ranged enemy |
| `scenes/BoneCharger.tscn` | `scripts/BoneCharger.gd` | Charge + death-burst enemy (procedural) |
| `scenes/Butcher.tscn` | `scripts/Butcher.gd` | Second boss (orbit + charge), animated |
| `scenes/Player.tscn` | `scripts/Player.gd` | Movement, firing, dash, damage, trail |
| `scenes/Projectile.tscn` | `scripts/Projectile.gd` | Bullet: pierce, crit roll, Hellfire splash. Build-reactive spell visuals (`assets/projectiles/{fire,ice,death,arc}/001-015.png`, art faces E, static frame cache): fire = base, ice = Velocity stacks (stretches per stack), enlarged deep-red fire = Hellfire Rounds, arc crescent = Wishbone (priority Wishbone > Hellfire > Velocity), death = Osseous Sentinel (passed as `launch()`'s 5th arg) |
| `scenes/XPOrb.tscn` | `scripts/XPOrb.gd` | XP pickup with magnet |
| `scenes/BombPickup.tscn` | `scripts/BombPickup.gd` | Screen-clear; chunks bosses 25% |
| `scenes/BalanceSim.tscn` | `scripts/BalanceSim.gd` | Headless balance harness (5 meta profiles × 100 runs) |
| `ui/LevelUpScreen.tscn` | `ui/LevelUpScreen.gd` | Upgrade card selection |
| `ui/HUD.tscn` | `ui/HUD.gd` | Bars, combo, death screen + leaderboard |
| `ui/UpgradeCard.tscn` | `ui/UpgradeCard.gd` | Card button (legacy; LevelUpScreen builds its own) |
| *(no scene)* | `scripts/Settings.gd` | Autoload — settings.cfg persistence |
| *(no scene)* | `scripts/Sfx.gd` | Autoload — pooled one-shot SFX player |
| *(no scene)* | `scripts/Meta.gd` | Autoload — giblets, talent tree, characters, roulette unlocks |
| *(no scene)* | `scripts/CharacterData.gd` | Playable roster data (class_name; deltas / passives / draw bias) |
| *(no scene)* | `scripts/WizardFrames.gd` | Generic 8-directional SpriteFrames builder, cached per base path; `get_frames()`/`get_reaper_frames()`/`get_necromancer_frames()` wrap the three animated player characters, `build(base_path, anims)` used directly by the Brawler, Cyclops, Skull King boss, Butcher, Wraith, Imp, and BoneCharger enemies |
| *(no scene)* | `scripts/GameState.gd` | Autoload — all in-run state, XP curve, hit-stop |
| *(no scene)* | `scripts/HighScores.gd` | Autoload — top-10 persistence |
| *(no scene)* | `scripts/UpgradeData.gd` | Upgrade pool, power scores, weighted draw |
| *(no scene)* | `ui/PauseScreen.gd` | Pause menu CanvasLayer (built by Main) |
| *(no scene)* | `ui/OptionsPanel.gd` | Shared options UI (pause + main menu) |
| *(no scene)* | `scripts/BoneSentry.gd` | Companion turret |
| *(no scene)* | `scripts/ImpBolt.gd`, `scripts/WebProjectile.gd` | Enemy projectiles (manual distance checks) |
| *(no scene)* | `scripts/BloodSmears.gd`, `scripts/DamageNumbers.gd` | Single-draw capped pools (blood splats + damage numbers) |
| *(no scene)* | `scripts/BloodTrailDrop.gd`, `scripts/DashDust.gd`, `scripts/HellfireRing.gd`, `scripts/MuzzleFlash.gd` | Transient procedural effects |
| *(no scene)* | `scripts/HitFlash.gd` | Shared enemy on-hit flash helper (`class_name`, static) |
| *(no scene)* | `scripts/Pickup.gd` | Field consumable pickup (heal / magnet), manual distance-check |
| *(no scene)* | `scripts/Background.gd` | Procedural stone floor |
| *(no scene)* | `shaders/crt_effect.gdshader` | Full-screen post-process |
