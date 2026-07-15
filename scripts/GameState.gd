extends Node

const WORLD_SIZE := Vector2(3840, 2160)

signal xp_changed(current_xp: int, required_xp: int)
signal level_changed(new_level: int)
signal health_changed(current_hp: int, max_hp: int)
signal score_changed(new_score: int)
signal game_over
signal level_up_triggered
signal sentry_summoned
signal shake_requested(strength: float, duration: float)
signal combo_changed(combo: int)

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

var score: int = 0
var enemies_killed: int = 0
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

var upgrade_stacks: Dictionary = {}  # upgrade id -> times taken this run

# Kill combo: kills chained within COMBO_WINDOW seconds. Cosmetic pressure
# feedback plus a small score multiplier (capped ×2 so it never dominates).
const COMBO_WINDOW := 2.0
const COMBO_SCORE_BONUS := 0.02  # +2% score per combo step
var combo: int = 0
var _combo_timer: float = 0.0

var _pending_level_ups: int = 0
var sentry_count: int = 0
var _regen_accum: float = 0.0
var _hitstop_cd: float = 0.0

func start_game() -> void:
	_reset()
	game_active = true

func _reset() -> void:
	player_level = 1
	player_xp = 0
	xp_to_next_level = xp_required(1)
	player_max_health = 100 + Meta.bonus_max_health()
	player_health = player_max_health
	elapsed_time = 0.0
	move_speed = 200.0 * Meta.bonus_move_speed_mul()
	projectile_damage = 15 + Meta.bonus_damage()
	projectile_speed = 400.0
	fire_rate = 1.5
	xp_magnet_range = 120.0 * Meta.bonus_magnet_mul()
	projectile_count = 1
	projectile_pierce = 0
	knockback_force = 0.0
	dash_cooldown_mul  = 1.0
	dash_distance_mul  = 1.0
	dash_knockback_mul = 1.0
	damage_mul = 1.0
	crit_chance = 0.0
	crit_mult = 2.0
	armor = 0
	regen_per_5s = 0.0
	xp_gain_mult = 1.0 * Meta.bonus_xp_mul()
	lifesteal_per_kill = 0
	explosive_pct = 0.0
	sentry_damage_mul = 0.5
	upgrade_stacks = {}
	_pending_level_ups = 0
	sentry_count = 0
	score = 0
	enemies_killed = 0
	damage_dealt = 0.0
	combo = 0
	_combo_timer = 0.0
	_regen_accum = 0.0
	_hitstop_cd = 0.0

# XP needed to go from `level` to `level + 1`.
func xp_required(level: int) -> int:
	var k := level - 1
	return XP_BASE + XP_LINEAR * k + XP_QUAD * k * k

# Expected player DPS at `minutes` into a run with average upgrade luck.
func dps_target(minutes: float) -> float:
	return DPS_BASE * exp(DPS_GROWTH_EXP * minutes)

func add_kill_score(enemy_xp: int) -> void:
	enemies_killed += 1
	combo += 1
	_combo_timer = COMBO_WINDOW
	combo_changed.emit(combo)
	var combo_mul: float = minf(1.0 + combo * COMBO_SCORE_BONUS, 2.0)
	score += int(enemy_xp * player_level * combo_mul)
	if lifesteal_per_kill > 0:
		heal(lifesteal_per_kill)
	score_changed.emit(score)

func _process(delta: float) -> void:
	if _hitstop_cd > 0.0:
		_hitstop_cd -= delta
	if not game_active:
		return
	elapsed_time += delta
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
