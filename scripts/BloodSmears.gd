extends Node2D

# Sprite-based blood splats (assets/blood/<variant 1-5>/<001-015>.png).
# Each splat plays its 15-frame splatter animation once, then the final frame
# persists as a floor decal. Hard cap — when full, the oldest decal fades out.
const MAX_SPLATS := 40
const VARIANTS   := 5
const FRAMES     := 15
const ANIM_FPS   := 20.0        # 15 frames -> 0.75 s splat animation
const FADE_TIME  := 1.0
const BASE_SCALE := 0.45        # 128 px canvas -> ~58 px world footprint at scale_mul 1
const FRAME_HALF := Vector2(-64, -64)

var _splats: Array = []
var _frames: Array = []         # [variant][frame] -> Texture2D
var _green_frames: Array = []   # built lazily on first green request (wraith)

func _ready() -> void:
	z_index = -5
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	add_to_group("blood_smears")
	set_process(false)
	for v in VARIANTS:
		var set: Array = []
		for f in FRAMES:
			set.append(load("res://assets/blood/%d/%03d.png" % [v + 1, f + 1]))
		_frames.append(set)

# Call from Enemy on death.
# dir  — normalised movement direction of the enemy (sets the splat's rotation)
# scale_mul — 1.0 for regulars, ~2.5 for bosses
func add_smear(pos: Vector2, dir: Vector2 = Vector2.RIGHT, scale_mul: float = 1.0, tint: Color = Color(1.0, 0.0, 0.0)) -> void:
	var non_fading := 0
	for sp in _splats:
		if sp["fade"] < 0.0:
			non_fading += 1
	if non_fading >= MAX_SPLATS:
		for sp in _splats:
			if sp["fade"] < 0.0:
				sp["fade"] = 0.0
				break

	var rot := dir.angle() + randf_range(-0.5, 0.5) if dir.length_squared() > 0.01 \
		else randf() * TAU
	_splats.append({
		"pos":    pos,
		"rot":    rot,
		"scale":  BASE_SCALE * scale_mul * randf_range(0.85, 1.15),
		"frames": _green_set() if tint.g > tint.r else _frames[randi() % VARIANTS],
		"age":    0.0,
		"fade":   -1.0
	})
	set_process(true)
	queue_redraw()

func _process(delta: float) -> void:
	var busy := false
	var i := 0
	while i < _splats.size():
		var sp: Dictionary = _splats[i]
		if sp["age"] < float(FRAMES) / ANIM_FPS:
			sp["age"] += delta
			busy = true
		if sp["fade"] >= 0.0:
			sp["fade"] += delta
			if sp["fade"] >= FADE_TIME:
				_splats.remove_at(i)
				continue
			busy = true
		i += 1
	queue_redraw()
	if not busy:
		set_process(false)

func _draw() -> void:
	for sp in _splats:
		var frame: int = mini(int(sp["age"] * ANIM_FPS), FRAMES - 1)
		var alpha: float = 1.0 - sp["fade"] / FADE_TIME if sp["fade"] >= 0.0 else 1.0
		var s: float = sp["scale"]
		draw_set_transform(sp["pos"], sp["rot"], Vector2(s, s))
		draw_texture(sp["frames"][frame], FRAME_HALF, Color(1, 1, 1, alpha))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

# Wraith ichor: variant 1 recolored once by swapping the R/G channels.
func _green_set() -> Array:
	if _green_frames.is_empty():
		for tex in _frames[0]:
			var img: Image = tex.get_image()
			img.convert(Image.FORMAT_RGBA8)
			for y in img.get_height():
				for x in img.get_width():
					var c := img.get_pixel(x, y)
					img.set_pixel(x, y, Color(c.g, c.r, c.b, c.a))
			_green_frames.append(ImageTexture.create_from_image(img))
	return _green_frames
