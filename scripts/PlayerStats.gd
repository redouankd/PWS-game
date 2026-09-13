extends Node

signal ability_unlocked(ability_name: String)
signal focus_changed(current: int, max: int)

var unlocked_abilities: Dictionary = {
	"double_jump": false,
	"dash": false,
	"wall_climb": false,
}

var max_focus: int = 100
var current_focus: int = 100
var focus_per_parry: int = 50

func has_ability(ability_name: String) -> bool:
	return unlocked_abilities.get(ability_name, false)

func unlock_ability(ability_name: String) -> void:
	if not unlocked_abilities.has(ability_name):
		return
	if unlocked_abilities[ability_name]:
		return
	unlocked_abilities[ability_name] = true
	ability_unlocked.emit(ability_name)

func add_focus(amount: int) -> void:
	current_focus = min(current_focus + amount, max_focus)
	focus_changed.emit(current_focus, max_focus)

func spend_focus(amount: int) -> bool:
	if current_focus < amount:
		return false
	current_focus -= amount
	focus_changed.emit(current_focus, max_focus)
	return true
