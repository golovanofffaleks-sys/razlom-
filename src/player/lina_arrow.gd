class_name LinaArrow
extends CharacterBody3D

var _charge: CombatElements.Charge
var _damage: float
var _xp: float
var _gravity_scale: float
var _flight_left: float
var _embedded_left: float = 1.25
var _embedded: bool = false
var _shooter_health: HealthComponent
var _shooter_origin: Vector3
var _rally_distance: float
var _rally_fraction: float

@onready var _whistle: AudioStreamPlayer3D = $Whistle


func launch(origin: Vector3, direction: Vector3, tuning: LinaCombatTuning,
		charge: CombatElements.Charge = CombatElements.Charge.NONE, shooter: Node3D = null) -> void:
	global_position = origin
	var shooter_hurtbox: HurtboxComponent = HurtboxComponent.on_body(shooter)
	if shooter_hurtbox != null:
		_shooter_health = shooter_hurtbox.health
		_shooter_origin = shooter.global_position
		_rally_distance = tuning.point_blank_range
		_rally_fraction = tuning.rally_damage_fraction
	_charge = charge
	var speed_multiplier: float = 1.55 if charge == CombatElements.Charge.LIGHTNING else 1.0
	velocity = direction * tuning.arrow_speed * speed_multiplier
	if charge != CombatElements.Charge.NONE:
		($Point as MeshInstance3D).material_override = CombatElements.glow(charge)
	_damage = tuning.arrow_damage
	_xp = tuning.archery_xp
	_gravity_scale = tuning.arrow_gravity_scale
	_flight_left = tuning.arrow_lifetime
	_face_velocity()
	_whistle.pitch_scale = 1.16 if charge == CombatElements.Charge.LIGHTNING else 1.0
	_whistle.play()


func _physics_process(delta: float) -> void:
	if _embedded:
		_embedded_left -= delta
		if _embedded_left <= 0.0:
			queue_free()
		return
	_flight_left -= delta
	if _flight_left <= 0.0:
		queue_free()
		return
	velocity += get_gravity() * _gravity_scale * delta
	_face_velocity()
	var start: Vector3 = global_position
	var collision: KinematicCollision3D = move_and_collide(velocity * delta)
	var core_ray: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
		start, global_position, AetherCore.COLLISION_MASK)
	core_ray.collide_with_areas = true
	core_ray.collide_with_bodies = false
	core_ray.hit_from_inside = true
	var core_contact: Dictionary = get_world_3d().direct_space_state.intersect_ray(core_ray)
	var core: AetherCore = core_contact.get("collider") as AetherCore
	if core == null and collision == null:
		return
	_embedded = true
	var hurtbox: HurtboxComponent
	if core != null:
		global_position = core_contact["position"]
		hurtbox = core.hurtbox
	else:
		hurtbox = HurtboxComponent.on_body(collision.get_collider() as Node)
	var struck: Dictionary[int, bool] = {}
	if hurtbox == null:
		return
	var damage_factor: float = AetherCore.DAMAGE_FACTOR if core != null else 1.0
	var applied: float = CombatElements.hit(hurtbox, _damage, start, _charge, struck, damage_factor)
	if applied > 0.0:
		StatsManager.add_xp("archery", _xp * AetherCore.ARCHERY_XP_FACTOR if core != null else _xp)
		hurtbox.receive_arrow_impact(core != null)
		var target: Node3D = hurtbox.get_parent() as Node3D
		if is_instance_valid(_shooter_health) and _shooter_origin.distance_to(target.global_position) <= _rally_distance:
			_shooter_health.recover_rally(applied * _rally_fraction)


func _face_velocity() -> void:
	var direction: Vector3 = velocity.normalized()
	var up: Vector3 = Vector3.UP if absf(direction.y) < 0.99 else Vector3.FORWARD
	look_at(global_position + direction, up)
