class_name LinaDefense
extends RefCounted

enum Strike { HIT, BLOCKED, PARRIED, EVADED }

var stamina: StaminaComponent
var hurtbox: HurtboxComponent
var parry_pose_left: float = 0.0
var hit_pose_left: float = 0.0
var _parry_left: float = 0.0


func arm_parry() -> void:
	if _parry_left == 0.0 and parry_pose_left == 0.0 and stamina.current >= stamina.tuning.parry_cost:
		_parry_left = stamina.tuning.parry_window


func advance(delta: float) -> void:
	_parry_left = maxf(0.0, _parry_left - delta)
	parry_pose_left = maxf(0.0, parry_pose_left - delta)
	hit_pose_left = maxf(0.0, hit_pose_left - delta)


func cancel_parry() -> void:
	_parry_left = 0.0


func reset() -> void:
	cancel_parry()
	parry_pose_left = 0.0
	hit_pose_left = 0.0


func receive_strike(amount: float, source: Vector3) -> Strike:
	if hurtbox.invulnerable:
		return Strike.EVADED
	var direction: Vector3 = source - hurtbox.global_position
	direction.y = 0.0
	var frontal: bool = hurtbox.guard_forward.dot(direction.normalized()) > 0.0
	if frontal and _parry_left > 0.0 and stamina.spend(stamina.tuning.parry_cost):
		cancel_parry()
		parry_pose_left = 0.38
		return Strike.PARRIED
	if frontal and hurtbox.guard_factor < 1.0:
		var cost: float = amount * stamina.tuning.block_stamina_factor
		if stamina.spend(cost):
			hurtbox.receive_hit(amount, source)
			return Strike.BLOCKED
		stamina.spend(stamina.current)
	if hurtbox.health.take_damage(amount) > 0.0:
		hit_pose_left = 0.34
	return Strike.HIT
