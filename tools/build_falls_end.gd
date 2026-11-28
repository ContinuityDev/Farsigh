extends SceneTree
## Builds scenes/compounds/falls_end.tscn from prefabs. Does not touch other compounds.


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var root := Node3D.new()
	root.name = "FallsEnd"
	_ground(root)
	_mountains(root)
	_chapel(root)
	_canopy(root)
	_banners(root)
	_prefab(root, "res://prefabs/buildings/garage.tscn", Vector3(-16.0, 0.0, 0.0), 90.0)
	_prefab(root, "res://prefabs/buildings/shack_barracks.tscn", Vector3(12.0, 0.0, -12.0), 180.0)
	_prefab(root, "res://prefabs/buildings/watchtower.tscn", Vector3(16.0, 0.0, -6.0), 20.0)
	_prefab(root, "res://prefabs/buildings/gate_arch.tscn", Vector3(0.0, 0.0, 22.0), 0.0)
	_prefab(root, "res://prefabs/buildings/gate_arch.tscn", Vector3(-24.0, 0.0, 6.0), 90.0)
	_fences(root)
	_prefab(root, "res://prefabs/props/pickup_truck.tscn", Vector3(7.0, 0.0, 12.0), 18.0)
	_prefab(root, "res://prefabs/props/pickup_truck_canopy.tscn", Vector3(-6.0, 0.0, 11.0), -70.0)
	_prefab(root, "res://prefabs/props/barrel_fuel.tscn", Vector3(-10.0, 0.0, 9.0), 0.0)
	_prefab(root, "res://prefabs/props/barrel.tscn", Vector3(-9.2, 0.0, 8.2), 15.0)
	_prefab(root, "res://prefabs/props/crate.tscn", Vector3(4.0, 0.0, -4.0), 12.0)
	_prefab(root, "res://prefabs/props/crate.tscn", Vector3(5.2, 0.0, -3.4), -8.0)
	_prefab(root, "res://prefabs/props/sandbag_wall.tscn", Vector3(2.0, 0.0, 14.0), 0.0)
	_prefab(root, "res://prefabs/props/hay_bale.tscn", Vector3(20.0, 0.0, 8.0), 15.0)
	_prefab(root, "res://prefabs/props/hay_bale.tscn", Vector3(22.0, 0.0, 10.0), -10.0)
	_prefab(root, "res://prefabs/buildings/light_pole.tscn", Vector3(-4.0, 0.0, 14.0), 0.0)
	_prefab(root, "res://prefabs/buildings/floodlight.tscn", Vector3(14.0, 0.0, 14.0), -30.0)
	_trees(root)
	_own(root)
	var packed := PackedScene.new()
	var err := packed.pack(root)
	if err != OK:
		push_error("pack failed %s" % err)
		quit(1)
		return
	var path := "res://scenes/compounds/falls_end.tscn"
	var save_err := ResourceSaver.save(packed, path)
	print("FALLS_END_SAVE ", save_err, " ", path)
	quit(0 if save_err == OK else 2)


func _own(node: Node) -> void:
	var root := node
	for c in node.get_children():
		c.owner = root
		if String(c.scene_file_path) == "":
			_own_under(c, root)


func _own_under(node: Node, root: Node) -> void:
	for c in node.get_children():
		c.owner = root
		if String(c.scene_file_path) == "":
			_own_under(c, root)


func _slab(root: Node3D, pos: Vector3, size: Vector3, color: Color) -> void:
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mi.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.92
	mi.material_override = mat
	mi.position = pos
	root.add_child(mi)
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	var shape := BoxShape3D.new()
	shape.size = size
	var col := CollisionShape3D.new()
	col.shape = shape
	body.add_child(col)
	mi.add_child(body)


func _ground(root: Node3D) -> void:
	_slab(root, Vector3(0, -0.55, 4), Vector3(150, 1.0, 150), Color(0.34, 0.46, 0.26))
	_slab(root, Vector3(0, 0.02, 2), Vector3(50, 0.06, 44), Color(0.55, 0.46, 0.32))
	_slab(root, Vector3(0, 0.04, 34), Vector3(7.2, 0.05, 36), Color(0.42, 0.36, 0.28))
	_slab(root, Vector3(-5.2, 0.03, 34), Vector3(2.2, 0.04, 36), Color(0.36, 0.40, 0.24))
	_slab(root, Vector3(5.2, 0.03, 34), Vector3(2.2, 0.04, 36), Color(0.36, 0.40, 0.24))
	_slab(root, Vector3(-8, 0.035, 8), Vector3(3.2, 0.04, 22), Color(0.46, 0.38, 0.27))
	_slab(root, Vector3(18, 0.03, 6), Vector3(22, 0.05, 28), Color(0.62, 0.56, 0.32))
	# West overlook hill, walkable.
	_slab(root, Vector3(-30, 0.55, 14), Vector3(16, 1.2, 18), Color(0.32, 0.42, 0.24))
	_slab(root, Vector3(-24, 0.25, 16), Vector3(8, 0.6, 10), Color(0.36, 0.46, 0.26))


func _mountains(root: Node3D) -> void:
	# Distant hazy ridges, not walls sitting behind the chapel.
	var ridge := Color(0.62, 0.68, 0.76)
	var far := Color(0.70, 0.75, 0.82)
	_slope(root, Vector3(-36, 10.0, -110), Vector3(48, 8, 28), -18.0, ridge)
	_slope(root, Vector3(10, 14.0, -128), Vector3(56, 10, 30), -14.0, far)
	_slope(root, Vector3(48, 9.0, -108), Vector3(40, 7, 24), -16.0, ridge)
	# Green foothill behind the station so the chapel has a horizon, not a blue slab.
	_slope(root, Vector3(0, 3.2, -36), Vector3(70, 4.5, 16), -12.0, Color(0.30, 0.40, 0.26))


func _chapel(root: Node3D) -> void:
	var hall := Node3D.new()
	hall.name = "Chapel"
	hall.position = Vector3(0, 0, -12)
	root.add_child(hall)
	var stucco := Color(0.86, 0.84, 0.78)
	var roof := Color(0.38, 0.16, 0.12)
	var wood := Color(0.36, 0.22, 0.13)
	_part(hall, Vector3(0, 2.2, 0), Vector3(9.2, 4.4, 13.0), stucco)
	# Gable: two planes leaning into a ridge along the nave.
	_roof_plane(hall, Vector3(-2.15, 5.15, 0), 28.0, roof)
	_roof_plane(hall, Vector3(2.15, 5.15, 0), -28.0, roof)
	# Front steeple, proud of the facade.
	_part(hall, Vector3(0, 4.6, 7.15), Vector3(2.0, 6.6, 1.7), stucco)
	_part(hall, Vector3(0, 8.15, 7.15), Vector3(2.35, 0.28, 2.0), roof)
	_part(hall, Vector3(0, 8.9, 7.15), Vector3(0.12, 1.15, 0.12), wood)
	_part(hall, Vector3(0, 9.35, 7.15), Vector3(0.72, 0.12, 0.12), wood)
	_part(hall, Vector3(0, 1.15, 6.6), Vector3(1.5, 2.2, 0.12), wood)
	_part(hall, Vector3(-2.6, 2.5, 6.55), Vector3(0.9, 1.3, 0.08), Color(0.45, 0.62, 0.72))
	_part(hall, Vector3(2.6, 2.5, 6.55), Vector3(0.9, 1.3, 0.08), Color(0.45, 0.62, 0.72))
	var sign := Label3D.new()
	sign.text = "LAMB OF GOD"
	sign.font_size = 64
	sign.pixel_size = 0.008
	sign.position = Vector3(-3.15, 3.15, 6.58)
	sign.modulate = Color(0.32, 0.1, 0.08)
	sign.outline_size = 6
	sign.outline_modulate = Color(0.93, 0.9, 0.82)
	hall.add_child(sign)


func _canopy(root: Node3D) -> void:
	var yard := Node3D.new()
	yard.name = "PumpIsland"
	yard.position = Vector3(-8, 0, 12)
	root.add_child(yard)
	var steel := Color(0.72, 0.18, 0.12)
	var white := Color(0.9, 0.9, 0.88)
	for p in [Vector3(-3.2, 1.6, -1.6), Vector3(3.2, 1.6, -1.6), Vector3(-3.2, 1.6, 1.6), Vector3(3.2, 1.6, 1.6)]:
		_part(yard, p, Vector3(0.18, 3.2, 0.18), Color(0.2, 0.2, 0.21))
	_part(yard, Vector3(0, 3.25, 0), Vector3(7.4, 0.18, 4.2), steel)
	_part(yard, Vector3(0, 3.38, 0), Vector3(7.6, 0.08, 4.4), white)
	_part(yard, Vector3(-1.3, 0.7, 0), Vector3(0.55, 1.3, 0.4), Color(0.15, 0.15, 0.16))
	_part(yard, Vector3(1.3, 0.7, 0), Vector3(0.55, 1.3, 0.4), Color(0.15, 0.15, 0.16))


func _banners(root: Node3D) -> void:
	_banner(root, Vector3(-6, 0, 20), 0.0)
	_banner(root, Vector3(6, 0, 20), 0.0)
	_banner(root, Vector3(0, 0, -4.6), 180.0)


func _banner(root: Node3D, pos: Vector3, yaw: float) -> void:
	var n := Node3D.new()
	n.name = "CultBanner"
	n.position = pos
	n.rotation_degrees.y = yaw
	root.add_child(n)
	_part(n, Vector3(0, 1.7, 0), Vector3(0.1, 3.4, 0.1), Color(0.25, 0.16, 0.1))
	_part(n, Vector3(0, 2.5, 0.04), Vector3(1.3, 1.8, 0.04), Color(0.55, 0.08, 0.08))
	_part(n, Vector3(0, 2.55, 0.07), Vector3(0.12, 1.05, 0.03), Color(0.93, 0.93, 0.9))
	_part(n, Vector3(0, 2.7, 0.07), Vector3(0.62, 0.1, 0.03), Color(0.93, 0.93, 0.9))


func _roof_plane(parent: Node3D, pos: Vector3, roll: float, color: Color) -> void:
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(5.6, 0.16, 13.4)
	mi.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.8
	mi.material_override = mat
	mi.position = pos
	mi.rotation_degrees.z = roll
	parent.add_child(mi)


func _slope(root: Node3D, pos: Vector3, size: Vector3, pitch: float, color: Color) -> void:
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mi.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.95
	mi.material_override = mat
	mi.position = pos
	mi.rotation_degrees.x = pitch
	root.add_child(mi)


func _part(parent: Node3D, pos: Vector3, size: Vector3, color: Color) -> void:
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mi.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.84
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	var shape := BoxShape3D.new()
	shape.size = size
	var col := CollisionShape3D.new()
	col.shape = shape
	body.add_child(col)
	mi.add_child(body)


func _fences(root: Node3D) -> void:
	var path := "res://prefabs/buildings/fence_segment.tscn"
	# Prefab is 4m along X. South wall leaves a gate at x=0.
	for x in [-18.0, -12.0, -6.0, 6.0, 12.0, 18.0]:
		_prefab(root, path, Vector3(x, 0, 22), 0.0, Vector3(1.4, 1, 1))
	for x in [-16.0, -8.0, 8.0, 16.0]:
		_prefab(root, path, Vector3(x, 0, -18), 0.0, Vector3(1.6, 1, 1))
	# West wall, gap at the flank gate.
	for z in [-12.0, -4.0, 14.0]:
		_prefab(root, path, Vector3(-24, 0, z), 90.0, Vector3(1.5, 1, 1))
	# East pasture is open on purpose. A short run marks the corner only.
	_prefab(root, path, Vector3(22, 0, -14), 90.0, Vector3(1.2, 1, 1))


func _trees(root: Node3D) -> void:
	var pine := "res://prefabs/foliage/pine_tree.tscn"
	var bush := "res://prefabs/foliage/bush_cluster.tscn"
	var spots := [
		Vector3(-36, 0, 8), Vector3(-32, 0, 18), Vector3(-28, 0, 4),
		Vector3(-34, 0, 22), Vector3(-18, 0, 28), Vector3(18, 0, 30),
		Vector3(28, 0, 22), Vector3(34, 0, 8), Vector3(-8, 0, -28),
		Vector3(8, 0, -26), Vector3(24, 0, -20), Vector3(-22, 0, -16),
	]
	for p in spots:
		_prefab(root, pine, p, randf() * 360.0, Vector3(1.1, 1.15, 1.1))
	for p in [Vector3(-8, 0, 18), Vector3(4, 0, 18), Vector3(18, 0, 4), Vector3(-18, 0, -4), Vector3(10, 0, -16), Vector3(-4, 0, 6)]:
		_prefab(root, bush, p, randf() * 360.0, Vector3(0.9, 0.9, 0.9))


func _prefab(root: Node3D, path: String, pos: Vector3, yaw: float, scl: Vector3 = Vector3.ONE) -> void:
	var packed := load(path) as PackedScene
	if packed == null:
		push_error("missing " + path)
		return
	var inst := packed.instantiate() as Node3D
	inst.position = pos
	inst.rotation_degrees.y = yaw
	inst.scale = scl
	root.add_child(inst)
