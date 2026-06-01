extends Button

signal chosen(upgrade: Dictionary)

@onready var icon_rect: ColorRect = $VBox/Icon
@onready var name_label: Label = $VBox/NameLabel
@onready var desc_label: Label = $VBox/DescLabel
@onready var rarity_label: Label = $VBox/RarityLabel

var _upgrade: Dictionary = {}

func _ready() -> void:
	pressed.connect(func(): chosen.emit(_upgrade))

func setup(upgrade: Dictionary) -> void:
	_upgrade = upgrade
	icon_rect.color = upgrade.get("color", Color.WHITE)
	name_label.text = upgrade.get("name", "???")
	desc_label.text = upgrade.get("description", "")
	rarity_label.text = "[%s]" % upgrade.get("rarity", "common").to_upper()
	var rarity_colors := {"common": Color(0.7, 0.7, 0.7), "uncommon": Color(0.3, 0.9, 0.3), "rare": Color(0.4, 0.4, 1.0)}
	rarity_label.modulate = rarity_colors.get(upgrade.get("rarity", "common"), Color.WHITE)
