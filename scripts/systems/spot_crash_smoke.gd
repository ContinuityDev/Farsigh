extends SceneTree
## Smoke: detection → combat → multi-guard fire → player down (one-shot).
## Exit 0 = no crash / no double death. Exit 2 = setup failure. Exit 3 = death race.


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
	var player := root.get_tree().get_first_node_in_group("player")
	var guards := root.get_tree().get_nodes_in_group("guards")
	print("SPOT player=", player, " guards=", guards.size())
	if player == null or guards.is_empty():
		quit(2)
		return

	# Put player in front of first guard while CROUCHED and force full detection/combat
	var g = guards[0]
	player.global_position = g.global_position + (-g.global_transform.basis.z) * 4.0 + Vector3.UP * 0.1
	# Toggle crouch explicitly (tests capsule height + crouch vision + crouch noise path)
	player._crouch_toggled = true
	player._handle_crouch()
	print("SPOT crouched=", player.is_crouching, " head_y=", player.head.position.y)
	g.detection = 1.0
	g._set_state(g.State.COMBAT)
	print("SPOT combat set, multi-guard fire...")

	var down_transitions := 0
	var prev_down := false
	for i in range(40):
		for guard in guards:
			if not is_instance_valid(guard):
				continue
			if guard.has_method("_fire_at"):
				guard._fire_at(player)
			if guard.has_method("_do_combat"):
				guard._do_combat(0.05)
		# Alarm / search transition mid-combat
		if i == 5 and is_instance_valid(g):
			g._alarm_used = false
			g.state = g.State.ALERT
			g._do_search(0.05)
			g._set_state(g.State.COMBAT)
		var now_down: bool = bool(player.get("is_down"))
		if now_down and not prev_down:
			down_transitions += 1
		prev_down = now_down
		await process_frame

	print("SPOT player_hp=", player.get("hp"), " is_down=", player.get("is_down"), " down_transitions=", down_transitions)
	if down_transitions > 1:
		print("SPOT FAIL: player_down raced ", down_transitions, " times")
		quit(3)
		return
	print("SPOT survived combat loop")
	quit(0)
