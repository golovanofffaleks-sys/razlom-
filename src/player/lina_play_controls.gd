class_name LinaPlayControls
extends Node3D

const START_PITCH: float = -12.0
const MOUSE_SENSITIVITY: float = 0.13
const STICK_PAN_SPEED: Vector2 = Vector2(156.0, 108.0)
const RUN_FOV: float = 70.0
const AIM_FOV: float = 50.0
const DASH_FOV: float = 78.0

var _saved_time_scale: float
var _saved_mouse_mode: Input.MouseMode
var _look: Vector3 = Vector3(START_PITCH, 0.0, 0.0)
var _aiming: bool = false
var _dash_pulse: float = 0.0
var _dash_requested: bool = false

@onready var _lina: LinaController = $Lina
@onready var _phantom: PhantomCamera3D = $PhantomCamera
@onready var _camera: Camera3D = $Camera
@onready var _spawn: Marker3D = $Spawn


func _ready() -> void:
	_saved_time_scale = Engine.time_scale
	_saved_mouse_mode = Input.mouse_mode
	_lina.aiming_changed.connect(_on_aiming_changed)
	_lina.dashed.connect(_on_dashed)
	_bind_hud()
	get_window().focus_exited.connect(_release_controls)
	_reset()
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _exit_tree() -> void:
	Engine.time_scale = _saved_time_scale
	Input.mouse_mode = _saved_mouse_mode


func _input(event: InputEvent) -> void:
	if event.is_action_pressed(&"dodge") and _controls_active():
		_dash_requested = true
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and not event.echo:
		if _handle_shortcut(event.physical_keycode):
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and _controls_active():
		_rotate_camera(event.screen_relative * MOUSE_SENSITIVITY)


func _controls_active() -> bool:
	return Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and get_window().has_focus()


func _physics_process(delta: float) -> void:
	var controls_active: bool = _controls_active()
	var direction: Vector3 = Vector3.ZERO
	if controls_active:
		var real_delta: float = delta / Engine.time_scale
		_update_look_stick(Input.get_vector(&"look_left", &"look_right", &"look_up", &"look_down"), real_delta)
	var forward: Vector3 = _movement_forward()
	if controls_active:
		var right: Vector3 = forward.cross(Vector3.UP)
		var stick: Vector2 = Input.get_vector(&"move_left", &"move_right", &"move_forward", &"move_back")
		direction = right * stick.x - forward * stick.y
	_lina.set_intent(direction, forward, _aiming)
	if _dash_requested and controls_active:
		_request_dash()
	_dash_requested = false
	var aiming: bool = _update_aim(controls_active, delta / Engine.time_scale)
	_lina.set_intent(direction, forward, aiming)
	var timescale: float = _gameplay_time_scale(aiming, delta / Engine.time_scale)
	Engine.set_deferred(&"time_scale", timescale)


func _gameplay_time_scale(aiming: bool, _real_delta: float) -> float:
	return _saved_time_scale * (_lina.tuning.aim_time_scale if aiming else 1.0)


func _update_look_stick(stick: Vector2, delta: float) -> void:
	if not stick.is_zero_approx():
		_rotate_camera(stick * STICK_PAN_SPEED * delta)


func _rotate_camera(offset: Vector2) -> void:
	_look.x = clampf(_look.x - offset.y, -70.0, 20.0)
	_look.y = wrapf(_look.y - offset.x, -180.0, 180.0)
	_phantom.set_third_person_rotation_degrees(_look)


func _update_aim(controls_active: bool, _delta: float) -> bool:
	return controls_active and Input.is_action_pressed(&"aim") and not _lina.is_dashing()


func _movement_forward() -> Vector3:
	return Vector3.FORWARD.rotated(Vector3.UP, deg_to_rad(_look.y))


func _request_dash() -> void:
	_lina.request_dash()


func _action_animation() -> StringName:
	if _lina.is_dashing():
		return &"Dodge"
	return &"Aim" if _aiming else LinaAnimations.LOCOMOTION


func _process(delta: float) -> void:
	# Реакция объектива сохраняет темп, пока мир замедлен.
	var real_delta: float = delta / Engine.time_scale
	_dash_pulse = move_toward(_dash_pulse, 0.0, real_delta * 4.0)
	var fov: float = AIM_FOV if _aiming else lerpf(RUN_FOV, DASH_FOV, _dash_pulse)
	_camera.fov = lerpf(_camera.fov, fov, 1.0 - exp(-12.0 * real_delta))
	_lina.animations.play_action(_action_animation())


func _bind_hud() -> void:
	pass


func _handle_shortcut(_key: Key) -> bool:
	return false


func _reset() -> void:
	_release_controls()
	_lina.reset_at(_spawn.global_position)
	_lina.animations.reset_pose()
	_look = Vector3(START_PITCH, 0.0, 0.0)
	_phantom.set_third_person_rotation_degrees(_look)
	_dash_pulse = 0.0
	_camera.fov = RUN_FOV


func _release_controls() -> void:
	_dash_requested = false
	Engine.time_scale = _saved_time_scale
	Engine.set_deferred(&"time_scale", _saved_time_scale)
	_lina.set_intent(Vector3.ZERO, Vector3.FORWARD, false)


func _on_aiming_changed(aiming: bool) -> void:
	_aiming = aiming


func _on_dashed() -> void:
	_dash_pulse = 1.0
