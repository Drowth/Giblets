extends Node2D

@export var xp_value: int = 10

var _player: Node2D = null
var _attracted: bool = false
var _attract_speed: float = 80.0

func _ready() -> void:
	_player = get_tree().get_first_node_in_group("player")
	queue_redraw()

func _draw() -> void:
	draw_circle(Vector2.ZERO, 7, Color(0.05, 0.7, 0.2))
	draw_circle(Vector2.ZERO, 4, Color(0.3, 1.0, 0.5))
	draw_circle(Vector2.ZERO, 2, Color(0.8, 1.0, 0.85))

func _process(delta: float) -> void:
	if not _player or not is_instance_valid(_player):
		return
	var dist := global_position.distance_to(_player.global_position)
	if dist < GameState.xp_magnet_range:
		_attracted = true
	if _attracted:
		_attract_speed = minf(_attract_speed + 350.0 * delta, 650.0)
		global_position = global_position.move_toward(_player.global_position, _attract_speed * delta)
		dist = global_position.distance_to(_player.global_position)
	if dist < 14.0:
		GameState.add_xp(xp_value)
		queue_free()
