extends Node2D

var _time:   float = 0.0
var _done:   bool  = false
var _player: Node2D = null

func _ready() -> void:
	_player = get_tree().get_first_node_in_group("player")
	queue_redraw()

func _process(delta: float) -> void:
	if _done:
		return
	_time += delta
	queue_redraw()

	if not _player or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player")
		return
	if global_position.distance_to(_player.global_position) < 26.0:
		_explode()

func _draw() -> void:
	var pulse := sin(_time * 5.0) * 0.5 + 0.5
	var bob   := sin(_time * 2.4) * 5.0
	# Outer glow
	draw_circle(Vector2(0, bob), 22.0 + pulse * 6.0, Color(1.0, 0.2, 0.0, 0.18 + pulse * 0.14))
	# Fire ring
	draw_circle(Vector2(0, bob), 17.0,               Color(1.0, 0.42, 0.0, 0.92))
	# Core
	draw_circle(Vector2(0, bob), 11.0,               Color(1.0, 0.76, 0.1))
	# Bright centre
	draw_circle(Vector2(0, bob),  5.0,               Color(1.0, 1.0, 0.88))
	var font := ThemeDB.fallback_font
	draw_string(font, Vector2(-15, bob - 26.0), "BOMB", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(1.0, 0.7, 0.0))

# ---------------------------------------------------------------------------
func _explode() -> void:
	_done = true
	set_process(false)
	var main := get_tree().current_scene

	# Kill every enemy instantly with fire
	for enemy in get_tree().get_nodes_in_group("enemies"):
		_fire_burst(enemy.global_position, 16, main)
		if enemy.has_method("fire_kill"):
			enemy.fire_kill()

	# Large central explosion
	_fire_burst(get_viewport_rect().size * 0.5, 220, main)

	# Orange screen flash
	var canvas := CanvasLayer.new()
	canvas.layer = 20
	var flash := ColorRect.new()
	flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	flash.color = Color(1.0, 0.35, 0.0, 0.6)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(flash)
	main.add_child(canvas)
	var tw := flash.create_tween()
	tw.tween_property(flash, "modulate:a", 0.0, 0.55)
	tw.tween_callback(canvas.queue_free)

	queue_free()

func _fire_burst(pos: Vector2, amount: int, parent: Node) -> void:
	var p := CPUParticles2D.new()
	p.emitting             = true
	p.amount               = amount
	p.lifetime             = 1.6
	p.one_shot             = true
	p.explosiveness        = 0.86
	p.direction            = Vector2(0.0, -1.0)
	p.spread               = 180.0
	p.gravity              = Vector2(0.0, -50.0)
	p.initial_velocity_min = 55.0
	p.initial_velocity_max = 310.0
	p.scale_amount_min     = 4.0
	p.scale_amount_max     = 13.0
	p.color                = Color(1.0, 0.42, 0.0)
	p.position             = pos
	parent.add_child(p)
	get_tree().create_timer(p.lifetime + 0.5).timeout.connect(p.queue_free)
