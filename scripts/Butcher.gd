extends CharacterBody2D

# The Butcher — second boss, alternates with the Skull King on the 60 s boss
# timer (docs/BALANCE.md §4). Distinct pattern: circles the player at
# mid-range, then telegraphs and charges across the arena. Forces sustained
# repositioning where the Skull King only asks for kiting. Trades 20% HP for
# the charge threat (BUTCHER_HP_MUL in Main.gd).

const XP_ORB_SCENE = preload("res://scenes/XPOrb.tscn")
const BOMB_SCENE   = preload("res://scenes/BombPickup.tscn")

@export var move_speed: float = 70.0
@export var max_health: int   = 1000
@export var health:     int   = 1000
@export var damage:     int   = 30
@export var xp_value:   int   = 500
@export var contact_cooldown: float = 0.8

const ORBIT_RADIUS      := 220.0
const CHARGE_SPEED      := 420.0
const CHARGE_TRAVEL     := 700.0
const WINDUP_DURATION   := 1.0
const ORBIT_DURATION_MIN := 4.0
const ORBIT_DURATION_MAX := 6.0
const BUTCHER_TINT      := Color(1.0, 0.35, 0.35)

# ~90 world px content height — bigger than the Skull King boss's ~80, matching
# the original cyclops.png-at-scale-6 Butcher's relative size lead.
const ANIM_SCALE := Vector2(0.83, 0.83)  # 192px HD frames, ~108px tall (Idle) content
const ANIM_PATH  := "res://assets/enemies/butcher"
# anim -> [fps, loops]. hurt: 15 frames @ 60fps = 0.25s (matches take_hit's
# hold). die: 15 frames @ 30fps = 0.5s (matches _die()'s 0.5s await). windup:
# 15 frames @ 15fps = 1.0s (matches WINDUP_DURATION). charge loops continuously
# for the (variable-length) charge dash.
const CORPSE_LINGER_BASE := 5.0  # seconds body stays after die anim
const ANIMS: Dictionary = {
	"idle":   [10.0, true],
	"run":    [16.0, true],
	"windup": [15.0, false],
	"charge": [20.0, true],
	"die":    [30.0, false],
	"hurt":   [60.0, false],
}

enum State { ORBIT, WINDUP, CHARGE }

var _player:        Node2D  = null
var _contact_timer: float   = 0.0
var _dead:          bool    = false
var _xp_container:  Node    = null
var _state:         State   = State.ORBIT
var _state_timer:   float   = 0.0
var _orbit_sign:    float   = 1.0
var _charge_dir:    Vector2 = Vector2.ZERO
var _charge_left:   float   = 0.0
var _anim_time:     float   = 0.0
var _last_dir:      Vector2 = Vector2.DOWN
var _facing:        String  = "S"
var _charmed:       bool    = false
var _charm_timer:   float   = 0.0

@onready var sprite:      Sprite2D         = $Sprite2D
@onready var anim_sprite: AnimatedSprite2D = $AnimSprite

func _ready() -> void:
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING  # top-down: no floor/platform tracking (see Enemy.gd)
	add_to_group("enemies")
	add_to_group("bosses")
	health = max_health
	_player = get_tree().get_first_node_in_group("player")
	sprite.hide()
	anim_sprite.show()
	# HD frames want smooth sampling; project default is nearest (pixel art)
	anim_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	anim_sprite.sprite_frames = WizardFrames.build(ANIM_PATH, ANIMS)
	anim_sprite.scale    = ANIM_SCALE
	anim_sprite.modulate = BUTCHER_TINT
	anim_sprite.play("idle_S")
	_state_timer = randf_range(ORBIT_DURATION_MIN, ORBIT_DURATION_MAX)
	_orbit_sign  = 1.0 if randf() < 0.5 else -1.0

func _physics_process(delta: float) -> void:
	_anim_time += delta
	queue_redraw()
	if _dead:
		return
	# Charmed enemies fight for the player
	if CharmedAI.process_charmed(self, delta):
		return
	if not _player or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player")
		return

	_contact_timer = maxf(0.0, _contact_timer - delta)
	_state_timer  -= delta

	match _state:
		State.ORBIT:
			var to_player := _player.global_position - global_position
			var dist := to_player.length()
			var dir  := to_player.normalized() if dist > 0.01 else _last_dir
			var perp := Vector2(-dir.y, dir.x) * _orbit_sign
			# Spiral toward/away from the orbit ring while circling
			var radial := dir * clampf((dist - ORBIT_RADIUS) * 0.02, -1.0, 1.0)
			velocity = (perp + radial).normalized() * move_speed
			anim_sprite.modulate = BUTCHER_TINT
			if _state_timer <= 0.0:
				_state = State.WINDUP
				_state_timer = WINDUP_DURATION
		State.WINDUP:
			velocity = Vector2.ZERO
			# Face the player through the windup — velocity is zero here so the
			# normal moving-based facing update below never fires.
			var to_player_face := _player.global_position - global_position
			if to_player_face.length_squared() > 0.0001:
				_facing = _dir_to_compass(to_player_face.normalized())
			var flash := 0.5 + 0.5 * sin(_anim_time * 25.0)
			anim_sprite.modulate = BUTCHER_TINT.lerp(Color(3.0, 0.5, 0.5), flash)
			if _state_timer <= 0.0:
				_state = State.CHARGE
				var to_player_charge := _player.global_position - global_position
				_charge_dir  = to_player_charge.normalized() if to_player_charge.length_squared() > 0.0001 else _last_dir
				_charge_left = CHARGE_TRAVEL
				anim_sprite.modulate = BUTCHER_TINT
		State.CHARGE:
			velocity = _charge_dir * CHARGE_SPEED
			_charge_left -= CHARGE_SPEED * delta
			if _charge_left <= 0.0 or _hit_wall():
				_state = State.ORBIT
				_state_timer = randf_range(ORBIT_DURATION_MIN, ORBIT_DURATION_MAX)
				_orbit_sign = -_orbit_sign
	move_and_slide()
	global_position.x = clampf(global_position.x, 30.0, GameState.WORLD_SIZE.x - 30.0)
	global_position.y = clampf(global_position.y, 30.0, GameState.WORLD_SIZE.y - 30.0)

	if velocity.length() > 5.0:
		_last_dir = velocity.normalized()
		_facing = _dir_to_compass(_last_dir)

	# Don't stomp an in-progress hurt/die animation — take_hit()/_die() own
	# those and hand control back explicitly when they finish.
	var cur_state := String(anim_sprite.animation).get_slice("_", 0)
	if cur_state not in ["hurt", "die"]:
		match _state:
			State.ORBIT:
				_play_anim("run" if velocity.length() > 5.0 else "idle")
			State.WINDUP:
				_play_anim("windup")
			State.CHARGE:
				_play_anim("charge")

	# Charmed enemies don't hurt the player
	if not _charmed:
		var hit_range := 45.0 if _state == State.CHARGE else 38.0
		if global_position.distance_to(_player.global_position) < hit_range and _contact_timer <= 0.0:
			_contact_timer = contact_cooldown
			if _player.has_method("take_damage"):
				_player.take_damage(damage)

func _hit_wall() -> bool:
	return (global_position.x <= 31.0 or global_position.x >= GameState.WORLD_SIZE.x - 31.0
		or global_position.y <= 31.0 or global_position.y >= GameState.WORLD_SIZE.y - 31.0)

func _draw() -> void:
	if _dead:
		return
	# Charm visual: pulsing green ring
	if _charmed:
		var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.008)
		draw_arc(Vector2.ZERO, 45.0 + pulse * 4.0, 0.0, TAU, 32, Color(0.3, 1.0, 0.3, 0.4 + pulse * 0.3), 2.0)
		return

	# Charge telegraph line during windup
	if _state == State.WINDUP and _player and is_instance_valid(_player):
		var local_player := to_local(_player.global_position)
		var dir := local_player.normalized() if local_player.length_squared() > 0.0001 else _last_dir
		var flash := 0.25 + 0.35 * (0.5 + 0.5 * sin(_anim_time * 25.0))
		draw_line(dir * 40.0, dir * CHARGE_TRAVEL, Color(1.0, 0.1, 0.1, flash), 4.0)
	var hp_ratio := float(health) / float(max_health) if max_health > 0 else 0.0
	draw_rect(Rect2(-32, -66, 64, 7), Color(0.12, 0.0, 0.0))
	draw_rect(Rect2(-32, -66, 64.0 * hp_ratio, 7), Color(0.9, 0.1, 0.1))
	var font := ThemeDB.fallback_font
	draw_string(font, Vector2(-24, -71), "BUTCHER", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(1.0, 0.3, 0.3))

func apply_knockback(_dir: Vector2, force: float) -> void:
	if _dead or _state == State.CHARGE:
		return
	# Bosses barely budge
	global_position += _dir * force * 0.02

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
		match _state:
			State.ORBIT:
				_play_anim("run" if velocity.length() > 5.0 else "idle")
			State.WINDUP:
				_play_anim("windup")
			State.CHARGE:
				_play_anim("charge")

func fire_kill() -> void:
	# Fire bombs chunk bosses for 25% max HP instead of instakilling them
	if _dead:
		return
	take_hit(int(max_health * 0.25))

func _die() -> void:
	_dead = true
	set_physics_process(false)
	$CollisionShape2D.set_deferred("disabled", true)
	remove_from_group("enemies")
	GameState.add_kill_score(xp_value, true)
	GameState.kill_hitstop(true)
	GameState.screen_shake(70.0, 0.35)
	_play_anim("die")
	_spawn_blood()
	_drop_xp()
	_spawn_bomb()
	_vacuum_xp_orbs()
	await get_tree().create_timer(0.5).timeout
	# Corpse linger: boss bodies stay longer; scales down as enemy density rises
	var linger := GameState.get_corpse_linger(CORPSE_LINGER_BASE)
	await get_tree().create_timer(linger).timeout
	queue_free()

func _spawn_blood() -> void:
	var smears := get_tree().get_first_node_in_group("blood_smears")
	if smears:
		smears.add_smear(global_position, _last_dir, 2.5)

func _drop_xp() -> void:
	if not _xp_container or not is_instance_valid(_xp_container):
		_xp_container = get_tree().get_first_node_in_group("xp_orbs_container")
	if not _xp_container:
		return
	# Boss XP ≈ 90% of a level at current progression (docs/BALANCE.md §4)
	var orb_xp := int(GameState.xp_to_next_level * 0.3)
	for _i in 3:
		var orb = XP_ORB_SCENE.instantiate()
		_xp_container.add_child(orb)
		orb.global_position = global_position + Vector2(randf_range(-50, 50), randf_range(-50, 50))
		orb.xp_value = orb_xp

func _vacuum_xp_orbs() -> void:
	var container := get_tree().get_first_node_in_group("xp_orbs_container")
	if not container:
		return
	for orb in container.get_children():
		orb._attracted = true
		orb._attract_speed = 80.0

func _spawn_bomb() -> void:
	var bomb = BOMB_SCENE.instantiate()
	get_tree().current_scene.add_child(bomb)
	bomb.global_position = global_position
