class_name LinaCombat
extends Node3D

signal element_changed(charge: CombatElements.Charge)
signal riposte_landed

const ARROW: PackedScene = preload("res://src/player/lina_arrow.tscn")
const WORLD_MASK: int = 1
const TARGET_MASK: int = 4
const AIM_DISTANCE: float = 45.0

@export var tuning: LinaCombatTuning
@export var player: LinaController
@export var camera: Camera3D
@export var facing: Node3D

var element: CombatElements.Charge = CombatElements.Charge.NONE
var hitstop_active: bool = false
var _sword_element: CombatElements.Charge = CombatElements.Charge.NONE
var _bow_left: float = 0.0
var _bow_draw: float = 0.0
var _bow_empty: bool = false
var _shot_requested: bool = false
var _iframe_left: float = 0.0
var _sword_time: float = -1.0
var _sword_stage: int = 0
var _combo_queued: bool = false
var _sword_hits: Dictionary[int, bool] = {}
var _sword_shape: BoxShape3D = BoxShape3D.new()

@onready var stamina: StaminaComponent = $Stamina
@onready var _bow_sound: AudioStreamPlayer3D = $BowDraw
@onready var _swing_sound: AudioStreamPlayer3D = $SwordSwing


func _ready() -> void:
	stamina.tuning = tuning
	player.defense.stamina = stamina
	player.defense.hurtbox = player.hurtbox


func select_element(charge: CombatElements.Charge) -> void:
	if charge == element:
		return
	element = charge
	player.animations.weapons.set_bow_charge(charge)
	element_changed.emit(charge)


func update_guard_and_aim(aim_requested: bool, guard_requested: bool,
		parry_pressed: bool, delta: float) -> bool:
	var can_defend: bool = not player.attack_committed and not player.is_dashing() and _bow_left <= 0.0
	player.blocking = guard_requested and can_defend and stamina.current > 0.0
	player.hurtbox.guard_factor = tuning.block_damage_factor if player.blocking else 1.0
	player.hurtbox.guard_forward = -facing.global_basis.z
	if can_defend and parry_pressed:
		player.defense.arm_parry()
	if player.defense.parry_pose_left > 0.0 or player.defense.hit_pose_left > 0.0:
		cancel_input()
		stamina.regenerate(delta, player.blocking)
		return false
	if not aim_requested:
		_bow_empty = false
	if aim_requested and not player.blocking and not player.attack_committed and not _bow_empty:
		if _bow_left > 0.0:
			stamina.regenerate(delta, false)
			return true
		var drain: float = minf(stamina.current, tuning.bow_stamina_per_second * delta)
		if drain > 0.0 and stamina.spend(drain) and stamina.current > 0.0:
			if _bow_draw == 0.0:
				_bow_sound.global_position = player.animations.weapons.muzzle.global_position
				_bow_sound.pitch_scale = clampf(_bow_sound.stream.get_length() / tuning.bow_draw_time, 0.65, 1.8)
				_bow_sound.play()
			_bow_draw += delta
			player.animations.weapons.set_draw(clampf(_bow_draw / tuning.bow_draw_time, 0.0, 1.0))
			if _shot_requested and _bow_draw >= tuning.bow_draw_time:
				_shot_requested = false
				_bow_draw = 0.0
				_bow_sound.stop()
				player.animations.weapons.set_draw(0.0)
				_bow_left = tuning.bow_cooldown
				_fire_arrow()
			return true
		_bow_empty = true
		cancel_input()
		return false
	cancel_input()
	stamina.regenerate(delta, player.blocking)
	return false


func attack(with_bow: bool) -> void:
	if player.attack_committed:
		var opens: float = maxf(0.0, tuning.sword_windup - 0.08)
		var closes: float = tuning.sword_windup + tuning.sword_active + tuning.sword_recovery * 0.62
		if not with_bow and _sword_stage == 1 and _sword_time >= opens and _sword_time <= closes:
			_combo_queued = true
		return
	if (player.is_dashing() and (not with_bow or _bow_draw <= 0.0)) or player.blocking or _bow_left > 0.0 or player.defense.parry_pose_left > 0.0 or player.defense.hit_pose_left > 0.0:
		return
	if with_bow:
		_shot_requested = not _bow_empty
	elif stamina.spend(tuning.sword_stamina_cost):
		_start_sword(1)


func _start_sword(stage: int) -> void:
	player.attack_committed = true
	player.defense.cancel_parry()
	_sword_stage = stage
	_sword_time = 0.0
	_combo_queued = false
	_sword_element = element
	player.animations.weapons.set_sword_charge(_sword_element)
	_sword_hits.clear()

func dodge() -> void:
	if not player.can_dash() or not stamina.spend(tuning.dodge_cost):
		return
	cancel_input()
	_bow_left = 0.0
	player.defense.cancel_parry()
	player.blocking = false
	player.hurtbox.guard_factor = 1.0
	_iframe_left = minf(tuning.dodge_iframes, tuning.dodge_duration)
	player.hurtbox.set_invulnerable(_iframe_left > 0.0)
	player.request_dash(tuning.dodge_duration, tuning.dodge_speed)


func action_animation(aiming: bool) -> StringName:
	player.animations.roll_bow_visible = player.is_dashing() and (aiming or _bow_left > 0.0)
	if player.is_dashing():
		return &"Dodge"
	if player.defense.parry_pose_left > 0.0:
		return &"Parry"
	if player.attack_committed:
		return &"SwordFollow" if _sword_stage == 2 else &"Sword"
	if player.defense.hit_pose_left > 0.0:
		return &"Hit"
	if _bow_left > 0.0:
		return &"BowShot"
	if player.blocking:
		return &"Block"
	return &"Aim" if aiming else LinaAnimations.LOCOMOTION


func cancel_input() -> void:
	if _bow_draw > 0.0:
		_bow_sound.stop()
		player.animations.weapons.set_draw(0.0)
	_bow_draw = 0.0
	_shot_requested = false


func interrupt_actions() -> void:
	cancel_input()
	_bow_left = 0.0
	_sword_time = -1.0
	_sword_stage = 0
	_combo_queued = false
	_sword_hits.clear()
	player.attack_committed = false
	player.blocking = false
	player.defense.cancel_parry()
	_swing_sound.stop()
	player.hurtbox.guard_factor = 1.0


func reset() -> void:
	interrupt_actions()
	_bow_empty = false
	_iframe_left = 0.0
	player.defense.reset()
	player.hurtbox.set_invulnerable(false)
	player.health.reset()
	stamina.reset()
	for arrow: Node in find_children("*", "CharacterBody3D", false, false):
		arrow.set_physics_process(false)
		arrow.queue_free()


func _physics_process(delta: float) -> void:
	var real_delta: float = delta / Engine.time_scale
	player.defense.advance(real_delta)
	_bow_left = maxf(0.0, _bow_left - real_delta)
	if _iframe_left > 0.0:
		_iframe_left = maxf(0.0, _iframe_left - real_delta)
		if _iframe_left == 0.0:
			player.hurtbox.set_invulnerable(false)
	if player.attack_committed:
		_update_sword(delta if hitstop_active else real_delta)


func _fire_arrow() -> void:
	var center: Vector2 = camera.get_viewport().get_visible_rect().get_center()
	var ray_origin: Vector3 = camera.project_ray_origin(center)
	var ray_direction: Vector3 = camera.project_ray_normal(center)
	var aim_end: Vector3 = ray_origin + ray_direction * AIM_DISTANCE
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var aim_ray: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
		ray_origin, aim_end, WORLD_MASK | TARGET_MASK | AetherCore.COLLISION_MASK
	)
	aim_ray.collide_with_areas = true
	var aim_hit: Dictionary = space.intersect_ray(aim_ray)
	var muzzle: Vector3 = player.animations.weapons.muzzle.global_position
	var target: Vector3 = aim_hit.get("position", aim_end)
	var core_in_sights: bool = aim_hit.get("collider") is AetherCore
	if core_in_sights:
		target += ray_direction * 0.07
	if ray_direction.dot(target - muzzle) < 0.2:
		target = aim_end
		core_in_sights = false
	# У стены оставляем начало полёта с той же стороны, что и Лина.
	var chest: Vector3 = Vector3(facing.global_position.x, muzzle.y, facing.global_position.z)
	if player.is_dashing():
		chest.y = player.global_position.y + 1.05
	var muzzle_ray: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
		chest, muzzle, WORLD_MASK | TARGET_MASK
	)
	if not space.intersect_ray(muzzle_ray).is_empty():
		muzzle = chest
	var shot: Vector3 = target - muzzle
	if core_in_sights:
		# При точном наведении на ядро учитываем падение стрелы от тетивы до цели.
		var gravity: Vector3 = player.get_gravity() * tuning.arrow_gravity_scale
		var speed: float = tuning.arrow_speed * (1.55 if element == CombatElements.Charge.LIGHTNING else 1.0)
		var displacement: Vector3 = shot
		for _step: int in range(2):
			var flight: float = shot.length() / speed
			shot = displacement - gravity * (0.5 * flight * flight)
	var arrow: LinaArrow = ARROW.instantiate() as LinaArrow
	add_child(arrow)
	arrow.launch(muzzle, shot.normalized(), tuning, element, player)


func _update_sword(delta: float) -> void:
	var previous_time: float = _sword_time
	_sword_time += delta
	var windup: float = tuning.sword_windup * (tuning.follow_windup_factor if _sword_stage == 2 else 1.0)
	var active_end: float = windup + tuning.sword_active
	if previous_time < windup and _sword_time >= windup:
		_swing_sound.global_position = player.animations.sword_grip()
		_swing_sound.play()
	if _sword_time >= windup and previous_time < active_end:
		_check_sword_hits(windup)
	if _combo_queued and _sword_time >= active_end + 0.05:
		_combo_queued = false
		if stamina.spend(tuning.follow_stamina_cost):
			_start_sword(2)
			return
	if _sword_time >= active_end + tuning.sword_recovery:
		player.attack_committed = false
		_sword_stage = 0


func _check_sword_hits(windup: float) -> void:
	var progress: float = clampf((_sword_time - windup) / tuning.sword_active, 0.0, 1.0)
	if _sword_stage == 2:
		progress = 1.0 - progress
	var heading: float = facing.global_rotation.y + deg_to_rad(lerpf(-64.0, 64.0, progress))
	var blade_basis: Basis = Basis.from_euler(Vector3(deg_to_rad(-6.0), heading, 0.0))
	var origin: Vector3 = player.animations.sword_grip()
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	_sword_shape.size = Vector3(0.75, 0.8, tuning.sword_reach)
	var hitbox: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
	hitbox.shape = _sword_shape
	hitbox.transform = Transform3D(blade_basis, origin - blade_basis.z * tuning.sword_reach * 0.5)
	hitbox.collision_mask = TARGET_MASK
	for hit: Dictionary in space.intersect_shape(hitbox):
		var body: Node3D = hit["collider"] as Node3D
		var hurtbox: HurtboxComponent = HurtboxComponent.on_body(body)
		if hurtbox == null or _sword_hits.has(hurtbox.get_instance_id()):
			continue
		var target: Vector3 = body.global_position + Vector3.UP * 1.1
		var wall_ray: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(origin, target, WORLD_MASK)
		if space.intersect_ray(wall_ray).is_empty():
			var riposte: bool = hurtbox.riposte_ready
			var damage: float = tuning.sword_damage
			if _sword_stage == 2:
				damage *= tuning.follow_damage_factor
			var factor: float = tuning.riposte_damage_factor if riposte else 1.0
			var applied: float = CombatElements.hit(hurtbox, damage, origin, _sword_element, _sword_hits, factor)
			if applied > 0.0:
				player.health.recover_rally(applied * tuning.rally_damage_fraction)
				if riposte:
					hurtbox.receive_riposte_impact()
					riposte_landed.emit()
				elif _sword_stage == 2:
					hurtbox.receive_heavy_impact()
