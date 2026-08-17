extends Area2D

@onready var boss_cam: Camera2D = $"../boss_cam"
@onready var player_cam: Camera2D = $"../Player/player_cam"
@onready var boss_cam_timer: Timer = $"boss cam timer"


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
func _on_body_entered(body):
	pass


func _on_area_2d_body_shape_entered(body_rid: RID, body: Node2D, body_shape_index: int, local_shape_index: int) -> void:
	if body.is_in_group("player"):  # or check body.name == "Player"
		boss_cam_timer.start()


func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		boss_cam_timer.stop()  # in case they leave mid-delay
		player_cam.enabled = true
		boss_cam.enabled = false



func _on_boss_cam_timer_timeout() -> void:
	boss_cam.enabled = true
	player_cam.enabled = false
	
