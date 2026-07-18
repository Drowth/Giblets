class_name CharacterData

# Playable character roster (docs/BALANCE.md §6, docs/DESIGN.md).
# Each character is a data problem, not a scene problem: Player.tscn stays the
# single player scene; GameState._reset() applies `deltas` (additive bumps to
# the base-stat floors) and `passive` (starting values for stats that normally
# begin at zero), and Player.gd swaps the sprite. `draw_bias` multiplies that
# character's signature upgrades' weight inside the level-up draw
# (UpgradeData.get_random_choices) — flavor, not raw power.
#
# Passives are the only sanctioned benders of the "additive-to-base only" meta
# rule (a starting crit chance / sentry / lifesteal), each paid for with a
# stat delta and validated against the BalanceSim death-time distribution.
#
# Unlock state and selection persist in Meta (unlocked_characters /
# selected_character). Buying a character also unlocks its draw_bias upgrade
# ids into the level-up rotation (Meta.buy_character).

const DRAW_BIAS_WEIGHT := 3.0  # signature upgrades are 3× as likely within their rarity

const CHARACTERS: Dictionary = {
	"ghoul": {
		# id kept as "ghoul" for save compatibility; renamed with the animated
		# 8-directional Wizard sprite set (WizardFrames.gd).
		"name": "The Wizard",
		"desc": "The classic. Robes and all.",
		"cost": 0,
		"animated": true,
		"sprite_path": "res://assets/player/wizard/idle/S/001.png",  # select-card portrait
		"sprite_scale": 0.7,    # 128px HD frames; figure ~80px tall
		"deltas": {},
		"passive": {},
		"passive_desc": "",
		"draw_bias": {},
	},
	"reaper": {
		"name": "The Reaper",
		"desc": "Dash through enemies to charm them. They fight for you.",
		"cost": 80,
		"animated": true,
		"sprite_path": "res://assets/player/reaper/idle/S/001.png",  # select-card portrait
		"sprite_scale": 0.7,    # 128px HD frames
		"deltas": {"max_health": -20},
		"passive": {"crit_chance": 0.10},
		"passive_desc": "Starts with 10% crit chance. Dashing through non-boss enemies charms them for 5s",
		"draw_bias": {"crit_1": DRAW_BIAS_WEIGHT, "crit_2": DRAW_BIAS_WEIGHT, "leg_crit": DRAW_BIAS_WEIGHT},
	},
	"necromancer": {
		"name": "The Necromancer",
		"desc": "Weak of arm, strong of servant.",
		"cost": 140,
		"animated": true,
		"sprite_path": "res://assets/player/necromancer/idle/S/001.png",  # select-card portrait
		"sprite_scale": 0.7,    # 128px HD frames, matches the Reaper set
		"deltas": {"projectile_damage": -4},
		"passive": {"sentry_count": 1, "dash_damage_pct": 0.5},
		"passive_desc": "Starts with a Bone Sentry. Dashing through enemies deals 50% weapon damage; a killing dash-hit binds the soul into a temporary Bone Sentry for 12s (max 3 active)",
		"draw_bias": {"sentry_1": DRAW_BIAS_WEIGHT, "leg_summon": DRAW_BIAS_WEIGHT, "dash_damage": DRAW_BIAS_WEIGHT},
	},
	"vampire": {
		"name": "The Vampire",
		"desc": "Slow, stout, and always feeding.",
		"cost": 220,
		"sprite_path": "res://assets/player/player3.png",
		"sprite_scale": 0.12,
		"deltas": {"max_health": 20, "move_speed": -15},
		"passive": {"lifesteal_per_kill": 1, "exsanguinate_enabled": 1.0},
		"passive_desc": "Heals 1 HP on every kill. Every 8th kill detonates a blood nova, dealing AoE damage and healing 25% of the damage dealt",
		"draw_bias": {"lifesteal_1": DRAW_BIAS_WEIGHT, "regen_1": DRAW_BIAS_WEIGHT, "leg_sustain": DRAW_BIAS_WEIGHT},
	},
}

static func get_selected() -> Dictionary:
	return CHARACTERS.get(Meta.selected_character, CHARACTERS["ghoul"])
