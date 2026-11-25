shader_type spatial;
render_mode depth_draw_never, cull_disabled;

uniform sampler2D ash_texture : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D roots_texture : source_color, filter_linear_mipmap, repeat_enable;
uniform float healing : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec2 offset = UV * 2.0 - 1.0;
	float radius = length(offset);
	vec3 ash = texture(ash_texture, UV * 8.0).rgb;
	vec3 roots = texture(roots_texture, UV * 9.0).rgb;
	float texture_detail = sqrt(dot(roots, vec3(0.299, 0.587, 0.114)));
	float patches = sqrt(texture(roots_texture, UV * 2.5).g);
	float boundary = radius + (patches - 0.35) * 0.13;
	float front = mix(-0.10, 1.14, healing);
	float healed = 1.0 - smoothstep(front - 0.085, front + 0.042, boundary);
	float crest = 1.0 - smoothstep(0.008, 0.07, abs(boundary - front));
	float moss = smoothstep(0.16, 0.46, mix(texture_detail, patches, 0.42));
	vec3 moss_color = mix(vec3(0.025, 0.065, 0.018), vec3(0.15, 0.26, 0.041), moss);
	moss_color *= 0.63 + texture_detail * 1.2;
	ALBEDO = mix(ash * vec3(0.37, 0.31, 0.43) + vec3(0.018, 0.010, 0.025), moss_color, healed);
	EMISSION = vec3(0.42, 0.78, 0.24) * crest * (0.14 + moss * 0.15);
	ROUGHNESS = 0.91;
	ALPHA = 1.0 - smoothstep(0.80, 1.0, max(boundary, radius));
}
