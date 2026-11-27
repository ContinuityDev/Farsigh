extends Node3D
class_name SecurityProps
## Lightweight layered defences for hard compounds: cameras, searchlights, tripwires.
## Designed for mobile — few meshes, simple Area3D triggers, no heavy shaders.


static func spawn_all(parent: Node3D, def: Dictionary) -> void:
	var root := Node3D.new()
	root.name = "SecurityProps"
	parent.add_child(root)
	for pos in def.get("cameras", []):
		if pos is Vector3:
			_spawn_camera(root, pos as Vector3)
	for pos in def.get("searchlights", []):
		if pos is Vector3:
			_spawn_searchlight(root, pos as Vector3)
	for pos in def.get("tripwires", []):
		if pos is Vector3:
			_spawn_tripwire(root, pos as Vector3)
	for pos in def.get("keycard_doors", []):
		if pos is Vector3:
			_spawn_keycard_door(root, pos as Vector3)


static func _spawn_camera(parent: Node3D, pos: Vector3) -> void:
	var n := Area3D.new()
	n.name = "SecurityCamera"
	n.add_to_group("security_cameras")
	n.add_to_group("taggable")
	n.collision_layer = 32
	n.collision_mask = 2  # player
	n.monitoring = true
	n.monitorable = true
	parent.add_child(n)
	n.global_position = pos + Vector3(0, 2.4, 0)
	var cs := CollisionShape3D.new()
	var sph := SphereShape3D.new()
	sph.radius = 9.0
	cs.shape = sph
	n.add_child(cs)
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.35, 0.25, 0.45)
	mesh.mesh = box
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.15, 0.15, 0.18)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh.material_override = mat
	n.add_child(mesh)
	var lens := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.08
	sphere.height = 0.16
	lens.mesh = sphere
	var lmat := StandardMaterial3D.new()
	lmat.albedo_color = Color(0.7, 0.1, 0.1)
	lmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	lens.material_override = lmat
	lens.position = Vector3(0, 0, -0.25)
	n.add_child(lens)
	var lbl := Label3D.new()
	lbl.text = "CAM"
	lbl.font_size = 28
	lbl.position = Vector3(0, 0.45, 0)
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	n.add_child(lbl)
	n.body_entered.connect(func(body: Node):
		if body.is_in_group("player") and not GameState.is_detection_frozen():
			NoiseBus.emit_noise(n.global_position, 28.0, "camera")
			if GameState.run_stats:
				GameState.run_stats.on_spotted()
			var hud := parent.get_tree().get_first_node_in_group("hud")
			if hud and hud.has_method("show_status"):
				hud.show_status("Camera spotted you!", 2.0)
	)


static func _spawn_searchlight(parent: Node3D, pos: Vector3) -> void:
	var n := Node3D.new()
	n.name = "Searchlight"
	parent.add_child(n)
	n.global_position = pos + Vector3(0, 4.5, 0)
	var mesh := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.2
	cyl.bottom_radius = 0.35
	cyl.height = 0.5
	mesh.mesh = cyl
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.55, 0.55, 0.35)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh.material_override = mat
	n.add_child(mesh)
	var area := Area3D.new()
	area.collision_layer = 0
	area.collision_mask = 2
	area.monitoring = true
	n.add_child(area)
	var cs := CollisionShape3D.new()
	var sph := SphereShape3D.new()
	sph.radius = 7.5
	cs.shape = sph
	cs.position = Vector3(0, -3.5, 0)
	area.add_child(cs)
	var sweep := 0.0
	area.set_meta("sweep", 0.0)
	area.body_entered.connect(func(body: Node):
		if body.is_in_group("player") and not GameState.is_detection_frozen():
			NoiseBus.emit_noise(n.global_position, 36.0, "searchlight")
			if GameState.run_stats:
				GameState.run_stats.on_spotted()
			var hud := parent.get_tree().get_first_node_in_group("hud")
			if hud and hud.has_method("show_status"):
				hud.show_status("Searchlight!", 1.8)
	)
	# Slow yaw sweep via process on a tiny script-free tween substitute
	n.set_script(load("res://scripts/systems/searchlight_spin.gd"))


static func _spawn_tripwire(parent: Node3D, pos: Vector3) -> void:
	var n := Area3D.new()
	n.name = "Tripwire"
	n.collision_layer = 0
	n.collision_mask = 2
	n.monitoring = true
	parent.add_child(n)
	n.global_position = pos + Vector3(0, 0.45, 0)
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(4.5, 0.9, 0.35)
	cs.shape = box
	n.add_child(cs)
	var mesh := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(4.5, 0.04, 0.04)
	mesh.mesh = bm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.85, 0.15, 0.12)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh.material_override = mat
	n.add_child(mesh)
	n.body_entered.connect(func(body: Node):
		if body.is_in_group("player") and not GameState.is_detection_frozen():
			NoiseBus.emit_noise(n.global_position, 55.0, "tripwire")
			if GameState.run_stats:
				GameState.run_stats.on_alarm()
			# Trigger nearest alarm if any
			for a in parent.get_tree().get_nodes_in_group("alarms"):
				if a.has_method("trigger"):
					a.trigger()
					break
			var hud := parent.get_tree().get_first_node_in_group("hud")
			if hud and hud.has_method("show_status"):
				hud.show_status("Tripwire! Alarms!", 2.5)
			n.queue_free()
	)


static func _spawn_keycard_door(parent: Node3D, pos: Vector3) -> void:
	var n := StaticBody3D.new()
	n.name = "KeycardDoor"
	n.add_to_group("keycard_doors")
	parent.add_child(n)
	n.global_position = pos + Vector3(0, 1.2, 0)
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(2.2, 2.4, 0.25)
	cs.shape = box
	n.add_child(cs)
	var mesh := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(2.2, 2.4, 0.25)
	mesh.mesh = bm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.28, 0.32, 0.38)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh.material_override = mat
	n.add_child(mesh)
	var lbl := Label3D.new()
	lbl.text = "KEYCARD"
	lbl.font_size = 32
	lbl.position = Vector3(0, 0.2, 0.2)
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	n.add_child(lbl)
