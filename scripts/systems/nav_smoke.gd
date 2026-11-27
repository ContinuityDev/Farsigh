extends SceneTree
## Headless smoke test for Feature 2: multi-storey buildings, doors, basements,
## runtime NavMesh baking, and guard pathfinding across floors.


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	await process_frame
	var gs := root.get_node("GameState")
	var sm := root.get_node("SaveManager")
	sm.clear_save()
	gs.start_new_run()

	for oid in ["compound_alpha", "ranch_redbarn", "lumber_mill", "river_dock", "hilltop_bunker"]:
		gs.select_outpost(oid)
		change_scene_to_file("res://scenes/levels/outpost.tscn")
		await process_frame
		await process_frame
		await create_timer(0.45).timeout
		var outpost := get_first_node_in_group("outpost")
		var nav_region := outpost.get_node_or_null("OutpostNavRegion") as NavigationRegion3D
		var poly_count := 0
		if nav_region and nav_region.navigation_mesh:
			poly_count = nav_region.navigation_mesh.get_polygon_count()
		var doors := get_nodes_in_group("doors")
		print("NAV_SMOKE id=%s nav_polys=%d doors=%d" % [oid, poly_count, doors.size()])
		if poly_count < 20 or doors.is_empty():
			print("NAV_SMOKE FAIL on ", oid)
			quit(2)
			return
		# Toggle first door and check state flipped
		var d = doors[0]
		var was_open: bool = bool(d.get("is_open"))
		d.interact(get_first_node_in_group("player"))
		if bool(d.get("is_open")) == was_open:
			print("NAV_SMOKE FAIL door did not toggle on ", oid)
			quit(3)
			return

	print("NAV_SMOKE PASS")
	quit(0)
