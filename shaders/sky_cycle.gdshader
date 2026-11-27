shader_type sky;
// Procedural day/night sky: gradient, clouds, sunset, stars.
// Compatibility sky shader — no screen textures.

uniform float sun_elev : hint_range(-1.0, 1.0) = 0.6;
uniform vec4 day_top : source_color = vec4(0.22, 0.42, 0.78, 1.0);
uniform vec4 day_horizon : source_color = vec4(0.72, 0.78, 0.84, 1.0);
uniform vec4 sunset_horizon : source_color = vec4(0.95, 0.42, 0.22, 1.0);
uniform vec4 night_top : source_color = vec4(0.02, 0.03, 0.08, 1.0);
uniform vec4 night_horizon : source_color = vec4(0.08, 0.10, 0.18, 1.0);
uniform float cloud_cover : hint_range(0.0, 1.0) = 0.45;
uniform float star_strength : hint_range(0.0, 1.0) = 0.0;

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

void sky() {
	float h = clamp(EYEDIR.y * 0.5 + 0.5, 0.0, 1.0);
	float day = smoothstep(-0.02, 0.42, sun_elev);
	float sunset = exp(-abs(sun_elev) * 3.4) * (1.0 - smoothstep(0.02, 0.48, sun_elev));
	vec3 zenith = mix(night_top.rgb, day_top.rgb, day);
	vec3 horizon = mix(night_horizon.rgb, day_horizon.rgb, day);
	horizon = mix(horizon, sunset_horizon.rgb, sunset * (1.0 - h));
	vec3 col = mix(horizon, zenith, pow(h, 0.65));

	vec2 cuv = EYEDIR.xz / max(0.15, EYEDIR.y * 0.5 + 0.55);
	float n = noise(cuv * 2.2 + vec2(TIME * 0.012, 0.0));
	n += noise(cuv * 5.0 - vec2(TIME * 0.02, TIME * 0.01)) * 0.45;
	float clouds = smoothstep(0.55 - cloud_cover * 0.25, 0.82, n) * smoothstep(0.02, 0.18, EYEDIR.y);
	vec3 cloud_col = mix(vec3(0.95, 0.78, 0.62), vec3(0.92, 0.94, 0.96), day);
	cloud_col = mix(cloud_col, vec3(0.15, 0.16, 0.22), 1.0 - day);
	col = mix(col, cloud_col, clouds * 0.85);

	float stars = step(0.992, hash(floor(EYEDIR.xy * 180.0))) * star_strength * smoothstep(0.15, 0.5, h);
	col += vec3(0.85, 0.9, 1.0) * stars * (1.0 - clouds);

	COLOR = col;
}
