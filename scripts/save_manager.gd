extends Node

const SAVE_PATH = "user://savegame.cfg"

var last_save_point_id: String = ""
var last_save_position: Vector2 = Vector2.ZERO
var last_camera_limits: Rect2 = Rect2()

func save_game() -> void:
	var config = ConfigFile.new()
	config.set_value("player", "abilities", PlayerStats.unlocked_abilities)
	config.set_value("player", "save_point_id", last_save_point_id)
	config.set_value("player", "position_x", last_save_position.x)
	config.set_value("player", "position_y", last_save_position.y)
	config.set_value("player", "cam_x", last_camera_limits.position.x)
	config.set_value("player", "cam_y", last_camera_limits.position.y)
	config.set_value("player", "cam_w", last_camera_limits.size.x)
	config.set_value("player", "cam_h", last_camera_limits.size.y)
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
	last_camera_limits = Rect2(
		config.get_value("player", "cam_x", -100000.0),
		config.get_value("player", "cam_y", -100000.0),
		config.get_value("player", "cam_w", 200000.0),
		config.get_value("player", "cam_h", 200000.0)
	)
	return true

func has_save_file() -> bool:
	return FileAccess.file_exists(SAVE_PATH)

func set_save_point(id: String, pos: Vector2, cam_limits: Rect2) -> void:
	last_save_point_id = id
	last_save_position = pos
	last_camera_limits = cam_limits
	save_game()
