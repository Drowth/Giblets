class_name WizardFrames

# Generic builder for 8-directional AnimatedSprite2D frames from
# res://<base_path>/<anim>/<dir>/NNN.png. Frames are normalized to 001.png..
# at copy time. Built once per base_path and cached.
#
# Animation names are "<anim>_<dir>", e.g. "run_NE", "idle_S", "roll_W",
# "die_E". Driven from 8-way facing state (see Player.gd / Enemy.gd
# _dir_to_compass + _play_anim).

const DIRECTIONS: Array[String] = ["E", "N", "NE", "NW", "S", "SE", "SW", "W"]

const WIZARD_PATH      := "res://assets/player/wizard"
const REAPER_PATH      := "res://assets/player/reaper"
const NECROMANCER_PATH := "res://assets/player/necromancer"
const PALADIN_PATH     := "res://assets/player/paladin"
# anim -> [fps, loops]
const WIZARD_ANIMS: Dictionary = {
	"idle": [12.0, true],
	"run":  [20.0, true],
	"roll": [30.0, false],  # dash is ~0.2s; the roll gets cut on dash end
	"die":  [15.0, false],
}
const REAPER_ANIMS: Dictionary = {
	"idle": [10.0, true],
	"run":  [16.0, true],
	"roll": [30.0, false],  # dash uses the DarkLord Rolling animation
	"die":  [34.0, false],
	"hurt": [60.0, false],
}
# Witchdoctor pack (D:\Assets\...\8Witchdoctor): idle/run/die 15 frames each,
# hurt (TakeDamage) 18 frames, roll (Rolling) 15 frames — same 128px HD frame
# size and 8-direction layout as the Reaper set, so timings mirror it.
const NECROMANCER_ANIMS: Dictionary = {
	"idle": [10.0, true],
	"run":  [16.0, true],
	"roll": [30.0, false],  # dash uses the Witchdoctor's Rolling animation
	"die":  [34.0, false],
	"hurt": [60.0, false],
}
# Paladin pack (D:\Assets\...\4Paladin): idle/run/roll(Rolling)/die/hurt
# (TakeDamage) all 15 frames each, same 128px HD frame size and 8-direction
# layout as the Reaper/Witchdoctor sets — hurt fps scaled down to keep the
# same ~0.3s read time despite fewer source frames (15 vs 18).
const PALADIN_ANIMS: Dictionary = {
	"idle": [10.0, true],
	"run":  [16.0, true],
	"roll": [30.0, false],  # dash uses the Paladin's Rolling animation
	"die":  [34.0, false],
	"hurt": [50.0, false],
}

static var _cache: Dictionary = {}  # base_path -> SpriteFrames

static func get_frames() -> SpriteFrames:
	return build(WIZARD_PATH, WIZARD_ANIMS)

static func get_reaper_frames() -> SpriteFrames:
	return build(REAPER_PATH, REAPER_ANIMS)

static func get_necromancer_frames() -> SpriteFrames:
	return build(NECROMANCER_PATH, NECROMANCER_ANIMS)

static func get_paladin_frames() -> SpriteFrames:
	return build(PALADIN_PATH, PALADIN_ANIMS)

static func build(base_path: String, anims: Dictionary) -> SpriteFrames:
	if _cache.has(base_path):
		return _cache[base_path]
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	for anim: String in anims:
		for dir in DIRECTIONS:
			var anim_name := "%s_%s" % [anim, dir]
			frames.add_animation(anim_name)
			frames.set_animation_speed(anim_name, anims[anim][0])
			frames.set_animation_loop(anim_name, anims[anim][1])
			var i := 1
			# ResourceLoader.exists (not DirAccess) so exported PCK builds work
			while ResourceLoader.exists("%s/%s/%s/%03d.png" % [base_path, anim, dir, i]):
				frames.add_frame(anim_name, load("%s/%s/%s/%03d.png" % [base_path, anim, dir, i]))
				i += 1
	_cache[base_path] = frames
	return frames
