extends Node

# Headless balance simulation harness (Phase 4, docs/BALANCE.md).
#
# Run:
#   "C:\Claude\REPOS\Games\Giblets\Godot_v4.7-stable_win64.exe" --path . --headless res://scenes/BalanceSim.tscn
#
# Simulates N synthetic runs at SIM_DT resolution. Progression is REAL code:
# GameState.add_xp / xp_required / upgrade_stacks and UpgradeData's weighted
# get_random_choices()/apply_upgrade() are exercised directly, so any change
# to the XP curve or the upgrade pool is automatically reflected here.
# Combat is an analytic horde model calibrated against the constants in
# Main.gd (spawn curve, per-archetype stats, overtime ramp, boss formula).

const RUNS      := 100
const SIM_DT    := 0.5           # seconds per tick
const SIM_LIMIT := 30.0 * 60.0   # give up and call it "survived" at 30 min

# Combat-model coefficients (sim-only; not game constants).
const PROJ_EFF      := 0.65  # marginal horde value of each extra projectile
const PIERCE_EFF    := 0.45  # marginal horde value of each pierce
const HELLFIRE_EFF  := 0.80  # horde uptime of the explosion splash
const RICOCHET_EFF  := 0.35  # marginal horde value of each Wishbone bounce
const REAR_SHOT_EFF := 0.25  # horde value of the backwards bonus shot
const BLOODLUST_AVG := 0.30  # average Bloodlust uptime bonus (cap is +0.50)
# Calibrated against a live playtest (player at full HP, L10, minute 4 with
# sub-20 live enemies): kiting + dash knockback make small hordes nearly
# harmless. Contact damage only lands once the screen saturates — below
# SATURATION_SAFE of the live cap the horde is dodgeable noise.
const SATURATION_SAFE    := 0.55 # fraction of MAX_LIVE_ENEMIES that is freely kitable
const SATURATION_DPS_MUL := 3.5  # contact DPS multiplier at full saturation
# Boss contact: a 52 px/s boss cannot catch a 200 px/s player in open space;
# it lands hits when the horde pins the player, so its hit rate rides on
# saturation with only a tiny base rate for positioning mistakes.
const BOSS_HIT_BASE := 0.01  # hits/s worth of boss damage while freely kiting
const BOSS_HIT_SAT  := 0.10  # additional hits/s at full horde saturation

var MAIN := preload("res://scripts/Main.gd")

# Sim-only: approximates the in-run combo multiplier for score accrual
# (builds fast in hordes, capped ×2 — see GameState.add_kill_score).
const SIM_COMBO_MUL := 1.5

func _ready() -> void:
	# Meta A/B profiles: fields are set directly (never through buy()/earn(),
	# which would persist to user://meta.save) and restored afterwards.
	var snapshot := _snapshot_meta()
	var profiles: Array[Dictionary] = [
		{"label": "BASELINE — no talents, starting pool, Ghoul", "maxed": false, "character": "ghoul"},
		{"label": "MAXED TALENTS — full pool, Ghoul",            "maxed": true,  "character": "ghoul"},
		{"label": "MAXED TALENTS — full pool, Reaper",           "maxed": true,  "character": "reaper"},
		{"label": "MAXED TALENTS — full pool, Necromancer",      "maxed": true,  "character": "necromancer"},
		{"label": "MAXED TALENTS — full pool, Paladin",          "maxed": true,  "character": "paladin"},
	]
	for profile in profiles:
		_apply_profile(profile)
		_run_batch(profile["label"])
	_restore_meta(snapshot)
	get_tree().quit()

func _snapshot_meta() -> Dictionary:
	return {
		"giblets": Meta.giblets,
		"ranks": Meta.ranks.duplicate(),
		"selected_character": Meta.selected_character,
		"unlocked_characters": Meta.unlocked_characters.duplicate(),
		"unlocked_upgrades": Meta.unlocked_upgrades.duplicate(),
	}

func _restore_meta(s: Dictionary) -> void:
	Meta.giblets = s["giblets"]
	Meta.ranks = s["ranks"]
	Meta.selected_character = s["selected_character"]
	Meta.unlocked_characters = s["unlocked_characters"]
	Meta.unlocked_upgrades = s["unlocked_upgrades"]

func _apply_profile(profile: Dictionary) -> void:
	if profile["maxed"]:
		var all_ranks := {}
		for id: String in Meta.TALENTS:
			all_ranks[id] = int(Meta.TALENTS[id]["max"])
		Meta.ranks = all_ranks
		var full_pool: Array = []
		for u in UpgradeData.ALL_UPGRADES:
			if u.get("locked_by_default", false):
				full_pool.append(u["id"])
		Meta.unlocked_upgrades = full_pool
	else:
		Meta.ranks = {}
		Meta.unlocked_upgrades = []
	Meta.unlocked_characters = CharacterData.CHARACTERS.keys()
	Meta.selected_character = profile["character"]

func _run_batch(label: String) -> void:
	var death_times: Array[float] = []
	var final_levels: Array[int] = []
	var final_dps: Array[float] = []
	var boss_ttks: Array[float] = []
	var giblet_yields: Array[int] = []
	var dps_samples := {1: [], 5: [], 10: [], 15: [], 20: []}

	print("\n########  %s  ########" % label)
	for run in RUNS:
		var result := _simulate_run(dps_samples, boss_ttks)
		death_times.append(result["time"])
		final_levels.append(result["level"])
		final_dps.append(result["dps"])
		giblet_yields.append(result["giblets"])
		if (run + 1) % 20 == 0:
			print("... %d/%d runs done" % [run + 1, RUNS])

	_report(death_times, final_levels, final_dps, boss_ttks, dps_samples)
	giblet_yields.sort()
	var g_sum := 0
	for g in giblet_yields: g_sum += g
	print("Giblet yield/run: median %d   p10 %d   p90 %d   avg %.1f" % [
		giblet_yields[giblet_yields.size() / 2],
		giblet_yields[giblet_yields.size() / 10],
		giblet_yields[giblet_yields.size() * 9 / 10],
		float(g_sum) / giblet_yields.size()])

func _simulate_run(dps_samples: Dictionary, boss_ttks: Array[float]) -> Dictionary:
	GameState.start_game()
	# Start-of-run talent hooks normally applied by Main._ready()
	if Meta.has_free_draw():
		var u := UpgradeData.get_random_by_rarity("common")
		if not u.is_empty():
			UpgradeData.apply_upgrade(u)
	if Meta.has_head_start():
		GameState.add_xp(GameState.xp_to_next_level)
		_consume_level_ups()
	var t := 0.0
	var sampled := {}
	var live := 0.0
	var boss_hp := 0.0
	var boss_dmg := 0.0
	var next_boss_at: float = MAIN.BOSS_INTERVAL
	var boss_index := 0
	var boss_start := 0.0

	while t < SIM_LIMIT and GameState.player_health > 0:
		t += SIM_DT
		GameState.elapsed_time = t
		var m := t / 60.0

		# --- player offense (reads real GameState stats)
		var single := _single_target_dps()
		var horde_dps := single \
			* (1.0 + PROJ_EFF * (GameState.projectile_count - 1)) \
			* (1.0 + PIERCE_EFF * GameState.projectile_pierce) \
			* (1.0 + GameState.explosive_pct * HELLFIRE_EFF) \
			* (1.0 + RICOCHET_EFF * GameState.ricochet_bounces) \
			* (1.0 + (REAR_SHOT_EFF if GameState.rear_shot else 0.0)) \
			* (1.0 + (BLOODLUST_AVG if GameState.bloodlust else 0.0)) \
			+ single * GameState.sentry_count * GameState.sentry_damage_mul

		# --- enemy population
		var spawn_rate := _spawn_rate(m)
		var avg := _avg_enemy(m)
		var boss_active := boss_hp > 0.0

		var dps_to_horde := horde_dps
		if boss_active:
			# While the horde is sparse, auto-aim naturally focuses the boss
			# (it chases, so it is usually nearest): designed focus factor.
			# Once the screen fills, the player holds the horde first and the
			# boss fight stretches — weak builds bleed instead of insta-dying.
			var boss_dps: float
			var sat_now: float = live / float(MAIN.MAX_LIVE_ENEMIES)
			if sat_now < SATURATION_SAFE * 0.75:
				boss_dps = horde_dps * MAIN.BOSS_FOCUS_FACTOR
				dps_to_horde = horde_dps * (1.0 - MAIN.BOSS_FOCUS_FACTOR)
			else:
				var hold_horde: float = minf(horde_dps * 0.85, spawn_rate * avg["hp"])
				boss_dps = maxf(horde_dps - hold_horde, horde_dps * 0.15) * MAIN.BOSS_FOCUS_FACTOR
				dps_to_horde = hold_horde
			boss_hp -= boss_dps * SIM_DT
			if boss_hp <= 0.0:
				boss_ttks.append(t - boss_start)
				GameState.add_xp(int(GameState.xp_to_next_level * 0.9))
				GameState.enemies_killed += 1
				GameState.bosses_killed += 1
				# Boss score value is 500 (Main.gd boss spawn)
				GameState.score += int(500 * GameState.player_level * SIM_COMBO_MUL)
				# Boss drops a fire bomb: picking it up wipes the live horde
				live = 0.0

		var kill_capacity: float = dps_to_horde / avg["hp"]
		var kills: float = minf(kill_capacity * SIM_DT, live)
		if live < MAIN.MAX_LIVE_ENEMIES:
			live += spawn_rate * SIM_DT
		live = clampf(live - kills, 0.0, MAIN.MAX_LIVE_ENEMIES)

		# --- XP income through the real pipeline
		if kills > 0.0:
			GameState.enemies_killed += int(kills)
			GameState.add_xp(int(kills * avg["xp"]))
			# Score mirrors add_kill_score: enemy_xp × level × combo (≈1.5 avg)
			GameState.score += int(kills * avg["xp"] * GameState.player_level * SIM_COMBO_MUL)
			if GameState.lifesteal_per_kill > 0:
				GameState.heal(int(kills) * GameState.lifesteal_per_kill)
		_consume_level_ups()

		# --- incoming damage
		var saturation: float = live / float(MAIN.MAX_LIVE_ENEMIES)
		var eff_threat: float = maxf(0.0, saturation - SATURATION_SAFE) / (1.0 - SATURATION_SAFE)
		var kite := clampf(GameState.move_speed / 200.0, 0.8, 1.6)
		var dps_in: float = avg["dmg"] * eff_threat * eff_threat * SATURATION_DPS_MUL / kite
		if boss_active:
			dps_in += boss_dmg * (BOSS_HIT_BASE + BOSS_HIT_SAT * saturation)
		# armor reduces each hit; hits/s approximated from average enemy damage
		if dps_in > 0.0:
			var hits_per_s: float = dps_in / maxf(avg["dmg"], 1.0)
			# Player i-frames (0.6s) cap how often ANY damage can land
			hits_per_s = minf(hits_per_s, 1.0 / 0.6)
			var per_hit: float = maxf(1.0, avg["dmg"] - GameState.armor)
			dps_in = hits_per_s * per_hit
		# Bone Broth heals per orb picked up; orbs ≈ kills, so fold into regen
		var regen := GameState.regen_per_5s / 5.0 + GameState.orb_heal * (kills / SIM_DT)
		GameState.player_health = mini(GameState.player_max_health,
			GameState.player_health - int((dps_in - regen) * SIM_DT))

		# --- boss spawns
		if t >= next_boss_at and not boss_active:
			next_boss_at += MAIN.BOSS_INTERVAL
			boss_start = t
			var hp := MAIN.BOSS_TTK_TARGET * GameState.dps_target(m) * MAIN.BOSS_FOCUS_FACTOR * _overtime(m)
			if boss_index % 2 == 1:
				hp *= MAIN.BUTCHER_HP_MUL
			boss_index += 1
			boss_hp = hp
			boss_dmg = MAIN.BOSS_DMG_BASE * (1.0 + MAIN.DMG_SCALE * m) * _overtime(m)

		# --- DPS budget samples at checkpoint minutes (first tick past each)
		for minute in dps_samples:
			if m >= minute and not sampled.has(minute):
				sampled[minute] = true
				dps_samples[minute].append(horde_dps)

	# Giblet yield via the real earn formula (pure computation, no save).
	var earned := Meta.compute_earn(GameState.score, GameState.bosses_killed, t / 60.0)
	return {"time": t, "level": GameState.player_level, "dps": _single_target_dps(),
		"giblets": int(earned["total"])}

func _consume_level_ups() -> void:
	while GameState.has_pending_level_up():
		var choices := UpgradeData.get_random_choices(GameState.level_up_choices)
		if not choices.is_empty():
			# Mid-skill pick model: 70% take the strongest card, 30% any of
			# the three (theme/defense picks, mistakes). A pure coin-flip
			# model produced unrealistic bimodal death clustering — real
			# players rarely take the worst card outright.
			var pick: Dictionary
			if randf() < 0.7:
				pick = choices[0]
				for c in choices:
					if int(c.get("power", 0)) > int(pick.get("power", 0)):
						pick = c
			else:
				pick = choices.pick_random()
			UpgradeData.apply_upgrade(pick)
		GameState.consume_level_up()

func _single_target_dps() -> float:
	return GameState.projectile_damage * GameState.damage_mul * GameState.fire_rate \
		* (1.0 + GameState.crit_chance * (GameState.crit_mult - 1.0))

func _spawn_rate(m: float) -> float:
	var interval: float = maxf(MAIN.SPAWN_INTERVAL_MIN, MAIN.SPAWN_INTERVAL_START - MAIN.SPAWN_INTERVAL_DECAY * m)
	var wave: int = mini(MAIN.WAVE_SIZE_CAP, 1 + int(m * MAIN.WAVE_SIZE_GROWTH))
	return wave / interval

func _overtime(m: float) -> float:
	var over: float = maxf(0.0, m - MAIN.OVERTIME_START)
	return 1.0 + MAIN.OVERTIME_QUAD * over * over

# Mix-weighted average enemy from Main's spawn schedule and archetype stats.
# Cached per 0.1-minute bucket — this is the hot path of the sim.
var _avg_cache := {}

func _avg_enemy(m: float) -> Dictionary:
	var key := int(m * 10.0)
	if _avg_cache.has(key):
		return _avg_cache[key]
	var result := _avg_enemy_uncached(m)
	_avg_cache[key] = result
	return result

func _avg_enemy_uncached(m: float) -> Dictionary:
	var spider: float  = clampf(0.5 - m * 0.25,    0.0, 0.50)
	var wraith: float  = clampf((m - 0.5) * 0.5,   0.0, 0.35)
	var imp: float     = clampf((m - 2.0) * 0.1,   0.0, 0.20)
	var cyclops: float = clampf((m - 3.0) * 0.04,  0.0, 0.12)
	var charger: float = clampf((m - 4.0) * 0.075, 0.0, 0.15)
	var brawler: float = 1.0 - spider - wraith - imp - cyclops - charger
	var mix := [
		[spider,  MAIN.SPIDER_STATS], [wraith, MAIN.WRAITH_STATS],
		[imp,     MAIN.IMP_STATS],    [cyclops, MAIN.CYCLOPS_STATS],
		[charger, MAIN.CHARGER_STATS], [brawler, MAIN.BRAWLER_STATS],
	]
	var hp_scale := (1.0 + MAIN.HP_SCALE_LIN * m + MAIN.HP_SCALE_QUAD * m * m) * _overtime(m)
	var dmg_scale := (1.0 + MAIN.DMG_SCALE * m) * _overtime(m)
	var xp_scale := 1.0 + MAIN.XP_TIME_SCALE * m
	var hp := 0.0
	var dmg := 0.0
	var xp := 0.0
	for entry in mix:
		var w: float = entry[0]
		var s: Dictionary = entry[1]
		hp  += w * s["hp"] * hp_scale
		dmg += w * s["dmg"] * dmg_scale
		xp  += w * s["xp"] * xp_scale
	return {"hp": maxf(hp, 1.0), "dmg": maxf(dmg, 1.0), "xp": maxf(xp, 1.0)}

func _report(death_times: Array[float], levels: Array[int], dps: Array[float],
		boss_ttks: Array[float], dps_samples: Dictionary) -> void:
	death_times.sort()
	var buckets := {"0-5": 0, "5-8": 0, "8-12": 0, "12-16": 0, "16-20": 0, "20-25": 0, "25-30": 0, "survived": 0}
	for t in death_times:
		var m := t / 60.0
		if m >= 29.9: buckets["survived"] += 1
		elif m < 5.0: buckets["0-5"] += 1
		elif m < 8.0: buckets["5-8"] += 1
		elif m < 12.0: buckets["8-12"] += 1
		elif m < 16.0: buckets["12-16"] += 1
		elif m < 20.0: buckets["16-20"] += 1
		elif m < 25.0: buckets["20-25"] += 1
		else: buckets["25-30"] += 1

	print("=== BALANCE SIM: %d runs ===" % death_times.size())
	print("Death-time distribution (minutes):")
	for k in buckets:
		print("  %-9s %3d  %s" % [k, buckets[k], "#".repeat(buckets[k])])
	print("Median death: %.1f min   p10: %.1f   p90: %.1f" % [
		death_times[death_times.size() / 2] / 60.0,
		death_times[death_times.size() / 10] / 60.0,
		death_times[death_times.size() * 9 / 10] / 60.0])
	var lvl_sum := 0
	for l in levels: lvl_sum += l
	print("Avg final level: %.1f" % (float(lvl_sum) / levels.size()))
	if not boss_ttks.is_empty():
		boss_ttks.sort()
		var ttk_sum := 0.0
		for b in boss_ttks: ttk_sum += b
		print("Boss kills: %d   avg TTK: %.1fs   median: %.1fs   p90: %.1fs" % [
			boss_ttks.size(), ttk_sum / boss_ttks.size(),
			boss_ttks[boss_ttks.size() / 2], boss_ttks[boss_ttks.size() * 9 / 10]])
	print("Player horde-DPS at checkpoints (avg of surviving runs):")
	for minute in dps_samples:
		var arr: Array = dps_samples[minute]
		if arr.is_empty():
			continue
		var s := 0.0
		for v in arr: s += v
		print("  min %2d: %6.0f   (target %.0f, n=%d)" % [minute, s / arr.size(), GameState.dps_target(minute), arr.size()])
