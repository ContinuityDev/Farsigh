shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;
// World-space grass / dirt / path splat. No textures — WebGL safe.

uniform vec4 grass_col : source_color = vec4(0.28, 0.38, 0.18, 1.0);
uniform vec4 dirt_col : source_color = vec4(0.42, 0.32, 0.20, 1.0);
uniform vec4 path_col : source_color = vec4(0.48, 0.38, 0.26, 1.0);
uniform float path_amount : hint_range(0.0, 1.0) = 0.15;
uniform float roughness_grass : hint_range(0.0, 1.0) = 0.92;
uniform float roughness_dirt : hint_range(0.0, 1.0) = 0.88;

varying vec3 wpos;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float n = noise(wpos.xz * 0.18);
	float n2 = noise(wpos.xz * 0.55 + 4.0);
	float dirt = smoothstep(0.42, 0.68, n);
	float path = path_amount * smoothstep(0.62, 0.82, n2);
	vec3 col = mix(grass_col.rgb, dirt_col.rgb, dirt);
	col = mix(col, path_col.rgb, path);
	float ao = mix(0.82, 1.0, n2);
	ALBEDO = col * ao;
	ROUGHNESS = mix(roughness_grass, roughness_dirt, max(dirt, path));
	METALLIC = 0.0;
}
