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
	rarity_label.modulate = UpgradeData.RARITY_COLORS.get(upgrade.get("rarity", "common"), Color.WHITE)
