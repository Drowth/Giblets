extends Control

signal upgrade_chosen

const CARD_DRAW_SOUNDS := [
	"res://assets/sfx/cards/card_draw_1.wav",
	"res://assets/sfx/cards/card_draw_2.wav",
	"res://assets/sfx/cards/card_draw_3.wav",
]
const CARD_FAN_SOUND := "res://assets/sfx/cards/card_fan.wav"
const SELECT_SOUND := "res://assets/sfx/ui/select.wav"
const SELECT_BIG_SOUND := "res://assets/sfx/ui/select_big.wav"
const HOVER_SOUND := "res://assets/sfx/ui/hover.wav"

const CARD_STAGGER := 0.12   # seconds between each card's draw
const CARD_SLIDE_DURATION := 0.32
const CARD_DROP_OFFSET := 130.0  # px below resting position cards start from

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

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(vbox)

	var title := Label.new()
	title.text = "LEVEL UP!  (Level %d)" % GameState.player_level
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 13)
	title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.1))
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(title)

	var sub := Label.new()
	sub.text = "Choose your dark gift:"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 6)
	sub.add_theme_color_override("font_color", Color(0.75, 0.7, 0.75))
	sub.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(sub)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 7)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(row)

	Sfx.play(CARD_FAN_SOUND, -6.0)

	var choices := UpgradeData.get_random_choices(3)
	var cards: Array[Button] = []
	for upgrade: Dictionary in choices:
		var card := _make_card(upgrade)
		card.disabled = true
		card.modulate.a = 0.0
		row.add_child(card)
		cards.append(card)

	# HBoxContainer only assigns real positions on the next sort pass, which
	# is deferred — read card.position before that and it's still (0,0), so
	# wait a frame before capturing each card's resting spot to slide from.
	await get_tree().process_frame
	for i in cards.size():
		_animate_card_draw(cards[i], i)

func _animate_card_draw(card: Button, index: int) -> void:
	# Cards start disabled and transparent (set in show_choices); each one
	# drops in from below on its own delay with a card_draw sting so the
	# hand reads as being dealt rather than just appearing.
	var rest_pos := card.position
	card.position.y += CARD_DROP_OFFSET

	var delay := index * CARD_STAGGER
	var tw := card.create_tween()
	tw.tween_interval(delay)
	tw.tween_callback(func(): Sfx.play_random(CARD_DRAW_SOUNDS, -4.0, 0.06))
	tw.tween_property(card, "position:y", rest_pos.y, CARD_SLIDE_DURATION) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(card, "modulate:a", 1.0, CARD_SLIDE_DURATION * 0.7)
	tw.tween_callback(func(): card.disabled = false)

func _make_card(upgrade: Dictionary) -> Button:
	var rarity: String = upgrade.get("rarity", "common")
	var rarity_color: Color = UpgradeData.RARITY_COLORS.get(rarity, Color.WHITE)

	var btn := Button.new()
	btn.custom_minimum_size = Vector2(70, 99)
	btn.process_mode = Node.PROCESS_MODE_ALWAYS

	var s_normal := StyleBoxFlat.new()
	s_normal.bg_color    = Color(0.08, 0.06, 0.11)
	s_normal.border_color = rarity_color
	s_normal.set_border_width_all(1)
	s_normal.set_corner_radius_all(1)
	btn.add_theme_stylebox_override("normal", s_normal)

	var s_hover := StyleBoxFlat.new()
	s_hover.bg_color     = Color(0.13, 0.10, 0.17)
	s_hover.border_color = rarity_color.lightened(0.25)
	s_hover.set_border_width_all(1)
	s_hover.set_corner_radius_all(1)
	btn.add_theme_stylebox_override("hover", s_hover)

	var s_pressed := StyleBoxFlat.new()
	s_pressed.bg_color     = Color(0.05, 0.04, 0.08)
	s_pressed.border_color = rarity_color.darkened(0.2)
	s_pressed.set_border_width_all(1)
	s_pressed.set_corner_radius_all(1)
	btn.add_theme_stylebox_override("pressed", s_pressed)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.offset_left = 2; vbox.offset_top = 2; vbox.offset_right = -2; vbox.offset_bottom = -2
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(vbox)

	var icon_path: String = upgrade.get("icon_path", "")
	if icon_path != "" and ResourceLoader.exists(icon_path):
		var icon := TextureRect.new()
		icon.custom_minimum_size = Vector2(0, 35)
		icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture = load(icon_path)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vbox.add_child(icon)
	else:
		var icon := ColorRect.new()
		icon.custom_minimum_size = Vector2(0, 35)
		icon.color = upgrade.get("color", Color.GRAY)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vbox.add_child(icon)

	var name_lbl := Label.new()
	name_lbl.text = upgrade.get("name", "???")
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.add_theme_font_size_override("font_size", 6)
	name_lbl.add_theme_color_override("font_color", Color(0.95, 0.92, 0.88))
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(name_lbl)

	var desc_lbl := Label.new()
	desc_lbl.text = upgrade.get("description", "")
	desc_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_lbl.add_theme_font_size_override("font_size", 5)
	desc_lbl.add_theme_color_override("font_color", Color(0.75, 0.72, 0.70))
	desc_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(desc_lbl)

	var rarity_lbl := Label.new()
	rarity_lbl.text = rarity.to_upper()
	rarity_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rarity_lbl.add_theme_font_size_override("font_size", 5)
	rarity_lbl.add_theme_color_override("font_color", rarity_color)
	rarity_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(rarity_lbl)

	btn.mouse_entered.connect(func():
		if not btn.disabled:
			Sfx.play(HOVER_SOUND, -8.0, 0.03)
	)
	btn.pressed.connect(func(): _on_card_pressed(upgrade, rarity))
	return btn

# ---------------------------------------------------------------------------
func _on_card_pressed(upgrade: Dictionary, rarity: String) -> void:
	var big := rarity in ["epic", "legendary"]
	Sfx.play(SELECT_BIG_SOUND if big else SELECT_SOUND, -3.0 if big else -5.0)
	UpgradeData.apply_upgrade(upgrade)
	upgrade_chosen.emit()
