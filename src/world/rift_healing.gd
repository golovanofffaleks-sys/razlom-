class_name RiftHealing
extends Node3D

const RADIUS: float = 12.0
const DURATION: float = 2.5
const FOG_DENSITY: float = 0.40
const FLOWER_COUNT: int = 320
const GROUND_SHADER: Shader = preload("res://src/world/rift_healing_ground.gdshader")
const FLOWER_SHADER: Shader = preload("res://src/world/rift_healing_flowers.gdshader")
const ASH_TEXTURE: Texture2D = preload("res://assets/textures/pbr/burned_ground_01/albedo.jpg")
const ROOTS_TEXTURE: Texture2D = preload("res://assets/textures/pbr/roots/albedo.jpg")

@export var scatter_seed: int = 1

var _ground_material: ShaderMaterial
var _flower_material: ShaderMaterial
var _fog: FogVolume
var _ash: GPUParticles3D
var _pollen: GPUParticles3D
var _flowers: MultiMeshInstance3D
var _light: OmniLight3D
var _started: bool = false


func _ready() -> void:
	var patch: PlaneMesh = PlaneMesh.new()
	patch.size = Vector2.ONE * RADIUS * 2.0
	_ground_material = ShaderMaterial.new()
	_ground_material.shader = GROUND_SHADER
	_ground_material.set_shader_parameter(&"ash_texture", ASH_TEXTURE)
	_ground_material.set_shader_parameter(&"roots_texture", ROOTS_TEXTURE)
	var ground: MeshInstance3D = MeshInstance3D.new()
	ground.name = &"Ground"
	ground.mesh = patch
	ground.material_override = _ground_material
	ground.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ground.position.y = 0.012
	add_child(ground)

	_fog = FogVolume.new()
	_fog.name = &"LowFog"
	_fog.shape = RenderingServer.FOG_VOLUME_SHAPE_ELLIPSOID
	_fog.size = Vector3(RADIUS * 2.0, 3.0, RADIUS * 2.0)
	_fog.position.y = 0.45
	var mist: FogMaterial = FogMaterial.new()
	mist.density = FOG_DENSITY
	mist.albedo = Color(0.52, 0.43, 0.58)
	mist.height_falloff = 0.8
	mist.edge_fade = 1.8
	_fog.material = mist
	add_child(_fog)

	_ash = _create_particles(false)
	_pollen = _create_particles(true)
	_build_flowers()

	_light = OmniLight3D.new()
	_light.name = &"GroveLight"
	_light.position.y = 2.2
	_light.omni_range = RADIUS
	_light.light_energy = 0.0
	_light.light_volumetric_fog_energy = 0.28
	add_child(_light)


func start() -> void:
	if _started:
		return
	_started = true
	_flowers.show()
	_pollen.emitting = true
	var wave: Tween = create_tween().set_ignore_time_scale(true)
	wave.tween_method(_apply_healing, 0.0, 1.0, DURATION).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	wave.tween_callback(_ash.set_emitting.bind(false))


func _apply_healing(progress: float) -> void:
	_ground_material.set_shader_parameter(&"healing", progress)
	_flower_material.set_shader_parameter(&"healing", progress)
	var mist: FogMaterial = _fog.material as FogMaterial
	mist.density = FOG_DENSITY * (1.0 - progress)
	if progress >= 1.0:
		_fog.hide()
	var ash_material: StandardMaterial3D = _ash.material_override as StandardMaterial3D
	ash_material.albedo_color.a = 1.0 - progress
	_pollen.amount_ratio = smoothstep(0.08, 0.85, progress)
	_light.light_color = Color(1.0, 0.75, 0.36).lerp(Color(0.50, 1.0, 0.63), progress * 0.60)
	_light.light_energy = 2.2 * progress + 0.9 * sin(PI * progress)


func _create_particles(pollen: bool) -> GPUParticles3D:
	var particles: GPUParticles3D = GPUParticles3D.new()
	particles.name = &"Pollen" if pollen else &"Ash"
	particles.amount = 180 if pollen else 240
	particles.lifetime = 3.4 if pollen else 4.0
	particles.preprocess = 0.0 if pollen else particles.lifetime
	particles.emitting = not pollen
	particles.amount_ratio = 0.0 if pollen else 1.0
	particles.position.y = 0.26 if pollen else 0.62
	particles.visibility_aabb = AABB(Vector3(-RADIUS - 2.0, -1.0, -RADIUS - 2.0), Vector3(28.0, 5.0, 28.0))
	particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	var process: ParticleProcessMaterial = ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	process.emission_ring_axis = Vector3.UP
	process.emission_ring_height = 0.44
	process.emission_ring_radius = RADIUS * (0.65 if pollen else 0.88)
	process.emission_ring_inner_radius = 0.55
	process.direction = Vector3(0.6, 0.8, 0.0) if pollen else Vector3(1, 0.15, 0.4)
	process.spread = 34.0
	process.initial_velocity_min = 0.18
	process.initial_velocity_max = 0.58
	process.gravity = Vector3.UP * (0.045 if pollen else -0.035)
	process.angle_min = -180.0
	process.angle_max = 180.0
	process.scale_min = 0.45
	process.scale_max = 1.3
	var tint: Color = Color(1.0, 0.83, 0.41, 0.83) if pollen else Color(0.25, 0.18, 0.30, 0.78)
	var trail: Gradient = Gradient.new()
	trail.offsets = PackedFloat32Array([0.0, 0.24, 0.68, 1.0])
	trail.colors = PackedColorArray([Color(tint, 0.0), tint, tint, Color(tint, 0.0)])
	var ramp: GradientTexture1D = GradientTexture1D.new()
	ramp.gradient = trail
	process.color_ramp = ramp
	particles.process_material = process

	var dot: QuadMesh = QuadMesh.new()
	dot.size = Vector2(0.036, 0.036) if pollen else Vector2(0.055, 0.038)
	var surface: StandardMaterial3D = StandardMaterial3D.new()
	surface.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	surface.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	surface.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	surface.billboard_keep_scale = true
	surface.vertex_color_use_as_albedo = true
	surface.albedo_color = Color(1.45, 1.23, 0.72) if pollen else Color(0.23, 0.18, 0.22)
	if pollen:
		var glow: Gradient = Gradient.new()
		glow.offsets = PackedFloat32Array([0.0, 0.45, 1.0])
		glow.colors = PackedColorArray([Color.WHITE, Color(1, 1, 1, 0.74), Color(1, 1, 1, 0)])
		var mask: GradientTexture2D = GradientTexture2D.new()
		mask.gradient = glow
		mask.width = 16
		mask.height = 16
		mask.fill = GradientTexture2D.FILL_RADIAL
		mask.fill_from = Vector2(0.5, 0.5)
		mask.fill_to = Vector2(1.0, 0.5)
		surface.albedo_texture = mask
	particles.material_override = surface
	particles.draw_pass_1 = dot
	add_child(particles)
	return particles


func _build_flowers() -> void:
	var random: RandomNumberGenerator = RandomNumberGenerator.new()
	random.seed = scatter_seed
	var bouquet: MultiMesh = MultiMesh.new()
	bouquet.transform_format = MultiMesh.TRANSFORM_3D
	bouquet.use_custom_data = true
	bouquet.mesh = _flower_mesh()
	bouquet.instance_count = FLOWER_COUNT
	bouquet.custom_aabb = AABB(Vector3(-RADIUS, 0.0, -RADIUS), Vector3(RADIUS * 2.0, 0.8, RADIUS * 2.0))
	for index: int in range(FLOWER_COUNT):
		var angle: float = random.randf_range(0.0, TAU)
		var distance: float = lerpf(1.72, RADIUS * 0.92, pow(random.randf(), 1.45))
		var offset: Vector3 = Vector3(cos(angle), 0.0, sin(angle)) * distance
		offset.y = 0.013
		var size: float = random.randf_range(0.40, 1.34)
		var orientation: Basis = Basis(Vector3.UP, angle).scaled(Vector3.ONE * size)
		bouquet.set_instance_transform(index, Transform3D(orientation, offset))
		bouquet.set_instance_custom_data(index, Color(distance / RADIUS, random.randf(), 0.0, 1.0))
	_flower_material = ShaderMaterial.new()
	_flower_material.shader = FLOWER_SHADER
	_flowers = MultiMeshInstance3D.new()
	_flowers.name = &"Flowers"
	_flowers.multimesh = bouquet
	_flowers.material_override = _flower_material
	_flowers.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_flowers.hide()
	add_child(_flowers)


func _flower_mesh() -> ArrayMesh:
	var mesh: SurfaceTool = SurfaceTool.new()
	mesh.begin(Mesh.PRIMITIVE_TRIANGLES)
	var crown: Vector3 = Vector3(0.0, 0.34, 0.0)
	var green: Color = Color(0.085, 0.30, 0.075, 0.0)
	for axis: Vector3 in [Vector3.RIGHT, Vector3.BACK]:
		var base: Vector3 = axis * 0.016
		var neck: Vector3 = axis * 0.009
		_triangle(mesh, -base, base, crown + neck, green)
		_triangle(mesh, -base, crown + neck, crown - neck, green)
	for side: float in [-1.0, 1.0]:
		var joint: Vector3 = Vector3.UP * (0.15 + side * 0.035)
		var leaf: Vector3 = joint + Vector3(0.10 * side, 0.04, 0.0)
		_triangle(mesh, joint, joint.lerp(leaf, 0.5) + Vector3.FORWARD * 0.024, leaf, green)
		_triangle(mesh, joint, leaf, joint.lerp(leaf, 0.5) + Vector3.BACK * 0.024, green)
	var petal: Color = Color(0.84, 0.91, 0.75, 0.72)
	for index: int in range(6):
		var ray: Vector3 = Vector3.RIGHT.rotated(Vector3.UP, TAU * index / 6.0)
		var shoulder: Vector3 = crown + ray * 0.068
		var width: Vector3 = ray.cross(Vector3.UP) * 0.035
		var tip: Vector3 = crown + ray * 0.117 + Vector3.UP * 0.032
		_triangle(mesh, crown, shoulder + width, tip, petal)
		_triangle(mesh, crown, tip, shoulder - width, petal)
	for index: int in range(6):
		var first: Vector3 = Vector3.RIGHT.rotated(Vector3.UP, TAU * index / 6.0)
		var second: Vector3 = Vector3.RIGHT.rotated(Vector3.UP, TAU * (index + 1) / 6.0)
		_triangle(mesh, crown + Vector3.UP * 0.028, crown + first * 0.031, crown + second * 0.031, Color(1.0, 0.82, 0.36, 1.0))
	mesh.generate_normals()
	return mesh.commit()


func _triangle(mesh: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, color: Color) -> void:
	mesh.set_color(color)
	mesh.add_vertex(a)
	mesh.add_vertex(b)
	mesh.add_vertex(c)
