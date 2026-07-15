extends Node

# Meta-progression singleton (docs/BALANCE.md §6).
# Giblets are earned at death (1 per GIBLETS_PER_SCORE score) and spent in the
# main menu on permanent, deliberately small base-stat unlocks. Unlocks shift
# the first two minutes of a run, never the curve.

const SAVE_PATH := "user://meta.save"
const GIBLETS_PER_SCORE := 400

# id -> {name, desc, max_rank, cost_per_rank, per_rank value}
const UNLOCKS: Dictionary = {
	"hp":     {"name": "Thick Skin",   "desc": "+10 max health",   "max": 3, "cost": 5, "per": 10.0},
	"damage": {"name": "Sharp Fangs",  "desc": "+1 damage",        "max": 3, "cost": 6, "per": 1.0},
	"speed":  {"name": "Long Stride",  "desc": "+5% move speed",   "max": 2, "cost": 5, "per": 0.05},
	"magnet": {"name": "Greedy Soul",  "desc": "+10% magnet range", "max": 2, "cost": 4, "per": 0.10},
	"xp":     {"name": "Old Bones",    "desc": "+5% XP gained",    "max": 2, "cost": 8, "per": 0.05},
}

var giblets: int = 0
var ranks: Dictionary = {}  # id -> rank purchased

func _ready() -> void:
	_load()

func earn_from_score(score: int) -> int:
	var earned := score / GIBLETS_PER_SCORE
	giblets += earned
	_save()
	return earned

func rank(id: String) -> int:
	return int(ranks.get(id, 0))

func cost(id: String) -> int:
	# Cost rises with rank: base, 2×base, 3×base...
	return int(UNLOCKS[id]["cost"]) * (rank(id) + 1)

func can_buy(id: String) -> bool:
	return rank(id) < int(UNLOCKS[id]["max"]) and giblets >= cost(id)

func buy(id: String) -> bool:
	if not can_buy(id):
		return false
	giblets -= cost(id)
	ranks[id] = rank(id) + 1
	_save()
	return true

func bonus_max_health() -> int:
	return int(rank("hp") * UNLOCKS["hp"]["per"])

func bonus_damage() -> int:
	return int(rank("damage") * UNLOCKS["damage"]["per"])

func bonus_move_speed_mul() -> float:
	return 1.0 + rank("speed") * float(UNLOCKS["speed"]["per"])

func bonus_magnet_mul() -> float:
	return 1.0 + rank("magnet") * float(UNLOCKS["magnet"]["per"])

func bonus_xp_mul() -> float:
	return 1.0 + rank("xp") * float(UNLOCKS["xp"]["per"])

func _save() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_var({"giblets": giblets, "ranks": ranks})
		file.close()

func _load() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file:
		var data = file.get_var()
		file.close()
		if data is Dictionary:
			giblets = int(data.get("giblets", 0))
			var r = data.get("ranks", {})
			if r is Dictionary:
				ranks = r
