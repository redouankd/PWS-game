extends Node
class_name Health

signal died
signal damaged(amount: int, knockback_dir: Vector2)
signal perfectly_deflected(source: Node, attack_type: int)

@export var max_health: int = 100
var current_health: int

func _ready() -> void:
	current_health = max_health

func take_damage(amount: int, knockback_dir: Vector2 = Vector2.ZERO, source: Node = null, attack_type: int = 0) -> void:
	if current_health <= 0:
		return

	var owner_node = get_parent()
	if owner_node.has_method("get_deflect_state"):
		var deflect_result = owner_node.get_deflect_state()
		if deflect_result == owner_node.PERFECT_WINDOW:
			perfectly_deflected.emit(source, attack_type)
			return
		elif deflect_result == owner_node.LATE_BLOCK:
			amount = int(amount * owner_node.LATE_BLOCK_DAMAGE_REDUCTION) + owner_node.LATE_BLOCK_CHIP_DAMAGE

	current_health -= amount
	damaged.emit(amount, knockback_dir)
	if current_health <= 0:
		current_health = 0
		died.emit()

func heal(amount: int) -> void:
	current_health = min(current_health + amount, max_health)
