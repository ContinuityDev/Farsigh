extends RefCounted
class_name SurfaceLib
## Tinted CC0-style surface textures for buildings, crates, and fences.
## Grayscale maps are colored by albedo so one texture serves every paint job.


static var _cache: Dictionary = {}


static func styled_box(color: Color, size: Vector3) -> Material:
	var kind := _kind_for(color, size)
	if kind == "":
		return null
	var reps := Vector3(maxf(maxf(size.x, size.z), 0.6) * 0.38, maxf(size.y, 0.35) * 0.48, 1.0)
	return tinted(kind, color, reps)


static func tinted(kind: String, color: Color, uv_scale: Vector3) -> StandardMaterial3D:
	var key := "%s_%s_%.2f_%.2f" % [kind, color.to_html(false), uv_scale.x, uv_scale.y]
	if _cache.has(key):
		return _cache[key]
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color.lightened(0.12)
	mat.albedo_texture = _texture(kind)
	mat.uv1_scale = uv_scale
	mat.roughness = 0.86 if kind != "roof" else 0.9
	mat.metallic = 0.04 if kind == "chain" else 0.02
	mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	if kind == "chain" or kind == "leaf":
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		mat.alpha_scissor_threshold = 0.35
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_cache[key] = mat
	return mat


static func _kind_for(color: Color, size: Vector3) -> String:
	# Roofs and wide caps. Skip paper-thin foundations (those stay concrete).
	if size.y >= 0.18 and size.y <= 0.55 and size.x >= 2.4 and size.z >= 2.4 and size.x < 36.0 and size.z < 36.0:
		return "roof"
	var wide := maxf(size.x, size.z)
	var thin := minf(size.x, size.z)
	if size.y >= 1.05 and wide >= 1.5 and wide <= 24.0 and thin >= 0.2 and thin <= 1.3:
		if color.r > color.b * 1.2 and color.r > 0.32 and color.g < color.r * 0.98:
			return "wood"
		return "stucco"
	return ""


static func _texture(kind: String) -> Texture2D:
	var path := "res://assets/textures/surfaces/stucco.png"
	match kind:
		"wood":
			path = "res://assets/textures/surfaces/wood.png"
		"roof":
			path = "res://assets/textures/surfaces/roof.png"
		"chain":
			path = "res://assets/textures/surfaces/chainlink.png"
		"leaf":
			path = "res://assets/textures/surfaces/leaf.png"
	if ResourceLoader.exists(path):
		return load(path) as Texture2D
	return null
