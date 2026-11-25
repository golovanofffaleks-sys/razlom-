class_name CombatElements
extends RefCounted

enum Charge { NONE, FIRE, ICE, LIGHTNING }

const COLORS: Array[Color] = [Color(0.92, 0.74, 0.48), Color(1.0, 0.29, 0.075),
	Color(0.32, 0.85, 1.0), Color(0.69, 0.53, 1.0)]
const NAMES: Array[String] = ["Без заряда", "Огонь", "Лёд", "Молния"]
const CHAIN_RANGE: float = 5.0
const CHAIN_HOPS: int = 2
const WORLD_MASK: int = 1
const CONTACT_HEIGHT: Vector3 = Vector3.UP * 1.1


static func glow(charge: Charge) -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	var tint: Color = COLORS[charge]
	material.albedo_color = tint.lerp(Color.WHITE, 0.25)
	material.emission_enabled = true
	material.emission = tint
	material.emission_energy_multiplier = 2.3 if charge != Charge.NONE else 0.65
	material.roughness = 0.36
	return material


static func hit(target: HurtboxComponent, damage: float, source: Vector3,
		charge: Charge, struck: Dictionary[int, bool], direct_damage_factor: float = 1.0) -> float:
	struck[target.get_instance_id()] = true
	var amount: float = damage * 1.20 if charge == Charge.FIRE else damage
	var applied: float = target.receive_hit(amount * direct_damage_factor, source)
	if applied <= 0.0:
		return 0.0
	match charge:
		Charge.FIRE:
			target.ignite()
		Charge.ICE:
			target.chill()
		Charge.LIGHTNING:
			_chain(target, damage * 0.60, struck)
	return applied


static func _chain(first: HurtboxComponent, damage: float, struck: Dictionary[int, bool]) -> void:
	var space: PhysicsDirectSpaceState3D = first.get_world_3d().direct_space_state
	var targets: Array[Node] = first.get_tree().get_nodes_in_group(&"lock_on_targets")
	var origin: Vector3 = (first.get_parent() as Node3D).global_position + CONTACT_HEIGHT
	for _hop: int in range(CHAIN_HOPS):
		var next: HurtboxComponent
		var next_point: Vector3
		var nearest: float = CHAIN_RANGE * CHAIN_RANGE
		for node: Node in targets:
			var body: Node3D = node as Node3D
			var candidate: HurtboxComponent = HurtboxComponent.on_body(body)
			if candidate == null or candidate.invulnerable or candidate.health.current_health <= 0.0 or struck.has(candidate.get_instance_id()):
				continue
			var point: Vector3 = body.global_position + CONTACT_HEIGHT
			var distance: float = origin.distance_squared_to(point)
			if distance >= nearest:
				continue
			var ray: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(origin, point, WORLD_MASK)
			if not space.intersect_ray(ray).is_empty():
				continue
			next = candidate
			next_point = point
			nearest = distance
		if next == null:
			return
		struck[next.get_instance_id()] = true
		next.receive_hit(damage, origin)
		_arc(first.get_tree().current_scene, origin, next_point)
		origin = next_point
		damage *= 0.65


static func _arc(parent: Node, start: Vector3, finish: Vector3) -> void:
	if parent == null or start.is_equal_approx(finish):
		return
	var delta: Vector3 = finish - start
	var side: Vector3 = delta.normalized().cross(Vector3.UP)
	if side.is_zero_approx():
		side = Vector3.RIGHT
	var across: Vector3 = side.normalized() * 0.018
	var mesh: ImmediateMesh = ImmediateMesh.new()
	var material: StandardMaterial3D = glow(Charge.LIGHTNING)
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES, material)
	var previous: Vector3 = Vector3.ZERO
	for i: int in range(1, 7):
		var next: Vector3 = delta * (float(i) / 6.0)
		if i < 6:
			next += across * (6.0 if i % 2 == 0 else -6.0) + Vector3.UP * sin(i * 2.5) * 0.16
		for width: Vector3 in [across, Vector3.UP * 0.018]:
			mesh.surface_add_vertex(previous - width)
			mesh.surface_add_vertex(previous + width)
			mesh.surface_add_vertex(next - width)
			mesh.surface_add_vertex(previous + width)
			mesh.surface_add_vertex(next + width)
			mesh.surface_add_vertex(next - width)
		previous = next
	mesh.surface_end()
	var bolt: MeshInstance3D = MeshInstance3D.new()
	bolt.mesh = mesh
	bolt.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(bolt)
	bolt.global_position = start
	var fade: Tween = bolt.create_tween()
	fade.tween_property(material, "albedo_color:a", 0.0, 0.18)
	fade.tween_callback(bolt.queue_free)
