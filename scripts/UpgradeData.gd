class_name UpgradeData

# WoW item quality colours
const RARITY_COLORS: Dictionary = {
	"common":    Color(1.000, 1.000, 1.000),  # #ffffff
	"uncommon":  Color(0.118, 1.000, 0.000),  # #1eff00
	"rare":      Color(0.000, 0.439, 0.867),  # #0070dd
	"epic":      Color(0.639, 0.208, 0.933),  # #a335ee
	"legendary": Color(1.000, 0.502, 0.000),  # #ff8000
}

const ALL_UPGRADES: Array[Dictionary] = [
	{
		"id": "speed_1", "name": "Fleet Feet", "rarity": "common",
		"description": "Move 20% faster through the carnage",
		"color": Color(0.2, 0.8, 1.0),
		"stat": "move_speed", "multiplier": 1.2
	},
	{
		"id": "damage_1", "name": "Bloodlust", "rarity": "common",
		"description": "+5 damage. More gore for your glory",
		"color": Color(1.0, 0.15, 0.15),
		"stat": "projectile_damage", "add": 5
	},
	{
		"id": "fire_rate_1", "name": "Frenzy", "rarity": "common",
		"description": "Fire 25% faster",
		"color": Color(1.0, 0.6, 0.1),
		"stat": "fire_rate", "multiplier": 1.25
	},
	{
		"id": "proj_speed_1", "name": "Velocity", "rarity": "common",
		"description": "Projectiles travel 30% faster",
		"color": Color(0.8, 0.8, 0.2),
		"stat": "projectile_speed", "multiplier": 1.3
	},
	{
		"id": "magnet_1", "name": "Soul Draw", "rarity": "common",
		"description": "XP orbs drawn from 50% farther away",
		"color": Color(0.5, 1.0, 0.3),
		"stat": "xp_magnet_range", "multiplier": 1.5
	},
	{
		"id": "max_hp_1", "name": "Iron Flesh", "rarity": "common",
		"description": "+25 max health and partial heal",
		"color": Color(0.9, 0.4, 0.4),
		"stat": "max_health", "add": 25
	},
	{
		"id": "multishot_1", "name": "Twin Barrage", "rarity": "rare",
		"description": "Fire an extra projectile per shot",
		"color": Color(0.8, 0.2, 1.0),
		"stat": "projectile_count", "add": 1
	},
	{
		"id": "pierce_1", "name": "Impale", "rarity": "rare",
		"description": "Projectiles pierce through 1 enemy",
		"color": Color(0.3, 0.3, 1.0),
		"stat": "projectile_pierce", "add": 1
	},
	{
		"id": "speed_2", "name": "Shadow Dash", "rarity": "uncommon",
		"description": "Move 30% faster",
		"color": Color(0.1, 0.6, 0.9),
		"stat": "move_speed", "multiplier": 1.3
	},
	{
		"id": "damage_2", "name": "Gore Storm", "rarity": "uncommon",
		"description": "+10 damage. Painting the walls red",
		"color": Color(0.9, 0.0, 0.0),
		"stat": "projectile_damage", "add": 10
	},
	{
		"id": "fire_rate_2", "name": "Berserker", "rarity": "uncommon",
		"description": "Fire 40% faster",
		"color": Color(1.0, 0.4, 0.0),
		"stat": "fire_rate", "multiplier": 1.4
	},
	{
		"id": "max_hp_2", "name": "Undying Flesh", "rarity": "uncommon",
		"description": "+50 max health and full heal",
		"color": Color(1.0, 0.2, 0.2),
		"stat": "max_health", "add": 50
	},
	{
		"id": "knockback_1", "name": "Soul Repel", "rarity": "rare",
		"description": "Strikes send enemies reeling backward",
		"color": Color(0.55, 0.15, 1.0),
		"stat": "knockback_force", "add": 220
	},
	{
		"id": "knockback_2", "name": "Banishment", "rarity": "uncommon",
		"description": "Knockback grows more savage — enemies flung further",
		"color": Color(0.7, 0.1, 1.0),
		"stat": "knockback_force", "add": 180
	},
	{
		"id": "sentry_1", "name": "Osseous Sentinel", "rarity": "epic",
		"description": "An undying skull rises at your feet, its eyes burning with arcane hunger",
		"color": Color(0.35, 0.08, 0.50),
		"icon_path": "res://assets/pickups/sentinel.png",
		"stat": "spawn_sentry"
	},
	{
		"id": "dash_cd_1", "name": "Afterburn", "rarity": "uncommon",
		"description": "Dash cooldown reduced by 20% — blink more, die less",
		"color": Color(0.2, 0.9, 1.0),
		"stat": "dash_cooldown_mul", "multiplier": 0.8
	},
	{
		"id": "dash_dist_1", "name": "Ghost Step", "rarity": "rare",
		"description": "Dash covers 35% more ground in a single bound",
		"color": Color(0.55, 0.15, 1.0),
		"stat": "dash_distance_mul", "multiplier": 1.35
	},
	{
		"id": "dash_knock_1", "name": "Shockwave", "rarity": "epic",
		"description": "Your dash erupts outward — enemies are flung twice as hard",
		"color": Color(0.9, 0.1, 0.95),
		"stat": "dash_knockback_mul", "multiplier": 2.0
	},
]

static func get_random_choices(count: int = 3) -> Array[Dictionary]:
	var pool := ALL_UPGRADES.duplicate()
	pool.shuffle()
	return pool.slice(0, mini(count, pool.size()))

static func apply_upgrade(upgrade: Dictionary) -> void:
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
		"spawn_sentry":
			GameState.sentry_count += 1
			GameState.sentry_summoned.emit()
