extends CharacterBody2D

const XP_ORB_SCENE = preload("res://scenes/XPOrb.tscn")
const WEB_SCRIPT   = preload("res://scripts/WebProjectile.gd")

@export var move_speed:       float = 95.0
@export var max_health:       int   = 10
@export var health:           int   = 10
@export var xp_value:         int   = 8
@export var damage:           int   = 6
@export var contact_cooldown: float = 0.8

var _player:        Node2D  = null
var _contact_timer: float   = 0.0
var _dead:          bool    = false
var _xp_container:  Node    = null
var _knockback_vel: Vector2 = Vector2.ZERO
var _last_dir:      Vector2 = Vector2.DOWN
var _web_timer:     float   = 0.0
var _facing:        String  = "S"
var _charmed:       bool    = false
var _charm_timer:   float   = 0.0

const ANIM_PATH := "res://assets/enemies/spider"
const ANIM_SCALE := Vector2(0.8, 0.8)  # 128px HD frames, ~60px tall content -> ~48 world px
# anim -> [fps, loops]. hurt: 15 frames @ 60fps = 0.25s (matches take_hit's
# await). die: 15 frames @ 34fps = 0.44s (matches _die()'s 0.45s await).
const CORPSE_LINGER_BASE := 2.5  # seconds body stays after die anim
const ANIMS: Dictionary = {
	"idle": [10.0, true],
	"run":  [16.0, true],
	"die":  [34.0, false],
	"hurt": [60.0, false],
}

@onready var sprite:      Sprite2D         = $Sprite2D
@onready var anim_sprite: AnimatedSprite2D = $AnimSprite

func _ready() -> void:
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING  # top-down: no floor/platform tracking (see Enemy.gd)
	add_to_group("enemies")
	health = max_health
	_player = get_tree().get_first_node_in_group("player")
	sprite.hide()
	anim_sprite.show()
	# HD frames want smooth sampling; project default is nearest (pixel art)
	anim_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	anim_sprite.sprite_frames = WizardFrames.build(ANIM_PATH, ANIMS)
	anim_sprite.scale = ANIM_SCALE
	anim_sprite.play("idle_S")
	_web_timer = randf_range(2.5, 5.0)


func _physics_process(delta: float) -> void:
	if _dead:
		return
	if not _player or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player")
		return

	# Charmed enemies fight for the player
	if CharmedAI.process_charmed(self, delta):
		return

	_contact_timer = maxf(0.0, _contact_timer - delta)
	_web_timer    -= delta

	if _knockback_vel.length_squared() > 4.0:
		_knockback_vel = _knockback_vel.lerp(Vector2.ZERO, delta * 10.0)
		velocity = _knockback_vel
	else:
		_knockback_vel = Vector2.ZERO
		var to_player := _player.global_position - global_position
		var dir := to_player.normalized() if to_player.length_squared() > 0.0001 else _last_dir
		velocity = dir * move_speed
	move_and_slide()

	# Charmed enemies don't hurt the player
	if not _charmed:
		if global_position.distance_to(_player.global_position) < 20.0 and _contact_timer <= 0.0:
			_contact_timer = contact_cooldown
			if _player.has_method("take_damage"):
				_player.take_damage(damage)

	if _web_timer <= 0.0:
		_web_timer = randf_range(3.0, 6.0)
		_shoot_web()

	var moving := velocity.length() > 5.0
	if moving:
		_last_dir = velocity.normalized()
		_facing = _dir_to_compass(_last_dir)

	# Don't stomp an in-progress hurt/die animation — take_hit()/_die() own
	# those and hand control back explicitly when they finish.
	var cur_state := String(anim_sprite.animation).get_slice("_", 0)
	if cur_state not in ["hurt", "die"]:
		_play_anim("run" if moving else "idle")

func _shoot_web() -> void:
	if not _player or not is_instance_valid(_player):
		return
	var proj_container := get_tree().get_first_node_in_group("projectiles_container")
	if not proj_container:
		return
	var web := Node2D.new()
	web.set_script(WEB_SCRIPT)
	proj_container.add_child(web)
	web.global_position = global_position
	var to_player_web := _player.global_position - global_position
	web.launch(to_player_web.normalized() if to_player_web.length_squared() > 0.0001 else _last_dir)

func _draw() -> void:
	if _dead:
		return
	# Charm visual: pulsing green ring
	if _charmed:
		var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.008)
		draw_arc(Vector2.ZERO, 20.0 + pulse * 4.0, 0.0, TAU, 32, Color(0.3, 1.0, 0.3, 0.4 + pulse * 0.3), 2.0)
		return

	var hp_ratio := float(health) / float(max_health) if max_health > 0 else 0.0
	if hp_ratio >= 1.0:
		return
	draw_rect(Rect2(-14, -26, 28, 4), Color(0.12, 0.0, 0.0))
	draw_rect(Rect2(-14, -26, 28.0 * hp_ratio, 4), Color(0.75, 0.05, 0.05))

func apply_knockback(dir: Vector2, force: float) -> void:
	if _dead:
		return
	_knockback_vel = dir * force

func apply_charm(duration: float) -> void:
	if _dead or _charmed:
		return
	_charmed = true
	_charm_timer = duration
	# Visual feedback for charm
	anim_sprite.modulate = Color(0.3, 1.0, 0.3)  # Green tint

# Map a direction vector to one of the 8 compass animation suffixes.
# Screen coords: +y is down, so angle 0 = E and the octants walk E→SE→S→…
func _dir_to_compass(v: Vector2) -> String:
	if v.length_squared() < 0.0001:
		return _facing
	var octant := wrapi(roundi(v.angle() / (TAU / 8.0)), 0, 8)
	return ["E", "SE", "S", "SW", "W", "NW", "N", "NE"][octant]

# Play "<state>_<facing>" if not already playing it (play() restarts otherwise).
func _play_anim(state: String) -> void:
	var anim_name := "%s_%s" % [state, _facing]
	if anim_sprite.animation != anim_name:
		anim_sprite.play(anim_name)

func take_hit(dmg: int) -> void:
	if _dead:
		return
	health -= dmg
	queue_redraw()
	if health <= 0:
		_die()
		return
	_play_anim("hurt")
	await get_tree().create_timer(0.25).timeout
	if not _dead:
		_play_anim("run" if velocity.length() > 5.0 else "idle")

func fire_kill() -> void:
	if _dead:
		return
	_dead = true
	set_physics_process(false)
	$CollisionShape2D.set_deferred("disabled", true)
	remove_from_group("enemies")
	GameState.add_kill_score(xp_value)
	_spawn_blood()
	queue_free()

func _die() -> void:
	_dead = true
	queue_redraw()
	set_physics_process(false)
	$CollisionShape2D.set_deferred("disabled", true)
	remove_from_group("enemies")
	GameState.add_kill_score(xp_value)
	GameState.kill_hitstop(false)
	_play_anim("die")
	_spawn_blood()
	_drop_xp()
	await get_tree().create_timer(0.45).timeout
	# Corpse linger: scales down as enemy density rises
	var linger := GameState.get_corpse_linger(CORPSE_LINGER_BASE)
	await get_tree().create_timer(linger).timeout
	queue_free()

func _spawn_blood() -> void:
	var smears := get_tree().get_first_node_in_group("blood_smears")
	if smears:
		smears.add_smear(global_position, _last_dir, 1.0)

func _drop_xp() -> void:
	if not _xp_container or not is_instance_valid(_xp_container):
		_xp_container = get_tree().get_first_node_in_group("xp_orbs_container")
	if not _xp_container:
		return
	var orb = XP_ORB_SCENE.instantiate()
	_xp_container.add_child(orb)
	orb.global_position = global_position + Vector2(randf_range(-12, 12), randf_range(-12, 12))
	orb.xp_value = xp_value
