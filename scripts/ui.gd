extends CanvasLayer

@onready var health_bar: ProgressBar = $HealthBar
@onready var game_over_label: Label = $GameOverLabel
@onready var boss_health_bar: ProgressBar = $BossHealthBar

@export var player_health: Health
@export var player: CharacterBody2D  
@export var boss_health: Health
@onready var focus_bar: ProgressBar = $FocusBar
@onready var pickup_popup: Label = $PickupPopup
@onready var pause_overlay: ColorRect = $ColorRect
@onready var pause_menu: Control = $PauseMenu

const ABILITY_DISPLAY_NAMES := {
	"double_jump": "Double Jump Unlocked!",
	"dash": "Dash Unlocked!",
	"wall_climb": "Wall Climb Unlocked!"
}

func _ready() -> void:
	add_to_group("ui")
	game_over_label.visible = false
	boss_health_bar.visible = false
	pickup_popup.visible = false
	pickup_popup.modulate.a = 0.0
	PlayerStats.ability_unlocked.connect(_on_ability_unlocked)

	health_bar.max_value = player_health.max_health
	health_bar.value = player_health.current_health
	player_health.damaged.connect(_on_player_damaged)
	player_health.died.connect(_on_player_died)
	player_health.healed.connect(_on_player_healed)
	player.player_died.connect(_on_player_animation_done)

	if boss_health:
		boss_health_bar.max_value = boss_health.max_health
		boss_health_bar.value = boss_health.current_health
		boss_health.damaged.connect(_on_boss_damaged)
		boss_health.died.connect(_on_boss_died)

	focus_bar.max_value = PlayerStats.max_focus
	focus_bar.value = PlayerStats.current_focus
	PlayerStats.focus_changed.connect(_on_focus_changed)

func _on_player_healed(current: int) -> void:
	health_bar.value = current
	
func _on_focus_changed(current: int, max: int) -> void:
	focus_bar.value = current
	
		
func _on_player_damaged(amount: int, knockback_dir: Vector2) -> void:
	health_bar.value = player_health.current_health

func _on_player_died() -> void:
	health_bar.value = 0

func _on_player_animation_done() -> void:
	game_over_label.visible = true

func _on_boss_damaged(amount: int, knockback_dir: Vector2) -> void:
	print("Boss damaged signal received, current HP: ", boss_health.current_health)
	boss_health_bar.value = boss_health.current_health

func _on_boss_died() -> void:
	boss_health_bar.visible = false

func show_boss_bar() -> void:
	boss_health_bar.visible = true
	
func hide_boss_bar() -> void:
	boss_health_bar.visible = false

func _on_ability_unlocked(ability_name: String) -> void:
	pickup_popup.text = ABILITY_DISPLAY_NAMES.get(ability_name, "New Ability Unlocked!")
	pickup_popup.modulate.a = 1.0
	pickup_popup.visible = true
	pause_overlay.visible = true

	pause_menu.process_mode = Node.PROCESS_MODE_DISABLED
	get_tree().paused = true
	await get_tree().create_timer(3.0).timeout
	get_tree().paused = false
	pause_menu.process_mode = Node.PROCESS_MODE_ALWAYS

	pause_overlay.visible = false
	var tween := create_tween()
	tween.tween_property(pickup_popup, "modulate:a", 0.0, 0.5)
	tween.tween_callback(func(): pickup_popup.visible = false)

func _process(_delta: float) -> void:
	if game_over_label.visible and Input.is_action_just_pressed("ui_accept"):
		get_tree().reload_current_scene()
