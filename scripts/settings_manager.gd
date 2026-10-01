extends Node

const SETTINGS_PATH := "user://settings.cfg"

var master_volume: float = 1.0
var music_volume: float = 1.0
var sfx_volume: float = 1.0
var fullscreen: bool = false

func _ready() -> void:
	load_settings()
	_apply_all()

func set_master_volume(value: float) -> void:
	master_volume = value
	_apply_bus_volume("Master", value)
	save_settings()

func set_music_volume(value: float) -> void:
	music_volume = value
	_apply_bus_volume("Music", value)
	save_settings()

func set_sfx_volume(value: float) -> void:
	sfx_volume = value
	_apply_bus_volume("SFX", value)
	save_settings()

func set_fullscreen(enabled: bool) -> void:
	fullscreen = enabled
	if enabled:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	save_settings()

func _apply_bus_volume(bus_name: String, linear_value: float) -> void:
	var idx = AudioServer.get_bus_index(bus_name)
	if idx == -1:
		return
	if linear_value <= 0.0001:
		AudioServer.set_bus_mute(idx, true)
	else:
		AudioServer.set_bus_mute(idx, false)
		AudioServer.set_bus_volume_db(idx, linear_to_db(linear_value))

func _apply_all() -> void:
	_apply_bus_volume("Master", master_volume)
	_apply_bus_volume("Music", music_volume)
	_apply_bus_volume("SFX", sfx_volume)
	if fullscreen:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)

func save_settings() -> void:
	var config = ConfigFile.new()
	config.set_value("audio", "master", master_volume)
	config.set_value("audio", "music", music_volume)
	config.set_value("audio", "sfx", sfx_volume)
	config.set_value("display", "fullscreen", fullscreen)
	config.save(SETTINGS_PATH)

func load_settings() -> void:
	var config = ConfigFile.new()
	var err = config.load(SETTINGS_PATH)
	if err != OK:
		return
	master_volume = config.get_value("audio", "master", 1.0)
	music_volume = config.get_value("audio", "music", 1.0)
	sfx_volume = config.get_value("audio", "sfx", 1.0)
	fullscreen = config.get_value("display", "fullscreen", false)
