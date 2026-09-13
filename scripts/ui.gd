extends CanvasLayer

@onready var health_bar: ProgressBar = $HealthBar
@onready var game_over_label: Label = $GameOverLabel
@onready var boss_health_bar: ProgressBar = $BossHealthBar

@export var player_health: Health
@export var player: CharacterBody2D  
@export var boss_health: Health
@onready var focus_bar: ProgressBar = $FocusBar



func _ready() -> void:
	add_to_group("ui")
	game_over_label.visible = false
	boss_health_bar.visible = false

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

func _process(_delta: float) -> void:
	if game_over_label.visible and Input.is_action_just_pressed("ui_accept"):
		get_tree().reload_current_scene()
