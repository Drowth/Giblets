extends Node2D

var _size: float = 2.5
var _col: Color = Color(0.5, 0.0, 0.0, 1.0)

func setup(sz: float, col: Color) -> void:
	_size = sz
	_col  = col
	z_index = -2
	queue_redraw()
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, randf_range(0.45, 0.75))
	tw.tween_callback(queue_free)

func _draw() -> void:
	draw_circle(Vector2.ZERO, _size, _col)
