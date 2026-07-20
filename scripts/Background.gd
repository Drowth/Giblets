extends Node2D

func _ready() -> void:
	z_index = -9
	queue_redraw()

func _draw() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 0xDEADBEEF
	var bounds := GameState.stage_bounds_rect()
	_draw_tiles(rng, bounds)
	_draw_cracks(rng, bounds)
	_draw_bones(rng, bounds)
	_draw_skulls(rng, bounds)
	_draw_world_border(bounds)

func _draw_tiles(rng: RandomNumberGenerator, bounds: Rect2) -> void:
	const TILE := 64
	var cols := int(bounds.size.x / TILE) + 1
	var rows := int(bounds.size.y / TILE) + 1
	for row in rows:
		for col in cols:
			var x := bounds.position.x + col * TILE
			var y := bounds.position.y + row * TILE
			var v := rng.randf_range(0.050, 0.090)
			# Slight blue tint for cold stone feel
			draw_rect(Rect2(x + 1, y + 1, TILE - 2, TILE - 2), Color(v * 0.87, v * 0.87, v, 1.0))
			# ~8% of tiles get a worn dark overlay
			if rng.randf() < 0.08:
				draw_rect(Rect2(x + 1, y + 1, TILE - 2, TILE - 2), Color(0.0, 0.0, 0.0, 0.28))

func _draw_cracks(rng: RandomNumberGenerator, bounds: Rect2) -> void:
	var crack_color := Color(0.018, 0.018, 0.030, 0.9)
	for _i in 60:
		var pos := bounds.position + Vector2(rng.randf() * bounds.size.x, rng.randf() * bounds.size.y)
		var angle := rng.randf() * TAU
		var cur := pos
		for _s in rng.randi_range(2, 5):
			angle += rng.randf_range(-0.5, 0.5)
			var length := rng.randf_range(12.0, 48.0)
			var nxt := cur + Vector2(cos(angle) * length, sin(angle) * length)
			draw_line(cur, nxt, crack_color, rng.randf_range(1.0, 2.0))
			cur = nxt
			# Occasional branch
			if rng.randf() < 0.35:
				var ba := angle + rng.randf_range(-0.8, 0.8)
				var bl := rng.randf_range(8.0, 24.0)
				draw_line(cur, cur + Vector2(cos(ba) * bl, sin(ba) * bl), crack_color, 1.0)

func _draw_bones(rng: RandomNumberGenerator, bounds: Rect2) -> void:
	for _i in 60:
		var cx := bounds.position.x + rng.randf() * bounds.size.x
		var cy := bounds.position.y + rng.randf() * bounds.size.y
		for _j in rng.randi_range(2, 4):
			var angle := rng.randf() * TAU
			var length := rng.randf_range(7.0, 22.0)
			var thick := rng.randf_range(1.5, 3.0)
			var bv := rng.randf_range(0.48, 0.64)
			var bone_col := Color(bv, bv * 0.93, bv * 0.78)
			var from := Vector2(cx + cos(angle) * 2.0, cy + sin(angle) * 2.0)
			var to := Vector2(cx + cos(angle) * (2.0 + length), cy + sin(angle) * (2.0 + length))
			draw_line(from, to, bone_col, thick)
			# Knob at each end
			draw_circle(from, thick * 1.1, bone_col.lightened(0.08))
			draw_circle(to, thick * 1.2, bone_col.lightened(0.08))

func _draw_skulls(rng: RandomNumberGenerator, bounds: Rect2) -> void:
	for _i in 20:
		var pos := bounds.position + Vector2(rng.randf() * bounds.size.x, rng.randf() * bounds.size.y)
		var sz := rng.randf_range(6.0, 12.0)
		var alpha := rng.randf_range(0.16, 0.32)
		var col := Color(0.54, 0.51, 0.43, alpha)
		var socket_col := Color(0.025, 0.018, 0.040, alpha * 1.6)
		# Braincase
		draw_circle(pos, sz, col)
		# Eye sockets
		draw_circle(pos + Vector2(-sz * 0.36, -sz * 0.10), sz * 0.28, socket_col)
		draw_circle(pos + Vector2(sz * 0.36, -sz * 0.10), sz * 0.28, socket_col)
		# Nose
		draw_circle(pos + Vector2(0.0, sz * 0.25), sz * 0.16, socket_col)

func _draw_world_border(bounds: Rect2) -> void:
	# Dark vignette band at the stage's bounding-rect edges so the hard limit
	# feels intentional. For non-rectangular stages this hugs the bounding
	# box, not the actual polygon edge — a rect vignette is the same
	# rectangle-camera tradeoff already accepted for those stages.
	var x := bounds.position.x
	var y := bounds.position.y
	var w := bounds.size.x
	var h := bounds.size.y
	const BAND := 48.0
	var edge := Color(0.0, 0.0, 0.0, 0.72)
	draw_rect(Rect2(x, y, w, BAND), edge)               # top
	draw_rect(Rect2(x, y + h - BAND, w, BAND), edge)    # bottom
	draw_rect(Rect2(x, y, BAND, h), edge)               # left
	draw_rect(Rect2(x + w - BAND, y, BAND, h), edge)    # right
