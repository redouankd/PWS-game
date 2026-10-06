extends Area2D

@export var damage: int = 15
@export var safe_position: Marker2D

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node) -> void:
	if not body.is_in_group("player"):
		return
	if not safe_position:
		push_error("AcidLake: no safe_position assigned")
		return

	if body.has_node("Health"):
		var health = body.get_node("Health")
		health.take_damage(damage, Vector2.ZERO, self)

	body.global_position = safe_position.global_position
	body.velocity = Vector2.ZERO
