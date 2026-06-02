extends Node

const SAVE_PATH := "user://highscores.save"
const MAX_ENTRIES := 10

var _scores: Array = []

func _ready() -> void:
	_load()

func is_high_score(score: int) -> bool:
	if _scores.size() < MAX_ENTRIES:
		return true
	return score > _scores.back().score

func add_score(player_name: String, score: int, level: int, kills: int, elapsed: float) -> int:
	var entry := {
		"name": player_name.strip_edges().to_upper().left(12),
		"score": score,
		"level": level,
		"kills": kills,
		"time": elapsed
	}
	_scores.append(entry)
	_scores.sort_custom(func(a, b): return a.score > b.score)
	if _scores.size() > MAX_ENTRIES:
		_scores.resize(MAX_ENTRIES)
	_save()
	for i in _scores.size():
		if _scores[i] == entry:
			return i + 1
	return -1

func get_scores() -> Array:
	return _scores.duplicate()

func _save() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_var(_scores)
		file.close()

func _load() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file:
		var data = file.get_var()
		file.close()
		if data is Array:
			_scores = data
