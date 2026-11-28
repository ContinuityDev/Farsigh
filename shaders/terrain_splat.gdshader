shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;
// World-space ground. Two photo tiles plus a large painted patch mask so the
// yard still reads as grass / dirt / path from the overlook, on every preset.
// Kept to four samples so the Compatibility / WebGL shader actually compiles.

uniform sampler2D grass_tex : source_color, repeat_enable, filter_linear_mipmap;
uniform sampler2D dirt_tex : source_color, repeat_enable, filter_linear_mipmap;
uniform sampler2D path_tex : source_color, repeat_enable, filter_linear_mipmap;
uniform float path_amount : hint_range(0.0, 1.0) = 0.25;
uniform float detail_strength : hint_range(0.0, 0.5) = 0.18;
uniform float uv_scale : hint_range(0.05, 1.5) = 0.5;

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
	// Baked materials stored a small uv_scale. Floor it so tiles stay readable.
	float scale = max(uv_scale, 0.5);
	vec2 uv = wpos.xz * scale;
	vec3 grass = texture(grass_tex, uv).rgb;
	vec3 dirt = texture(dirt_tex, uv + vec2(3.1, 1.7)).rgb;
	vec3 path = texture(path_tex, uv * 0.82 + vec2(8.0, 2.0)).rgb;
	vec3 detail = texture(grass_tex, uv * 2.35 + vec2(1.3, 4.8)).rgb;
	grass = mix(grass, detail, clamp(detail_strength, 0.0, 0.45));

	// 12–20 m patches. These survive mipmaps from the HQ roof.
	float patch = noise(wpos.xz * 0.055);
	float patch2 = noise(wpos.xz * 0.019 + 4.2);
	float dirt_mask = smoothstep(0.34, 0.58, patch);
	float bare_mask = smoothstep(0.55, 0.78, patch2);
	float path_mask = clamp(path_amount, 0.0, 1.0);

	vec3 paint_grass = vec3(0.18, 0.36, 0.12);
	vec3 paint_dirt = vec3(0.42, 0.29, 0.14);
	vec3 paint_path = vec3(0.50, 0.38, 0.20);
	vec3 paint = mix(paint_grass, paint_dirt, max(dirt_mask, bare_mask * 0.85));
	paint = mix(paint, paint_path, path_mask);

	vec3 photos = mix(grass, dirt, max(dirt_mask, bare_mask));
	photos = mix(photos, path, path_mask);
	// Photo detail up close, painted regions from the roof if the tile mips out.
	vec3 col = mix(paint, photos, 0.72);

	float broad = noise(wpos.xz * 0.09 + 2.0);
	col *= mix(0.78, 1.16, broad);
	col *= mix(0.92, 1.06, patch);

	ALBEDO = col;
	ROUGHNESS = mix(0.96, 0.74, luma(col));
	METALLIC = 0.0;
}
