extends CharacterBody2D

# Imp — ranged pressure enemy (docs/BALANCE.md §3). Keeps mid-range distance,
# strafes, and lobs bolts. Same take_hit()/fire_kill()/apply_knockback()
# interface as Enemy so projectiles and fire bombs work unmodified.

const XP_ORB_SCENE = preload("res://scenes/XPOrb.tscn")
const BLOOD_SCENE  = preload("res://scenes/BloodSplatter.tscn")
const BOLT_SCRIPT  = preload("res://scripts/ImpBolt.gd")

@export var move_speed:       float = 70.0
@export var max_health:       int   = 12
@export var health:           int   = 12
@export var xp_value:         int   = 14
@export var damage:           int   = 7
@export var contact_cooldown: float = 0.8

const PREFERRED_RANGE := 180.0   # tries to hover here
const RANGE_SLACK     := 40.0    # deadband so it strafes instead of jittering
const SPRITE_SCALE    := Vector2(2.2, 2.2)
const IMP_TINT        := Color(1.0, 0.55, 0.25)

var _player:        Node2D  = null
var _contact_timer: float   = 0.0
var _dead:          bool    = false
var _xp_container:  Node    = null
var _knockback_vel: Vector2 = Vector2.ZERO
var _last_dir:      Vector2 = Vector2.DOWN
var _bolt_timer:    float   = 0.0
var _strafe_sign:   float   = 1.0

@onready var sprite:      Sprite2D        = $Sprite2D
@onready var anim_player: AnimationPlayer = $AnimationPlayer

func _ready() -> void:
	add_to_group("enemies")
	health = max_health
	_player = get_tree().get_first_node_in_group("player")
	sprite.scale    = SPRITE_SCALE
	sprite.modulate = IMP_TINT
	_bolt_timer  = randf_range(1.5, 3.0)
	_strafe_sign = 1.0 if randf() < 0.5 else -1.0
	_build_animations()
	anim_player.play("walk")

func _build_animations() -> void:
	var lib := AnimationLibrary.new()
	var walk := Animation.new()
	walk.length = 0.3
	walk.loop_mode = Animation.LOOP_LINEAR
	var t := walk.add_track(Animation.TYPE_VALUE)
	walk.track_set_path(t, "Sprite2D:position")
	walk.value_track_set_update_mode(t, Animation.UPDATE_CONTINUOUS)
	walk.track_insert_key(t, 0.00, Vector2(0,  0))
	walk.track_insert_key(t, 0.15, Vector2(0, -3))
	walk.track_insert_key(t, 0.30, Vector2(0,  0))
	lib.add_animation("walk", walk)

	var hurt := Animation.new()
	hurt.length = 0.22
	hurt.loop_mode = Animation.LOOP_NONE
	var tm := hurt.add_track(Animation.TYPE_VALUE)
	hurt.track_set_path(tm, "Sprite2D:modulate")
	hurt.value_track_set_update_mode(tm, Animation.UPDATE_CONTINUOUS)
	hurt.track_insert_key(tm, 0.00, IMP_TINT)
	hurt.track_insert_key(tm, 0.02, Color(4.0, 4.0, 4.0, 1.0))
	hurt.track_insert_key(tm, 0.10, Color(4.0, 4.0, 4.0, 1.0))
	hurt.track_insert_key(tm, 0.22, IMP_TINT)
	lib.add_animation("hurt", hurt)

	var death := Animation.new()
	death.length = 0.4
	death.loop_mode = Animation.LOOP_NONE
	var ts := death.add_track(Animation.TYPE_VALUE)
	death.track_set_path(ts, "Sprite2D:scale")
	death.value_track_set_update_mode(ts, Animation.UPDATE_CONTINUOUS)
	death.track_insert_key(ts, 0.0, SPRITE_SCALE)
	death.track_insert_key(ts, 0.4, Vector2.ZERO)
	var tr := death.add_track(Animation.TYPE_VALUE)
	death.track_set_path(tr, "Sprite2D:rotation")
	death.value_track_set_update_mode(tr, Animation.UPDATE_CONTINUOUS)
	death.track_insert_key(tr, 0.0, 0.0)
	death.track_insert_key(tr, 0.4, TAU)
	lib.add_animation("death", death)

	anim_player.add_animation_library("", lib)

func _physics_process(delta: float) -> void:
	if _dead:
		return
	if not _player or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player")
		return

	_contact_timer = maxf(0.0, _contact_timer - delta)
	_bolt_timer   -= delta

	var to_player := _player.global_position - global_position
	var dist := to_player.length()
	var dir  := to_player.normalized()

	if _knockback_vel.length_squared() > 4.0:
		_knockback_vel = _knockback_vel.lerp(Vector2.ZERO, delta * 10.0)
		velocity = _knockback_vel
	else:
		_knockback_vel = Vector2.ZERO
		var perp := Vector2(-dir.y, dir.x) * _strafe_sign
		if dist > PREFERRED_RANGE + RANGE_SLACK:
			velocity = dir * move_speed
		elif dist < PREFERRED_RANGE - RANGE_SLACK:
			velocity = -dir * move_speed + perp * move_speed * 0.4
		else:
			velocity = perp * move_speed * 0.8
	move_and_slide()

	if dist < 22.0 and _contact_timer <= 0.0:
		_contact_timer = contact_cooldown
		if _player.has_method("take_damage"):
			_player.take_damage(damage)

	if _bolt_timer <= 0.0 and dist < 400.0:
		_bolt_timer = randf_range(2.5, 4.0)
		_shoot_bolt(dir)

	if velocity.length() > 5.0:
		_last_dir = velocity.normalized()
		sprite.flip_h = velocity.x < -5.0

func _shoot_bolt(dir: Vector2) -> void:
	var container := get_tree().get_first_node_in_group("projectiles_container")
	if not container:
		return
	var bolt := Node2D.new()
	bolt.set_script(BOLT_SCRIPT)
	container.add_child(bolt)
	bolt.global_position = global_position
	bolt.launch(dir, damage)

func _draw() -> void:
	if _dead:
		return
	var hp_ratio := float(health) / float(max_health) if max_health > 0 else 0.0
	if hp_ratio >= 1.0:
		return
	draw_rect(Rect2(-14, -26, 28, 4), Color(0.12, 0.0, 0.0))
	draw_rect(Rect2(-14, -26, 28.0 * hp_ratio, 4), Color(1.0, 0.55, 0.05))

func apply_knockback(dir: Vector2, force: float) -> void:
	if _dead:
		return
	_knockback_vel = dir * force

func take_hit(dmg: int) -> void:
	if _dead:
		return
	health -= dmg
	queue_redraw()
	if health <= 0:
		_die()
		return
	anim_player.play("hurt")
	await get_tree().create_timer(0.25).timeout
	if not _dead:
		anim_player.play("walk")

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
	queue_redraw()
	set_physics_process(false)
	$CollisionShape2D.set_deferred("disabled", true)
	remove_from_group("enemies")
	GameState.add_kill_score(xp_value)
	GameState.kill_hitstop(false)
	sprite.position = Vector2.ZERO
	anim_player.play("death")
	_spawn_blood()
	_drop_xp()
	await get_tree().create_timer(0.45).timeout
	queue_free()

func _spawn_blood() -> void:
	var splat = BLOOD_SCENE.instantiate()
	get_parent().add_child(splat)
	splat.global_position = global_position
	var smears := get_tree().get_first_node_in_group("blood_smears")
	if smears:
		smears.add_smear(global_position, _last_dir, 0.8)

func _drop_xp() -> void:
	if not _xp_container or not is_instance_valid(_xp_container):
		_xp_container = get_tree().get_first_node_in_group("xp_orbs_container")
	if not _xp_container:
		return
	var orb = XP_ORB_SCENE.instantiate()
	_xp_container.add_child(orb)
	orb.global_position = global_position + Vector2(randf_range(-12, 12), randf_range(-12, 12))
	orb.xp_value = xp_value
