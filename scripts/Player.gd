extends CharacterBody2D

const PROJECTILE_SCENE = preload("res://scenes/Projectile.tscn")

const TEX_LVL1        = preload("res://assets/player/player.png")
const TEX_LVL2        = preload("res://assets/player/player2.png")
const TEX_LVL3        = preload("res://assets/player/player3.png")
const BLOOD_DROP      = preload("res://scripts/BloodTrailDrop.gd")

@onready var attack_timer:  Timer           = $AttackTimer
@onready var iframes_timer: Timer           = $IFramesTimer
@onready var sprite:        Sprite2D        = $Sprite2D
@onready var anim_player:   AnimationPlayer = $AnimationPlayer
@onready var camera:        Camera2D        = $Camera2D

var is_invincible: bool     = false
var _proj_container: Node2D = null
var _trail_timer: float     = 0.0

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

	# Idle: gentle 2px bob, 1.0s
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

	# Walk: snappier 3px bob, 0.35s
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

func _physics_process(delta: float) -> void:
	var dir := Vector2(
		Input.get_axis("ui_left", "ui_right"),
		Input.get_axis("ui_up", "ui_down")
	)
	if dir != Vector2.ZERO:
		velocity = dir.normalized() * GameState.move_speed
		if dir.x != 0.0:
			sprite.flip_h = dir.x < 0.0
	else:
		velocity = velocity.move_toward(Vector2.ZERO, GameState.move_speed)
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
