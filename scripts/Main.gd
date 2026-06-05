extends Node2D

const ENEMY_SCENE         = preload("res://scenes/Enemy.tscn")
const WRAITH_SCENE        = preload("res://scenes/Wraith.tscn")
const CYCLOPS_TEXTURE     = preload("res://assets/enemies/cyclops.png")
const BONE_SENTRY_SCRIPT  = preload("res://scripts/BoneSentry.gd")
const BLOOD_SMEARS_SCRIPT = preload("res://scripts/BloodSmears.gd")
const OPTIONS_SCRIPT      = preload("res://ui/OptionsScreen.gd")

var _crt_rect:            ColorRect   = null
var _enemies_canvas:      CanvasLayer = null
var _options_screen:      CanvasLayer = null
var _crt_enabled:         bool        = true
var _crt_affects_enemies: bool        = false

@onready var enemies_container: Node2D = $Enemies
@onready var projectiles_container: Node2D = $Projectiles
@onready var xp_orbs_container: Node2D = $XPOrbs
@onready var spawn_timer: Timer = $SpawnTimer
@onready var level_up_screen = $UI/LevelUpScreen
@onready var hud = $UI/HUD
@onready var music_player:    AudioStreamPlayer = $MusicPlayer
@onready var xp_pickup_sfx:   AudioStreamPlayer = $XPPickupSFX
@onready var level_up_sfx:    AudioStreamPlayer = $LevelUpSFX
@onready var upgrade_music:   AudioStreamPlayer = $UpgradeMusic
@onready var boss_timer:      Timer             = $BossTimer

func _ready() -> void:
	_setup_inputs()
	enemies_container.add_to_group("enemies_container")
	projectiles_container.add_to_group("projectiles_container")
	xp_orbs_container.add_to_group("xp_orbs_container")
	spawn_timer.timeout.connect(_spawn_wave)
	boss_timer.timeout.connect(_spawn_boss)
	GameState.level_up_triggered.connect(_on_level_up)
	GameState.game_over.connect(_on_game_over)
	GameState.sentry_summoned.connect(_on_sentry_summoned)
	GameState.start_game()
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
	_setup_options_screen()

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
	_enemies_canvas.layer                = 150 if not _crt_affects_enemies else 50
	add_child(_enemies_canvas)
	enemies_container.reparent(_enemies_canvas)

func _setup_options_screen() -> void:
	_options_screen = CanvasLayer.new()
	_options_screen.set_script(OPTIONS_SCRIPT)
	add_child(_options_screen)
	_options_screen.open_requested.connect(func():
		if GameState.game_active:
			_open_options()
	)
	_options_screen.crt_changed.connect(_on_crt_changed)
	_options_screen.crt_enemies_changed.connect(_on_crt_enemies_changed)
	_options_screen.resumed.connect(_close_options)

func _open_options() -> void:
	get_tree().paused = true
	_options_screen.open(_crt_enabled, _crt_affects_enemies)

func _close_options() -> void:
	_options_screen.hide()
	if not GameState.has_pending_level_up():
		get_tree().paused = false

func _on_crt_changed(enabled: bool) -> void:
	_crt_enabled = enabled
	_apply_crt_settings()

func _on_crt_enemies_changed(enabled: bool) -> void:
	_crt_affects_enemies = enabled
	_apply_crt_settings()

func _apply_crt_settings() -> void:
	if _crt_rect:
		_crt_rect.visible = _crt_enabled
	if _enemies_canvas:
		var above := not _crt_enabled or not _crt_affects_enemies
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

func _setup_inputs() -> void:
	var wasd := {"ui_left": KEY_A, "ui_right": KEY_D, "ui_up": KEY_W, "ui_down": KEY_S}
	for action: String in wasd:
		var ev := InputEventKey.new()
		ev.keycode = wasd[action]
		InputMap.action_add_event(action, ev)

func _process(_delta: float) -> void:
	spawn_timer.wait_time = maxf(0.35, 2.0 - GameState.elapsed_time * 0.012)

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
	var center := _get_screen_center()
	var count := 1 + int(GameState.elapsed_time / 18.0)
	for _i in count:
		_spawn_one(center)

func _spawn_one(screen_center: Vector2) -> void:
	var t := GameState.elapsed_time / 60.0
	var cyclops_chance := clampf((GameState.elapsed_time - 60.0) / 120.0, 0.0, 0.25)
	var wraith_chance  := clampf((GameState.elapsed_time - 30.0) / 60.0,  0.0, 0.50)
	var roll := randf()
	if roll < cyclops_chance:
		_spawn_cyclops(screen_center, t)
	elif roll < cyclops_chance + wraith_chance:
		_spawn_wraith(screen_center, t)
	else:
		_spawn_demon(screen_center, t)

func _spawn_demon(screen_center: Vector2, t: float) -> void:
	var enemy: Node = ENEMY_SCENE.instantiate()
	enemies_container.add_child(enemy)
	enemy.global_position = _edge_pos(screen_center)
	enemy.max_health = int(25 * (1.0 + t * 1.2))
	enemy.health = enemy.max_health
	enemy.move_speed = 55.0 + t * 35.0
	enemy.damage = int(10 * (1.0 + t * 0.5))
	enemy.xp_value = int(20 * (1.0 + t * 0.4))

func _spawn_cyclops(screen_center: Vector2, t: float) -> void:
	var enemy: Node = ENEMY_SCENE.instantiate()
	enemies_container.add_child(enemy)
	enemy.sprite.texture = CYCLOPS_TEXTURE
	enemy.global_position = _edge_pos(screen_center)
	enemy.max_health = int(75 * (1.0 + t * 1.2))
	enemy.health     = enemy.max_health
	enemy.move_speed = 28.0 + t * 12.0
	enemy.damage     = int(12 * (1.0 + t * 0.5))
	enemy.xp_value   = int(60 * (1.0 + t * 0.4))

func _spawn_wraith(screen_center: Vector2, t: float) -> void:
	var wraith: Node = WRAITH_SCENE.instantiate()
	enemies_container.add_child(wraith)
	wraith.global_position = _edge_pos(screen_center)
	wraith.max_health = int(15 * (1.0 + t * 1.0))
	wraith.health = wraith.max_health
	wraith.move_speed = 80.0 + t * 30.0
	wraith.damage = int(8 * (1.0 + t * 0.5))
	wraith.xp_value = int(25 * (1.0 + t * 0.4))

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

func _spawn_boss() -> void:
	if not GameState.game_active:
		return
	_show_boss_warning()
	var t := GameState.elapsed_time / 60.0
	var boss: Node = ENEMY_SCENE.instantiate()
	boss.is_boss    = true
	boss.max_health = int(500 * (1.0 + t * 0.8))
	boss.move_speed = minf(28.0 + t * 8.0, 52.0)
	boss.damage     = int(25 * (1.0 + t * 0.5))
	boss.xp_value   = 500
	enemies_container.add_child(boss)
	boss.global_position = _edge_pos(_get_screen_center())

func _show_boss_warning() -> void:
	var canvas := CanvasLayer.new()
	canvas.layer = 10
	var lbl := Label.new()
	lbl.text = "BOSS INCOMING"
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
		get_tree().paused = false
		if music_player and music_player.playing:
			var tw := music_player.create_tween()
			tw.tween_property(music_player, "volume_db", -8.0, 0.5)

func _on_sentry_summoned() -> void:
	var player := get_tree().get_first_node_in_group("player")
	if not player:
		return
	var sentry := Node2D.new()
	sentry.set_script(BONE_SENTRY_SCRIPT)
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
