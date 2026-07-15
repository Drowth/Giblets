class_name UpgradeData

# Upgrade pool, rarity weights, and apply logic.
# Rarity is assigned from each upgrade's power score band and selection weight
# from rarity — see docs/BALANCE.md §5. Power decides rarity, never feel.

# WoW item quality colours
const RARITY_COLORS: Dictionary = {
	"common":    Color(1.000, 1.000, 1.000),  # #ffffff
	"uncommon":  Color(0.118, 1.000, 0.000),  # #1eff00
	"rare":      Color(0.000, 0.439, 0.867),  # #0070dd
	"epic":      Color(0.639, 0.208, 0.933),  # #a335ee
	"legendary": Color(1.000, 0.502, 0.000),  # #ff8000
}

# Selection weights per rarity. Expected power gain per pick ≈ +22%, the
# number the DPS budget in docs/BALANCE.md §1 is built on.
const RARITY_WEIGHTS: Dictionary = {
	"common":    45,
	"uncommon":  30,
	"rare":      15,
	"epic":      7,
	"legendary": 3,
}

# "power" = expected % gain in run-winning power (documented, drives rarity).
# "max_stacks" caps how many times an upgrade can be taken in one run.
const ALL_UPGRADES: Array[Dictionary] = [
	# ---- common (P ≤ 15) --------------------------------------------------
	{
		"id": "speed_1", "name": "Fleet Feet", "rarity": "common", "power": 9,
		"description": "Move 15% faster through the carnage",
		"color": Color(0.2, 0.8, 1.0),
		"stat": "move_speed", "multiplier": 1.15
	},
	{
		"id": "damage_1", "name": "Bloodlust", "rarity": "common", "power": 12,
		"description": "+4 damage. More gore for your glory",
		"color": Color(1.0, 0.15, 0.15),
		"stat": "projectile_damage", "add": 4
	},
	{
		"id": "fire_rate_1", "name": "Frenzy", "rarity": "common", "power": 14,
		"description": "Fire 20% faster",
		"color": Color(1.0, 0.6, 0.1),
		"stat": "fire_rate", "multiplier": 1.2
	},
	{
		"id": "proj_speed_1", "name": "Velocity", "rarity": "common", "power": 8,
		"description": "Projectiles travel 25% faster",
		"color": Color(0.8, 0.8, 0.2),
		"stat": "projectile_speed", "multiplier": 1.25, "max_stacks": 4
	},
	{
		"id": "magnet_1", "name": "Soul Draw", "rarity": "common", "power": 7,
		"description": "XP orbs drawn from 50% farther away",
		"color": Color(0.5, 1.0, 0.3),
		"stat": "xp_magnet_range", "multiplier": 1.5, "max_stacks": 4
	},
	{
		"id": "max_hp_1", "name": "Iron Flesh", "rarity": "common", "power": 10,
		"description": "+20 max health and partial heal",
		"color": Color(0.9, 0.4, 0.4),
		"stat": "max_health", "add": 20
	},
	{
		"id": "armor_1", "name": "Thick Hide", "rarity": "common", "power": 11,
		"description": "+1 armor — every hit hurts a little less",
		"color": Color(0.6, 0.5, 0.35),
		"stat": "armor", "add": 1, "max_stacks": 5
	},
	{
		"id": "xp_gain_1", "name": "Scavenger", "rarity": "common", "power": 13,
		"description": "+10% XP from every soul",
		"color": Color(0.4, 1.0, 0.6),
		"stat": "xp_gain_mult", "multiplier": 1.1, "max_stacks": 5
	},
	# ---- uncommon (15 < P ≤ 25) --------------------------------------------
	{
		"id": "speed_2", "name": "Shadow Dash", "rarity": "uncommon", "power": 16,
		"description": "Move 25% faster",
		"color": Color(0.1, 0.6, 0.9),
		"stat": "move_speed", "multiplier": 1.25
	},
	{
		"id": "damage_2", "name": "Gore Storm", "rarity": "uncommon", "power": 20,
		"description": "+8 damage. Painting the walls red",
		"color": Color(0.9, 0.0, 0.0),
		"stat": "projectile_damage", "add": 8
	},
	{
		"id": "fire_rate_2", "name": "Berserker", "rarity": "uncommon", "power": 21,
		"description": "Fire 30% faster",
		"color": Color(1.0, 0.4, 0.0),
		"stat": "fire_rate", "multiplier": 1.3
	},
	{
		"id": "max_hp_2", "name": "Undying Flesh", "rarity": "uncommon", "power": 18,
		"description": "+40 max health and full heal",
		"color": Color(1.0, 0.2, 0.2),
		"stat": "max_health_full_heal", "add": 40
	},
	{
		"id": "knockback_2", "name": "Banishment", "rarity": "uncommon", "power": 16,
		"description": "Knockback grows more savage — enemies flung further",
		"color": Color(0.7, 0.1, 1.0),
		"stat": "knockback_force", "add": 180
	},
	{
		"id": "dash_cd_1", "name": "Afterburn", "rarity": "uncommon", "power": 17,
		"description": "Dash cooldown reduced by 20% — blink more, die less",
		"color": Color(0.2, 0.9, 1.0),
		"stat": "dash_cooldown_mul", "multiplier": 0.8, "max_stacks": 4
	},
	{
		"id": "regen_1", "name": "Regrowth", "rarity": "uncommon", "power": 19,
		"description": "Slowly knit flesh: +2 HP every 5 seconds",
		"color": Color(0.3, 0.9, 0.4),
		"stat": "regen_per_5s", "add": 2.0, "max_stacks": 4
	},
	{
		"id": "crit_1", "name": "Keen Edge", "rarity": "uncommon", "power": 20,
		"description": "+8% chance to strike critically for double damage",
		"color": Color(1.0, 0.9, 0.3),
		"stat": "crit_chance", "add": 0.08
	},
	# ---- rare (25 < P ≤ 40) -------------------------------------------------
	{
		"id": "multishot_1", "name": "Twin Barrage", "rarity": "rare", "power": 35,
		"description": "Fire an extra projectile per shot",
		"color": Color(0.8, 0.2, 1.0),
		"stat": "projectile_count", "add": 1
	},
	{
		"id": "pierce_1", "name": "Impale", "rarity": "rare", "power": 30,
		"description": "Projectiles pierce through 1 enemy",
		"color": Color(0.3, 0.3, 1.0),
		"stat": "projectile_pierce", "add": 1, "max_stacks": 6
	},
	{
		"id": "knockback_1", "name": "Soul Repel", "rarity": "rare", "power": 26,
		"description": "Strikes send enemies reeling backward",
		"color": Color(0.55, 0.15, 1.0),
		"stat": "knockback_force", "add": 220
	},
	{
		"id": "dash_dist_1", "name": "Ghost Step", "rarity": "rare", "power": 26,
		"description": "Dash covers 35% more ground in a single bound",
		"color": Color(0.55, 0.15, 1.0),
		"stat": "dash_distance_mul", "multiplier": 1.35, "max_stacks": 3
	},
	{
		"id": "damage_mul_1", "name": "Heavy Calibre", "rarity": "rare", "power": 35,
		"description": "All damage increased by 35%",
		"color": Color(0.8, 0.1, 0.1),
		"stat": "damage_mul", "multiplier": 1.35
	},
	{
		"id": "crit_2", "name": "Executioner", "rarity": "rare", "power": 30,
		"description": "+12% critical strike chance",
		"color": Color(1.0, 0.8, 0.1),
		"stat": "crit_chance", "add": 0.12
	},
	{
		"id": "lifesteal_1", "name": "Vampiric Strikes", "rarity": "rare", "power": 28,
		"description": "Every kill restores 1 health",
		"color": Color(0.7, 0.05, 0.25),
		"stat": "lifesteal_per_kill", "add": 1, "max_stacks": 3
	},
	# ---- epic (40 < P ≤ 60) ---------------------------------------------------
	{
		"id": "sentry_1", "name": "Osseous Sentinel", "rarity": "epic", "power": 45,
		"description": "An undying skull rises at your feet, its eyes burning with arcane hunger",
		"color": Color(0.35, 0.08, 0.50),
		"icon_path": "res://assets/pickups/sentinel.png",
		"stat": "spawn_sentry", "max_stacks": 3
	},
	{
		"id": "dash_knock_1", "name": "Shockwave", "rarity": "epic", "power": 42,
		"description": "Your dash erupts outward — enemies are flung twice as hard",
		"color": Color(0.9, 0.1, 0.95),
		"stat": "dash_knockback_mul", "multiplier": 2.0, "max_stacks": 2
	},
	{
		"id": "multishot_2", "name": "Overload", "rarity": "epic", "power": 60,
		"description": "Fire TWO extra projectiles per shot",
		"color": Color(0.9, 0.3, 1.0),
		"stat": "projectile_count", "add": 2
	},
	{
		"id": "fire_rate_3", "name": "Adrenaline", "rarity": "epic", "power": 45,
		"description": "Fire 50% faster",
		"color": Color(1.0, 0.3, 0.0),
		"stat": "fire_rate", "multiplier": 1.5, "max_stacks": 2
	},
	{
		"id": "max_hp_3", "name": "Titan's Vigor", "rarity": "epic", "power": 44,
		"description": "+80 max health and +2 armor",
		"color": Color(1.0, 0.5, 0.4),
		"stat": "titan_vigor"
	},
	# ---- legendary (P > 60): build-defining -----------------------------------
	{
		"id": "leg_crit", "name": "Deathmark", "rarity": "legendary", "power": 85,
		"description": "+25% crit chance and crits deal TRIPLE damage",
		"color": Color(1.0, 0.85, 0.0),
		"stat": "deathmark", "max_stacks": 1
	},
	{
		"id": "leg_aoe", "name": "Hellfire Rounds", "rarity": "legendary", "power": 90,
		"description": "Every hit detonates, burning nearby enemies for 60% damage",
		"color": Color(1.0, 0.35, 0.0),
		"stat": "hellfire", "max_stacks": 1
	},
	{
		"id": "leg_summon", "name": "Bone Legion", "rarity": "legendary", "power": 80,
		"description": "TWO more sentinels rise — and all sentinels strike at full power",
		"color": Color(0.8, 0.75, 0.6),
		"icon_path": "res://assets/pickups/sentinel.png",
		"stat": "bone_legion", "max_stacks": 1
	},
	{
		"id": "leg_sustain", "name": "Gorefeast", "rarity": "legendary", "power": 75,
		"description": "Devour the fallen: +3 health per kill and +25% move speed",
		"color": Color(0.9, 0.1, 0.3),
		"stat": "gorefeast", "max_stacks": 1
	},
]

# Crit chance is capped so the crit build converges instead of hitting 100%.
const CRIT_CHANCE_CAP := 0.6
const PROJECTILE_COUNT_CAP := 8

static func _is_available(upgrade: Dictionary) -> bool:
	var stacks: int = GameState.upgrade_stacks.get(upgrade["id"], 0)
	if stacks >= int(upgrade.get("max_stacks", 999)):
		return false
	# Derived caps that span multiple upgrade ids
	match upgrade.get("stat", ""):
		"crit_chance":
			return GameState.crit_chance < CRIT_CHANCE_CAP
		"projectile_count":
			return GameState.projectile_count < PROJECTILE_COUNT_CAP
	return true

static func get_random_choices(count: int = 3) -> Array[Dictionary]:
	# Weighted draw: roll rarity by RARITY_WEIGHTS, then uniform within that
	# rarity's still-available entries. Re-roll if a tier is exhausted.
	var by_rarity: Dictionary = {}
	for u in ALL_UPGRADES:
		if _is_available(u):
			var r: String = u["rarity"]
			if not by_rarity.has(r):
				by_rarity[r] = []
			by_rarity[r].append(u)

	var choices: Array[Dictionary] = []
	var picked_ids: Array = []
	for _i in count:
		var pool := _roll_rarity_pool(by_rarity, picked_ids)
		if pool.is_empty():
			break
		var pick: Dictionary = pool.pick_random()
		picked_ids.append(pick["id"])
		choices.append(pick)
	return choices

static func _roll_rarity_pool(by_rarity: Dictionary, exclude: Array) -> Array:
	var total := 0
	for r in RARITY_WEIGHTS:
		total += RARITY_WEIGHTS[r]
	for _attempt in 12:
		var roll := randi() % total
		var acc := 0
		var chosen := "common"
		for r in RARITY_WEIGHTS:
			acc += RARITY_WEIGHTS[r]
			if roll < acc:
				chosen = r
				break
		var pool: Array = []
		for u in by_rarity.get(chosen, []):
			if u["id"] not in exclude:
				pool.append(u)
		if not pool.is_empty():
			return pool
	# Fallback: anything still available
	var rest: Array = []
	for r in by_rarity:
		for u in by_rarity[r]:
			if u["id"] not in exclude:
				rest.append(u)
	return rest

static func apply_upgrade(upgrade: Dictionary) -> void:
	var id: String = upgrade["id"]
	GameState.upgrade_stacks[id] = GameState.upgrade_stacks.get(id, 0) + 1
	match upgrade.get("stat", ""):
		"move_speed":
			if upgrade.has("multiplier"):
				GameState.move_speed *= upgrade["multiplier"]
			else:
				GameState.move_speed += upgrade.get("add", 0)
		"projectile_damage":
			GameState.projectile_damage += upgrade.get("add", 0)
		"fire_rate":
			GameState.fire_rate *= upgrade.get("multiplier", 1.0)
		"projectile_speed":
			GameState.projectile_speed *= upgrade.get("multiplier", 1.0)
		"xp_magnet_range":
			GameState.xp_magnet_range *= upgrade.get("multiplier", 1.0)
		"max_health":
			GameState.increase_max_health(upgrade.get("add", 0))
		"max_health_full_heal":
			GameState.increase_max_health(upgrade.get("add", 0))
			GameState.heal(GameState.player_max_health)
		"projectile_count":
			GameState.projectile_count += upgrade.get("add", 0)
		"projectile_pierce":
			GameState.projectile_pierce += upgrade.get("add", 0)
		"knockback_force":
			GameState.knockback_force += upgrade.get("add", 0)
		"dash_cooldown_mul":
			GameState.dash_cooldown_mul *= upgrade.get("multiplier", 1.0)
		"dash_distance_mul":
			GameState.dash_distance_mul *= upgrade.get("multiplier", 1.0)
		"dash_knockback_mul":
			GameState.dash_knockback_mul *= upgrade.get("multiplier", 1.0)
		"armor":
			GameState.armor += upgrade.get("add", 0)
		"xp_gain_mult":
			GameState.xp_gain_mult *= upgrade.get("multiplier", 1.0)
		"regen_per_5s":
			GameState.regen_per_5s += upgrade.get("add", 0.0)
		"crit_chance":
			GameState.crit_chance = minf(GameState.crit_chance + upgrade.get("add", 0.0), CRIT_CHANCE_CAP)
		"damage_mul":
			GameState.damage_mul *= upgrade.get("multiplier", 1.0)
		"lifesteal_per_kill":
			GameState.lifesteal_per_kill += upgrade.get("add", 0)
		"titan_vigor":
			GameState.increase_max_health(80)
			GameState.armor += 2
		"spawn_sentry":
			GameState.sentry_count += 1
			GameState.sentry_summoned.emit()
		"deathmark":
			GameState.crit_chance = minf(GameState.crit_chance + 0.25, CRIT_CHANCE_CAP)
			GameState.crit_mult = 3.0
		"hellfire":
			GameState.explosive_pct = 0.6
		"bone_legion":
			GameState.sentry_damage_mul = 1.0
			for _i in 2:
				GameState.sentry_count += 1
				GameState.sentry_summoned.emit()
		"gorefeast":
			GameState.lifesteal_per_kill += 3
			GameState.move_speed *= 1.25
