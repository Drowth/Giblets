extends Node2D

# One dash dust puff: an expanding, fading cloud that drifts opposite the
# dash direction. ~35% of puffs also draw a short ember spark streak.

var _dir:      Vector2 = Vector2.RIGHT
var _life:     float   = 0.0
var _duration: float   = 0.35
var _radius:   float   = 3.5
var _drift:    float   = 45.0
var _spark:    bool    = false
var _offset2:  Vector2 = Vector2.ZERO

func setup(dash_dir: Vector2) -> void:
	_dir      = dash_dir.normalized() if dash_dir.length() > 0.01 else Vector2.RIGHT
	_duration = randf_range(0.22, 0.40)
	_radius   = randf_range(2.5, 5.0)
	_drift    = randf_range(30.0, 60.0)
	_spark    = randf() < 0.35
	_offset2  = Vector2(randf_range(-3, 3), randf_range(-3, 3))
	rotation  = _dir.angle()
	z_index   = -1
	queue_redraw()

func _process(delta: float) -> void:
	_life += delta
	if _life >= _duration:
		queue_free()
		return
	position -= _dir * _drift * delta
	queue_redraw()

func _draw() -> void:
	var t     := clampf(_life / _duration, 0.0, 1.0)
	var alpha := 1.0 - t
	var r     := _radius * (1.0 + t * 2.2)
	draw_circle(Vector2.ZERO, r, Color(0.55, 0.50, 0.44, alpha * 0.40))
	draw_circle(_offset2, r * 0.6, Color(0.70, 0.66, 0.58, alpha * 0.30))
	if _spark:
		var len := 9.0 * alpha
		draw_line(Vector2(-len, 0), Vector2(len * 0.3, 0), Color(1.0, 0.75, 0.20, alpha * 0.9), 1.5)
