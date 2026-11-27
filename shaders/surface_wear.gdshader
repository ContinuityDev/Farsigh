shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;
// PBR-ish albedo with wear noise, AO and a soft rim. Compatibility safe.

uniform vec4 albedo : source_color = vec4(0.45, 0.43, 0.40, 1.0);
uniform vec4 wear_col : source_color = vec4(0.22, 0.20, 0.18, 1.0);
uniform float roughness : hint_range(0.0, 1.0) = 0.72;
uniform float metallic : hint_range(0.0, 1.0) = 0.04;
uniform float wear : hint_range(0.0, 1.0) = 0.35;
uniform vec4 rim_color : source_color = vec4(0.65, 0.72, 0.8, 1.0);
uniform float rim_strength : hint_range(0.0, 1.0) = 0.25;

varying vec3 wpos;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float n = hash(floor(wpos.xz * 3.5) + floor(wpos.y * 2.0));
	float edge = smoothstep(0.55, 0.9, n);
	vec3 col = mix(albedo.rgb, wear_col.rgb, edge * wear);
	float ndotv = clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0);
	float rim = pow(1.0 - ndotv, 2.6) * rim_strength;
	ALBEDO = col + rim_color.rgb * rim;
	ROUGHNESS = mix(roughness, min(1.0, roughness + 0.15), edge * wear);
	METALLIC = metallic;
	EMISSION = rim_color.rgb * rim * 0.15;
}
