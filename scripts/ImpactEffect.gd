extends Node2D

# Small hit-flash spawned where projectiles connect with enemies.
# Procedural _draw() per project style — no sprite exists for this.

var _life: float = 0.0
const DURATION := 0.12
const MAX_RADIUS := 10.0

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
	draw_circle(Vector2.ZERO, r, Color(1.0, 0.95, 0.8, alpha * 0.3))
	draw_arc(Vector2.ZERO, r, 0.0, TAU, 16, Color(1.0, 0.85, 0.5, alpha), 2.0)
