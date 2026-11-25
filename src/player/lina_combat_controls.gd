class_name LinaCombatControls
extends LinaPlayControls

enum Attack { NONE, BOW, SWORD }

const LOCK_RANGE: float = 18.0
const LOCK_HEIGHT: float = 1.24
const HITSTOP_DURATION: float = 0.08
const HITSTOP_SCALE: float = 0.045
const SHAKE_DURATION: float = 0.23
const ELEMENT_ACTIONS: Array[StringName] = [&"element_fire", &"element_ice", &"element_lightning"]

var _pending_attack: Attack = Attack.NONE
var _lock_requested: bool = false
var _cycle_ready: bool = true
var _target: Node3D
var _hitstop_left: float = 0.0
var _shake_left: float = 0.0
var _acrobatic_left: float = 0.0
var _roll_aim_used: bool = false

@onready var _combat: LinaCombat = $Combat
@onready var _lock_marker: Label3D = $LockMarker
@onready var _free_follow_offset: Vector3 = _phantom.follow_offset


func _ready() -> void:
	super._ready()
	_combat.riposte_landed.connect(_on_riposte_landed)


func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and is_instance_valid(_target):
		return
	super._input(event)
	if not _controls_active():
		return
	for index: int in ELEMENT_ACTIONS.size():
		if event.is_action_pressed(ELEMENT_ACTIONS[index]):
			_combat.select_element((index + CombatElements.Charge.FIRE) as CombatElements.Charge)
			get_viewport().set_input_as_handled()
			return
	if event.is_action_pressed(&"lock_on"):
		_lock_requested = true
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"attack"):
		var bow_mouse: bool = event is InputEventMouseButton and Input.is_action_pressed(&"aim")
		_pending_attack = Attack.BOW if bow_mouse else Attack.SWORD
		get_viewport().set_input_as_handled()

func _physics_process(delta: float) -> void:
	if _lock_requested:
		_set_lock(_nearest_target() if not is_instance_valid(_target) else null)
		_lock_requested = false
	if is_instance_valid(_target):
		if _can_lock(_target, LOCK_RANGE * 1.15):
			var direction: Vector3 = _target.global_position - _lina.global_position
			direction.y = 0.0
			_lina.lock_forward = direction.normalized()
			var heading: float = rad_to_deg(atan2(-direction.x, -direction.z))
			_look.y = rad_to_deg(lerp_angle(deg_to_rad(_look.y), deg_to_rad(heading), 1.0 - exp(-12.0 * delta / Engine.time_scale)))
			_phantom.set_third_person_rotation_degrees(_look)
			_phantom.follow_offset = Vector3.UP * 1.62 + _movement_forward().cross(Vector3.UP) * 0.86
			_lock_marker.global_position = _target.global_position + Vector3.UP * LOCK_HEIGHT
		else:
			_set_lock(null)
	elif _lock_marker.visible:
		_set_lock(null)
	super._physics_process(delta)
	if _controls_active() and Input.is_action_pressed(&"aim") and Input.is_action_just_pressed(&"bow_shot"):
		_pending_attack = Attack.BOW
	if _pending_attack != Attack.NONE and _controls_active():
		_combat.attack(_pending_attack == Attack.BOW)
	_pending_attack = Attack.NONE


func _update_aim(controls_active: bool, delta: float) -> bool:
	var parry: bool = controls_active and (Input.is_action_just_pressed(&"block") or
		Input.is_action_just_pressed(&"parry_trigger"))
	var aiming: bool = _combat.update_guard_and_aim(
		controls_active and Input.is_action_pressed(&"aim"),
		controls_active and Input.is_action_pressed(&"block"), parry, delta
	)
	if aiming and _lina.is_dashing() and not _roll_aim_used:
		_roll_aim_used = true
		_acrobatic_left = _combat.tuning.acrobatic_aim_duration
	return aiming


func _update_look_stick(stick: Vector2, delta: float) -> void:
	if not is_instance_valid(_target):
		_cycle_ready = true
		super._update_look_stick(stick, delta)
		return
	if absf(stick.x) < 0.32:
		_cycle_ready = true
	elif _cycle_ready and absf(stick.x) > 0.60:
		_cycle_ready = false
		var candidate: Node3D = _target_on_side(signf(stick.x))
		if candidate != null:
			_set_lock(candidate)


func _target_on_side(side: float) -> Node3D:
	var selected: Node3D
	var best: float = INF
	var screen_x: float = _camera.unproject_position(_target.global_position + Vector3.UP * LOCK_HEIGHT).x
	for member: Node in get_tree().get_nodes_in_group(&"lock_on_targets"):
		var candidate: Node3D = member as Node3D
		if candidate == null or candidate == _target or not _can_lock(candidate, LOCK_RANGE):
			continue
		var point: Vector3 = candidate.global_position + Vector3.UP * LOCK_HEIGHT
		if _camera.is_position_behind(point):
			continue
		var offset: float = (_camera.unproject_position(point).x - screen_x) * side
		if offset > 8.0 and offset < best:
			best = offset
			selected = candidate
	return selected


func _movement_forward() -> Vector3:
	return super._movement_forward() if _lina.lock_forward.is_zero_approx() else _lina.lock_forward


func _request_dash() -> void:
	_combat.dodge()


func _action_animation() -> StringName:
	return _combat.action_animation(_aiming)


func _gameplay_time_scale(aiming: bool, real_delta: float) -> float:
	_hitstop_left = maxf(_hitstop_left - real_delta, 0.0)
	_combat.hitstop_active = _hitstop_left > 0.0
	_lina.animations.hitstop_active = _combat.hitstop_active
	var acrobatic: bool = _acrobatic_left > 0.0
	_acrobatic_left = maxf(_acrobatic_left - real_delta, 0.0)
	if _combat.hitstop_active:
		return HITSTOP_SCALE
	return _combat.tuning.acrobatic_aim_scale if acrobatic else super._gameplay_time_scale(aiming, real_delta)


func _process(delta: float) -> void:
	super._process(delta)
	if _shake_left <= 0.0:
		return
	_shake_left = maxf(_shake_left - delta / Engine.time_scale, 0.0)
	var elapsed: float = SHAKE_DURATION - _shake_left
	var envelope: float = pow(_shake_left / SHAKE_DURATION, 2.0)
	_camera.h_offset = sin(elapsed * TAU * 23.0) * envelope * 0.13
	_camera.v_offset = sin(elapsed * TAU * 17.0) * envelope * 0.10


func _on_riposte_landed() -> void:
	_hitstop_left = HITSTOP_DURATION
	_shake_left = SHAKE_DURATION
	_combat.hitstop_active = true
	_lina.animations.hitstop_active = true
	Engine.set_deferred(&"time_scale", HITSTOP_SCALE)


func _on_dashed() -> void:
	super._on_dashed()
	_roll_aim_used = false


func _nearest_target() -> Node3D:
	var nearest: Node3D
	var nearest_squared: float = LOCK_RANGE * LOCK_RANGE
	for node: Node in get_tree().get_nodes_in_group(&"lock_on_targets"):
		var candidate: Node3D = node as Node3D
		if candidate == null:
			continue
		var distance_squared: float = _lina.global_position.distance_squared_to(candidate.global_position)
		if distance_squared < nearest_squared and _can_lock(candidate, LOCK_RANGE):
			nearest = candidate
			nearest_squared = distance_squared
	return nearest


func _can_lock(target: Node3D, max_distance: float) -> bool:
	var hurtbox: HurtboxComponent = HurtboxComponent.on_body(target)
	if hurtbox == null or hurtbox.health.current_health <= 0.0 or _lina.global_position.distance_squared_to(target.global_position) > max_distance * max_distance:
		return false
	var origin: Vector3 = _lina.global_position + Vector3.UP * LOCK_HEIGHT
	var destination: Vector3 = target.global_position + Vector3.UP * LOCK_HEIGHT
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(origin, destination, LinaCombat.WORLD_MASK)
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()


func _set_lock(target: Node3D) -> void:
	_target = target
	_lock_marker.visible = target != null
	if target == null:
		_lina.lock_forward = Vector3.ZERO
		_phantom.follow_offset = _free_follow_offset
		_phantom.set_look_at_target(null)
		_phantom.look_at_mode = PhantomCamera3D.LookAtMode.NONE
	else:
		_look.x = START_PITCH
		_phantom.look_at_mode = PhantomCamera3D.LookAtMode.SIMPLE
		_phantom.set_look_at_target(target)


func _bind_hud() -> void:
	_lina.animations.configure_actions(_combat.tuning)


func _reset() -> void:
	super._reset()
	_set_lock(null)
	_combat.reset()


func _release_controls() -> void:
	_pending_attack = Attack.NONE
	_lock_requested = false
	_hitstop_left = 0.0
	_shake_left = 0.0
	_acrobatic_left = 0.0
	_combat.hitstop_active = false
	_lina.animations.hitstop_active = false
	_camera.h_offset = 0.0
	_camera.v_offset = 0.0
	_combat.cancel_input()
	_lina.defense.cancel_parry()
	super._release_controls()
