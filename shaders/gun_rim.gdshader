shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, specular_disabled;
// Soft rim / fresnel highlight for viewmodel weapons (Compatibility-safe).

uniform vec4 albedo : source_color = vec4(0.18, 0.19, 0.21, 1.0);
uniform vec4 rim_color : source_color = vec4(0.55, 0.72, 0.95, 1.0);
uniform float rim_power : hint_range(0.5, 8.0) = 2.8;
uniform float rim_strength : hint_range(0.0, 1.5) = 0.55;
uniform float roughness : hint_range(0.0, 1.0) = 0.55;
uniform float metallic : hint_range(0.0, 1.0) = 0.35;

varying vec3 local_pos;

void vertex() {
	local_pos = VERTEX;
}

void fragment() {
	float ndotv = clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0);
	float rim = pow(1.0 - ndotv, rim_power) * rim_strength;
	float wear = fract(sin(dot(local_pos.xy, vec2(12.4, 78.2))) * 43758.0);
	vec3 worn = albedo.rgb * mix(1.0, 0.72, smoothstep(0.62, 0.95, wear) * 0.55);
	ALBEDO = worn + rim_color.rgb * rim;
	ROUGHNESS = mix(roughness, 0.25, rim);
	METALLIC = metallic;
	EMISSION = rim_color.rgb * rim * 0.35;
}
