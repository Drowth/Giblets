extends CanvasLayer

signal open_requested
signal crt_changed(enabled: bool)
signal crt_enemies_changed(enabled: bool)
signal resumed

var _crt_enabled: bool        = true
var _crt_affects_enemies: bool = true

func _ready() -> void:
	layer        = 210
	process_mode = Node.PROCESS_MODE_ALWAYS
	hide()

func open(crt_on: bool, crt_enemies: bool) -> void:
	_crt_enabled         = crt_on
	_crt_affects_enemies = crt_enemies
	_rebuild()
	show()

func _process(_delta: float) -> void:
	if not Input.is_action_just_pressed("ui_cancel"):
		return
	if visible:
		_on_resume()
	else:
		open_requested.emit()

func _rebuild() -> void:
	for child in get_children():
		child.queue_free()

	# Dark overlay — blocks clicks on game world
	var overlay := ColorRect.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.color        = Color(0.0, 0.0, 0.0, 0.74)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(overlay)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(center)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	vbox.process_mode = Node.PROCESS_MODE_ALWAYS
	center.add_child(vbox)

	# Title
	var title := Label.new()
	title.text = "OPTIONS"
	title.add_theme_font_size_override("font_size", 32)
	title.add_theme_color_override("font_color", Color(1.0, 0.45, 0.0))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.process_mode = Node.PROCESS_MODE_ALWAYS
	vbox.add_child(title)

	_add_spacer(vbox, 8)

	# CRT effect toggle
	var crt_btn := _make_toggle("CRT Effect", _crt_enabled)
	crt_btn.pressed.connect(func():
		_crt_enabled = not _crt_enabled
		crt_changed.emit(_crt_enabled)
		_rebuild()
	)
	vbox.add_child(crt_btn)

	# CRT affects enemies toggle — greyed when CRT is off
	var enemies_btn := _make_toggle("CRT Affects Enemies", _crt_affects_enemies)
	if not _crt_enabled:
		enemies_btn.disabled  = true
		enemies_btn.modulate.a = 0.35
	enemies_btn.pressed.connect(func():
		_crt_affects_enemies = not _crt_affects_enemies
		crt_enemies_changed.emit(_crt_affects_enemies)
		_rebuild()
	)
	vbox.add_child(enemies_btn)

	_add_spacer(vbox, 8)

	# Resume
	var resume_btn := _make_button("RESUME  [ESC]", Color(1.0, 0.45, 0.0))
	resume_btn.pressed.connect(_on_resume)
	vbox.add_child(resume_btn)

func _on_resume() -> void:
	hide()
	resumed.emit()

func _add_spacer(parent: Control, height: int) -> void:
	var s := Control.new()
	s.custom_minimum_size = Vector2(0, height)
	parent.add_child(s)

func _make_toggle(label: String, state: bool) -> Button:
	var color := Color(0.25, 1.0, 0.25) if state else Color(0.6, 0.6, 0.6)
	return _make_button("%s:  %s" % [label, "ON" if state else "OFF"], color)

func _make_button(label: String, font_color: Color) -> Button:
	var btn := Button.new()
	btn.text         = label
	btn.process_mode = Node.PROCESS_MODE_ALWAYS
	btn.custom_minimum_size = Vector2(310, 0)
	btn.add_theme_font_size_override("font_size", 18)
	btn.add_theme_color_override("font_color", font_color)

	var norm := StyleBoxFlat.new()
	norm.bg_color     = Color(0.07, 0.03, 0.03)
	norm.border_color = Color(0.35, 0.12, 0.0)
	norm.set_border_width_all(2)
	norm.set_corner_radius_all(4)
	norm.content_margin_left   = 22
	norm.content_margin_right  = 22
	norm.content_margin_top    = 10
	norm.content_margin_bottom = 10
	btn.add_theme_stylebox_override("normal", norm)

	var hover := norm.duplicate() as StyleBoxFlat
	hover.bg_color     = Color(0.15, 0.06, 0.02)
	hover.border_color = Color(1.0, 0.45, 0.0)
	btn.add_theme_stylebox_override("hover", hover)

	var dis := norm.duplicate() as StyleBoxFlat
	dis.bg_color = Color(0.04, 0.04, 0.04)
	btn.add_theme_stylebox_override("disabled", dis)

	return btn
