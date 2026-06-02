extends Node2D

const PROJECTILE_SCENE = preload("res://scenes/Projectile.tscn")

var _fire_timer: float = 0.0
var _bob_time: float = 0.0
var _proj_container: Node2D = null

func _process(delta: float) -> void:
	if not GameState.game_active:
		return
	_bob_time += delta
	queue_redraw()
	_fire_timer -= delta
	if _fire_timer <= 0.0:
		_fire_timer = 1.0 / GameState.fire_rate
		_try_fire()

func _try_fire() -> void:
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
	var dir := (nearest.global_position - global_position).normalized()
	scale.x = -1.0 if dir.x < 0 else 1.0
	var count := GameState.projectile_count
	for i in count:
		var angle_offset := 0.0
		if count > 1:
			angle_offset = lerp(-0.1, 0.1, float(i) / float(count - 1))
		var proj: Area2D = PROJECTILE_SCENE.instantiate()
		_proj_container.add_child(proj)
		proj.global_position = global_position
		proj.launch(dir.rotated(angle_offset), GameState.projectile_damage, GameState.projectile_speed, GameState.projectile_pierce)

func _draw() -> void:
	var by := sin(_bob_time * 2.5) * 2.5

	# Soft purple aura
	draw_circle(Vector2(0, by), 22.0, Color(0.40, 0.05, 0.60, 0.18))

	# Skull
	draw_circle(Vector2(0, by), 16.0, Color(0.86, 0.81, 0.72))

	# Eye sockets
	draw_circle(Vector2(-6, by - 2), 5.0, Color(0.04, 0.0, 0.06))
	draw_circle(Vector2(6, by - 2), 5.0, Color(0.04, 0.0, 0.06))

	# Purple glowing eyes — pulse with bob_time
	var pulse := 0.6 + sin(_bob_time * 4.0) * 0.4
	draw_circle(Vector2(-6, by - 2), 3.5, Color(0.639, 0.208, 0.933, pulse))
	draw_circle(Vector2(6, by - 2), 3.5, Color(0.639, 0.208, 0.933, pulse))
	draw_circle(Vector2(-6, by - 2), 1.5, Color(0.95, 0.80, 1.0))
	draw_circle(Vector2(6, by - 2), 1.5, Color(0.95, 0.80, 1.0))

	# Nose cavity
	draw_circle(Vector2(0, by + 3), 2.5, Color(0.28, 0.24, 0.20))

	# Teeth — 5 stubs along jaw line
	for i in 5:
		draw_rect(Rect2(-9.5 + i * 4.0, by + 8.5, 3.0, 5.0), Color(0.95, 0.92, 0.88))

	# Hanging chain below skull
	for i in 4:
		var cy := by + 22.0 + i * 6.0
		draw_circle(Vector2(0, cy), 2.0, Color(0.50, 0.47, 0.40))
		draw_circle(Vector2(0, cy), 1.0, Color(0.70, 0.67, 0.58))
