extends Area2D

@export var damage: int = 10
@export var knockback_force: float = 250.0
@export var hit_stop_duration: float = 0.06
@export var hit_stop_scale: float = 0.05
var already_hit: Array = []

func _ready() -> void:
	monitoring = false
	area_entered.connect(_on_area_entered)
	body_entered.connect(_on_body_entered)

func _on_area_entered(area: Area2D) -> void:
	_try_damage(area.get_owner())

func _on_body_entered(body: Node) -> void:
	_try_damage(body)

func _try_damage(target: Node) -> void:
	if target == null or target in already_hit:
		return
	if target == get_owner():
		return
	if target.has_node("Health"):
		var direction = (target.global_position - get_owner().global_position).normalized()
		target.get_node("Health").take_damage(damage, direction * knockback_force)
		already_hit.append(target)
		GameEffects.hit_stop(hit_stop_duration, hit_stop_scale)

func enable_hitbox() -> void:
	already_hit.clear()
	monitoring = true

func disable_hitbox() -> void:
	monitoring = false
