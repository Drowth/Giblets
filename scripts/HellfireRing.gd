extends Node2D

# One-shot expanding fire ring for Hellfire Rounds explosions. Procedural
# _draw() per project style — no sprite exists for this.

var _life: float = 0.0
const DURATION := 0.22
const MAX_RADIUS := 70.0  # matches Projectile.EXPLOSION_RADIUS

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
	draw_arc(Vector2.ZERO, r, 0.0, TAU, 32, Color(1.0, 0.45, 0.0, alpha), 3.0)
	draw_arc(Vector2.ZERO, r * 0.75, 0.0, TAU, 24, Color(1.0, 0.75, 0.1, alpha * 0.6), 2.0)
