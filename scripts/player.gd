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
const WALL_JUMP_LOCKOUT = 0.10
const WALL_JUMP_CONTROL_LOCK = 0.10
const WALL_SLIDE_SPEED = 60.0
const ATTACK_COOLDOWN = 0.1
const ATTACK_DURATION = 0.3
const INVINCIBILITY_DURATION = 0.8
const MAX_FALL_SPEED = 400.0

const BeamEffect = preload("res://scenes/BeamEffect.tscn")
const DashTrail = preload("res://scenes/DashTrail.tscn")
# ---------- DOWN / UP STRIKE ----------
const POGO_BOUNCE_MULTIPLIER = 0.85
const POGO_MIN_BOUNCE = -280.0
const POGO_MAX_BOUNCE = -280.0

# ---------- FOCUS / HEAL / SPECIAL ----------
const HEAL_FOCUS_COST = 100
const HEAL_AMOUNT = 20
const HEAL_DURATION = 1.0
const SPECIAL_FOCUS_COST = 33

# ---------- DEFLECT / BLOCK ----------
enum { NOT_BLOCKING, PERFECT_WINDOW, LATE_BLOCK }
const PERFECT_DEFLECT_WINDOW = 0.15
const LATE_BLOCK_DAMAGE_REDUCTION = 0.5
const LATE_BLOCK_CHIP_DAMAGE = 3

var block_timer: float = 0.0

# ---------- STATE MACHINE ----------
enum State { IDLE, RUN, JUMP, DASH, ATTACK, HURT, DEAD, WALL_CLING, BLOCK, HEAL }
var current_state: State = State.IDLE

# ---------- SOUNDS -----------------
@export_group("Sounds")
@export var jump_sound: AudioStream
@export var attack_sound: AudioStream
@export var hurt_sound: AudioStream
@export var late_block_sound: AudioStream
@export var perfect_deflect_sound: AudioStream
@export var death_sound: AudioStream
@export var dash_sound: AudioStream
@export var heal_channel_sound: AudioStream
@export var heal_complete_sound: AudioStream

# ---------- NODES ----------
@onready var dash_timer: Timer = $dash_timer
@onready var dash_cooldown_timer: Timer = $dash_cooldown_timer
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var hitbox_area: Area2D = $HitboxArea
@onready var down_hitbox_area: Area2D = $DownHitboxArea
@onready var up_hitbox_area: Area2D = $UpHitboxArea
@onready var hitbox_timer: Timer = $hitbox_timer
@onready var attack_duration_timer: Timer = $attack_duration_timer
@onready var hurt_timer: Timer = $hurt_timer
@onready var health: Health = $Health
@onready var camera: Camera2D = $player_cam

# ---------- DASH VARIABLES ----------
var can_dash = true
var dash_direction = 1
var has_air_dashed = false

# ---------- ATTACK VARIABLES ----------
var attack_hitbox_triggered = false
var attack_cooldown_timer_value: float = 0.0
var attack_direction: String = "side"
@export var hitbox_offset_x: float = 18.0
@export var beam_offset_up: Vector2 = Vector2(0, -16)
@export var beam_offset_down: Vector2 = Vector2(0, 12)
@export var beam_offset_side: Vector2 = Vector2(14, -8)

# ---------- HURT / KNOCKBACK ----------
var knockback_velocity: Vector2 = Vector2.ZERO

# ---------- INVINCIBILITY ----------
var is_invincible: bool = false
var invincibility_timer: float = 0.0

# ---------- DOUBLE JUMP ----------
var has_double_jumped: bool = false
var is_double_jumping: bool = false
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
	down_hitbox_area.hit_landed.connect(_on_pogo_hit)

	if SaveManager.last_save_point_id != "":	
		_apply_save_point_position()
	

func _physics_process(delta: float) -> void:
	apply_gravity(delta)
	update_jump_timers(delta)
	handle_state_transitions()
	run_current_state(delta)
	update_animation()
	move_and_slide()

func apply_gravity(delta: float) -> void:
	if not is_on_floor():
		if current_state != State.WALL_CLING and current_state != State.DASH:
			velocity += get_gravity() * delta
			velocity.y = min(velocity.y, MAX_FALL_SPEED)
	else:
		has_air_dashed = false
		has_double_jumped = false
		is_double_jumping = false

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

	if attack_cooldown_timer_value > 0:
		attack_cooldown_timer_value -= delta

	if invincibility_timer > 0:
		invincibility_timer -= delta
		if invincibility_timer <= 0:
			is_invincible = false


func is_currently_invincible() -> bool:
	return is_invincible


func is_touching_wall_for_cling() -> bool:
	if wall_jump_lockout_timer > 0:
		return false
	if not PlayerStats.has_ability("wall_climb"):
		return false
	if is_on_floor():
		return false
	if not is_on_wall():
		return false
	if velocity.y < 0:
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
	if current_state == State.HURT or current_state == State.DEAD or current_state == State.DASH or current_state == State.HEAL:
		return

	var direction := Input.get_axis("move_left", "move_right")
	var can_dash_now = PlayerStats.has_ability("dash") and can_dash and (is_on_floor() or not has_air_dashed)

	if current_state == State.ATTACK:
		if Input.is_action_just_pressed("dash") and can_dash_now:
			hitbox_area.disable_hitbox()
			down_hitbox_area.disable_hitbox()
			up_hitbox_area.disable_hitbox()
			start_dash()
			return
		return

	if Input.is_action_just_pressed("heal"):
		try_heal()
		return

	if Input.is_action_just_pressed("special"):
		try_special_attack()
		return

	if Input.is_action_pressed("block") and is_on_floor():
		if current_state != State.BLOCK:
			if Input.is_action_just_pressed("block"):
				block_timer = 0.0
				print("[BLOCK] Fresh press: perfect window started")
			else:
				block_timer = PERFECT_DEFLECT_WINDOW + 1.0
				print("[BLOCK] Resumed while held: late block only")

		current_state = State.BLOCK
		return
	elif current_state == State.BLOCK:
		current_state = State.IDLE
	
	if current_state == State.WALL_CLING:
		if jump_buffer_timer > 0:
			velocity.x = WALL_JUMP_VELOCITY.x * -wall_direction
			velocity.y = WALL_JUMP_VELOCITY.y
			has_double_jumped = false
			is_double_jumping = false
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
			has_air_dashed = false
		current_state = State.WALL_CLING
		wall_direction = 1 if get_wall_normal().x < 0 else -1
		return

	if Input.is_action_just_pressed("attack") and attack_cooldown_timer_value <= 0:
		current_state = State.ATTACK
		SoundManager.play_sfx(attack_sound)
		attack_hitbox_triggered = false

		if not is_on_floor() and Input.is_action_pressed("down"):
			attack_direction = "down"
		elif Input.is_action_pressed("up"):
			attack_direction = "up"
		else:
			attack_direction = "side"

		attack_duration_timer.wait_time = ATTACK_DURATION
		attack_duration_timer.start()

		return

	if Input.is_action_just_pressed("dash") and can_dash_now:
		start_dash()
		return

	if jump_buffer_timer > 0:
		if is_on_floor() or coyote_timer > 0:
			SoundManager.play_sfx(jump_sound)
			velocity.y = JUMP_VELOCITY
			coyote_timer = 0
			jump_buffer_timer = 0
			is_double_jumping = false
			current_state = State.JUMP
			return
		elif PlayerStats.has_ability("double_jump") and not has_double_jumped:
			SoundManager.play_sfx(jump_sound)
			velocity.y = JUMP_VELOCITY
			has_double_jumped = true
			jump_buffer_timer = 0
			is_double_jumping = true
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
			velocity.y = 0	
			dash_trail_timer -= delta
			if dash_trail_timer <= 0:
				dash_trail_timer = dash_trail_interval
				spawn_dash_trail()

		State.ATTACK:
			velocity.x = direction * SPEED
			if direction != 0:
				face_direction(direction)
			if not attack_hitbox_triggered:
				attack_hitbox_triggered = true
				match attack_direction:
					"down":
						down_hitbox_area.enable_hitbox()
					"up":
						up_hitbox_area.enable_hitbox()
					_:
						hitbox_area.enable_hitbox()
				hitbox_timer.start()
				spawn_beam()

		State.HURT:
			velocity = knockback_velocity
			knockback_velocity = knockback_velocity.move_toward(Vector2.ZERO, SPEED * 4 * delta)

		State.WALL_CLING:
			velocity.x = wall_direction * 20.0
			velocity.y = WALL_SLIDE_SPEED
			animated_sprite.flip_h = wall_direction < 0

		State.BLOCK:
			velocity.x = move_toward(velocity.x, 0, SPEED)
			block_timer += delta
			
			if block_timer <= PERFECT_DEFLECT_WINDOW:
				print("[BLOCK] PERFECT window | Time: %.3f s" % block_timer)
			else:
				print("[BLOCK] LATE block | Time: %.3f s" % block_timer)

		State.HEAL:
			velocity.x = 0

		State.DEAD:
			velocity.x = move_toward(velocity.x, 0, SPEED)


func spawn_beam() -> void:
	var beam = BeamEffect.instantiate()
	add_child(beam)

	match attack_direction:
		"down":
			beam.position = beam_offset_down
			beam.rotation = Vector2.DOWN.angle()
		"up":
			beam.position = beam_offset_up
			beam.rotation = Vector2.UP.angle()
		_:
			var dir = -1 if animated_sprite.flip_h else 1
			beam.position = Vector2(beam_offset_side.x * dir, beam_offset_side.y)
			beam.rotation = 0
			beam.get_node("AnimatedSprite2D").flip_h = animated_sprite.flip_h


func get_attack_animation() -> String:
	match attack_direction:
		"down":
			return "attack_down"
		"up":
			return "attack_up"
		_:
			return "attack_1"


func update_animation() -> void:
	match current_state:
		State.IDLE:
			if animated_sprite.animation != "idle":
				animated_sprite.play("idle")
		State.RUN:
			if animated_sprite.animation != "run":
				animated_sprite.play("run")
		State.JUMP:
			var jump_anim = "double_jump" if is_double_jumping else "jump"
			if animated_sprite.animation != jump_anim:
				animated_sprite.play(jump_anim)
		State.DASH:
			if animated_sprite.animation != "dash":
				animated_sprite.play("dash")
		State.ATTACK:
			var anim_name = get_attack_animation()
			if animated_sprite.animation != anim_name:
				animated_sprite.play(anim_name)
		State.HURT:
			if animated_sprite.animation != "hurt":
				animated_sprite.play("hurt")
		State.WALL_CLING:
			if animated_sprite.animation != "wall_cling":
				animated_sprite.flip_h
				animated_sprite.play("wall_cling")
		State.BLOCK:
			if animated_sprite.animation != "block":
				animated_sprite.play("block")
		State.HEAL:
			pass
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
	SoundManager.play_sfx(dash_sound)
	current_state = State.DASH
	can_dash = false
	is_double_jumping = false
	dash_direction = -1 if animated_sprite.flip_h else 1
	dash_timer.start()
	dash_cooldown_timer.start()
	dash_trail_timer = 0.0
	if not is_on_floor():
		has_air_dashed = true


func try_heal() -> void:
	if not is_on_floor():
		return
	if PlayerStats.spend_focus(HEAL_FOCUS_COST):
		current_state = State.HEAL
		SoundManager.play_sfx(heal_channel_sound)
		health.heal(HEAL_AMOUNT)
		var timer = get_tree().create_timer(HEAL_DURATION)
		var tween = create_tween()
		animated_sprite.modulate = Color(1, 1, 1, 1)
		tween.tween_property(animated_sprite, "modulate", Color(2.5, 2.5, 6, 1), 0.04)
		tween.tween_property(animated_sprite, "modulate", Color(0.385, 0.981, 0.0, 1.0), 0.08)
		tween.tween_property(animated_sprite, "modulate", Color(1, 1, 1, 1), 0.15)
		await timer.timeout
		if current_state == State.HEAL:
			current_state = State.IDLE
			SoundManager.play_sfx(heal_complete_sound)


func try_special_attack() -> void:
	if not PlayerStats.spend_focus(SPECIAL_FOCUS_COST):
		return

	if Input.is_action_pressed("up"):
		special_attack_up()
	elif Input.is_action_pressed("down") and not is_on_floor():
		special_attack_down()
	else:
		special_attack_side()


func special_attack_up() -> void:
	print("Special (UP) triggered — no ability assigned yet")

func special_attack_down() -> void:
	print("Special (DOWN) triggered — no ability assigned yet")

func special_attack_side() -> void:
	print("Special (SIDE) triggered — no ability assigned yet")


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

@export var dash_trail_interval: float = 0.03
var dash_trail_timer: float = 0.0

func spawn_dash_trail() -> void:
	var ghost := Sprite2D.new()
	ghost.texture = animated_sprite.sprite_frames.get_frame_texture(animated_sprite.animation, animated_sprite.frame)
	ghost.global_position = global_position
	ghost.flip_h = animated_sprite.flip_h
	ghost.centered = animated_sprite.centered
	ghost.modulate = Color(0.6, 0.8, 1.0, 0.5)
	get_tree().current_scene.add_child(ghost)
	var tween := ghost.create_tween()
	tween.tween_property(ghost, "modulate:a", 0.0, 0.25)
	tween.tween_callback(ghost.queue_free)

func start_invincibility_flicker() -> void:
	var flicker_tween = create_tween()
	flicker_tween.set_loops(int(INVINCIBILITY_DURATION / 0.1))
	flicker_tween.tween_property(animated_sprite, "modulate:a", 0.3, 0.05)
	flicker_tween.tween_property(animated_sprite, "modulate:a", 1.0, 0.05)

func _apply_save_point_position() -> void:
	global_position = SaveManager.last_save_position
	var limits = SaveManager.last_camera_limits
	camera.limit_left = int(limits.position.x)
	camera.limit_right = int(limits.end.x)
	camera.limit_top = -100000
	camera.limit_bottom = 100000
	camera.reset_smoothing()

func respawn_at_save_point() -> void:
	var ui = get_tree().get_first_node_in_group("ui")
	var fade = ui.get_node("TransitionFade") if ui else null

	if fade:
		await fade.fade_out(0.5)

	await get_tree().create_timer(0.6).timeout

	if SaveManager.last_save_point_id == "":
		global_position = Vector2.ZERO
	else:
		_apply_save_point_position()

	health.current_health = health.max_health
	health.healed.emit(health.current_health)

	current_state = State.IDLE
	set_physics_process(true)
	hitbox_area.monitoring = false
	down_hitbox_area.monitoring = false
	up_hitbox_area.monitoring = false
	animated_sprite.modulate = Color(1, 1, 1, 1)

	if fade:
		await fade.fade_in(0.5)

# ---------- SIGNALS ----------
func _on_timer_timeout() -> void:
	current_state = State.IDLE

func _on_dash_cooldown_timer_timeout() -> void:
	can_dash = true

func _on_hitbox_timer_timeout() -> void:
	hitbox_area.disable_hitbox()
	down_hitbox_area.disable_hitbox()
	up_hitbox_area.disable_hitbox()

func _on_animated_sprite_2d_animation_finished() -> void:
	pass

func _on_attack_duration_timer_timeout() -> void:
	if current_state == State.ATTACK:
		current_state = State.IDLE
		attack_cooldown_timer_value = ATTACK_COOLDOWN

func _on_hurt_timer_timeout() -> void:
	if current_state != State.DEAD:
		current_state = State.IDLE

func _on_damaged(amount: int, knockback_dir: Vector2) -> void:
	if current_state == State.DEAD:
		return
	if current_state == State.BLOCK:
		SoundManager.play_sfx(late_block_sound)
	else:
		SoundManager.play_sfx(hurt_sound)
	current_state = State.HURT
	knockback_velocity = knockback_dir
	hurt_timer.start()
	flash_hit()
	var shake_strength = clamp(knockback_dir.length() / 20.0, 2.0, 8.0)
	GameEffects.screen_shake(camera, shake_strength, 0.1)

	is_invincible = true
	invincibility_timer = INVINCIBILITY_DURATION
	start_invincibility_flicker()

func _on_perfectly_deflected(source: Node, attack_type: int) -> void:
	
	SoundManager.play_sfx(perfect_deflect_sound)
	flash_perfect_parry()
	GameEffects.hit_stop(0.15, 0.02)
	GameEffects.screen_shake(camera, 6.0, 0.15)
	PlayerStats.add_focus(PlayerStats.focus_per_parry)

func _on_pogo_hit() -> void:
	var bounce = clamp(velocity.y * -POGO_BOUNCE_MULTIPLIER, POGO_MAX_BOUNCE, POGO_MIN_BOUNCE)
	velocity.y = bounce
	current_state = State.JUMP
	has_double_jumped = false
	has_air_dashed = false
	can_dash = true
	dash_cooldown_timer.stop()

func _on_died() -> void:
	SoundManager.play_sfx(death_sound)
	current_state = State.DEAD
	hitbox_area.monitoring = false
	down_hitbox_area.monitoring = false
	up_hitbox_area.monitoring = false
	velocity = Vector2.ZERO
	set_physics_process(false)
	for door in get_tree().get_nodes_in_group("laser_door"):
		door.deactivate()
	animated_sprite.play("death")
	await animated_sprite.animation_finished

	var ui = get_tree().get_first_node_in_group("ui")
	var fade = ui.get_node("TransitionFade") if ui else null
	if fade:
		await fade.fade_out(0.4)

	get_tree().reload_current_scene()
