extends Node

# Meta-progression singleton (docs/BALANCE.md §6).
# Giblets are earned at death (score + boss kills + survival time) and spent in
# the main menu on the talent tree and character unlocks. Talents are permanent,
# deliberately small, additive-to-base-stat bumps — they shift the first two
# minutes of a run, never the curve. In-run upgrades NEVER persist across runs.
#
# Three persistence tracks live here:
#   ranks              — talent tree purchases (id -> rank)
#   unlocked_characters / selected_character — playable roster (CharacterData.gd)
#   unlocked_upgrades  — level-up pool entries won from the end-of-run roulette

const SAVE_PATH := "user://meta.save"
const SAVE_VERSION := 2

# --- Earn formula (docs/BALANCE.md §6) ---
# Score compounds explosively late-game (kills × level × combo), so its giblet
# component is capped — boss kills and survival minutes carry the steady,
# predictable income. Calibrated via BalanceSim yield report: early runs ~8-12
# giblets, endgame runs ~30.
const GIBLETS_PER_SCORE := 100000 # score component: 1 giblet per this much score...
const SCORE_GIBLETS_CAP := 10     # ...capped here
const BOSS_KILL_GIBLETS := 1     # per boss killed
const SURVIVAL_GIBLETS  := 1     # per 2 full minutes survived

# --- Talent tree ---
# 3 branches × 3 tiers. Tier 1 always open; tier 2 needs TIER2_POINTS spent in
# the branch, tier 3 needs TIER3_POINTS. Every talent is additive to a base
# floor — nothing on the multiplicative DPS path (no fire rate / projectile
# count / crit / damage_mul), per docs/DESIGN.md.
# id -> {name, desc, branch, tier, max rank, cost (base, scales ×(rank+1)), per-rank value}
const TIER2_POINTS := 3
const TIER3_POINTS := 6
const BRANCHES: Array[String] = ["offense", "defense", "utility"]

const TALENTS: Dictionary = {
	# OFFENSE
	"damage":      {"name": "Sharp Fangs",    "desc": "+1 base damage",                    "branch": "offense", "tier": 1, "max": 4, "cost": 6,  "per": 1.0},
	"proj_speed":  {"name": "Swift Bolts",    "desc": "+25 projectile speed",              "branch": "offense", "tier": 1, "max": 3, "cost": 5,  "per": 25.0},
	"knockback":   {"name": "Heavy Rounds",   "desc": "+8 knockback force",                "branch": "offense", "tier": 2, "max": 3, "cost": 8,  "per": 8.0},
	"free_draw":   {"name": "Grim Arsenal",   "desc": "Start each run with a random common upgrade", "branch": "offense", "tier": 3, "max": 1, "cost": 40, "per": 1.0},
	# DEFENSE
	"hp":          {"name": "Thick Skin",     "desc": "+10 max health",                    "branch": "defense", "tier": 1, "max": 4, "cost": 5,  "per": 10.0},
	"armor":       {"name": "Stone Hide",     "desc": "+1 armor",                          "branch": "defense", "tier": 1, "max": 2, "cost": 12, "per": 1.0},
	"regen":       {"name": "Slow Mend",      "desc": "+0.5 health per 5s",                "branch": "defense", "tier": 2, "max": 3, "cost": 8,  "per": 0.5},
	"second_wind": {"name": "Death Defiance", "desc": "Survive one killing blow per run",  "branch": "defense", "tier": 3, "max": 1, "cost": 45, "per": 1.0},
	# UTILITY
	"speed":       {"name": "Long Stride",    "desc": "+5% move speed",                    "branch": "utility", "tier": 1, "max": 3, "cost": 5,  "per": 0.05},
	"magnet":      {"name": "Greedy Soul",    "desc": "+10% magnet range",                 "branch": "utility", "tier": 1, "max": 3, "cost": 4,  "per": 0.10},
	"xp":          {"name": "Old Bones",      "desc": "+5% XP gained",                     "branch": "utility", "tier": 2, "max": 3, "cost": 8,  "per": 0.05},
	"dash_cd":     {"name": "Nimble",         "desc": "-5% dash cooldown",                 "branch": "utility", "tier": 2, "max": 2, "cost": 8,  "per": 0.05},
	"head_start":  {"name": "Head Start",     "desc": "Begin each run at level 2",         "branch": "utility", "tier": 3, "max": 1, "cost": 40, "per": 1.0},
}

var giblets: int = 0
var ranks: Dictionary = {}               # talent id -> rank purchased
var selected_character: String = "ghoul"
var selected_stage: String = "default"
var unlocked_characters: Array = ["ghoul"]
var unlocked_upgrades: Array = []        # roulette-won upgrade ids (UpgradeData locked_by_default pool)

func _ready() -> void:
	_load()

# ---------------------------------------------------------------------------
# Earning
# ---------------------------------------------------------------------------
# Pure calculation — shared by the death screen (via earn_from_run) and
# BalanceSim's yield report (which must not mutate saved state).
func compute_earn(score: int, bosses: int, minutes: float) -> Dictionary:
	var score_part: int = mini(score / GIBLETS_PER_SCORE, SCORE_GIBLETS_CAP)
	var boss_part  := bosses * BOSS_KILL_GIBLETS
	var time_part  := int(minutes / 2.0) * SURVIVAL_GIBLETS
	return {"score_part": score_part, "boss_part": boss_part, "time_part": time_part,
		"total": score_part + boss_part + time_part}

# Itemized so the death screen can show each component.
func earn_from_run(score: int, bosses: int, minutes: float) -> Dictionary:
	var earned := compute_earn(score, bosses, minutes)
	giblets += int(earned["total"])
	_save()
	return earned

# ---------------------------------------------------------------------------
# Talent tree
# ---------------------------------------------------------------------------
func rank(id: String) -> int:
	return int(ranks.get(id, 0))

func cost(id: String) -> int:
	# Cost rises with rank: base, 2×base, 3×base...
	return int(TALENTS[id]["cost"]) * (rank(id) + 1)

func points_in(branch: String) -> int:
	var total := 0
	for id: String in TALENTS:
		if TALENTS[id]["branch"] == branch:
			total += rank(id)
	return total

func tier_points_required(tier: int) -> int:
	match tier:
		2: return TIER2_POINTS
		3: return TIER3_POINTS
	return 0

func tier_unlocked(id: String) -> bool:
	var t: int = TALENTS[id]["tier"]
	return points_in(TALENTS[id]["branch"]) >= tier_points_required(t)

func can_buy(id: String) -> bool:
	return tier_unlocked(id) and rank(id) < int(TALENTS[id]["max"]) and giblets >= cost(id)

func buy(id: String) -> bool:
	if not can_buy(id):
		return false
	giblets -= cost(id)
	ranks[id] = rank(id) + 1
	_save()
	return true

# --- Bonus getters, consumed by GameState._reset() ---
func bonus_max_health() -> int:
	return int(rank("hp") * TALENTS["hp"]["per"])

func bonus_damage() -> int:
	return int(rank("damage") * TALENTS["damage"]["per"])

func bonus_move_speed_mul() -> float:
	return 1.0 + rank("speed") * float(TALENTS["speed"]["per"])

func bonus_magnet_mul() -> float:
	return 1.0 + rank("magnet") * float(TALENTS["magnet"]["per"])

func bonus_xp_mul() -> float:
	return 1.0 + rank("xp") * float(TALENTS["xp"]["per"])

func bonus_proj_speed() -> float:
	return rank("proj_speed") * float(TALENTS["proj_speed"]["per"])

func bonus_knockback() -> float:
	return rank("knockback") * float(TALENTS["knockback"]["per"])

func bonus_armor() -> int:
	return int(rank("armor") * TALENTS["armor"]["per"])

func bonus_regen() -> float:
	return rank("regen") * float(TALENTS["regen"]["per"])

func bonus_dash_cd_mul() -> float:
	return 1.0 - rank("dash_cd") * float(TALENTS["dash_cd"]["per"])

func has_second_wind() -> bool:
	return rank("second_wind") > 0

func has_head_start() -> bool:
	return rank("head_start") > 0

func has_free_draw() -> bool:
	return rank("free_draw") > 0

# ---------------------------------------------------------------------------
# Characters (roster data lives in CharacterData.gd)
# ---------------------------------------------------------------------------
func is_character_unlocked(id: String) -> bool:
	return id in unlocked_characters

func can_buy_character(id: String) -> bool:
	return not is_character_unlocked(id) and giblets >= CharacterData.CHARACTERS[id]["cost"]

func buy_character(id: String) -> bool:
	if not can_buy_character(id):
		return false
	giblets -= int(CharacterData.CHARACTERS[id]["cost"])
	unlocked_characters.append(id)
	# A character's signature upgrades join the level-up rotation with them —
	# their draw bias must never point at upgrades locked out of the pool.
	for upgrade_id: String in CharacterData.CHARACTERS[id]["draw_bias"]:
		if upgrade_id not in unlocked_upgrades:
			unlocked_upgrades.append(upgrade_id)
	_save()
	return true

func select_character(id: String) -> void:
	if is_character_unlocked(id):
		selected_character = id
		_save()

func select_stage(id: String) -> void:
	if id in StageData.STAGES:
		selected_stage = id
		_save()

# ---------------------------------------------------------------------------
# End-of-run upgrade roulette
# ---------------------------------------------------------------------------
func is_upgrade_unlocked(id: String) -> bool:
	return id in unlocked_upgrades

func locked_upgrade_pool() -> Array:
	var pool: Array = []
	for u in UpgradeData.ALL_UPGRADES:
		if u.get("locked_by_default", false) and u["id"] not in unlocked_upgrades:
			pool.append(u)
	return pool

func run_earned_spin() -> bool:
	return (GameState.elapsed_time >= 300.0 or GameState.bosses_killed >= 1) \
		and not locked_upgrade_pool().is_empty()

# Rarity-weighted draw from the still-locked pool; unlocks and returns the
# entry ({} if nothing left). Legendaries land rarely (weight 3 vs common 45).
func roll_unlock() -> Dictionary:
	var pool := locked_upgrade_pool()
	if pool.is_empty():
		return {}
	var total := 0
	for u in pool:
		total += int(UpgradeData.RARITY_WEIGHTS.get(u["rarity"], 1))
	var roll := randi() % total
	var acc := 0
	for u in pool:
		acc += int(UpgradeData.RARITY_WEIGHTS.get(u["rarity"], 1))
		if roll < acc:
			unlocked_upgrades.append(u["id"])
			_save()
			return u
	return {}

# ---------------------------------------------------------------------------
# Persistence
# ---------------------------------------------------------------------------
func _save() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_var({
			"version": SAVE_VERSION,
			"giblets": giblets,
			"ranks": ranks,
			"selected_character": selected_character,
			"selected_stage": selected_stage,
			"unlocked_characters": unlocked_characters,
			"unlocked_upgrades": unlocked_upgrades,
		})
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
			# v1 saves carry only giblets+ranks; the 5 old unlock ids (hp,
			# damage, speed, magnet, xp) are reused verbatim as talent ids, so
			# ranks migrate with no translation. New fields fall back to
			# defaults — the roulette pool starts locked for everyone.
			selected_character = str(data.get("selected_character", "ghoul"))
			var uc = data.get("unlocked_characters", ["ghoul"])
			if uc is Array and not uc.is_empty():
				unlocked_characters = uc
			var uu = data.get("unlocked_upgrades", [])
			if uu is Array:
				unlocked_upgrades = uu
			if "ghoul" not in unlocked_characters:
				unlocked_characters.append("ghoul")
			if selected_character not in unlocked_characters:
				selected_character = "ghoul"
			selected_stage = str(data.get("selected_stage", "default"))
			if selected_stage not in StageData.STAGES:
				selected_stage = "default"
