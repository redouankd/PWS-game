extends StaticBody2D

@export var door_group: String = ""

@export var activate_sound: AudioStream
@export var deactivate_sound: AudioStream


@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var light: PointLight2D = $PointLight2D
@onready var damage_area: Area2D = $DamageArea
@onready var damage_area_shape: CollisionShape2D = $DamageArea/CollisionShape2D

func _ready() -> void:
	add_to_group("laser_door")
	if door_group != "":
		add_to_group(door_group)
	deactivate_start()
	

func activate() -> void:
	SoundManager.play_sfx(activate_sound)
	sprite.visible = true
	light.visible = true
	collision_shape.set_deferred("disabled", false)
	damage_area.monitoring = true
	damage_area_shape.set_deferred("disabled", false)
	if sprite.sprite_frames and sprite.sprite_frames.has_animation("on"):
		sprite.play("on")

func deactivate_start() -> void:
	
	sprite.visible = false
	light.visible = false
	collision_shape.set_deferred("disabled", true)
	damage_area.monitoring = false
	damage_area_shape.set_deferred("disabled", true)

func deactivate() -> void:
	SoundManager.play_sfx(deactivate_sound)
	sprite.visible = false
	light.visible = false
	collision_shape.set_deferred("disabled", true)
	damage_area.monitoring = false
	damage_area_shape.set_deferred("disabled", true)
