extends Area2D

@export var new_camera_limits: Rect2
@export var spawn_point: Marker2D
@onready var player: CharacterBody2D = $"../../Player"

func _ready() -> void:
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		var ui = get_tree().get_first_node_in_group("ui")
		var fade = ui.get_node("TransitionFade")

		body.set_physics_process(false)
		await fade.fade_out()

		var camera = body.get_node("player_cam")
		camera.limit_left = int(new_camera_limits.position.x)
		camera.limit_right = int(new_camera_limits.end.x)
		camera.limit_top = -100000
		camera.limit_bottom = 100000

		if spawn_point:
			body.global_position = spawn_point.global_position
		
		if player.is_on_floor():
			await get_tree().create_timer(1.5).timeout
			await fade.fade_in()
			body.set_physics_process(true)
		else:
			body.set_physics_process(true)
			await get_tree().create_timer(1.5).timeout
			await fade.fade_in()
