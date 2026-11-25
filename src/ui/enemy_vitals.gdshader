shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled;

instance uniform float health_ratio = 1.0;
instance uniform float posture_ratio = 0.0;
instance uniform bool broken = false;

void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(
		INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]
	);
}

void fragment() {
	float x = clamp((UV.x - 0.024) / 0.952, 0.0, 1.0);
	bool hp = UV.y < 0.51;
	bool inner = UV.x > 0.024 && UV.x < 0.976;
	inner = inner && (hp ? UV.y > 0.085 && UV.y < 0.43 : UV.y > 0.61 && UV.y < 0.91);
	bool filled = x < (hp ? health_ratio : posture_ratio);
	vec3 frame = vec3(0.043, 0.027, 0.066);
	vec3 empty = hp ? vec3(0.17, 0.067, 0.12) : vec3(0.21, 0.15, 0.085);
	vec3 fill = hp ? mix(vec3(0.74, 0.13, 0.23), vec3(0.93, 0.32, 0.38), 1.0 - UV.y)
		: mix(vec3(0.95, 0.55, 0.07), vec3(1.0, 0.89, 0.46), 1.0 - x);
	if (broken && !hp) {
		fill = vec3(1.0, 0.83, 0.36);
		EMISSION = fill * 0.48;
	}
	ALBEDO = inner ? (filled ? fill : empty) : frame;
}
