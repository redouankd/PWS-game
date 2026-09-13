extends Node

const SAVE_PATH = "user://savegame.cfg"

var last_save_point_id: String = ""
var last_save_position: Vector2 = Vector2.ZERO

func save_game() -> void:
	var config = ConfigFile.new()
	config.set_value("player", "abilities", PlayerStats.unlocked_abilities)
	config.set_value("player", "save_point_id", last_save_point_id)
	config.set_value("player", "position_x", last_save_position.x)
	config.set_value("player", "position_y", last_save_position.y)
	config.save(SAVE_PATH)
	print("Game saved at: ", last_save_point_id)

func load_game() -> bool:
	var config = ConfigFile.new()
	var err = config.load(SAVE_PATH)
	if err != OK:
		return false

	PlayerStats.unlocked_abilities = config.get_value("player", "abilities", PlayerStats.unlocked_abilities)
	last_save_point_id = config.get_value("player", "save_point_id", "")
	last_save_position = Vector2(
		config.get_value("player", "position_x", 0.0),
		config.get_value("player", "position_y", 0.0)
	)
	return true

func has_save_file() -> bool:
	return FileAccess.file_exists(SAVE_PATH)

func set_save_point(id: String, pos: Vector2) -> void:
	last_save_point_id = id
	last_save_position = pos
	save_game()
