extends Node2D

var _dir:      Vector2 = Vector2.RIGHT
var _speed:    float   = 75.0
var _lifetime: float   = 2.5

func launch(dir: Vector2) -> void:
	_dir = dir
	queue_redraw()

func _process(delta: float) -> void:
	global_position += _dir * _speed * delta
	_lifetime -= delta
	if _lifetime <= 0.0:
		queue_free()
		return
	var player := get_tree().get_first_node_in_group("player")
	if player and global_position.distance_to(player.global_position) < 14.0:
		if player.has_method("apply_slow"):
			player.apply_slow(3.0, 0.4)
		queue_free()

func _draw() -> void:
	draw_circle(Vector2.ZERO, 6.5, Color(0.35, 0.35, 0.35, 0.92))
	draw_circle(Vector2.ZERO, 4.5, Color(0.72, 0.72, 0.72, 0.88))
	draw_circle(Vector2.ZERO, 2.2, Color(0.96, 0.96, 0.96, 0.95))
	for i in 4:
		var angle := float(i) * PI * 0.25
		var end   := Vector2(cos(angle), sin(angle)) * 6.5
		draw_line(Vector2.ZERO, end, Color(0.88, 0.88, 0.88, 0.75), 0.9)
