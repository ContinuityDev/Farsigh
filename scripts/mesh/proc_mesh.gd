extends RefCounted
class_name ProcMesh
## Low-poly procedural mesh & cached material helpers.
## Material caching keeps WebGL / mobile shader & state changes minimal.

static var _mat_cache: Dictionary = {}


static func mat(color: Color, roughness: float = 0.82, metallic: float = 0.05) -> StandardMaterial3D:
	var key := "%s_%.2f_%.2f" % [color.to_html(true), roughness, metallic]
	if _mat_cache.has(key):
		return _mat_cache[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = roughness
	m.metallic = metallic
	if color.a < 0.99:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat_cache[key] = m
	return m


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
	if color.a < 0.99:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat_cache[key] = m
	return m


static func box_mesh(size: Vector3, color: Color, roughness: float = 0.82, metallic: float = 0.05) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mi.mesh = box
	mi.material_override = mat(color, roughness, metallic)
	return mi


static func capsule_mesh(radius: float, height: float, color: Color, roughness: float = 0.82, metallic: float = 0.05) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cap := CapsuleMesh.new()
	cap.radius = radius
	cap.height = height
	cap.radial_segments = 10
	cap.rings = 4
	mi.mesh = cap
	mi.material_override = mat(color, roughness, metallic)
	return mi


static func sphere_mesh(radius: float, color: Color, roughness: float = 0.82, metallic: float = 0.05) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var sph := SphereMesh.new()
	sph.radius = radius
	sph.height = radius * 2.0
	sph.radial_segments = 10
	sph.rings = 6
	mi.mesh = sph
	mi.material_override = mat(color, roughness, metallic)
	return mi


static func cylinder_mesh(radius: float, height: float, color: Color, roughness: float = 0.8, metallic: float = 0.1, segments: int = 10) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = radius
	cyl.bottom_radius = radius
	cyl.height = height
	cyl.radial_segments = segments
	cyl.rings = 1
	mi.mesh = cyl
	mi.material_override = mat(color, roughness, metallic)
	return mi


static func cone_mesh(bottom_radius: float, top_radius: float, height: float, color: Color, roughness: float = 0.85, metallic: float = 0.05, segments: int = 8) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.bottom_radius = bottom_radius
	cyl.top_radius = top_radius
	cyl.height = height
	cyl.radial_segments = segments
	cyl.rings = 1
	mi.mesh = cyl
	mi.material_override = mat(color, roughness, metallic)
	return mi


static func add_part(parent: Node3D, mesh_inst: MeshInstance3D, pos: Vector3 = Vector3.ZERO, rot_deg: Vector3 = Vector3.ZERO, part_name: String = "") -> MeshInstance3D:
	if part_name != "":
		mesh_inst.name = part_name
	mesh_inst.position = pos
	if rot_deg != Vector3.ZERO:
		mesh_inst.rotation_degrees = rot_deg
	parent.add_child(mesh_inst)
	return mesh_inst
