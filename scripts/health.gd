extends Node
class_name Health

signal died
signal damaged(amount: int, knockback_dir: Vector2)

@export var max_health: int = 100
var current_health: int

func _ready() -> void:
	current_health = max_health

func take_damage(amount: int, knockback_dir: Vector2 = Vector2.ZERO) -> void:
	if current_health <= 0:
		return

	current_health -= amount
	damaged.emit(amount, knockback_dir)
	print("Took %d damage, %d/%d HP left" % [amount, current_health, max_health])

	if current_health <= 0:
		current_health = 0
		died.emit()
		print("Died!")

func heal(amount: int) -> void:
	current_health = min(current_health + amount, max_health)
