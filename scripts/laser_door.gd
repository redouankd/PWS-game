extends StaticBody2D

@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var light: PointLight2D = $PointLight2D
@onready var damage_area: Area2D = $DamageArea
@onready var damage_area_shape: CollisionShape2D = $DamageArea/CollisionShape2D

func _ready() -> void:
	deactivate()

func activate() -> void:
	sprite.visible = true
	light.visible = true
	collision_shape.set_deferred("disabled", false)
	damage_area.monitoring = true
	damage_area_shape.set_deferred("disabled", false)
	if sprite.sprite_frames and sprite.sprite_frames.has_animation("on"):
		sprite.play("on")

func deactivate() -> void:
	sprite.visible = false
	light.visible = false
	collision_shape.set_deferred("disabled", true)
	damage_area.monitoring = false
	damage_area_shape.set_deferred("disabled", true)
