shader_type spatial;
render_mode cull_disabled;

uniform float healing : hint_range(0.0, 1.0) = 0.0;

varying float hue;

void vertex() {
	float front = mix(-0.10, 1.14, healing);
	float grown = smoothstep(INSTANCE_CUSTOM.x - 0.025, INSTANCE_CUSTOM.x + 0.12, front);
	hue = INSTANCE_CUSTOM.y;
	VERTEX *= grown;
	VERTEX.x += sin(TIME * 2.2 + hue * 6.283) * VERTEX.y * 0.08;
}

void fragment() {
	vec3 petals = mix(vec3(0.42, 0.97, 0.64), vec3(1.0, 0.75, 0.31), hue);
	ALBEDO = COLOR.rgb * mix(vec3(1.0), petals, COLOR.a);
	EMISSION = petals * COLOR.a * 0.92;
	ROUGHNESS = 0.82;
}
