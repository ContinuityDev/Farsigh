extends SceneTree
## Headless smoke: load outpost, kill all guards, assert liberation + save.


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	await process_frame
	var gs := root.get_node("GameState")
	gs.start_new_run()
	gs.set_loadout(gs.WeaponId.BOW, gs.WeaponId.KNIFE)
	change_scene_to_file("res://scenes/levels/outpost.tscn")
	await process_frame
	await process_frame
	await create_timer(1.2).timeout
	var guards := get_nodes_in_group("guards")
	print("SMOKE guards=", guards.size())
	for g in guards:
		if g.has_method("apply_damage"):
			g.apply_damage(999.0)
	await create_timer(1.0).timeout
	var liberated: bool = gs.is_liberated()
	var save_ok := FileAccess.file_exists("user://outpost_save.json")
	print("SMOKE liberated=", liberated, " save=", save_ok)
	quit(0 if liberated and save_ok else 1)
