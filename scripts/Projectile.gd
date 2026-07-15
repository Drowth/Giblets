extends Area2D

const EXPLOSION_RADIUS := 70.0  # Hellfire Rounds AoE (docs/BALANCE.md §5)

var _dir: Vector2 = Vector2.RIGHT
var _speed: float = 400.0
var _damage: int = 10
var _pierce: int = 0
var _hit_set: Array = []
var _lifetime: float = 3.5

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	queue_redraw()

func launch(direction: Vector2, dmg: int, spd: float, pierce: int = 0) -> void:
	_dir = direction
	_damage = dmg
	_speed = spd
	_pierce = pierce

func _draw() -> void:
	draw_circle(Vector2.ZERO, 4, Color(1.0, 0.75, 0.1, 0.85))
	draw_circle(Vector2.ZERO, 2.5, Color(1.0, 0.45, 0.0, 0.9))
	draw_circle(Vector2.ZERO, 1.5, Color(1.0, 1.0, 0.8))

func _process(delta: float) -> void:
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
	GameState.screen_shake(4.0, 0.04)
	if GameState.knockback_force > 0.0 and body.has_method("apply_knockback"):
		body.apply_knockback(_dir, GameState.knockback_force)
	if GameState.explosive_pct > 0.0:
		_explode(body)
	if _hit_set.size() > _pierce:
		queue_free()

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

func _pop_number(pos: Vector2, amount: int, is_crit: bool) -> void:
	var dn := get_tree().get_first_node_in_group("damage_numbers")
	if dn:
		dn.pop(pos, amount, is_crit)
