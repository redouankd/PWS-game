extends Control

const REBINDABLE_ACTIONS := [
	{"action": "move_left", "label": "Move Left"},
	{"action": "move_right", "label": "Move Right"},
	{"action": "up", "label": "Up / Climb"},
	{"action": "down", "label": "Down"},
	{"action": "jump", "label": "Jump"},
	{"action": "dash", "label": "Dash"},
	{"action": "attack", "label": "Attack"},
	{"action": "block", "label": "Block"},
	{"action": "heal", "label": "Heal"},
	{"action": "special", "label": "Special"},
	{"action": "interact", "label": "Interact"},
	{"action": "pause", "label": "Pause"},
]

@onready var action_list: VBoxContainer = $ScrollContainer/ActionList
@onready var rebind_prompt: Label = $RebindPrompt
@onready var reset_button: Button = $Reset

var listening_action: String = ""
var action_buttons: Dictionary = {}

func _ready() -> void:
	rebind_prompt.visible = false
	for entry in REBINDABLE_ACTIONS:
		_add_action_row(entry["action"], entry["label"])
	reset_button.pressed.connect(_on_reset_pressed)

func _add_action_row(action: String, label_text: String) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 24)

	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size = Vector2(220, 0)
	row.add_child(label)

	var key_button := Button.new()
	key_button.text = _key_text(action)
	key_button.custom_minimum_size = Vector2(160, 0)
	key_button.pressed.connect(_on_rebind_pressed.bind(action, key_button))
	row.add_child(key_button)

	action_list.add_child(row)
	action_buttons[action] = key_button

func _key_text(action: String) -> String:
	for event in InputMap.action_get_events(action):
		if event is InputEventKey:
			return event.as_text().trim_suffix(" (Physical)")
	return "Unbound"

func _on_rebind_pressed(action: String, button: Button) -> void:
	if listening_action != "":
		return
	button.release_focus()
	listening_action = action
	button.text = "Press a key..."
	rebind_prompt.text = "Press any key to bind \"%s\"  (Esc to cancel)" % action
	rebind_prompt.visible = true

func _unhandled_key_input(event: InputEvent) -> void:
	if listening_action == "":
		return
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	get_viewport().set_input_as_handled()
	if event.keycode == KEY_ESCAPE:
		_cancel_rebind()
		return
	_apply_rebind(listening_action, event)

func _apply_rebind(action: String, event: InputEventKey) -> void:
	var clean_event := InputEventKey.new()
	clean_event.physical_keycode = event.physical_keycode
	clean_event.keycode = event.keycode
	clean_event.unicode = event.unicode

	for existing in InputMap.action_get_events(action):
		if existing is InputEventKey:
			InputMap.action_erase_event(action, existing)
	InputMap.action_add_event(action, clean_event)
	SettingsManager.save_keybind(action, clean_event)

	action_buttons[action].text = _key_text(action)
	_cancel_rebind()

func _cancel_rebind() -> void:
	listening_action = ""
	rebind_prompt.visible = false

func _on_reset_pressed() -> void:
	SettingsManager.reset_keybinds()
	for action in action_buttons.keys():
		action_buttons[action].text = _key_text(action)

func _on_button_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/SettingsMenu.tscn")
