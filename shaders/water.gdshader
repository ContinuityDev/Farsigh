shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, specular_disabled;
// Simple Compatibility-safe water: scrolling tint + fresnel edge highlight.
// No refraction / screen_texture (those break or cost too much on WebGL).

uniform vec4 shallow_color : source_color = vec4(0.18, 0.46, 0.52, 0.88);
uniform vec4 deep_color : source_color = vec4(0.06, 0.22, 0.34, 0.95);
uniform float wave_speed : hint_range(0.0, 2.0) = 0.35;
uniform float wave_scale : hint_range(0.1, 8.0) = 2.4;
uniform float fresnel_power : hint_range(0.5, 8.0) = 3.2;
uniform float specular_boost : hint_range(0.0, 1.0) = 0.35;
uniform float roughness : hint_range(0.0, 1.0) = 0.18;

varying vec3 v_world_pos;

void vertex() {
	v_world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float w1 = sin(v_world_pos.x * wave_scale + TIME * wave_speed * 6.28);
	float w2 = cos(v_world_pos.z * wave_scale * 0.85 + TIME * wave_speed * 5.1);
	VERTEX.y += (w1 + w2) * 0.035;
}

void fragment() {
	float ripple = 0.5 + 0.5 * sin(v_world_pos.x * wave_scale + TIME * wave_speed * 6.28)
		* cos(v_world_pos.z * wave_scale * 0.9 + TIME * wave_speed * 4.7);
	vec3 base = mix(deep_color.rgb, shallow_color.rgb, ripple);
	float ndotv = clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0);
	float fres = pow(1.0 - ndotv, fresnel_power);
	ALBEDO = mix(base, vec3(0.72, 0.88, 0.95), fres * specular_boost);
	ROUGHNESS = mix(roughness, 0.05, fres);
	METALLIC = 0.15 + fres * 0.25;
	ALPHA = mix(deep_color.a, shallow_color.a, ripple);
}
