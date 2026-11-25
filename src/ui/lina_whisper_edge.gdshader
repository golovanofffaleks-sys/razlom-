shader_type canvas_item;
render_mode unshaded;

uniform float right_side = 0.0;

void fragment() {
	float x = mix(UV.x, 1.0 - UV.x, right_side);
	float y = abs(UV.y - 0.5) * 2.0;
	float reach = mix(0.18, 0.045, y);
	float aura = (1.0 - smoothstep(0.0, reach, x)) * (1.0 - smoothstep(0.28, 1.0, y));
	float rim = (1.0 - smoothstep(0.002, 0.026, x)) * (1.0 - smoothstep(0.10, 0.95, y));
	COLOR = vec4(mix(vec3(0.55, 0.13, 0.32), vec3(1.0, 0.58, 0.44), rim), COLOR.a * max(aura * 0.57, rim));
}
