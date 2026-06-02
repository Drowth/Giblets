extends Node2D

# Hard cap — old smears are evicted FIFO to keep performance flat
const MAX_SMEARS := 150

var _smears: Array = []

func _ready() -> void:
	z_index = -5
	add_to_group("blood_smears")

# Call from Enemy on death.
# dir  — normalised movement direction of the enemy (used for smear trail axis)
# scale_mul — 1.0 for regulars, ~2.5 for bosses
func add_smear(pos: Vector2, dir: Vector2 = Vector2.RIGHT, scale_mul: float = 1.0) -> void:
	if _smears.size() >= MAX_SMEARS:
		_smears.pop_front()

	var rng := RandomNumberGenerator.new()
	rng.seed = hash(pos) ^ (Time.get_ticks_msec() & 0xFFFFFF)

	var d := dir.normalized() if dir.length_squared() > 0.01 \
		else Vector2(rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0)).normalized()

	var main_r  := rng.randf_range(10.0, 17.0) * scale_mul
	var length  := rng.randf_range(20.0, 44.0) * scale_mul
	var redness := rng.randf_range(0.12, 0.22)
	var alpha   := rng.randf_range(0.60, 0.80)
	var col     := Color(redness,         0.0, 0.0, alpha)
	var icol    := Color(redness * 0.50,  0.0, 0.0, alpha * 0.72)

	# Satellite splatter drops
	var dots: Array = []
	for _i in rng.randi_range(4, 9):
		var spread := rng.randf_range(main_r * 0.7, length * 1.3)
		var da := rng.randf() * TAU
		dots.append({
			"ofs": Vector2(cos(da) * spread, sin(da) * spread),
			"r":   rng.randf_range(2.0, 7.0) * scale_mul,
			"col": Color(redness * 0.7, 0.0, 0.0, rng.randf_range(0.28, 0.52))
		})

	_smears.append({
		"pos":  pos,
		"dir":  d,
		"len":  length,
		"r":    main_r,
		"col":  col,
		"icol": icol,
		"dots": dots
	})

	queue_redraw()

func _draw() -> void:
	for sm in _smears:
		_draw_one(sm)

func _draw_one(sm: Dictionary) -> void:
	var pos: Vector2 = sm["pos"]
	var d:   Vector2 = sm["dir"]
	var r:   float   = sm["r"]
	var l:   float   = sm["len"]
	var col: Color   = sm["col"]

	# Trail: two circles extending backward along movement direction
	draw_circle(pos - d * l * 0.70, r * 0.40, col)
	draw_circle(pos - d * l * 0.35, r * 0.68, col)
	# Main pool
	draw_circle(pos, r, col)
	draw_circle(pos, r * 0.52, sm["icol"])
	# Forward splatter nub
	draw_circle(pos + d * r * 0.65, r * 0.32, col)

	# Satellite drops
	for dot in sm["dots"]:
		draw_circle(pos + dot["ofs"], dot["r"], dot["col"])
