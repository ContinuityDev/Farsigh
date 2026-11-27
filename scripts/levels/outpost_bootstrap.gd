extends Node3D
## Attaches a simple Environment to WorldEnvironment for mobile-friendly lighting.


func _ready() -> void:
	var we := get_node_or_null("WorldEnvironment") as WorldEnvironment
	if we == null:
		return
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.45, 0.55, 0.62)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.55, 0.58, 0.5)
	env.ambient_light_energy = 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = false
	env.ssao_enabled = false
	env.ssil_enabled = false
	env.sdfgi_enabled = false
	env.fog_enabled = false
	we.environment = env
