extends Node

signal ability_unlocked(ability_name: String)

var unlocked_abilities: Dictionary = {
	"double_jump": false,
	"dash": false,
	"wall_climb": false,
}

func has_ability(ability_name: String) -> bool:
	return unlocked_abilities.get(ability_name, false)

func unlock_ability(ability_name: String) -> void:
	if not unlocked_abilities.has(ability_name):
		return
	if unlocked_abilities[ability_name]:
		return  # already unlocked, don't re-fire the signal
	unlocked_abilities[ability_name] = true
	ability_unlocked.emit(ability_name)
