extends Area2D

@export var new_camera_limits: Rect2
@export var spawn_point: Marker2D

var player_in_range: bool = false
var player: Node2D = null

@onready var prompt_label: Label = $EnterSewerLabel

func _ready() -> void:
	prompt_label.visible = false
	
	# Verbind beide signalen netjes in de ready-functie
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	if not body_exited.is_connected(_on_body_exited):
		body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		prompt_label.visible = true
		player_in_range = true
		player = body 

func _on_body_exited(body: Node2D) -> void:
	if body == player:
		prompt_label.visible = false
		player_in_range = false
		player = null

func _unhandled_input(event: InputEvent):
	if player_in_range and event.is_action_pressed("interact") and player:
		_room_trans(player)

func _room_trans(body: Node):	
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

		await fade.fade_in()
		body.set_physics_process(true)
