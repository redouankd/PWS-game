extends Area2D

@export var heal_amount: int = 30

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	print("Something entered:", body.name)

	if body.is_in_group("player"):
		print("Player detected!")

		var player_health := body.get_node_or_null("Health") as Health

		if player_health:
			print("Health found:", player_health.current_health)
			player_health.heal(heal_amount)
			print("After healing:", player_health.current_health)
		else:
			print("Health node NOT found!")
