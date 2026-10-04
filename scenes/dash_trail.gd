extends Node2D

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

func _ready() -> void:
	sprite.play("dash_trail")
	await sprite.animation_finished
	queue_free()
