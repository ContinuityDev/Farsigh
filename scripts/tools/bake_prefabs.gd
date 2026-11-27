extends RefCounted
## Writes res://prefabs/<category>/*.tscn from the live greybox builders,
## then one editable compound scene per outpost built from those instances.
##
##   BAKE_COMPOUNDS=1 godot --headless --path .


static func bake(tree: SceneTree) -> void:
	var root := tree.root
	var gb = load("res://scripts/levels/greybox_builder.gd").new()
	gb.name = "GreyboxBaker"
	root.add_child(gb)
	gb.force_raw = true
	gb.lightweight_props = false
	print("BAKE graphics=", GraphicsQuality, " in_tree=", gb.is_inside_tree())

	_capture_call(gb, "res://prefabs/props/crate.tscn", "Crate", func() -> void:
		gb._crate(Vector3.ZERO, 1.0, 0.0))
	_capture_call(gb, "res://prefabs/props/sandbag_wall.tscn", "SandbagWall", func () -> void:
		gb._sandbag_wall(Vector3.ZERO, 3.2, 0.0))
	_capture_call(gb, "res://prefabs/props/barrel.tscn", "Barrel", func () -> void:
		gb._barrel(Vector3.ZERO, false))
	_capture_call(gb, "res://prefabs/props/barrel_fuel.tscn", "BarrelFuel", func () -> void:
		gb._barrel(Vector3.ZERO, true))
	_capture_call(gb, "res://prefabs/props/pickup_truck.tscn", "PickupTruck", func () -> void:
		gb._pickup_truck(Vector3.ZERO, 0.0, Color(0.58, 0.19, 0.14), false))
	_capture_call(gb, "res://prefabs/props/pickup_truck_canopy.tscn", "PickupTruckCanopy", func () -> void:
		gb._pickup_truck(Vector3.ZERO, 0.0, Color(0.28, 0.34, 0.23), true))
	_capture_call(gb, "res://prefabs/props/boulder.tscn", "Boulder", func () -> void:
		gb._boulder(Vector3.ZERO, 0.85))
	_capture_call(gb, "res://prefabs/props/jersey_barrier.tscn", "JerseyBarrier", func () -> void:
		gb._jersey_barrier(Vector3.ZERO, 0.0))
	_capture_call(gb, "res://prefabs/props/hay_bale.tscn", "HayBale", func () -> void:
		gb._hay_bale(Vector3.ZERO, 0.0))
	_capture_call(gb, "res://prefabs/props/log_pile.tscn", "LogPile", func () -> void:
		gb._log_pile(Vector3.ZERO, 0.0))
	_capture_call(gb, "res://prefabs/props/patrol_boat.tscn", "PatrolBoat", func () -> void:
		gb._patrol_boat(Vector3.ZERO, 0.0))
	_capture_call(gb, "res://prefabs/foliage/pine_tree.tscn", "PineTree", func () -> void:
		gb._pine_tree(Vector3.ZERO, 1.0))
	_capture_call(gb, "res://prefabs/foliage/bush_cluster.tscn", "BushCluster", func () -> void:
		gb._bush_cluster(Vector3.ZERO, 5, 2.2))
	_capture_call(gb, "res://prefabs/buildings/fence_segment.tscn", "FenceSegment", func () -> void:
		gb._fence_segment(Vector3.ZERO, Vector3(4.0, 3.0, 0.45), Color(0.39, 0.40, 0.37), Color(0.24, 0.25, 0.23)))
	_capture_call(gb, "res://prefabs/buildings/ranch_fence.tscn", "RanchFence", func () -> void:
		gb._ranch_fence(Vector3.ZERO, Vector3(4.0, 1.35, 0.3), Color(0.46, 0.34, 0.21)))
	_capture_call(gb, "res://prefabs/buildings/gate_arch.tscn", "GateArch", func () -> void:
		gb._gate_arch(Vector3.ZERO, Color(0.24, 0.25, 0.23), Color(0.48, 0.24, 0.16)))
	_capture_call(gb, "res://prefabs/buildings/watchtower.tscn", "Watchtower", func () -> void:
		gb._watchtower_at(Vector3.ZERO))
	_capture_call(gb, "res://prefabs/buildings/shack_barracks.tscn", "ShackBarracks", func () -> void:
		gb._hollow_building(Vector3.ZERO, Vector3(9, 3.6, 7), Color(0.44, 0.42, 0.38), Color(0.30, 0.25, 0.20), "S"))
	_capture_call(gb, "res://prefabs/buildings/shack_armory.tscn", "ShackArmory", func () -> void:
		gb._hollow_building(Vector3.ZERO, Vector3(7, 3.4, 9), Color(0.42, 0.39, 0.35), Color(0.28, 0.30, 0.28), "W"))
	_capture_call(gb, "res://prefabs/buildings/hq_multistorey.tscn", "HqMultistorey", func () -> void:
		BuildingKit.build_multi_storey(gb, Vector3.ZERO, 11.0, 7.6, 3.3, Color(0.38, 0.41, 0.43), Color(0.26, 0.24, 0.22), "S", true, "E")
		gb._radio_mast(Vector3(3.2, 6.75, -0.5)))
	_capture_call(gb, "res://prefabs/buildings/garage.tscn", "Garage", func () -> void:
		BuildingKit.build_garage(gb, Vector3.ZERO, 8.6, 6.0, 3.3, Color(0.40, 0.38, 0.34), Color(0.32, 0.22, 0.18), "N"))
	_capture_call(gb, "res://prefabs/buildings/floodlight.tscn", "Floodlight", func () -> void:
		gb._compound_floodlight(Vector3.ZERO))
	_capture_call(gb, "res://prefabs/buildings/light_pole.tscn", "LightPole", func () -> void:
		gb._yard_light_pole(Vector3.ZERO))
	_capture_call(gb, "res://prefabs/buildings/grain_silo.tscn", "GrainSilo", func () -> void:
		gb._grain_silo(Vector3.ZERO, 2.5, 8.5))
	_capture_call(gb, "res://prefabs/buildings/windmill.tscn", "Windmill", func () -> void:
		gb._windmill(Vector3.ZERO))
	_capture_call(gb, "res://prefabs/buildings/radar_dish.tscn", "RadarDish", func () -> void:
		gb._radar_dish(Vector3.ZERO, 0.0))

	_save_grass_tuft()
	_save_marker("res://prefabs/gameplay/cover_point.tscn", "CoverPoint", "cover_points", Color(0.95, 0.72, 0.15), 0.22, "")
	_save_marker("res://prefabs/gameplay/entrance.tscn", "Entrance", "entrances", Color(0.25, 0.85, 0.45), 0.28, "")
	_save_marker("res://prefabs/gameplay/patrol_point.tscn", "PatrolPoint", "patrol_point", Color(0.35, 0.65, 1.0), 0.16, "")
	_save_spawn_marker()

	# Overlook nest is a prefab made of the prefabs above.
	gb.force_raw = false
	_capture_call(gb, "res://prefabs/buildings/overlook_nest.tscn", "OverlookNest", func () -> void:
		gb._sandbag_wall(Vector3(0, 0, 1.6), 3.6, 0.0)
		gb._sandbag_wall(Vector3(-2.4, 0, 0), 2.8, 90.0)
		gb._crate(Vector3(2.0, 0, 0.2), 0.9, 12.0)
		gb._barrel(Vector3(-1.2, 0, -0.4), false)
		gb._compound_floodlight(Vector3(0.2, 0.9, -0.2)))

	for id in OutpostCatalog.all_ids():
		_bake_compound(gb, id)

	print("BAKE_DONE")


static func _capture_call(gb, path: String, root_name: String, build: Callable) -> void:
	_wipe(gb)
	build.call()
	_save_children(gb, path, root_name)
	_wipe(gb)


static func _bake_compound(gb, id: String) -> void:
	_wipe(gb)
	gb.force_raw = false
	gb.lightweight_props = false
	gb.current_outpost_id = id
	gb._path_strips.clear()
	var stages: Array = gb._stage_plan(id)
	for stage in stages:
		var fn: Callable = stage["fn"]
		fn.call()
	gb._stage_ground_tufts()
	_add_guard_markers(gb, id)
	var path := "res://scenes/compounds/%s.tscn" % id
	_save_children(gb, path, "Compound")
	_wipe(gb)
	print("COMPOUND ", id)


static func _add_guard_markers(gb, id: String) -> void:
	var def: Dictionary = OutpostCatalog.get_outpost(id)
	var spawn_ps := load("res://prefabs/gameplay/guard_spawn.tscn") as PackedScene
	var patrol_ps := load("res://prefabs/gameplay/patrol_point.tscn") as PackedScene
	if spawn_ps == null or patrol_ps == null:
		push_error("spawn prefabs missing")
		return
	var specs: Array = def.get("guards", [])
	for i in range(specs.size()):
		var spec: Dictionary = specs[i]
		var spawn := spawn_ps.instantiate() as Marker3D
		spawn.name = "GuardSpawn_%02d" % (i + 1)
		var pos: Vector3 = spec.get("pos", Vector3.ZERO)
		spawn.position = pos
		spawn.rotation_degrees.y = float(spec.get("rot", 0.0))
		spawn.set("role", String(spec.get("role", "patrol")))
		spawn.set("sniper", bool(spec.get("sniper", false)))
		spawn.set("sentry", bool(spec.get("sentry", false)))
		spawn.set("dog_id", String(spec.get("dog_id", "")))
		gb.add_child(spawn)
		var patrol: Array = spec.get("patrol", [])
		for p in patrol:
			if not (p is Vector3):
				continue
			var pt := patrol_ps.instantiate() as Node3D
			pt.name = "PatrolPoint"
			pt.position = (p as Vector3) - pos
			spawn.add_child(pt)


static func _save_grass_tuft() -> void:
	var root := Node3D.new()
	root.name = "GrassTuft"
	Engine.get_main_loop().root.add_child(root)
	var colors := [Color(0.20, 0.40, 0.16), Color(0.26, 0.46, 0.18), Color(0.16, 0.34, 0.13)]
	for i in range(5):
		var mi := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.06, 0.42 + float(i % 3) * 0.08, 0.14)
		mi.mesh = box
		mi.position = Vector3(cos(float(i) * 1.3) * 0.12, box.size.y * 0.5, sin(float(i) * 1.3) * 0.12)
		mi.rotation_degrees.y = float(i) * 36.0
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if GraphicsQuality:
			mi.material_override = GraphicsQuality.make_foliage_material(colors[i % colors.size()])
		mi.add_to_group("foliage_wind", true)
		root.add_child(mi)
	_claim(root, root)
	_write_scene(root, "res://prefabs/foliage/grass_tuft.tscn")
	root.free()


static func _save_spawn_marker() -> void:
	var root := Marker3D.new()
	root.name = "GuardSpawn"
	root.set_script(load("res://scripts/levels/guard_spawn_marker.gd"))
	root.add_to_group("guard_spawn", true)
	Engine.get_main_loop().root.add_child(root)
	_add_gizmo(root, Color(0.95, 0.35, 0.25), 0.28, 1.0)
	_claim(root, root)
	_write_scene(root, "res://prefabs/gameplay/guard_spawn.tscn")
	root.free()


static func _save_marker(path: String, root_name: String, group_name: String, color: Color, radius: float, _unused: String) -> void:
	var root := Marker3D.new()
	root.name = root_name
	Engine.get_main_loop().root.add_child(root)
	if group_name != "":
		root.add_to_group(group_name, true)
	_add_gizmo(root, color, radius, 0.45)
	_claim(root, root)
	_write_scene(root, path)
	root.free()


static func _add_gizmo(parent: Node3D, color: Color, radius: float, y: float) -> void:
	var gizmo := MeshInstance3D.new()
	gizmo.name = "EditorGizmo"
	var sphere := SphereMesh.new()
	sphere.radius = radius
	sphere.height = radius * 2.0
	gizmo.mesh = sphere
	gizmo.position = Vector3(0, y, 0)
	gizmo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	gizmo.add_to_group("editor_gizmo", true)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	gizmo.material_override = mat
	parent.add_child(gizmo)


static func _save_children(gb: Node, path: String, root_name: String) -> void:
	var root := Node3D.new()
	root.name = root_name
	Engine.get_main_loop().root.add_child(root)
	var kids: Array[Node] = []
	for c in gb.get_children():
		kids.append(c)
	for c in kids:
		var keep_pos := Vector3.ZERO
		var keep_rot := Vector3.ZERO
		var keep_scale := Vector3.ONE
		if c is Node3D:
			keep_pos = (c as Node3D).position
			keep_rot = (c as Node3D).rotation
			keep_scale = (c as Node3D).scale
		gb.remove_child(c)
		root.add_child(c)
		if c is Node3D:
			(c as Node3D).position = keep_pos
			(c as Node3D).rotation = keep_rot
			(c as Node3D).scale = keep_scale
	_claim(root, root)
	_write_scene(root, path)
	root.free()


static func _claim(node: Node, pack_root: Node) -> void:
	for c in node.get_children():
		c.owner = pack_root
		if c.scene_file_path.is_empty():
			# Unique node: every descendant is owned by the scene we are saving.
			_claim(c, pack_root)
		else:
			# Instanced prefab. Keep its internal nodes owned by the instance,
			# but any child added afterwards (patrol points on a spawn) must be saved.
			_claim_instance_extras(c, pack_root)


static func _claim_instance_extras(inst: Node, pack_root: Node) -> void:
	for c in inst.get_children():
		if c.owner == inst:
			continue
		c.owner = pack_root
		if c.scene_file_path.is_empty():
			_claim(c, pack_root)
		else:
			_claim_instance_extras(c, pack_root)


static func _write_scene(root: Node, path: String) -> void:
	var abs_dir := ProjectSettings.globalize_path(path.get_base_dir())
	DirAccess.make_dir_recursive_absolute(abs_dir)
	var packed := PackedScene.new()
	var err := packed.pack(root)
	if err != OK:
		push_error("pack failed %s err=%s" % [path, err])
		return
	err = ResourceSaver.save(packed, path)
	if err != OK:
		push_error("save failed %s err=%s" % [path, err])
	else:
		print("SAVED ", path)


static func _wipe(gb: Node) -> void:
	var kids: Array[Node] = []
	for c in gb.get_children():
		kids.append(c)
	for c in kids:
		gb.remove_child(c)
		c.free()
