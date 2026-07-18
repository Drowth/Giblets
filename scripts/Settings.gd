extends Node

# Settings singleton — owns everything persisted to user://settings.cfg.
# Display/audio config only; gameplay state stays in GameState.

signal crt_settings_changed
signal shake_setting_changed

const CFG_PATH := "user://settings.cfg"

var master_volume: float = 1.0
var music_volume: float = 0.8
var sfx_volume: float = 1.0
var crt_enabled: bool = false
var crt_affects_enemies: bool = false
var screen_shake_enabled: bool = true
var reduce_flash: bool = false
var fullscreen: bool = false
var key_overrides: Dictionary = {}  # action name -> physical keycode

const REBINDABLE_ACTIONS := ["move_left", "move_right", "move_up", "move_down", "dash", "pause"]

func _ready() -> void:
	_ensure_buses()
	load_settings()
	apply_all()
	apply_input_overrides()

# Music/SFX buses are created at runtime so no .tres bus layout is needed.
func _ensure_buses() -> void:
	for bus_name in ["Music", "SFX"]:
		if AudioServer.get_bus_index(bus_name) == -1:
			AudioServer.add_bus()
			var idx := AudioServer.bus_count - 1
			AudioServer.set_bus_name(idx, bus_name)
			AudioServer.set_bus_send(idx, "Master")

func apply_all() -> void:
	AudioServer.set_bus_volume_db(0, linear_to_db(clampf(master_volume, 0.0001, 1.0)))
	AudioServer.set_bus_mute(0, master_volume <= 0.0)
	var music_idx := AudioServer.get_bus_index("Music")
	if music_idx != -1:
		AudioServer.set_bus_volume_db(music_idx, linear_to_db(clampf(music_volume, 0.0001, 1.0)))
		AudioServer.set_bus_mute(music_idx, music_volume <= 0.0)
	var sfx_idx := AudioServer.get_bus_index("SFX")
	if sfx_idx != -1:
		AudioServer.set_bus_volume_db(sfx_idx, linear_to_db(clampf(sfx_volume, 0.0001, 1.0)))
		AudioServer.set_bus_mute(sfx_idx, sfx_volume <= 0.0)
	var mode := DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
	if DisplayServer.window_get_mode() != mode:
		DisplayServer.window_set_mode(mode)
	crt_settings_changed.emit()
	shake_setting_changed.emit()

# Replace an action's keyboard binding (joypad events are preserved).
func rebind(action: String, physical_keycode: int) -> void:
	key_overrides[action] = physical_keycode
	_apply_override(action, physical_keycode)
	save_settings()

func apply_input_overrides() -> void:
	for action in key_overrides:
		if InputMap.has_action(action):
			_apply_override(action, int(key_overrides[action]))

func _apply_override(action: String, physical_keycode: int) -> void:
	for ev in InputMap.action_get_events(action):
		if ev is InputEventKey:
			InputMap.action_erase_event(action, ev)
	var key := InputEventKey.new()
	key.physical_keycode = physical_keycode as Key
	InputMap.action_add_event(action, key)

func current_key_name(action: String) -> String:
	for ev in InputMap.action_get_events(action):
		if ev is InputEventKey:
			return OS.get_keycode_string(DisplayServer.keyboard_get_keycode_from_physical(ev.physical_keycode))
	return "—"

func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "master", master_volume)
	cfg.set_value("audio", "music", music_volume)
	cfg.set_value("audio", "sfx", sfx_volume)
	cfg.set_value("video", "crt", crt_enabled)
	cfg.set_value("video", "crt_enemies", crt_affects_enemies)
	cfg.set_value("video", "screen_shake", screen_shake_enabled)
	cfg.set_value("video", "reduce_flash", reduce_flash)
	cfg.set_value("video", "fullscreen", fullscreen)
	cfg.set_value("input", "overrides", key_overrides)
	cfg.save(CFG_PATH)

func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(CFG_PATH) != OK:
		return
	master_volume = cfg.get_value("audio", "master", master_volume)
	music_volume = cfg.get_value("audio", "music", music_volume)
	sfx_volume = cfg.get_value("audio", "sfx", sfx_volume)
	crt_enabled = cfg.get_value("video", "crt", crt_enabled)
	crt_affects_enemies = cfg.get_value("video", "crt_enemies", crt_affects_enemies)
	screen_shake_enabled = cfg.get_value("video", "screen_shake", screen_shake_enabled)
	reduce_flash = cfg.get_value("video", "reduce_flash", reduce_flash)
	fullscreen = cfg.get_value("video", "fullscreen", fullscreen)
	var overrides = cfg.get_value("input", "overrides", {})
	if overrides is Dictionary:
		key_overrides = overrides
