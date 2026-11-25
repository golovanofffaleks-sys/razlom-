shader_type spatial;

varying vec3 world_position;

float hash(vec2 point) {
	return fract(sin(dot(point, vec2(127.1, 311.7))) * 43758.5453);
}

float noise_field(vec2 point) {
	vec2 cell = floor(point);
	vec2 part = fract(point);
	part = part * part * (3.0 - 2.0 * part);
	return mix(mix(hash(cell), hash(cell + vec2(1.0, 0.0)), part.x),
		mix(hash(cell + vec2(0.0, 1.0)), hash(cell + vec2(1.0)), part.x), part.y);
}

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 point = world_position.xz;
	float grit = noise_field(point * 13.0);
	float patch = noise_field(point * 0.55);
	float grain = 0.63 + 0.28 * grit + 0.33 * patch;
	float trail_center = 2.7 * sin((-point.y - 5.0) * 0.18) * smoothstep(1.0, 10.0, -point.y);
	float path = 1.0 - smoothstep(0.8, 2.05, abs(point.x - trail_center) + 0.8 * patch);
	path = max(path, 1.0 - smoothstep(5.0, 8.0, length(point - vec2(0.0, 1.5))));
	path = max(path, 1.0 - smoothstep(5.1, 8.1, length(point - vec2(-5.0, -22.0))));
	path = max(path, 1.0 - smoothstep(5.7, 8.8, length(point - vec2(6.5, -43.0))));
	float corruption = smoothstep(8.0, 36.0, -point.y) * (0.2 + patch * 0.8);
	vec3 growth = mix(vec3(0.053, 0.07, 0.046), vec3(0.065, 0.039, 0.082), corruption);
	vec3 soil = mix(vec3(0.125, 0.087, 0.063), vec3(0.079, 0.063, 0.083), corruption);
	ALBEDO = mix(growth, soil, path) * grain;
	ROUGHNESS = 0.97;
}
