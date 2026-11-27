extends Node
## Boot helper: AUTO_CAPTURE=1 drives menu → loadout → outpost & weapon/guard showcase shots.


func _ready() -> void:
	if OS.get_environment("AUTO_CAPTURE") != "1":
		return
	process_mode = Node.PROCESS_MODE_ALWAYS
	await get_tree().process_frame
	await get_tree().create_timer(1.2).timeout
	await _snap("01_main_menu")

	GameState.start_new_run()
	GameState.set_loadout(GameState.WeaponId.PISTOL, GameState.WeaponId.KNIFE)
	get_tree().change_scene_to_file("res://scenes/ui/loadout.tscn")
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().create_timer(1.0).timeout
	await _snap("02_loadout")

	get_tree().change_scene_to_file("res://scenes/levels/outpost.tscn")
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().create_timer(1.8).timeout
	# Move just inside the gate so compound, watchtower, pickup, crates, barrels, and guards shine
	var player := get_tree().get_first_node_in_group("player") as Node3D
	if is_instance_valid(player):
		player.global_position = Vector3(0.0, 0.1, 22.5)
	await get_tree().create_timer(0.5).timeout
	await _snap("03_outpost")

	# Showcase Assault Rifle + muzzle flash
	var wm = player.get_node_or_null("WeaponManager") if is_instance_valid(player) else null
	if is_instance_valid(wm) and is_instance_valid(wm.viewmodel_rig):
		wm.primary = WeaponData.make_rifle()
		wm.primary_mag = wm.primary.magazine_size
		wm.active_is_primary = true
		wm._refresh_viewmodel(false)
		wm._emit_ammo()
		wm.viewmodel_rig.play_fire(GameState.WeaponId.RIFLE)
		wm.viewmodel_rig._flash_t = 0.5
		await get_tree().process_frame
		await _snap("05_rifle_muzzle")
		wm.viewmodel_rig._flash_t = 0.01

		# Showcase Hunting Bow with visible nocked arrow + close view of humanoid guard & pickup
		wm.primary = WeaponData.make_bow()
		wm.primary_mag = 1
		wm._refresh_viewmodel(false)
		wm._emit_ammo()
		var guards := get_tree().get_nodes_in_group("guards")
		if not guards.is_empty() and is_instance_valid(guards[0]) and is_instance_valid(player):
			var g := guards[0] as Node3D
			var fwd := -g.global_transform.basis.z
			player.global_position = g.global_position + fwd * 4.2 + Vector3.UP * 0.1
			player.look_at(g.global_position + Vector3.UP * 1.15, Vector3.UP)
		await get_tree().create_timer(0.35).timeout
		await _snap("06_bow_guard")

		# Showcase Throwing Knife + compound overview near watchtower/vehicles
		wm.active_is_primary = false
		wm._refresh_viewmodel(false)
		wm._emit_ammo()
		if is_instance_valid(player):
			player.global_position = Vector3(-4.5, 0.1, -18.5)
			player.look_at(Vector3(-14.5, 2.5, -14.5), Vector3.UP)
		await get_tree().create_timer(0.35).timeout
		await _snap("07_knife_watchtower")

		# Restore pistol for touch controls shot
		wm.primary = WeaponData.make_pistol()
		wm.primary_mag = wm.primary.magazine_size
		wm.active_is_primary = true
		wm._refresh_viewmodel(false)
		wm._emit_ammo()

	# Force touch UI overlay shot for docs (hidden on PC during normal play)
	TouchInput.force_touch_ui = true
	var hud := get_tree().get_first_node_in_group("hud")
	if is_instance_valid(hud):
		var tc = hud.get_node_or_null("TouchControls")
		if is_instance_valid(tc):
			tc.visible = true
			var root_c = tc.get_node_or_null("Root")
			if is_instance_valid(root_c):
				root_c.visible = true
	await get_tree().create_timer(0.5).timeout
	await _snap("04_touch_controls")

	print("AUTO_CAPTURE complete")
	await get_tree().create_timer(0.2).timeout
	get_tree().quit()


func _snap(name: String) -> void:
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var tex := get_viewport().get_texture()
	if tex == null:
		push_warning("No viewport texture for " + name)
		return
	var img := tex.get_image()
	if img == null:
		return
	var docs := ProjectSettings.globalize_path("res://docs/screenshots")
	DirAccess.make_dir_recursive_absolute(docs)
	var path := "%s/%s.png" % [docs, name]
	img.save_png(path)
	print("Saved screenshot ", path, " scene=", str(get_tree().current_scene))
