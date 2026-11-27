extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	await process_frame
	var gs := root.get_node("GameState")
	gs.start_new_run()
	gs.set_loadout(gs.WeaponId.PISTOL, gs.WeaponId.KNIFE)
	gs.begin_world_load()
	change_scene_to_file("res://scenes/levels/outpost.tscn")
	await gs.wait_world_ready()
	await process_frame
	await process_frame
	await create_timer(1.0).timeout
	var guards := get_nodes_in_group("guards")
	print("HZ guards=", guards.size())
	if guards.is_empty():
		quit(2)
		return
	var g = guards[0]
	var head = g.get_node("HitZones/Head")
	print("HZ head_zone=", head.zone if head else null)
	# Torso shot should wound, not kill (pistol 34 dmg)
	g.apply_hit_zone(g.get_node("HitZones/Torso"), 34.0, g.global_position + Vector3.UP, null)
	print("HZ after_torso hp=", g.hp, " alive=", g.is_alive())
	# Headshot should kill
	g.apply_hit_zone(g.get_node("HitZones/Head"), 34.0, g.global_position + Vector3.UP * 1.7, null)
	await create_timer(0.3).timeout
	var still = is_instance_valid(g) and g.is_alive()
	print("HZ after_head still_alive=", still)
	quit(0 if not still else 1)
