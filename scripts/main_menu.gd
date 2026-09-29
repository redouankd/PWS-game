extends Control

@export var level_scene_path: String = "res://scenes/level.tscn"

@onready var slot_buttons: Array[Button] = [
	$VBoxContainer/Slot1Row/Slot1Button,
	$VBoxContainer/Slot2Row/Slot2Button,
	$VBoxContainer/Slot3Row/Slot3Button,
]

@onready var reset_buttons: Array[Button] = [
	$VBoxContainer/Slot1Row/Slot1ResetButton,
	$VBoxContainer/Slot2Row/Slot2ResetButton,
	$VBoxContainer/Slot3Row/Slot3ResetButton,
]

@onready var confirm_dialog: ConfirmationDialog = $ResetConfirmDialog

var slot_pending_reset: int = -1

func _ready() -> void:
	_refresh_slot_buttons()
	confirm_dialog.confirmed.connect(_on_reset_confirmed)

func _refresh_slot_buttons() -> void:
	for i in slot_buttons.size():
		var slot := i + 1
		var has_save := SaveManager.has_save_file(slot)
		slot_buttons[i].text = "Slot %d - %s" % [slot, "Continue" if has_save else "New Game"]
		reset_buttons[i].visible = has_save

func _on_slot_1_button_pressed() -> void:
	_select_slot(1)

func _on_slot_2_button_pressed() -> void:
	_select_slot(2)

func _on_slot_3_button_pressed() -> void:
	_select_slot(3)

func _select_slot(slot: int) -> void:
	if SaveManager.has_save_file(slot):
		SaveManager.load_game(slot)
	else:
		SaveManager.start_new_game(slot)
	get_tree().change_scene_to_file(level_scene_path)

func _on_slot_1_reset_button_pressed() -> void:
	_request_reset(1)

func _on_slot_2_reset_button_pressed() -> void:
	_request_reset(2)

func _on_slot_3_reset_button_pressed() -> void:
	_request_reset(3)

func _request_reset(slot: int) -> void:
	slot_pending_reset = slot
	confirm_dialog.dialog_text = "Erase Slot %d? This cannot be undone." % slot
	confirm_dialog.popup_centered()

func _on_reset_confirmed() -> void:
	if slot_pending_reset != -1:
		SaveManager.delete_save(slot_pending_reset)
		slot_pending_reset = -1
		_refresh_slot_buttons()

func _on_quit_button_pressed() -> void:
	get_tree().quit()
