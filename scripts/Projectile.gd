extends Area2D

const EXPLOSION_RADIUS := 70.0  # Hellfire Rounds AoE (docs/BALANCE.md §5)

# --- Spell visuals (assets/projectiles/<kind>/001-015.png, art faces E) ---
# The set a shot uses is resolved in launch() from the build state (the sentry
# passes "death" explicitly): Wishbone -> arc crescent, Hellfire -> enlarged
# deep-red fire, Velocity stacks -> ice streak (stretched per stack), else
# fire. Frames play 0-14 once (ignition), then the tail loops in flight.
const VIS_FRAMES    := 15
const VIS_FPS       := 30.0
const VIS_LOOP_FROM := 11.0
const HEAD_ANCHOR   := 0.75   # fraction of the texture trailing behind the hitbox
const BOLT_SCALE    := 0.30   # fire/ice/death (256x64)
const ARC_SCALE     := 0.22   # arc crescent (256x256)
const HELLFIRE_SCALE := 0.45
const HELLFIRE_MOD   := Color(1.25, 0.7, 0.6)
const ICE_STRETCH_PER_STACK := 0.025

static var _vis_cache: Dictionary = {}

var _dir: Vector2 = Vector2.RIGHT
var _speed: float = 400.0
var _damage: int = 10
var _pierce: int = 0
var _bounces: int = 0     # Wishbone: retargets left once pierce is spent
var _hit_set: Array = []
var _lifetime: float = 3.5

var _tex_frames: Array = []
var _vis_scale: Vector2 = Vector2.ONE
var _vis_mod: Color = Color.WHITE
var _frame: float = 0.0

const RICOCHET_RANGE := 260.0

var _light: PointLight2D = null

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR  # HD frames; project default is nearest
	_add_light()
	queue_redraw()

func _add_light() -> void:
	_light = PointLight2D.new()
	_light.texture = _make_light_texture()
	_light.texture_scale = 0.75
	_light.energy = 0.8
	_light.blend_mode = PointLight2D.BLEND_MODE_ADD
	add_child(_light)

func _make_light_texture() -> GradientTexture2D:
	var grad := Gradient.new()
	grad.set_color(0, Color(1.0, 1.0, 1.0, 1.0))
	grad.set_color(1, Color(1.0, 1.0, 1.0, 0.0))
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(0.5, 0.0)
	tex.width = 128
	tex.height = 128
	return tex

func launch(direction: Vector2, dmg: int, spd: float, pierce: int = 0, visual: String = "auto") -> void:
	_dir = direction
	_damage = dmg
	_speed = spd
	_pierce = pierce
	_bounces = GameState.ricochet_bounces
	_set_visual(visual)
	rotation = _dir.angle()

func _set_visual(visual: String) -> void:
	var kind := visual
	_vis_scale = Vector2(BOLT_SCALE, BOLT_SCALE)
	if visual == "auto":
		if GameState.ricochet_bounces > 0:
			kind = "arc"
		elif GameState.explosive_pct > 0.0:
			kind = "fire"
			_vis_scale = Vector2(HELLFIRE_SCALE, HELLFIRE_SCALE)
			_vis_mod = HELLFIRE_MOD
		else:
			var speed_stacks: int = GameState.upgrade_stacks.get("proj_speed_1", 0)
			if speed_stacks > 0:
				kind = "ice"
				_vis_scale.x += ICE_STRETCH_PER_STACK * speed_stacks
			else:
				kind = "fire"
	if kind == "arc":
		_vis_scale = Vector2(ARC_SCALE, ARC_SCALE)
	_tex_frames = _get_frames(kind)
	# Tint the dynamic light to match the spell element
	if _light:
		match kind:
			"ice":
				_light.color = Color(0.35, 0.75, 1.0)
			"arc":
				_light.color = Color(1.0, 0.9, 0.3)
			"death":
				_light.color = Color(0.4, 1.0, 0.3)
			_:
				_light.color = Color(1.0, 0.55, 0.15)  # fire / default

static func _get_frames(kind: String) -> Array:
	if kind in _vis_cache:
		return _vis_cache[kind]
	var frames: Array = []
	for i in VIS_FRAMES:
		var path := "res://assets/projectiles/%s/%03d.png" % [kind, i + 1]
		if not ResourceLoader.exists(path):
			frames.clear()
			break
		frames.append(load(path))
	_vis_cache[kind] = frames
	return frames

func _draw() -> void:
	if _tex_frames.is_empty():
		# Fallback: the original procedural bolt (frame set missing)
		draw_circle(Vector2.ZERO, 4, Color(1.0, 0.75, 0.1, 0.85))
		draw_circle(Vector2.ZERO, 2.5, Color(1.0, 0.45, 0.0, 0.9))
		draw_circle(Vector2.ZERO, 1.5, Color(1.0, 1.0, 0.8))
		return
	var tex: Texture2D = _tex_frames[mini(int(_frame), VIS_FRAMES - 1)]
	var size: Vector2 = tex.get_size() * _vis_scale
	draw_texture_rect(tex, Rect2(Vector2(-size.x * HEAD_ANCHOR, -size.y * 0.5), size), false, _vis_mod)

func _process(delta: float) -> void:
	if not _tex_frames.is_empty():
		_frame += VIS_FPS * delta
		if _frame >= float(VIS_FRAMES):
			_frame = VIS_LOOP_FROM
		queue_redraw()
	global_position += _dir * _speed * delta
	_lifetime -= delta
	if _lifetime <= 0.0:
		queue_free()
		return
	var vp_size := get_viewport_rect().size
	var cam := get_viewport().get_camera_2d()
	var zoom := cam.zoom.x if cam else 1.0
	var cam_center := cam.get_screen_center_position() if cam else vp_size / 2.0
	var half := vp_size * 0.5 / zoom
	var margin := 100.0
	if (global_position.x < cam_center.x - half.x - margin or
			global_position.x > cam_center.x + half.x + margin or
			global_position.y < cam_center.y - half.y - margin or
			global_position.y > cam_center.y + half.y + margin):
		queue_free()

func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("enemies"):
		return
	if body in _hit_set:
		return
	_hit_set.append(body)
	# Crit roll happens per hit so each pierce target rolls independently
	var is_crit := randf() < GameState.crit_chance
	var dmg := _damage if not is_crit else int(_damage * GameState.crit_mult)
	if body.has_method("take_hit"):
		body.take_hit(dmg)
	GameState.damage_dealt += dmg
	_pop_number(body.global_position, dmg, is_crit)
	GameState.play_hit_sfx(is_crit)
	GameState.screen_shake(4.0, 0.04)
	_spawn_impact(body.global_position)
	if GameState.knockback_force > 0.0 and body.has_method("apply_knockback"):
		body.apply_knockback(_dir, GameState.knockback_force)
	if GameState.explosive_pct > 0.0:
		_explode(body)
	if _hit_set.size() > _pierce:
		# Wishbone: instead of dying, snap toward a fresh victim in range
		if _bounces > 0 and _ricochet():
			_bounces -= 1
		else:
			queue_free()

# Retarget at the nearest enemy not yet hit; false if none in range.
func _ricochet() -> bool:
	var nearest: Node2D = null
	var nearest_dist := RICOCHET_RANGE
	for enemy: Node2D in get_tree().get_nodes_in_group("enemies"):
		if enemy in _hit_set:
			continue
		var d := global_position.distance_to(enemy.global_position)
		if d < nearest_dist:
			nearest_dist = d
			nearest = enemy
	if not nearest:
		return false
	var to_target := nearest.global_position - global_position
	if to_target.length_squared() < 0.0001:
		return false
	_dir = to_target.normalized()
	rotation = _dir.angle()
	_lifetime = maxf(_lifetime, 1.0)
	return true

# Hellfire Rounds: splash a fraction of the hit onto everything nearby.
# No chain reaction — splash never triggers further explosions.
func _explode(center: Node2D) -> void:
	var splash := int(_damage * GameState.explosive_pct)
	if splash <= 0:
		return
	_flash_ring(center.global_position)
	for enemy: Node2D in get_tree().get_nodes_in_group("enemies"):
		if enemy == center or enemy in _hit_set:
			continue
		if enemy.global_position.distance_to(center.global_position) <= EXPLOSION_RADIUS:
			if enemy.has_method("take_hit"):
				enemy.take_hit(splash)
				GameState.damage_dealt += splash
				_pop_number(enemy.global_position, splash, false)

func _flash_ring(pos: Vector2) -> void:
	var ring := Node2D.new()
	ring.set_script(preload("res://scripts/HellfireRing.gd"))
	get_tree().current_scene.add_child(ring)
	ring.global_position = pos

func _spawn_impact(pos: Vector2) -> void:
	var impact := Node2D.new()
	impact.set_script(preload("res://scripts/ImpactEffect.gd"))
	get_tree().current_scene.add_child(impact)
	impact.global_position = pos

func _pop_number(pos: Vector2, amount: int, is_crit: bool) -> void:
	var dn := get_tree().get_first_node_in_group("damage_numbers")
	if dn:
		dn.pop(pos, amount, is_crit)
