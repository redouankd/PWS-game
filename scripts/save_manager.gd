extends Node

const SAVE_PATH_FORMAT = "user://savegame_slot_%d.cfg"
const NUM_SLOTS = 3

var current_slot: int = -1
var last_save_point_id: String = ""
var last_save_position: Vector2 = Vector2.ZERO
var last_camera_limits: Rect2 = Rect2()
var collected_pickups: Dictionary = {}
var defeated_bosses: Dictionary = {}

func get_save_path(slot: int) -> String:
	return SAVE_PATH_FORMAT % slot

func has_save_file(slot: int) -> bool:
	return FileAccess.file_exists(get_save_path(slot))

func delete_save(slot: int) -> void:
	var path = get_save_path(slot)
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)

func start_new_game(slot: int) -> void:
	current_slot = slot
	PlayerStats.unlocked_abilities = {
		"double_jump": false,
		"dash": false,
		"wall_climb": false,
	}
	collected_pickups = {}
	defeated_bosses = {}
	last_save_point_id = ""
	last_save_position = Vector2.ZERO
	last_camera_limits = Rect2()

func save_game() -> void:
	if current_slot == -1:
		return
	var config = ConfigFile.new()
	config.set_value("player", "abilities", PlayerStats.unlocked_abilities)
	config.set_value("player", "collected_pickups", collected_pickups)
	config.set_value("player", "defeated_bosses", defeated_bosses)
	config.set_value("player", "save_point_id", last_save_point_id)
	config.set_value("player", "position_x", last_save_position.x)
	config.set_value("player", "position_y", last_save_position.y)
	config.set_value("player", "cam_x", last_camera_limits.position.x)
	config.set_value("player", "cam_y", last_camera_limits.position.y)
	config.set_value("player", "cam_w", last_camera_limits.size.x)
	config.set_value("player", "cam_h", last_camera_limits.size.y)
	config.save(get_save_path(current_slot))
	print("Game saved to slot ", current_slot, " at: ", last_save_point_id)

func load_game(slot: int) -> bool:
	var config = ConfigFile.new()
	var err = config.load(get_save_path(slot))
	if err != OK:
		return false

	current_slot = slot
	PlayerStats.unlocked_abilities = config.get_value("player", "abilities", PlayerStats.unlocked_abilities)
	collected_pickups = config.get_value("player", "collected_pickups", {})
	defeated_bosses = config.get_value("player", "defeated_bosses", {})
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

func is_pickup_collected(pickup_id: String) -> bool:
	return collected_pickups.get(pickup_id, false)

func mark_pickup_collected(pickup_id: String) -> void:
	collected_pickups[pickup_id] = true

func is_boss_defeated(boss_id: String) -> bool:
	return defeated_bosses.get(boss_id, false)

func mark_boss_defeated(boss_id: String) -> void:
	defeated_bosses[boss_id] = true

func set_save_point(id: String, pos: Vector2, cam_limits: Rect2) -> void:
	last_save_point_id = id
	last_save_position = pos
	last_camera_limits = cam_limits
	save_game()
