extends CharacterBody2D

const PROJECTILE_SCENE = preload("res://scenes/Projectile.tscn")

const TEX_LVL1        = preload("res://assets/player/player.png")
const TEX_LVL2        = preload("res://assets/player/player2.png")
const TEX_LVL3        = preload("res://assets/player/player3.png")
const BLOOD_DROP      = preload("res://scripts/BloodTrailDrop.gd")

const DASH_SPEED:           float = 600.0
const DASH_DURATION_BASE:   float = 0.20
const DASH_COOLDOWN_BASE:   float = 3.0
const DASH_KNOCKBACK_BASE:  float = 65.0
const DASH_KNOCKBACK_FORCE: float = 550.0

@onready var attack_timer:  Timer           = $AttackTimer
@onready var iframes_timer: Timer           = $IFramesTimer
@onready var sprite:        Sprite2D        = $Sprite2D
@onready var anim_player:   AnimationPlayer = $AnimationPlayer
@onready var camera:        Camera2D        = $Camera2D

var is_invincible:   bool     = false
var _proj_container: Node2D   = null
var _trail_timer:    float    = 0.0
var _slow_factor:    float    = 1.0
var _slow_timer:     float    = 0.0
var _dash_active:    bool     = false
var _dash_timer:     float    = 0.0
var _dash_cooldown:  float    = 0.0
var _dash_dir:       Vector2  = Vector2.RIGHT
var _dash_hit_set:   Array    = []
var _last_move_dir:  Vector2  = Vector2.DOWN

func _ready() -> void:
	add_to_group("player")
	attack_timer.wait_time = 1.0 / GameState.fire_rate
	attack_timer.timeout.connect(_fire)
	iframes_timer.timeout.connect(func(): is_invincible = false)
	GameState.game_over.connect(_on_game_over)
	GameState.level_changed.connect(_on_level_changed)
	camera.limit_right  = int(GameState.WORLD_SIZE.x)
	camera.limit_bottom = int(GameState.WORLD_SIZE.y)
	camera.zoom = Vector2(0.3, 0.3)
	_build_animations()
	anim_player.play("idle")

func _build_animations() -> void:
	var lib := AnimationLibrary.new()

	var idle := Animation.new()
	idle.length = 1.0
	idle.loop_mode = Animation.LOOP_LINEAR
	var t := idle.add_track(Animation.TYPE_VALUE)
	idle.track_set_path(t, "Sprite2D:position")
	idle.value_track_set_update_mode(t, Animation.UPDATE_CONTINUOUS)
	idle.track_insert_key(t, 0.0, Vector2(0,  0))
	idle.track_insert_key(t, 0.5, Vector2(0,  2))
	idle.track_insert_key(t, 1.0, Vector2(0,  0))
	lib.add_animation("idle", idle)

	var walk := Animation.new()
	walk.length = 0.35
	walk.loop_mode = Animation.LOOP_LINEAR
	t = walk.add_track(Animation.TYPE_VALUE)
	walk.track_set_path(t, "Sprite2D:position")
	walk.value_track_set_update_mode(t, Animation.UPDATE_CONTINUOUS)
	walk.track_insert_key(t, 0.000, Vector2(0,  0))
	walk.track_insert_key(t, 0.088, Vector2(0, -3))
	walk.track_insert_key(t, 0.175, Vector2(0,  0))
	walk.track_insert_key(t, 0.263, Vector2(0, -3))
	walk.track_insert_key(t, 0.350, Vector2(0,  0))
	lib.add_animation("walk", walk)

	anim_player.add_animation_library("", lib)

func _unhandled_input(event: InputEvent) -> void:
	if not GameState.game_active:
		return
	if event.is_action_pressed("dash"):
		_try_dash()
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			_try_dash()

func _try_dash() -> void:
	if _dash_cooldown > 0.0 or _dash_active:
		return
	_dash_dir = _last_move_dir
	_dash_hit_set.clear()
	_dash_active  = true
	_dash_timer   = DASH_DURATION_BASE * GameState.dash_distance_mul
	_dash_cooldown = DASH_COOLDOWN_BASE * GameState.dash_cooldown_mul
	# Clear web slow — dashing through breaks it
	_slow_factor = 1.0
	_slow_timer  = 0.0
	is_invincible = true
	iframes_timer.start(_dash_timer + 0.05)
	queue_redraw()

func _do_dash_knockback() -> void:
	var radius := DASH_KNOCKBACK_BASE * GameState.dash_knockback_mul
	var force  := DASH_KNOCKBACK_FORCE * GameState.dash_knockback_mul
	for enemy: Node2D in get_tree().get_nodes_in_group("enemies"):
		if enemy in _dash_hit_set:
			continue
		if global_position.distance_to(enemy.global_position) < radius:
			_dash_hit_set.append(enemy)
			var dir: Vector2 = _dash_dir
			if enemy.has_method("apply_knockback"):
				enemy.apply_knockback(dir, force)

func _physics_process(delta: float) -> void:
	# Dash active — override all movement
	if _dash_active:
		_dash_timer -= delta
		_do_dash_knockback()
		if _dash_timer <= 0.0:
			_dash_active = false
		velocity = _dash_dir * DASH_SPEED
		move_and_slide()
		global_position.x = clampf(global_position.x, 20.0, GameState.WORLD_SIZE.x - 20.0)
		global_position.y = clampf(global_position.y, 20.0, GameState.WORLD_SIZE.y - 20.0)
		queue_redraw()
		return

	# Dash cooldown countdown
	if _dash_cooldown > 0.0:
		_dash_cooldown = maxf(0.0, _dash_cooldown - delta)

	# Web slow countdown
	if _slow_timer > 0.0:
		_slow_timer -= delta
		if _slow_timer <= 0.0:
			_slow_factor = 1.0

	var dir := Vector2(
		Input.get_axis("ui_left", "ui_right"),
		Input.get_axis("ui_up", "ui_down")
	)
	var effective_speed := GameState.move_speed * _slow_factor
	if dir != Vector2.ZERO:
		_last_move_dir = dir.normalized()
		velocity = _last_move_dir * effective_speed
		if dir.x != 0.0:
			sprite.flip_h = dir.x < 0.0
	else:
		velocity = velocity.move_toward(Vector2.ZERO, effective_speed)
	move_and_slide()
	global_position.x = clampf(global_position.x, 20.0, GameState.WORLD_SIZE.x - 20.0)
	global_position.y = clampf(global_position.y, 20.0, GameState.WORLD_SIZE.y - 20.0)

	var moving := velocity.length() > 5.0
	if moving:
		_trail_timer -= delta
		if _trail_timer <= 0.0:
			_trail_timer = 0.1
			_leave_blood_trail()

	var cur := anim_player.current_animation
	if moving and cur != "walk":
		anim_player.play("walk")
	elif not moving and cur != "idle":
		anim_player.play("idle")

	queue_redraw()

func _fire() -> void:
	attack_timer.wait_time = 1.0 / GameState.fire_rate
	var enemies := get_tree().get_nodes_in_group("enemies")
	if enemies.is_empty():
		return
	var nearest: Node2D = null
	var nearest_dist := INF
	for e: Node2D in enemies:
		var d := global_position.distance_to(e.global_position)
		if d < nearest_dist:
			nearest_dist = d
			nearest = e
	if not nearest:
		return
	if not _proj_container or not is_instance_valid(_proj_container):
		_proj_container = get_tree().get_first_node_in_group("projectiles_container")
	if not _proj_container:
		return
	var base_dir := (nearest.global_position - global_position).normalized()
	var count := GameState.projectile_count
	for i in count:
		var proj: Area2D = PROJECTILE_SCENE.instantiate()
		_proj_container.add_child(proj)
		proj.global_position = global_position
		var angle_offset := 0.0
		if count > 1:
			angle_offset = lerp(-0.1, 0.1, float(i) / float(count - 1))
		proj.launch(
			base_dir.rotated(angle_offset),
			GameState.projectile_damage,
			GameState.projectile_speed,
			GameState.projectile_pierce
		)

func apply_slow(duration: float, factor: float) -> void:
	if _dash_active:
		return
	_slow_factor = minf(_slow_factor, factor)
	_slow_timer  = maxf(_slow_timer, duration)
	queue_redraw()

func _draw() -> void:
	# Web-slow ring: fading blue arc
	if _slow_timer > 0.0:
		var alpha := clampf(_slow_timer / 3.0, 0.15, 0.65)
		draw_arc(Vector2.ZERO, 18.0, 0.0, TAU, 24, Color(0.3, 0.55, 1.0, alpha), 2.5)

	# Dash cooldown ring: fills clockwise from top; pulses gold when ready
	var eff_cd := DASH_COOLDOWN_BASE * GameState.dash_cooldown_mul
	if _dash_cooldown > 0.0:
		var frac := 1.0 - clampf(_dash_cooldown / eff_cd, 0.0, 1.0)
		if frac > 0.0:
			draw_arc(Vector2.ZERO, 22.0, -PI * 0.5,
					-PI * 0.5 + TAU * frac, 36, Color(0.85, 0.82, 0.18, 0.60), 2.0)
	else:
		var pulse := 0.30 + 0.22 * sin(Time.get_ticks_msec() * 0.006)
		draw_arc(Vector2.ZERO, 22.0, 0.0, TAU, 36, Color(1.0, 0.90, 0.12, pulse), 2.0)

func take_damage(amount: int) -> void:
	if is_invincible:
		return
	GameState.take_damage(amount)
	is_invincible = true
	iframes_timer.start(0.6)
	_flash_damage()

func _flash_damage() -> void:
	for _i in 3:
		modulate = Color(2.0, 0.2, 0.2)
		await get_tree().create_timer(0.07).timeout
		modulate = Color.WHITE
		await get_tree().create_timer(0.07).timeout

func _leave_blood_trail() -> void:
	var drop := Node2D.new()
	drop.set_script(BLOOD_DROP)
	get_parent().add_child(drop)
	drop.global_position = global_position + Vector2(randf_range(-5, 5), randf_range(3, 9))
	drop.setup(randf_range(1.5, 3.5), Color(randf_range(0.35, 0.6), 0.0, 0.0, 1.0))

func _on_level_changed(new_level: int) -> void:
	if new_level >= 4:
		sprite.texture = TEX_LVL3
	elif new_level >= 2:
		sprite.texture = TEX_LVL2

func _on_game_over() -> void:
	set_physics_process(false)
	attack_timer.stop()
	modulate = Color(0.4, 0.0, 0.0)
