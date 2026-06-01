extends CharacterBody2D

const PROJECTILE_SCENE = preload("res://scenes/Projectile.tscn")

@onready var attack_timer: Timer = $AttackTimer
@onready var iframes_timer: Timer = $IFramesTimer

var is_invincible: bool = false
var _proj_container: Node2D = null

func _ready() -> void:
	add_to_group("player")
	attack_timer.wait_time = 1.0 / GameState.fire_rate
	attack_timer.timeout.connect(_fire)
	iframes_timer.timeout.connect(func(): is_invincible = false)
	GameState.game_over.connect(_on_game_over)
	queue_redraw()

func _draw() -> void:
	draw_circle(Vector2.ZERO, 16, Color(0.2, 0.3, 0.55))
	draw_circle(Vector2.ZERO, 12, Color(0.3, 0.45, 0.75))
	draw_arc(Vector2.ZERO, 16, 0, TAU, 32, Color(0.5, 0.7, 1.0), 2.0)
	draw_circle(Vector2(-5, -3), 4, Color(0.9, 0.1, 0.1))
	draw_circle(Vector2(5, -3), 4, Color(0.9, 0.1, 0.1))
	draw_circle(Vector2(-5, -3), 2, Color(0.1, 0.0, 0.0))
	draw_circle(Vector2(5, -3), 2, Color(0.1, 0.0, 0.0))

func _physics_process(_delta: float) -> void:
	var dir := Vector2(
		Input.get_axis("ui_left", "ui_right"),
		Input.get_axis("ui_up", "ui_down")
	)
	if dir != Vector2.ZERO:
		velocity = dir.normalized() * GameState.move_speed
	else:
		velocity = velocity.move_toward(Vector2.ZERO, GameState.move_speed)
	move_and_slide()
	var vp := get_viewport_rect()
	global_position.x = clampf(global_position.x, 20.0, vp.size.x - 20.0)
	global_position.y = clampf(global_position.y, 20.0, vp.size.y - 20.0)

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
			angle_offset = lerp(-0.3, 0.3, float(i) / float(count - 1))
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

func _on_game_over() -> void:
	set_physics_process(false)
	attack_timer.stop()
	modulate = Color(0.4, 0.0, 0.0)
