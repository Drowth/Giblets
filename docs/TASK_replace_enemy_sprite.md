# Task: replace an enemy's sprite with an animated 8-directional character

Step-by-step recipe for swapping a static enemy sprite for an animated
8-directional character from the HD packs at `D:\Assets\2d\Characters\`.
This mirrors how the player was replaced with the Wizard — the finished
reference implementation is `scripts/WizardFrames.gd` + the animated branch in
`scripts/Player.gd` (`_apply_character_visuals`, `_dir_to_compass`,
`_play_anim`, `_facing`). Read those two files first; this task is mostly
"do the same thing to one enemy script".

## Step 0 — Decisions (ask the user if not already specified)

1. **Which enemy?** As of this writing, Brawler, Cyclops, Skull King boss,
   Butcher, Wraith, Imp, and BoneCharger are all already animated
   (`WizardFrames.build`) — check `CLAUDE.md`'s enemy roster table before
   assuming a target is untouched. `Spider.gd` is the remaining simple target
   — it owns exactly one enemy with its own scene + Sprite2D.
   ⚠️ `Enemy.gd` serves THREE variants (Brawler, Cyclops, Skull King boss) —
   replacing its sprite changes all three unless each variant gets its own
   frame set (see `is_cyclops`/`is_boss` branches in `_ready()`). A boss with
   a state machine (like `Butcher.gd`) or a fully-procedural enemy (like
   `BoneCharger.gd` was) is not off-limits — map each state to a distinct
   animation and keep any procedural telegraph overlays (charge aim line,
   death-burst pulse) that don't come from the sprite pack.
2. **Which pack character?** A folder like
   `D:\Assets\2d\Characters\2D HD Character pack 1\2D HD Character pack 1\<N><Name>`.
   Verify its structure matches the Wizard's: `<Anim>\{E,N,NE,NW,S,SE,SW,W}\*.png`,
   128×128 frames.
3. **Which animations?** Core enemy set: `Idle`, `Run` (or `Walk` for slow
   enemies), `Die`, `TakeDamage`. Do NOT copy the whole pack (53 MB); the core
   set is ~600 files / ~9 MB. Map them to folder names `idle`, `run`, `die`,
   `hurt`.

## Step 1 — Copy + normalize frames

Copy into `res://assets/enemies/<enemyname>/<anim>/<dir>/`, renaming frames to
`001.png`, `002.png`, … (source names embed angle numbers — normalizing makes
the loader trivial). PowerShell template (adjust paths/mapping):

```powershell
$src = "D:\Assets\2d\Characters\2D HD Character pack 1\2D HD Character pack 1\<N><Name>"
$dst = "C:\Claude\REPOS\Games\Giblets\assets\enemies\<enemyname>"
$animMap = @{ "Idle"="idle"; "Run"="run"; "Die"="die"; "TakeDamage"="hurt" }
foreach ($srcAnim in $animMap.Keys) {
  foreach ($dir in @("E","N","NE","NW","S","SE","SW","W")) {
    $outDir = Join-Path $dst "$($animMap[$srcAnim])\$dir"
    New-Item -ItemType Directory -Force $outDir | Out-Null
    $i = 1
    foreach ($f in (Get-ChildItem "$src\$srcAnim\$dir" -File -Filter *.png | Sort-Object Name)) {
      Copy-Item $f.FullName (Join-Path $outDir ("{0:d3}.png" -f $i)); $i++
    }
  }
}
```

Then bulk-import (also regenerates the global class cache — required whenever
a new `class_name` script is added, or autoloads fail to parse):

```powershell
& "C:\Claude\REPOS\Games\Giblets\Godot_v4.7-stable_win64.exe" --path "C:\Claude\REPOS\Games\Giblets" --headless --import
```

Do NOT hand-write `.import` files for bulk adds — the import pass generates
all of them.

## Step 2 — Generalize the frames builder (small refactor)

`scripts/WizardFrames.gd` currently hardcodes the wizard's path. Refactor it
into a generic builder (keep the class name and the wizard entry point so
Player.gd is untouched):

- `static func build(base_path: String, anims: Dictionary) -> SpriteFrames` —
  the existing loop, parameterized; cache per `base_path` in a static Dictionary.
- Keep `static func get_frames()` returning
  `build("res://assets/player/wizard", ANIMS)`.
- The new enemy calls
  `WizardFrames.build("res://assets/enemies/<enemyname>", {"idle":[10.0,true],"run":[16.0,true],"die":[15.0,false],"hurt":[20.0,false]})`.
- Frame-count probing MUST use `ResourceLoader.exists(path)` (works in
  exported PCK builds; `DirAccess` does not).

## Step 3 — Enemy scene + script changes

**Scene** (`scenes/<Enemy>.tscn`): add below the existing `Sprite2D`:

```
[node name="AnimSprite" type="AnimatedSprite2D" parent="."]
visible = false
```

**Script** (`scripts/<Enemy>.gd`) — follow the Player.gd pattern:

1. `@onready var anim_sprite: AnimatedSprite2D = $AnimSprite` and
   `var _facing: String = "S"`.
2. In `_ready()`: hide `sprite`, show `anim_sprite`, set
   `anim_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR` (the
   project default is `nearest` for pixel art — HD frames need linear), set
   `anim_sprite.sprite_frames = WizardFrames.build(...)`, set scale
   (start at `0.7` for a demon-sized enemy — the old sprites are ~40–60 px
   world height and the figure fills ~80 px of the 128 canvas; tune visually),
   and `anim_sprite.play("idle_S")`.
   ⚠️ Do NOT remove `motion_mode = CharacterBody2D.MOTION_MODE_FLOATING` —
   it prevents a physics NaN bug.
3. Copy `_dir_to_compass(v: Vector2) -> String` and `_play_anim(state)`
   verbatim from Player.gd (they're 10 lines; per-file copies match this
   codebase's style — each enemy already duplicates its interface).
4. In `_physics_process`, where the script currently sets
   `_last_dir = velocity.normalized()` (guarded by `velocity.length() > 5.0`):
   also set `_facing = _dir_to_compass(_last_dir)`, then drive
   `_play_anim("run" if moving else "idle")`. Remove/guard the old
   `anim_player.play("walk"/"idle"/"float")` calls and `sprite.flip_h` /
   `sprite.rotation` writes — the 8-directional frames replace flips.
5. `take_hit()`: replace `anim_player.play("hurt")` with `_play_anim("hurt")`;
   the existing `await 0.25s` then return-to-walk still works — just have the
   post-await line call `_play_anim("run")` instead of `anim_player.play(...)`.
6. `_die()`: replace `anim_player.play("death")` with `_play_anim("die")`.
   Check the timing: `_die()` awaits **0.6 s** before `queue_free()`. A
   15-frame die animation at 15 fps runs 1.0 s (gets cut). Either raise die
   fps to ~25 (0.6 s) or extend that one enemy's await to match — pick one,
   don't leave the animation visibly truncated.
   `fire_kill()` frees immediately (bomb clear) — no animation needed there.
7. Leave `_draw()` (health bar) untouched — it draws on the body, not the
   sprite. Leave `_spawn_blood`, knockback, and the `take_hit/fire_kill/
   apply_knockback` interface exactly as they are.

## Step 4 — Check for texture references elsewhere

Grep the target scene/script name across `scripts/` and `scenes/` for
anything else referencing the old texture (e.g. `Main._spawn_cyclops` swaps
`enemy.sprite.texture` — only relevant if targeting Enemy.gd). The old
static texture in `assets/enemies/` stays (other things may use it; removal
is out of scope).

## Step 5 — Docs

- CLAUDE.md: update the enemy's row in the roster table + Scene/Script Map if
  its description mentions the old look; note it now uses the
  `WizardFrames.build` animated path.
- No BALANCE.md changes (visual-only — stats untouched).

## Verification

1. `--headless --import` exits clean (already run in step 1; rerun after the
   WizardFrames refactor so the class cache updates).
2. Smoke: `--headless --quit-after 60 res://scenes/Main.tscn` → zero
   `SCRIPT ERROR` lines.
3. Soak: `$env:GIBLETS_SOAK='1'` + headless `res://scenes/Main.tscn` → must
   reach "SOAK: reached 12 min clean" with zero errors (exercises the enemy's
   animation driver at the 130-enemy cap; catches missing-frame loads).
4. Ask the user to play: enemy faces its movement direction in all 8
   compass directions, hurt flinch on hit, death animation plays fully
   (not truncated), scale looks right next to the player and other enemies.
