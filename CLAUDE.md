# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Running the Game

Godot is installed at `D:\GoDot\Godot_v4.6.3-stable_win64.exe`.

- **Run from CLI:** `"D:\GoDot\Godot_v4.6.3-stable_win64.exe" --path "C:\Claude\REPOS\Games\Giblets"`
- **Run in editor:** Open `project.godot` in Godot, press F5
- **Force asset import (CLI):** `"D:\GoDot\Godot_v4.6.3-stable_win64.exe" --path "C:\Claude\REPOS\Games\Giblets" --headless --import`
- **No build step** — Godot parses GDScript at runtime; errors surface in the editor Output/Debugger panel

There are no tests or linters. Parser errors appear as red messages in the Godot debugger on launch.

## Architecture

**GameState** (`scripts/GameState.gd`) is a singleton autoload. It is the single source of truth for all mutable gameplay values: player stats, XP, level, score, and all upgrade multipliers (`move_speed`, `fire_rate`, `projectile_damage`, etc.). It emits signals (`xp_changed`, `level_changed`, `health_changed`, `game_over`, `level_up_triggered`, `score_changed`) that drive UI updates. Never modify player stats directly on the player node — go through GameState.

**HighScores** (`scripts/HighScores.gd`) is a singleton autoload. It persists the top 10 runs to `user://highscores.save` via `FileAccess.store_var`. Call `is_high_score(score)` before `add_score(name, score, level, kills, elapsed)` which returns the rank (1-based). Both autoloads are registered in `project.godot`.

**Main** (`scripts/Main.gd`, `scenes/Main.tscn`) owns the game loop. It holds named containers (`Enemies`, `Projectiles`, `XPOrbs`) which are exposed to other systems via groups (`"enemies_container"`, `"projectiles_container"`, `"xp_orbs_container"`). Wave spawning is driven by `SpawnTimer`; boss spawning by `BossTimer` (60 s). All audio players live here (`MusicPlayer`, `XPPickupSFX`, `LevelUpSFX`). `_ready()` also instantiates `BloodSmears` and the CRT post-process layer programmatically.

**Enemy** (`scripts/Enemy.gd`) handles both regular enemies and boss enemies via the `is_boss: bool` export. Set `is_boss = true` **before** `add_child()` so `_ready()` applies the 3× scale, larger collision shape, and orange tint. Bosses drop XP orbs, spawn a `BombPickup`, and vacuum all XP orbs on screen to the player on death. Animations are built entirely in code (`_build_animations()`) — the AnimationPlayer in the scene has no pre-authored clips.

**Wraith** (`scripts/Wraith.gd`) is a second-tier enemy that appears after 30 s of play (up to 50% of spawns by 90 s). It has lower HP than a demon but moves faster with a sinusoidal side-drift and a periodic lunge (3.5× speed for 0.35 s every 2–4 s). Shares the same `take_hit()` / `fire_kill()` / `apply_knockback()` interface as Enemy so projectiles and fire bombs work without modification. Both enemy types are spawned and stat-scaled by `Main._spawn_demon()` / `Main._spawn_wraith()`.

**Pickup pattern** — XPOrb and BombPickup both use manual distance checks in `_process()` against `get_first_node_in_group("player")`, not Area2D signals. This sidesteps collision-layer mismatches. Follow this pattern for any new pickups.

**LevelUpScreen** (`ui/LevelUpScreen.gd`) rebuilds its entire child tree on every `show_choices()` call (all children freed at the top). It instantiates `UpgradeCard` (`ui/UpgradeCard.gd`) — a `Button` subclass that emits `chosen(upgrade: Dictionary)` when clicked. Cards are constructed in code with `StyleBoxFlat` borders coloured by rarity. Blood/fire particle effects are `CPUParticles2D` nodes added as children here — they are automatically cleaned up on the next `show_choices()` call.

**Upgrade system** — `UpgradeData` (`scripts/UpgradeData.gd`) is a plain class (not autoloaded). It holds `ALL_UPGRADES` (array of Dicts), `RARITY_COLORS` (WoW-accurate: common white, uncommon `#1eff00`, rare `#0070dd`, epic `#a335ee`, legendary `#ff8000`), and `apply_upgrade()`. Adding a new upgrade means adding a Dict to `ALL_UPGRADES` and adding a match arm in `apply_upgrade()`.

**BoneSentry** (`scripts/BoneSentry.gd`) is a companion turret with no scene file — it is a plain `Node2D` instantiated from script via `Node2D.new(); set_script(BONE_SENTRY_SCRIPT)`. It draws itself entirely in `_draw()` and fires at the nearest enemy using the same projectile container as the player.

**BloodSmears** (`scripts/BloodSmears.gd`) manages persistent floor decals drawn in a single `_draw()` pass. Hard-capped at 150 smears (FIFO eviction); `queue_redraw()` is only called when a smear is added, so there is no per-frame redraw cost. Accessed by enemies via the group `"blood_smears"`. Bosses pass `scale_mul = 2.5` for a larger pool.

**CRT post-process** (`shaders/crt_effect.gdshader`) runs on a full-screen `ColorRect` inside a `CanvasLayer` at layer 128. The `UI` CanvasLayer (HUD + LevelUpScreen) is programmatically moved to layer 200 in `Main._setup_crt()` so it renders clean above the effect.

## Key Patterns

**Pause-safe nodes** — When the game pauses during level-up (`get_tree().paused = true`), any node that must keep running needs `process_mode = Node.PROCESS_MODE_ALWAYS`. The LevelUpScreen, its cards, and all particle effects added during level-up must have this set.

**Drawing** — Most game objects draw themselves via `_draw()` / `queue_redraw()` rather than using Sprite2D or textures. The player and enemies have sprites (`demon_basic.png`, `player*.png`) but everything else (projectiles, XP orbs, bomb pickup, HUD overlays) is procedural.

**Screen-flash overlays** — Temporary CanvasLayer nodes are created programmatically, tweened to alpha 0, then freed. See `BombPickup._explode()` and `Main._show_boss_warning()` for the pattern. These use layer 10, which sits below the CRT layer (128) and therefore gets the post-process applied.

**CanvasLayer ordering** — Layer 0–127: game world and world-space effects (flash overlays at 10, CRT at 128). Layer 200: `UI` CanvasLayer (HUD + LevelUpScreen). Do not add gameplay overlays above 128 or they will escape the CRT effect. Do not move the UI below 200 or it will be darkened by the CRT vignette.

**Collision layers** — Enemy CharacterBody2D is on layer 2 / mask 2. Projectile (Area2D) uses `body_entered` to detect enemies. Player is on the default layer. Do not modify the enemy's shared `CircleShape2D` resource; create a new one with `CircleShape2D.new()` when overriding collision size (as done for the boss).

**Adding new image/audio assets** — Godot requires a `.import` file and a compiled `.ctex` / `.sample` in `.godot/imported/` before a texture or audio file can be loaded at runtime. Run `--headless --import` to compile the asset, then manually write the `.import` file in the asset's directory mirroring the hash that Godot placed in `.godot/imported/`. See `assets/enemies/wraith.png.import` for a template. Opening the project in the editor will also auto-generate both files.

## Scene / Script Map

| Scene | Script | Role |
|---|---|---|
| `scenes/Main.tscn` | `scripts/Main.gd` | Game loop, spawning, audio, level-up flow |
| `scenes/Enemy.tscn` | `scripts/Enemy.gd` | Regular + boss enemies |
| `scenes/Player.tscn` | `scripts/Player.gd` | Movement, firing, damage, blood trail |
| `scenes/Projectile.tscn` | `scripts/Projectile.gd` | Area2D bullet; pierce support |
| `scenes/XPOrb.tscn` | `scripts/XPOrb.gd` | XP pickup with magnet attraction |
| `scenes/BombPickup.tscn` | `scripts/BombPickup.gd` | Fire bomb; kills all enemies on pickup |
| `scenes/BloodSplatter.tscn` | `scripts/BloodSplatter.gd` | One-shot CPUParticles2D death effect |
| `ui/LevelUpScreen.tscn` | `ui/LevelUpScreen.gd` | Upgrade card selection (builds UI in code) |
| `ui/HUD.tscn` | `ui/HUD.gd` | Health/XP/score bars; game-over screen |
| `scenes/Wraith.tscn` | `scripts/Wraith.gd` | Second-tier enemy; sinusoidal drift + lunge |
| *(no scene)* | `scripts/GameState.gd` | Autoload singleton — all player state |
| *(no scene)* | `scripts/HighScores.gd` | Autoload singleton — top-10 persistence to `user://` |
| *(no scene)* | `scripts/UpgradeData.gd` | Upgrade pool, rarity colours, apply logic |
| *(no scene)* | `scripts/BloodTrailDrop.gd` | Inline script for blood trail dots |
| *(no scene)* | `scripts/BoneSentry.gd` | Companion turret; Node2D created from script |
| *(no scene)* | `scripts/BloodSmears.gd` | Persistent floor smears; capped pool, group `"blood_smears"` |
| *(no scene)* | `scripts/Background.gd` | Procedural stone floor (tiles, cracks, bones, skulls) drawn once in `_draw()` |
| `ui/UpgradeCard.tscn` | `ui/UpgradeCard.gd` | Button subclass; emits `chosen(upgrade)` signal |
| *(no scene)* | `shaders/crt_effect.gdshader` | Full-screen post-process: vignette, scanlines, aberration, grain |
