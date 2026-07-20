extends Control

const HOVER_SOUND      := "res://assets/sfx/ui/hover.wav"
const SELECT_SOUND     := "res://assets/sfx/ui/select.wav"
const SELECT_BIG_SOUND := "res://assets/sfx/ui/select_big.wav"
const CANCEL_SOUND     := "res://assets/sfx/ui/cancel.wav"
const DISALLOW_SOUND   := "res://assets/sfx/ui/disallow.wav"
const COIN_SOUND       := "res://assets/sfx/game/coin.wav"

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
	_crt_rect.visible = Settings.crt_enabled
	Settings.crt_settings_changed.connect(func():
		if _crt_rect:
			_crt_rect.visible = Settings.crt_enabled
	)
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
	vbox.add_theme_constant_override("separation", 4)
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

	_add_spacer(vbox, 4)

	# font 9 → "mid" margins in _make_button: six rows must fit 216 units.
	var start_btn := _make_button("START GAME", Color(1.0, 0.45, 0.0), false, 9)
	start_btn.pressed.connect(func():
		Sfx.play(SELECT_BIG_SOUND, -2.0)
		get_tree().change_scene_to_file("res://scenes/Main.tscn")
	)
	vbox.add_child(start_btn)

	var chars_btn := _make_button("CHARACTERS", Color(0.75, 0.45, 0.95), false, 9)
	chars_btn.pressed.connect(_show_characters)
	vbox.add_child(chars_btn)

	var stage_btn := _make_button("STAGE", Color(0.45, 0.70, 0.95), false, 9)
	stage_btn.pressed.connect(_show_stages)
	vbox.add_child(stage_btn)

	var talents_btn := _make_button("TALENTS  (%d giblets)" % Meta.giblets, Color(0.95, 0.35, 0.30), false, 9)
	talents_btn.pressed.connect(_show_talents)
	vbox.add_child(talents_btn)

	var scores_btn := _make_button("HIGH SCORES", Color(1.0, 0.85, 0.1), false, 9)
	scores_btn.pressed.connect(_show_high_scores)
	vbox.add_child(scores_btn)

	var options_btn := _make_button("OPTIONS", Color(0.55, 0.80, 0.55), false, 9)
	options_btn.pressed.connect(_show_options)
	vbox.add_child(options_btn)

	var credits_btn := _make_button("CREDITS", Color(0.55, 0.50, 0.60), false, 9)
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

	var panel: VBoxContainer = VBoxContainer.new()
	panel.set_script(load("res://ui/OptionsPanel.gd"))
	center.add_child(panel)
	panel.closed.connect(_show_main)

const BRANCH_COLORS: Dictionary = {
	"offense": Color(0.95, 0.30, 0.25),
	"defense": Color(0.35, 0.55, 0.95),
	"utility": Color(0.40, 0.85, 0.45),
}

func _show_talents() -> void:
	_clear_panel()

	var overlay := ColorRect.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0.0, 0.0, 0.0, 0.88)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_panel = overlay
	_ui_layer.add_child(overlay)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(center)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 3)
	center.add_child(vbox)

	var title := Label.new()
	title.text = "— TALENTS —"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 12)
	title.add_theme_color_override("font_color", Color(0.95, 0.35, 0.30))
	vbox.add_child(title)

	var bank := Label.new()
	bank.text = "%d giblets" % Meta.giblets
	bank.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bank.add_theme_font_size_override("font_size", 8)
	bank.add_theme_color_override("font_color", Color(1.0, 0.85, 0.1))
	vbox.add_child(bank)

	_add_spacer(vbox, 2)

	# Shared detail label, fed by focus/hover on every talent button — no
	# hover popups at 384×216.
	var detail := Label.new()

	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 6)
	columns.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(columns)

	for branch: String in Meta.BRANCHES:
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 2)
		col.custom_minimum_size = Vector2(112, 0)
		columns.add_child(col)

		var header := Label.new()
		header.text = branch.to_upper()
		header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		header.add_theme_font_size_override("font_size", 7)
		header.add_theme_color_override("font_color", BRANCH_COLORS[branch])
		col.add_child(header)

		var pts := Label.new()
		pts.text = "%d pts" % Meta.points_in(branch)
		pts.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		pts.add_theme_font_size_override("font_size", 5)
		pts.add_theme_color_override("font_color", BRANCH_COLORS[branch].darkened(0.35))
		col.add_child(pts)

		for id: String in Meta.TALENTS:
			var info: Dictionary = Meta.TALENTS[id]
			if info["branch"] != branch:
				continue
			col.add_child(_make_talent_button(id, info, detail))

	_add_spacer(vbox, 2)

	detail.text = " \n "
	detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	detail.add_theme_font_size_override("font_size", 6)
	detail.add_theme_color_override("font_color", Color(0.8, 0.75, 0.7))
	detail.custom_minimum_size = Vector2(340, 16)
	vbox.add_child(detail)

	var back_btn := _make_button("BACK", Color(0.7, 0.7, 0.7), true)
	var back_wrap := CenterContainer.new()
	back_wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	back_wrap.add_child(back_btn)
	vbox.add_child(back_wrap)
	back_btn.pressed.connect(_show_main)
	back_btn.grab_focus()

func _make_talent_button(id: String, info: Dictionary, detail: Label) -> Button:
	var r := Meta.rank(id)
	var maxed := r >= int(info["max"])
	var gated := not Meta.tier_unlocked(id)
	var text: String
	var color: Color
	var detail_text: String
	if gated:
		var need := Meta.tier_points_required(int(info["tier"]))
		text = "%s  LOCKED" % info["name"]
		color = Color(0.45, 0.40, 0.45)
		detail_text = "%s — %s\nSpend %d points in %s to unlock" % [info["name"], info["desc"], need, str(info["branch"]).to_upper()]
	elif maxed:
		text = "%s  %d/%d" % [info["name"], r, int(info["max"])]
		color = Color(0.4, 0.9, 0.4)
		detail_text = "%s — %s\nMAXED" % [info["name"], info["desc"]]
	else:
		text = "%s  %d/%d (%d)" % [info["name"], r, int(info["max"]), Meta.cost(id)]
		color = Color(1.0, 0.85, 0.1) if Meta.can_buy(id) else Color(0.5, 0.45, 0.5)
		detail_text = "%s — %s\nCost: %d giblets" % [info["name"], info["desc"], Meta.cost(id)]

	var btn := _make_button(text, color, false, 5, 112)
	btn.disabled = gated or maxed or not Meta.can_buy(id)
	if btn.disabled:
		btn.modulate.a = 0.6
		if not maxed and not gated:
			btn.mouse_entered.connect(func(): Sfx.play(DISALLOW_SOUND, -8.0))
	var show_detail := func(): detail.text = detail_text
	btn.mouse_entered.connect(show_detail)
	btn.focus_entered.connect(show_detail)
	btn.pressed.connect(func():
		if Meta.buy(id):
			Sfx.play(COIN_SOUND, -4.0)
			_show_talents()
	)
	return btn

func _show_characters() -> void:
	_clear_panel()

	var overlay := ColorRect.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0.0, 0.0, 0.0, 0.88)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_panel = overlay
	_ui_layer.add_child(overlay)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(center)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	center.add_child(vbox)

	var title := Label.new()
	title.text = "— CHARACTERS —"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 12)
	title.add_theme_color_override("font_color", Color(0.75, 0.45, 0.95))
	vbox.add_child(title)

	var bank := Label.new()
	bank.text = "%d giblets" % Meta.giblets
	bank.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bank.add_theme_font_size_override("font_size", 8)
	bank.add_theme_color_override("font_color", Color(1.0, 0.85, 0.1))
	vbox.add_child(bank)

	_add_spacer(vbox, 2)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(row)

	for id: String in CharacterData.CHARACTERS:
		row.add_child(_make_character_card(id))

	_add_spacer(vbox, 2)

	var back_btn := _make_button("BACK", Color(0.7, 0.7, 0.7), true)
	var back_wrap := CenterContainer.new()
	back_wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	back_wrap.add_child(back_btn)
	vbox.add_child(back_wrap)
	back_btn.pressed.connect(_show_main)
	back_btn.grab_focus()

func _make_character_card(id: String) -> Button:
	var info: Dictionary = CharacterData.CHARACTERS[id]
	var unlocked := Meta.is_character_unlocked(id)
	var selected := Meta.selected_character == id

	var border_color: Color
	var status_text: String
	var status_color: Color
	if selected:
		border_color = Color(0.4, 0.9, 0.4)
		status_text = "SELECTED"
		status_color = Color(0.4, 0.9, 0.4)
	elif unlocked:
		border_color = Color(0.7, 0.65, 0.7)
		status_text = "SELECT"
		status_color = Color(0.9, 0.88, 0.9)
	elif Meta.can_buy_character(id):
		border_color = Color(1.0, 0.85, 0.1)
		status_text = "UNLOCK (%d)" % int(info["cost"])
		status_color = Color(1.0, 0.85, 0.1)
	else:
		border_color = Color(0.4, 0.35, 0.4)
		status_text = "%d GIBLETS" % int(info["cost"])
		status_color = Color(0.5, 0.45, 0.5)

	var card := Button.new()
	card.custom_minimum_size = Vector2(80, 112)
	var norm := StyleBoxFlat.new()
	norm.bg_color = Color(0.07, 0.03, 0.03)
	norm.border_color = border_color
	norm.set_border_width_all(2)
	norm.set_corner_radius_all(3)
	card.add_theme_stylebox_override("normal", norm)
	var hover := norm.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.15, 0.06, 0.02)
	hover.border_color = border_color.lightened(0.25)
	card.add_theme_stylebox_override("hover", hover)
	card.add_theme_stylebox_override("focus", hover)
	var pressed_sb := norm.duplicate() as StyleBoxFlat
	pressed_sb.border_color = border_color.darkened(0.2)
	card.add_theme_stylebox_override("pressed", pressed_sb)

	var inner := VBoxContainer.new()
	inner.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	inner.offset_left = 3
	inner.offset_right = -3
	inner.offset_top = 3
	inner.offset_bottom = -3
	inner.add_theme_constant_override("separation", 2)
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(inner)

	var portrait := TextureRect.new()
	portrait.texture = load(info["sprite_path"])
	portrait.custom_minimum_size = Vector2(0, 36)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not unlocked:
		portrait.modulate = Color(0.25, 0.2, 0.25)
	inner.add_child(portrait)

	var name_lbl := Label.new()
	name_lbl.text = info["name"]
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.add_theme_font_size_override("font_size", 6)
	name_lbl.add_theme_color_override("font_color", Color(0.95, 0.92, 0.9))
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.add_child(name_lbl)

	var desc_lbl := Label.new()
	desc_lbl.text = _character_summary(info)
	desc_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_lbl.add_theme_font_size_override("font_size", 5)
	desc_lbl.add_theme_color_override("font_color", Color(0.65, 0.6, 0.65))
	desc_lbl.size_flags_vertical = Control.SIZE_EXPAND_FILL
	desc_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.add_child(desc_lbl)

	var status_lbl := Label.new()
	status_lbl.text = status_text
	status_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_lbl.add_theme_font_size_override("font_size", 5)
	status_lbl.add_theme_color_override("font_color", status_color)
	status_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.add_child(status_lbl)

	card.mouse_entered.connect(func():
		if not card.disabled:
			Sfx.play(HOVER_SOUND, -9.0, 0.03)
	)
	card.pressed.connect(func():
		if selected:
			return
		if unlocked:
			Meta.select_character(id)
			Sfx.play(SELECT_SOUND, -6.0)
			_show_characters()
		elif Meta.buy_character(id):
			Meta.select_character(id)
			Sfx.play(COIN_SOUND, -4.0)
			_show_characters()
		else:
			Sfx.play(DISALLOW_SOUND, -8.0)
	)

	return card

func _show_stages() -> void:
	_clear_panel()

	var overlay := ColorRect.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0.0, 0.0, 0.0, 0.88)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_panel = overlay
	_ui_layer.add_child(overlay)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(center)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	center.add_child(vbox)

	var title := Label.new()
	title.text = "— STAGE —"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 12)
	title.add_theme_color_override("font_color", Color(0.45, 0.70, 0.95))
	vbox.add_child(title)

	_add_spacer(vbox, 2)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(row)

	for id: String in StageData.STAGES:
		row.add_child(_make_stage_card(id))

	_add_spacer(vbox, 2)

	var back_btn := _make_button("BACK", Color(0.7, 0.7, 0.7), true)
	var back_wrap := CenterContainer.new()
	back_wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	back_wrap.add_child(back_btn)
	vbox.add_child(back_wrap)
	back_btn.pressed.connect(_show_main)
	back_btn.grab_focus()

func _make_stage_card(id: String) -> Button:
	var info: Dictionary = StageData.STAGES[id]
	var selected := Meta.selected_stage == id

	var border_color := Color(0.4, 0.9, 0.4) if selected else Color(0.7, 0.65, 0.7)
	var status_text := "SELECTED" if selected else "SELECT"
	var status_color := border_color

	var card := Button.new()
	card.custom_minimum_size = Vector2(80, 60)
	var norm := StyleBoxFlat.new()
	norm.bg_color = Color(0.07, 0.03, 0.03)
	norm.border_color = border_color
	norm.set_border_width_all(2)
	norm.set_corner_radius_all(3)
	card.add_theme_stylebox_override("normal", norm)
	var hover := norm.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.15, 0.06, 0.02)
	hover.border_color = border_color.lightened(0.25)
	card.add_theme_stylebox_override("hover", hover)
	card.add_theme_stylebox_override("focus", hover)
	var pressed_sb := norm.duplicate() as StyleBoxFlat
	pressed_sb.border_color = border_color.darkened(0.2)
	card.add_theme_stylebox_override("pressed", pressed_sb)

	var inner := VBoxContainer.new()
	inner.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	inner.offset_left = 3
	inner.offset_right = -3
	inner.offset_top = 3
	inner.offset_bottom = -3
	inner.add_theme_constant_override("separation", 2)
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(inner)

	var name_lbl := Label.new()
	name_lbl.text = info["name"]
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.add_theme_font_size_override("font_size", 6)
	name_lbl.add_theme_color_override("font_color", Color(0.95, 0.92, 0.9))
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.add_child(name_lbl)

	var desc_lbl := Label.new()
	desc_lbl.text = info["desc"]
	desc_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_lbl.add_theme_font_size_override("font_size", 5)
	desc_lbl.add_theme_color_override("font_color", Color(0.65, 0.6, 0.65))
	desc_lbl.size_flags_vertical = Control.SIZE_EXPAND_FILL
	desc_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.add_child(desc_lbl)

	var status_lbl := Label.new()
	status_lbl.text = status_text
	status_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_lbl.add_theme_font_size_override("font_size", 5)
	status_lbl.add_theme_color_override("font_color", status_color)
	status_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.add_child(status_lbl)

	card.mouse_entered.connect(func():
		if not card.disabled:
			Sfx.play(HOVER_SOUND, -9.0, 0.03)
	)
	card.pressed.connect(func():
		if selected:
			return
		Meta.select_stage(id)
		Sfx.play(SELECT_SOUND, -6.0)
		_show_stages()
	)

	return card

func _character_summary(info: Dictionary) -> String:
	var parts: Array[String] = []
	var deltas: Dictionary = info["deltas"]
	if deltas.has("max_health"):
		parts.append("%+d HP" % int(deltas["max_health"]))
	if deltas.has("projectile_damage"):
		parts.append("%+d dmg" % int(deltas["projectile_damage"]))
	if deltas.has("move_speed"):
		parts.append("%+d spd" % int(deltas["move_speed"]))
	var out := ", ".join(parts)
	if info["passive_desc"] != "":
		out += ("\n" if out != "" else "") + str(info["passive_desc"])
	if out == "":
		out = str(info["desc"])
	return out

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
	# separation 2 + font-7 rows: a full 10-entry board must fit 216 units
	vbox.add_theme_constant_override("separation", 2)
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
			rank_lbl.add_theme_font_size_override("font_size", 7)
			rank_lbl.add_theme_color_override("font_color", row_color)
			row.add_child(rank_lbl)

			var name_lbl := Label.new()
			name_lbl.text = entry.name
			name_lbl.custom_minimum_size = Vector2(68, 0)
			name_lbl.add_theme_font_size_override("font_size", 7)
			name_lbl.add_theme_color_override("font_color", row_color)
			row.add_child(name_lbl)

			var score_lbl := Label.new()
			score_lbl.text = "%d" % entry.score
			score_lbl.custom_minimum_size = Vector2(36, 0)
			score_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			score_lbl.add_theme_font_size_override("font_size", 7)
			score_lbl.add_theme_color_override("font_color", row_color)
			row.add_child(score_lbl)

			var et := int(entry.time)
			var meta_lbl := Label.new()
			meta_lbl.text = "  Lv%d %dk %d:%02d" % [entry.level, entry.kills, et / 60, et % 60]
			meta_lbl.add_theme_font_size_override("font_size", 5)
			meta_lbl.add_theme_color_override("font_color", row_color.darkened(0.3))
			row.add_child(meta_lbl)

	_add_spacer(vbox, 4)

	var back_btn := _make_button("BACK", Color(0.7, 0.7, 0.7), true, 9)
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
		["Godot Engine 4.7", 8, Color(0.65, 0.65, 0.70)],
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

	var back_btn := _make_button("BACK", Color(0.7, 0.7, 0.7), true)
	back_btn.pressed.connect(func():
		_show_main()
	)
	back_center.add_child(back_btn)
	back_btn.grab_focus()

func _add_spacer(parent: Control, height: int) -> void:
	var s := Control.new()
	s.custom_minimum_size = Vector2(0, height)
	parent.add_child(s)

# is_back plays the softer cancel sound on press instead of select — used for
# BACK buttons so backing out of a menu doesn't sound identical to confirming.
# font_size/min_width shrink the button for dense grids (talent tree).
func _make_button(text: String, font_color: Color, is_back: bool = false,
		font_size: int = 10, min_width: int = 180) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(min_width, 0)
	btn.add_theme_font_size_override("font_size", font_size)
	btn.add_theme_color_override("font_color", font_color)

	# Margins scale with font size so dense menus fit the 216-unit viewport:
	# <8 = grid buttons (talents), <10 = stacked menus, else = sparse screens.
	var compact := font_size < 8
	var mid := font_size < 10
	var norm := StyleBoxFlat.new()
	norm.bg_color = Color(0.07, 0.03, 0.03)
	norm.border_color = Color(0.35, 0.12, 0.0)
	norm.set_border_width_all(1 if compact else 2)
	norm.set_corner_radius_all(2 if compact else 4)
	norm.content_margin_left = 4 if compact else (10 if mid else 16)
	norm.content_margin_right = 4 if compact else (10 if mid else 16)
	norm.content_margin_top = 2 if compact else (3 if mid else 6)
	norm.content_margin_bottom = 2 if compact else (3 if mid else 6)
	btn.add_theme_stylebox_override("normal", norm)

	var hover := norm.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.15, 0.06, 0.02)
	hover.border_color = Color(1.0, 0.45, 0.0)
	btn.add_theme_stylebox_override("hover", hover)
	# Gamepad/keyboard focus must be visible — a grid can't rely on the mouse.
	btn.add_theme_stylebox_override("focus", hover)

	btn.mouse_entered.connect(func():
		if not btn.disabled:
			Sfx.play(HOVER_SOUND, -9.0, 0.03)
	)
	btn.pressed.connect(func():
		Sfx.play(CANCEL_SOUND if is_back else SELECT_SOUND, -6.0)
	)

	return btn
