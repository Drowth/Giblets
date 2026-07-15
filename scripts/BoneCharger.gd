extends CharacterBody2D

# Bone Charger — movement-forcing enemy (docs/BALANCE.md §3). Shambles toward
# the player, periodically wind-ups (flash, freeze) then charges in a locked
# direction. On death its ribcage detonates after a short fuse, punishing
# players who stand on the corpse. Entirely procedural _draw() — no sprite
# asset exists for it.

const XP_ORB_SCENE = preload("res://scenes/XPOrb.tscn")
const BLOOD_SCENE  = preload("res://scenes/BloodSplatter.tscn")

@export var move_speed:       float = 40.0
@export var max_health:       int   = 35
@export var health:           int   = 35
@export var xp_value:         int   = 30
@export var damage:           int   = 18
@export var contact_cooldown: float = 0.8

const CHARGE_MULT      := 4.5
const CHARGE_DURATION  := 0.6
const WINDUP_DURATION  := 0.7
const CHARGE_INTERVAL_MIN := 3.0
const CHARGE_INTERVAL_MAX := 5.0
const BURST_RADIUS     := 60.0   # death explosion
const BURST_FUSE       := 0.5

enum State { WALK, WINDUP, CHARGE }

var _player:        Node2D  = null
var _contact_timer: float   = 0.0
var _dead:          bool    = false
var _xp_container:  Node    = null
var _knockback_vel: Vector2 = Vector2.ZERO
var _last_dir:      Vector2 = Vector2.DOWN
var _state:         State   = State.WALK
var _state_timer:   float   = 0.0
var _charge_dir:    Vector2 = Vector2.ZERO
var _anim_time:     float   = 0.0
var _fuse:          float   = -1.0

func _ready() -> void:
	add_to_group("enemies")
	health = max_health
	_player = get_tree().get_first_node_in_group("player")
	_state_timer = randf_range(CHARGE_INTERVAL_MIN, CHARGE_INTERVAL_MAX)

func _physics_process(delta: float) -> void:
	_anim_time += delta
	queue_redraw()

	if _dead:
		if _fuse >= 0.0:
			_fuse -= delta
			if _fuse <= 0.0:
				_burst()
		return
	if not _player or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player")
		return

	_contact_timer = maxf(0.0, _contact_timer - delta)
	_state_timer  -= delta

	if _knockback_vel.length_squared() > 4.0:
		_knockback_vel = _knockback_vel.lerp(Vector2.ZERO, delta * 8.0)
		velocity = _knockback_vel
		move_and_slide()
		return

	match _state:
		State.WALK:
			velocity = (_player.global_position - global_position).normalized() * move_speed
			if _state_timer <= 0.0:
				_state = State.WINDUP
				_state_timer = WINDUP_DURATION
				velocity = Vector2.ZERO
		State.WINDUP:
			velocity = Vector2.ZERO
			# Direction locks at the END of windup — dodge during the flash
			if _state_timer <= 0.0:
				_state = State.CHARGE
				_state_timer = CHARGE_DURATION
				_charge_dir = (_player.global_position - global_position).normalized()
		State.CHARGE:
			velocity = _charge_dir * move_speed * CHARGE_MULT
			if _state_timer <= 0.0:
				_state = State.WALK
				_state_timer = randf_range(CHARGE_INTERVAL_MIN, CHARGE_INTERVAL_MAX)
	move_and_slide()

	if velocity.length() > 5.0:
		_last_dir = velocity.normalized()

	var hit_range := 26.0 if _state == State.CHARGE else 22.0
	if global_position.distance_to(_player.global_position) < hit_range and _contact_timer <= 0.0:
		_contact_timer = contact_cooldown
		if _player.has_method("take_damage"):
			_player.take_damage(damage)

func _draw() -> void:
	if _dead:
		# Fuse: pulsing ribcage about to burst
		if _fuse >= 0.0:
			var pulse := 0.5 + 0.5 * sin(_anim_time * 40.0)
			draw_circle(Vector2.ZERO, 12.0 + pulse * 4.0, Color(1.0, 0.5, 0.1, 0.5 + pulse * 0.4))
			draw_arc(Vector2.ZERO, BURST_RADIUS, 0.0, TAU, 32, Color(1.0, 0.3, 0.0, 0.35 + pulse * 0.3), 2.0)
		return

	var bob := sin(_anim_time * 6.0) * 2.0
	var body_col := Color(0.85, 0.82, 0.72)
	var dark     := Color(0.30, 0.26, 0.20)
	if _state == State.WINDUP:
		# Red warning flash during windup
		var flash := 0.5 + 0.5 * sin(_anim_time * 30.0)
		body_col = body_col.lerp(Color(1.0, 0.15, 0.1), flash * 0.7)
	# Skull
	draw_circle(Vector2(0, -8 + bob), 9.0, body_col)
	draw_circle(Vector2(-3.2, -10 + bob), 2.2, dark)
	draw_circle(Vector2(3.2, -10 + bob), 2.2, dark)
	draw_rect(Rect2(-4, -4 + bob, 8, 3), dark)
	# Ribcage
	for i in 3:
		var y := 2.0 + i * 4.0 + bob
		draw_line(Vector2(-8 + i * 1.5, y), Vector2(8 - i * 1.5, y), body_col, 2.0)
	# Spine
	draw_line(Vector2(0, -2 + bob), Vector2(0, 14 + bob), body_col, 2.5)
	# Legs (simple scuttle)
	var leg := sin(_anim_time * 10.0) * 3.0
	draw_line(Vector2(0, 14 + bob), Vector2(-5 + leg, 20), body_col, 2.0)
	draw_line(Vector2(0, 14 + bob), Vector2(5 - leg, 20), body_col, 2.0)

	# Health bar
	var hp_ratio := float(health) / float(max_health) if max_health > 0 else 0.0
	if hp_ratio < 1.0:
		draw_rect(Rect2(-14, -28, 28, 4), Color(0.12, 0.0, 0.0))
		draw_rect(Rect2(-14, -28, 28.0 * hp_ratio, 4), Color(0.9, 0.85, 0.6))

func apply_knockback(dir: Vector2, force: float) -> void:
	if _dead or _state == State.CHARGE:
		return
	_knockback_vel = dir * force

func take_hit(dmg: int) -> void:
	if _dead:
		return
	health -= dmg
	queue_redraw()
	if health <= 0:
		_die()

func fire_kill() -> void:
	if _dead:
		return
	_dead = true
	set_physics_process(false)
	$CollisionShape2D.set_deferred("disabled", true)
	remove_from_group("enemies")
	GameState.add_kill_score(xp_value)
	_spawn_blood()
	queue_free()

func _die() -> void:
	_dead = true
	remove_from_group("enemies")
	$CollisionShape2D.set_deferred("disabled", true)
	GameState.add_kill_score(xp_value)
	GameState.kill_hitstop(false)
	_spawn_blood()
	_drop_xp()
	# Arm the death burst — _physics_process keeps running for the fuse
	_fuse = BURST_FUSE
	queue_redraw()

func _burst() -> void:
	_fuse = -1.0
	set_physics_process(false)
	var player := get_tree().get_first_node_in_group("player")
	if player and global_position.distance_to(player.global_position) < BURST_RADIUS:
		if player.has_method("take_damage"):
			player.take_damage(damage)
	var splat = BLOOD_SCENE.instantiate()
	get_parent().add_child(splat)
	splat.global_position = global_position
	GameState.screen_shake(12.0, 0.12)
	queue_free()

func _spawn_blood() -> void:
	var splat = BLOOD_SCENE.instantiate()
	get_parent().add_child(splat)
	splat.global_position = global_position
	var smears := get_tree().get_first_node_in_group("blood_smears")
	if smears:
		smears.add_smear(global_position, _last_dir, 1.2)

func _drop_xp() -> void:
	if not _xp_container or not is_instance_valid(_xp_container):
		_xp_container = get_tree().get_first_node_in_group("xp_orbs_container")
	if not _xp_container:
		return
	var orb = XP_ORB_SCENE.instantiate()
	_xp_container.add_child(orb)
	orb.global_position = global_position + Vector2(randf_range(-12, 12), randf_range(-12, 12))
	orb.xp_value = xp_value
