extends Node
## Graphics quality tiers for GL Compatibility / WebGL.
## Low  (0): flat materials, light fog, no wind/grade/rim — mobile default
## Med  (1): wind foliage + water shader + fog
## High (2): + gun rim, scope lens, color grade overlay — PC default

signal quality_changed(level: int)

const LEVEL_LOW := 0
const LEVEL_MED := 1
const LEVEL_HIGH := 2
const LEVEL_NAMES := ["Low", "Medium", "High"]

var level: int = LEVEL_HIGH
var _grade_layer: CanvasLayer
var _grade_rect: ColorRect
var _foliage_shader: Shader
var _water_shader: Shader
var _gun_shader: Shader
var _lens_shader: Shader
var _grade_shader: Shader
var _sky_shader: Shader
var _terrain_shader: Shader
var _surface_shader: Shader
var _grass_tex: Texture2D
var _dirt_tex: Texture2D
var _mud_tex: Texture2D
var _gravel_tex: Texture2D
var _path_tex: Texture2D
var _terrain_cache: Dictionary = {}
var _terrain_mat: ShaderMaterial
var _path_mat: ShaderMaterial
var _surface_cache: Dictionary = {}


func _ready() -> void:
	_foliage_shader = load("res://shaders/foliage_wind.gdshader") as Shader
	_water_shader = load("res://shaders/water.gdshader") as Shader
	_gun_shader = load("res://shaders/gun_rim.gdshader") as Shader
	_lens_shader = load("res://shaders/scope_lens.gdshader") as Shader
	_grade_shader = load("res://shaders/color_grade.gdshader") as Shader
	_sky_shader = load("res://shaders/sky_cycle.gdshader") as Shader
	_terrain_shader = load("res://shaders/terrain_splat.gdshader") as Shader
	_surface_shader = load("res://shaders/surface_wear.gdshader") as Shader
	_grass_tex = load("res://assets/textures/ground/Grass004.png") as Texture2D
	_dirt_tex = load("res://assets/textures/ground/Ground037.png") as Texture2D
	_mud_tex = load("res://assets/textures/ground/Ground048.png") as Texture2D
	_gravel_tex = load("res://assets/textures/ground/Gravel020.png") as Texture2D
	_path_tex = load("res://assets/textures/ground/Ground054.png") as Texture2D
	# Phones start on Low. Desktop, including desktop web, starts on High.
	# A laptop that reports a touchscreen must not drop the PC default.
	var phone := OS.has_feature("mobile") or OS.has_feature("android") or OS.has_feature("ios")
	if phone:
		level = LEVEL_LOW
	else:
		level = LEVEL_HIGH
	if GameState and "graphics_quality" in GameState:
		if phone:
			level = clampi(int(GameState.graphics_quality), LEVEL_LOW, LEVEL_HIGH)
		else:
			# Saved Low from an old touchscreen heuristic should not stick on PC.
			var saved := clampi(int(GameState.graphics_quality), LEVEL_LOW, LEVEL_HIGH)
			level = LEVEL_HIGH if saved == LEVEL_LOW else saved
			if GameState.graphics_quality != level:
				GameState.graphics_quality = level
	print("QUALITY_READY level=", level_name(), " phone=", phone)
	call_deferred("_ensure_grade_overlay")
	call_deferred("apply")


func cycle() -> int:
	level = (level + 1) % 3
	if GameState and GameState.has_method("set_graphics_quality"):
		GameState.set_graphics_quality(level)
	elif GameState:
		GameState.graphics_quality = level
	apply()
	return level


func set_level(v: int) -> void:
	level = clampi(v, LEVEL_LOW, LEVEL_HIGH)
	if GameState:
		GameState.graphics_quality = level
	apply()


func level_name() -> String:
	return LEVEL_NAMES[clampi(level, 0, 2)]


func wants_wind() -> bool:
	return level >= LEVEL_MED


func wants_water_shader() -> bool:
	return level >= LEVEL_MED


func wants_gun_rim() -> bool:
	return level >= LEVEL_HIGH


func wants_scope_lens() -> bool:
	return level >= LEVEL_HIGH


func wants_color_grade() -> bool:
	return level >= LEVEL_MED


func wants_shadows() -> bool:
	return level >= LEVEL_MED


func wants_bloom() -> bool:
	return level >= LEVEL_HIGH


func wants_sky_shader() -> bool:
	return level >= LEVEL_MED and _sky_shader != null


func wants_terrain_shader() -> bool:
	return _terrain_shader != null and _grass_tex != null


func shadow_distance() -> float:
	return 48.0 if level == LEVEL_MED else 80.0


func fog_density_scale() -> float:
	match level:
		LEVEL_LOW:
			return 0.45
		LEVEL_MED:
			return 0.85
		_:
			return 1.0


func refresh_group_materials() -> void:
	_retag_group_materials("foliage_wind", wants_wind())
	_retag_group_materials("water_fx", wants_water_shader())


func apply() -> void:
	_ensure_grade_overlay()
	if is_instance_valid(_grade_rect):
		_grade_rect.visible = wants_color_grade()
	_refresh_world_env()
	_retag_group_materials("foliage_wind", wants_wind())
	_retag_group_materials("water_fx", wants_water_shader())
	quality_changed.emit(level)


func make_foliage_material(color: Color, tex: Texture2D = null) -> Material:
	if tex != null:
		# Leaf cards stay cut out on every preset. Wind sway is Med+.
		if wants_wind() and _foliage_shader != null:
			var cut := ShaderMaterial.new()
			cut.shader = _foliage_shader
			cut.set_shader_parameter("albedo", color)
			cut.set_shader_parameter("albedo_tex", tex)
			cut.set_shader_parameter("cutout", 1.0)
			cut.set_shader_parameter("wind_strength", 0.12 if level == LEVEL_MED else 0.18)
			cut.set_shader_parameter("wind_speed", 1.2)
			return cut
		var flat := StandardMaterial3D.new()
		flat.albedo_color = color
		flat.albedo_texture = tex
		flat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		flat.alpha_scissor_threshold = 0.4
		flat.cull_mode = BaseMaterial3D.CULL_DISABLED
		flat.roughness = 0.95
		flat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		return flat
	if not wants_wind() or _foliage_shader == null:
		return ProcMesh.mat(color, 0.92, 0.0)
	var mat := ShaderMaterial.new()
	mat.shader = _foliage_shader
	mat.set_shader_parameter("albedo", color)
	mat.set_shader_parameter("cutout", 0.0)
	mat.set_shader_parameter("wind_strength", 0.16 if level == LEVEL_MED else 0.22)
	mat.set_shader_parameter("wind_speed", 1.2)
	return mat


func make_water_material(shallow: Color = Color(0.18, 0.46, 0.52, 0.88), deep: Color = Color(0.06, 0.22, 0.34, 0.95)) -> Material:
	if not wants_water_shader() or _water_shader == null:
		var flat := StandardMaterial3D.new()
		flat.albedo_color = deep
		flat.roughness = 0.2
		flat.metallic = 0.2
		if deep.a < 0.99:
			flat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		return flat
	var mat := ShaderMaterial.new()
	mat.shader = _water_shader
	mat.set_shader_parameter("shallow_color", shallow)
	mat.set_shader_parameter("deep_color", deep)
	mat.set_shader_parameter("wave_speed", 0.32)
	return mat


func make_terrain_material(path_bias: float = 0.18) -> Material:
	if not wants_terrain_shader():
		return ProcMesh.mat(Color(0.30, 0.38, 0.22), 0.92, 0.0)
	var key := "%d_%.2f" % [level, path_bias]
	if _terrain_cache.has(key):
		return _terrain_cache[key]
	var mat := ShaderMaterial.new()
	mat.shader = _terrain_shader
	mat.set_shader_parameter("grass_tex", _grass_tex)
	mat.set_shader_parameter("dirt_tex", _dirt_tex)
	mat.set_shader_parameter("mud_tex", _mud_tex)
	mat.set_shader_parameter("gravel_tex", _gravel_tex)
	mat.set_shader_parameter("path_tex", _path_tex)
	mat.set_shader_parameter("path_amount", path_bias)
	# Low keeps a real tile. Detail is one extra sample, not a second shader.
	mat.set_shader_parameter("detail_strength", 0.12 if level == LEVEL_LOW else (0.2 if level == LEVEL_MED else 0.28))
	mat.set_shader_parameter("uv_scale", 0.52)
	_terrain_cache[key] = mat
	return mat


func make_surface_material(color: Color, roughness: float = 0.72, metallic: float = 0.05) -> Material:
	if level < LEVEL_HIGH or _surface_shader == null:
		return ProcMesh.mat(color, roughness, metallic)
	var key := "%s_%.2f_%.2f" % [color.to_html(false), roughness, metallic]
	if _surface_cache.has(key):
		return _surface_cache[key]
	var mat := ShaderMaterial.new()
	mat.shader = _surface_shader
	mat.set_shader_parameter("albedo", color)
	mat.set_shader_parameter("roughness", roughness)
	mat.set_shader_parameter("metallic", metallic)
	mat.set_shader_parameter("wear", 0.45)
	_surface_cache[key] = mat
	return mat


func apply_sky(env: Environment, hour: float, sun_elev: float) -> void:
	if env == null:
		return
	if wants_sky_shader():
		var sky := env.sky if env.sky else Sky.new()
		var sm := sky.sky_material as ShaderMaterial
		if sm == null or sm.shader != _sky_shader:
			sm = ShaderMaterial.new()
			sm.shader = _sky_shader
			sky.sky_material = sm
		env.sky = sky
		env.background_mode = Environment.BG_SKY
		sm.set_shader_parameter("sun_elev", sun_elev)
		var night := sun_elev < -0.02
		var dusk := absf(sun_elev) < 0.28 and not night
		sm.set_shader_parameter("star_strength", 0.85 if night else (0.15 if dusk else 0.0))
		sm.set_shader_parameter("cloud_cover", 0.35 if night else 0.5)
	var day := sun_elev > 0.12
	if wants_bloom():
		env.glow_enabled = true
		# Day bloom was blowing the yard out. Night bloom stays.
		env.glow_intensity = 0.16 if day else 0.7
		env.glow_bloom = 0.08 if day else 0.12
		env.glow_strength = 0.55 if day else 0.8
	else:
		env.glow_enabled = false
	# Depth haze on Med+, cheap exponential on Low. Pull day fog back so the yard stays saturated.
	env.fog_height = 5.5
	env.fog_height_density = 0.04 if level == LEVEL_LOW else (0.05 if day else 0.09)
	if level >= LEVEL_MED:
		env.fog_mode = Environment.FOG_MODE_DEPTH
		env.fog_depth_begin = (70.0 if day else 36.0) if level == LEVEL_MED else (88.0 if day else 42.0)
		env.fog_depth_end = 260.0 if day else 210.0
		env.fog_depth_curve = 1.35 if day else 1.55
	elif not day:
		env.fog_mode = Environment.FOG_MODE_EXPONENTIAL
		env.fog_density = 0.0014
		env.fog_light_color = Color(0.08, 0.10, 0.16)
	_apply_grade_for_hour(hour, sun_elev)


func _apply_grade_for_hour(hour: float, sun_elev: float) -> void:
	if not is_instance_valid(_grade_rect) or _grade_rect.material == null:
		return
	var sm := _grade_rect.material as ShaderMaterial
	if sm == null:
		return
	# Day grade is a whisper of warmth. The old pale-blue wash was the daylight haze.
	var tint := Color(1.0, 0.96, 0.88, 0.025)
	if sun_elev < -0.05:
		tint = Color(0.35, 0.42, 0.7, 0.16)
	elif absf(sun_elev) < 0.28:
		tint = Color(0.95, 0.55, 0.28, 0.12)
	sm.set_shader_parameter("grade_tint", tint)
	sm.set_shader_parameter("vignette_strength", 0.22 if level == LEVEL_MED else 0.38)


func make_gun_material(color: Color, metallic: float = 0.35, roughness: float = 0.55) -> Material:
	if not wants_gun_rim() or _gun_shader == null:
		return ProcMesh.mat(color, roughness, metallic)
	var mat := ShaderMaterial.new()
	mat.shader = _gun_shader
	mat.set_shader_parameter("albedo", color)
	mat.set_shader_parameter("rim_color", Color(0.55, 0.72, 0.95, 1.0))
	mat.set_shader_parameter("rim_strength", 0.5)
	mat.set_shader_parameter("metallic", metallic)
	mat.set_shader_parameter("roughness", roughness)
	return mat


func make_scope_lens_material(glass: Color = Color(0.55, 0.78, 1.0, 0.14)) -> Material:
	if not wants_scope_lens() or _lens_shader == null:
		var m := StandardMaterial3D.new()
		m.albedo_color = glass
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.roughness = 0.08
		m.metallic = 0.05
		return m
	var mat := ShaderMaterial.new()
	mat.shader = _lens_shader
	mat.set_shader_parameter("glass_color", glass)
	return mat


func _ensure_grade_overlay() -> void:
	if is_instance_valid(_grade_layer):
		return
	_grade_layer = CanvasLayer.new()
	_grade_layer.name = "GraphicsGrade"
	_grade_layer.layer = 40
	_grade_rect = ColorRect.new()
	_grade_rect.name = "GradeRect"
	_grade_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_grade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_grade_rect.color = Color(1, 1, 1, 1)
	if _grade_shader:
		var sm := ShaderMaterial.new()
		sm.shader = _grade_shader
		_grade_rect.material = sm
	_grade_layer.add_child(_grade_rect)
	get_tree().root.call_deferred("add_child", _grade_layer)
	_grade_rect.visible = wants_color_grade()


func _refresh_world_env() -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return
	var we := scene.find_child("WorldEnvironment", true, false) as WorldEnvironment
	if we == null or we.environment == null:
		return
	var base := 0.0042
	we.environment.fog_density = base * fog_density_scale()
	we.environment.fog_enabled = true
	if level == LEVEL_LOW:
		we.environment.fog_density = 0.0009


func _retag_group_materials(group: String, enable: bool) -> void:
	## Nodes in foliage_wind / water_fx can expose apply_quality(enable).
	for n in get_tree().get_nodes_in_group(group):
		if n.has_method("apply_quality"):
			n.apply_quality(enable)
		elif n is MeshInstance3D or n is MultiMeshInstance3D:
			var geo := n as GeometryInstance3D
			if group == "foliage_wind":
				var col := Color(0.22, 0.38, 0.16)
				var tex: Texture2D = null
				if geo.material_override is StandardMaterial3D:
					var std := geo.material_override as StandardMaterial3D
					col = std.albedo_color
					tex = std.albedo_texture
				elif geo.material_override is ShaderMaterial:
					var sm := geo.material_override as ShaderMaterial
					var albedo = sm.get_shader_parameter("albedo")
					if albedo is Color:
						col = albedo
					var existing = sm.get_shader_parameter("albedo_tex")
					if existing is Texture2D:
						tex = existing
					var cut = sm.get_shader_parameter("cutout")
					var cut_v := 0.0
					if cut is float or cut is int:
						cut_v = float(cut)
					if tex == null and cut_v > 0.5:
						continue
				if enable:
					geo.material_override = make_foliage_material(col, tex)
				elif tex != null:
					geo.material_override = make_foliage_material(col, tex)
				elif geo.material_override is ShaderMaterial:
					geo.material_override = ProcMesh.mat(col, 0.92, 0.0)
			elif group == "water_fx" and enable:
				geo.material_override = make_water_material()
