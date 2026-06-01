extends Control

signal upgrade_chosen

func _ready() -> void:
	add_to_group("level_up_screen")
	process_mode = Node.PROCESS_MODE_ALWAYS
	hide()

func show_choices() -> void:
	# Wipe any previous UI
	for child in get_children():
		child.free()

	# Dark overlay
	var overlay := ColorRect.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0, 0, 0, 0.82)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(overlay)

	# Center wrapper
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
		var card := _make_card(upgrade)
		row.add_child(card)

func _make_card(upgrade: Dictionary) -> Button:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(210, 290)
	btn.process_mode = Node.PROCESS_MODE_ALWAYS

	var vbox := VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
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
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(name_lbl)

	var desc_lbl := Label.new()
	desc_lbl.text = upgrade.get("description", "")
	desc_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_lbl.add_theme_font_size_override("font_size", 12)
	desc_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(desc_lbl)

	var rarity_lbl := Label.new()
	var rarity: String = upgrade.get("rarity", "common")
	rarity_lbl.text = "[%s]" % rarity.to_upper()
	rarity_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rarity_lbl.add_theme_font_size_override("font_size", 12)
	var rarity_colors := {
		"common": Color(0.65, 0.65, 0.65),
		"uncommon": Color(0.3, 0.9, 0.3),
		"rare": Color(0.5, 0.5, 1.0)
	}
	rarity_lbl.add_theme_color_override("font_color", rarity_colors.get(rarity, Color.WHITE))
	rarity_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(rarity_lbl)

	btn.pressed.connect(func(): _on_card_pressed(upgrade))
	return btn

func _on_card_pressed(upgrade: Dictionary) -> void:
	UpgradeData.apply_upgrade(upgrade)
	upgrade_chosen.emit()
