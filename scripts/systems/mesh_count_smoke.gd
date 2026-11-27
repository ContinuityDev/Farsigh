extends SceneTree
func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	await process_frame
	var gs := root.get_node("GameState")
	gs.select_outpost("compound_alpha")
	gs.begin_world_load()
	change_scene_to_file("res://scenes/levels/outpost.tscn")
	await gs.wait_world_ready()
	await process_frame
	await process_frame
	await create_timer(1.2).timeout
	var scene := current_scene
	var grey := scene.get_node_or_null("Greybox")
	var player := scene.get_node_or_null("Player")
	var wm = player.get_node_or_null("WeaponManager") if player else null
	var cam = player.get_node_or_null("Head/Camera3D") if player else null
	var vm = cam.get_node_or_null("Viewmodels") if cam else null
	var meshes := 0
	var visible_meshes := 0
	var stack: Array = [scene]
	while not stack.is_empty():
		var n = stack.pop_back()
		if n is MeshInstance3D:
			meshes += 1
			if n.is_visible_in_tree():
				visible_meshes += 1
		for c in n.get_children():
			stack.append(c)
	var vm_vis := 0
	var vm_total := 0
	if vm:
		var st2: Array = [vm]
		while not st2.is_empty():
			var n2 = st2.pop_back()
			if n2 is MeshInstance3D:
				vm_total += 1
				if n2.is_visible_in_tree():
					vm_vis += 1
			for c2 in n2.get_children():
				st2.append(c2)
	print("MESH_COUNT grey_children=", grey.get_child_count() if grey else -1,
		" total_meshes=", meshes, " visible=", visible_meshes,
		" vm_meshes=", vm_total, "/", vm_vis,
		" guards=", get_nodes_in_group("guards").size(),
		" cam_path=", wm.camera_path if wm else "?",
		" vm_rig=", is_instance_valid(wm.viewmodel_rig) if wm else false,
		" player_pos=", player.global_position if player else Vector3.ZERO)
	# Sample a few greybox mesh names
	if grey and grey.get_child_count() > 0:
		print("MESH_COUNT sample=", grey.get_child(0).name, " ", grey.get_child(mini(5, grey.get_child_count()-1)).name)
	quit(0)
