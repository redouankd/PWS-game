extends Area2D

@export var save_point_id: String = "room_a_bench"

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		SaveManager.set_save_point(save_point_id, global_position)
		print("Save point reached: ", save_point_id)
