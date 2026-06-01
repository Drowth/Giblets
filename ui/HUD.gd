extends Control

@onready var health_bar: ProgressBar = $TopBar/MarginContainer/HBox/HealthBar
@onready var xp_bar: ProgressBar = $TopBar/MarginContainer/HBox/XPBar
@onready var level_label: Label = $TopBar/MarginContainer/HBox/LevelLabel
@onready var score_label: Label = $TopBar/MarginContainer/HBox/ScoreLabel
@onready var timer_label: Label = $TopBar/MarginContainer/HBox/TimerLabel

func _ready() -> void:
	GameState.health_changed.connect(_on_health_changed)
	GameState.xp_changed.connect(_on_xp_changed)
	GameState.level_changed.connect(_on_level_changed)
	GameState.score_changed.connect(_on_score_changed)
	_refresh()

func _refresh() -> void:
	health_bar.max_value = GameState.player_max_health
	health_bar.value = GameState.player_health
	xp_bar.max_value = GameState.xp_to_next_level
	xp_bar.value = GameState.player_xp
	level_label.text = "LVL %d" % GameState.player_level
	score_label.text = "%d" % GameState.score

func _process(_delta: float) -> void:
	var t := int(GameState.elapsed_time)
	timer_label.text = "%d:%02d" % [t / 60, t % 60]

func _on_health_changed(current: int, maximum: int) -> void:
	health_bar.max_value = maximum
	health_bar.value = current

func _on_xp_changed(current: int, required: int) -> void:
	xp_bar.max_value = required
	xp_bar.value = current

func _on_level_changed(new_level: int) -> void:
	level_label.text = "LVL %d" % new_level

func _on_score_changed(new_score: int) -> void:
	score_label.text = "%d" % new_score

func show_game_over() -> void:
	var overlay := ColorRect.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0.0, 0.0, 0.0, 0.0)
	overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(overlay)

	var tween := overlay.create_tween()
	tween.tween_property(overlay, "color", Color(0.0, 0.0, 0.0, 0.88), 1.2)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.process_mode = Node.PROCESS_MODE_ALWAYS
	overlay.add_child(center)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(vbox)

	var title := Label.new()
	title.text = "YOU DIED"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 62)
	title.add_theme_color_override("font_color", Color(0.88, 0.04, 0.04))
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(title)

	var score_lbl := Label.new()
	score_lbl.text = "SCORE  %d" % GameState.score
	score_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	score_lbl.add_theme_font_size_override("font_size", 36)
	score_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.1))
	score_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(score_lbl)

	var t := int(GameState.elapsed_time)
	var stats_lbl := Label.new()
	stats_lbl.text = "Level %d  •  %d kills  •  %d:%02d survived" % [
		GameState.player_level,
		GameState.enemies_killed,
		t / 60, t % 60
	]
	stats_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats_lbl.add_theme_font_size_override("font_size", 17)
	stats_lbl.add_theme_color_override("font_color", Color(0.7, 0.65, 0.7))
	stats_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(stats_lbl)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 18)
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(spacer)

	var restart_btn := Button.new()
	restart_btn.text = "RISE AGAIN"
	restart_btn.custom_minimum_size = Vector2(240, 52)
	restart_btn.process_mode = Node.PROCESS_MODE_ALWAYS
	restart_btn.add_theme_font_size_override("font_size", 22)
	restart_btn.pressed.connect(func():
		get_tree().paused = false
		get_tree().reload_current_scene()
	)
	vbox.add_child(restart_btn)
