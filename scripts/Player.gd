extends CharacterBody2D

const PROJECTILE_SCENE = preload("res://scenes/Projectile.tscn")

const BLOOD_DROP      = preload("res://scripts/BloodTrailDrop.gd")
const DASH_DUST       = preload("res://scripts/DashDust.gd")

const DASH_SPEED:           float = 1200.0
const DASH_DURATION_BASE:   float = 0.20
const DASH_COOLDOWN_BASE:   float = 3.0
const DASH_KNOCKBACK_BASE:  float = 65.0
const DASH_KNOCKBACK_FORCE: float = 550.0

const PLAYER_SIZE_MUL := 1.1  # 10% larger than each character's base sprite scale

const WOOSH_SOUND := "res://assets/sfx/combat/woosh.wav"
const HURT_SOUND  := "res://assets/sfx/combat/player_hurt.wav"

@onready var attack_timer:  Timer            = $AttackTimer
@onready var iframes_timer: Timer            = $IFramesTimer
@onready var sprite:        Sprite2D         = $Sprite2D
@onready var anim_sprite:   AnimatedSprite2D = $AnimSprite
@onready var anim_player:   AnimationPlayer  = $AnimationPlayer
@onready var camera:        Camera2D         = $Camera2D

# Animated characters (The Wizard) use 8-directional AnimatedSprite2D frames;
# static roster characters keep the Sprite2D + bob-animation path.
var _animated_mode: bool = false
var _facing: String = "S"

var is_invincible:    bool     = false
var _proj_container:  Node2D   = null
var _trail_timer:     float    = 0.0
var _dust_timer:      float    = 0.0
var _slow_factor:     float    = 1.0
var _slow_timer:      float    = 0.0
var _dash_active:     bool     = false
var _dash_timer:      float    = 0.0
var _dash_cooldown:   float    = 0.0
var _dash_dir:        Vector2  = Vector2.RIGHT
var _dash_hit_set:    Array    = []
var _last_move_dir:   Vector2  = Vector2.DOWN
var _shake_strength:  float    = 0.0
var _shake_timer:     float    = 0.0
var _shake_duration:  float    = 1.0

func _ready() -> void:
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING  # top-down: no floor/platform tracking (see Enemy.gd)
	add_to_group("player")
	_apply_character_visuals()
	_add_light()
	attack_timer.wait_time = 1.0 / GameState.fire_rate
	attack_timer.timeout.connect(_fire)
	iframes_timer.timeout.connect(func(): is_invincible = false)
	GameState.game_over.connect(_on_game_over)
	GameState.shake_requested.connect(shake)
	GameState.second_wind_triggered.connect(_on_second_wind)
	camera.limit_right  = int(GameState.WORLD_SIZE.x)
	camera.limit_bottom = int(GameState.WORLD_SIZE.y)
	camera.zoom = Vector2(0.3, 0.3)
	_build_animations()
	if not _animated_mode:
		anim_player.play("idle")

func _add_light() -> void:
	var light := PointLight2D.new()
	light.texture = _make_light_texture(256)
	light.texture_scale = 5.0
	light.color = Color(1.0, 0.92, 0.78)
	light.energy = 1.0
	light.blend_mode = PointLight2D.BLEND_MODE_ADD
	add_child(light)

func _make_light_texture(size: int) -> GradientTexture2D:
	var grad := Gradient.new()
	grad.set_color(0, Color(1.0, 1.0, 1.0, 1.0))
	grad.set_color(1, Color(1.0, 1.0, 1.0, 0.0))
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(0.5, 0.0)
	tex.width = size
	tex.height = size
	return tex

func _build_animations() -> void:
	var lib := AnimationLibrary.new()

	var idle := Animation.new()
	idle.length = 1.0
	idle.loop_mode = Animation.LOOP_LINEAR
	var t := idle.add_track(Animation.TYPE_VALUE)
	idle.track_set_path(t, "Sprite2D:position")
	idle.value_track_set_update_mode(t, Animation.UPDATE_CONTINUOUS)
	idle.track_insert_key(t, 0.0, Vector2(0,  0))
	idle.track_insert_key(t, 0.5, Vector2(0,  2))
	idle.track_insert_key(t, 1.0, Vector2(0,  0))
	lib.add_animation("idle", idle)

	var walk := Animation.new()
	walk.length = 0.35
	walk.loop_mode = Animation.LOOP_LINEAR
	t = walk.add_track(Animation.TYPE_VALUE)
	walk.track_set_path(t, "Sprite2D:position")
	walk.value_track_set_update_mode(t, Animation.UPDATE_CONTINUOUS)
	walk.track_insert_key(t, 0.000, Vector2(0,  0))
	walk.track_insert_key(t, 0.088, Vector2(0, -3))
	walk.track_insert_key(t, 0.175, Vector2(0,  0))
	walk.track_insert_key(t, 0.263, Vector2(0, -3))
	walk.track_insert_key(t, 0.350, Vector2(0,  0))
	lib.add_animation("walk", walk)

	anim_player.add_animation_library("", lib)

func _unhandled_input(event: InputEvent) -> void:
	if not GameState.game_active:
		return
	if event.is_action_pressed("dash"):
		_try_dash()
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			_try_dash()

func _try_dash() -> void:
	if _dash_cooldown > 0.0 or _dash_active:
		return
	_dash_dir = _last_move_dir
	_facing = _dir_to_compass(_dash_dir)
	_dash_hit_set.clear()
	_dash_active  = true
	_dash_timer   = DASH_DURATION_BASE * GameState.dash_distance_mul
	_dash_cooldown = DASH_COOLDOWN_BASE * GameState.dash_cooldown_mul
	# Clear web slow — dashing through breaks it
	_slow_factor = 1.0
	_slow_timer  = 0.0
	is_invincible = true
	iframes_timer.start(_dash_timer + 0.05)
	Sfx.play(WOOSH_SOUND, -6.0, 0.08)
	for _i in 5:
		_spawn_dash_dust()
	# Grave Robber: the dash rips every XP orb on the field loose
	if GameState.dash_vacuum:
		var container := get_tree().get_first_node_in_group("xp_orbs_container")
		if container:
			for orb in container.get_children():
				orb._attracted = true
				orb._attract_speed = 80.0
	queue_redraw()

func _do_dash_knockback() -> void:
	var radius       := DASH_KNOCKBACK_BASE * GameState.dash_knockback_mul
	var force        := DASH_KNOCKBACK_FORCE * GameState.dash_knockback_mul
	var contact_dist := 32.0  # player radius (15) + enemy radius (13) + buffer
	for enemy: Node2D in get_tree().get_nodes_in_group("enemies"):
		var diff := enemy.global_position - global_position
		var d    := diff.length()
		var dir  := diff.normalized() if d > 0.01 else _dash_dir
		if enemy not in _dash_hit_set and d < radius:
			_dash_hit_set.append(enemy)
			if enemy.has_method("apply_knockback"):
				enemy.apply_knockback(dir, force)
			# Puppet Master (Reaper): charm non-boss enemies charged through
			if Meta.selected_character == "reaper" and enemy.has_method("apply_charm"):
				if not enemy.is_in_group("bosses"):
					enemy.apply_charm(5.0)  # Charm for 5 seconds
			# Phase Ripper: dashing through deals weapon damage
			if GameState.dash_damage_pct > 0.0 and enemy.has_method("take_hit"):
				var dmg := int(GameState.projectile_damage * GameState.attack_damage_mul() * GameState.dash_damage_pct)
				enemy.take_hit(dmg)
				GameState.damage_dealt += dmg
				var dn := get_tree().get_first_node_in_group("damage_numbers")
				if dn:
					dn.pop(enemy.global_position, dmg, false)
		# Every frame: push overlapping enemies physically outside contact radius
		if d < contact_dist and d > 0.01:
			enemy.global_position += dir * (contact_dist - d)

func _physics_process(delta: float) -> void:
	# Dash active — override all movement
	if _dash_active:
		_dash_timer -= delta
		_do_dash_knockback()
		_dust_timer -= delta
		if _dust_timer <= 0.0:
			_dust_timer = 0.03
			_spawn_dash_dust()
		if _dash_timer <= 0.0:
			_dash_active = false
		velocity = _dash_dir * DASH_SPEED
		move_and_slide()
		global_position.x = clampf(global_position.x, 20.0, GameState.WORLD_SIZE.x - 20.0)
		global_position.y = clampf(global_position.y, 20.0, GameState.WORLD_SIZE.y - 20.0)
		if _animated_mode:
			_play_anim("roll")
		queue_redraw()
		return

	# Dash cooldown countdown
	if _dash_cooldown > 0.0:
		_dash_cooldown = maxf(0.0, _dash_cooldown - delta)

	# Web slow countdown
	if _slow_timer > 0.0:
		_slow_timer -= delta
		if _slow_timer <= 0.0:
			_slow_factor = 1.0

	var dir := Vector2(
		Input.get_axis("move_left", "move_right"),
		Input.get_axis("move_up", "move_down")
	)
	var effective_speed := GameState.current_move_speed() * _slow_factor
	if dir != Vector2.ZERO:
		_last_move_dir = dir.normalized()
		_facing = _dir_to_compass(_last_move_dir)
		velocity = _last_move_dir * effective_speed
		if dir.x != 0.0:
			sprite.flip_h = dir.x < 0.0
	else:
		velocity = velocity.move_toward(Vector2.ZERO, effective_speed)
	move_and_slide()
	global_position.x = clampf(global_position.x, 20.0, GameState.WORLD_SIZE.x - 20.0)
	global_position.y = clampf(global_position.y, 20.0, GameState.WORLD_SIZE.y - 20.0)

	var moving := velocity.length() > 5.0
	if moving:
		_trail_timer -= delta
		if _trail_timer <= 0.0:
			_trail_timer = 0.1
			_leave_blood_trail()

	if _animated_mode:
		_play_anim("run" if moving else "idle")
	else:
		var cur := anim_player.current_animation
		if moving and cur != "walk":
			anim_player.play("walk")
		elif not moving and cur != "idle":
			anim_player.play("idle")

	queue_redraw()

func _fire() -> void:
	attack_timer.wait_time = 1.0 / GameState.fire_rate
	var enemies := get_tree().get_nodes_in_group("enemies")
	if enemies.is_empty():
		return
	var nearest: Node2D = null
	var nearest_dist := INF
	for e: Node2D in enemies:
		# Skip charmed enemies - they're on our side now
		if e.has_method("get") and e.get("_charmed") and e._charmed:
			continue
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
	var base_dir := to_nearest.normalized() if to_nearest.length_squared() > 0.0001 else _last_move_dir
	var count := GameState.projectile_count
	var dmg := int(GameState.projectile_damage * GameState.attack_damage_mul())
	for i in count:
		var proj: Area2D = PROJECTILE_SCENE.instantiate()
		_proj_container.add_child(proj)
		proj.global_position = global_position
		var angle_offset := 0.0
		if count > 1:
			# Spread widens with projectile count so 8-shot builds fan out
			var half_spread := 0.1 + 0.04 * (count - 2)
			angle_offset = lerp(-half_spread, half_spread, float(i) / float(count - 1))
		proj.launch(
			base_dir.rotated(angle_offset),
			dmg,
			GameState.projectile_speed,
			GameState.projectile_pierce
		)
	# Eyes in the Back: one bonus shot straight behind the volley
	if GameState.rear_shot:
		var rear: Area2D = PROJECTILE_SCENE.instantiate()
		_proj_container.add_child(rear)
		rear.global_position = global_position
		rear.launch(-base_dir, dmg, GameState.projectile_speed, GameState.projectile_pierce)

func apply_slow(duration: float, factor: float) -> void:
	if _dash_active:
		return
	_slow_factor = minf(_slow_factor, factor)
	_slow_timer  = maxf(_slow_timer, duration)
	queue_redraw()

func _draw() -> void:
	# Web-slow ring: fading blue arc
	if _slow_timer > 0.0:
		var alpha := clampf(_slow_timer / 3.0, 0.15, 0.65)
		draw_arc(Vector2.ZERO, 18.0, 0.0, TAU, 24, Color(0.3, 0.55, 1.0, alpha), 2.5)

	# Dash cooldown ring: fills clockwise from top; pulses gold when ready
	var eff_cd := DASH_COOLDOWN_BASE * GameState.dash_cooldown_mul
	if _dash_cooldown > 0.0:
		var frac := 1.0 - clampf(_dash_cooldown / eff_cd, 0.0, 1.0)
		if frac > 0.0:
			draw_arc(Vector2.ZERO, 22.0, -PI * 0.5,
					-PI * 0.5 + TAU * frac, 36, Color(0.85, 0.82, 0.18, 0.60), 2.0)
	else:
		var pulse := 0.30 + 0.22 * sin(Time.get_ticks_msec() * 0.006)
		draw_arc(Vector2.ZERO, 22.0, 0.0, TAU, 36, Color(1.0, 0.90, 0.12, pulse), 2.0)

func shake(strength: float, duration: float) -> void:
	if not Settings.screen_shake_enabled:
		return
	_shake_strength = maxf(_shake_strength, strength)
	if duration > _shake_timer:
		_shake_timer   = duration
		_shake_duration = duration

func _process(delta: float) -> void:
	if _shake_timer > 0.0 and delta > 0.0:
		_shake_timer = maxf(0.0, _shake_timer - delta)
		var decay := _shake_timer / _shake_duration
		camera.offset = Vector2(
			randf_range(-_shake_strength, _shake_strength) * decay,
			randf_range(-_shake_strength, _shake_strength) * decay
		)
		if _shake_timer <= 0.0:
			_shake_strength = 0.0
			camera.offset   = Vector2.ZERO

func take_damage(amount: int) -> void:
	if is_invincible:
		return
	GameState.take_damage(amount)
	if _second_wind_fired:
		# Death Defiance handled this hit (2s shield, flash, hitstop already
		# applied in _on_second_wind) — don't clobber its window with the
		# standard 0.6s i-frames. The rescue nova below still fires.
		_second_wind_fired = false
		if GameState.hurt_nova_level > 0:
			_hurt_nova()
		return
	is_invincible = true
	iframes_timer.start(0.6)
	Sfx.play(HURT_SOUND, -4.0, 0.1)
	_flash_damage()
	shake(30.0, 0.18)
	GameState.hitstop(0.05)
	# Tantrum nova — but not on the hit that killed us
	if GameState.game_active and GameState.hurt_nova_level > 0:
		_hurt_nova()

# Tantrum: taking a hit detonates a retaliatory nova around the player.
const HURT_NOVA_RADIUS    := 130.0
const HURT_NOVA_KNOCKBACK := 420.0
func _hurt_nova() -> void:
	var dmg := int(GameState.projectile_damage * GameState.attack_damage_mul()
		* 1.5 * GameState.hurt_nova_level)
	var dn := get_tree().get_first_node_in_group("damage_numbers")
	for enemy: Node2D in get_tree().get_nodes_in_group("enemies"):
		var diff := enemy.global_position - global_position
		var d := diff.length()
		if d > HURT_NOVA_RADIUS:
			continue
		var dir := diff.normalized() if d > 0.01 else _last_move_dir
		if enemy.has_method("apply_knockback"):
			enemy.apply_knockback(dir, HURT_NOVA_KNOCKBACK)
		if enemy.has_method("take_hit"):
			enemy.take_hit(dmg)
			GameState.damage_dealt += dmg
			if dn:
				dn.pop(enemy.global_position, dmg, false)
	var ring := Node2D.new()
	ring.set_script(preload("res://scripts/HellfireRing.gd"))
	get_tree().current_scene.add_child(ring)
	ring.global_position = global_position
	shake(45.0, 0.25)

# Corpse tint: full dark red for the static sprite; softer for the animated
# wizard so the Die animation stays readable.
func _death_tint() -> Color:
	return Color(0.75, 0.5, 0.5) if _animated_mode else Color(0.4, 0.0, 0.0)

func _flash_damage() -> void:
	for _i in 3:
		modulate = Color(2.0, 0.2, 0.2)
		await get_tree().create_timer(0.07).timeout
		if not GameState.game_active:
			# Died mid-flash: keep the corpse tint, don't wash white
			modulate = _death_tint()
			return
		modulate = Color.WHITE
		await get_tree().create_timer(0.07).timeout

# Selected character's visuals (CharacterData.gd). Animated characters swap in
# the 8-directional AnimatedSprite2D; static ones set the Sprite2D texture.
func _apply_character_visuals() -> void:
	var character := CharacterData.get_selected()
	var s: float = character["sprite_scale"] * PLAYER_SIZE_MUL
	_animated_mode = character.get("animated", false)
	if _animated_mode:
		sprite.hide()
		anim_sprite.show()
		# HD frames want smooth sampling; project default is nearest (pixel art)
		anim_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		# Use appropriate animation set based on character
		if Meta.selected_character == "reaper":
			anim_sprite.sprite_frames = WizardFrames.get_reaper_frames()
		else:
			anim_sprite.sprite_frames = WizardFrames.get_frames()
		anim_sprite.scale = Vector2(s, s)
		anim_sprite.play("idle_S")
	else:
		anim_sprite.hide()
		var tex := load(character["sprite_path"]) as Texture2D
		if tex:
			sprite.texture = tex
			sprite.scale = Vector2(s, s)

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

# Death Defiance (second-wind talent): a long invulnerability window so the
# hit that "killed" us can't immediately land again. Fires synchronously from
# inside GameState.take_damage — _second_wind_fired tells take_damage to skip
# its own (shorter) i-frames afterwards.
var _second_wind_fired := false
func _on_second_wind() -> void:
	_second_wind_fired = true
	is_invincible = true
	iframes_timer.start(2.0)
	Sfx.play(HURT_SOUND, -2.0, 0.0)
	shake(50.0, 0.3)
	GameState.hitstop(0.12)
	_flash_damage()

func _spawn_dash_dust() -> void:
	var dust := Node2D.new()
	dust.set_script(DASH_DUST)
	get_parent().add_child(dust)
	dust.global_position = global_position + Vector2(randf_range(-6, 6), randf_range(8, 14))
	dust.setup(_dash_dir)

func _leave_blood_trail() -> void:
	var drop := Node2D.new()
	drop.set_script(BLOOD_DROP)
	get_parent().add_child(drop)
	drop.global_position = global_position + Vector2(randf_range(-5, 5), randf_range(3, 9))
	drop.setup(randf_range(1.5, 3.5), Color(randf_range(0.35, 0.6), 0.0, 0.0, 1.0))

func _on_game_over() -> void:
	set_physics_process(false)
	attack_timer.stop()
	if _animated_mode:
		_play_anim("die")
	modulate = _death_tint()
