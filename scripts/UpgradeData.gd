class_name UpgradeData

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
