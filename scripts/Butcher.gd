extends CharacterBody2D

# The Butcher — second boss, alternates with the Skull King on the 60 s boss
# timer (docs/BALANCE.md §4). Distinct pattern: circles the player at
# mid-range, then telegraphs and charges across the arena. Forces sustained
# repositioning where the Skull King only asks for kiting. Trades 20% HP for
# the charge threat (BUTCHER_HP_MUL in Main.gd).

const XP_ORB_SCENE = preload("res://scenes/XPOrb.tscn")
const BLOOD_SCENE  = preload("res://scenes/BloodSplatter.tscn")
const BOMB_SCENE   = preload("res://scenes/BombPickup.tscn")

@export var move_speed: float = 70.0
@export var max_health: int   = 1000
@export var health:     int   = 1000
@export var damage:     int   = 30
@export var xp_value:   int   = 500
@export var contact_cooldown: float = 0.8

const ORBIT_RADIUS      := 220.0
const CHARGE_SPEED      := 420.0
const CHARGE_TRAVEL     := 700.0
const WINDUP_DURATION   := 1.0
const ORBIT_DURATION_MIN := 4.0
const ORBIT_DURATION_MAX := 6.0
const SPRITE_SCALE      := Vector2(6.0, 6.0)
const BUTCHER_TINT      := Color(1.0, 0.35, 0.35)

enum State { ORBIT, WINDUP, CHARGE }

var _player:        Node2D  = null
var _contact_timer: float   = 0.0
var _dead:          bool    = false
var _xp_container:  Node    = null
var _state:         State   = State.ORBIT
var _state_timer:   float   = 0.0
var _orbit_sign:    float   = 1.0
var _charge_dir:    Vector2 = Vector2.ZERO
var _charge_left:   float   = 0.0
var _anim_time:     float   = 0.0
var _last_dir:      Vector2 = Vector2.DOWN

@onready var sprite: Sprite2D = $Sprite2D

func _ready() -> void:
	add_to_group("enemies")
	add_to_group("bosses")
	health = max_health
	_player = get_tree().get_first_node_in_group("player")
	sprite.texture  = load("res://assets/enemies/cyclops.png")
	sprite.scale    = SPRITE_SCALE
	sprite.modulate = BUTCHER_TINT
	_state_timer = randf_range(ORBIT_DURATION_MIN, ORBIT_DURATION_MAX)
	_orbit_sign  = 1.0 if randf() < 0.5 else -1.0

func _physics_process(delta: float) -> void:
	_anim_time += delta
	queue_redraw()
	if _dead:
		return
	if not _player or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player")
		return

	_contact_timer = maxf(0.0, _contact_timer - delta)
	_state_timer  -= delta

	match _state:
		State.ORBIT:
			var to_player := _player.global_position - global_position
			var dist := to_player.length()
			var dir  := to_player.normalized()
			var perp := Vector2(-dir.y, dir.x) * _orbit_sign
			# Spiral toward/away from the orbit ring while circling
			var radial := dir * clampf((dist - ORBIT_RADIUS) * 0.02, -1.0, 1.0)
			velocity = (perp + radial).normalized() * move_speed
			sprite.modulate = BUTCHER_TINT
			if _state_timer <= 0.0:
				_state = State.WINDUP
				_state_timer = WINDUP_DURATION
		State.WINDUP:
			velocity = Vector2.ZERO
			var flash := 0.5 + 0.5 * sin(_anim_time * 25.0)
			sprite.modulate = BUTCHER_TINT.lerp(Color(3.0, 0.5, 0.5), flash)
			if _state_timer <= 0.0:
				_state = State.CHARGE
				_charge_dir  = (_player.global_position - global_position).normalized()
				_charge_left = CHARGE_TRAVEL
				sprite.modulate = BUTCHER_TINT
		State.CHARGE:
			velocity = _charge_dir * CHARGE_SPEED
			_charge_left -= CHARGE_SPEED * delta
			if _charge_left <= 0.0 or _hit_wall():
				_state = State.ORBIT
				_state_timer = randf_range(ORBIT_DURATION_MIN, ORBIT_DURATION_MAX)
				_orbit_sign = -_orbit_sign
	move_and_slide()
	global_position.x = clampf(global_position.x, 30.0, GameState.WORLD_SIZE.x - 30.0)
	global_position.y = clampf(global_position.y, 30.0, GameState.WORLD_SIZE.y - 30.0)

	if velocity.length() > 5.0:
		_last_dir = velocity.normalized()
		sprite.flip_h = velocity.x < -5.0

	var hit_range := 45.0 if _state == State.CHARGE else 38.0
	if global_position.distance_to(_player.global_position) < hit_range and _contact_timer <= 0.0:
		_contact_timer = contact_cooldown
		if _player.has_method("take_damage"):
			_player.take_damage(damage)

func _hit_wall() -> bool:
	return (global_position.x <= 31.0 or global_position.x >= GameState.WORLD_SIZE.x - 31.0
		or global_position.y <= 31.0 or global_position.y >= GameState.WORLD_SIZE.y - 31.0)

func _draw() -> void:
	if _dead:
		return
	# Charge telegraph line during windup
	if _state == State.WINDUP and _player and is_instance_valid(_player):
		var dir := to_local(_player.global_position).normalized()
		var flash := 0.25 + 0.35 * (0.5 + 0.5 * sin(_anim_time * 25.0))
		draw_line(dir * 40.0, dir * CHARGE_TRAVEL, Color(1.0, 0.1, 0.1, flash), 4.0)
	var hp_ratio := float(health) / float(max_health) if max_health > 0 else 0.0
	draw_rect(Rect2(-32, -66, 64, 7), Color(0.12, 0.0, 0.0))
	draw_rect(Rect2(-32, -66, 64.0 * hp_ratio, 7), Color(0.9, 0.1, 0.1))
	var font := ThemeDB.fallback_font
	draw_string(font, Vector2(-24, -71), "BUTCHER", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(1.0, 0.3, 0.3))

func apply_knockback(_dir: Vector2, force: float) -> void:
	if _dead or _state == State.CHARGE:
		return
	# Bosses barely budge
	global_position += _dir * force * 0.02

func take_hit(dmg: int) -> void:
	if _dead:
		return
	health -= dmg
	queue_redraw()
	var tw := sprite.create_tween()
	tw.tween_property(sprite, "modulate", Color(4.0, 4.0, 4.0), 0.03)
	tw.tween_property(sprite, "modulate", BUTCHER_TINT, 0.1)
	if health <= 0:
		_die()

func fire_kill() -> void:
	# Fire bombs chunk bosses for 25% max HP instead of instakilling them
	if _dead:
		return
	take_hit(int(max_health * 0.25))

func _die() -> void:
	_dead = true
	set_physics_process(false)
	$CollisionShape2D.set_deferred("disabled", true)
	remove_from_group("enemies")
	GameState.add_kill_score(xp_value)
	GameState.kill_hitstop(true)
	GameState.screen_shake(70.0, 0.35)
	_spawn_blood()
	_drop_xp()
	_spawn_bomb()
	_vacuum_xp_orbs()
	var tw := sprite.create_tween()
	tw.tween_property(sprite, "scale", Vector2.ZERO, 0.45)
	tw.parallel().tween_property(sprite, "rotation", TAU, 0.45)
	await get_tree().create_timer(0.5).timeout
	queue_free()

func _spawn_blood() -> void:
	var splat = BLOOD_SCENE.instantiate()
	get_parent().add_child(splat)
	splat.global_position = global_position
	var smears := get_tree().get_first_node_in_group("blood_smears")
	if smears:
		smears.add_smear(global_position, _last_dir, 2.5)

func _drop_xp() -> void:
	if not _xp_container or not is_instance_valid(_xp_container):
		_xp_container = get_tree().get_first_node_in_group("xp_orbs_container")
	if not _xp_container:
		return
	# Boss XP ≈ 90% of a level at current progression (docs/BALANCE.md §4)
	var orb_xp := int(GameState.xp_to_next_level * 0.3)
	for _i in 3:
		var orb = XP_ORB_SCENE.instantiate()
		_xp_container.add_child(orb)
		orb.global_position = global_position + Vector2(randf_range(-50, 50), randf_range(-50, 50))
		orb.xp_value = orb_xp

func _vacuum_xp_orbs() -> void:
	var container := get_tree().get_first_node_in_group("xp_orbs_container")
	if not container:
		return
	for orb in container.get_children():
		orb._attracted = true
		orb._attract_speed = 80.0

func _spawn_bomb() -> void:
	var bomb = BOMB_SCENE.instantiate()
	get_tree().current_scene.add_child(bomb)
	bomb.global_position = global_position
