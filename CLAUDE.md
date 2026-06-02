# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Running the Game

Godot is installed at `D:\GoDot\Godot_v4.6.3-stable_win64.exe`.

- **Run from CLI:** `"D:\GoDot\Godot_v4.6.3-stable_win64.exe" --path "C:\Claude\REPOS\Games\Giblets"`
- **Run in editor:** Open `project.godot` in Godot, press F5
- **No build step** — Godot parses GDScript at runtime; errors surface in the editor Output/Debugger panel

There are no tests or linters. Parser errors appear as red messages in the Godot debugger on launch.

## Architecture

**GameState** (`scripts/GameState.gd`) is a singleton autoload (registered in `project.godot`). It is the single source of truth for all mutable gameplay values: player stats, XP, level, score, and all upgrade multipliers (`move_speed`, `fire_rate`, `projectile_damage`, etc.). It emits signals (`xp_changed`, `level_changed`, `health_changed`, `game_over`, `level_up_triggered`, `score_changed`) that drive UI updates. Never modify player stats directly on the player node — go through GameState.

**Main** (`scripts/Main.gd`, `scenes/Main.tscn`) owns the game loop. It holds named containers (`Enemies`, `Projectiles`, `XPOrbs`) which are exposed to other systems via groups (`"enemies_container"`, `"projectiles_container"`, `"xp_orbs_container"`). Wave spawning is driven by `SpawnTimer`; boss spawning by `BossTimer` (60 s). All audio players live here (`MusicPlayer`, `XPPickupSFX`, `LevelUpSFX`).

**Enemy** (`scripts/Enemy.gd`) handles both regular enemies and boss enemies via the `is_boss: bool` export. Set `is_boss = true` **before** `add_child()` so `_ready()` applies the 3× scale, larger collision shape, and orange tint. Bosses drop 6 XP orbs worth 2 full levels and spawn a `BombPickup` on death. Animations are built entirely in code (`_build_animations()`) — the AnimationPlayer in the scene has no pre-authored clips.

**Pickup pattern** — XPOrb and BombPickup both use manual distance checks in `_process()` against `get_first_node_in_group("player")`, not Area2D signals. This sidesteps collision-layer mismatches. Follow this pattern for any new pickups.

**LevelUpScreen** (`ui/LevelUpScreen.gd`) rebuilds its entire child tree on every `show_choices()` call (all children freed at the top). Cards are constructed in code with `StyleBoxFlat` borders coloured by rarity. Blood/fire particle effects are `CPUParticles2D` nodes added as children here — they are automatically cleaned up on the next `show_choices()` call.

**Upgrade system** — `UpgradeData` (`scripts/UpgradeData.gd`) is a plain class (not autoloaded). It holds `ALL_UPGRADES` (array of Dicts), `RARITY_COLORS` (WoW-accurate: common white, uncommon `#1eff00`, rare `#0070dd`, epic `#a335ee`, legendary `#ff8000`), and `apply_upgrade()`. Adding a new upgrade means adding a Dict to `ALL_UPGRADES` and adding a match arm in `apply_upgrade()`.

## Key Patterns

**Pause-safe nodes** — When the game pauses during level-up (`get_tree().paused = true`), any node that must keep running needs `process_mode = Node.PROCESS_MODE_ALWAYS`. The LevelUpScreen, its cards, and all particle effects added during level-up must have this set.

**Drawing** — Most game objects draw themselves via `_draw()` / `queue_redraw()` rather than using Sprite2D or textures. The player and enemies have sprites (`demon_basic.png`, `player*.png`) but everything else (projectiles, XP orbs, bomb pickup, HUD overlays) is procedural.

**Screeen-flash overlays** — Temporary CanvasLayer nodes are created programmatically, tweened to alpha 0, then freed. See `BombPickup._explode()` and `Main._show_boss_warning()` for the pattern.

**Collision layers** — Enemy CharacterBody2D is on layer 2 / mask 2. Projectile (Area2D) uses `body_entered` to detect enemies. Player is on the default layer. Do not modify the enemy's shared `CircleShape2D` resource; create a new one with `CircleShape2D.new()` when overriding collision size (as done for the boss).

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
| *(no scene)* | `scripts/GameState.gd` | Autoload singleton — all player state |
| *(no scene)* | `scripts/UpgradeData.gd` | Upgrade pool, rarity colours, apply logic |
| *(no scene)* | `scripts/BloodTrailDrop.gd` | Inline script for blood trail dots |
