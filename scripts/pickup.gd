extends Area2D

@export var ability_name: String = "double_jump"
@export var pickup_label: String = "Double Jump"
@export var pickup_id: String = ""

@onready var prompt_label: Label = $Label

var player_in_range: bool = false

func _ready() -> void:
	if pickup_id != "" and SaveManager.is_pickup_collected(pickup_id):
		queue_free()
		return
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	prompt_label.visible = false

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		player_in_range = true
		prompt_label.visible = true

func _on_body_exited(body: Node) -> void:
	if body.is_in_group("player"):
		player_in_range = false
		prompt_label.visible = false

func _unhandled_input(event: InputEvent) -> void:
	if player_in_range and event.is_action_pressed("interact"):
		_pick_up()

func _pick_up() -> void:
	PlayerStats.unlock_ability(ability_name)
	if pickup_id != "":
		SaveManager.mark_pickup_collected(pickup_id)
	SaveManager.save_game()
	prompt_label.visible = false
	queue_free()
