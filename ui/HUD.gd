extends Control

const HOVER_SOUND         := "res://assets/sfx/ui/hover.wav"
const SELECT_SOUND        := "res://assets/sfx/ui/select.wav"
const CANCEL_SOUND        := "res://assets/sfx/ui/cancel.wav"
const COMBO_POP_SOUND     := "res://assets/sfx/game/combo_pop.wav"
const COIN_SOUND          := "res://assets/sfx/game/coin.wav"
const GAME_OVER_SOUND     := "res://assets/sfx/game/game_over.wav"
const NEW_HIGH_SCORE_SOUND := "res://assets/sfx/game/new_high_score.wav"

@onready var health_bar:  ProgressBar = $TopBar/MarginContainer/HBox/HealthBarContainer/HealthBar
@onready var health_text: Label       = $TopBar/MarginContainer/HBox/HealthBarContainer/HealthText
@onready var xp_bar:      ProgressBar = $TopBar/MarginContainer/HBox/XPBarContainer/XPBar
@onready var xp_text:     Label       = $TopBar/MarginContainer/HBox/XPBarContainer/XPText
@onready var level_label: Label       = $TopBar/MarginContainer/HBox/LevelLabel
@onready var score_label: Label       = $TopBar/MarginContainer/HBox/ScoreLabel
@onready var timer_label: Label       = $TopBar/MarginContainer/HBox/TimerLabel

var _combo_label: Label = null

func _ready() -> void:
	GameState.health_changed.connect(_on_health_changed)
	GameState.xp_changed.connect(_on_xp_changed)
	GameState.level_changed.connect(_on_level_changed)
	GameState.score_changed.connect(_on_score_changed)
	GameState.combo_changed.connect(_on_combo_changed)
	_setup_combo_label()
	_refresh()

func _setup_combo_label() -> void:
	_combo_label = Label.new()
	_combo_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_combo_label.offset_top = 22
	_combo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_combo_label.add_theme_font_size_override("font_size", 9)
	_combo_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.1))
	_combo_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_combo_label.visible = false
	add_child(_combo_label)

const COMBO_SHOW_THRESHOLD := 5

func _on_combo_changed(combo: int) -> void:
	if combo < COMBO_SHOW_THRESHOLD:
		_combo_label.visible = false
		return
	_combo_label.visible = true
	_combo_label.text = "COMBO x%d" % combo
	# Pitch climbs with combo count (capped) so a long chain audibly escalates
	Sfx.play_pitched(COMBO_POP_SOUND, -7.0, clampf(1.0 + combo * 0.02, 1.0, 1.6))
	# Punch scale on each step
	_combo_label.scale = Vector2(1.3, 1.3)
	_combo_label.pivot_offset = _combo_label.size / 2.0
	var tw := _combo_label.create_tween()
	tw.tween_property(_combo_label, "scale", Vector2.ONE, 0.15)

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
	Sfx.play(GAME_OVER_SOUND, -3.0)
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
	vbox.add_theme_constant_override("separation", 3)
	vbox.custom_minimum_size = Vector2(160, 0)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(vbox)
	_death_vbox = vbox
	_death_transients.clear()

	var title := Label.new()
	title.text = "YOU DIED"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Color(0.88, 0.04, 0.04))
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(title)
	_death_title = title

	var score_lbl := Label.new()
	score_lbl.text = "SCORE  %d" % GameState.score
	score_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	score_lbl.add_theme_font_size_override("font_size", 12)
	score_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.1))
	score_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(score_lbl)
	_death_score = score_lbl

	var t := int(GameState.elapsed_time)
	var dps := GameState.damage_dealt / maxf(GameState.elapsed_time, 1.0)
	var earned := Meta.earn_from_run(GameState.score, GameState.bosses_killed, GameState.elapsed_time / 60.0)
	var stats_lbl := Label.new()
	stats_lbl.text = "Level %d  •  %d kills  •  %d:%02d survived  •  %.0f DPS" % [
		GameState.player_level, GameState.enemies_killed, t / 60, t % 60, dps
	]
	stats_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats_lbl.add_theme_font_size_override("font_size", 6)
	stats_lbl.add_theme_color_override("font_color", Color(0.7, 0.65, 0.7))
	stats_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(stats_lbl)
	_death_transients.append(stats_lbl)

	var breakdown_lbl := Label.new()
	breakdown_lbl.text = "+%d score  +%d bosses  +%d survival" % [
		earned["score_part"], earned["boss_part"], earned["time_part"]
	]
	breakdown_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	breakdown_lbl.add_theme_font_size_override("font_size", 5)
	breakdown_lbl.add_theme_color_override("font_color", Color(0.65, 0.45, 0.35))
	breakdown_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(breakdown_lbl)
	_death_transients.append(breakdown_lbl)

	var giblets_lbl := Label.new()
	giblets_lbl.text = "+%d GIBLETS  (%d total)" % [earned["total"], Meta.giblets]
	giblets_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	giblets_lbl.add_theme_font_size_override("font_size", 7)
	giblets_lbl.add_theme_color_override("font_color", Color(0.95, 0.35, 0.30))
	giblets_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(giblets_lbl)
	_death_giblets = giblets_lbl
	if int(earned["total"]) > 0:
		Sfx.play(COIN_SOUND, -6.0)

	_build_roulette(vbox)

	var sep := HSeparator.new()
	vbox.add_child(sep)
	_death_transients.append(sep)

	_build_name_entry(vbox)

# The 216-unit viewport can't fit the run summary AND the leaderboard at once.
# Once the name is submitted, drop the transient rows (stats, giblet breakdown,
# roulette, separator) and shrink the header so the leaderboard + buttons fit.
var _death_vbox: VBoxContainer = null
var _death_transients: Array[Node] = []
var _death_title: Label = null
var _death_score: Label = null
var _death_giblets: Label = null

func _compact_death_header() -> void:
	for node in _death_transients:
		if is_instance_valid(node):
			node.queue_free()
	_death_transients.clear()
	if is_instance_valid(_death_title):
		_death_title.add_theme_font_size_override("font_size", 12)
	if is_instance_valid(_death_score):
		_death_score.add_theme_font_size_override("font_size", 9)
	if is_instance_valid(_death_giblets):
		_death_giblets.queue_free()
	if is_instance_valid(_death_vbox):
		_death_vbox.add_theme_constant_override("separation", 2)

# End-of-run upgrade roulette (docs/BALANCE.md §6): milestone-gated slot that
# unlocks one locked upgrade into the permanent level-up rotation.
const ROULETTE_TICKS := 14
func _build_roulette(vbox: VBoxContainer) -> void:
	var pool: Array = Meta.locked_upgrade_pool()
	if pool.is_empty():
		return
	if not Meta.run_earned_spin():
		var hint := Label.new()
		hint.text = "survive 5:00 or slay a boss to spin for a new upgrade"
		hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		hint.add_theme_font_size_override("font_size", 5)
		hint.add_theme_color_override("font_color", Color(0.45, 0.4, 0.45))
		hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vbox.add_child(hint)
		_death_transients.append(hint)
		return

	var won: Dictionary = Meta.roll_unlock()
	if won.is_empty():
		return

	var banner := Label.new()
	banner.text = "NEW UPGRADE IN ROTATION"
	banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner.add_theme_font_size_override("font_size", 6)
	banner.add_theme_color_override("font_color", Color(0.75, 0.45, 0.95))
	banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(banner)
	_death_transients.append(banner)

	var card := _make_roulette_card(won)
	vbox.add_child(card["root"])
	_death_transients.append(card["root"])
	_animate_roulette(card, pool, won)

# A non-interactive upgrade card for the roulette result. The wheel flickers
# through names in the title slot; when it lands, the rarity + description are
# revealed inside the card so the player can read what the new upgrade does.
func _make_roulette_card(won: Dictionary) -> Dictionary:
	var rarity: String = won.get("rarity", "common")
	var rarity_color: Color = UpgradeData.RARITY_COLORS.get(rarity, Color.WHITE)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(150, 0)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.process_mode = Node.PROCESS_MODE_ALWAYS

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.06, 0.11)
	style.border_color = rarity_color
	style.set_border_width_all(1)
	style.set_corner_radius_all(1)
	style.content_margin_left = 4
	style.content_margin_right = 4
	style.content_margin_top = 3
	style.content_margin_bottom = 3
	panel.add_theme_stylebox_override("panel", style)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 1)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(col)

	var name_lbl := Label.new()
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.add_theme_font_size_override("font_size", 8)
	name_lbl.custom_minimum_size = Vector2(140, 12)
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(name_lbl)

	var rarity_lbl := Label.new()
	rarity_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rarity_lbl.add_theme_font_size_override("font_size", 5)
	rarity_lbl.add_theme_color_override("font_color", rarity_color)
	rarity_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rarity_lbl.visible = false
	col.add_child(rarity_lbl)

	var desc_lbl := Label.new()
	desc_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_lbl.add_theme_font_size_override("font_size", 5)
	desc_lbl.add_theme_color_override("font_color", Color(0.78, 0.75, 0.73))
	desc_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	desc_lbl.visible = false
	col.add_child(desc_lbl)

	return {"root": panel, "name": name_lbl, "rarity": rarity_lbl, "desc": desc_lbl}

func _animate_roulette(card: Dictionary, pool: Array, won: Dictionary) -> void:
	var slot: Label = card["name"]
	var won_color: Color = UpgradeData.RARITY_COLORS.get(won["rarity"], Color.WHITE)
	for i in ROULETTE_TICKS:
		var face: Dictionary = pool.pick_random()
		slot.text = str(face["name"]).to_upper()
		slot.add_theme_color_override("font_color", UpgradeData.RARITY_COLORS.get(face["rarity"], Color.WHITE))
		Sfx.play_random([
			"res://assets/sfx/cards/card_draw_1.wav",
			"res://assets/sfx/cards/card_draw_2.wav",
			"res://assets/sfx/cards/card_draw_3.wav",
		], -14.0, 0.1)
		# Decelerating ticks: fast flicker into a landing.
		await get_tree().create_timer(0.06 + 0.16 * pow(float(i) / ROULETTE_TICKS, 2.0)).timeout
		if not is_instance_valid(slot):
			return
	slot.text = "★ %s ★" % str(won["name"]).to_upper()
	slot.add_theme_color_override("font_color", won_color)
	_reveal_card_details(card, won)
	if won["rarity"] in ["epic", "legendary"]:
		Sfx.play(NEW_HIGH_SCORE_SOUND, -4.0)
	else:
		Sfx.play(COIN_SOUND, -6.0)

# Fade in the rarity tag + description once the wheel has settled on a winner.
func _reveal_card_details(card: Dictionary, won: Dictionary) -> void:
	var rarity_lbl: Label = card["rarity"]
	var desc_lbl: Label = card["desc"]
	if not is_instance_valid(rarity_lbl) or not is_instance_valid(desc_lbl):
		return
	rarity_lbl.text = str(won.get("rarity", "common")).to_upper()
	desc_lbl.text = str(won.get("description", ""))
	rarity_lbl.modulate.a = 0.0
	desc_lbl.modulate.a = 0.0
	rarity_lbl.visible = true
	desc_lbl.visible = true
	var tw := desc_lbl.create_tween()
	tw.tween_property(rarity_lbl, "modulate:a", 1.0, 0.25)
	tw.parallel().tween_property(desc_lbl, "modulate:a", 1.0, 0.35)

func _build_name_entry(vbox: VBoxContainer) -> void:
	var name_section := VBoxContainer.new()
	name_section.add_theme_constant_override("separation", 3)
	name_section.process_mode = Node.PROCESS_MODE_ALWAYS
	vbox.add_child(name_section)

	var prompt_lbl := Label.new()
	prompt_lbl.text = "ENTER YOUR NAME"
	prompt_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt_lbl.add_theme_font_size_override("font_size", 8)
	prompt_lbl.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
	name_section.add_child(prompt_lbl)

	var input_row := HBoxContainer.new()
	input_row.alignment = BoxContainer.ALIGNMENT_CENTER
	input_row.add_theme_constant_override("separation", 3)
	input_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_section.add_child(input_row)

	var name_input := LineEdit.new()
	name_input.placeholder_text = "PLAYER"
	name_input.max_length = 12
	name_input.custom_minimum_size = Vector2(72, 14)
	name_input.alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_input.process_mode = Node.PROCESS_MODE_ALWAYS
	var input_style := StyleBoxFlat.new()
	input_style.bg_color = Color(0.07, 0.03, 0.03)
	input_style.border_color = Color(1.0, 0.85, 0.1)
	input_style.set_border_width_all(1)
	input_style.set_corner_radius_all(1)
	name_input.add_theme_stylebox_override("normal", input_style)
	name_input.add_theme_stylebox_override("focus", input_style)
	name_input.add_theme_color_override("font_color", Color(1.0, 0.85, 0.1))
	name_input.add_theme_color_override("font_placeholder_color", Color(0.5, 0.42, 0.1))
	name_input.add_theme_font_size_override("font_size", 8)
	input_row.add_child(name_input)

	var confirm_btn := Button.new()
	confirm_btn.text = "OK"
	confirm_btn.custom_minimum_size = Vector2(20, 14)
	confirm_btn.process_mode = Node.PROCESS_MODE_ALWAYS
	confirm_btn.add_theme_font_size_override("font_size", 7)
	confirm_btn.mouse_entered.connect(func(): Sfx.play(HOVER_SOUND, -9.0, 0.03))
	input_row.add_child(confirm_btn)

	var submitted := false
	var submit := func():
		if submitted:
			return
		submitted = true
		Sfx.play(SELECT_SOUND, -5.0)
		var raw := name_input.text.strip_edges()
		if raw.is_empty():
			raw = "UNKNOWN"
		name_section.hide()
		name_section.queue_free()
		_compact_death_header()
		var rank := HighScores.add_score(
			raw, GameState.score, GameState.player_level,
			GameState.enemies_killed, GameState.elapsed_time
		)
		_build_leaderboard(vbox, rank)

	confirm_btn.pressed.connect(submit)
	name_input.text_submitted.connect(func(_t): submit.call())
	name_input.grab_focus()

func _build_leaderboard(vbox: VBoxContainer, current_rank: int) -> void:
	if current_rank == 1:
		Sfx.play(NEW_HIGH_SCORE_SOUND, -3.0)
		var crown := Label.new()
		crown.text = "★ NEW BEST RUN ★"
		crown.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		crown.add_theme_font_size_override("font_size", 8)
		crown.add_theme_color_override("font_color", Color(1.0, 0.84, 0.0))
		vbox.add_child(crown)
	elif current_rank > 0:
		var rank_note := Label.new()
		rank_note.text = "HIGH SCORE — RANK %d" % current_rank
		rank_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		rank_note.add_theme_font_size_override("font_size", 8)
		rank_note.add_theme_color_override("font_color", Color(1.0, 0.92, 0.2))
		vbox.add_child(rank_note)
	var header := Label.new()
	header.text = "— HIGH SCORES —"
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.add_theme_font_size_override("font_size", 7)
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

		var row_font_size := 7 if is_current else 6

		var row_wrap := CenterContainer.new()
		row_wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vbox.add_child(row_wrap)

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 4)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row_wrap.add_child(row)

		var prefix_lbl := Label.new()
		prefix_lbl.text = ">" if is_current else " "
		prefix_lbl.custom_minimum_size = Vector2(5, 0)
		prefix_lbl.add_theme_font_size_override("font_size", row_font_size)
		prefix_lbl.add_theme_color_override("font_color", row_color)
		row.add_child(prefix_lbl)

		var rank_lbl := Label.new()
		rank_lbl.text = "%d." % (i + 1)
		rank_lbl.custom_minimum_size = Vector2(8, 0)
		rank_lbl.add_theme_font_size_override("font_size", row_font_size)
		rank_lbl.add_theme_color_override("font_color", row_color)
		row.add_child(rank_lbl)

		var name_lbl := Label.new()
		name_lbl.text = entry.name
		name_lbl.custom_minimum_size = Vector2(52, 0)
		name_lbl.add_theme_font_size_override("font_size", row_font_size)
		name_lbl.add_theme_color_override("font_color", row_color)
		row.add_child(name_lbl)

		var score_val_lbl := Label.new()
		score_val_lbl.text = "%d" % entry.score
		score_val_lbl.custom_minimum_size = Vector2(26, 0)
		score_val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		score_val_lbl.add_theme_font_size_override("font_size", row_font_size)
		score_val_lbl.add_theme_color_override("font_color", row_color)
		row.add_child(score_val_lbl)

		var et := int(entry.time)
		var meta_lbl := Label.new()
		meta_lbl.text = "  Lv%d  %dk  %d:%02d" % [entry.level, entry.kills, et / 60, et % 60]
		meta_lbl.add_theme_font_size_override("font_size", 5)
		meta_lbl.add_theme_color_override("font_color", row_color.darkened(0.25))
		row.add_child(meta_lbl)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 2)
	vbox.add_child(spacer)

	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", 6)
	btn_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(btn_row)

	var restart_btn := Button.new()
	restart_btn.text = "RISE AGAIN"
	restart_btn.custom_minimum_size = Vector2(72, 17)
	restart_btn.process_mode = Node.PROCESS_MODE_ALWAYS
	restart_btn.add_theme_font_size_override("font_size", 8)
	restart_btn.mouse_entered.connect(func(): Sfx.play(HOVER_SOUND, -9.0, 0.03))
	restart_btn.pressed.connect(func():
		Sfx.play(SELECT_SOUND, -5.0)
		get_tree().paused = false
		GameState.start_game()
		get_tree().reload_current_scene()
	)
	btn_row.add_child(restart_btn)

	var menu_btn := Button.new()
	menu_btn.text = "MAIN MENU"
	menu_btn.custom_minimum_size = Vector2(72, 17)
	menu_btn.process_mode = Node.PROCESS_MODE_ALWAYS
	menu_btn.add_theme_font_size_override("font_size", 8)
	menu_btn.mouse_entered.connect(func(): Sfx.play(HOVER_SOUND, -9.0, 0.03))
	menu_btn.pressed.connect(func():
		Sfx.play(CANCEL_SOUND, -6.0)
		get_tree().paused = false
		get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")
	)
	btn_row.add_child(menu_btn)

	restart_btn.grab_focus()
