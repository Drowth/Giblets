extends CharacterBody2D

const XP_ORB_SCENE = preload("res://scenes/XPOrb.tscn")
const BLOOD_SCENE  = preload("res://scenes/BloodSplatter.tscn")

@export var move_speed:       float = 80.0
@export var max_health:       int   = 15
@export var health:           int   = 15
@export var xp_value:         int   = 25
@export var damage:           int   = 8
@export var contact_cooldown: float = 0.8

var _player:        Node2D  = null
var _contact_timer: float   = 0.0
var _dead:          bool    = false
var _xp_container:  Node    = null
var _knockback_vel: Vector2 = Vector2.ZERO
var _drift_timer:   float   = 0.0
var _lunge_timer:   float   = 0.0
var _lunge_active:  bool    = false
var _lunge_dir:     Vector2 = Vector2.ZERO

const SPRITE_SCALE := Vector2(0.056, 0.056)

@onready var sprite:      Sprite2D        = $Sprite2D
@onready var anim_player: AnimationPlayer = $AnimationPlayer

func _ready() -> void:
	add_to_group("enemies")
	health = max_health
	_player = get_tree().get_first_node_in_group("player")
	sprite.scale    = SPRITE_SCALE
	sprite.modulate = Color(0.72, 0.85, 1.0, 0.65)
	for path in ["res://assets/enemies/wraith.png", "res://assets/enemies/demon_basic.png"]:
		var tex = load(path) if ResourceLoader.exists(path) else null
		if tex:
			sprite.texture = tex
			break
	_lunge_timer = randf_range(2.0, 4.0)
	_build_animations()
	anim_player.play("float")

func _build_animations() -> void:
	var lib := AnimationLibrary.new()
	lib.add_animation("float", _anim_float())
	lib.add_animation("hurt",  _anim_hurt())
	lib.add_animation("death", _anim_death())
	anim_player.add_animation_library("", lib)

func _anim_float() -> Animation:
	var a := Animation.new()
	a.length    = 1.4
	a.loop_mode = Animation.LOOP_LINEAR
	var t := a.add_track(Animation.TYPE_VALUE)
	a.track_set_path(t, "Sprite2D:position")
	a.value_track_set_update_mode(t, Animation.UPDATE_CONTINUOUS)
	a.track_insert_key(t, 0.0, Vector2(0,  0))
	a.track_insert_key(t, 0.7, Vector2(0, -5))
	a.track_insert_key(t, 1.4, Vector2(0,  0))
	return a

func _anim_hurt() -> Animation:
	var a := Animation.new()
	a.length    = 0.15
	a.loop_mode = Animation.LOOP_NONE
	var tm := a.add_track(Animation.TYPE_VALUE)
	a.track_set_path(tm, "Sprite2D:modulate")
	a.value_track_set_update_mode(tm, Animation.UPDATE_CONTINUOUS)
	a.track_insert_key(tm, 0.00, Color(0.72, 0.85, 1.0, 0.65))
	a.track_insert_key(tm, 0.03, Color(4.0,  4.0,  4.0, 1.0))
	a.track_insert_key(tm, 0.15, Color(0.72, 0.85, 1.0, 0.65))
	return a

func _anim_death() -> Animation:
	var a := Animation.new()
	a.length    = 0.55
	a.loop_mode = Animation.LOOP_NONE
	var ts := a.add_track(Animation.TYPE_VALUE)
	a.track_set_path(ts, "Sprite2D:scale")
	a.value_track_set_update_mode(ts, Animation.UPDATE_CONTINUOUS)
	a.track_insert_key(ts, 0.00, SPRITE_SCALE)
	a.track_insert_key(ts, 0.20, SPRITE_SCALE * 1.4)
	a.track_insert_key(ts, 0.55, Vector2.ZERO)
	var ta := a.add_track(Animation.TYPE_VALUE)
	a.track_set_path(ta, "Sprite2D:modulate:a")
	a.value_track_set_update_mode(ta, Animation.UPDATE_CONTINUOUS)
	a.track_insert_key(ta, 0.00, 0.65)
	a.track_insert_key(ta, 0.55, 0.0)
	return a

func _physics_process(delta: float) -> void:
	if _dead:
		return
	if not _player or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player")
		return

	_contact_timer  = maxf(0.0, _contact_timer - delta)
	_drift_timer   += delta
	_lunge_timer   -= delta

	if _knockback_vel.length_squared() > 4.0:
		_knockback_vel = _knockback_vel.lerp(Vector2.ZERO, delta * 14.0)
		velocity = _knockback_vel
	elif _lunge_active:
		velocity = _lunge_dir * (move_speed * 3.5)
		if _lunge_timer <= 0.0:
			_lunge_active = false
			_lunge_timer  = randf_range(2.0, 4.0)
	elif _lunge_timer <= 0.0:
		_lunge_active = true
		_lunge_dir    = (_player.global_position - global_position).normalized()
		_lunge_timer  = 0.35
		velocity      = _lunge_dir * (move_speed * 3.5)
	else:
		var dir  := (_player.global_position - global_position).normalized()
		var perp := Vector2(-dir.y, dir.x)
		velocity  = dir * move_speed + perp * sin(_drift_timer * 2.8) * 28.0

	move_and_slide()

	if _player and global_position.distance_to(_player.global_position) < 22.0 and _contact_timer <= 0.0:
		_contact_timer = contact_cooldown
		if _player.has_method("take_damage"):
			_player.take_damage(damage)

func _draw() -> void:
	if _dead:
		return
	var hp_ratio := float(health) / float(max_health) if max_health > 0 else 0.0
	if hp_ratio >= 1.0:
		return
	draw_rect(Rect2(-14, -26, 28, 4), Color(0.05, 0.0, 0.15))
	draw_rect(Rect2(-14, -26, 28.0 * hp_ratio, 4), Color(0.45, 0.1, 0.95))

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
	await get_tree().create_timer(0.18).timeout
	if not _dead:
		anim_player.play("float")

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
	sprite.position = Vector2.ZERO
	anim_player.play("death")
	_spawn_blood()
	_drop_xp()
	await get_tree().create_timer(0.6).timeout
	queue_free()

func _spawn_blood() -> void:
	var splat = BLOOD_SCENE.instantiate()
	get_parent().add_child(splat)
	splat.global_position = global_position
	var smears := get_tree().get_first_node_in_group("blood_smears")
	if smears:
		var dir := velocity.normalized() if velocity.length() > 1.0 else Vector2.DOWN
		smears.add_smear(global_position, dir, 1.0, Color(0.0, 1.0, 0.0))

func _drop_xp() -> void:
	if not _xp_container or not is_instance_valid(_xp_container):
		_xp_container = get_tree().get_first_node_in_group("xp_orbs_container")
	if not _xp_container:
		return
	var orb = XP_ORB_SCENE.instantiate()
	_xp_container.add_child(orb)
	orb.global_position = global_position + Vector2(randf_range(-12, 12), randf_range(-12, 12))
	orb.xp_value = xp_value
