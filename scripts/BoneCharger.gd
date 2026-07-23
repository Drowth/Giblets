extends CharacterBody2D

# Bone Charger — movement-forcing enemy (docs/BALANCE.md §3). Shambles toward
# the player, periodically wind-ups (flash, freeze) then charges in a locked
# direction. On death its ribcage detonates after a short fuse, punishing
# players who stand on the corpse. Animated 8-dir sprite via
# `WizardFrames.build`; the post-death burst-radius telegraph stays procedural.

const XP_ORB_SCENE = preload("res://scenes/XPOrb.tscn")
@export var move_speed:       float = 40.0
@export var max_health:       int   = 35
@export var health:           int   = 35
@export var xp_value:         int   = 30
@export var damage:           int   = 18
@export var contact_cooldown: float = 0.8

const CHARGE_MULT      := 4.5
const CHARGE_DURATION  := 0.6
const WINDUP_DURATION  := 0.7
const CHARGE_INTERVAL_MIN := 3.0
const CHARGE_INTERVAL_MAX := 5.0
const BURST_RADIUS     := 60.0   # death explosion
const BURST_FUSE_BASE  := 2.0    # base corpse fuse time before burst

const WINDUP_FLASH_COLOR := Color(3.0, 0.3, 0.3)

const ANIM_SCALE := Vector2(0.8, 0.8)  # 128px HD frames, ~59px tall content -> ~48 world px
const ANIM_PATH  := "res://assets/enemies/bonecharger"
# anim -> [fps, loops]. hurt: 18 frames @ 72fps = 0.25s (matches take_hit's
# hold). die: 15 frames @ 30fps = 0.5s (matches the BURST_FUSE window). windup
# holds its pose for ~WINDUP_DURATION; charge loops for CHARGE_DURATION.
const ANIMS: Dictionary = {
	"idle":   [10.0, true],
	"run":    [16.0, true],
	"windup": [20.0, false],
	"charge": [20.0, true],
	"die":    [30.0, false],
	"hurt":   [72.0, false],
}

enum State { WALK, WINDUP, CHARGE }

var _player:        Node2D  = null
var _contact_timer: float   = 0.0
var _dead:          bool    = false
var _xp_container:  Node    = null
var _knockback_vel: Vector2 = Vector2.ZERO
var _last_dir:      Vector2 = Vector2.DOWN
var _state:         State   = State.WALK
var _state_timer:   float   = 0.0
var _charge_dir:    Vector2 = Vector2.ZERO
var _anim_time:     float   = 0.0
var _fuse:          float   = -1.0
var _facing:        String  = "S"
var _charmed:       bool    = false
var _charm_timer:   float   = 0.0

@onready var anim_sprite: AnimatedSprite2D = $AnimSprite

func _ready() -> void:
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING  # top-down: no floor/platform tracking (see Enemy.gd)
	add_to_group("enemies")
	health = max_health
	_player = get_tree().get_first_node_in_group("player")
	anim_sprite.show()
	# HD frames want smooth sampling; project default is nearest (pixel art)
	anim_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	anim_sprite.sprite_frames = WizardFrames.build(ANIM_PATH, ANIMS)
	anim_sprite.scale = ANIM_SCALE
	anim_sprite.play("idle_S")
	_state_timer = randf_range(CHARGE_INTERVAL_MIN, CHARGE_INTERVAL_MAX)

func _physics_process(delta: float) -> void:
	_anim_time += delta
	queue_redraw()

	if _dead:
		if _fuse >= 0.0:
			_fuse -= delta
			if _fuse <= 0.0:
				_burst()
		return
	# Charmed enemies fight for the player
	if CharmedAI.process_charmed(self, delta):
		return

	if not _player or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player")
		return

	_contact_timer = maxf(0.0, _contact_timer - delta)
	_state_timer  -= delta

	if _knockback_vel.length_squared() > 4.0:
		_knockback_vel = _knockback_vel.lerp(Vector2.ZERO, delta * 8.0)
		velocity = _knockback_vel
		move_and_slide()
		return

	match _state:
		State.WALK:
			var to_player_walk := _player.global_position - global_position
			var walk_dir := to_player_walk.normalized() if to_player_walk.length_squared() > 0.0001 else _last_dir
			velocity = walk_dir * move_speed
			# Guarded so an on-hit flash pop isn't stomped by this per-frame reset.
			if not HitFlash.is_flashing(anim_sprite):
				anim_sprite.modulate = Color.WHITE
			if _state_timer <= 0.0:
				_state = State.WINDUP
				_state_timer = WINDUP_DURATION
				velocity = Vector2.ZERO
		State.WINDUP:
			velocity = Vector2.ZERO
			# Face the player through the windup — velocity is zero here so the
			# normal moving-based facing update below never fires. Direction
			# still locks at the END of windup — dodge during the flash.
			var to_player_face := _player.global_position - global_position
			if to_player_face.length_squared() > 0.0001:
				_facing = _dir_to_compass(to_player_face.normalized())
			var flash := 0.6 if Settings.reduce_flash else 0.5 + 0.5 * sin(_anim_time * 30.0)
			anim_sprite.modulate = Color.WHITE.lerp(WINDUP_FLASH_COLOR, flash * 0.7)
			if _state_timer <= 0.0:
				_state = State.CHARGE
				_state_timer = CHARGE_DURATION
				var to_player_charge := _player.global_position - global_position
				_charge_dir = to_player_charge.normalized() if to_player_charge.length_squared() > 0.0001 else _last_dir
				anim_sprite.modulate = Color.WHITE
		State.CHARGE:
			velocity = _charge_dir * move_speed * CHARGE_MULT
			if _state_timer <= 0.0:
				_state = State.WALK
				_state_timer = randf_range(CHARGE_INTERVAL_MIN, CHARGE_INTERVAL_MAX)
	move_and_slide()

	if velocity.length() > 5.0:
		_last_dir = velocity.normalized()
		_facing = _dir_to_compass(_last_dir)

	# Don't stomp an in-progress hurt/die animation — take_hit()/_die() own
	# those and hand control back explicitly when they finish.
	var cur_state := String(anim_sprite.animation).get_slice("_", 0)
	if cur_state not in ["hurt", "die"]:
		match _state:
			State.WALK:
				_play_anim("run" if velocity.length() > 5.0 else "idle")
			State.WINDUP:
				_play_anim("windup")
			State.CHARGE:
				_play_anim("charge")

	# Charmed enemies don't hurt the player
	if not _charmed:
		var hit_range := 26.0 if _state == State.CHARGE else 22.0
		if global_position.distance_to(_player.global_position) < hit_range and _contact_timer <= 0.0:
			_contact_timer = contact_cooldown
			if _player.has_method("take_damage"):
				_player.take_damage(damage)

func _draw() -> void:
	if _dead:
		# Fuse: pulsing warning ring over the collapsed corpse (die anim holds
		# its last frame underneath) about to burst
		if _fuse >= 0.0:
			var pulse := 0.5 + 0.5 * sin(_anim_time * 40.0)
			draw_circle(Vector2.ZERO, 12.0 + pulse * 4.0, Color(1.0, 0.5, 0.1, 0.5 + pulse * 0.4))
			draw_arc(Vector2.ZERO, BURST_RADIUS, 0.0, TAU, 32, Color(1.0, 0.3, 0.0, 0.35 + pulse * 0.3), 2.0)
		return

	# Charm visual: pulsing green ring
	if _charmed:
		var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.008)
		draw_arc(Vector2.ZERO, 20.0 + pulse * 4.0, 0.0, TAU, 32, Color(0.3, 1.0, 0.3, 0.4 + pulse * 0.3), 2.0)
		return

	# Health bar
	var hp_ratio := float(health) / float(max_health) if max_health > 0 else 0.0
	if hp_ratio < 1.0:
		draw_rect(Rect2(-14, -28, 28, 4), Color(0.12, 0.0, 0.0))
		draw_rect(Rect2(-14, -28, 28.0 * hp_ratio, 4), Color(0.9, 0.85, 0.6))

func apply_knockback(dir: Vector2, force: float) -> void:
	if _dead or _state == State.CHARGE:
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
	HitFlash.flash(anim_sprite, _flash_base())
	if health <= 0:
		_die()
		return
	_play_anim("hurt")
	await get_tree().create_timer(0.25).timeout
	if not _dead:
		match _state:
			State.WALK:
				_play_anim("run" if velocity.length() > 5.0 else "idle")
			State.WINDUP:
				_play_anim("windup")
			State.CHARGE:
				_play_anim("charge")

# Resting modulate the on-hit flash fades back to (charm green if charmed). The
# WINDUP telegraph writes its own flash unconditionally, so a pop there is fine.
func _flash_base() -> Color:
	return Color(0.3, 1.0, 0.3) if _charmed else Color.WHITE

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
	remove_from_group("enemies")
	$CollisionShape2D.set_deferred("disabled", true)
	GameState.add_kill_score(xp_value)
	GameState.kill_hitstop(false)
	_play_anim("die")
	_spawn_blood()
	_drop_xp()
	Pickup.maybe_drop(global_position, false)
	# Arm the death burst — _physics_process keeps running for the fuse.
	# Fuse scales down with enemy density so late-game corpses don't pile up.
	_fuse = GameState.get_corpse_linger(BURST_FUSE_BASE)
	queue_redraw()

func _burst() -> void:
	_fuse = -1.0
	set_physics_process(false)
	var player := get_tree().get_first_node_in_group("player")
	if player and global_position.distance_to(player.global_position) < BURST_RADIUS:
		if player.has_method("take_damage"):
			player.take_damage(damage)
	var smears := get_tree().get_first_node_in_group("blood_smears")
	if smears:
		smears.add_smear(global_position, _last_dir, 1.2)
	GameState.screen_shake(12.0, 0.12)
	queue_free()

func _spawn_blood() -> void:
	var smears := get_tree().get_first_node_in_group("blood_smears")
	if smears:
		smears.add_smear(global_position, _last_dir, 1.2)

func _drop_xp() -> void:
	if not _xp_container or not is_instance_valid(_xp_container):
		_xp_container = get_tree().get_first_node_in_group("xp_orbs_container")
	if not _xp_container:
		return
	var orb = XP_ORB_SCENE.instantiate()
	_xp_container.add_child(orb)
	orb.global_position = global_position + Vector2(randf_range(-12, 12), randf_range(-12, 12))
	orb.xp_value = xp_value
