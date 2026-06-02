extends CharacterBody2D

const XP_ORB_SCENE  = preload("res://scenes/XPOrb.tscn")
const BLOOD_SCENE   = preload("res://scenes/BloodSplatter.tscn")
const BOMB_SCENE    = preload("res://scenes/BombPickup.tscn")

@export var move_speed:       float = 60.0
@export var max_health:       int   = 25
@export var health:           int   = 25
@export var xp_value:         int   = 20
@export var damage:           int   = 10
@export var contact_cooldown: float = 0.8
@export var is_boss:          bool  = false

var _player:         Node2D  = null
var _contact_timer:  float   = 0.0
var _dead:           bool    = false
var _xp_container:   Node    = null
var _knockback_vel:  Vector2 = Vector2.ZERO
var _effective_scale: Vector2
var _last_dir:       Vector2 = Vector2.DOWN

@onready var sprite:      Sprite2D        = $Sprite2D
@onready var anim_player: AnimationPlayer = $AnimationPlayer

const BASE_SCALE := Vector2(0.056, 0.056)

# ---------------------------------------------------------------------------
func _ready() -> void:
	add_to_group("enemies")
	_effective_scale = BASE_SCALE * (3.0 if is_boss else 1.0)
	sprite.scale = _effective_scale
	if is_boss:
		var boss_tex = load("res://assets/enemies/boss1.png")
		if boss_tex:
			sprite.texture = boss_tex
		var boss_shape := CircleShape2D.new()
		boss_shape.radius = 32.0
		$CollisionShape2D.shape = boss_shape
	health = max_health
	_player = get_tree().get_first_node_in_group("player")
	_build_animations()
	anim_player.play("idle")

# ---------------------------------------------------------------------------
func _build_animations() -> void:
	var lib := AnimationLibrary.new()
	lib.add_animation("idle",  _anim_idle())
	lib.add_animation("walk",  _anim_walk())
	lib.add_animation("hurt",  _anim_hurt())
	lib.add_animation("death", _anim_death())
	anim_player.add_animation_library("", lib)

func _anim_idle() -> Animation:
	var a := Animation.new()
	a.length    = 0.8
	a.loop_mode = Animation.LOOP_LINEAR
	var t := a.add_track(Animation.TYPE_VALUE)
	a.track_set_path(t, "Sprite2D:position")
	a.value_track_set_update_mode(t, Animation.UPDATE_CONTINUOUS)
	a.track_insert_key(t, 0.0, Vector2(0, 0))
	a.track_insert_key(t, 0.4, Vector2(0, 3))
	a.track_insert_key(t, 0.8, Vector2(0, 0))
	return a

func _anim_walk() -> Animation:
	# Faster bob; lean is driven procedurally in _physics_process
	var a := Animation.new()
	a.length    = 0.4
	a.loop_mode = Animation.LOOP_LINEAR
	var t := a.add_track(Animation.TYPE_VALUE)
	a.track_set_path(t, "Sprite2D:position")
	a.value_track_set_update_mode(t, Animation.UPDATE_CONTINUOUS)
	a.track_insert_key(t, 0.00, Vector2(0,  0))
	a.track_insert_key(t, 0.10, Vector2(0, -2))
	a.track_insert_key(t, 0.20, Vector2(0,  0))
	a.track_insert_key(t, 0.30, Vector2(0, -2))
	a.track_insert_key(t, 0.40, Vector2(0,  0))
	return a

func _anim_hurt() -> Animation:
	var a := Animation.new()
	a.length    = 0.15
	a.loop_mode = Animation.LOOP_NONE
	var ts := a.add_track(Animation.TYPE_VALUE)
	a.track_set_path(ts, "Sprite2D:scale")
	a.value_track_set_update_mode(ts, Animation.UPDATE_CONTINUOUS)
	a.track_insert_key(ts, 0.00, _effective_scale)
	a.track_insert_key(ts, 0.05, Vector2(_effective_scale.x * 1.3, _effective_scale.y * 0.7))
	a.track_insert_key(ts, 0.10, Vector2(_effective_scale.x * 0.9, _effective_scale.y * 1.1))
	a.track_insert_key(ts, 0.15, _effective_scale)
	var tm := a.add_track(Animation.TYPE_VALUE)
	a.track_set_path(tm, "Sprite2D:modulate")
	a.value_track_set_update_mode(tm, Animation.UPDATE_CONTINUOUS)
	var base_mod := Color.WHITE
	a.track_insert_key(tm, 0.00, base_mod)
	a.track_insert_key(tm, 0.03, Color(4.0, 4.0, 4.0, 1.0))
	a.track_insert_key(tm, 0.15, base_mod)
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
	a.track_insert_key(ts, 0.0, _effective_scale)
	a.track_insert_key(ts, 0.4, Vector2.ZERO)
	return a

# ---------------------------------------------------------------------------
func _physics_process(delta: float) -> void:
	if _dead:
		return
	if not _player or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player")
		return

	_contact_timer = maxf(0.0, _contact_timer - delta)

	if _knockback_vel.length_squared() > 4.0:
		_knockback_vel = _knockback_vel.lerp(Vector2.ZERO, delta * 10.0)
		velocity = _knockback_vel
	else:
		_knockback_vel = Vector2.ZERO
		var dir := (_player.global_position - global_position).normalized()
		velocity = dir * move_speed
	move_and_slide()

	if global_position.distance_to(_player.global_position) < 25.0 and _contact_timer <= 0.0:
		_contact_timer = contact_cooldown
		if _player.has_method("take_damage"):
			_player.take_damage(damage)

	var moving := velocity.length() > 5.0
	if moving:
		_last_dir = velocity.normalized()
	var cur := anim_player.current_animation
	if moving and cur not in ["hurt", "death", "walk"]:
		anim_player.play("walk")
	elif not moving and cur not in ["hurt", "death", "idle"]:
		anim_player.play("idle")

	if moving:
		sprite.rotation = lerp(sprite.rotation, velocity.normalized().x * 0.12, delta * 8.0)
		sprite.flip_h   = velocity.x < -5.0
	else:
		sprite.rotation = lerp(sprite.rotation, 0.0, delta * 6.0)

# ---------------------------------------------------------------------------
func _draw() -> void:
	if _dead:
		return
	var hp_ratio := float(health) / float(max_health) if max_health > 0 else 0.0
	if hp_ratio >= 1.0:
		return
	if is_boss:
		draw_rect(Rect2(-32, -58, 64, 7), Color(0.12, 0.0, 0.0))
		draw_rect(Rect2(-32, -58, 64.0 * hp_ratio, 7), Color(1.0, 0.35, 0.0))
		var font := ThemeDB.fallback_font
		draw_string(font, Vector2(-14, -63), "BOSS", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(1.0, 0.5, 0.0))
	else:
		draw_rect(Rect2(-14, -26, 28, 4), Color(0.12, 0.0, 0.0))
		draw_rect(Rect2(-14, -26, 28.0 * hp_ratio, 4), Color(0.75, 0.05, 0.05))

# ---------------------------------------------------------------------------
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
	await get_tree().create_timer(0.18).timeout
	if not _dead:
		anim_player.play("walk" if velocity.length() > 5.0 else "idle")

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
	if is_boss:
		_spawn_bomb()
	await get_tree().create_timer(0.45).timeout
	queue_free()

# ---------------------------------------------------------------------------
func _spawn_blood() -> void:
	var splat = BLOOD_SCENE.instantiate()
	get_parent().add_child(splat)
	splat.global_position = global_position
	var smears := get_tree().get_first_node_in_group("blood_smears")
	if smears:
		smears.add_smear(global_position, _last_dir, 2.5 if is_boss else 1.0)

func _drop_xp() -> void:
	if not _xp_container or not is_instance_valid(_xp_container):
		_xp_container = get_tree().get_first_node_in_group("xp_orbs_container")
	if not _xp_container:
		return
	if is_boss:
		# Drop 6 orbs totalling 2 full levels of XP
		var total_xp := GameState.xp_to_next_level * 2
		var orb_xp   := total_xp / 6
		for i in 6:
			var orb = XP_ORB_SCENE.instantiate()
			_xp_container.add_child(orb)
			orb.global_position = global_position + Vector2(randf_range(-50, 50), randf_range(-50, 50))
			orb.xp_value = orb_xp
	else:
		var orb_count := clampi(xp_value / 20, 1, 3)
		var orb_xp    := xp_value / orb_count
		for i in orb_count:
			var orb = XP_ORB_SCENE.instantiate()
			_xp_container.add_child(orb)
			orb.global_position = global_position + Vector2(randf_range(-18, 18), randf_range(-18, 18))
			orb.xp_value = orb_xp

func _spawn_bomb() -> void:
	var bomb = BOMB_SCENE.instantiate()
	get_tree().current_scene.add_child(bomb)
	bomb.global_position = global_position
