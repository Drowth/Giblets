extends Node

# Central one-shot SFX player. Everything routes through here instead of
# scenes managing their own AudioStreamPlayer nodes, so every sound respects
# the SFX volume slider (Settings) and pooled players avoid cutting each
# other off when several sounds fire the same frame (e.g. multishot kills).

const POOL_SIZE := 12

var _pool: Array[AudioStreamPlayer] = []
var _next: int = 0
var _cache: Dictionary = {}  # path -> AudioStream, avoids reloading every call

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for _i in POOL_SIZE:
		var p := AudioStreamPlayer.new()
		p.bus = &"SFX"
		add_child(p)
		_pool.append(p)

func _load(path: String) -> AudioStream:
	if not _cache.has(path):
		_cache[path] = load(path)
	return _cache[path]

# Play a single sound. pitch_variance randomises pitch_scale by +/- that
# fraction so repeated plays (hits, coins) don't sound mechanical.
func play(path: String, volume_db: float = 0.0, pitch_variance: float = 0.0) -> void:
	var stream := _load(path)
	if not stream:
		return
	var player := _pool[_next]
	_next = (_next + 1) % _pool.size()
	player.stream = stream
	player.volume_db = volume_db
	player.pitch_scale = 1.0 + randf_range(-pitch_variance, pitch_variance) if pitch_variance > 0.0 else 1.0
	player.play()

# Play one random file from a list — useful for hit/kill variation.
func play_random(paths: Array, volume_db: float = 0.0, pitch_variance: float = 0.0) -> void:
	if paths.is_empty():
		return
	play(paths.pick_random(), volume_db, pitch_variance)

# Play with an exact pitch_scale (e.g. rising pitch on an escalating combo)
# instead of the symmetric random variance play() applies.
func play_pitched(path: String, volume_db: float, pitch_scale: float) -> void:
	var stream := _load(path)
	if not stream:
		return
	var player := _pool[_next]
	_next = (_next + 1) % _pool.size()
	player.stream = stream
	player.volume_db = volume_db
	player.pitch_scale = pitch_scale
	player.play()
