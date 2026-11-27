shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled, specular_disabled;
// Translucent optic glass with fresnel rim — keeps ADS FOV clear (no solid black).

uniform vec4 glass_color : source_color = vec4(0.55, 0.78, 1.0, 0.14);
uniform vec4 rim_color : source_color = vec4(0.75, 0.9, 1.0, 0.55);
uniform float rim_power : hint_range(0.5, 8.0) = 2.4;
uniform float roughness : hint_range(0.0, 1.0) = 0.08;

void fragment() {
	float ndotv = clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0);
	float rim = pow(1.0 - ndotv, rim_power);
	vec2 p = UV * 2.0 - 1.0;
	float vignette = smoothstep(0.35, 1.05, length(p));
	vec3 glass = mix(glass_color.rgb, glass_color.rgb * 0.45, vignette * 0.65);
	ALBEDO = mix(glass, rim_color.rgb, rim * 0.7);
	ALPHA = mix(glass_color.a, rim_color.a, rim);
	ROUGHNESS = roughness;
	METALLIC = 0.08;
	EMISSION = rim_color.rgb * rim * 0.25;
}
