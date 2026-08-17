extends Node

var shaking := false

func hit_stop(duration: float = 0.06, scale: float = 0.05) -> void:
	Engine.time_scale = scale
	await get_tree().create_timer(duration, true, false, true).timeout
	Engine.time_scale = 1.0

func screen_shake(camera: Camera2D, strength: float = 6.0, duration: float = 0.15) -> void:
	if camera == null or not is_instance_valid(camera) or shaking:
		return
	shaking = true
	var original_offset = camera.offset
	var elapsed = 0.0
	while elapsed < duration:
		if not is_instance_valid(camera):
			shaking = false
			return
		camera.offset = original_offset + Vector2(
			randf_range(-strength, strength),
			randf_range(-strength, strength)
		)
		await get_tree().create_timer(0.016, true, false, true).timeout
		elapsed += 0.016
	if is_instance_valid(camera):
		camera.offset = original_offset
	shaking = false
