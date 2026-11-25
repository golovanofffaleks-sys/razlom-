class_name LinaController
extends CharacterBody3D

signal aiming_changed(active: bool)
signal dashed

@export var tuning: LinaTuning

var _move_direction: Vector3 = Vector3.ZERO
var _aim_forward: Vector3 = Vector3.FORWARD
var _dash_direction: Vector3 = Vector3.FORWARD
var _dash_left: float = 0.0
var _cooldown_left: float = 0.0
var _aiming: bool = false
var lock_forward: Vector3 = Vector3.ZERO
var attack_committed: bool = false
var blocking: bool = false
var defense: LinaDefense = LinaDefense.new()
var in_sanctuary: bool = false
var _roll_speed: float = 0.0
var _roll_duration: float = 0.0

@onready var _visual: Node3D = $Visual
@onready var animations: LinaAnimations = $AnimationTree
@onready var health: HealthComponent = $Health
@onready var hurtbox: HurtboxComponent = $Hurtbox


func set_intent(direction: Vector3, aim_forward: Vector3, aiming: bool) -> void:
	_move_direction = direction
	_aim_forward = aim_forward
	if _aiming != aiming:
		_aiming = aiming
		aiming_changed.emit(_aiming)


func can_dash() -> bool:
	return is_on_floor() and not is_dashing() and _cooldown_left <= 0.0 and not attack_committed


func is_dashing() -> bool:
	return _dash_left > 0.0


func request_dash(roll_duration: float = 0.0, roll_speed: float = 0.0) -> void:
	if not can_dash():
		return
	_dash_direction = _move_direction.normalized() if not _move_direction.is_zero_approx() else -_visual.basis.z
	_roll_duration = roll_duration
	_roll_speed = roll_speed
	_dash_left = roll_duration if roll_duration > 0.0 else tuning.dash_duration
	dashed.emit()


func stop_horizontal_motion() -> void:
	_dash_left = 0.0
	velocity.x = 0.0
	velocity.z = 0.0


func face_toward(point: Vector3) -> void:
	var direction: Vector3 = point - global_position
	if absf(direction.x) + absf(direction.z) > 0.01:
		_visual.rotation.y = atan2(-direction.x, -direction.z)


func reset_at(spawn: Vector3) -> void:
	global_position = spawn
	velocity = Vector3.ZERO
	_dash_left = 0.0
	_cooldown_left = 0.0
	attack_committed = false
	blocking = false
	lock_forward = Vector3.ZERO
	_visual.rotation.y = 0.0
	set_intent(Vector3.ZERO, Vector3.FORWARD, false)
	reset_physics_interpolation()


func _physics_process(delta: float) -> void:
	var dashing: bool = is_dashing()
	var rolling: bool = dashing and _roll_duration > 0.0
	var horizontal: Vector3 = Vector3(velocity.x, 0.0, velocity.z)
	var facing: Vector3 = _aim_forward if _aiming else _move_direction
	if not lock_forward.is_zero_approx():
		facing = lock_forward
	if dashing:
		var dash_speed: float = tuning.dash_speed
		if rolling:
			dash_speed = _roll_speed * smoothstep(0.0, 0.30, _dash_left / _roll_duration)
		horizontal = _dash_direction * dash_speed
		facing = _dash_direction
	else:
		_cooldown_left = maxf(0.0, _cooldown_left - delta)
		var speed: float = tuning.run_speed
		if _aiming:
			speed *= tuning.aim_movement_factor
		elif blocking or not lock_forward.is_zero_approx():
			speed *= 0.65
		if attack_committed:
			speed = 0.0
			facing = Vector3.ZERO
		var acceleration: float = tuning.run_deceleration if _move_direction.is_zero_approx() else tuning.run_acceleration
		horizontal = horizontal.move_toward(_move_direction * speed, acceleration * delta)
	velocity.x = horizontal.x
	velocity.z = horizontal.z
	if rolling:
		# Кувырок проходит полную дистанцию при замедлении мира.
		velocity.x /= Engine.time_scale
		velocity.z /= Engine.time_scale
	if not is_on_floor():
		velocity += get_gravity() * delta
	move_and_slide()
	if rolling:
		velocity.x *= Engine.time_scale
		velocity.z *= Engine.time_scale
	if not facing.is_zero_approx():
		_visual.rotation.y = atan2(-facing.x, -facing.z)
	if dashing:
		var dash_delta: float = delta / Engine.time_scale if rolling else delta
		_dash_left = maxf(0.0, _dash_left - dash_delta)
		if not rolling and is_on_wall() and get_wall_normal().dot(_dash_direction) < -0.5:
			_dash_left = 0.0
		if _dash_left == 0.0:
			_cooldown_left = tuning.dash_cooldown
			# Завершаем импульс, чтобы длина рывка читалась по разметке.
			if not rolling:
				var exit_velocity: Vector3 = _move_direction * tuning.run_speed
				velocity.x = exit_velocity.x
				velocity.z = exit_velocity.z
	var movement: Vector3 = get_real_velocity()
	animations.update_locomotion(Vector2(movement.x, movement.z).length() / tuning.run_speed)
