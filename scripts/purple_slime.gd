extends CharacterBody2D

# ---------- CONSTANTS ----------
const CHASE_SPEED = 80.0
const ATTACK_RANGE = 10.0

# ---------- STATE MACHINE ----------
enum State { IDLE, CHASE, ATTACK, HURT, DEAD, }
var current_state: State = State.IDLE

# ---------- NODES ----------
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var hitbox_area: Area2D = $HitboxArea
@onready var hitbox_timer: Timer = $hitbox_timer
@onready var attack_cooldown_timer: Timer = $attack_cooldown_timer
@onready var detection_area: Area2D = $DetectionArea
@onready var health: Health = $Health
@onready var hurt_timer: Timer = $hurt_timer

# ---------- DETECTION ----------
var player_ref: Node2D = null

# ---------- ATTACK ----------
var attack_hitbox_triggered = false

# ---------- KNOCKBACK ----------
var knockback_velocity: Vector2 = Vector2.ZERO

# ---------- HITBOX FLIP ----------
@export var hitbox_offset_x: float = 1.0


func _ready() -> void:
	detection_area.body_entered.connect(_on_detection_body_entered)
	detection_area.body_exited.connect(_on_detection_body_exited)
	health.damaged.connect(_on_damaged)
	health.died.connect(_on_died)

func _physics_process(delta: float) -> void:
	apply_gravity(delta)
	handle_state_transitions()
	run_current_state(delta)
	update_animation()
	move_and_slide()


func apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta


# ---------- DETECTION SIGNALS ----------
func _on_detection_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		player_ref = body

func _on_detection_body_exited(body: Node) -> void:
	if body == player_ref:
		player_ref = null


# ---------- STATE TRANSITIONS ----------
func handle_state_transitions() -> void:
	if current_state == State.HURT or current_state == State.ATTACK or current_state == State.DEAD:
		return

	if player_ref == null:
		current_state = State.IDLE
		return

	var distance = global_position.distance_to(player_ref.global_position)

	if distance <= ATTACK_RANGE and attack_cooldown_timer.is_stopped():
		current_state = State.ATTACK
		attack_hitbox_triggered = false
		return

	current_state = State.CHASE


# ---------- PER-STATE BEHAVIOR ----------
func run_current_state(delta: float) -> void:
	match current_state:
		State.IDLE:
			velocity.x = move_toward(velocity.x, 0, CHASE_SPEED)

		State.CHASE:
			var direction = sign(player_ref.global_position.x - global_position.x)
			velocity.x = direction * CHASE_SPEED
			face_direction(direction)

		State.ATTACK:
			velocity.x = 0
			if player_ref != null:
				var direction = sign(player_ref.global_position.x - global_position.x)
				face_direction(direction)

			if not attack_hitbox_triggered:
				attack_hitbox_triggered = true
				hitbox_area.enable_hitbox()
				hitbox_timer.start()
				attack_cooldown_timer.start()

		State.HURT:
			velocity.x = knockback_velocity.x
			knockback_velocity.x = move_toward(knockback_velocity.x, 0, CHASE_SPEED * 4 * delta)
		
		State.DEAD:
			velocity.x = move_toward(velocity.x, 0, CHASE_SPEED * 4 * delta)

# ---------- ANIMATION ----------
func update_animation() -> void:
	match current_state:
		State.IDLE:
			animated_sprite.play("idle")
		State.CHASE:
			animated_sprite.play("run")
		State.ATTACK:
			animated_sprite.play("attack_1")
		State.HURT:
			animated_sprite.play("hurt")
		State.DEAD:
			pass


# ---------- HELPERS ----------
func face_direction(direction: float) -> void:
	if direction > 0:
		animated_sprite.flip_h = false
		hitbox_area.position.x = hitbox_offset_x
	elif direction < 0:
		animated_sprite.flip_h = true
		hitbox_area.position.x = -hitbox_offset_x

func flash_hit() -> void:
	var tween = create_tween()
	animated_sprite.modulate = Color(1, 1, 1, 1)
	tween.tween_property(animated_sprite, "modulate", Color(4, 4, 4, 1), 0.05)
	tween.tween_property(animated_sprite, "modulate", Color(1, 1, 1, 1), 0.1)

func apply_stun(duration: float) -> void:
	current_state = State.HURT
	if player_ref != null:
		var direction_away = (global_position - player_ref.global_position).normalized()
		knockback_velocity = direction_away * 100.0
	else:
		knockback_velocity = Vector2.ZERO
	hurt_timer.wait_time = duration
	hurt_timer.start()
	flash_hit()

# ---------- SIGNALS ----------
func _on_hitbox_timer_timeout() -> void:
	hitbox_area.disable_hitbox()

func _on_animated_sprite_2d_animation_finished() -> void:
	if current_state == State.ATTACK:
		current_state = State.IDLE

func _on_damaged(amount: int, knockback_dir: Vector2) -> void:
	if current_state == State.DEAD:
		return
	current_state = State.HURT
	knockback_velocity = knockback_dir
	hurt_timer.start()
	flash_hit()

func _on_hurt_timer_timeout() -> void:
	if current_state != State.DEAD:
		current_state = State.IDLE

func _on_attack_cooldown_timer_timeout() -> void:
	pass

func _on_died() -> void:
	current_state = State.DEAD
	hitbox_area.monitoring = false
	detection_area.monitoring = false
	animated_sprite.modulate = Color(1, 1, 1, 1)   # reset in case a flash tween was mid-flight
	animated_sprite.play("death")
	await animated_sprite.animation_finished
	queue_free()
