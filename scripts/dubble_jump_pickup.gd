extends Area2D

@export var ability_name: String = "double_jump"
@export var pickup_label: String = "Double Jump"

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		PlayerStats.unlock_ability(ability_name)
		# optional: show a "Double Jump acquired!" popup here
		queue_free()
