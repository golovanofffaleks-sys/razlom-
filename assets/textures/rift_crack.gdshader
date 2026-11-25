shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, depth_draw_never;

uniform vec4 rift_color : source_color = vec4(0.67, 0.24, 0.98, 1.0);
uniform float charge : hint_range(0.0, 1.0) = 0.0;

float crack_path(float y) {
	return 0.14 * sin(9.0 * y + 0.2) + 0.06 * (abs(fract(y * 5.4) - 0.5) * 4.0 - 1.0)
		+ 0.022 * sin(y * 56.0);
}

void fragment() {
	vec2 point = UV * 2.0 - 1.0;
	float span = 1.0 - smoothstep(0.68, 1.0, abs(point.y));
	float core = crack_path(point.y) + 0.018 * sin(TIME * 2.9 + point.y * 30.0);
	float width = (0.075 + 0.035 * sin(point.y * 16.0 + TIME)) * span;
	float distance_to_core = abs(point.x - core);
	float border = exp(-abs(distance_to_core - width) * 88.0) * span;
	float halo = exp(-distance_to_core * 12.0) * span;
	float interior = (1.0 - smoothstep(width * 0.64, width + 0.013, distance_to_core)) * span;
	float upper_branch = abs(point.x - (crack_path(-0.27) + (point.y + 0.27) * 0.72 + sin(point.y * 40.0) * 0.017));
	float lower_branch = abs(point.x - (crack_path(0.26) + (point.y - 0.26) * 0.79 + sin(point.y * 34.0) * 0.020));
	float fork = exp(-upper_branch * 100.0) * smoothstep(-0.28, -0.23, point.y) * (1.0 - smoothstep(0.12, 0.34, point.y));
	fork += exp(-lower_branch * 92.0) * smoothstep(-0.39, -0.15, point.y) * (1.0 - smoothstep(0.22, 0.27, point.y));
	float flicker = 0.86 + 0.14 * sin(TIME * 4.2 + point.y * 26.0);
	ALBEDO = mix(rift_color.rgb * (0.48 + halo * 0.8), vec3(0.012, 0.006, 0.024), interior);
	EMISSION = rift_color.rgb * (border * 4.8 + fork * 2.0 + halo * 0.45) * flicker * (1.0 + charge);
	ALPHA = clamp(max(interior, border) + fork + halo * 0.49, 0.0, 1.0);
}
