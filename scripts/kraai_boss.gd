extends CharacterBody2D

# ---------- FLIGHT ----------
@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D
@onready var base_scale: Vector2 = animated_sprite_2d.scale
@export var flight_points: Array[NodePath] = []
@export var fly_speed = 150.0
@export var hover_amplitude = 8.0
@export var hover_frequency = 3.0
@export var curve_smoothness = 0.2

var curve: Curve2D
var path_length: float
var distance_traveled = 0.0
var time_alive = 0.0
var direction_forward = true

# ---------- COMBAT ----------
enum State { FLYING, ATTACK, DEAD }
var current_state: State = State.FLYING

enum AttackType { MELEE, PROJECTILE, BURST, DASH, RETREAT_SHOT }

@onready var health: Health = $Health
@onready var hitbox_area: Area2D = $HitboxArea
@onready var hitbox_timer: Timer = $hitbox_timer
@onready var attack_cooldown_timer: Timer = $attack_cooldown_timer
@onready var arena_bounds: Area2D = $"../ArenaBounds"
@onready var ui: CanvasLayer = $"../UI"

@export var projectile_scene: PackedScene
@export var melee_range: float = 120.0
@export var ranged_trigger_range: float = 450.0
@export var projectile_speed: float = 300.0
@export var hitbox_offset_x: float = 12.0
@export var burst_chance: float = 0.35
@export var dash_chance: float = 0.4
@export var dash_stop_distance: float = 10.0
@export var max_melee_in_a_row: int = 2
@export var dash_telegraph_duration: float = 0.6

# ---------- PHASE 2 BULLET HELL INTRO ----------
@export var phase_2_burst_count: int = 12
@export var phase_2_burst_waves: int = 6
@export var phase_2_burst_wave_delay: float = 0.7
@export var phase_2_burst_speed: float = 180.0
@export var phase_2_burst_rotation_offset: float = 15.0
@export var phase_2_fly_up_height: float = 120.0
@export var phase_2_fly_up_duration: float = 0.6
@export var phase_2_pre_burst_pause: float = 0.5
@export var phase_2_max_height_y: float = 500.0

var player_ref: Node2D = null
var attack_hitbox_triggered = false
var player_in_arena: bool = false
var phase_2_triggered = false
var is_dashing: bool = false
var melee_streak: int = 0


func _ready():
	var points: Array[Vector2] = []
	for p in flight_points:
		points.append(get_node(p).global_position)
	curve = Curve2D.new()
	for i in points.size():
		var point = points[i]
		var in_dir = Vector2.ZERO
		var out_dir = Vector2.ZERO
		if i > 0 and i < points.size() - 1:
			var dir = (points[i + 1] - points[i - 1]).normalized()
			in_dir = -dir * points[i].distance_to(points[i - 1]) * curve_smoothness
			out_dir = dir * points[i].distance_to(points[i + 1]) * curve_smoothness
		elif i == 0 and points.size() > 1:
			out_dir = (points[i + 1] - points[i]).normalized() * points[i].distance_to(points[i + 1]) * curve_smoothness
		elif i == points.size() - 1 and points.size() > 1:
			in_dir = (points[i] - points[i - 1]).normalized() * -points[i].distance_to(points[i - 1]) * curve_smoothness
		curve.add_point(point, in_dir, out_dir)
	path_length = curve.get_baked_length()
	global_position = points[0]

	player_ref = get_tree().get_first_node_in_group("player")
	health.damaged.connect(_on_damaged)
	health.died.connect(_on_died)

	if not arena_bounds.body_entered.is_connected(_on_arena_body_entered):
		arena_bounds.body_entered.connect(_on_arena_body_entered)
	if not arena_bounds.body_exited.is_connected(_on_arena_body_exited):
		arena_bounds.body_exited.connect(_on_arena_body_exited)

	animated_sprite_2d.play("non_attack")


func _on_arena_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		player_in_arena = true
		ui.show_boss_bar()

func _on_arena_body_exited(body: Node) -> void:
	if body.is_in_group("player"):
		player_in_arena = false


func _physics_process(delta):
	if current_state == State.DEAD:
		return

	time_alive += delta

	if current_state != State.ATTACK and player_ref != null and player_in_arena and attack_cooldown_timer.is_stopped():
		var distance = global_position.distance_to(player_ref.global_position)
		if distance <= ranged_trigger_range:
			current_state = State.ATTACK
			attack_hitbox_triggered = false
			start_attack()

	if current_state == State.ATTACK:
		if not is_dashing:
			velocity = Vector2.ZERO
			move_and_slide()
		return

	_fly_along_curve(delta)
	move_and_slide()


func _fly_along_curve(delta):
	if path_length <= 0:
		return
	if direction_forward:
		distance_traveled += fly_speed * delta
	else:
		distance_traveled -= fly_speed * delta

	if distance_traveled >= path_length:
		distance_traveled = path_length
		direction_forward = false
	elif distance_traveled <= 0:
		distance_traveled = 0
		direction_forward = true

	var target_position = curve.sample_baked(distance_traveled)
	var move_direction = (target_position - global_position)
	var hover_offset = sin(time_alive * hover_frequency) * hover_amplitude
	velocity = move_direction * 10.0 + Vector2(0, hover_offset * delta * 10)

	if move_direction.x != 0:
		animated_sprite_2d.flip_h = move_direction.x > 0
		hitbox_area.position.x = hitbox_offset_x if move_direction.x > 0 else -hitbox_offset_x


# ---------- ATTACK ----------
func choose_attack(distance: float) -> int:
	if distance <= melee_range:
		if melee_streak >= max_melee_in_a_row:
			return AttackType.RETREAT_SHOT
		if randf() < dash_chance * 0.5:
			return AttackType.DASH
		return AttackType.MELEE

	var roll = randf()
	if roll < dash_chance:
		return AttackType.DASH

	if phase_2_triggered:
		return AttackType.BURST
	else:
		return AttackType.PROJECTILE


func start_attack() -> void:
	if player_ref == null:
		return

	var distance = global_position.distance_to(player_ref.global_position)
	var attack_type = choose_attack(distance)

	if attack_type == AttackType.MELEE:
		melee_streak += 1
	else:
		melee_streak = 0

	var direction_to_player = player_ref.global_position.x - global_position.x
	if direction_to_player != 0:
		animated_sprite_2d.flip_h = direction_to_player > 0
		hitbox_area.position.x = hitbox_offset_x if direction_to_player > 0 else -hitbox_offset_x

	if attack_type == AttackType.DASH:
		animated_sprite_2d.play("non_attack")
		var loop_time = dash_telegraph_duration / 4.0
		var telegraph = create_tween()
		telegraph.set_loops(2)
		telegraph.tween_property(animated_sprite_2d, "modulate", Color(2, 0.5, 0.5, 1), loop_time)
		telegraph.tween_property(animated_sprite_2d, "modulate", Color(1, 1, 1, 1), loop_time)
		await telegraph.finished
	elif attack_type == AttackType.RETREAT_SHOT:
		animated_sprite_2d.play("non_attack")
	else:
		animated_sprite_2d.play("wind_up")
		await animated_sprite_2d.animation_finished

	if current_state == State.DEAD:
		return

	match attack_type:
		AttackType.MELEE:
			animated_sprite_2d.play("melee_attack")
			hitbox_area.enable_hitbox()
			hitbox_timer.start()

		AttackType.PROJECTILE:
			animated_sprite_2d.play("ranged_attack")
			fire_projectile()

		AttackType.BURST:
			animated_sprite_2d.play("ranged_attack")
			fire_projectile_burst(3)

		AttackType.DASH:
			await dash_attack()

		AttackType.RETREAT_SHOT:
			await retreat_and_shoot()

	animated_sprite_2d.modulate = Color(1, 1, 1, 1)
	animated_sprite_2d.scale = base_scale

	attack_cooldown_timer.start()
	await get_tree().create_timer(0.6).timeout

	distance_traveled = curve.get_closest_offset(global_position)

	if current_state == State.ATTACK:
		current_state = State.FLYING
		animated_sprite_2d.play("non_attack")


func fire_projectile() -> void:
	if projectile_scene == null or player_ref == null:
		return
	var proj = projectile_scene.instantiate()
	get_tree().current_scene.add_child(proj)
	proj.global_position = global_position
	var direction = (player_ref.global_position - global_position).normalized()
	proj.set_direction(direction * projectile_speed)


func fire_projectile_burst(count: int) -> void:
	if projectile_scene == null or player_ref == null:
		return
	var base_direction = (player_ref.global_position - global_position).normalized()
	var spread_angle = 15.0
	for i in range(count):
		var offset_deg = spread_angle * (i - (count - 1) / 2.0)
		var dir = base_direction.rotated(deg_to_rad(offset_deg))
		var proj = projectile_scene.instantiate()
		get_tree().current_scene.add_child(proj)
		proj.global_position = global_position
		proj.set_direction(dir * projectile_speed)


func dash_attack() -> void:
	if player_ref == null:
		return
	is_dashing = true

	var direction = (player_ref.global_position - global_position).normalized()
	var target_pos = player_ref.global_position - direction * dash_stop_distance

	var tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(self, "global_position", target_pos, 0.25)
	await tween.finished
	is_dashing = false

	animated_sprite_2d.scale = base_scale
	velocity = Vector2.ZERO
	move_and_slide()

	var direction_to_player = player_ref.global_position.x - global_position.x
	if direction_to_player != 0:
		animated_sprite_2d.flip_h = direction_to_player > 0
		hitbox_area.position.x = hitbox_offset_x if direction_to_player > 0 else -hitbox_offset_x

	hitbox_area.enable_hitbox()
	await get_tree().create_timer(0.15).timeout
	hitbox_area.disable_hitbox()


func retreat_and_shoot() -> void:
	is_dashing = true
	var direction_away = (global_position - player_ref.global_position).normalized()
	var target_pos = global_position + direction_away * 150.0

	var tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(self, "global_position", target_pos, 0.3)
	await tween.finished
	is_dashing = false

	velocity = Vector2.ZERO
	move_and_slide()

	animated_sprite_2d.play("wind_up")
	await animated_sprite_2d.animation_finished
	if current_state == State.DEAD:
		return

	animated_sprite_2d.play("ranged_attack")
	if phase_2_triggered:
		fire_projectile_burst(3)
	else:
		fire_projectile()


# ---------- PHASE 2 ----------
func enter_phase_two() -> void:
	phase_2_triggered = true
	fly_speed *= 1.4
	attack_cooldown_timer.wait_time = max(attack_cooldown_timer.wait_time * 0.6, 0.6)
	dash_chance = min(dash_chance + 0.15, 0.6)

	current_state = State.ATTACK
	is_dashing = true
	velocity = Vector2.ZERO
	attack_cooldown_timer.start()

	var flash = create_tween()
	flash.tween_property(animated_sprite_2d, "modulate", Color(3, 3, 1, 1), 0.15)
	flash.tween_property(animated_sprite_2d, "modulate", Color(1, 1, 1, 1), 0.2)
	GameEffects.screen_shake(get_viewport().get_camera_2d(), 8.0, 0.2)
	await flash.finished

	var fly_up_target = global_position + Vector2(0, -phase_2_fly_up_height)
	fly_up_target.y = max(fly_up_target.y, phase_2_max_height_y)

	var fly_tween = create_tween()
	fly_tween.set_ease(Tween.EASE_OUT)
	fly_tween.set_trans(Tween.TRANS_SINE)
	fly_tween.tween_property(self, "global_position", fly_up_target, phase_2_fly_up_duration)
	await fly_tween.finished

	is_dashing = false
	velocity = Vector2.ZERO
	move_and_slide()

	await get_tree().create_timer(phase_2_pre_burst_pause).timeout

	await phase_2_intro_bullet_hell()

	distance_traveled = curve.get_closest_offset(global_position)

	if current_state == State.ATTACK:
		current_state = State.FLYING
		animated_sprite_2d.play("non_attack")


func phase_2_intro_bullet_hell() -> void:
	for wave in range(phase_2_burst_waves):
		fire_radial_ring(phase_2_burst_count, wave * phase_2_burst_rotation_offset)
		await get_tree().create_timer(phase_2_burst_wave_delay).timeout


func fire_radial_ring(count: int, rotation_offset_deg: float) -> void:
	if projectile_scene == null:
		return
	var angle_step = 360.0 / count
	for i in range(count):
		var angle_deg = angle_step * i + rotation_offset_deg
		var dir = Vector2.RIGHT.rotated(deg_to_rad(angle_deg))
		var proj = projectile_scene.instantiate()
		get_tree().current_scene.add_child(proj)
		proj.global_position = global_position
		proj.set_direction(dir * phase_2_burst_speed)


# ---------- SIGNALS ----------
func _on_hitbox_timer_timeout() -> void:
	hitbox_area.disable_hitbox()

func _on_damaged(amount: int, knockback_dir: Vector2) -> void:
	if current_state == State.DEAD:
		return
	flash_hit()
	GameEffects.screen_shake(get_viewport().get_camera_2d(), 1.0, 0.1)
	if not phase_2_triggered and health.current_health <= health.max_health / 2:
		enter_phase_two()

func flash_hit() -> void:
	var tween = create_tween()
	animated_sprite_2d.modulate = Color(1, 1, 1, 1)
	tween.tween_property(animated_sprite_2d, "modulate", Color(4, 4, 4, 1), 0.05)
	tween.tween_property(animated_sprite_2d, "modulate", Color(1, 1, 1, 1), 0.1)

func _on_died() -> void:
	current_state = State.DEAD
	hitbox_area.monitoring = false
	animated_sprite_2d.play("death")
	await animated_sprite_2d.animation_finished
	queue_free()
