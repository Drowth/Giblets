extends VBoxContainer

# Reusable options panel — embedded by both PauseScreen (in-game) and
# MainMenu. Every control reads/writes the Settings autoload and persists
# immediately; nothing here touches GameState.

signal closed

var _rebinding_action: String = ""
var _rebind_button: Button = null

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_theme_constant_override("separation", 4)
	_rebuild()

func _rebuild() -> void:
	for child in get_children():
		child.queue_free()

	var title := Label.new()
	title.text = "OPTIONS"
	title.add_theme_font_size_override("font_size", 13)
	title.add_theme_color_override("font_color", Color(1.0, 0.45, 0.0))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(title)

	_add_slider("Master", Settings.master_volume, func(v: float):
		Settings.master_volume = v
		Settings.apply_all()
		Settings.save_settings())
	_add_slider("Music", Settings.music_volume, func(v: float):
		Settings.music_volume = v
		Settings.apply_all()
		Settings.save_settings())
	_add_slider("SFX", Settings.sfx_volume, func(v: float):
		Settings.sfx_volume = v
		Settings.apply_all()
		Settings.save_settings())

	_add_toggle("CRT Effect", Settings.crt_enabled, func():
		Settings.crt_enabled = not Settings.crt_enabled
		Settings.apply_all()
		Settings.save_settings()
		_rebuild())
	if Settings.crt_enabled:
		_add_toggle("CRT On Enemies", Settings.crt_affects_enemies, func():
			Settings.crt_affects_enemies = not Settings.crt_affects_enemies
			Settings.apply_all()
			Settings.save_settings()
			_rebuild())
	_add_toggle("Screen Shake", Settings.screen_shake_enabled, func():
		Settings.screen_shake_enabled = not Settings.screen_shake_enabled
		Settings.apply_all()
		Settings.save_settings()
		_rebuild())
	_add_toggle("Fullscreen", Settings.fullscreen, func():
		Settings.fullscreen = not Settings.fullscreen
		Settings.apply_all()
		Settings.save_settings()
		_rebuild())

	var keys_lbl := Label.new()
	keys_lbl.text = "— KEYS —"
	keys_lbl.add_theme_font_size_override("font_size", 7)
	keys_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.1))
	keys_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(keys_lbl)

	for action in Settings.REBINDABLE_ACTIONS:
		_add_rebind_row(action)

	var back := _make_button("BACK", Color(1.0, 0.45, 0.0))
	back.pressed.connect(func(): closed.emit())
	add_child(back)
	back.grab_focus()

func _add_slider(label_text: String, value: float, on_change: Callable) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	row.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(row)
	var lbl := Label.new()
	lbl.text = label_text
	lbl.custom_minimum_size = Vector2(52, 0)
	lbl.add_theme_font_size_override("font_size", 7)
	lbl.add_theme_color_override("font_color", Color(0.85, 0.8, 0.8))
	row.add_child(lbl)
	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.05
	slider.value = value
	slider.custom_minimum_size = Vector2(90, 10)
	slider.process_mode = Node.PROCESS_MODE_ALWAYS
	slider.value_changed.connect(on_change)
	row.add_child(slider)

func _add_toggle(label_text: String, state: bool, on_press: Callable) -> void:
	var color := Color(0.25, 1.0, 0.25) if state else Color(0.6, 0.6, 0.6)
	var btn := _make_button("%s:  %s" % [label_text, "ON" if state else "OFF"], color)
	btn.pressed.connect(on_press)
	add_child(btn)

func _add_rebind_row(action: String) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	row.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(row)
	var lbl := Label.new()
	lbl.text = action.replace("_", " ")
	lbl.custom_minimum_size = Vector2(60, 0)
	lbl.add_theme_font_size_override("font_size", 7)
	lbl.add_theme_color_override("font_color", Color(0.75, 0.7, 0.75))
	row.add_child(lbl)
	var btn := _make_button(Settings.current_key_name(action), Color(0.9, 0.85, 0.6))
	btn.custom_minimum_size = Vector2(70, 0)
	btn.pressed.connect(func():
		_rebinding_action = action
		_rebind_button = btn
		btn.text = "press key..."
	)
	row.add_child(btn)

func _unhandled_key_input(event: InputEvent) -> void:
	if _rebinding_action == "":
		return
	var key := event as InputEventKey
	if not key or not key.pressed or key.echo:
		return
	get_viewport().set_input_as_handled()
	Settings.rebind(_rebinding_action, key.physical_keycode)
	if _rebind_button and is_instance_valid(_rebind_button):
		_rebind_button.text = Settings.current_key_name(_rebinding_action)
	_rebinding_action = ""
	_rebind_button = null

func _make_button(text: String, font_color: Color) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.process_mode = Node.PROCESS_MODE_ALWAYS
	btn.custom_minimum_size = Vector2(150, 0)
	btn.add_theme_font_size_override("font_size", 7)
	btn.add_theme_color_override("font_color", font_color)
	var norm := StyleBoxFlat.new()
	norm.bg_color = Color(0.07, 0.03, 0.03)
	norm.border_color = Color(0.35, 0.12, 0.0)
	norm.set_border_width_all(1)
	norm.set_corner_radius_all(2)
	norm.content_margin_left = 8
	norm.content_margin_right = 8
	norm.content_margin_top = 3
	norm.content_margin_bottom = 3
	btn.add_theme_stylebox_override("normal", norm)
	var hover := norm.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.15, 0.06, 0.02)
	hover.border_color = Color(1.0, 0.45, 0.0)
	btn.add_theme_stylebox_override("hover", hover)
	return btn
