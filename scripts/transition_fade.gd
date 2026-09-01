extends ColorRect

signal fade_finished

func fade_out(duration: float = 0.40) -> void:
	modulate.a = 0.0
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 1.0, duration)
	await tween.finished
	fade_finished.emit()

func fade_in(duration: float = 0.40) -> void:
	modulate.a = 1.0
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, duration)
	await tween.finished
