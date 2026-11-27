extends RefCounted
class_name ProcMesh
## Low-poly procedural mesh & cached material helpers.
## Material + primitive mesh caching keeps WebGL / mobile shader & RID churn low.

static var _mat_cache: Dictionary = {}
static var _mesh_cache: Dictionary = {}


static func mat(color: Color, roughness: float = 0.82, metallic: float = 0.05) -> Material:
	var webish := OS.has_feature("web") or OS.has_feature("mobile")
	# Unshaded on web/mobile Compatibility — fewer shader variants, reliable draw
	var key := "%s_%.2f_%.2f_%s" % [color.to_html(true), roughness, metallic, "u" if webish else "l"]
	if _mat_cache.has(key):
		return _mat_cache[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = roughness
	m.metallic = metallic
	m.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	if webish:
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	if color.a < 0.99:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat_cache[key] = m
	return m


static func gun_mat(color: Color, roughness: float = 0.55, metallic: float = 0.35) -> Material:
	## Weapon viewmodel material — rim/fresnel on High quality.
	if GraphicsQuality:
		return GraphicsQuality.make_gun_material(color, metallic, roughness)
	return mat(color, roughness, metallic)


static func unshaded(color: Color) -> StandardMaterial3D:
	var key := "u_%s" % color.to_html(true)
	if _mat_cache.has(key):
		return _mat_cache[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	if color.a < 0.99:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat_cache[key] = m
	return m


static func emissive(color: Color, energy: float = 2.0) -> StandardMaterial3D:
	var key := "e_%s_%.2f" % [color.to_html(true), energy]
	if _mat_cache.has(key):
		return _mat_cache[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = energy
	m.roughness = 0.4
	m.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	if color.a < 0.99:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat_cache[key] = m
	return m


static func _cached_box(size: Vector3) -> BoxMesh:
	var key := "box:%.3f,%.3f,%.3f" % [size.x, size.y, size.z]
	if _mesh_cache.has(key):
		return _mesh_cache[key]
	var box := BoxMesh.new()
	box.size = size
	_mesh_cache[key] = box
	return box


static func box_mesh(size: Vector3, color: Color, roughness: float = 0.82, metallic: float = 0.05) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = _cached_box(size)
	mi.material_override = mat(color, roughness, metallic)
	_prepare_instance(mi)
	return mi


static func _prepare_instance(mi: MeshInstance3D) -> void:
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	if OS.has_feature("web") or OS.has_feature("mobile"):
		mi.extra_cull_margin = 2.0


static func capsule_mesh(radius: float, height: float, color: Color, roughness: float = 0.82, metallic: float = 0.05) -> MeshInstance3D:
	var key := "cap:%.3f,%.3f" % [radius, height]
	var cap: CapsuleMesh
	if _mesh_cache.has(key):
		cap = _mesh_cache[key]
	else:
		cap = CapsuleMesh.new()
		cap.radius = radius
		cap.height = height
		cap.radial_segments = 8
		cap.rings = 3
		_mesh_cache[key] = cap
	var mi := MeshInstance3D.new()
	mi.mesh = cap
	mi.material_override = mat(color, roughness, metallic)
	_prepare_instance(mi)
	return mi


static func sphere_mesh(radius: float, color: Color, roughness: float = 0.82, metallic: float = 0.05) -> MeshInstance3D:
	var key := "sph:%.3f" % radius
	var sph: SphereMesh
	if _mesh_cache.has(key):
		sph = _mesh_cache[key]
	else:
		sph = SphereMesh.new()
		sph.radius = radius
		sph.height = radius * 2.0
		sph.radial_segments = 8
		sph.rings = 4
		_mesh_cache[key] = sph
	var mi := MeshInstance3D.new()
	mi.mesh = sph
	mi.material_override = mat(color, roughness, metallic)
	_prepare_instance(mi)
	return mi


static func cylinder_mesh(radius: float, height: float, color: Color, roughness: float = 0.8, metallic: float = 0.1, segments: int = 10) -> MeshInstance3D:
	var segs := mini(segments, 8) if OS.has_feature("web") else segments
	var key := "cyl:%.3f,%.3f,%d" % [radius, height, segs]
	var cyl: CylinderMesh
	if _mesh_cache.has(key):
		cyl = _mesh_cache[key]
	else:
		cyl = CylinderMesh.new()
		cyl.top_radius = radius
		cyl.bottom_radius = radius
		cyl.height = height
		cyl.radial_segments = segs
		cyl.rings = 1
		_mesh_cache[key] = cyl
	var mi := MeshInstance3D.new()
	mi.mesh = cyl
	mi.material_override = mat(color, roughness, metallic)
	_prepare_instance(mi)
	return mi


static func cone_mesh(bottom_radius: float, top_radius: float, height: float, color: Color, roughness: float = 0.85, metallic: float = 0.05, segments: int = 8) -> MeshInstance3D:
	var segs := mini(segments, 7) if OS.has_feature("web") else segments
	var key := "cone:%.3f,%.3f,%.3f,%d" % [bottom_radius, top_radius, height, segs]
	var cyl: CylinderMesh
	if _mesh_cache.has(key):
		cyl = _mesh_cache[key]
	else:
		cyl = CylinderMesh.new()
		cyl.bottom_radius = bottom_radius
		cyl.top_radius = top_radius
		cyl.height = height
		cyl.radial_segments = segs
		cyl.rings = 1
		_mesh_cache[key] = cyl
	var mi := MeshInstance3D.new()
	mi.mesh = cyl
	mi.material_override = mat(color, roughness, metallic)
	_prepare_instance(mi)
	return mi


static func add_part(parent: Node3D, mesh_inst: MeshInstance3D, pos: Vector3 = Vector3.ZERO, rot_deg: Vector3 = Vector3.ZERO, part_name: String = "") -> MeshInstance3D:
	if part_name != "":
		mesh_inst.name = part_name
	mesh_inst.position = pos
	if rot_deg != Vector3.ZERO:
		mesh_inst.rotation_degrees = rot_deg
	parent.add_child(mesh_inst)
	return mesh_inst


static func cache_stats() -> Dictionary:
	return {"materials": _mat_cache.size(), "meshes": _mesh_cache.size()}
