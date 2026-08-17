extends Area2D

var velocity: Vector2 = Vector2.ZERO
@export var damage: int = 10
@export var lifetime: float = 3.0
@export var homing_strength: float = 0.4  # 0 = straight line, 0.3-0.6 = light homing
@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D

var target: Node2D = null

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	target = get_tree().get_first_node_in_group("player")
	await get_tree().create_timer(lifetime).timeout
	queue_free()



func set_direction(vel: Vector2) -> void:
	velocity = vel

func _physics_process(delta: float) -> void:
	if homing_strength > 0.0 and target and is_instance_valid(target):
		var desired = (target.global_position - global_position).normalized()
		velocity = velocity.lerp(desired * velocity.length(), homing_strength * delta)
	global_position += velocity * delta

func _on_body_entered(body: Node) -> void:
	if body.has_node("Health"):
		body.get_node("Health").take_damage(damage)
		animated_sprite_2d.play("impact")
		await _on_animated_sprite_2d_animation_finished()
	queue_free()


func _on_animated_sprite_2d_animation_finished() -> void:
	pass # Replace with function body.
