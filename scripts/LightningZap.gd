extends Node2D

# One-shot jagged lightning bolt between two world points (Paladin's Judgment
# Chain dash-zap). Procedural per project style — no sprite exists for this.
# Spawned at the world origin (like HellfireRing centers on the caster) so
# from_pos/to_pos can be drawn as absolute world coordinates.

var _life: float = 0.0
const DURATION := 0.18
const SEGMENTS := 7
const JITTER   := 7.0

var from_pos := Vector2.ZERO
var to_pos   := Vector2.ZERO
var color    := Color(0.65, 0.85, 1.0)

func setup(a: Vector2, b: Vector2) -> void:
	from_pos = a
	to_pos = b
	queue_redraw()

func _process(delta: float) -> void:
	_life += delta
	if _life >= DURATION:
		queue_free()
		return
	queue_redraw()

func _draw() -> void:
	var t := clampf(_life / DURATION, 0.0, 1.0)
	var alpha := 1.0 - t
	var perp := (to_pos - from_pos).orthogonal().normalized()
	var prev := from_pos
	for i in range(1, SEGMENTS + 1):
		var f := float(i) / float(SEGMENTS)
		var point := from_pos.lerp(to_pos, f)
		if i < SEGMENTS:
			point += perp * randf_range(-JITTER, JITTER)
		draw_line(prev, point, Color(color, alpha), 2.5)
		prev = point
