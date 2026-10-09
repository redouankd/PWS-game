extends Control

@onready var master_slider: HSlider = $VBoxContainer/MasterSlider
@onready var music_slider: HSlider = $VBoxContainer/MusicSlider
@onready var sfx_slider: HSlider = $VBoxContainer/SFXSlider
@onready var fullscreen_checkbox: CheckBox = $VBoxContainer/FullscreenCheckBox

func _ready() -> void:
	master_slider.value = SettingsManager.master_volume
	music_slider.value = SettingsManager.music_volume
	sfx_slider.value = SettingsManager.sfx_volume
	fullscreen_checkbox.button_pressed = SettingsManager.fullscreen

	master_slider.value_changed.connect(SettingsManager.set_master_volume)
	music_slider.value_changed.connect(SettingsManager.set_music_volume)
	sfx_slider.value_changed.connect(SettingsManager.set_sfx_volume)
	fullscreen_checkbox.toggled.connect(SettingsManager.set_fullscreen)

func _on_back_button_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")


func _on_controlbutton_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/ControlsMenu.tscn")
