extends Control

@export var Win_screen: AudioStream

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	SoundManager.play_music(Win_screen)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func _on_main_menu_button_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")
