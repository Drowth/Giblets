extends Control

@onready var health_bar:  ProgressBar = $TopBar/MarginContainer/HBox/HealthBarContainer/HealthBar
@onready var health_text: Label       = $TopBar/MarginContainer/HBox/HealthBarContainer/HealthText
@onready var xp_bar:      ProgressBar = $TopBar/MarginContainer/HBox/XPBarContainer/XPBar
@onready var xp_text:     Label       = $TopBar/MarginContainer/HBox/XPBarContainer/XPText
@onready var level_label: Label       = $TopBar/MarginContainer/HBox/LevelLabel
@onready var score_label: Label       = $TopBar/MarginContainer/HBox/ScoreLabel
@onready var timer_label: Label       = $TopBar/MarginContainer/HBox/TimerLabel

func _ready() -> void:
	GameState.health_changed.connect(_on_health_changed)
	GameState.xp_changed.connect(_on_xp_changed)
	GameState.level_changed.connect(_on_level_changed)
	GameState.score_changed.connect(_on_score_changed)
	_refresh()

func _refresh() -> void:
	health_bar.max_value  = GameState.player_max_health
	health_bar.value      = GameState.player_health
	health_text.text      = "%d / %d" % [GameState.player_health, GameState.player_max_health]
	xp_bar.max_value      = GameState.xp_to_next_level
	xp_bar.value          = GameState.player_xp
	xp_text.text          = "%d / %d" % [GameState.player_xp, GameState.xp_to_next_level]
	level_label.text      = "LVL %d" % GameState.player_level
	score_label.text      = "%d" % GameState.score

func _process(_delta: float) -> void:
	var t := int(GameState.elapsed_time)
	timer_label.text = "%d:%02d" % [t / 60, t % 60]

func _on_health_changed(current: int, maximum: int) -> void:
	health_bar.max_value = maximum
	health_bar.value     = current
	health_text.text     = "%d / %d" % [current, maximum]

func _on_xp_changed(current: int, required: int) -> void:
	xp_bar.max_value = required
	xp_bar.value     = current
	xp_text.text     = "%d / %d" % [current, required]

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
	vbox.add_theme_constant_override("separation", 12)
	vbox.custom_minimum_size = Vector2(500, 0)
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
		GameState.player_level, GameState.enemies_killed, t / 60, t % 60
	]
	stats_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats_lbl.add_theme_font_size_override("font_size", 17)
	stats_lbl.add_theme_color_override("font_color", Color(0.7, 0.65, 0.7))
	stats_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(stats_lbl)

	var sep := HSeparator.new()
	vbox.add_child(sep)

	_build_name_entry(vbox)

func _build_name_entry(vbox: VBoxContainer) -> void:
	var name_section := VBoxContainer.new()
	name_section.add_theme_constant_override("separation", 10)
	name_section.process_mode = Node.PROCESS_MODE_ALWAYS
	vbox.add_child(name_section)

	var prompt_lbl := Label.new()
	prompt_lbl.text = "ENTER YOUR NAME"
	prompt_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt_lbl.add_theme_font_size_override("font_size", 22)
	prompt_lbl.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
	name_section.add_child(prompt_lbl)

	var input_row := HBoxContainer.new()
	input_row.alignment = BoxContainer.ALIGNMENT_CENTER
	input_row.add_theme_constant_override("separation", 10)
	input_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_section.add_child(input_row)

	var name_input := LineEdit.new()
	name_input.placeholder_text = "PLAYER"
	name_input.max_length = 12
	name_input.custom_minimum_size = Vector2(220, 44)
	name_input.alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_input.process_mode = Node.PROCESS_MODE_ALWAYS
	var input_style := StyleBoxFlat.new()
	input_style.bg_color = Color(0.07, 0.03, 0.03)
	input_style.border_color = Color(1.0, 0.85, 0.1)
	input_style.set_border_width_all(2)
	input_style.set_corner_radius_all(4)
	name_input.add_theme_stylebox_override("normal", input_style)
	name_input.add_theme_stylebox_override("focus", input_style)
	name_input.add_theme_color_override("font_color", Color(1.0, 0.85, 0.1))
	name_input.add_theme_color_override("font_placeholder_color", Color(0.5, 0.42, 0.1))
	name_input.add_theme_font_size_override("font_size", 22)
	input_row.add_child(name_input)

	var confirm_btn := Button.new()
	confirm_btn.text = "OK"
	confirm_btn.custom_minimum_size = Vector2(60, 44)
	confirm_btn.process_mode = Node.PROCESS_MODE_ALWAYS
	confirm_btn.add_theme_font_size_override("font_size", 18)
	input_row.add_child(confirm_btn)

	var submitted := false
	var submit := func():
		if submitted:
			return
		submitted = true
		var raw := name_input.text.strip_edges()
		if raw.is_empty():
			raw = "UNKNOWN"
		name_section.hide()
		name_section.queue_free()
		var rank := HighScores.add_score(
			raw, GameState.score, GameState.player_level,
			GameState.enemies_killed, GameState.elapsed_time
		)
		_build_leaderboard(vbox, rank)

	confirm_btn.pressed.connect(submit)
	name_input.text_submitted.connect(func(_t): submit.call())
	name_input.grab_focus()

func _build_leaderboard(vbox: VBoxContainer, current_rank: int) -> void:
	var header := Label.new()
	header.text = "— HIGH SCORES —"
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.add_theme_font_size_override("font_size", 22)
	header.add_theme_color_override("font_color", Color(1.0, 0.85, 0.1))
	vbox.add_child(header)

	var scores := HighScores.get_scores()

	for i in scores.size():
		var entry: Dictionary = scores[i]
		var is_current := (i + 1 == current_rank)

		var row_color: Color
		if is_current:
			row_color = Color(1.0, 0.92, 0.2)
		elif i == 0:
			row_color = Color(1.0, 0.84, 0.0)
		elif i == 1:
			row_color = Color(0.75, 0.75, 0.78)
		elif i == 2:
			row_color = Color(0.80, 0.50, 0.20)
		else:
			row_color = Color(0.62, 0.58, 0.65)

		var row_font_size := 18 if is_current else 15

		var row_wrap := CenterContainer.new()
		row_wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vbox.add_child(row_wrap)

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row_wrap.add_child(row)

		var prefix_lbl := Label.new()
		prefix_lbl.text = ">" if is_current else " "
		prefix_lbl.custom_minimum_size = Vector2(14, 0)
		prefix_lbl.add_theme_font_size_override("font_size", row_font_size)
		prefix_lbl.add_theme_color_override("font_color", row_color)
		row.add_child(prefix_lbl)

		var rank_lbl := Label.new()
		rank_lbl.text = "%d." % (i + 1)
		rank_lbl.custom_minimum_size = Vector2(24, 0)
		rank_lbl.add_theme_font_size_override("font_size", row_font_size)
		rank_lbl.add_theme_color_override("font_color", row_color)
		row.add_child(rank_lbl)

		var name_lbl := Label.new()
		name_lbl.text = entry.name
		name_lbl.custom_minimum_size = Vector2(160, 0)
		name_lbl.add_theme_font_size_override("font_size", row_font_size)
		name_lbl.add_theme_color_override("font_color", row_color)
		row.add_child(name_lbl)

		var score_val_lbl := Label.new()
		score_val_lbl.text = "%d" % entry.score
		score_val_lbl.custom_minimum_size = Vector2(80, 0)
		score_val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		score_val_lbl.add_theme_font_size_override("font_size", row_font_size)
		score_val_lbl.add_theme_color_override("font_color", row_color)
		row.add_child(score_val_lbl)

		var et := int(entry.time)
		var meta_lbl := Label.new()
		meta_lbl.text = "  Lv%d  %dk  %d:%02d" % [entry.level, entry.kills, et / 60, et % 60]
		meta_lbl.add_theme_font_size_override("font_size", 13)
		meta_lbl.add_theme_color_override("font_color", row_color.darkened(0.25))
		row.add_child(meta_lbl)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 12)
	vbox.add_child(spacer)

	var restart_btn := Button.new()
	restart_btn.text = "RISE AGAIN"
	restart_btn.custom_minimum_size = Vector2(240, 52)
	restart_btn.process_mode = Node.PROCESS_MODE_ALWAYS
	restart_btn.add_theme_font_size_override("font_size", 22)
	restart_btn.pressed.connect(func():
		get_tree().paused = false
		GameState.start_game()
		get_tree().reload_current_scene()
	)
	vbox.add_child(restart_btn)
	restart_btn.grab_focus()
