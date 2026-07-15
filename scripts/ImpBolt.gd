extends Node2D

# Imp's ranged attack. Manual distance check against the player per the
# project's pickup/projectile-vs-player pattern (no Area2D signals).

var _dir:      Vector2 = Vector2.RIGHT
var _speed:    float   = 220.0
var _damage:   int     = 7
var _lifetime: float   = 2.5

func launch(dir: Vector2, dmg: int) -> void:
	_dir = dir
	_damage = dmg
	queue_redraw()

func _process(delta: float) -> void:
	global_position += _dir * _speed * delta
	_lifetime -= delta
	if _lifetime <= 0.0:
		queue_free()
		return
	var player := get_tree().get_first_node_in_group("player")
	if player and global_position.distance_to(player.global_position) < 14.0:
		if player.has_method("take_damage"):
			player.take_damage(_damage)
		queue_free()

func _draw() -> void:
	# Ember bolt with a short tail
	draw_line(-_dir * 10.0, Vector2.ZERO, Color(1.0, 0.35, 0.0, 0.5), 3.0)
	draw_circle(Vector2.ZERO, 4.0, Color(1.0, 0.45, 0.05, 0.9))
	draw_circle(Vector2.ZERO, 2.0, Color(1.0, 0.9, 0.4))
