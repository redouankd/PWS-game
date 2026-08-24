extends Area2D

@export var new_camera_limits: Rect2
@export var spawn_point: Marker2D

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		var camera = body.get_node("player_cam")
		camera.limit_left = int(new_camera_limits.position.x)
		camera.limit_top = int(new_camera_limits.position.y)
		camera.limit_right = int(new_camera_limits.end.x)
		camera.limit_bottom = int(new_camera_limits.end.y)
		if spawn_point:
			body.global_position = spawn_point.global_position
