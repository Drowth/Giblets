extends CharacterBody2D

const XP_ORB_SCENE = preload("res://scenes/XPOrb.tscn")
const BLOOD_SCENE = preload("res://scenes/BloodSplatter.tscn")

@export var move_speed: float = 60.0
@export var max_health: int = 25
@export var health: int = 25
@export var xp_value: int = 20
@export var damage: int = 10
@export var contact_cooldown: float = 0.8

var _player: Node2D = null
var _contact_timer: float = 0.0
var _dead: bool = false
var _xp_container: Node = null

func _ready() -> void:
	add_to_group("enemies")
	health = max_health
	_player = get_tree().get_first_node_in_group("player")
	queue_redraw()

func _draw() -> void:
	var hp_ratio := float(health) / float(max_health) if max_health > 0 else 0.0
	var body_col := Color(0.5 + (1.0 - hp_ratio) * 0.35, 0.04, 0.04)
	draw_circle(Vector2.ZERO, 14, body_col)
	draw_arc(Vector2.ZERO, 14, 0, TAU, 32, Color(0.15, 0.0, 0.0), 2.5)
	draw_circle(Vector2(-5, -4), 4, Color(1.0, 0.75, 0.0))
	draw_circle(Vector2(5, -4), 4, Color(1.0, 0.75, 0.0))
	draw_circle(Vector2(-5, -4), 2, Color.BLACK)
	draw_circle(Vector2(5, -4), 2, Color.BLACK)
	if hp_ratio < 1.0:
		draw_rect(Rect2(-14, -23, 28, 4), Color(0.12, 0.0, 0.0))
		draw_rect(Rect2(-14, -23, 28.0 * hp_ratio, 4), Color(0.85, 0.1, 0.1))

func _physics_process(delta: float) -> void:
	if _dead:
		return
	if not _player or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player")
		return
	_contact_timer = maxf(0.0, _contact_timer - delta)
	var dir := (_player.global_position - global_position).normalized()
	velocity = dir * move_speed
	move_and_slide()
	if global_position.distance_to(_player.global_position) < 25.0 and _contact_timer <= 0.0:
		_contact_timer = contact_cooldown
		if _player.has_method("take_damage"):
			_player.take_damage(damage)
	queue_redraw()

func take_hit(dmg: int) -> void:
	if _dead:
		return
	health -= dmg
	queue_redraw()
	if health <= 0:
		_die()
		return
	modulate = Color(2.5, 0.6, 0.6)
	await get_tree().create_timer(0.09).timeout
	if not _dead:
		modulate = Color.WHITE

func _die() -> void:
	_dead = true
	set_physics_process(false)
	GameState.add_kill_score(xp_value)
	_spawn_blood()
	_drop_xp()
	queue_free()

func _spawn_blood() -> void:
	var splat = BLOOD_SCENE.instantiate()
	get_parent().add_child(splat)
	splat.global_position = global_position

func _drop_xp() -> void:
	if not _xp_container or not is_instance_valid(_xp_container):
		_xp_container = get_tree().get_first_node_in_group("xp_orbs_container")
	if not _xp_container:
		return
	var orb_count := clampi(xp_value / 5, 1, 6)
	var orb_xp := xp_value / orb_count
	for i in orb_count:
		var orb = XP_ORB_SCENE.instantiate()
		_xp_container.add_child(orb)
		orb.global_position = global_position + Vector2(randf_range(-18, 18), randf_range(-18, 18))
		orb.xp_value = orb_xp
