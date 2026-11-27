extends SceneTree
## Headless smoke test for Feature 3: new guard & player animations
## (investigate, look_around, radio, alarm_press, front/back takedowns,
## weapon inspect, lean/peek, low-wall vault, and body carry/drag).


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	await process_frame
	var gs := root.get_node("GameState")
	var sm := root.get_node("SaveManager")
	sm.clear_save()
	gs.start_new_run()
	gs.select_outpost("compound_alpha")
	change_scene_to_file("res://scenes/levels/outpost.tscn")
	await process_frame
	await process_frame
	await create_timer(0.45).timeout

	var player := get_first_node_in_group("player")
	var guards := get_nodes_in_group("guards")
	if player == null or guards.size() < 2:
		print("ANIM_SMOKE FAIL missing player/guards")
		quit(2)
		return

	# 1. Verify guard animations exist and play cleanly
	var g0 = guards[0]
	var vis = g0.get_node("Visual")
	for anim_name in ["idle", "walk", "run", "shoot", "hit", "death", "investigate", "look_around", "radio", "alarm_press", "takedown_back", "takedown_front"]:
		if not vis._has_anim(StringName(anim_name)):
			print("ANIM_SMOKE FAIL missing anim: ", anim_name)
			quit(3)
			return
	vis.play_radio()
	await process_frame
	vis.play_alarm_press()
	await process_frame

	# 2. Verify Back Takedown vs Front Takedown detection & animation
	player.global_position = g0.global_position + g0.global_transform.basis.z * 1.3
	var was_behind: bool = g0.melee_takedown(player)
	var g1 = guards[1]
	player.global_position = g1.global_position - g1.global_transform.basis.z * 1.3
	var was_front: bool = not g1.melee_takedown(player)
	print("ANIM_SMOKE takedown_back=", was_behind, " takedown_front=", was_front)
	if not (was_behind and was_front):
		print("ANIM_SMOKE FAIL takedown facing check")
		quit(4)
		return

	# 3. Verify Weapon Inspect, Lean, and Vault trigger cleanly without errors
	player.weapons.viewmodel_rig.play_inspect()
	player.weapons.viewmodel_rig.play_takedown(true)
	var ti := root.get_node("TouchInput")
	ti.press("lean_right")
	for _i in range(6):
		await process_frame
	var lean_x: float = player.head.position.x
	ti.release("lean_right")

	# Position player facing a courtyard sandbag wall (0, 0, 10) and trigger vault
	player.global_position = Vector3(0.0, 0.1, 10.95)
	player.rotation_degrees.y = 0.0
	var vaulted: bool = player._try_start_vault()
	for _i in range(25):
		await process_frame
	print("ANIM_SMOKE lean_x=%.3f vaulted=%s post_vault_y=%.2f" % [lean_x, str(vaulted), player.global_position.y])
	if lean_x <= 0.05 or not vaulted:
		print("ANIM_SMOKE FAIL lean or vault")
		quit(5)
		return

	print("ANIM_SMOKE PASS")
	quit(0)
