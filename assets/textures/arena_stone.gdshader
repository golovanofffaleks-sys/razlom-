shader_type spatial;

uniform vec4 stone_color : source_color = vec4(0.29, 0.31, 0.34, 1.0);
uniform vec4 grout_color : source_color = vec4(0.125, 0.135, 0.15, 1.0);
uniform vec2 block_size = vec2(1.2, 0.8);
uniform float relief : hint_range(0.0, 0.05, 0.001) = 0.024;

varying vec3 world_position;
varying vec3 world_normal;

float hash_cell(vec2 cell) {
	vec3 value = fract(vec3(cell.xyx) * 0.1031);
	value += dot(value, value.yzx + 33.33);
	return fract((value.x + value.y) * value.z);
}

float stone_noise(vec2 position) {
	vec2 cell = floor(position);
	vec2 blend = fract(position);
	blend = blend * blend * (3.0 - 2.0 * blend);
	return mix(
		mix(hash_cell(cell), hash_cell(cell + vec2(1.0, 0.0)), blend.x),
		mix(hash_cell(cell + vec2(0.0, 1.0)), hash_cell(cell + vec2(1.0, 1.0)), blend.x),
		blend.y
	);
}

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = MODEL_NORMAL_MATRIX * NORMAL;
}

void fragment() {
	// Проекция в мировых координатах сохраняет размер кладки на стенах и полу.
	vec3 axis = abs(world_normal);
	vec2 plane = world_position.xz;
	if (axis.x > max(axis.y, axis.z)) {
		plane = world_position.zy;
	} else if (axis.z > axis.y) {
		plane = world_position.xy;
	}

	float broad = stone_noise(plane * 2.3);
	float chips = stone_noise(plane * 10.0);
	float grain = stone_noise(plane * 42.0);
	vec2 blocks = plane / block_size;
	blocks.x += 0.5 * mod(floor(blocks.y), 2.0);
	vec2 cell = floor(blocks);
	vec2 edges = (0.5 - abs(fract(blocks) - 0.5)) * block_size;
	float distance_to_joint = min(edges.x, edges.y) + (chips - 0.5) * 0.037;
	float joint_width = clamp(fwidth(distance_to_joint) * 0.65, 0.0, 0.04);
	float bevel = smoothstep(0.008 - joint_width, 0.036 + joint_width, distance_to_joint);

	float variation = 0.73 + 0.35 * hash_cell(cell) + 0.25 * broad + 0.11 * chips;
	ALBEDO = mix(grout_color.rgb * (0.8 + 0.3 * chips), stone_color.rgb * variation, bevel);
	ROUGHNESS = mix(0.96, 0.64 + 0.23 * chips, bevel);
	AO = mix(0.74, 1.0, bevel);
	AO_LIGHT_AFFECT = 0.15;

	// Градиент высоты даёт швам и сколам собственную реакцию на освещение.
	float height = relief * (bevel * (0.63 + 0.26 * chips + 0.11 * grain) + 0.27 * broad);
	vec3 dx = dFdx(VERTEX);
	vec3 dy = dFdy(VERTEX);
	vec3 tangent_x = cross(dy, NORMAL);
	vec3 tangent_y = cross(NORMAL, dx);
	float determinant = dot(dx, tangent_x);
	vec3 gradient = dFdx(height) * tangent_x + dFdy(height) * tangent_y;
	NORMAL = normalize(NORMAL * max(abs(determinant), 0.000001) - sign(determinant) * gradient);
}
