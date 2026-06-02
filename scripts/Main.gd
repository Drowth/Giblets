extends Node2D

const ENEMY_SCENE = preload("res://scenes/Enemy.tscn")

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
	GameState.start_game()
	_start_music()
	_load_xp_sfx()
	_load_level_up_sfx()
	_load_upgrade_music()
	if level_up_screen:
		level_up_screen.connect("upgrade_chosen", _on_upgrade_chosen)
		level_up_screen.hide()

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
	var stream: AudioStreamWAV = load("res://assets/music/levelup.wav")
	if stream:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		upgrade_music.stream = stream

func _setup_inputs() -> void:
	var wasd := {"ui_left": KEY_A, "ui_right": KEY_D, "ui_up": KEY_W, "ui_down": KEY_S}
	for action: String in wasd:
		var ev := InputEventKey.new()
		ev.keycode = wasd[action]
		InputMap.action_add_event(action, ev)

func _process(_delta: float) -> void:
	spawn_timer.wait_time = maxf(0.35, 2.0 - GameState.elapsed_time * 0.012)

func _spawn_wave() -> void:
	var vp := get_viewport_rect()
	var count := 1 + int(GameState.elapsed_time / 18.0)
	for _i in count:
		_spawn_one(vp)

func _spawn_one(vp: Rect2) -> void:
	var enemy: Node = ENEMY_SCENE.instantiate()
	enemies_container.add_child(enemy)
	enemy.global_position = _edge_pos(vp)
	var t := GameState.elapsed_time / 60.0
	enemy.max_health = int(25 * (1.0 + t * 1.2))
	enemy.health = enemy.max_health
	enemy.move_speed = 55.0 + t * 35.0
	enemy.damage = int(10 * (1.0 + t * 0.5))
	enemy.xp_value = int(20 * (1.0 + t * 0.4))

func _edge_pos(vp: Rect2) -> Vector2:
	match randi() % 4:
		0: return Vector2(randf_range(0, vp.size.x), -35.0)
		1: return Vector2(randf_range(0, vp.size.x), vp.size.y + 35.0)
		2: return Vector2(-35.0, randf_range(0, vp.size.y))
		_: return Vector2(vp.size.x + 35.0, randf_range(0, vp.size.y))

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
	boss.global_position = _edge_pos(get_viewport_rect())

func _show_boss_warning() -> void:
	var canvas := CanvasLayer.new()
	canvas.layer = 10
	var lbl := Label.new()
	lbl.text = "BOSS INCOMING"
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 40)
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
	if upgrade_music and upgrade_music.stream and not upgrade_music.playing:
		upgrade_music.volume_db = -6.0
		upgrade_music.play()
	if music_player and music_player.playing:
		var tw := music_player.create_tween()
		tw.tween_property(music_player, "volume_db", -60.0, 0.3)
		tw.tween_callback(func(): music_player.stream_paused = true)
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
		if upgrade_music and upgrade_music.playing:
			var tw := upgrade_music.create_tween()
			tw.tween_property(upgrade_music, "volume_db", -60.0, 0.4)
			tw.tween_callback(upgrade_music.stop)
		if music_player and music_player.stream_paused:
			music_player.stream_paused = false
			var tw := music_player.create_tween()
			tw.tween_property(music_player, "volume_db", -8.0, 0.5)

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
