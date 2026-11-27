shader_type spatial;
render_mode cull_disabled, depth_draw_opaque, specular_disabled;
// GL Compatibility / WebGL-safe soft wind sway for grass & bush leaves.
// Vertex displacement only — no screen textures.

uniform vec4 albedo : source_color = vec4(0.22, 0.38, 0.16, 1.0);
uniform float wind_strength : hint_range(0.0, 0.6) = 0.18;
uniform float wind_speed : hint_range(0.0, 4.0) = 1.35;
uniform float wind_scale : hint_range(0.1, 4.0) = 1.0;
uniform float roughness : hint_range(0.0, 1.0) = 0.92;
uniform float metallic : hint_range(0.0, 1.0) = 0.0;

void vertex() {
	float h = clamp(VERTEX.y * 0.55 + 0.15, 0.0, 1.0);
	float phase = (NODE_POSITION_WORLD.x + NODE_POSITION_WORLD.z) * wind_scale;
	float sway = sin(TIME * wind_speed + phase) * wind_strength * h;
	float sway2 = cos(TIME * wind_speed * 0.73 + phase * 1.3) * wind_strength * 0.45 * h;
	VERTEX.x += sway;
	VERTEX.z += sway2;
}

void fragment() {
	ALBEDO = albedo.rgb;
	ROUGHNESS = roughness;
	METALLIC = metallic;
	ALPHA = albedo.a;
}
