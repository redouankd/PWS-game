extends Control

@onready var continue_button: Button = $VBoxContainer/ContinueButton
@export var level_scene_path: String = "res://scenes/level.tscn"

func _ready() -> void:
	continue_button.disabled = not SaveManager.has_save_file()

func _on_start_button_pressed() -> void:
	# Fresh start — clear any existing save data if you want a true "New Game"
	get_tree().change_scene_to_file(level_scene_path)

func _on_continue_button_pressed() -> void:
	SaveManager.load_game()
	get_tree().change_scene_to_file(level_scene_path)

func _on_quit_button_pressed() -> void:
	get_tree().quit()
