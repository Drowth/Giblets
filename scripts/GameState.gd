extends Node

const WORLD_SIZE := Vector2(3840, 2160)

# Non-rectangular stages (e.g. City's isometric diamond ground) confine
# movement/spawns to this convex polygon instead of the WORLD_SIZE rect.
# Empty = rectangular WORLD_SIZE bounds (the default). Set once per run by
# Main._setup_stage_floor(); world-space, vertices in a simple (non-crossing)
# winding order.
var stage_bounds_polygon: PackedVector2Array = PackedVector2Array()
var _stage_bounds_inset_cache: Dictionary = {}

func set_stage_bounds(poly: PackedVector2Array) -> void:
	stage_bounds_polygon = poly
	_stage_bounds_inset_cache.clear()

# Axis-aligned bounding rect of the current stage bounds — used for camera
# limits (Camera2D can't clip to an arbitrary polygon).
func stage_bounds_rect() -> Rect2:
	if stage_bounds_polygon.is_empty():
		return Rect2(Vector2.ZERO, WORLD_SIZE)
	var min_pt := stage_bounds_polygon[0]
	var max_pt := stage_bounds_polygon[0]
	for p in stage_bounds_polygon:
		min_pt = min_pt.min(p)
		max_pt = max_pt.max(p)
	return Rect2(min_pt, max_pt - min_pt)

# Clamps pos to stay `margin` px inside the stage bounds — a rectangle clamp
# when there's no polygon (identical to the old WORLD_SIZE clampf calls), or
# a nearest-point-on-convex-polygon clamp when one is set.
func clamp_to_stage_bounds(pos: Vector2, margin: float = 0.0) -> Vector2:
	if stage_bounds_polygon.is_empty():
		return Vector2(
			clampf(pos.x, margin, WORLD_SIZE.x - margin),
			clampf(pos.y, margin, WORLD_SIZE.y - margin)
		)
	var poly := _inset_stage_bounds(margin)
	if poly.size() < 3 or Geometry2D.is_point_in_polygon(pos, poly):
		return pos
	var closest := poly[poly.size() - 1]
	var best_dist := INF
	for i in poly.size():
		var a: Vector2 = poly[i]
		var b: Vector2 = poly[(i + 1) % poly.size()]
		var c: Vector2 = Geometry2D.get_closest_point_to_segment(pos, a, b)
		var d := pos.distance_squared_to(c)
		if d < best_dist:
			best_dist = d
			closest = c
	return closest

func _inset_stage_bounds(margin: float) -> PackedVector2Array:
	if margin <= 0.0:
		return stage_bounds_polygon
	if not _stage_bounds_inset_cache.has(margin):
		var offset := Geometry2D.offset_polygon(stage_bounds_polygon, -margin)
		_stage_bounds_inset_cache[margin] = offset[0] if not offset.is_empty() else stage_bounds_polygon
	return _stage_bounds_inset_cache[margin]

signal xp_changed(current_xp: int, required_xp: int)
signal level_changed(new_level: int)
signal health_changed(current_hp: int, max_hp: int)
signal score_changed(new_score: int)
signal game_over
signal level_up_triggered
signal sentry_summoned
signal temp_sentry_summoned(lifespan: float)  # Bone Harvest: temporary sentry from a dash kill
signal blood_nova_requested  # Exsanguinate: every 8th kill
signal shake_requested(strength: float, duration: float)
signal combo_changed(combo: int)
signal second_wind_triggered  # Death Defiance talent saved the player

# --- XP curve (docs/BALANCE.md §2) ---------------------------------------
# Quadratic, not exponential: keeps late levels arriving ~1/min instead of
# stalling the run at L12-15 like the old ×1.4 curve did.
const XP_BASE:   int = 30
const XP_LINEAR: int = 45
const XP_QUAD:   int = 22

# --- Player DPS budget (docs/BALANCE.md §1) -------------------------------
# Anchor curve that boss HP is derived from. DPS_BASE matches the actual
# starting kit (15 dmg × 1.5/s = 22.5) plus meta unlocks. Growth is
# exponential because upgrade picks compound multiplicatively — BalanceSim
# measured ~3.3× effective DPS per 5 minutes for a median build.
const DPS_BASE:       float = 24.0
const DPS_GROWTH_EXP: float = 0.24  # per minute, e^(k·m) growth

# --- Hit-stop budget (docs/BALANCE.md §7) ---------------------------------
# Kill-gated with a cooldown so multishot volleys read as one impact instead
# of freezing the game 20% of wall-clock at late-game fire rates.
const HITSTOP_KILL:     float = 0.025
const HITSTOP_BOSS:     float = 0.08
const HITSTOP_COOLDOWN: float = 0.15

# Kill/hit SFX: gated the same way as hit-stop so a wave of simultaneous
# impacts reads as a steady crunch instead of a dozen overlapping samples.
const KILL_SFX_COOLDOWN: float = 0.05
const HIT_SFX_COOLDOWN:  float = 0.04
const KILL_SOUNDS := [
	"res://assets/sfx/combat/kill_1.wav",
	"res://assets/sfx/combat/kill_2.wav",
]
const HIT_SOUNDS := [
	"res://assets/sfx/combat/hit_1.wav",
	"res://assets/sfx/combat/hit_2.wav",
	"res://assets/sfx/combat/hit_3.wav",
]

# --- Corpse persistence (docs/BALANCE.md §?) --------------------------------
# Bodies linger longer early game for visual feedback, then scale down with
# enemy density so late-game hordes don't become a performance burden.
const CORPSE_LINGER_PER_ENEMY := 0.04  # seconds removed per living enemy
const CORPSE_LINGER_MIN := 0.3

var _kill_sfx_cd: float = 0.0
var _hit_sfx_cd: float = 0.0

var score: int = 0
var enemies_killed: int = 0
var bosses_killed: int = 0     # feeds the giblet boss bonus + roulette milestone
var damage_dealt: float = 0.0  # lifetime damage this run, for death-screen DPS

var player_level: int = 1
var player_xp: int = 0
var xp_to_next_level: int = XP_BASE
var player_health: int = 100
var player_max_health: int = 100
var elapsed_time: float = 0.0
var game_active: bool = false

var move_speed: float = 200.0
var projectile_damage: int = 15
var projectile_speed: float = 400.0
var fire_rate: float = 1.5
var xp_magnet_range: float = 120.0
var projectile_count: int = 1
var projectile_pierce: int = 0
var knockback_force: float = 0.0
var dash_cooldown_mul: float = 1.0
var dash_distance_mul: float = 1.0
var dash_knockback_mul: float = 1.0

# Build-archetype stats (docs/BALANCE.md §5)
var damage_mul: float = 1.0          # multiplicative damage (Heavy Calibre etc.)
var crit_chance: float = 0.0         # 0..1, capped 0.6 via upgrade max_stacks
var crit_mult: float = 2.0           # Deathmark raises to 3.0
var armor: int = 0                   # flat damage reduction, min 1 taken
var regen_per_5s: float = 0.0        # HP per 5 seconds
var xp_gain_mult: float = 1.0
var lifesteal_per_kill: int = 0
var explosive_pct: float = 0.0       # fraction of hit dmg dealt as AoE (Hellfire)
var sentry_damage_mul: float = 0.5   # Bone Legion raises to 1.0

# Quirk stats (docs/BALANCE.md §5 — the strange ones)
var rear_shot: bool = false          # Eyes in the Back: extra projectile backwards
var orb_heal: int = 0                # Bone Broth: HP healed per XP orb
var dash_vacuum: bool = false        # Grave Robber: dash magnetizes all orbs
var kill_speed_burst: bool = false   # Adrenal Gland: kills grant a speed burst
var hurt_nova_level: int = 0         # Tantrum: retaliatory nova on taking a hit
var level_up_choices: int = 3        # Third Eye raises to 4
var dash_damage_pct: float = 0.0     # Phase Ripper: dash damage as fraction of weapon dmg
var ricochet_bounces: int = 0        # Wishbone: spent projectiles retarget
var bloodlust: bool = false          # +0.5%/combo damage, capped +50%
var _speed_burst_timer: float = 0.0
var exsanguinate_enabled: bool = false  # Vampire passive: nova every 8th kill
var _exsanguinate_counter: int = 0

const SPEED_BURST_MUL      := 1.4
const SPEED_BURST_DURATION := 1.5
const BLOODLUST_PER_COMBO  := 0.005
const BLOODLUST_CAP        := 0.5

# Weapon damage multiplier including Bloodlust's combo frenzy. Player-driven
# attacks (projectiles, dash damage, nova) use this; sentries stay on the
# plain damage_mul (frenzy is the player's, not the skull's).
func attack_damage_mul() -> float:
	var mul := damage_mul
	if bloodlust:
		mul *= 1.0 + minf(combo * BLOODLUST_PER_COMBO, BLOODLUST_CAP)
	return mul

# Move speed including Adrenal Gland's kill burst; Player reads this.
func current_move_speed() -> float:
	return move_speed * (SPEED_BURST_MUL if _speed_burst_timer > 0.0 else 1.0)

var upgrade_stacks: Dictionary = {}  # upgrade id -> times taken this run
var draw_bias: Dictionary = {}       # upgrade id -> weight mult in level-up draws (from character)
var _second_wind_used: bool = false  # Death Defiance fires once per run

# Kill combo: kills chained within COMBO_WINDOW seconds. Cosmetic pressure
# feedback plus a small score multiplier (capped ×2 so it never dominates).
const COMBO_WINDOW := 2.0
const COMBO_SCORE_BONUS := 0.02  # +2% score per combo step
var combo: int = 0
var _combo_timer: float = 0.0

var _pending_level_ups: int = 0
var sentry_count: int = 0
var temp_sentry_count: int = 0  # Bone Harvest: temporary sentries counted against their own cap
var _regen_accum: float = 0.0
var _hitstop_cd: float = 0.0

func start_game() -> void:
	_reset()
	game_active = true

func _reset() -> void:
	player_level = 1
	player_xp = 0
	xp_to_next_level = xp_required(1)
	# Base floors + permanent talent bonuses (Meta) — all additive, never on
	# the multiplicative DPS path (docs/DESIGN.md).
	player_max_health = 100 + Meta.bonus_max_health()
	elapsed_time = 0.0
	move_speed = 200.0 * Meta.bonus_move_speed_mul()
	projectile_damage = 15 + Meta.bonus_damage()
	projectile_speed = 400.0 + Meta.bonus_proj_speed()
	fire_rate = 1.5
	xp_magnet_range = 120.0 * Meta.bonus_magnet_mul()
	projectile_count = 1
	projectile_pierce = 0
	knockback_force = 0.0 + Meta.bonus_knockback()
	dash_cooldown_mul  = 1.0 * Meta.bonus_dash_cd_mul()
	dash_distance_mul  = 1.0
	dash_knockback_mul = 1.0
	damage_mul = 1.0
	crit_chance = 0.0
	crit_mult = 2.0
	armor = 0 + Meta.bonus_armor()
	regen_per_5s = 0.0 + Meta.bonus_regen()
	xp_gain_mult = 1.0 * Meta.bonus_xp_mul()
	lifesteal_per_kill = 0
	explosive_pct = 0.0
	sentry_damage_mul = 0.5
	rear_shot = false
	orb_heal = 0
	dash_vacuum = false
	kill_speed_burst = false
	hurt_nova_level = 0
	level_up_choices = 3
	dash_damage_pct = 0.0
	ricochet_bounces = 0
	bloodlust = false
	_speed_burst_timer = 0.0
	exsanguinate_enabled = false
	_exsanguinate_counter = 0
	upgrade_stacks = {}
	_pending_level_ups = 0
	sentry_count = 0
	temp_sentry_count = 0
	# Character: additive stat deltas, then passive starting values, then the
	# level-up draw bias (CharacterData.gd).
	var character := CharacterData.get_selected()
	var deltas: Dictionary = character["deltas"]
	player_max_health += int(deltas.get("max_health", 0))
	projectile_damage += int(deltas.get("projectile_damage", 0))
	move_speed += float(deltas.get("move_speed", 0.0))
	var passive: Dictionary = character["passive"]
	crit_chance += float(passive.get("crit_chance", 0.0))
	sentry_count += int(passive.get("sentry_count", 0))
	lifesteal_per_kill += int(passive.get("lifesteal_per_kill", 0))
	dash_damage_pct += float(passive.get("dash_damage_pct", 0.0))
	exsanguinate_enabled = bool(passive.get("exsanguinate_enabled", 0.0) > 0.0)
	draw_bias = character["draw_bias"]
	player_health = player_max_health
	score = 0
	enemies_killed = 0
	bosses_killed = 0
	damage_dealt = 0.0
	combo = 0
	_combo_timer = 0.0
	_regen_accum = 0.0
	_hitstop_cd = 0.0
	_second_wind_used = false

# XP needed to go from `level` to `level + 1`.
func xp_required(level: int) -> int:
	var k := level - 1
	return XP_BASE + XP_LINEAR * k + XP_QUAD * k * k

# Expected player DPS at `minutes` into a run with average upgrade luck.
func dps_target(minutes: float) -> float:
	return DPS_BASE * exp(DPS_GROWTH_EXP * minutes)

func add_kill_score(enemy_xp: int, is_boss: bool = false) -> void:
	enemies_killed += 1
	if is_boss:
		bosses_killed += 1
	combo += 1
	_combo_timer = COMBO_WINDOW
	combo_changed.emit(combo)
	var combo_mul: float = minf(1.0 + combo * COMBO_SCORE_BONUS, 2.0)
	score += int(enemy_xp * player_level * combo_mul)
	if lifesteal_per_kill > 0:
		heal(lifesteal_per_kill)
	if exsanguinate_enabled:
		_exsanguinate_counter += 1
		if _exsanguinate_counter >= 8:
			_exsanguinate_counter = 0
			blood_nova_requested.emit()
	if kill_speed_burst:
		_speed_burst_timer = SPEED_BURST_DURATION
	score_changed.emit(score)
	if _kill_sfx_cd <= 0.0:
		_kill_sfx_cd = KILL_SFX_COOLDOWN
		Sfx.play_random(KILL_SOUNDS, -10.0, 0.15)

# Rate-limited projectile impact SFX — called from Projectile on every hit.
func play_hit_sfx(is_crit: bool) -> void:
	if _hit_sfx_cd > 0.0:
		return
	_hit_sfx_cd = HIT_SFX_COOLDOWN
	Sfx.play_random(HIT_SOUNDS, -16.0 if not is_crit else -10.0, 0.2)

func _process(delta: float) -> void:
	if _hitstop_cd > 0.0:
		_hitstop_cd -= delta
	if _kill_sfx_cd > 0.0:
		_kill_sfx_cd -= delta
	if _hit_sfx_cd > 0.0:
		_hit_sfx_cd -= delta
	if not game_active:
		return
	elapsed_time += delta
	if _speed_burst_timer > 0.0:
		_speed_burst_timer -= delta
	if _combo_timer > 0.0:
		_combo_timer -= delta
		if _combo_timer <= 0.0 and combo > 0:
			combo = 0
			combo_changed.emit(0)
	if regen_per_5s > 0.0 and player_health < player_max_health:
		_regen_accum += regen_per_5s / 5.0 * delta
		if _regen_accum >= 1.0:
			var whole := int(_regen_accum)
			_regen_accum -= whole
			heal(whole)

func add_xp(amount: int) -> void:
	player_xp += int(amount * xp_gain_mult)
	while player_xp >= xp_to_next_level:
		player_xp -= xp_to_next_level
		_do_level_up()
	xp_changed.emit(player_xp, xp_to_next_level)

func _do_level_up() -> void:
	player_level += 1
	xp_to_next_level = xp_required(player_level)
	level_changed.emit(player_level)
	_pending_level_ups += 1
	level_up_triggered.emit()

func consume_level_up() -> void:
	_pending_level_ups = max(0, _pending_level_ups - 1)

func has_pending_level_up() -> bool:
	return _pending_level_ups > 0

func take_damage(amount: int) -> void:
	if not game_active:
		return
	var reduced: int = max(1, amount - armor)
	player_health = max(0, player_health - reduced)
	if player_health <= 0 and Meta.has_second_wind() and not _second_wind_used:
		# Death Defiance: cheat death once per run at 1 HP.
		_second_wind_used = true
		player_health = 1
		health_changed.emit(player_health, player_max_health)
		second_wind_triggered.emit()
		return
	health_changed.emit(player_health, player_max_health)
	if player_health <= 0:
		game_active = false
		game_over.emit()

func heal(amount: int) -> void:
	player_health = min(player_max_health, player_health + amount)
	health_changed.emit(player_health, player_max_health)

func increase_max_health(amount: int) -> void:
	player_max_health += amount
	player_health = min(player_health + amount, player_max_health)
	health_changed.emit(player_health, player_max_health)

func screen_shake(strength: float, duration: float) -> void:
	shake_requested.emit(strength, duration)

var _hitstop_depth: int = 0

# Kill-gated hit-stop. Called by enemies from _die(); never per-hit.
func kill_hitstop(boss: bool = false) -> void:
	if not boss and _hitstop_cd > 0.0:
		return
	_hitstop_cd = HITSTOP_COOLDOWN
	hitstop(HITSTOP_BOSS if boss else HITSTOP_KILL)

func hitstop(duration: float) -> void:
	if not game_active or get_tree().paused:
		return
	_hitstop_depth += 1
	Engine.time_scale = 0.0
	await get_tree().create_timer(duration, true, false, true).timeout
	_hitstop_depth -= 1
	if _hitstop_depth <= 0:
		_hitstop_depth = 0
		Engine.time_scale = 1.0

# How long a dead enemy body should persist after its death animation.
# Scales down with living enemy count so late-game hordes don't pile up.
func get_corpse_linger(base: float) -> float:
	var enemy_count := get_tree().get_nodes_in_group("enemies").size()
	return maxf(CORPSE_LINGER_MIN, base - enemy_count * CORPSE_LINGER_PER_ENEMY)
