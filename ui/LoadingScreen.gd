extends Control

const FADE_DURATION := 0.3

func show_loading() -> void:
	show()
	modulate = Color(1, 1, 1, 1)

func hide_loading() -> void:
	hide()

func fade_in() -> void:
	show()
	modulate = Color(1, 1, 1, 0)
	var tween := create_tween()
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.set_trans(Tween.TRANS_LINEAR)
	tween.tween_property(self, "modulate:a", 1.0, FADE_DURATION)
	await tween.finished

func fade_out() -> void:
	var tween := create_tween()
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.set_trans(Tween.TRANS_LINEAR)
	tween.tween_property(self, "modulate:a", 0.0, FADE_DURATION)
	await tween.finished
	hide()
