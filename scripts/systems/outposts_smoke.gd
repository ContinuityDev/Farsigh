extends SceneTree
## Headless smoke test for all 5 Far Cry 5–inspired outposts, Map Select UI,
## per-outpost liberation persistence, and New Run reset.

const OutpostCatalog = preload("res://scripts/levels/outpost_catalog.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	await process_frame
	var gs := root.get_node("GameState")
	var sm := root.get_node("SaveManager")
	sm.clear_save()
	gs.start_new_run()

	# Verify Map Select scene loads without errors
	change_scene_to_file("res://scenes/ui/map_select.tscn")
	await process_frame
	await process_frame

	# Verify all 5 outposts load with expected guard counts and snipers
	for def in OutpostCatalog.get_all():
		var oid: String = def["id"]
		gs.select_outpost(oid)
		change_scene_to_file("res://scenes/levels/outpost.tscn")
		await process_frame
		await process_frame
		await create_timer(0.35).timeout
		var guards := get_nodes_in_group("guards")
		var expected := OutpostCatalog.guard_count(def)
		var snipers := 0
		for g in guards:
			if bool(g.get("is_sniper")):
				snipers += 1
		var expected_snipers := OutpostCatalog.sniper_count(def)
		print("OUTPOST_SMOKE id=%s guards=%d/%d snipers=%d/%d" % [oid, guards.size(), expected, snipers, expected_snipers])
		if guards.size() != expected or snipers != expected_snipers:
			print("OUTPOST_SMOKE FAIL mismatch on ", oid)
			quit(2)
			return

	# Liberate ranch_redbarn only and check per-outpost persistence
	gs.select_outpost("ranch_redbarn")
	change_scene_to_file("res://scenes/levels/outpost.tscn")
	await process_frame
	await process_frame
	await create_timer(0.35).timeout
	for g in get_nodes_in_group("guards"):
		if g.has_method("apply_damage"):
			g.apply_damage(999.0)
	await create_timer(0.35).timeout
	var ranch_lib: bool = gs.is_liberated("ranch_redbarn")
	var dock_lib: bool = gs.is_liberated("river_dock")
	# Reload from disk
	gs.outposts.clear()
	sm.load_game()
	var ranch_reloaded: bool = gs.is_liberated("ranch_redbarn")
	var dock_reloaded: bool = gs.is_liberated("river_dock")
	# Reset on New Run
	sm.clear_save()
	gs.start_new_run()
	var ranch_after_reset: bool = gs.is_liberated("ranch_redbarn")
	print("OUTPOST_SMOKE lib=", ranch_lib, " other=", dock_lib, " reload=", ranch_reloaded, "/", dock_reloaded, " reset=", ranch_after_reset)
	if not (ranch_lib and not dock_lib and ranch_reloaded and not dock_reloaded and not ranch_after_reset):
		print("OUTPOST_SMOKE FAIL persistence check")
		quit(3)
		return
	print("OUTPOST_SMOKE PASS")
	quit(0)
