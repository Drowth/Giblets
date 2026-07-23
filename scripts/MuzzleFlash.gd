extends Node2D

# One muzzle flash: a brief bright burst at the barrel, oriented along the fire
# direction, that fades over ~70 ms. Spawned once per volley by Player._fire()
# (not per projectile, so multishot builds don't strobe). Procedural, no asset —
# matches the DashDust/HellfireRing transient pattern. z_index above the player
# so it reads on top of the sprite.

var _life:     float = 0.0
var _duration: float = 0.07
var _reach:    float = 22.0  # how far the flash streaks along the fire dir
var _core:     float = 6.0

func setup(dir: Vector2) -> void:
	rotation  = dir.angle() if dir.length() > 0.01 else 0.0
	_duration = randf_range(0.06, 0.085)
	_reach    = randf_range(18.0, 26.0)
	_core     = randf_range(5.0, 7.5)
	z_index   = 5
	# Keep animating/clearing even if a pause lands right after firing.
	process_mode = Node.PROCESS_MODE_ALWAYS
	queue_redraw()

func _process(delta: float) -> void:
	_life += delta
	if _life >= _duration:
		queue_free()
		return
	queue_redraw()

func _draw() -> void:
	var t     := clampf(_life / _duration, 0.0, 1.0)
	var alpha := 1.0 - t
	var reach := _reach * (0.7 + 0.3 * t)  # streak stretches slightly as it fades
	# Outer warm glow
	draw_circle(Vector2.ZERO, _core * 1.9, Color(1.0, 0.6, 0.15, alpha * 0.35))
	# Directional streak: a bright forward-pointing quad along +x (local = dir)
	var w := _core * 0.65
	var streak := PackedVector2Array([
		Vector2(0.0, -w), Vector2(reach, -w * 0.35),
		Vector2(reach,  w * 0.35), Vector2(0.0,  w),
	])
	draw_colored_polygon(streak, Color(1.0, 0.85, 0.4, alpha * 0.8))
	# Hot core
	draw_circle(Vector2.ZERO, _core, Color(1.0, 0.95, 0.75, alpha * 0.9))
	draw_circle(Vector2.ZERO, _core * 0.5, Color(1.0, 1.0, 1.0, alpha))
