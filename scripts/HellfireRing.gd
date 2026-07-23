extends Node2D

# One-shot expanding ring for Hellfire Rounds explosions and nova effects
# (Tantrum). Procedural _draw() per project style — no sprite exists for this.
# Colors default to the original fire palette; callers that want a different
# tone use set_colors().

var _life: float = 0.0
const DURATION := 0.22
const MAX_RADIUS := 70.0  # matches Projectile.EXPLOSION_RADIUS

var outer_color := Color(1.0, 0.45, 0.0)
var inner_color := Color(1.0, 0.75, 0.1)

func set_colors(outer: Color, inner: Color) -> void:
	outer_color = outer
	inner_color = inner

func _process(delta: float) -> void:
	_life += delta
	if _life >= DURATION:
		queue_free()
		return
	queue_redraw()

func _draw() -> void:
	var t := clampf(_life / DURATION, 0.0, 1.0)
	var r := MAX_RADIUS * (0.35 + 0.65 * t)
	var alpha := (1.0 - t) * 0.7
	draw_arc(Vector2.ZERO, r, 0.0, TAU, 32, Color(outer_color, alpha), 3.0)
	draw_arc(Vector2.ZERO, r * 0.75, 0.0, TAU, 24, Color(inner_color, alpha * 0.6), 2.0)
