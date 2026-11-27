shader_type canvas_item;
render_mode blend_mix;
// Fullscreen soft grade / atmosphere tint. No screen_texture — WebGL-safe.
// Applied as a low-alpha ColorRect so Compatibility never samples the backbuffer.

uniform vec4 grade_tint : source_color = vec4(0.78, 0.86, 0.95, 0.08);
uniform vec4 vignette_color : source_color = vec4(0.05, 0.07, 0.10, 0.22);
uniform float vignette_strength : hint_range(0.0, 1.0) = 0.35;
uniform float vignette_power : hint_range(0.5, 4.0) = 1.8;

void fragment() {
	vec2 uv = UV * 2.0 - 1.0;
	float r = length(uv);
	float vig = pow(clamp(r, 0.0, 1.0), vignette_power) * vignette_strength;
	vec4 tint = grade_tint;
	vec4 vig_col = vignette_color;
	COLOR = mix(tint, vig_col, vig);
	COLOR.a = mix(tint.a, vig_col.a, vig);
}
