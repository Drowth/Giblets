extends Node

const WORLD_SIZE := Vector2(3840, 2160)

signal xp_changed(current_xp: int, required_xp: int)
signal level_changed(new_level: int)
signal health_changed(current_hp: int, max_hp: int)
signal score_changed(new_score: int)
signal game_over
signal level_up_triggered
signal sentry_summoned

var score: int = 0
var enemies_killed: int = 0

var player_level: int = 1
var player_xp: int = 0
var xp_to_next_level: int = 40
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

var _pending_level_ups: int = 0
var sentry_count: int = 0

func start_game() -> void:
	_reset()
	game_active = true

func _reset() -> void:
	player_level = 1
	player_xp = 0
	xp_to_next_level = 40
	player_health = 100
	player_max_health = 100
	elapsed_time = 0.0
	move_speed = 200.0
	projectile_damage = 15
	projectile_speed = 400.0
	fire_rate = 1.5
	xp_magnet_range = 120.0
	projectile_count = 1
	projectile_pierce = 0
	knockback_force = 0.0
	dash_cooldown_mul  = 1.0
	dash_distance_mul  = 1.0
	dash_knockback_mul = 1.0
	_pending_level_ups = 0
	sentry_count = 0
	score = 0
	enemies_killed = 0

func add_kill_score(enemy_xp: int) -> void:
	enemies_killed += 1
	score += enemy_xp * player_level
	score_changed.emit(score)

func _process(delta: float) -> void:
	if game_active:
		elapsed_time += delta

func add_xp(amount: int) -> void:
	player_xp += amount
	while player_xp >= xp_to_next_level:
		player_xp -= xp_to_next_level
		_do_level_up()
	xp_changed.emit(player_xp, xp_to_next_level)

func _do_level_up() -> void:
	player_level += 1
	xp_to_next_level = int(xp_to_next_level * 1.4)
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
	player_health = max(0, player_health - amount)
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
