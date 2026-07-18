extends CanvasLayer

# In-game pause menu (Esc / controller Start): resume, options, restart,
# quit to menu. Replaces the old CRT-only OptionsScreen. Layer 210 sits above
# the UI layer (200) so it covers the HUD but stays below nothing.

const OPTIONS_PANEL := preload("res://ui/OptionsPanel.gd")

const HOVER_SOUND       := "res://assets/sfx/ui/hover.wav"
const SELECT_SOUND      := "res://assets/sfx/ui/select.wav"
const CANCEL_SOUND      := "res://assets/sfx/ui/cancel.wav"
const PAUSE_OPEN_SOUND  := "res://assets/sfx/ui/pause_open.wav"
const PAUSE_CLOSE_SOUND := "res://assets/sfx/ui/pause_close.wav"

var _showing_options: bool = false

func _ready() -> void:
	layer = 210
	process_mode = Node.PROCESS_MODE_ALWAYS
	hide()

func _process(_delta: float) -> void:
	if not Input.is_action_just_pressed("pause"):
		return
	# Never fight the level-up screen or the death screen for the pause state
	if GameState.has_pending_level_up() or not GameState.game_active:
		return
	if visible:
		_resume()
	else:
		_open()

func _open() -> void:
	Sfx.play(PAUSE_OPEN_SOUND, -4.0)
	get_tree().paused = true
	_showing_options = false
	_rebuild()
	show()

func _resume() -> void:
	Sfx.play(PAUSE_CLOSE_SOUND, -4.0)
	hide()
	if not GameState.has_pending_level_up():
		get_tree().paused = false

func _rebuild() -> void:
	for child in get_children():
		child.queue_free()

	var overlay := ColorRect.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0.0, 0.0, 0.0, 0.78)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(overlay)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(center)

	if _showing_options:
		var panel: VBoxContainer = VBoxContainer.new()
		panel.set_script(OPTIONS_PANEL)
		center.add_child(panel)
		panel.closed.connect(func():
			_showing_options = false
			_rebuild()
		)
		return

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 7)
	vbox.process_mode = Node.PROCESS_MODE_ALWAYS
	center.add_child(vbox)

	var title := Label.new()
	title.text = "PAUSED"
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color(1.0, 0.45, 0.0))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	var resume_btn := _make_button("RESUME", Color(1.0, 0.45, 0.0), "none")
	resume_btn.pressed.connect(_resume)
	vbox.add_child(resume_btn)

	var options_btn := _make_button("OPTIONS", Color(0.55, 0.80, 0.55))
	options_btn.pressed.connect(func():
		_showing_options = true
		_rebuild()
	)
	vbox.add_child(options_btn)

	var restart_btn := _make_button("RESTART", Color(1.0, 0.85, 0.1))
	restart_btn.pressed.connect(func():
		get_tree().paused = false
		GameState.start_game()
		get_tree().reload_current_scene()
	)
	vbox.add_child(restart_btn)

	var quit_btn := _make_button("QUIT TO MENU", Color(0.7, 0.55, 0.55), "cancel")
	quit_btn.pressed.connect(func():
		get_tree().paused = false
		get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")
	)
	vbox.add_child(quit_btn)

	resume_btn.grab_focus()

# sound: "select" (default confirm), "cancel" (softer, for leaving/quitting),
# or "none" (Resume plays its own PAUSE_CLOSE_SOUND from _resume() instead).
func _make_button(label: String, font_color: Color, sound: String = "select") -> Button:
	var btn := Button.new()
	btn.text = label
	btn.process_mode = Node.PROCESS_MODE_ALWAYS
	btn.custom_minimum_size = Vector2(160, 0)
	btn.add_theme_font_size_override("font_size", 9)
	btn.add_theme_color_override("font_color", font_color)
	var norm := StyleBoxFlat.new()
	norm.bg_color = Color(0.07, 0.03, 0.03)
	norm.border_color = Color(0.35, 0.12, 0.0)
	norm.set_border_width_all(1)
	norm.set_corner_radius_all(2)
	norm.content_margin_left = 12
	norm.content_margin_right = 12
	norm.content_margin_top = 5
	norm.content_margin_bottom = 5
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
