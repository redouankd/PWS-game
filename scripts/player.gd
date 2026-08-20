extends CharacterBody2D

signal player_died

# ---------- CONSTANTS ----------
const SPEED = 140.0
const JUMP_VELOCITY = -330.0
const JUMP_CUT_MULTIPLIER = 0.5
const DASH_SPEED = 300
const COYOTE_TIME = 0.1
const JUMP_BUFFER_TIME = 0.1
const WALL_JUMP_VELOCITY = Vector2(100.0, -260.0)
const WALL_JUMP_LOCKOUT = 0.13
const WALL_JUMP_CONTROL_LOCK = 0.13

# ---------- DEFLECT / BLOCK ----------
enum { NOT_BLOCKING, PERFECT_WINDOW, LATE_BLOCK }
const PERFECT_DEFLECT_WINDOW = 0.15
const LATE_BLOCK_DAMAGE_REDUCTION = 0.5
const LATE_BLOCK_CHIP_DAMAGE = 3

var block_timer: float = 0.0

# ---------- STATE MACHINE ----------
enum State { IDLE, RUN, JUMP, DASH, ATTACK, HURT, DEAD, WALL_CLING, BLOCK }
var current_state: State = State.IDLE

# ---------- NODES ----------
@onready var dash_timer: Timer = $dash_timer
@onready var dash_cooldown_timer: Timer = $dash_cooldown_timer
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var hitbox_area: Area2D = $HitboxArea
@onready var hitbox_timer: Timer = $hitbox_timer
@onready var hurt_timer: Timer = $hurt_timer
@onready var health: Health = $Health
@onready var camera: Camera2D = $player_cam

# ---------- DASH VARIABLES ----------
var can_dash = true
var dash_direction = 1
var has_air_dashed = false

# ---------- ATTACK VARIABLES ----------
var attack_hitbox_triggered = false
@export var hitbox_offset_x: float = 12.0

# ---------- HURT / KNOCKBACK ----------
var knockback_velocity: Vector2 = Vector2.ZERO

# ---------- DOUBLE JUMP ----------
var has_double_jumped: bool = false

# ---------- WALL CLING ----------
var wall_direction: int = 0
var wall_jump_lockout_timer: float = 0.0
var wall_jump_control_timer: float = 0.0

# ---------- JUMP FORGIVENESS ----------
var coyote_timer: float = 0.0
var jump_buffer_timer: float = 0.0


func _ready() -> void:
	add_to_group("player")
	health.damaged.connect(_on_damaged)
	health.died.connect(_on_died)
	if health.has_signal("perfectly_deflected"):
		health.perfectly_deflected.connect(_on_perfectly_deflected)


func _physics_process(delta: float) -> void:
	apply_gravity(delta)
	update_jump_timers(delta)
	handle_state_transitions()
	run_current_state(delta)
	update_animation()
	move_and_slide()


func apply_gravity(delta: float) -> void:
	if not is_on_floor():
		if current_state != State.WALL_CLING:
			velocity += get_gravity() * delta
	else:
		has_air_dashed = false
		has_double_jumped = false

	if Input.is_action_just_released("jump") and velocity.y < 0:
		velocity.y *= JUMP_CUT_MULTIPLIER


func update_jump_timers(delta: float) -> void:
	if is_on_floor():
		coyote_timer = COYOTE_TIME
	else:
		coyote_timer -= delta

	if Input.is_action_just_pressed("jump"):
		jump_buffer_timer = JUMP_BUFFER_TIME
	else:
		jump_buffer_timer -= delta

	if wall_jump_lockout_timer > 0:
		wall_jump_lockout_timer -= delta

	if wall_jump_control_timer > 0:
		wall_jump_control_timer -= delta


func is_touching_wall_for_cling() -> bool:
	if wall_jump_lockout_timer > 0:
		return false
	if not PlayerStats.has_ability("wall_climb"):
		return false
	if is_on_floor():
		return false
	if not is_on_wall():
		return false

	var direction := Input.get_axis("move_left", "move_right")
	var normal = get_wall_normal()
	if normal.x > 0 and direction < 0:
		return true
	if normal.x < 0 and direction > 0:
		return true
	return false


func get_deflect_state() -> int:
	if current_state != State.BLOCK:
		return NOT_BLOCKING
	if block_timer <= PERFECT_DEFLECT_WINDOW:
		return PERFECT_WINDOW
	return LATE_BLOCK


func handle_state_transitions() -> void:
	if current_state == State.HURT or current_state == State.DEAD or current_state == State.DASH:
		return

	var direction := Input.get_axis("move_left", "move_right")
	var can_dash_now = can_dash and (is_on_floor() or not has_air_dashed)

	if current_state == State.ATTACK:
		if Input.is_action_just_pressed("dash") and can_dash_now:
			hitbox_area.disable_hitbox()
			start_dash()
			return
		return

	# Block — held, not just pressed
	if Input.is_action_pressed("block") and is_on_floor():
		if current_state != State.BLOCK:
			block_timer = 0.0
			print("Block started")
		current_state = State.BLOCK
		return
	elif current_state == State.BLOCK:
		print("Block released")
		current_state = State.IDLE

	if current_state == State.WALL_CLING:
		if jump_buffer_timer > 0:
			velocity.x = WALL_JUMP_VELOCITY.x * -wall_direction
			velocity.y = WALL_JUMP_VELOCITY.y
			has_double_jumped = false
			jump_buffer_timer = 0
			wall_jump_lockout_timer = WALL_JUMP_LOCKOUT
			wall_jump_control_timer = WALL_JUMP_CONTROL_LOCK
			current_state = State.JUMP
			return
		if is_on_floor():
			current_state = State.JUMP
		elif not is_touching_wall_for_cling():
			current_state = State.JUMP
		else:
			return

	if is_touching_wall_for_cling():
		if current_state != State.WALL_CLING:
			has_double_jumped = false
		current_state = State.WALL_CLING
		wall_direction = 1 if get_wall_normal().x < 0 else -1
		return

	if Input.is_action_just_pressed("attack"):
		current_state = State.ATTACK
		attack_hitbox_triggered = false
		return

	if Input.is_action_just_pressed("dash") and can_dash_now:
		start_dash()
		return

	if jump_buffer_timer > 0:
		if is_on_floor() or coyote_timer > 0:
			velocity.y = JUMP_VELOCITY
			coyote_timer = 0
			jump_buffer_timer = 0
			current_state = State.JUMP
			return
		elif PlayerStats.has_ability("double_jump") and not has_double_jumped:
			velocity.y = JUMP_VELOCITY
			has_double_jumped = true
			jump_buffer_timer = 0
			current_state = State.JUMP
			return

	if not is_on_floor():
		current_state = State.JUMP
		return

	current_state = State.RUN if direction != 0 else State.IDLE


func run_current_state(delta: float) -> void:
	var direction := Input.get_axis("move_left", "move_right")

	match current_state:
		State.IDLE:
			velocity.x = move_toward(velocity.x, 0, SPEED)

		State.RUN:
			velocity.x = direction * SPEED
			face_direction(direction)

		State.JUMP:
			if wall_jump_control_timer > 0:
				pass
			elif direction != 0:
				velocity.x = direction * SPEED
				face_direction(direction)
			else:
				velocity.x = move_toward(velocity.x, 0, SPEED)

		State.DASH:
			velocity.x = dash_direction * DASH_SPEED

		State.ATTACK:
			velocity.x = direction * SPEED
			if direction != 0:
				face_direction(direction)
			if not attack_hitbox_triggered:
				attack_hitbox_triggered = true
				hitbox_area.enable_hitbox()
				hitbox_timer.start()

		State.HURT:
			velocity = knockback_velocity
			knockback_velocity = knockback_velocity.move_toward(Vector2.ZERO, SPEED * 4 * delta)

		State.WALL_CLING:
			velocity.x = 0
			velocity.y = 0
			animated_sprite.flip_h = wall_direction < 0

		State.BLOCK:
			velocity.x = move_toward(velocity.x, 0, SPEED)
			block_timer += delta
			if block_timer <= PERFECT_DEFLECT_WINDOW:
				print("Perfect window active — t=", block_timer)
			else:
				print("Late block — t=", block_timer)

		State.DEAD:
			velocity.x = move_toward(velocity.x, 0, SPEED)


func update_animation() -> void:
	match current_state:
		State.IDLE:
			animated_sprite.play("idle")
		State.RUN:
			animated_sprite.play("run")
		State.JUMP:
			animated_sprite.play("jump")
		State.DASH:
			animated_sprite.play("dash")
		State.ATTACK:
			animated_sprite.play("attack_1")
		State.HURT:
			animated_sprite.play("hurt")
		State.WALL_CLING:
			animated_sprite.play("wall_cling")
		State.BLOCK:
			if animated_sprite.animation != "block":
				animated_sprite.play("block")
		State.DEAD:
			pass


func face_direction(direction: float) -> void:
	if direction > 0:
		animated_sprite.flip_h = false
		hitbox_area.position.x = hitbox_offset_x
	elif direction < 0:
		animated_sprite.flip_h = true
		hitbox_area.position.x = -hitbox_offset_x


func start_dash() -> void:
	current_state = State.DASH
	can_dash = false
	dash_direction = -1 if animated_sprite.flip_h else 1
	dash_timer.start()
	dash_cooldown_timer.start()
	if not is_on_floor():
		has_air_dashed = true


func flash_hit() -> void:
	var tween = create_tween()
	animated_sprite.modulate = Color(1, 1, 1, 1)
	tween.tween_property(animated_sprite, "modulate", Color(4, 4, 4, 1), 0.05)
	tween.tween_property(animated_sprite, "modulate", Color(1, 1, 1, 1), 0.1)


func flash_perfect_parry() -> void:
	var tween = create_tween()
	animated_sprite.modulate = Color(1, 1, 1, 1)
	tween.tween_property(animated_sprite, "modulate", Color(2.5, 2.5, 6, 1), 0.04)
	tween.tween_property(animated_sprite, "modulate", Color(0.5, 0.5, 2, 1), 0.08)
	tween.tween_property(animated_sprite, "modulate", Color(1, 1, 1, 1), 0.15)


# ---------- SIGNALS ----------
func _on_timer_timeout() -> void:
	current_state = State.IDLE

func _on_dash_cooldown_timer_timeout() -> void:
	can_dash = true

func _on_hitbox_timer_timeout() -> void:
	hitbox_area.disable_hitbox()

func _on_animated_sprite_2d_animation_finished() -> void:
	if current_state == State.ATTACK:
		current_state = State.IDLE

func _on_hurt_timer_timeout() -> void:
	if current_state != State.DEAD:
		current_state = State.IDLE

func _on_damaged(amount: int, knockback_dir: Vector2) -> void:
	if current_state == State.DEAD:
		return
	current_state = State.HURT
	knockback_velocity = knockback_dir
	hurt_timer.start()
	flash_hit()
	var shake_strength = clamp(knockback_dir.length() / 20.0, 2.0, 8.0)
	GameEffects.screen_shake(camera, shake_strength, 0.1)

func _on_perfectly_deflected(source: Node, attack_type: int) -> void:
	print("PERFECT DEFLECT! Source: ", source, " type: ", attack_type)
	flash_perfect_parry()
	GameEffects.hit_stop(0.15, 0.02)
	GameEffects.screen_shake(camera, 6.0, 0.15)

func _on_died() -> void:
	current_state = State.DEAD
	hitbox_area.monitoring = false
	velocity = Vector2.ZERO
	set_physics_process(false)
	animated_sprite.play("death")
	await animated_sprite.animation_finished
	player_died.emit()
