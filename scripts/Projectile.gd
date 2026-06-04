extends Area2D

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
	if body.has_method("take_hit"):
		body.take_hit(_damage)
	if GameState.knockback_force > 0.0 and body.has_method("apply_knockback"):
		body.apply_knockback(_dir, GameState.knockback_force)
	if _hit_set.size() > _pierce:
		queue_free()
