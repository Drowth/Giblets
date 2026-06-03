extends Node2D

@export var xp_value: int = 10

var _player: Node2D = null
var _attracted: bool = false
var _attract_speed: float = 80.0

func _ready() -> void:
	_player = get_tree().get_first_node_in_group("player")
	queue_redraw()

func _get_radius() -> float:
	return clampf(5.0 + xp_value * 0.07, 5.0, 13.0)

func _draw() -> void:
	var r := _get_radius()
	var outer: Color
	var mid:   Color
	var inner: Color
	if xp_value <= 30:       # green — early game
		outer = Color(0.00, 0.50, 0.12)
		mid   = Color(0.15, 0.85, 0.30)
		inner = Color(0.70, 1.00, 0.75)
	elif xp_value <= 100:    # blue — mid game
		outer = Color(0.02, 0.10, 0.65)
		mid   = Color(0.15, 0.40, 1.00)
		inner = Color(0.70, 0.82, 1.00)
	else:                    # red — late game / boss
		outer = Color(0.55, 0.00, 0.00)
		mid   = Color(1.00, 0.15, 0.05)
		inner = Color(1.00, 0.75, 0.70)
	draw_circle(Vector2.ZERO, r,        outer)
	draw_circle(Vector2.ZERO, r * 0.60, mid)
	draw_circle(Vector2.ZERO, r * 0.30, inner)

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
	if dist < _get_radius() + 7.0:
		GameState.add_xp(xp_value)
		var sfx = get_tree().get_first_node_in_group("xp_pickup_sfx")
		if sfx:
			sfx.play()
		queue_free()
