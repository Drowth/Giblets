extends Node2D

const PROJECTILE_SCENE = preload("res://scenes/Projectile.tscn")

const ORBIT_RADIUS := 90.0
const ORBIT_SPEED  := 1.1

var _fire_timer: float = 0.0
var _bob_time: float = 0.0
var _orbit_angle: float = 0.0
var _player: Node2D = null
var _proj_container: Node2D = null
var _sprite: Sprite2D = null
# Set by the spawner for batch spawns (start-of-run sentries) where
# sentry_count is already at its final value and can't disambiguate slots.
var orbit_index: int = -1
# Bone Harvest (Necromancer): temporary sentries self-expire; permanent
# sentries never set this and orbit forever.
var lifespan: float = -1.0

func _ready() -> void:
	_player = get_tree().get_first_node_in_group("player")
	# Spread multiple sentries evenly. Incremental spawns (level-up picks)
	# derive the slot from sentry_count, which is incremented before spawn.
	var slot := orbit_index if orbit_index >= 0 else GameState.sentry_count - 1
	_orbit_angle = slot * (TAU / 3.0)
	_sprite = Sprite2D.new()
	_sprite.texture = load("res://assets/pickups/sentinel.png")
	var s := 48.0 / _sprite.texture.get_size().y
	_sprite.scale = Vector2(s, s)
	add_child(_sprite)

func _process(delta: float) -> void:
	if not GameState.game_active:
		return
	if lifespan > 0.0:
		lifespan -= delta
		if lifespan <= 0.0:
			GameState.sentry_count = maxi(0, GameState.sentry_count - 1)
			GameState.temp_sentry_count = maxi(0, GameState.temp_sentry_count - 1)
			queue_free()
			return
	if not _player or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player")
		return
	_bob_time    += delta
	_orbit_angle += ORBIT_SPEED * delta
	global_position = _player.global_position + Vector2(
		cos(_orbit_angle) * ORBIT_RADIUS,
		sin(_orbit_angle) * ORBIT_RADIUS + sin(_bob_time * 3.0) * 4.0
	)
	_fire_timer -= delta
	if _fire_timer <= 0.0:
		_fire_timer = 1.0 / GameState.fire_rate
		_try_fire()

func _try_fire() -> void:
	var enemies := get_tree().get_nodes_in_group("enemies")
	if enemies.is_empty():
		return
	var nearest: Node2D = null
	var nearest_dist := INF
	for e: Node2D in enemies:
		var d := global_position.distance_to(e.global_position)
		if d < nearest_dist:
			nearest_dist = d
			nearest = e
	if not nearest:
		return
	if not _proj_container or not is_instance_valid(_proj_container):
		_proj_container = get_tree().get_first_node_in_group("projectiles_container")
	if not _proj_container:
		return
	var to_nearest := nearest.global_position - global_position
	var dir := to_nearest.normalized() if to_nearest.length_squared() > 0.0001 else Vector2.RIGHT
	_sprite.flip_h = dir.x < 0.0
	var count := GameState.projectile_count
	for i in count:
		var angle_offset := 0.0
		if count > 1:
			angle_offset = lerp(-0.1, 0.1, float(i) / float(count - 1))
		var proj: Area2D = PROJECTILE_SCENE.instantiate()
		_proj_container.add_child(proj)
		proj.global_position = global_position
		var dmg := int(GameState.projectile_damage * GameState.damage_mul * GameState.sentry_damage_mul)
		proj.launch(dir.rotated(angle_offset), dmg, GameState.projectile_speed, GameState.projectile_pierce, "death")
