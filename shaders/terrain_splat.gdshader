shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;
// Tiled CC0 ground: grass, dirt, mud, gravel, worn path.
// World-space UVs, height blend, macro warp and a detail octave so repeats stay quiet.

uniform sampler2D grass_tex : source_color, repeat_enable, filter_linear_mipmap;
uniform sampler2D dirt_tex : source_color, repeat_enable, filter_linear_mipmap;
uniform sampler2D mud_tex : source_color, repeat_enable, filter_linear_mipmap;
uniform sampler2D gravel_tex : source_color, repeat_enable, filter_linear_mipmap;
uniform sampler2D path_tex : source_color, repeat_enable, filter_linear_mipmap;
uniform float path_amount : hint_range(0.0, 1.0) = 0.2;
uniform float detail_strength : hint_range(0.0, 0.5) = 0.22;
uniform float uv_scale : hint_range(0.05, 1.0) = 0.24;

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

float luma(vec3 c) {
	return dot(c, vec3(0.30, 0.55, 0.15));
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float macro = noise(wpos.xz * 0.028);
	float warp_n = noise(wpos.xz * 0.06 + 4.0);
	vec2 warp = vec2(macro, warp_n) - 0.5;
	vec2 uv = wpos.xz * uv_scale + warp * 0.42;
	// Second octave, offset so the tile grid doesn't line up
	vec2 uv_b = wpos.xz * uv_scale * 0.47 + vec2(19.2, 7.4) + warp * 0.2;

	vec3 grass = texture(grass_tex, uv).rgb;
	vec3 dirt = texture(dirt_tex, uv).rgb;
	vec3 mud = texture(mud_tex, uv).rgb;
	vec3 gravel = texture(gravel_tex, uv_b).rgb;
	vec3 path = texture(path_tex, uv).rgb;

	grass = mix(grass, texture(grass_tex, uv * 3.6 + 2.0).rgb, detail_strength);
	dirt = mix(dirt, texture(dirt_tex, uv * 3.2 + 5.0).rgb, detail_strength * 0.85);
	path = mix(path, texture(path_tex, uv * 2.8).rgb, detail_strength * 0.7);

	float n = noise(wpos.xz * 0.09 + macro);
	float n2 = noise(wpos.xz * 0.17 + 11.0);
	float n3 = noise(wpos.xz * 0.045 + 2.0);

	float grass_w = 1.0;
	float dirt_w = smoothstep(0.34, 0.72, n) * 0.95;
	float mud_w = smoothstep(0.58, 0.88, n3) * 0.7;
	float gravel_w = smoothstep(0.52, 0.84, n2) * 0.55;
	float path_w = path_amount * smoothstep(0.28, 0.78, noise(wpos.xz * 0.31 + 1.3));

	// Height blend: heavier weights win, but the texture's own relief keeps the edge
	float wg = grass_w * (luma(grass) + 0.25);
	float wd = dirt_w * (luma(dirt) + 0.25);
	float wm = mud_w * (luma(mud) + 0.22);
	float wv = gravel_w * (luma(gravel) + 0.2);
	float wp = path_w * (luma(path) + 0.28);
	float mx = max(max(max(wg, wd), max(wm, wv)), wp);
	float sharp = 0.16;
	wg = max(wg - mx + sharp, 0.0);
	wd = max(wd - mx + sharp, 0.0);
	wm = max(wm - mx + sharp, 0.0);
	wv = max(wv - mx + sharp, 0.0);
	wp = max(wp - mx + sharp, 0.0);
	float sumw = max(wg + wd + wm + wv + wp, 0.0001);
	vec3 col = (grass * wg + dirt * wd + mud * wm + gravel * wv + path * wp) / sumw;

	// Broad colour variation so a repeated tile doesn't read as a grid
	col *= mix(0.86, 1.08, macro);
	col *= mix(0.94, 1.04, noise(wpos.xz * 0.004));

	ALBEDO = col;
	ROUGHNESS = mix(0.92, 0.78, luma(col));
	METALLIC = 0.0;
}
