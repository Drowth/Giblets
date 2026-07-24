extends Node2D

# One muzzle flash: a bright burst at the barrel, oriented along the fire
# direction, that fades over ~150 ms. Spawned once per volley by Player._fire()
# (not per projectile, so multishot builds don't strobe). Procedural, no asset —
# matches the DashDust/HellfireRing transient pattern.
#
# Sizing note: the camera runs at zoom 0.3 (zoomed OUT), so world px render at
# ~0.3x. These radii are therefore large in world units — a ~28 px core reads as
# ~8 screen px, roughly a third of the player's ~43 px height. Anything smaller
# is invisible in practice, especially inside the player's torch light.

var _life:     float = 0.0
var _duration: float = 0.15
var _reach:    float = 54.0  # how far the flash streaks along the fire dir
var _core:     float = 13.0

func setup(dir: Vector2) -> void:
	rotation  = dir.angle() if dir.length() > 0.01 else 0.0
	_duration = randf_range(0.13, 0.17)
	_reach    = randf_range(46.0, 62.0)
	_core     = randf_range(11.0, 15.0)
	z_index   = 10  # above the player sprite and world decorations
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
	var alpha := 1.0 - t * t  # hold bright, then fall away fast
	var reach := _reach * (0.7 + 0.3 * t)  # streak stretches slightly as it fades
	# Outer warm glow
	draw_circle(Vector2.ZERO, _core * 2.1, Color(1.0, 0.55, 0.12, alpha * 0.45))
	# Directional streak: a bright forward-pointing quad along +x (local = dir)
	var w := _core * 0.8
	var streak := PackedVector2Array([
		Vector2(0.0, -w), Vector2(reach, -w * 0.30),
		Vector2(reach,  w * 0.30), Vector2(0.0,  w),
	])
	draw_colored_polygon(streak, Color(1.0, 0.82, 0.35, alpha * 0.9))
	# Hot core
	draw_circle(Vector2.ZERO, _core, Color(1.0, 0.93, 0.70, alpha))
	draw_circle(Vector2.ZERO, _core * 0.55, Color(1.0, 1.0, 1.0, alpha))
