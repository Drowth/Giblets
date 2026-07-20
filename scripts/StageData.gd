class_name StageData

# Playable stage roster. Each stage is just a floor: Main.tscn/Main.gd stay
# the single game loop (spawn curve, bosses, UI, timers); a non-empty
# scene_path layers that scene's contents on top of the procedural
# WorldBackground (Background.gd), which stays in place underneath so any
# gaps in the stage art (e.g. City's diamond-shaped isometric Ground only
# covers ~half its bounding rect) show textured floor, not a flat void (see
# Main.gd _setup_stage_floor). Selection persists in Meta.selected_stage.

const STAGES: Dictionary = {
	"default": {
		"name": "Boneyard",
		"desc": "The original graveyard arena.",
		"scene_path": "",
	},
	"city": {
		"name": "City",
		"desc": "Overgrown city streets.",
		"scene_path": "res://scenes/City.tscn",
	},
}
