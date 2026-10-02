extends Area2D

@export var save_point_id: String = "room_a_bench"
@export var camera_limits: Rect2

@onready var prompt_label: Label = $Label

var player_in_range: bool = false

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	prompt_label.visible = false

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		player_in_range = true
		prompt_label.visible = true

func _on_body_exited(body: Node) -> void:
	if body.is_in_group("player"):
		player_in_range = false
		prompt_label.visible = false

func _unhandled_input(event: InputEvent) -> void:
	if player_in_range and event.is_action_pressed("interact"):
		_save_and_reset()

func _save_and_reset() -> void:
	SaveManager.set_save_point(save_point_id, global_position, camera_limits)

	var ui = get_tree().get_first_node_in_group("ui")
	var fade = ui.get_node("TransitionFade") if ui else null
	if fade:
		await fade.fade_out(0.4)

	get_tree().reload_current_scene()
