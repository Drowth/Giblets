extends Node2D

const ENEMY_SCENE         = preload("res://scenes/Enemy.tscn")
const WRAITH_SCENE        = preload("res://scenes/Wraith.tscn")
const SPIDER_SCENE        = preload("res://scenes/Spider.tscn")
const IMP_SCENE           = preload("res://scenes/Imp.tscn")
const BONE_CHARGER_SCENE  = preload("res://scenes/BoneCharger.tscn")
const BUTCHER_SCENE       = preload("res://scenes/Butcher.tscn")
const BONE_SENTRY_SCRIPT  = preload("res://scripts/BoneSentry.gd")
const BLOOD_SMEARS_SCRIPT = preload("res://scripts/BloodSmears.gd")
const DAMAGE_NUMBERS_SCRIPT = preload("res://scripts/DamageNumbers.gd")
const PAUSE_SCRIPT        = preload("res://ui/PauseScreen.gd")

# =========================================================================
# Balance constants — every value here is derived in docs/BALANCE.md.
# =========================================================================

# --- Spawn curve (§3): 0.5/s at start rising to ~9/s at minute 20,
# bounded by MAX_LIVE_ENEMIES for perf and readability.
const SPAWN_INTERVAL_START := 2.0
const SPAWN_INTERVAL_MIN   := 0.60
const SPAWN_INTERVAL_DECAY := 0.07   # seconds shaved per minute
const WAVE_SIZE_GROWTH     := 0.35   # extra enemies per wave per minute
const WAVE_SIZE_CAP        := 8
const MAX_LIVE_ENEMIES     := 130

# --- Enemy scaling (§3): HP tracks the player DPS budget so TTK stays flat
# early and rises late; speed capped below player speed so kiting always
# works; damage grows slowly because volume is the real threat.
const HP_SCALE_LIN  := 0.12    # per minute
const HP_SCALE_QUAD := 0.020   # per minute², the mid/late squeeze — puts
                               # influx/DPS parity near minute 15 for a
                               # median build (BalanceSim-tuned)
const SPEED_SCALE   := 6.0     # px/s gained per minute
const DMG_SCALE     := 0.18    # per minute
const XP_TIME_SCALE := 0.15    # per minute — keeps mid-game leveling on pace
                               # while the quadratic requirement still wins late

# --- Post-20-minute death ramp (§3): a wall, not a slope. Runs must end.
const OVERTIME_START := 18.0   # minutes
const OVERTIME_QUAD  := 0.60   # (m-18)² coefficient on enemy HP and damage —
                               # steep enough to end even snowballed builds by ~24

# --- Boss (§4): HP derived from the DPS budget to force a 15-25 s TTK for
# an on-curve build. Butcher trades 20% HP for its charge threat.
const BOSS_INTERVAL     := 90.0  # seconds between bosses (mirrored in Main.tscn BossTimer)
const BOSS_TTK_TARGET   := 20.0
const BOSS_FOCUS_FACTOR := 0.85  # share of player fire that hits the boss
const BUTCHER_HP_MUL    := 0.8
const BOSS_SPEED_BASE   := 28.0
const BOSS_SPEED_SCALE  := 8.0
const BOSS_SPEED_CAP    := 52.0
const BOSS_DMG_BASE     := 25.0

# --- Per-archetype base stats and speed caps (§3 table).
const BRAWLER_STATS := {"hp": 25.0, "spd": 55.0, "cap": 140.0, "dmg": 10.0, "xp": 20.0}
const SPIDER_STATS  := {"hp": 10.0, "spd": 95.0, "cap": 150.0, "dmg":  6.0, "xp":  8.0}
const WRAITH_STATS  := {"hp": 15.0, "spd": 80.0, "cap": 165.0, "dmg":  8.0, "xp": 25.0}
const CYCLOPS_STATS := {"hp": 75.0, "spd": 28.0, "cap":  90.0, "dmg": 12.0, "xp": 60.0}
const IMP_STATS     := {"hp": 12.0, "spd": 70.0, "cap": 130.0, "dmg":  7.0, "xp": 14.0}
const CHARGER_STATS := {"hp": 35.0, "spd": 40.0, "cap": 100.0, "dmg": 18.0, "xp": 30.0}

var _crt_rect:            ColorRect   = null
var _enemies_canvas:      CanvasLayer = null
var _pause_screen:        CanvasLayer = null
var _boss_index:          int         = 0

@onready var enemies_container: Node2D = $Enemies
@onready var projectiles_container: Node2D = $Projectiles
@onready var xp_orbs_container: Node2D = $XPOrbs
@onready var spawn_timer: Timer = $SpawnTimer
@onready var level_up_screen = $UI/LevelUpScreen
@onready var hud = $UI/HUD
@onready var loading_screen = $UI/LoadingScreen
@onready var music_player:    AudioStreamPlayer = $MusicPlayer
@onready var xp_pickup_sfx:   AudioStreamPlayer = $XPPickupSFX
@onready var level_up_sfx:    AudioStreamPlayer = $LevelUpSFX
@onready var upgrade_music:   AudioStreamPlayer = $UpgradeMusic
@onready var boss_timer:      Timer             = $BossTimer

func _ready() -> void:
	enemies_container.add_to_group("enemies_container")
	projectiles_container.add_to_group("projectiles_container")
	xp_orbs_container.add_to_group("xp_orbs_container")
	spawn_timer.timeout.connect(_spawn_wave)
	boss_timer.timeout.connect(_spawn_boss)
	GameState.level_up_triggered.connect(_on_level_up)
	GameState.game_over.connect(_on_game_over)
	GameState.sentry_summoned.connect(_on_sentry_summoned)
	GameState.start_game()
	# Fade to loading screen before heavy asset loading, then fade out once complete
	if loading_screen:
		await loading_screen.fade_in()
	_prebuild_enemy_animations()
	if loading_screen:
		await loading_screen.fade_out()
	_start_music()
	_load_xp_sfx()
	_load_level_up_sfx()
	_load_upgrade_music()
	if level_up_screen:
		level_up_screen.connect("upgrade_chosen", _on_upgrade_chosen)
		level_up_screen.hide()
	_setup_blood_smears()
	_setup_crt()
	_setup_enemies_canvas()
	_setup_damage_numbers()
	_setup_pause_screen()
	Settings.crt_settings_changed.connect(_apply_crt_settings)
	_apply_meta_start_conditions.call_deferred()
	if OS.get_environment("GIBLETS_SOAK") == "1":
		_start_soak_mode()

# --- Soak harness: headless physics/AI regression test (found the grounded-
# motion-mode NaN bug — see motion_mode in the enemy _ready()s).
# Run: $env:GIBLETS_SOAK='1'; godot --path . --headless res://scenes/Main.tscn
# God-modes the player, runs 5x speed, auto-picks level-ups, and reports any
# physics body whose position/velocity goes non-finite or runs away; a clean
# pass reaches 12 game-minutes at the live-enemy cap with zero warnings.
var _soak_offenders := 0
func _start_soak_mode() -> void:
	Engine.time_scale = 5.0
	var watchdog := Timer.new()
	watchdog.wait_time = 0.25
	watchdog.autostart = true
	watchdog.process_mode = Node.PROCESS_MODE_ALWAYS  # must survive level-up pause
	add_child(watchdog)
	watchdog.timeout.connect(_soak_tick)
	print("SOAK: started")

func _soak_tick() -> void:
	Engine.time_scale = 5.0  # hitstop restores to 1.0; push back to soak speed
	GameState.player_health = GameState.player_max_health
	# Auto-resolve level-ups so the run keeps flowing
	while GameState.has_pending_level_up():
		var choices := UpgradeData.get_random_choices(3)
		if not choices.is_empty():
			UpgradeData.apply_upgrade(choices.pick_random())
		GameState.consume_level_up()
	if level_up_screen and level_up_screen.visible:
		level_up_screen.hide()
	if get_tree().paused:
		get_tree().paused = false
	var m := GameState.elapsed_time / 60.0
	if int(GameState.elapsed_time) % 60 < 1:
		print("SOAK: minute %.1f  live=%d" % [m, get_tree().get_nodes_in_group("enemies").size()])
	_soak_check_body(get_tree().get_first_node_in_group("player"))
	for e in get_tree().get_nodes_in_group("enemies"):
		_soak_check_body(e)
	if m >= 12.0:
		print("SOAK: reached 12 min clean, quitting")
		get_tree().quit()

func _soak_check_body(body: Node) -> void:
	if not body or not body is CharacterBody2D:
		return
	var pos: Vector2 = body.global_position
	var vel: Vector2 = body.velocity
	var bad := not pos.is_finite() or not vel.is_finite() \
		or absf(pos.x) > 1.0e7 or absf(pos.y) > 1.0e7 \
		or absf(vel.x) > 1.0e7 or absf(vel.y) > 1.0e7
	if bad:
		_soak_offenders += 1
		var script_path: String = body.get_script().resource_path if body.get_script() else "<none>"
		print("SOAK OFFENDER #%d at %.1f min: %s (%s) pos=%s vel=%s" % [
			_soak_offenders, GameState.elapsed_time / 60.0, body.name, script_path, str(pos), str(vel)])
		if body.has_method("apply_knockback"):
			print("  knockback_vel=", body.get("_knockback_vel"))
		if _soak_offenders >= 5:
			print("SOAK: enough offenders, quitting")
			get_tree().quit()
# --- END soak harness

# Permanent meta start-of-run effects (docs/BALANCE.md §6): the selected
# character's starting sentries, Grim Arsenal's free common upgrade, and Head
# Start's instant level 2 (deferred so the level-up screen is ready to show).
func _prebuild_enemy_animations() -> void:
	# Pre-build all enemy animation frames to cache them before gameplay starts.
	# This prevents freezes when new monster types spawn for the first time,
	# since WizardFrames.build() loads texture files synchronously on the main thread.
	const BRAWLER_ANIMS: Dictionary = {
		"idle": [10.0, true],
		"run":  [16.0, true],
		"die":  [34.0, false],
		"hurt": [60.0, false],
	}
	const CYCLOPS_ANIMS: Dictionary = {
		"idle": [10.0, true],
		"run":  [16.0, true],
		"die":  [34.0, false],
		"hurt": [60.0, false],
	}
	const BOSS_ANIMS: Dictionary = {
		"idle":   [10.0, true],
		"run":    [16.0, true],
		"die":    [34.0, false],
		"hurt":   [60.0, false],
		"attack": [30.0, false],
	}
	const WRAITH_ANIMS: Dictionary = {
		"idle": [10.0, true],
		"run":  [16.0, true],
		"die":  [25.0, false],
		"hurt": [60.0, false],
	}
	const IMP_ANIMS: Dictionary = {
		"idle": [10.0, true],
		"run":  [16.0, true],
		"die":  [34.0, false],
		"hurt": [60.0, false],
	}
	const CHARGER_ANIMS: Dictionary = {
		"idle":   [10.0, true],
		"run":    [16.0, true],
		"windup": [20.0, false],
		"charge": [20.0, true],
		"die":    [30.0, false],
		"hurt":   [72.0, false],
	}
	const BUTCHER_ANIMS: Dictionary = {
		"idle":   [10.0, true],
		"run":    [16.0, true],
		"windup": [15.0, false],
		"charge": [20.0, true],
		"die":    [30.0, false],
		"hurt":   [60.0, false],
	}
	const SPIDER_ANIMS: Dictionary = {
		"idle": [10.0, true],
		"run":  [16.0, true],
		"die":  [34.0, false],
		"hurt": [60.0, false],
	}
	WizardFrames.build("res://assets/enemies/brawler", BRAWLER_ANIMS)
	WizardFrames.build("res://assets/enemies/cyclops", CYCLOPS_ANIMS)
	WizardFrames.build("res://assets/enemies/boss", BOSS_ANIMS)
	WizardFrames.build("res://assets/enemies/wraith", WRAITH_ANIMS)
	WizardFrames.build("res://assets/enemies/imp", IMP_ANIMS)
	WizardFrames.build("res://assets/enemies/bonecharger", CHARGER_ANIMS)
	WizardFrames.build("res://assets/enemies/butcher", BUTCHER_ANIMS)
	WizardFrames.build("res://assets/enemies/spider", SPIDER_ANIMS)
	# Pre-build player animations too (Wizard and Reaper)
	WizardFrames.build("res://assets/player/wizard", WizardFrames.WIZARD_ANIMS)
	WizardFrames.build("res://assets/player/reaper", WizardFrames.REAPER_ANIMS)

func _apply_meta_start_conditions() -> void:
	for i in GameState.sentry_count:
		_on_sentry_summoned(i)  # explicit slot: sentry_count is already final
	if Meta.has_free_draw():
		var u := UpgradeData.get_random_by_rarity("common")
		if not u.is_empty():
			UpgradeData.apply_upgrade(u)
	if Meta.has_head_start():
		GameState.add_xp(GameState.xp_to_next_level)

func _setup_blood_smears() -> void:
	var node := BLOOD_SMEARS_SCRIPT.new()
	add_child(node)

func _setup_crt() -> void:
	$UI.layer = 200
	var crt_layer := CanvasLayer.new()
	crt_layer.layer        = 128
	crt_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	_crt_rect = ColorRect.new()
	_crt_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_crt_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_crt_rect.process_mode = Node.PROCESS_MODE_ALWAYS
	_crt_rect.visible      = Settings.crt_enabled
	var shader = load("res://shaders/crt_effect.gdshader")
	if shader:
		var mat := ShaderMaterial.new()
		mat.shader = shader
		_crt_rect.material = mat
	crt_layer.add_child(_crt_rect)
	add_child(crt_layer)

func _setup_enemies_canvas() -> void:
	_enemies_canvas                      = CanvasLayer.new()
	_enemies_canvas.follow_viewport_enabled = true
	_enemies_canvas.layer                = 150 if not Settings.crt_affects_enemies else 50
	add_child(_enemies_canvas)
	enemies_container.reparent(_enemies_canvas)

func _setup_damage_numbers() -> void:
	# Lives on the enemies canvas so numbers render above enemy sprites
	var dn := DAMAGE_NUMBERS_SCRIPT.new()
	_enemies_canvas.add_child(dn)

func _setup_pause_screen() -> void:
	_pause_screen = CanvasLayer.new()
	_pause_screen.set_script(PAUSE_SCRIPT)
	add_child(_pause_screen)

func _apply_crt_settings() -> void:
	if _crt_rect:
		_crt_rect.visible = Settings.crt_enabled
	if _enemies_canvas:
		var above := not Settings.crt_enabled or not Settings.crt_affects_enemies
		_enemies_canvas.layer = 150 if above else 50

func _start_music() -> void:
	if not music_player:
		return
	var stream = load("res://assets/music/lvl1.mp3")
	if stream:
		stream.loop = true
		music_player.stream = stream
		music_player.play()

func _load_xp_sfx() -> void:
	if not xp_pickup_sfx:
		return
	for ext in ["wav", "ogg", "mp3"]:
		var path := "res://assets/sfx/xp_pickup.%s" % ext
		var stream = load(path) if ResourceLoader.exists(path) else null
		if stream:
			xp_pickup_sfx.stream = stream
			xp_pickup_sfx.add_to_group("xp_pickup_sfx")
			return

func _load_level_up_sfx() -> void:
	if not level_up_sfx:
		return
	var stream = load("res://assets/sfx/levelup.wav")
	if stream:
		level_up_sfx.stream = stream

func _load_upgrade_music() -> void:
	if not upgrade_music:
		return
	var stream = load("res://assets/music/levelup.wav")
	if stream:
		upgrade_music.stream = stream
		upgrade_music.finished.connect(func():
			if upgrade_music.stream and upgrade_music.playing == false:
				upgrade_music.play()
		)

func _minutes() -> float:
	return GameState.elapsed_time / 60.0

func _process(_delta: float) -> void:
	spawn_timer.wait_time = maxf(SPAWN_INTERVAL_MIN,
		SPAWN_INTERVAL_START - _minutes() * SPAWN_INTERVAL_DECAY)

# --- Scaling helpers (docs/BALANCE.md §3) --------------------------------

func _overtime_mult(m: float) -> float:
	var over := maxf(0.0, m - OVERTIME_START)
	return 1.0 + OVERTIME_QUAD * over * over

func _hp_at(base: float, m: float) -> int:
	return int(base * (1.0 + HP_SCALE_LIN * m + HP_SCALE_QUAD * m * m) * _overtime_mult(m))

func _spd_at(base: float, cap: float, m: float) -> float:
	return minf(base + SPEED_SCALE * m, cap)

func _dmg_at(base: float, m: float) -> int:
	return int(base * (1.0 + DMG_SCALE * m) * _overtime_mult(m))

func _xp_at(base: float, m: float) -> int:
	return int(base * (1.0 + XP_TIME_SCALE * m))

func _apply_stats(enemy: Node, stats: Dictionary, m: float) -> void:
	enemy.max_health = _hp_at(stats["hp"], m)
	enemy.health     = enemy.max_health
	enemy.move_speed = _spd_at(stats["spd"], stats["cap"], m)
	enemy.damage     = _dmg_at(stats["dmg"], m)
	enemy.xp_value   = _xp_at(stats["xp"], m)

# --- Spawning -------------------------------------------------------------

func _get_screen_center() -> Vector2:
	var player := get_tree().get_first_node_in_group("player")
	var vp_half := get_viewport().get_visible_rect().size / 2.0
	if not player:
		return GameState.WORLD_SIZE / 2.0
	return Vector2(
		clampf(player.global_position.x, vp_half.x, GameState.WORLD_SIZE.x - vp_half.x),
		clampf(player.global_position.y, vp_half.y, GameState.WORLD_SIZE.y - vp_half.y)
	)

func _spawn_wave() -> void:
	var live := get_tree().get_nodes_in_group("enemies").size()
	if live >= MAX_LIVE_ENEMIES:
		return
	var center := _get_screen_center()
	var m := _minutes()
	var count: int = mini(WAVE_SIZE_CAP, 1 + int(m * WAVE_SIZE_GROWTH))
	count = mini(count, MAX_LIVE_ENEMIES - live)
	for _i in count:
		_spawn_one(center, m)

# Mix schedule (docs/BALANCE.md §3): spiders fade out over the first 2 min,
# wraiths ramp to 35% by 1.2 min, imps to 20% from min 2, cyclops to 12%
# from min 3 (its 75 base HP dominates average HP — keep it occasional),
# bone chargers to 15% from min 4; remainder brawlers.
func _spawn_one(screen_center: Vector2, m: float) -> void:
	var spider_chance  := clampf(0.5 - m * 0.25,        0.0, 0.50)
	var wraith_chance  := clampf((m - 0.5) * 0.5,       0.0, 0.35)
	var imp_chance     := clampf((m - 2.0) * 0.1,       0.0, 0.20)
	var cyclops_chance := clampf((m - 3.0) * 0.04,      0.0, 0.12)
	var charger_chance := clampf((m - 4.0) * 0.075,     0.0, 0.15)
	var roll := randf()
	var acc := spider_chance
	if roll < acc:
		_spawn_scene(SPIDER_SCENE, SPIDER_STATS, screen_center, m)
		return
	acc += wraith_chance
	if roll < acc:
		_spawn_scene(WRAITH_SCENE, WRAITH_STATS, screen_center, m)
		return
	acc += imp_chance
	if roll < acc:
		_spawn_scene(IMP_SCENE, IMP_STATS, screen_center, m)
		return
	acc += cyclops_chance
	if roll < acc:
		_spawn_cyclops(screen_center, m)
		return
	acc += charger_chance
	if roll < acc:
		_spawn_scene(BONE_CHARGER_SCENE, CHARGER_STATS, screen_center, m)
		return
	_spawn_scene(ENEMY_SCENE, BRAWLER_STATS, screen_center, m)

func _spawn_scene(scene: PackedScene, stats: Dictionary, screen_center: Vector2, m: float) -> void:
	var enemy: Node = scene.instantiate()
	enemies_container.add_child(enemy)
	enemy.global_position = _edge_pos(screen_center)
	_apply_stats(enemy, stats, m)

func _spawn_cyclops(screen_center: Vector2, m: float) -> void:
	var enemy: Node = ENEMY_SCENE.instantiate()
	enemy.is_cyclops = true
	enemies_container.add_child(enemy)
	enemy.global_position = _edge_pos(screen_center)
	_apply_stats(enemy, CYCLOPS_STATS, m)

func _edge_pos(screen_center: Vector2) -> Vector2:
	var zoom := 1.0
	var player := get_tree().get_first_node_in_group("player")
	if player:
		var cam := player.get_node_or_null("Camera2D")
		if cam:
			zoom = cam.zoom.x
	var half := get_viewport().get_visible_rect().size / 2.0 / zoom
	var margin := 80.0
	var pos: Vector2
	match randi() % 4:
		0: pos = Vector2(randf_range(screen_center.x - half.x, screen_center.x + half.x), screen_center.y - half.y - margin)
		1: pos = Vector2(randf_range(screen_center.x - half.x, screen_center.x + half.x), screen_center.y + half.y + margin)
		2: pos = Vector2(screen_center.x - half.x - margin, randf_range(screen_center.y - half.y, screen_center.y + half.y))
		_: pos = Vector2(screen_center.x + half.x + margin, randf_range(screen_center.y - half.y, screen_center.y + half.y))
	pos.x = clampf(pos.x, 0.0, GameState.WORLD_SIZE.x)
	pos.y = clampf(pos.y, 0.0, GameState.WORLD_SIZE.y)
	return pos

# --- Bosses ---------------------------------------------------------------

const BOSS_WARNING_SOUND := "res://assets/sfx/game/boss_warning.wav"

func _spawn_boss() -> void:
	if not GameState.game_active:
		return
	if not get_tree().get_nodes_in_group("bosses").is_empty():
		# Previous boss outlasted the timer (a struggling build) — don't
		# stack a second one on top. Retry next timeout instead.
		return
	Sfx.play(BOSS_WARNING_SOUND, -2.0)
	_show_boss_warning()
	var m := _minutes()
	# HP derived from the DPS budget (docs/BALANCE.md §4)
	var hp := int(BOSS_TTK_TARGET * GameState.dps_target(m) * BOSS_FOCUS_FACTOR * _overtime_mult(m))
	var boss: Node
	if _boss_index % 2 == 0:
		boss = ENEMY_SCENE.instantiate()
		boss.is_boss    = true
		boss.max_health = hp
		boss.move_speed = minf(BOSS_SPEED_BASE + m * BOSS_SPEED_SCALE, BOSS_SPEED_CAP)
	else:
		boss = BUTCHER_SCENE.instantiate()
		boss.max_health = int(hp * BUTCHER_HP_MUL)
	boss.damage   = _dmg_at(BOSS_DMG_BASE, m)
	boss.xp_value = 500  # score value; XP drop is level-derived in the boss script
	_boss_index += 1
	enemies_container.add_child(boss)
	boss.global_position = _edge_pos(_get_screen_center())

func _show_boss_warning() -> void:
	var canvas := CanvasLayer.new()
	canvas.layer = 10
	var lbl := Label.new()
	lbl.text = "THE BUTCHER APPROACHES" if _boss_index % 2 == 1 else "BOSS INCOMING"
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.add_theme_color_override("font_color", Color(1.0, 0.3, 0.0))
	lbl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(lbl)
	add_child(canvas)
	var tw := lbl.create_tween()
	tw.tween_interval(0.6)
	tw.tween_property(lbl, "modulate:a", 0.0, 2.0)
	tw.tween_callback(canvas.queue_free)

# --- Level-up / game-over flow ---------------------------------------------

func _on_level_up() -> void:
	if level_up_sfx and level_up_sfx.stream:
		level_up_sfx.play()
	if music_player and music_player.playing:
		var tw := music_player.create_tween()
		tw.tween_property(music_player, "volume_db", -18.0, 0.3)
	if not level_up_screen or not is_instance_valid(level_up_screen):
		level_up_screen = get_tree().get_first_node_in_group("level_up_screen")
	if not level_up_screen:
		GameState.consume_level_up()
		return
	get_tree().paused = true
	level_up_screen.show()
	level_up_screen.show_choices()

func _on_upgrade_chosen() -> void:
	GameState.consume_level_up()
	if GameState.has_pending_level_up():
		level_up_screen.show_choices()
	else:
		level_up_screen.hide()
		if not (_pause_screen and _pause_screen.visible):
			get_tree().paused = false
		if music_player and music_player.playing:
			var tw := music_player.create_tween()
			tw.tween_property(music_player, "volume_db", -8.0, 0.5)

func _on_sentry_summoned(orbit_index: int = -1) -> void:
	var player := get_tree().get_first_node_in_group("player")
	if not player:
		return
	var sentry := Node2D.new()
	sentry.set_script(BONE_SENTRY_SCRIPT)
	sentry.orbit_index = orbit_index
	add_child(sentry)
	sentry.global_position = player.global_position

func _on_game_over() -> void:
	spawn_timer.stop()
	boss_timer.stop()
	if upgrade_music and upgrade_music.playing:
		upgrade_music.stop()
	if music_player:
		var tween := create_tween()
		tween.tween_property(music_player, "volume_db", -60.0, 2.0)
		tween.tween_callback(music_player.stop)
	await get_tree().create_timer(1.5).timeout
	if hud:
		hud.show_game_over()
