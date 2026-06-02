extends Control

signal upgrade_chosen

func _ready() -> void:
	add_to_group("level_up_screen")
	process_mode = Node.PROCESS_MODE_ALWAYS
	hide()

func show_choices() -> void:
	for child in get_children():
		child.free()

	var overlay := ColorRect.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0, 0, 0, 0.82)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(overlay)

	_spawn_blood_effects()

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 24)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(vbox)

	var title := Label.new()
	title.text = "LEVEL UP!  (Level %d)" % GameState.player_level
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 40)
	title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.1))
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(title)

	var sub := Label.new()
	sub.text = "Choose your dark gift:"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 16)
	sub.add_theme_color_override("font_color", Color(0.75, 0.7, 0.75))
	sub.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(sub)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 20)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(row)

	var choices := UpgradeData.get_random_choices(3)
	for upgrade: Dictionary in choices:
		row.add_child(_make_card(upgrade))

func _make_card(upgrade: Dictionary) -> Button:
	var rarity: String = upgrade.get("rarity", "common")
	var rarity_color: Color = UpgradeData.RARITY_COLORS.get(rarity, Color.WHITE)

	var btn := Button.new()
	btn.custom_minimum_size = Vector2(210, 298)
	btn.process_mode = Node.PROCESS_MODE_ALWAYS

	var s_normal := StyleBoxFlat.new()
	s_normal.bg_color    = Color(0.08, 0.06, 0.11)
	s_normal.border_color = rarity_color
	s_normal.set_border_width_all(2)
	s_normal.set_corner_radius_all(4)
	btn.add_theme_stylebox_override("normal", s_normal)

	var s_hover := StyleBoxFlat.new()
	s_hover.bg_color     = Color(0.13, 0.10, 0.17)
	s_hover.border_color = rarity_color.lightened(0.25)
	s_hover.set_border_width_all(3)
	s_hover.set_corner_radius_all(4)
	btn.add_theme_stylebox_override("hover", s_hover)

	var s_pressed := StyleBoxFlat.new()
	s_pressed.bg_color     = Color(0.05, 0.04, 0.08)
	s_pressed.border_color = rarity_color.darkened(0.2)
	s_pressed.set_border_width_all(2)
	s_pressed.set_corner_radius_all(4)
	btn.add_theme_stylebox_override("pressed", s_pressed)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.offset_left = 6; vbox.offset_top = 6; vbox.offset_right = -6; vbox.offset_bottom = -6
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(vbox)

	var icon := ColorRect.new()
	icon.custom_minimum_size = Vector2(0, 105)
	icon.color = upgrade.get("color", Color.GRAY)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(icon)

	var name_lbl := Label.new()
	name_lbl.text = upgrade.get("name", "???")
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.add_theme_font_size_override("font_size", 16)
	name_lbl.add_theme_color_override("font_color", Color(0.95, 0.92, 0.88))
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(name_lbl)

	var desc_lbl := Label.new()
	desc_lbl.text = upgrade.get("description", "")
	desc_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_lbl.add_theme_font_size_override("font_size", 12)
	desc_lbl.add_theme_color_override("font_color", Color(0.75, 0.72, 0.70))
	desc_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(desc_lbl)

	var rarity_lbl := Label.new()
	rarity_lbl.text = rarity.to_upper()
	rarity_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rarity_lbl.add_theme_font_size_override("font_size", 12)
	rarity_lbl.add_theme_color_override("font_color", rarity_color)
	rarity_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(rarity_lbl)

	btn.pressed.connect(func(): _on_card_pressed(upgrade))
	return btn

# ---------------------------------------------------------------------------
func _spawn_blood_effects() -> void:
	var vp := get_viewport_rect().size
	# Central explosion
	_make_burst(vp * 0.5, 120, Vector2(0, -1), 180.0)
	# Left wall splatter
	_make_burst(Vector2(0.0, vp.y * 0.45), 60, Vector2(1, 0), 75.0)
	# Right wall splatter
	_make_burst(Vector2(vp.x, vp.y * 0.45), 60, Vector2(-1, 0), 75.0)
	# Continuous drip from the top
	_make_drip(vp)

func _make_burst(pos: Vector2, amount: int, dir: Vector2, spread: float) -> void:
	var p := CPUParticles2D.new()
	p.process_mode   = Node.PROCESS_MODE_ALWAYS
	p.z_index        = 5
	p.emitting        = true
	p.amount          = amount
	p.lifetime        = 2.0
	p.one_shot        = true
	p.explosiveness   = 0.92
	p.direction       = dir
	p.spread          = spread
	p.gravity         = Vector2(0.0, 280.0)
	p.initial_velocity_min = 120.0
	p.initial_velocity_max = 500.0
	p.scale_amount_min = 3.0
	p.scale_amount_max = 8.0
	p.color           = Color(0.72, 0.0, 0.02)
	p.position        = pos
	add_child(p)

func _make_drip(vp: Vector2) -> void:
	var p := CPUParticles2D.new()
	p.process_mode   = Node.PROCESS_MODE_ALWAYS
	p.z_index        = 5
	p.emitting        = true
	p.amount          = 18
	p.lifetime        = 5.0
	p.one_shot        = false
	p.direction       = Vector2(0.0, 1.0)
	p.spread          = 8.0
	p.gravity         = Vector2(0.0, 50.0)
	p.initial_velocity_min = 25.0
	p.initial_velocity_max = 90.0
	p.scale_amount_min = 2.0
	p.scale_amount_max = 5.0
	p.emission_shape  = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(vp.x * 0.5, 1.0)
	p.color           = Color(0.55, 0.0, 0.01)
	p.position        = Vector2(vp.x * 0.5, 0.0)
	add_child(p)

# ---------------------------------------------------------------------------
func _on_card_pressed(upgrade: Dictionary) -> void:
	UpgradeData.apply_upgrade(upgrade)
	upgrade_chosen.emit()
