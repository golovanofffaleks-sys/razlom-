class_name HurtboxComponent
extends Area3D

signal heavy_hit
signal hit_received
signal arrow_received(core_hit: bool)
signal riposte_received

@export var health: HealthComponent

var invulnerable: bool = false
var guard_factor: float = 1.0
var riposte_ready: bool = false
var guard_forward: Vector3 = Vector3.FORWARD

var _burn_ticks: int = 0
var _burn_left: float = 0.0
var _chill_left: float = 0.0


func _ready() -> void:
	set_physics_process(false)


func receive_heavy_impact() -> void:
	heavy_hit.emit()


func receive_riposte_impact() -> void:
	riposte_received.emit()


func receive_arrow_impact(core_hit: bool) -> void:
	arrow_received.emit(core_hit)


func ignite() -> void:
	if health.current_health > 0.0:
		if _burn_ticks == 0:
			_burn_left = 0.6
		_burn_ticks = 3
		set_physics_process(true)


func chill() -> void:
	if health.current_health > 0.0:
		_chill_left = 2.8
		set_physics_process(true)


func is_burning() -> bool:
	return _burn_ticks > 0


func effect_speed() -> float:
	return 0.48 if _chill_left > 0.0 else 1.0


func clear_elements() -> void:
	_burn_ticks = 0
	_burn_left = 0.0
	_chill_left = 0.0
	set_physics_process(false)


func _physics_process(delta: float) -> void:
	if health.current_health <= 0.0:
		clear_elements()
		return
	_chill_left = maxf(_chill_left - delta, 0.0)
	if _burn_ticks > 0:
		_burn_left -= delta
		while _burn_ticks > 0 and _burn_left <= 0.0 and health.current_health > 0.0:
			_burn_left += 0.6
			_burn_ticks -= 1
			if not invulnerable:
				health.take_damage(3.0)
	if _burn_ticks == 0 and _chill_left == 0.0:
		set_physics_process(false)


static func on_body(body: Node) -> HurtboxComponent:
	return body.get_node_or_null(^"Hurtbox") as HurtboxComponent if is_instance_valid(body) else null


func set_invulnerable(value: bool) -> void:
	invulnerable = value
	set_deferred(&"monitorable", not value)


func receive_hit(damage: float, source: Vector3) -> float:
	if invulnerable:
		return 0.0
	var applied: float = health.take_damage(damage * guard_multiplier(source))
	if applied > 0.0:
		hit_received.emit()
	return applied


func guard_multiplier(source: Vector3) -> float:
	var direction: Vector3 = source - global_position
	direction.y = 0.0
	return guard_factor if guard_forward.dot(direction.normalized()) > 0.0 else 1.0
