extends CharacterBody2D

const XP_ORB_SCENE  = preload("res://scenes/XPOrb.tscn")
const BOMB_SCENE    = preload("res://scenes/BombPickup.tscn")

@export var move_speed:       float = 60.0
@export var max_health:       int   = 25
@export var health:           int   = 25
@export var xp_value:         int   = 20
@export var damage:           int   = 10
@export var contact_cooldown: float = 0.8
@export var is_boss:          bool  = false
@export var is_cyclops:       bool  = false  # set true before add_child(), mirrors is_boss

var _player:         Node2D  = null
var _contact_timer:  float   = 0.0
var _dead:           bool    = false
var _xp_container:   Node    = null
var _knockback_vel:  Vector2 = Vector2.ZERO
var _last_dir:       Vector2 = Vector2.DOWN
var _facing:         String  = "S"
var _attack_anim_timer: float = 0.0  # boss only; see ATTACK_ANIM_DURATION
var _charmed:        bool    = false
var _charm_timer:    float   = 0.0

@onready var sprite:      Sprite2D         = $Sprite2D
@onready var anim_sprite: AnimatedSprite2D = $AnimSprite

const ANIM_SCALE := Vector2(0.7, 0.7)  # brawler: 192px HD frames, ~72px tall content
const ANIM_PATH  := "res://assets/enemies/brawler"
# anim -> [fps, loops]. hurt: 15 frames @ 60fps = 0.25s (matches take_hit's
# await). die: 15 frames @ 34fps = 0.44s (fits _die()'s 0.45s await).
const CORPSE_LINGER_BASE := 2.5  # seconds body stays after die anim
const ANIMS: Dictionary = {
	"idle": [10.0, true],
	"run":  [16.0, true],
	"die":  [34.0, false],
	"hurt": [60.0, false],
}

const CYCLOPS_ANIM_SCALE := Vector2(0.64, 0.64)  # 192px HD frames, ~78px tall content
const CYCLOPS_ANIM_PATH  := "res://assets/enemies/cyclops"
# Same timing constraints as ANIMS (take_hit's 0.25s / _die()'s 0.45s awaits
# are shared across every non-boss variant).
const CYCLOPS_ANIMS: Dictionary = {
	"idle": [10.0, true],
	"run":  [16.0, true],
	"die":  [34.0, false],
	"hurt": [60.0, false],
}

# ~80 world px content height vs the player's ~43 and a regular enemy's ~50 —
# reads clearly as a boss silhouette even before the health bar/BOSS label draw.
const BOSS_ANIM_SCALE := Vector2(1.1, 1.1)  # 192px HD frames, ~73px tall content
const BOSS_ANIM_PATH  := "res://assets/enemies/boss"
const ATTACK_ANIM_DURATION := 0.5  # 15 frames @ 30fps; fits inside the 0.8s contact_cooldown gap
const BOSS_ANIMS: Dictionary = {
	"idle":   [10.0, true],
	"run":    [16.0, true],
	"die":    [34.0, false],
	"hurt":   [60.0, false],
	"attack": [30.0, false],
}

# ---------------------------------------------------------------------------
func _ready() -> void:
	# Top-down game: floating mode disables grounded-mode floor/platform
	# tracking, which treats other enemies as "floors" and reads stale state
	# when they are freed mid-contact (NaN warning spam + wasted solve time).
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	add_to_group("enemies")
	sprite.hide()
	anim_sprite.show()
	# HD frames want smooth sampling; project default is nearest (pixel art)
	anim_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	if is_boss:
		add_to_group("bosses")
		var boss_shape := CircleShape2D.new()
		boss_shape.radius = 32.0
		$CollisionShape2D.shape = boss_shape
		anim_sprite.sprite_frames = WizardFrames.build(BOSS_ANIM_PATH, BOSS_ANIMS)
		anim_sprite.scale = BOSS_ANIM_SCALE
	elif is_cyclops:
		anim_sprite.sprite_frames = WizardFrames.build(CYCLOPS_ANIM_PATH, CYCLOPS_ANIMS)
		anim_sprite.scale = CYCLOPS_ANIM_SCALE
	else:
		anim_sprite.sprite_frames = WizardFrames.build(ANIM_PATH, ANIMS)
		anim_sprite.scale = ANIM_SCALE
	anim_sprite.play("idle_S")
	health = max_health
	_player = get_tree().get_first_node_in_group("player")

# ---------------------------------------------------------------------------
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
		if global_position.distance_to(_player.global_position) < 25.0 and _contact_timer <= 0.0:
			_contact_timer = contact_cooldown
			if _player.has_method("take_damage"):
				_player.take_damage(damage)
				if is_boss:
					_attack_anim_timer = ATTACK_ANIM_DURATION

	var moving := velocity.length() > 5.0
	if moving:
		_last_dir = velocity.normalized()
		_facing = _dir_to_compass(_last_dir)

	# Don't stomp an in-progress hurt/die animation — take_hit()/_die() own
	# those and hand control back explicitly when they finish.
	var cur_state := String(anim_sprite.animation).get_slice("_", 0)
	if cur_state in ["hurt", "die"]:
		pass
	elif _attack_anim_timer > 0.0:
		_attack_anim_timer = maxf(0.0, _attack_anim_timer - delta)
		_play_anim("attack")
	else:
		_play_anim("run" if moving else "idle")

# ---------------------------------------------------------------------------
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
	if is_boss:
		# Offsets raised vs the old boss1.png sprite to clear the taller Ogre frames.
		draw_rect(Rect2(-32, -75, 64, 7), Color(0.12, 0.0, 0.0))
		draw_rect(Rect2(-32, -75, 64.0 * hp_ratio, 7), Color(1.0, 0.35, 0.0))
		var font := ThemeDB.fallback_font
		draw_string(font, Vector2(-14, -80), "BOSS", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(1.0, 0.5, 0.0))
	else:
		draw_rect(Rect2(-14, -26, 28, 4), Color(0.12, 0.0, 0.0))
		draw_rect(Rect2(-14, -26, 28.0 * hp_ratio, 4), Color(0.75, 0.05, 0.05))

# ---------------------------------------------------------------------------
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
		_play_anim("run" if velocity.length() > 5.0 else "idle")

# Resting modulate the on-hit flash fades back to: charm green if charmed, else
# this variant's untinted default.
func _flash_base() -> Color:
	return Color(0.3, 1.0, 0.3) if _charmed else Color.WHITE

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

func fire_kill() -> void:
	if _dead:
		return
	# Fire bombs chunk bosses for 25% max HP instead of instakilling them —
	# otherwise the bomb a boss drops trivialises the next boss.
	if is_boss:
		take_hit(int(max_health * 0.25))
		return
	_dead = true
	set_physics_process(false)
	$CollisionShape2D.set_deferred("disabled", true)
	remove_from_group("enemies")
	GameState.add_kill_score(xp_value, is_boss)
	_spawn_blood()
	queue_free()

func _die() -> void:
	_dead = true
	queue_redraw()
	set_physics_process(false)
	$CollisionShape2D.set_deferred("disabled", true)
	remove_from_group("enemies")
	GameState.add_kill_score(xp_value, is_boss)
	GameState.kill_hitstop(is_boss)
	_play_anim("die")
	_spawn_blood()
	_drop_xp()
	Pickup.maybe_drop(global_position, is_boss)
	if is_boss:
		GameState.screen_shake(70.0, 0.35)
		GameState.rumble(0.6, 0.9, 0.4)
		_spawn_bomb()
		_vacuum_xp_orbs()
	await get_tree().create_timer(0.45).timeout
	# Corpse linger: longer for bosses, shorter as enemy density rises
	var linger := GameState.get_corpse_linger(5.0 if is_boss else CORPSE_LINGER_BASE)
	await get_tree().create_timer(linger).timeout
	queue_free()

# ---------------------------------------------------------------------------
func _spawn_blood() -> void:
	var smears := get_tree().get_first_node_in_group("blood_smears")
	if smears:
		smears.add_smear(global_position, _last_dir, 2.5 if is_boss else 1.0)

const MAX_XP_ORBS := 75

func _drop_xp() -> void:
	if not _xp_container or not is_instance_valid(_xp_container):
		_xp_container = get_tree().get_first_node_in_group("xp_orbs_container")
	if not _xp_container:
		return
	if is_boss:
		# Boss XP ≈ 90% of a level at current progression (docs/BALANCE.md §4)
		var orb_xp := int(GameState.xp_to_next_level * 0.3)
		for _i in 3:
			var orb = XP_ORB_SCENE.instantiate()
			_xp_container.add_child(orb)
			orb.global_position = global_position + Vector2(randf_range(-50, 50), randf_range(-50, 50))
			orb.xp_value = orb_xp
	else:
		var orb = XP_ORB_SCENE.instantiate()
		_xp_container.add_child(orb)
		orb.global_position = global_position + Vector2(randf_range(-18, 18), randf_range(-18, 18))
		orb.xp_value = xp_value
	# Enforce cap — merge smallest orb into its nearest neighbour
	var orbs := _xp_container.get_children()
	if orbs.size() > MAX_XP_ORBS:
		_merge_smallest(orbs)

func _merge_smallest(orbs: Array) -> void:
	var target: Node2D = null
	var min_val := 999999
	for orb in orbs:
		if orb.xp_value < min_val:
			min_val = orb.xp_value
			target = orb
	if not target:
		return
	var nearest: Node2D = null
	var nearest_dist := INF
	for orb in orbs:
		if orb == target:
			continue
		var d := target.global_position.distance_to((orb as Node2D).global_position)
		if d < nearest_dist:
			nearest_dist = d
			nearest = orb
	if nearest:
		nearest.xp_value += target.xp_value
		nearest.queue_redraw()
	target.queue_free()

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
