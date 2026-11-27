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


func _ready() -> void:
	_foliage_shader = load("res://shaders/foliage_wind.gdshader") as Shader
	_water_shader = load("res://shaders/water.gdshader") as Shader
	_gun_shader = load("res://shaders/gun_rim.gdshader") as Shader
	_lens_shader = load("res://shaders/scope_lens.gdshader") as Shader
	_grade_shader = load("res://shaders/color_grade.gdshader") as Shader
	# Default: High on desktop, Low on mobile / touch web
	if OS.has_feature("mobile") or OS.has_feature("android") or OS.has_feature("ios"):
		level = LEVEL_LOW
	elif OS.has_feature("web") and DisplayServer.is_touchscreen_available():
		level = LEVEL_LOW
	else:
		level = LEVEL_HIGH
	if GameState and "graphics_quality" in GameState:
		level = clampi(int(GameState.graphics_quality), LEVEL_LOW, LEVEL_HIGH)
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
	return level >= LEVEL_HIGH


func fog_density_scale() -> float:
	match level:
		LEVEL_LOW:
			return 0.65
		LEVEL_MED:
			return 1.0
		_:
			return 1.35


func apply() -> void:
	_ensure_grade_overlay()
	if is_instance_valid(_grade_rect):
		_grade_rect.visible = wants_color_grade()
	_refresh_world_env()
	_retag_group_materials("foliage_wind", wants_wind())
	_retag_group_materials("water_fx", wants_water_shader())
	quality_changed.emit(level)


func make_foliage_material(color: Color) -> Material:
	if not wants_wind() or _foliage_shader == null:
		return ProcMesh.mat(color, 0.92, 0.0)
	var mat := ShaderMaterial.new()
	mat.shader = _foliage_shader
	mat.set_shader_parameter("albedo", color)
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
	match level:
		LEVEL_LOW:
			we.environment.tonemap_exposure = 1.05
		LEVEL_MED:
			we.environment.tonemap_exposure = 1.0
		_:
			we.environment.tonemap_exposure = 0.95


func _retag_group_materials(group: String, enable: bool) -> void:
	## Nodes in foliage_wind / water_fx can expose apply_quality(enable).
	for n in get_tree().get_nodes_in_group(group):
		if n.has_method("apply_quality"):
			n.apply_quality(enable)
		elif n is MeshInstance3D:
			var mi := n as MeshInstance3D
			if group == "foliage_wind" and enable:
				var col := Color(0.22, 0.38, 0.16)
				if mi.material_override is StandardMaterial3D:
					col = (mi.material_override as StandardMaterial3D).albedo_color
				mi.material_override = make_foliage_material(col)
			elif group == "water_fx" and enable:
				mi.material_override = make_water_material()
