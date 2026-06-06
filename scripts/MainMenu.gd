extends Control

var _panel: Control = null
var _credits_tween: Tween = null
var _crt_rect: ColorRect = null
var _ui_layer: CanvasLayer = null

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_setup_background()
	_setup_crt()
	_ui_layer = CanvasLayer.new()
	_ui_layer.layer = 200
	add_child(_ui_layer)
	_show_main()

func _setup_background() -> void:
	var bg := ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.04, 0.02, 0.02)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

func _setup_crt() -> void:
	var crt_layer := CanvasLayer.new()
	crt_layer.layer = 128
	_crt_rect = ColorRect.new()
	_crt_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_crt_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_crt_rect.visible = GameState.crt_enabled
	var shader = load("res://shaders/crt_effect.gdshader")
	if shader:
		var mat := ShaderMaterial.new()
		mat.shader = shader
		_crt_rect.material = mat
	crt_layer.add_child(_crt_rect)
	add_child(crt_layer)

func _clear_panel() -> void:
	if _credits_tween != null and _credits_tween.is_valid():
		_credits_tween.kill()
	_credits_tween = null
	if _panel and is_instance_valid(_panel):
		_panel.queue_free()
	_panel = null

func _show_main() -> void:
	_clear_panel()

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel = center
	_ui_layer.add_child(center)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 7)
	center.add_child(vbox)

	var title := Label.new()
	title.text = "GIBLETS"
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Color(0.88, 0.06, 0.06))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	var sub := Label.new()
	sub.text = "survive the horde"
	sub.add_theme_font_size_override("font_size", 6)
	sub.add_theme_color_override("font_color", Color(0.50, 0.38, 0.38))
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(sub)

	_add_spacer(vbox, 6)

	var start_btn := _make_button("START GAME", Color(1.0, 0.45, 0.0))
	start_btn.pressed.connect(func():
		get_tree().change_scene_to_file("res://scenes/Main.tscn")
	)
	vbox.add_child(start_btn)

	var scores_btn := _make_button("HIGH SCORES", Color(1.0, 0.85, 0.1))
	scores_btn.pressed.connect(_show_high_scores)
	vbox.add_child(scores_btn)

	var options_btn := _make_button("OPTIONS", Color(0.55, 0.80, 0.55))
	options_btn.pressed.connect(_show_options)
	vbox.add_child(options_btn)

	var credits_btn := _make_button("CREDITS", Color(0.55, 0.50, 0.60))
	credits_btn.pressed.connect(_show_credits)
	vbox.add_child(credits_btn)

	start_btn.grab_focus()

func _show_options() -> void:
	_clear_panel()

	var overlay := ColorRect.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0.0, 0.0, 0.0, 0.80)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_panel = overlay
	_ui_layer.add_child(overlay)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(center)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 9)
	center.add_child(vbox)

	var title := Label.new()
	title.text = "OPTIONS"
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", Color(1.0, 0.45, 0.0))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	_add_spacer(vbox, 2)

	var crt_btn := _make_toggle("CRT Effect", GameState.crt_enabled)
	crt_btn.pressed.connect(func():
		GameState.crt_enabled = not GameState.crt_enabled
		if _crt_rect:
			_crt_rect.visible = GameState.crt_enabled
		_show_options()
	)
	vbox.add_child(crt_btn)

	var enemies_btn := _make_toggle("CRT Enemies", GameState.crt_affects_enemies)
	if not GameState.crt_enabled:
		enemies_btn.disabled  = true
		enemies_btn.modulate.a = 0.35
	enemies_btn.pressed.connect(func():
		GameState.crt_affects_enemies = not GameState.crt_affects_enemies
		_show_options()
	)
	vbox.add_child(enemies_btn)

	_add_spacer(vbox, 2)

	var back_btn := _make_button("BACK", Color(1.0, 0.45, 0.0))
	back_btn.pressed.connect(_show_main)
	vbox.add_child(back_btn)
	back_btn.grab_focus()

func _show_high_scores() -> void:
	_clear_panel()

	var overlay := ColorRect.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0.0, 0.0, 0.0, 0.92)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_panel = overlay
	_ui_layer.add_child(overlay)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(center)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	vbox.custom_minimum_size = Vector2(240, 0)
	center.add_child(vbox)

	var title := Label.new()
	title.text = "— HIGH SCORES —"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 12)
	title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.1))
	vbox.add_child(title)

	_add_spacer(vbox, 4)

	var scores := HighScores.get_scores()
	if scores.is_empty():
		var empty := Label.new()
		empty.text = "No scores yet.\nSurvive to earn your place."
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty.add_theme_font_size_override("font_size", 7)
		empty.add_theme_color_override("font_color", Color(0.55, 0.5, 0.55))
		vbox.add_child(empty)
	else:
		for i in scores.size():
			var entry: Dictionary = scores[i]
			var row_color: Color
			if i == 0:
				row_color = Color(1.0, 0.84, 0.0)
			elif i == 1:
				row_color = Color(0.75, 0.75, 0.78)
			elif i == 2:
				row_color = Color(0.80, 0.50, 0.20)
			else:
				row_color = Color(0.62, 0.58, 0.65)

			var row_wrap := CenterContainer.new()
			row_wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
			vbox.add_child(row_wrap)

			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 4)
			row.mouse_filter = Control.MOUSE_FILTER_IGNORE
			row_wrap.add_child(row)

			var rank_lbl := Label.new()
			rank_lbl.text = "%d." % (i + 1)
			rank_lbl.custom_minimum_size = Vector2(12, 0)
			rank_lbl.add_theme_font_size_override("font_size", 8)
			rank_lbl.add_theme_color_override("font_color", row_color)
			row.add_child(rank_lbl)

			var name_lbl := Label.new()
			name_lbl.text = entry.name
			name_lbl.custom_minimum_size = Vector2(68, 0)
			name_lbl.add_theme_font_size_override("font_size", 8)
			name_lbl.add_theme_color_override("font_color", row_color)
			row.add_child(name_lbl)

			var score_lbl := Label.new()
			score_lbl.text = "%d" % entry.score
			score_lbl.custom_minimum_size = Vector2(36, 0)
			score_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			score_lbl.add_theme_font_size_override("font_size", 8)
			score_lbl.add_theme_color_override("font_color", row_color)
			row.add_child(score_lbl)

			var et := int(entry.time)
			var meta_lbl := Label.new()
			meta_lbl.text = "  Lv%d %dk %d:%02d" % [entry.level, entry.kills, et / 60, et % 60]
			meta_lbl.add_theme_font_size_override("font_size", 5)
			meta_lbl.add_theme_color_override("font_color", row_color.darkened(0.3))
			row.add_child(meta_lbl)

	_add_spacer(vbox, 4)

	var back_btn := _make_button("BACK", Color(0.7, 0.7, 0.7))
	back_btn.pressed.connect(_show_main)
	vbox.add_child(back_btn)
	back_btn.grab_focus()

func _show_credits() -> void:
	_clear_panel()

	var bg := ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.0, 0.0, 0.0, 0.95)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	_panel = bg
	_ui_layer.add_child(bg)

	# Clip area leaves room for the BACK button at the bottom
	var clip := Control.new()
	clip.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	clip.offset_bottom = -26
	clip.clip_contents = true
	clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.add_child(clip)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 2)
	clip.add_child(vbox)

	# Each entry: [text, font_size, color]
	var lines: Array = [
		["", 10, Color(0, 0, 0, 0)],
		["", 10, Color(0, 0, 0, 0)],
		["GIBLETS", 20, Color(0.88, 0.06, 0.06)],
		["", 4, Color(0, 0, 0, 0)],
		["A gothic horror survival game", 7, Color(0.60, 0.55, 0.60)],
		["", 12, Color(0, 0, 0, 0)],
		["— CREATED BY —", 8, Color(1.0, 0.85, 0.1)],
		["", 4, Color(0, 0, 0, 0)],
		["Lee Grieve", 14, Color(1.0, 0.45, 0.0)],
		["", 12, Color(0, 0, 0, 0)],
		["— BUILT WITH —", 8, Color(1.0, 0.85, 0.1)],
		["", 4, Color(0, 0, 0, 0)],
		["Godot Engine 4.6", 8, Color(0.65, 0.65, 0.70)],
		["", 12, Color(0, 0, 0, 0)],
		["Thank you for playing.", 7, Color(0.50, 0.45, 0.50)],
		["", 16, Color(0, 0, 0, 0)],
		["", 16, Color(0, 0, 0, 0)],
	]

	for line in lines:
		var lbl := Label.new()
		lbl.text = line[0]
		lbl.add_theme_font_size_override("font_size", line[1])
		lbl.add_theme_color_override("font_color", line[2])
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.custom_minimum_size = Vector2(384, 0)
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vbox.add_child(lbl)

	var vp_h := get_viewport_rect().size.y
	vbox.position = Vector2(0, vp_h)

	await get_tree().process_frame

	var content_h := vbox.size.y
	var duration := (vp_h + content_h) / 28.0

	_credits_tween = clip.create_tween()
	_credits_tween.tween_property(vbox, "position:y", -content_h, duration)
	_credits_tween.tween_callback(_show_main)

	var back_center := CenterContainer.new()
	back_center.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	back_center.offset_top = -26
	back_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.add_child(back_center)

	var back_btn := _make_button("BACK", Color(0.7, 0.7, 0.7))
	back_btn.pressed.connect(func():
		_show_main()
	)
	back_center.add_child(back_btn)
	back_btn.grab_focus()

func _add_spacer(parent: Control, height: int) -> void:
	var s := Control.new()
	s.custom_minimum_size = Vector2(0, height)
	parent.add_child(s)

func _make_toggle(label: String, state: bool) -> Button:
	var color := Color(0.25, 1.0, 0.25) if state else Color(0.6, 0.6, 0.6)
	return _make_button("%s:  %s" % [label, "ON" if state else "OFF"], color)

func _make_button(text: String, font_color: Color) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(180, 0)
	btn.add_theme_font_size_override("font_size", 10)
	btn.add_theme_color_override("font_color", font_color)

	var norm := StyleBoxFlat.new()
	norm.bg_color = Color(0.07, 0.03, 0.03)
	norm.border_color = Color(0.35, 0.12, 0.0)
	norm.set_border_width_all(2)
	norm.set_corner_radius_all(4)
	norm.content_margin_left = 16
	norm.content_margin_right = 16
	norm.content_margin_top = 6
	norm.content_margin_bottom = 6
	btn.add_theme_stylebox_override("normal", norm)

	var hover := norm.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.15, 0.06, 0.02)
	hover.border_color = Color(1.0, 0.45, 0.0)
	btn.add_theme_stylebox_override("hover", hover)

	return btn
