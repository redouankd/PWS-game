extends Area2D

var velocity: Vector2 = Vector2.ZERO
@export var damage: int = 10
@export var lifetime: float = 4.0
@export var homing_strength: float = 0.0
@export var stun_duration: float = 0.5

var target: Node2D = null
var shooter: Node = null

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	target = get_tree().get_first_node_in_group("player")
	await get_tree().create_timer(lifetime).timeout
	queue_free()

func set_direction(vel: Vector2) -> void:
	velocity = vel
	rotation = vel.angle()

func _physics_process(delta: float) -> void:
	if homing_strength > 0.0 and target and is_instance_valid(target):
		var desired = (target.global_position - global_position).normalized()
		velocity = velocity.lerp(desired * velocity.length(), homing_strength * delta)
	global_position += velocity * delta

func _on_body_entered(body: Node) -> void:
	if body.has_node("Health"):
		var health = body.get_node("Health")
		if body.has_method("get_deflect_state") and body.get_deflect_state() == body.PERFECT_WINDOW:
			velocity = -velocity  # reflect it back
			if shooter != null and is_instance_valid(shooter) and shooter.has_method("apply_stun"):
				shooter.apply_stun(stun_duration)
				PlayerStats.add_focus(PlayerStats.focus_per_parry)
			return
		health.take_damage(damage, Vector2.ZERO, null, 1)  # 1 = PROJECTILE
	queue_free()
