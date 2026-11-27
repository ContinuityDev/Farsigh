extends Node3D
## Builds a performance-friendly greybox compound from primitive meshes at runtime.


func _ready() -> void:
	_build()


func _build() -> void:
	# Ground (collision + visible mesh)
	_box(Vector3(0, -0.5, 0), Vector3(90, 1.0, 90), Color(0.30, 0.34, 0.27), true)
	# Outer fence / walls
	_wall_ring()
	# Buildings
	_building(Vector3(-8, 0, -6), Vector3(8, 4, 6), "Barracks")
	_building(Vector3(10, 0, -8), Vector3(6, 3.5, 8), "Armory")
	_building(Vector3(4, 0, 10), Vector3(10, 3, 5), "HQ")
	# Cover crates
	for p in [
		Vector3(-2, 0.5, 2), Vector3(2, 0.5, -2), Vector3(-12, 0.5, 4),
		Vector3(6, 0.5, 4), Vector3(-6, 0.5, 8), Vector3(12, 0.5, 2),
		Vector3(0, 0.6, -12), Vector3(-14, 0.5, -4), Vector3(8, 0.5, -14),
	]:
		_box(p, Vector3(1.4, 1.2, 1.4), Color(0.45, 0.4, 0.32))
	# Sandbags / low cover
	for p in [Vector3(-4, 0.35, 0), Vector3(0, 0.35, 6), Vector3(8, 0.35, -4)]:
		_box(p, Vector3(3.0, 0.7, 0.8), Color(0.5, 0.45, 0.35))
	# Watchtower
	_box(Vector3(-14, 2.5, -14), Vector3(2.5, 5, 2.5), Color(0.35, 0.38, 0.4))
	# Entrances markers (gaps already in walls)
	_box(Vector3(0, 0.05, 22), Vector3(4, 0.1, 2), Color(0.4, 0.55, 0.35), false)
	_box(Vector3(-22, 0.05, 0), Vector3(2, 0.1, 4), Color(0.4, 0.55, 0.35), false)


func _wall_ring() -> void:
	var h := 2.8
	var t := 0.4
	var s := 22.0
	# North / South with gate gaps
	_box(Vector3(-8, h * 0.5, -s), Vector3(20, h, t), Color(0.4, 0.42, 0.38))
	_box(Vector3(10, h * 0.5, -s), Vector3(16, h, t), Color(0.4, 0.42, 0.38))
	_box(Vector3(-10, h * 0.5, s), Vector3(16, h, t), Color(0.4, 0.42, 0.38))
	_box(Vector3(10, h * 0.5, s), Vector3(16, h, t), Color(0.4, 0.42, 0.38))
	# West / East with side entrance
	_box(Vector3(-s, h * 0.5, -10), Vector3(t, h, 16), Color(0.4, 0.42, 0.38))
	_box(Vector3(-s, h * 0.5, 10), Vector3(t, h, 16), Color(0.4, 0.42, 0.38))
	_box(Vector3(s, h * 0.5, 0), Vector3(t, h, 44), Color(0.4, 0.42, 0.38))


func _building(pos: Vector3, size: Vector3, _name: String) -> void:
	_box(pos + Vector3(0, size.y * 0.5, 0), size, Color(0.38, 0.4, 0.42))
	# Interior cover
	_box(pos + Vector3(0, 0.6, 0), Vector3(size.x * 0.3, 1.2, size.z * 0.3), Color(0.42, 0.36, 0.3))


func _box(pos: Vector3, size: Vector3, color: Color, collide: bool = true) -> void:
	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mi.mesh = box
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	# Mobile-friendly: no shadows on tiny props optional — keep simple materials
	mi.material_override = mat
	mi.position = pos
	add_child(mi)
	if collide:
		var body := StaticBody3D.new()
		body.collision_layer = 1
		body.collision_mask = 0
		var cs := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = size
		cs.shape = shape
		body.add_child(cs)
		body.position = pos
		add_child(body)
