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
	draw_circle(Vector2.ZERO, 7, Color(1.0, 0.85, 0.1))
	draw_circle(Vector2.ZERO, 4, Color(1.0, 0.45, 0.0))
	draw_circle(Vector2.ZERO, 2, Color(1.0, 1.0, 0.8))

func _process(delta: float) -> void:
	global_position += _dir * _speed * delta
	_lifetime -= delta
	if _lifetime <= 0.0:
		queue_free()
		return
	var vp := get_viewport_rect()
	if (global_position.x < -60 or global_position.x > vp.size.x + 60
			or global_position.y < -60 or global_position.y > vp.size.y + 60):
		queue_free()

func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("enemies"):
		return
	if body in _hit_set:
		return
	_hit_set.append(body)
	if body.has_method("take_hit"):
		body.take_hit(_damage)
	if _hit_set.size() > _pierce:
		queue_free()
