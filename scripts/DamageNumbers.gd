extends Node2D

# Floating damage numbers, drawn in a single _draw() pass (same pattern as
# BloodSmears — one node, capped pool, no per-number scene cost).
# Accessed via group "damage_numbers"; Projectile calls pop().

const MAX_NUMBERS := 48   # FIFO eviction keeps worst-case draw cost flat
const LIFETIME    := 0.7
const RISE_SPEED  := 34.0

var _numbers: Array = []

func _ready() -> void:
	z_index = 20
	add_to_group("damage_numbers")

func pop(pos: Vector2, amount: int, is_crit: bool) -> void:
	if _numbers.size() >= MAX_NUMBERS:
		_numbers.pop_front()
	_numbers.append({
		"pos": pos + Vector2(randf_range(-8, 8), -18),
		"text": str(amount),
		"crit": is_crit,
		"life": 0.0,
	})

func _process(delta: float) -> void:
	if _numbers.is_empty():
		return
	var alive: Array = []
	for n in _numbers:
		n["life"] += delta
		if n["life"] < LIFETIME:
			alive.append(n)
	_numbers = alive
	queue_redraw()

func _draw() -> void:
	var font := ThemeDB.fallback_font
	for n in _numbers:
		var t: float = n["life"] / LIFETIME
		var alpha := 1.0 - t * t
		var pos: Vector2 = to_local(n["pos"]) + Vector2(0, -RISE_SPEED * n["life"])
		if n["crit"]:
			var col := Color(1.0, 0.85, 0.1, alpha)
			draw_string(font, pos + Vector2(1, 1), n["text"], HORIZONTAL_ALIGNMENT_CENTER, -1, 14, Color(0.3, 0.1, 0.0, alpha))
			draw_string(font, pos, n["text"], HORIZONTAL_ALIGNMENT_CENTER, -1, 14, col)
		else:
			draw_string(font, pos + Vector2(1, 1), n["text"], HORIZONTAL_ALIGNMENT_CENTER, -1, 9, Color(0.0, 0.0, 0.0, alpha * 0.7))
			draw_string(font, pos, n["text"], HORIZONTAL_ALIGNMENT_CENTER, -1, 9, Color(1.0, 0.95, 0.85, alpha))
