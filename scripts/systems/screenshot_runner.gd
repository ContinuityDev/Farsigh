extends Node
## Boot helper: AUTO_CAPTURE=1 captures showcase screenshots into docs/screenshots/
## covering Map Select, Gunsmith Workbench, all new Far Cry 5–inspired outposts,
## multi-storey interiors, customized weapons/mods, animations, and touch controls.


func _ready() -> void:
	if OS.get_environment("AUTO_CAPTURE") != "1":
		return
	process_mode = Node.PROCESS_MODE_ALWAYS
	await get_tree().process_frame
	await get_tree().create_timer(0.8).timeout

	# Prepare a rich sample campaign state (1 liberated outpost + modded arsenal)
	SaveManager.clear_save()
	GameState.start_new_run()
	GameState.mark_liberated("ranch_redbarn")
	GameState.set_full_loadout(
		GameState.WeaponId.RIFLE,
		GameState.WeaponId.PISTOL,
		GameState.WeaponId.BOW,
		GameState.WeaponId.MOLOTOV,
		GameState.WeaponId.MACHETE
	)
	GameState.set_weapon_mod(GameState.WeaponId.RIFLE, "muzzle", "suppressor")
	GameState.set_weapon_mod(GameState.WeaponId.RIFLE, "optic", "holo")
	GameState.set_weapon_mod(GameState.WeaponId.RIFLE, "mag", "extended")
	GameState.set_weapon_mod(GameState.WeaponId.RIFLE, "underbarrel", "laser")
	GameState.set_weapon_mod(GameState.WeaponId.RIFLE, "skin", "tan")
	GameState.set_weapon_mod(GameState.WeaponId.BOW, "arrow", "explosive")
	GameState.set_weapon_mod(GameState.WeaponId.BOW, "skin", "crimson")
	GameState.select_outpost("lumber_mill")

	# 1. Outpost / Map Select screen showing liberated status & tactical intel
	get_tree().change_scene_to_file("res://scenes/ui/map_select.tscn")
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().create_timer(0.7).timeout
	await _snap("01_map_select")

	# 2. Gunsmith & Loadout workbench with live 3D weapon preview + mods + stat bars
	get_tree().change_scene_to_file("res://scenes/ui/loadout.tscn")
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().create_timer(0.9).timeout
	await _snap("02_gunsmith_workbench")

	# 3. Seed Family Ranch (2-storey Big Red Barn, twin grain silos, farmhouse, hay bales)
	GameState.outposts["ranch_redbarn"]["status"] = "active"
	GameState.select_outpost("ranch_redbarn")
	get_tree().change_scene_to_file("res://scenes/levels/outpost.tscn")
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().create_timer(1.0).timeout
	var player := get_tree().get_first_node_in_group("player") as Node3D
	if is_instance_valid(player):
		player.global_position = Vector3(-5.0, 2.8, 22.0)
		player.look_at(Vector3(3.0, 2.2, -7.0), Vector3.UP)
	await get_tree().create_timer(0.35).timeout
	await _snap("03_ranch_redbarn")

	# 4. Baron Lumber Mill (2-storey saw hall, log piles, watchtowers, customized rifle w/ laser)
	GameState.select_outpost("lumber_mill")
	get_tree().change_scene_to_file("res://scenes/levels/outpost.tscn")
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().create_timer(1.0).timeout
	player = get_tree().get_first_node_in_group("player") as Node3D
	if is_instance_valid(player):
		player.global_position = Vector3(6.0, 1.8, 21.0)
		player.look_at(Vector3(-1.0, 2.4, -10.0), Vector3.UP)
		var wm = player.get_node_or_null("WeaponManager")
		if is_instance_valid(wm):
			wm.select_slot(2)  # Compound Bow w/ Explosive Warhead arrow
			await get_tree().create_timer(0.35).timeout
	await _snap("04_lumber_mill_bow")

	# 5. Whitetail Bait & Dock (river, wooden pier, patrol boat, 2-storey boathouse, bait shop)
	GameState.select_outpost("river_dock")
	get_tree().change_scene_to_file("res://scenes/levels/outpost.tscn")
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().create_timer(1.0).timeout
	player = get_tree().get_first_node_in_group("player") as Node3D
	if is_instance_valid(player):
		player.global_position = Vector3(-11.0, 4.2, -7.5)
		player.look_at(Vector3(6.0, 0.6, -15.5), Vector3.UP)
		var wm = player.get_node_or_null("WeaponManager")
		if is_instance_valid(wm):
			wm.select_slot(3)  # Molotov Cocktail lit bottle
			await get_tree().create_timer(0.35).timeout
	await _snap("05_river_dock_molotov")

	# 6. Jacob's Ridge Bunker (reinforced concrete bunker, radar dishes, helipad, bunker basement)
	GameState.select_outpost("hilltop_bunker")
	get_tree().change_scene_to_file("res://scenes/levels/outpost.tscn")
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().create_timer(1.0).timeout
	player = get_tree().get_first_node_in_group("player") as Node3D
	if is_instance_valid(player):
		player.global_position = Vector3(8.5, 3.2, 19.0)
		player.look_at(Vector3(0.0, 2.2, -13.0), Vector3.UP)
		var wm = player.get_node_or_null("WeaponManager")
		if is_instance_valid(wm):
			wm.select_slot(0)  # Customized Rifle (Suppressor + Holo + Ext Mag + Laser + Tan)
			await get_tree().create_timer(0.35).timeout
	await _snap("06_hilltop_bunker")

	# 7. Multi-storey HQ interior (stairs, see-through window, open door) + weapon inspect + Touch UI
	GameState.select_outpost("compound_alpha")
	get_tree().change_scene_to_file("res://scenes/levels/outpost.tscn")
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().create_timer(1.0).timeout
	player = get_tree().get_first_node_in_group("player") as Node3D
	if is_instance_valid(player):
		# Stand inside 2nd floor HQ looking through see-through glass window across the compound
		player.global_position = Vector3(-1.2, 3.45, -13.2)
		player.look_at(Vector3(-1.2, 3.2, 8.0), Vector3.UP)
		var wm = player.get_node_or_null("WeaponManager")
		if is_instance_valid(wm) and is_instance_valid(wm.viewmodel_rig):
			wm.select_slot(0)
			wm.viewmodel_rig.play_inspect()
			await get_tree().create_timer(0.55).timeout
	await _snap("07_interior_inspect")

	# 8. Touch Controls UI showing new Peek L/R, Inspect, Vault/Jump, and Takedown buttons
	TouchInput.force_touch_ui = true
	var hud := get_tree().get_first_node_in_group("hud")
	if is_instance_valid(hud):
		var tc = hud.get_node_or_null("TouchControls")
		if is_instance_valid(tc):
			tc.visible = true
			var root_c = tc.get_node_or_null("Root")
			if is_instance_valid(root_c):
				root_c.visible = true
	if is_instance_valid(player):
		player.global_position = Vector3(0.0, 0.15, 22.0)
		player.look_at(Vector3(0.0, 2.0, -10.0), Vector3.UP)
		var wm = player.get_node_or_null("WeaponManager")
		if is_instance_valid(wm):
			wm.select_slot(4)  # Kukri Machete
	await get_tree().create_timer(0.45).timeout
	await _snap("08_touch_controls")

	# 9. Proper ADS with holo sight centered + FOV drop + hidden crosshair
	TouchInput.force_touch_ui = false
	if is_instance_valid(hud):
		var tc = hud.get_node_or_null("TouchControls")
		if is_instance_valid(tc):
			tc.visible = false
	GameState.select_outpost("compound_alpha")
	get_tree().change_scene_to_file("res://scenes/levels/outpost.tscn")
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().create_timer(1.0).timeout
	player = get_tree().get_first_node_in_group("player") as Node3D
	if is_instance_valid(player):
		player.global_position = Vector3(2.0, 0.2, 18.0)
		player.look_at(Vector3(0.0, 1.6, -8.0), Vector3.UP)
		var wm = player.get_node_or_null("WeaponManager")
		if is_instance_valid(wm):
			wm.select_slot(0)  # Holo-modded AR-C
		TouchInput.press("aim")
		await get_tree().create_timer(0.55).timeout
	await _snap("09_ads_holo")
	TouchInput.release("aim")

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
