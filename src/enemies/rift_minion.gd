class_name RiftMinion
extends CharacterBody3D

signal defeated

enum State { IDLE, CHASE, WINDUP, RECOVERY, STAGGERED, DEAD }

const PARRY_STAGGER: float = 1.5
const HEAVY_STAGGER: float = 0.48

const EYE_COLOR: Color = Color(0.78, 0.20, 1.0)
const STRIKE_COLOR: Color = Color(1.0, 0.35, 0.10)

@export var target: LinaController
@export var tuning: RiftTuning

var posture: float = 0.0
var _posture_delay: float = 0.0
var _state: State = State.IDLE
var _state_time: float = 0.0
var _stride: float = 0.0
var _hit_flash: float = 0.0
var _recoil_left: float = 0.0
var _patrol_side: float = 1.0
var _patrol_wait: float = 0.65
@onready var _spawn_point: Vector3 = global_position

@onready var health: HealthComponent = $Health
@onready var _hurtbox: HurtboxComponent = $Hurtbox
@onready var _visual: Node3D = $Visual
@onready var _arm: Node3D = $Visual/WeaponArm
@onready var _left_leg: Node3D = $Visual/LeftLeg
@onready var _right_leg: Node3D = $Visual/RightLeg
@onready var _telegraph: MeshInstance3D = $Telegraph
@onready var _eyes: StandardMaterial3D = $Visual/Head/Eyes.material_override
@onready var _status: Label3D = $Status
@onready var _bars: MeshInstance3D = $Vitals
@onready var _break_sound: AudioStreamPlayer3D = $PostureBreak
@onready var _core: AetherCore = $Visual/AetherCore


func _ready() -> void:
	_build_telegraph()
	health.health_changed.connect(_on_health_changed)
	_hurtbox.heavy_hit.connect(_on_heavy_hit)
	_hurtbox.hit_received.connect(_on_hit_received)
	_hurtbox.arrow_received.connect(_on_arrow_received)
	_hurtbox.riposte_received.connect(_on_riposte_received)
	_on_health_changed(health.current_health, health.max_health, 0.0)


func _physics_process(delta: float) -> void:
	var real_delta: float = delta / Engine.time_scale
	_update_posture(real_delta)
	velocity.x = 0.0
	velocity.z = 0.0
	if _state == State.STAGGERED:
		_update_stagger(delta, real_delta)
	elif is_instance_valid(target) and target.health.current_health > 0.0:
		if target.in_sanctuary:
			_retreat()
		else:
			_update_state(delta * _hurtbox.effect_speed())
	else:
		_state = State.IDLE
		_telegraph.hide()
		_patrol(delta)
	if not is_on_floor():
		velocity += get_gravity() * delta
	velocity.x *= _hurtbox.effect_speed()
	velocity.z *= _hurtbox.effect_speed()
	move_and_slide()
	_update_pose(delta)


func _retreat() -> void:
	_state = State.IDLE
	_telegraph.hide()
	var direction: Vector3 = _spawn_point - global_position
	direction.y = 0.0
	if direction.length_squared() > 0.16:
		rotation.y = atan2(-direction.x, -direction.z)
		var movement: Vector3 = direction.normalized() * tuning.enemy_speed
		velocity.x = movement.x
		velocity.z = movement.z


func _update_state(delta: float) -> void:
	var direction: Vector3 = target.global_position - global_position
	var same_height: bool = absf(direction.y) < 1.2
	direction.y = 0.0
	var distance: float = direction.length()
	match _state:
		State.IDLE:
			if distance <= tuning.detection_radius and _has_clear_path():
				_state = State.CHASE
			else:
				_patrol(delta)
		State.CHASE:
			if distance > tuning.detection_radius * 1.25:
				_state = State.IDLE
				return
			if not direction.is_zero_approx():
				rotation.y = atan2(-direction.x, -direction.z)
			if same_height and distance <= tuning.strike_radius * 0.86 and _has_clear_path():
				_state = State.WINDUP
				_state_time = tuning.strike_windup
				_telegraph.show()
				EventBus.minion_windup_started.emit(target, global_position)
			else:
				var movement: Vector3 = direction.normalized() * tuning.enemy_speed
				velocity.x = movement.x
				velocity.z = movement.z
		State.WINDUP:
			_state_time -= delta
			if _state_time <= 0.0:
				_telegraph.hide()
				_state = State.RECOVERY
				_state_time = tuning.strike_recovery
				if same_height and distance <= tuning.strike_radius:
					_strike(direction)
		State.RECOVERY:
			_state_time -= delta
			if distance < tuning.strike_radius * 0.72:
				var retreat: Vector3 = -direction.normalized() * tuning.enemy_speed * 0.46
				velocity.x = retreat.x
				velocity.z = retreat.z
			if _state_time <= 0.0:
				_state = State.CHASE


func _strike(direction: Vector3) -> void:
	if not direction.is_zero_approx() and -global_basis.z.dot(direction.normalized()) < cos(deg_to_rad(tuning.strike_half_angle)):
		return
	if not _has_clear_path():
		return
	var before: float = target.health.current_health
	var result: LinaDefense.Strike = target.defense.receive_strike(tuning.strike_damage, global_position)
	if result == LinaDefense.Strike.PARRIED:
		_add_posture(tuning.parry_posture)
		if not _hurtbox.riposte_ready:
			_stagger(PARRY_STAGGER, "Парирован")
	elif result == LinaDefense.Strike.HIT:
		var damage: float = before - target.health.current_health
		if damage > 0.0:
			StatsManager.add_xp("endurance", damage * tuning.endurance_xp_per_hp)


func _patrol(delta: float) -> void:
	_patrol_wait = maxf(0.0, _patrol_wait - delta)
	if _patrol_wait > 0.0:
		return
	var offset: Vector3 = Vector3(1.55 * _patrol_side, 0.0, 0.85 * _patrol_side)
	var direction: Vector3 = _spawn_point + offset - global_position
	direction.y = 0.0
	if direction.length_squared() < 0.08:
		_patrol_side *= -1.0
		_patrol_wait = 0.62
		return
	var movement: Vector3 = direction.normalized() * tuning.enemy_speed * 0.35
	rotation.y = atan2(-direction.x, -direction.z)
	velocity.x = movement.x
	velocity.z = movement.z


func _on_heavy_hit() -> void:
	if not _hurtbox.riposte_ready:
		_stagger(HEAVY_STAGGER, "Пошатнулся")


func _on_arrow_received(core_hit: bool) -> void:
	if core_hit:
		_add_posture(tuning.core_arrow_posture)
		if _state == State.WINDUP:
			_stagger(HEAVY_STAGGER, "Ядро поражено")
	elif _state == State.WINDUP:
		_add_posture(tuning.windup_arrow_posture)


func _on_hit_received() -> void:
	_posture_delay = tuning.posture_decay_delay


func _add_posture(amount: float) -> void:
	if _state == State.DEAD or _hurtbox.riposte_ready:
		return
	_on_hit_received()
	_set_posture(minf(posture + amount, 1.0))
	if posture >= 1.0:
		_hurtbox.riposte_ready = true
		_bars.set_instance_shader_parameter(&"broken", true)
		_stagger(tuning.posture_break_duration, "Добивание")
		_break_sound.play()


func _update_posture(delta: float) -> void:
	if posture <= 0.0 or _hurtbox.riposte_ready:
		return
	var decay_time: float = maxf(0.0, delta - _posture_delay)
	_posture_delay = maxf(0.0, _posture_delay - delta)
	if decay_time > 0.0:
		_set_posture(maxf(0.0, posture - decay_time * tuning.posture_decay_per_second))


func _set_posture(value: float) -> void:
	posture = value
	_bars.set_instance_shader_parameter(&"posture_ratio", value)


func _clear_posture_break() -> void:
	_hurtbox.riposte_ready = false
	_bars.set_instance_shader_parameter(&"broken", false)
	_set_posture(0.0)


func _on_riposte_received() -> void:
	if _state != State.DEAD:
		_clear_posture_break()
		_stagger(HEAVY_STAGGER, "Добивание!")


func _stagger(seconds: float, label: String) -> void:
	if _state == State.DEAD:
		return
	_state = State.STAGGERED
	_state_time = seconds
	_recoil_left = 0.20
	_telegraph.hide()
	_status.text = label


func _update_stagger(delta: float, real_delta: float) -> void:
	_state_time -= real_delta if _hurtbox.riposte_ready else delta
	_recoil_left = maxf(0.0, _recoil_left - delta)
	var recoil: Vector3 = global_basis.z * 1.25 * (_recoil_left / 0.20)
	velocity.x = recoil.x
	velocity.z = recoil.z
	if _state_time <= 0.0:
		if _hurtbox.riposte_ready:
			_clear_posture_break()
		_state = State.CHASE
		_status.text = "%d / %d" % [ceili(health.current_health), roundi(health.max_health)]


func _has_clear_path() -> bool:
	var height: Vector3 = Vector3.UP * 1.1
	var ray: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
		global_position + height, target.global_position + height, LinaCombat.WORLD_MASK
	)
	return get_world_3d().direct_space_state.intersect_ray(ray).is_empty()


func _update_pose(delta: float) -> void:
	var movement: Vector2 = Vector2(velocity.x, velocity.z)
	if not movement.is_zero_approx():
		_stride += delta * movement.length() * 4.2
	var step: float = 0.31 * sin(_stride) if not movement.is_zero_approx() else 0.0
	_left_leg.rotation.x = lerpf(_left_leg.rotation.x, step, minf(delta * 16.0, 1.0))
	_right_leg.rotation.x = -_left_leg.rotation.x
	var arm_pitch: float = step
	if _state == State.WINDUP:
		arm_pitch = lerpf(-0.6, -2.2, 1.0 - _state_time / tuning.strike_windup)
	elif _state == State.RECOVERY:
		arm_pitch = lerpf(0.0, 1.5, clampf(_state_time / tuning.strike_recovery, 0.0, 1.0))
	var staggered: bool = _state == State.STAGGERED
	if staggered:
		arm_pitch = 0.64
	var lean: float = -0.50 if _hurtbox.riposte_ready else (-0.22 if staggered else 0.0)
	_visual.rotation.x = lerpf(_visual.rotation.x, lean, minf(delta * 14.0, 1.0))
	_arm.rotation.x = lerpf(_arm.rotation.x, arm_pitch, minf(delta * 27.0, 1.0))
	_hit_flash = maxf(0.0, _hit_flash - delta * 6.0)
	var glow: Color = STRIKE_COLOR if _state == State.WINDUP else EYE_COLOR
	if _hurtbox.is_burning():
		glow = CombatElements.COLORS[CombatElements.Charge.FIRE]
	elif _hurtbox.effect_speed() < 1.0:
		glow = CombatElements.COLORS[CombatElements.Charge.ICE]
	_eyes.emission = glow.lerp(Color.WHITE, _hit_flash)
	_eyes.emission_energy_multiplier = 2.4 + _hit_flash * 3.5


func _on_health_changed(current: float, maximum: float, damage: float) -> void:
	if _state == State.DEAD:
		return
	_bars.set_instance_shader_parameter(&"health_ratio", current / maximum)
	if _state != State.STAGGERED:
		_status.text = "%d / %d" % [ceili(current), roundi(maximum)]
	_hit_flash = 1.0 if damage > 0.0 else 0.0
	if current > 0.0:
		return
	_state = State.DEAD
	_clear_posture_break()
	_telegraph.hide()
	_status.hide()
	_bars.hide()
	set_physics_process(false)
	set_deferred(&"collision_layer", 0)
	_core.set_deferred(&"collision_layer", 0)
	_hurtbox.set_invulnerable(true)
	defeated.emit()
	var dissolve: Tween = create_tween().set_parallel(true)
	dissolve.tween_property(_visual, "rotation_degrees:z", 38.0, 0.28)
	dissolve.tween_property(_visual, "scale", Vector3.ONE * 0.03, 0.28)
	dissolve.chain().tween_callback(queue_free)


func _build_telegraph() -> void:
	var mesh: ImmediateMesh = ImmediateMesh.new()
	var half_angle: float = deg_to_rad(tuning.strike_half_angle)
	var radius: float = tuning.strike_radius
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for segment: int in range(24):
		var start: Vector3 = Vector3.FORWARD.rotated(Vector3.UP, lerpf(-half_angle, half_angle, segment / 24.0))
		var end: Vector3 = Vector3.FORWARD.rotated(Vector3.UP, lerpf(-half_angle, half_angle, (segment + 1) / 24.0))
		mesh.surface_add_vertex(Vector3.ZERO)
		mesh.surface_add_vertex(start * radius)
		mesh.surface_add_vertex(end * radius)
	mesh.surface_end()
	_telegraph.mesh = mesh
