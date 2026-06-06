extends CharacterBody2D

const XP_ORB_SCENE = preload("res://scenes/XPOrb.tscn")
const BLOOD_SCENE  = preload("res://scenes/BloodSplatter.tscn")
const SPIDER_TEX   = preload("res://assets/enemies/spider.png")
const WEB_SCRIPT   = preload("res://scripts/WebProjectile.gd")

@export var move_speed:       float = 95.0
@export var max_health:       int   = 10
@export var health:           int   = 10
@export var xp_value:         int   = 8
@export var damage:           int   = 6
@export var contact_cooldown: float = 0.8

var _player:        Node2D  = null
var _contact_timer: float   = 0.0
var _dead:          bool    = false
var _xp_container:  Node    = null
var _knockback_vel: Vector2 = Vector2.ZERO
var _last_dir:      Vector2 = Vector2.DOWN
var _web_timer:     float   = 0.0

const SPRITE_SCALE := Vector2(3.0, 3.0)

@onready var sprite:      Sprite2D        = $Sprite2D
@onready var anim_player: AnimationPlayer = $AnimationPlayer

func _ready() -> void:
	add_to_group("enemies")
	health         = max_health
	_player        = get_tree().get_first_node_in_group("player")
	sprite.scale   = SPRITE_SCALE
	sprite.texture = SPIDER_TEX
	_web_timer     = randf_range(2.5, 5.0)
	_build_animations()
	anim_player.play("walk")

func _build_animations() -> void:
	var lib := AnimationLibrary.new()
	lib.add_animation("walk",  _anim_walk())
	lib.add_animation("hurt",  _anim_hurt())
	lib.add_animation("death", _anim_death())
	anim_player.add_animation_library("", lib)

func _anim_walk() -> Animation:
	var a := Animation.new()
	a.length    = 0.28
	a.loop_mode = Animation.LOOP_LINEAR
	var t := a.add_track(Animation.TYPE_VALUE)
	a.track_set_path(t, "Sprite2D:position")
	a.value_track_set_update_mode(t, Animation.UPDATE_CONTINUOUS)
	a.track_insert_key(t, 0.00, Vector2(0,  0))
	a.track_insert_key(t, 0.07, Vector2(0, -2))
	a.track_insert_key(t, 0.14, Vector2(0,  0))
	a.track_insert_key(t, 0.21, Vector2(0, -2))
	a.track_insert_key(t, 0.28, Vector2(0,  0))
	return a

func _anim_hurt() -> Animation:
	var a := Animation.new()
	a.length    = 0.22
	a.loop_mode = Animation.LOOP_NONE
	var ts := a.add_track(Animation.TYPE_VALUE)
	a.track_set_path(ts, "Sprite2D:scale")
	a.value_track_set_update_mode(ts, Animation.UPDATE_CONTINUOUS)
	a.track_insert_key(ts, 0.00, SPRITE_SCALE)
	a.track_insert_key(ts, 0.06, Vector2(SPRITE_SCALE.x * 1.45, SPRITE_SCALE.y * 0.55))
	a.track_insert_key(ts, 0.13, Vector2(SPRITE_SCALE.x * 0.85, SPRITE_SCALE.y * 1.15))
	a.track_insert_key(ts, 0.22, SPRITE_SCALE)
	var tm := a.add_track(Animation.TYPE_VALUE)
	a.track_set_path(tm, "Sprite2D:modulate")
	a.value_track_set_update_mode(tm, Animation.UPDATE_CONTINUOUS)
	a.track_insert_key(tm, 0.00, Color.WHITE)
	a.track_insert_key(tm, 0.02, Color(5.0, 5.0, 5.0))
	a.track_insert_key(tm, 0.10, Color(5.0, 5.0, 5.0))
	a.track_insert_key(tm, 0.22, Color.WHITE)
	return a

func _anim_death() -> Animation:
	var a := Animation.new()
	a.length    = 0.4
	a.loop_mode = Animation.LOOP_NONE
	var tr := a.add_track(Animation.TYPE_VALUE)
	a.track_set_path(tr, "Sprite2D:rotation")
	a.value_track_set_update_mode(tr, Animation.UPDATE_CONTINUOUS)
	a.track_insert_key(tr, 0.0, 0.0)
	a.track_insert_key(tr, 0.4, TAU)
	var ts := a.add_track(Animation.TYPE_VALUE)
	a.track_set_path(ts, "Sprite2D:scale")
	a.value_track_set_update_mode(ts, Animation.UPDATE_CONTINUOUS)
	a.track_insert_key(ts, 0.0, SPRITE_SCALE)
	a.track_insert_key(ts, 0.4, Vector2.ZERO)
	var tm := a.add_track(Animation.TYPE_VALUE)
	a.track_set_path(tm, "Sprite2D:modulate")
	a.value_track_set_update_mode(tm, Animation.UPDATE_CONTINUOUS)
	a.track_insert_key(tm, 0.00, Color(5.0, 5.0, 5.0))
	a.track_insert_key(tm, 0.07, Color.WHITE)
	return a

func _physics_process(delta: float) -> void:
	if _dead:
		return
	if not _player or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player")
		return

	_contact_timer = maxf(0.0, _contact_timer - delta)
	_web_timer    -= delta

	if _knockback_vel.length_squared() > 4.0:
		_knockback_vel = _knockback_vel.lerp(Vector2.ZERO, delta * 10.0)
		velocity = _knockback_vel
	else:
		_knockback_vel = Vector2.ZERO
		var dir := (_player.global_position - global_position).normalized()
		velocity = dir * move_speed
	move_and_slide()

	if global_position.distance_to(_player.global_position) < 20.0 and _contact_timer <= 0.0:
		_contact_timer = contact_cooldown
		if _player.has_method("take_damage"):
			_player.take_damage(damage)

	if _web_timer <= 0.0:
		_web_timer = randf_range(3.0, 6.0)
		_shoot_web()

	var moving := velocity.length() > 5.0
	if moving:
		_last_dir    = velocity.normalized()
		sprite.flip_h = velocity.x < -5.0
	var cur := anim_player.current_animation
	if cur not in ["hurt", "death"]:
		anim_player.play("walk")

func _shoot_web() -> void:
	if not _player or not is_instance_valid(_player):
		return
	var proj_container := get_tree().get_first_node_in_group("projectiles_container")
	if not proj_container:
		return
	var web := Node2D.new()
	web.set_script(WEB_SCRIPT)
	proj_container.add_child(web)
	web.global_position = global_position
	web.launch((_player.global_position - global_position).normalized())

func _draw() -> void:
	if _dead:
		return
	var hp_ratio := float(health) / float(max_health) if max_health > 0 else 0.0
	if hp_ratio >= 1.0:
		return
	draw_rect(Rect2(-14, -26, 28, 4), Color(0.12, 0.0, 0.0))
	draw_rect(Rect2(-14, -26, 28.0 * hp_ratio, 4), Color(0.75, 0.05, 0.05))

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
	sprite.position = Vector2.ZERO
	sprite.rotation = 0.0
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
	sprite.position = Vector2.ZERO
	sprite.rotation = 0.0
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
		smears.add_smear(global_position, _last_dir, 1.0)

func _drop_xp() -> void:
	if not _xp_container or not is_instance_valid(_xp_container):
		_xp_container = get_tree().get_first_node_in_group("xp_orbs_container")
	if not _xp_container:
		return
	var orb = XP_ORB_SCENE.instantiate()
	_xp_container.add_child(orb)
	orb.global_position = global_position + Vector2(randf_range(-12, 12), randf_range(-12, 12))
	orb.xp_value = xp_value
