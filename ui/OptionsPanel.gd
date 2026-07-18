extends VBoxContainer

# Reusable options panel — embedded by both PauseScreen (in-game) and
# MainMenu. Every control reads/writes the Settings autoload and persists
# immediately; nothing here touches GameState.

signal closed

const HOVER_SOUND      := "res://assets/sfx/ui/hover.wav"
const SELECT_SOUND     := "res://assets/sfx/ui/select.wav"
const CANCEL_SOUND     := "res://assets/sfx/ui/cancel.wav"
const TOGGLE_ON_SOUND  := "res://assets/sfx/ui/toggle_on.wav"
const TOGGLE_OFF_SOUND := "res://assets/sfx/ui/toggle_off.wav"

var _rebinding_action: String = ""
var _rebind_button: Button = null

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_theme_constant_override("separation", 4)
	_rebuild()

# Two columns (audio+display left, key rebinds right) — a single stack of
# every control is ~320 units tall and the viewport is only 216.
var _left_col: VBoxContainer = null
var _right_col: VBoxContainer = null

func _rebuild() -> void:
	for child in get_children():
		child.queue_free()

	var title := Label.new()
	title.text = "OPTIONS"
	title.add_theme_font_size_override("font_size", 13)
	title.add_theme_color_override("font_color", Color(1.0, 0.45, 0.0))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(title)

	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 14)
	columns.mouse_filter = Control.MOUSE_FILTER_IGNORE
	columns.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(columns)

	_left_col = VBoxContainer.new()
	_left_col.add_theme_constant_override("separation", 3)
	_left_col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_left_col.process_mode = Node.PROCESS_MODE_ALWAYS
	columns.add_child(_left_col)

	_right_col = VBoxContainer.new()
	_right_col.add_theme_constant_override("separation", 3)
	_right_col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_right_col.process_mode = Node.PROCESS_MODE_ALWAYS
	columns.add_child(_right_col)

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
	_add_toggle("Reduce Flash", Settings.reduce_flash, func():
		Settings.reduce_flash = not Settings.reduce_flash
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
	_right_col.add_child(keys_lbl)

	for action in Settings.REBINDABLE_ACTIONS:
		_add_rebind_row(action)

	var back := _make_button("BACK", Color(1.0, 0.45, 0.0), "cancel")
	back.pressed.connect(func(): closed.emit())
	var back_wrap := CenterContainer.new()
	back_wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	back_wrap.process_mode = Node.PROCESS_MODE_ALWAYS
	back_wrap.add_child(back)
	add_child(back_wrap)
	back.grab_focus()

func _add_slider(label_text: String, value: float, on_change: Callable) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	row.process_mode = Node.PROCESS_MODE_ALWAYS
	_left_col.add_child(row)
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
	var btn := _make_button("%s:  %s" % [label_text, "ON" if state else "OFF"], color, "none")
	btn.pressed.connect(func():
		Sfx.play(TOGGLE_OFF_SOUND if state else TOGGLE_ON_SOUND, -6.0)
		on_press.call()
	)
	_left_col.add_child(btn)

func _add_rebind_row(action: String) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	row.process_mode = Node.PROCESS_MODE_ALWAYS
	_right_col.add_child(row)
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
	Sfx.play(SELECT_SOUND, -5.0)
	if _rebind_button and is_instance_valid(_rebind_button):
		_rebind_button.text = Settings.current_key_name(_rebinding_action)
	_rebinding_action = ""
	_rebind_button = null

# sound: "select" (default confirm), "cancel" (softer, for BACK), or "none"
# (caller plays its own sound, e.g. toggles which need on/off variants).
func _make_button(text: String, font_color: Color, sound: String = "select") -> Button:
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
	# Gamepad/keyboard focus must be visible
	btn.add_theme_stylebox_override("focus", hover)

	btn.mouse_entered.connect(func():
		if not btn.disabled:
			Sfx.play(HOVER_SOUND, -9.0, 0.03)
	)
	if sound != "none":
		btn.pressed.connect(func():
			Sfx.play(CANCEL_SOUND if sound == "cancel" else SELECT_SOUND, -6.0)
		)

	return btn
