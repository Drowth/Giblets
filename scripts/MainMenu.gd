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

const MENU_TITLE_FONT := 20
const MENU_SUB_FONT   := 6
const MENU_SPACER     := 4
const MENU_V_MARGIN   := 8  # breathing room so the column never touches the edges
const CHAR_CARD_PAD   := 6  # character card inner inset (3 top + 3 bottom)
# Largest-first; the first combination that fits the viewport wins.
const MENU_FONT_STEPS := [10, 9, 8, 7, 6, 5]
const MENU_SEP_STEPS  := [4, 3, 2]

func _show_main() -> void:
	_clear_panel()

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel = center
	_ui_layer.add_child(center)

	# Rows as data so the column can be rebuilt at different sizes while fitting.
	var rows: Array = [
		{"text": "START GAME", "color": Color(1.0, 0.45, 0.0), "cb": func():
			Sfx.play(SELECT_BIG_SOUND, -2.0)
			get_tree().change_scene_to_file("res://scenes/Main.tscn")},
		{"text": "CHARACTERS", "color": Color(0.75, 0.45, 0.95), "cb": _show_characters},
		{"text": "STAGE", "color": Color(0.45, 0.70, 0.95), "cb": _show_stages},
		{"text": "TALENTS  (%d giblets)" % Meta.giblets, "color": Color(0.95, 0.35, 0.30), "cb": _show_talents},
		{"text": "UPGRADES", "color": Color(0.45, 0.85, 0.85), "cb": _show_upgrades},
		{"text": "HIGH SCORES", "color": Color(1.0, 0.85, 0.1), "cb": _show_high_scores},
		{"text": "OPTIONS", "color": Color(0.55, 0.80, 0.55), "cb": _show_options},
		{"text": "CREDITS", "color": Color(0.55, 0.50, 0.60), "cb": _show_credits},
	]

	# Size the column to the viewport rather than hard-coding a font: build at
	# the largest font/separation, measure, and step down until it fits. Adding
	# a row later shrinks the menu automatically instead of running off-screen.
	var avail := get_viewport_rect().size.y - MENU_V_MARGIN
	var vbox: VBoxContainer = null
	for font_size in MENU_FONT_STEPS:
		for sep in MENU_SEP_STEPS:
			var candidate := _build_main_column(rows, font_size, sep)
			center.add_child(candidate)
			if candidate.get_combined_minimum_size().y <= avail:
				vbox = candidate
				break
			center.remove_child(candidate)
			candidate.free()
		if vbox:
			break
	if vbox == null:  # smaller than the smallest step: take the tightest and clip
		vbox = _build_main_column(rows, MENU_FONT_STEPS[-1], MENU_SEP_STEPS[-1])
		center.add_child(vbox)

	var first := vbox.get_meta("first_button") as Button
	if first:
		first.grab_focus()

func _build_main_column(rows: Array, font_size: int, sep: int) -> VBoxContainer:
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", sep)

	var title := Label.new()
	title.text = "GIBLETS"
	title.add_theme_font_size_override("font_size", MENU_TITLE_FONT)
	title.add_theme_color_override("font_color", Color(0.88, 0.06, 0.06))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	var sub := Label.new()
	sub.text = "survive the horde"
	sub.add_theme_font_size_override("font_size", MENU_SUB_FONT)
	sub.add_theme_color_override("font_color", Color(0.50, 0.38, 0.38))
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(sub)

	_add_spacer(vbox, MENU_SPACER)

	var first: Button = null
	for r in rows:
		var btn := _make_button(r["text"], r["color"], false, font_size)
		btn.pressed.connect(r["cb"])
		vbox.add_child(btn)
		if first == null:
			first = btn
	vbox.set_meta("first_button", first)
	return vbox

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

const TALENT_NODE_SIZE := Vector2(56, 26)
const TALENT_TIERS := [1, 2, 3]

var _talent_refund_mode := false
var _talent_focus_id := ""  # survives the rebuild after a buy/refund

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
	vbox.add_theme_constant_override("separation", 2)
	center.add_child(vbox)

	var title := Label.new()
	title.text = "— TALENTS —"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 10)
	title.add_theme_color_override("font_color", Color(0.95, 0.35, 0.30))
	vbox.add_child(title)

	var bank := Label.new()
	bank.text = "%d giblets" % Meta.giblets
	bank.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bank.add_theme_font_size_override("font_size", 7)
	bank.add_theme_color_override("font_color", Color(1.0, 0.85, 0.1))
	vbox.add_child(bank)

	# Shared detail label, fed by focus/hover on every talent node — no hover
	# popups at 384×216. Declared early so nodes can capture it.
	var detail := Label.new()

	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 5)
	columns.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(columns)

	var nodes: Array = []
	var focus_target: Button = null

	for branch: String in Meta.BRANCHES:
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 1)
		col.custom_minimum_size = Vector2(118, 0)
		columns.add_child(col)

		var header := Label.new()
		header.text = branch.to_upper()
		header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		header.add_theme_font_size_override("font_size", 6)
		header.add_theme_color_override("font_color", BRANCH_COLORS[branch])
		col.add_child(header)

		var pts := Label.new()
		pts.text = "%d pts" % Meta.points_in(branch)
		pts.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		pts.add_theme_font_size_override("font_size", 4)
		pts.add_theme_color_override("font_color", BRANCH_COLORS[branch].darkened(0.35))
		col.add_child(pts)

		# One row per tier, with a connector between them — this is what makes
		# the 3-tier structure in Meta.TALENTS actually legible.
		for tier: int in TALENT_TIERS:
			if tier > 1:
				col.add_child(_make_tier_connector(branch, tier))
			var row := HBoxContainer.new()
			row.alignment = BoxContainer.ALIGNMENT_CENTER
			row.add_theme_constant_override("separation", 3)
			row.mouse_filter = Control.MOUSE_FILTER_IGNORE
			col.add_child(row)
			for id: String in Meta.TALENTS:
				var info: Dictionary = Meta.TALENTS[id]
				if info["branch"] != branch or int(info["tier"]) != tier:
					continue
				var node := _make_talent_node(id, info, detail)
				row.add_child(node)
				nodes.append(node)
				if id == _talent_focus_id:
					focus_target = node

	detail.text = " \n "
	detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail.add_theme_font_size_override("font_size", 5)
	detail.add_theme_color_override("font_color", Color(0.8, 0.75, 0.7))
	detail.custom_minimum_size = Vector2(340, 14)
	vbox.add_child(detail)

	var footer := HBoxContainer.new()
	footer.alignment = BoxContainer.ALIGNMENT_CENTER
	footer.add_theme_constant_override("separation", 4)
	footer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(footer)

	# Mode toggle rather than right-click only: menus are fully gamepad
	# navigable, so refund needs an input a pad can reach.
	var mode_btn := _make_button(
		"MODE: REFUND" if _talent_refund_mode else "MODE: BUY",
		Color(1.0, 0.55, 0.35) if _talent_refund_mode else Color(0.55, 0.80, 0.55),
		false, 7, 92)
	mode_btn.pressed.connect(func():
		_talent_refund_mode = not _talent_refund_mode
		_show_talents()
	)
	footer.add_child(mode_btn)

	var back_btn := _make_button("BACK", Color(0.7, 0.7, 0.7), true, 7, 70)
	back_btn.pressed.connect(_show_main)
	footer.add_child(back_btn)

	if focus_target:
		focus_target.grab_focus()
	else:
		back_btn.grab_focus()

	_fit_talent_tree(vbox, nodes)

# Vertical link between two tier rows: branch-coloured once the tier is open,
# dark plus its point requirement while still gated.
func _make_tier_connector(branch: String, tier: int) -> Control:
	var wrap := CenterContainer.new()
	wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 2)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wrap.add_child(row)

	var need := Meta.tier_points_required(tier)
	var open: bool = Meta.points_in(branch) >= need

	var line := ColorRect.new()
	line.custom_minimum_size = Vector2(2, 6)
	line.color = BRANCH_COLORS[branch] if open else Color(0.22, 0.20, 0.22)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(line)

	if not open:
		var lbl := Label.new()
		lbl.text = "needs %d" % need
		lbl.add_theme_font_size_override("font_size", 4)
		lbl.add_theme_color_override("font_color", Color(0.55, 0.48, 0.55))
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(lbl)
	return wrap

# Rank pips as ColorRects — deliberately not a unicode bullet, so this doesn't
# depend on the fallback font having glyph coverage.
func _make_pip_row(r: int, max_rank: int, filled: Color) -> Control:
	var wrap := CenterContainer.new()
	wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 1)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wrap.add_child(row)
	for i in max_rank:
		var pip := ColorRect.new()
		pip.custom_minimum_size = Vector2(3, 3)
		pip.color = filled if i < r else Color(0.24, 0.21, 0.24)
		pip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(pip)
	return wrap

func _make_talent_node(id: String, info: Dictionary, detail: Label) -> Button:
	var r := Meta.rank(id)
	var max_rank := int(info["max"])
	var branch: String = info["branch"]
	var bcol: Color = BRANCH_COLORS[branch]
	var gated := not Meta.tier_unlocked(id)
	var maxed := r >= max_rank
	var affordable := Meta.can_buy(id)

	# States are conveyed by colour, NOT by `disabled` — using disabled for
	# affordability made every talent look identically dead when giblets were low.
	var border: Color
	var name_col: Color
	var status_text: String
	var status_col: Color
	if gated:
		border = Color(0.28, 0.25, 0.28)
		name_col = Color(0.48, 0.44, 0.48)
		status_text = "LOCKED"
		status_col = Color(0.55, 0.48, 0.55)
	elif maxed:
		border = Color(0.35, 0.85, 0.40)
		name_col = Color(0.85, 1.00, 0.85)
		status_text = "MAX"
		status_col = Color(0.45, 0.90, 0.45)
	elif affordable:
		border = bcol
		name_col = Color(0.97, 0.95, 0.92)
		status_text = "%d g" % Meta.cost(id)
		status_col = Color(1.0, 0.85, 0.1)
	else:
		border = bcol.darkened(0.55)
		name_col = Color(0.72, 0.68, 0.72) if r > 0 else Color(0.55, 0.51, 0.55)
		status_text = "%d g" % Meta.cost(id)
		status_col = Color(0.60, 0.52, 0.40)

	var node := Button.new()
	node.custom_minimum_size = TALENT_NODE_SIZE
	var norm := StyleBoxFlat.new()
	norm.bg_color = Color(0.09, 0.05, 0.05) if not gated else Color(0.05, 0.045, 0.05)
	norm.border_color = border
	norm.set_border_width_all(1)
	norm.set_corner_radius_all(2)
	node.add_theme_stylebox_override("normal", norm)
	var hover := norm.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.17, 0.08, 0.03)
	hover.border_color = border.lightened(0.3)
	node.add_theme_stylebox_override("hover", hover)
	node.add_theme_stylebox_override("focus", hover)
	node.add_theme_stylebox_override("pressed", norm)

	var inner := VBoxContainer.new()
	inner.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	inner.offset_left = 2
	inner.offset_right = -2
	inner.offset_top = 2
	inner.offset_bottom = -2
	inner.add_theme_constant_override("separation", 1)
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.add_child(inner)

	var name_lbl := Label.new()
	name_lbl.text = info["name"]
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_lbl.add_theme_font_size_override("font_size", 4)
	name_lbl.add_theme_constant_override("line_spacing", -1)
	name_lbl.add_theme_color_override("font_color", name_col)
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.add_child(name_lbl)

	inner.add_child(_make_pip_row(r, max_rank, Color(0.45, 0.90, 0.45) if maxed else bcol))

	var status_lbl := Label.new()
	status_lbl.text = status_text
	status_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_lbl.add_theme_font_size_override("font_size", 4)
	status_lbl.add_theme_color_override("font_color", status_col)
	status_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.add_child(status_lbl)

	var show_detail := func():
		_talent_focus_id = id
		detail.text = _talent_detail_text(id, info)
	node.mouse_entered.connect(func():
		Sfx.play(HOVER_SOUND, -9.0, 0.03)
		show_detail.call()
	)
	node.focus_entered.connect(show_detail)
	node.pressed.connect(func():
		_talent_focus_id = id
		if _talent_refund_mode:
			_try_talent_refund(id)
		else:
			_try_talent_buy(id)
	)
	# Mouse shortcut: right-click always refunds regardless of mode.
	node.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed \
				and (ev as InputEventMouseButton).button_index == MOUSE_BUTTON_RIGHT:
			_talent_focus_id = id
			_try_talent_refund(id)
	)
	return node

func _talent_detail_text(id: String, info: Dictionary) -> String:
	var r := Meta.rank(id)
	if _talent_refund_mode:
		if r <= 0:
			return "%s — nothing to refund" % info["name"]
		var blocker := Meta.refund_blocker(id)
		if blocker != "":
			return "%s — refund blocked: would lock %s" % [info["name"], blocker]
		return "%s — refund 1 rank: +%d giblets (%d%% back)" % [
			info["name"], Meta.refund_value(id), int(Meta.REFUND_RATE * 100.0)]
	if not Meta.tier_unlocked(id):
		return "%s — %s\nSpend %d points in %s to unlock" % [info["name"], info["desc"],
			Meta.tier_points_required(int(info["tier"])), str(info["branch"]).to_upper()]
	if r >= int(info["max"]):
		return "%s — %s\nMAXED" % [info["name"], info["desc"]]
	return "%s — %s\nCost: %d giblets" % [info["name"], info["desc"], Meta.cost(id)]

func _try_talent_buy(id: String) -> void:
	if Meta.buy(id):
		Sfx.play(COIN_SOUND, -4.0)
		_show_talents()
	else:
		Sfx.play(DISALLOW_SOUND, -8.0)

func _try_talent_refund(id: String) -> void:
	if Meta.refund(id):
		Sfx.play(COIN_SOUND, -4.0)
		_show_talents()
	else:
		Sfx.play(DISALLOW_SOUND, -8.0)

# The tree is the densest screen in the game; if it overruns the 216-unit
# viewport, pull the height out of the three tier rows rather than clipping.
func _fit_talent_tree(vbox: Control, nodes: Array) -> void:
	await get_tree().process_frame
	if not is_instance_valid(vbox) or nodes.is_empty():
		return
	var over: float = vbox.get_combined_minimum_size().y - (get_viewport_rect().size.y - MENU_V_MARGIN)
	if over <= 0.0:
		return
	var per_row := ceilf(over / float(TALENT_TIERS.size()))
	for n in nodes:
		if not is_instance_valid(n):
			return
		n.custom_minimum_size.y = maxf(18.0, n.custom_minimum_size.y - per_row)

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

	var cards: Array = []
	for id: String in CharacterData.CHARACTERS:
		var card := _make_character_card(id)
		row.add_child(card)
		cards.append(card)

	_add_spacer(vbox, 2)

	var back_btn := _make_button("BACK", Color(0.7, 0.7, 0.7), true)
	var back_wrap := CenterContainer.new()
	back_wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	back_wrap.add_child(back_btn)
	vbox.add_child(back_wrap)
	back_btn.pressed.connect(_show_main)
	back_btn.grab_focus()

	_fit_character_cards(vbox, cards)

# Cards are fixed-size Buttons with an anchored inner VBox, so a long passive
# description spills past the border instead of growing the card (that's what
# clipped the Necromancer/Paladin text). Measure what the tallest card actually
# needs, grow every card to match, and only shrink the description font if the
# content still can't fit the space the viewport leaves over.
func _fit_character_cards(vbox: Control, cards: Array) -> void:
	await get_tree().process_frame
	if not is_instance_valid(vbox) or cards.is_empty():
		return
	for c in cards:
		if not is_instance_valid(c):
			return
	var avail := get_viewport_rect().size.y - MENU_V_MARGIN
	var slack: float = avail - vbox.get_combined_minimum_size().y
	var max_h: float = float(cards[0].custom_minimum_size.y) + slack
	var needed := _cards_needed_height(cards)
	if needed > max_h:
		for c in cards:
			(c.get_meta("desc_label") as Label).add_theme_font_size_override("font_size", 4)
		await get_tree().process_frame
		if not is_instance_valid(vbox):
			return
		needed = _cards_needed_height(cards)
	for c in cards:
		c.custom_minimum_size.y = minf(needed, max_h)

func _cards_needed_height(cards: Array) -> float:
	var needed := 0.0
	for c in cards:
		var inner := c.get_child(0) as Control
		needed = maxf(needed, inner.get_combined_minimum_size().y + CHAR_CARD_PAD)
	return needed

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
	card.set_meta("desc_label", desc_lbl)  # _fit_character_cards may shrink this
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

# Upgrade collection: every entry in the pool as a card, grouped by rarity.
# Unlocked entries show in their rarity colour; still-locked roulette entries
# (locked_by_default and not yet won) are greyed out. Read-only gallery — the
# cards are focusable so d-pad/keyboard navigation auto-scrolls the grid.
const UPGRADE_RARITY_ORDER := ["common", "uncommon", "rare", "epic", "legendary"]

func _show_upgrades() -> void:
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
	vbox.add_theme_constant_override("separation", 2)
	center.add_child(vbox)

	# Sort a copy by rarity band so the gallery reads as a collection.
	var entries: Array = []
	for u in UpgradeData.ALL_UPGRADES:
		entries.append(u)
	entries.sort_custom(func(a, b):
		var ra := UPGRADE_RARITY_ORDER.find(a.get("rarity", "common"))
		var rb := UPGRADE_RARITY_ORDER.find(b.get("rarity", "common"))
		return ra < rb
	)

	var unlocked_count := 0
	for u in entries:
		if _is_upgrade_collected(u):
			unlocked_count += 1

	var title := Label.new()
	title.text = "— UPGRADE COLLECTION —"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 9)
	title.add_theme_color_override("font_color", Color(0.45, 0.85, 0.85))
	vbox.add_child(title)

	var count := Label.new()
	count.text = "%d / %d unlocked   ·   locked entries are won from the end-of-run roulette" % [
		unlocked_count, entries.size()]
	count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	count.add_theme_font_size_override("font_size", 4)
	count.add_theme_color_override("font_color", Color(0.62, 0.58, 0.62))
	vbox.add_child(count)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(352, 158)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	vbox.add_child(scroll)

	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 3)
	grid.add_theme_constant_override("v_separation", 3)
	scroll.add_child(grid)

	var first_card: Button = null
	for u in entries:
		var card := _make_upgrade_card(u)
		grid.add_child(card)
		if first_card == null:
			first_card = card

	var back_btn := _make_button("BACK", Color(0.7, 0.7, 0.7), true, 8, 120)
	var back_wrap := CenterContainer.new()
	back_wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	back_wrap.add_child(back_btn)
	vbox.add_child(back_wrap)
	back_btn.pressed.connect(_show_main)
	back_btn.grab_focus()

# An upgrade counts as collected if it was never roulette-gated, or if it has
# since been won (Meta.unlocked_upgrades — also filled by character purchases).
func _is_upgrade_collected(u: Dictionary) -> bool:
	if not u.get("locked_by_default", false):
		return true
	return Meta.is_upgrade_unlocked(u.get("id", ""))

func _make_upgrade_card(u: Dictionary) -> Button:
	var unlocked := _is_upgrade_collected(u)
	var rarity: String = u.get("rarity", "common")
	var rc: Color = UpgradeData.RARITY_COLORS.get(rarity, Color.WHITE)
	# Locked cards keep a dimmed hint of their rarity so you can see what's missing.
	var border_color := rc if unlocked else rc.darkened(0.68)

	var card := Button.new()
	# 4 across in a 384-wide viewport. Height fits the longest description at
	# font 4 (3 wrapped lines) — the inner VBox is anchored full-rect, so it does
	# NOT grow the button; text that outgrows this height would spill the border.
	card.custom_minimum_size = Vector2(84, 44)
	var norm := StyleBoxFlat.new()
	norm.bg_color = Color(0.07, 0.03, 0.03) if unlocked else Color(0.045, 0.04, 0.045)
	norm.border_color = border_color
	norm.set_border_width_all(1)
	norm.set_corner_radius_all(3)
	card.add_theme_stylebox_override("normal", norm)
	var hover := norm.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.15, 0.06, 0.02) if unlocked else Color(0.09, 0.08, 0.09)
	hover.border_color = border_color.lightened(0.25)
	card.add_theme_stylebox_override("hover", hover)
	card.add_theme_stylebox_override("focus", hover)
	card.add_theme_stylebox_override("pressed", norm)

	var inner := VBoxContainer.new()
	inner.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	inner.offset_left = 2
	inner.offset_right = -2
	inner.offset_top = 2
	inner.offset_bottom = -2
	inner.add_theme_constant_override("separation", 0)
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(inner)

	var name_lbl := Label.new()
	name_lbl.text = u.get("name", "?")
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_lbl.add_theme_font_size_override("font_size", 5)
	name_lbl.add_theme_constant_override("line_spacing", -1)
	name_lbl.add_theme_color_override("font_color",
		Color(0.95, 0.92, 0.90) if unlocked else Color(0.44, 0.42, 0.44))
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.add_child(name_lbl)

	var desc_lbl := Label.new()
	desc_lbl.text = u.get("description", "")
	desc_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_lbl.add_theme_font_size_override("font_size", 4)
	desc_lbl.add_theme_constant_override("line_spacing", -1)
	desc_lbl.add_theme_color_override("font_color",
		Color(0.66, 0.62, 0.66) if unlocked else Color(0.32, 0.30, 0.32))
	desc_lbl.size_flags_vertical = Control.SIZE_EXPAND_FILL
	desc_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.add_child(desc_lbl)

	var status_lbl := Label.new()
	status_lbl.text = rarity.to_upper() if unlocked else "LOCKED"
	status_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_lbl.add_theme_font_size_override("font_size", 4)
	status_lbl.add_theme_color_override("font_color",
		rc if unlocked else Color(0.55, 0.45, 0.30))
	status_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.add_child(status_lbl)

	card.mouse_entered.connect(func():
		Sfx.play(HOVER_SOUND, -9.0, 0.03)
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
