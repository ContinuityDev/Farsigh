extends Node
## Boot helper: AUTO_CAPTURE=1 captures showcase screenshots into docs/screenshots/
## covering Map Select, Gunsmith Workbench, all new Far Cry 5–inspired outposts,
## multi-storey interiors, customized weapons/mods, animations, and touch controls.


func _ready() -> void:
	if OS.get_environment("WHEEL_SNAP") == "1":
		process_mode = Node.PROCESS_MODE_ALWAYS
		await _snap_wheels_only()
		return
	if OS.get_environment("HAYDEN_SNAP") == "1":
		process_mode = Node.PROCESS_MODE_ALWAYS
		await _snap_controls_and_bushes()
		return
	if OS.get_environment("HAYDEN_SNAP2") == "1":
		process_mode = Node.PROCESS_MODE_ALWAYS
		await _snap_batch2()
		return
	if OS.get_environment("AUTO_CAPTURE") != "1":
		return
	process_mode = Node.PROCESS_MODE_ALWAYS
	await get_tree().process_frame
	await get_tree().create_timer(0.8).timeout

	# Prepare a rich sample campaign state (1 liberated outpost + modded arsenal)
	SaveManager.clear_save()
	GameState.start_new_run()
	GameState.mark_liberated("ranch_redbarn")
	GameState.mark_liberated("compound_alpha")
	GameState.mark_liberated("lumber_mill")
	GameState.mark_liberated("river_dock")
	GameState.add_currency(2500)
	GameState.try_purchase("streak_recon")
	GameState.try_purchase("streak_mortar")
	GameState.try_purchase("mod_pack")
	GameState.try_purchase("skin_pack")
	GameState.try_purchase("ally_sniper")
	GameState.try_purchase("smoke")
	GameState.try_purchase("lure")
	GameState.try_purchase("armour_t1")
	GameState.set_equipped_streak(0, "recon_drone")
	GameState.set_equipped_streak(1, "mortar")
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

	# 1. Outpost / Map Select — difficulty tiers + hard compounds
	get_tree().change_scene_to_file("res://scenes/ui/map_select.tscn")
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().create_timer(0.7).timeout
	await _snap("01_map_select")

	# 1b. Shop / Armory with support charges
	get_tree().change_scene_to_file("res://scenes/ui/shop.tscn")
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().create_timer(0.7).timeout
	await _snap("01b_shop_armory")

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
			GameState.assign_carried_to_slot(0, GameState.WeaponId.BOW)
			wm.refresh_slot_from_loadout(0)
			wm.select_slot(0)
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
			wm.set_lethal(GameState.WeaponId.MOLOTOV)
			wm.select_slot(0)
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
			wm.select_slot(0)
	await get_tree().create_timer(0.45).timeout
	await _snap("08_touch_controls")

	# 9. ADS sight gallery — iron / red_dot / holo (must not be a black wall)
	TouchInput.force_touch_ui = false
	if is_instance_valid(hud):
		var tc = hud.get_node_or_null("TouchControls")
		if is_instance_valid(tc):
			tc.visible = false
	GameState.select_outpost("compound_alpha")
	for optic_pair in [["iron", "17_ads_iron"], ["red_dot", "12_ads_red_dot"], ["holo", "09_ads_holo"]]:
		GameState.set_weapon_mod(GameState.WeaponId.RIFLE, "optic", String(optic_pair[0]))
		GameState.set_full_loadout(
			GameState.WeaponId.RIFLE,
			GameState.WeaponId.PISTOL,
			GameState.WeaponId.BOW,
			GameState.WeaponId.MOLOTOV,
			GameState.WeaponId.MACHETE
		)
		GameState.begin_world_load()
		get_tree().change_scene_to_file("res://scenes/levels/outpost.tscn")
		await GameState.wait_world_ready(60.0)
		await get_tree().create_timer(0.45).timeout
		var oroot := get_tree().current_scene
		if is_instance_valid(oroot):
			var lo := oroot.get_node_or_null("LoadingOverlay")
			if is_instance_valid(lo):
				lo.visible = false
		player = get_tree().get_first_node_in_group("player") as Node3D
		if is_instance_valid(player):
			player.global_position = Vector3(2.0, 0.2, 18.0)
			player.rotation = Vector3.ZERO
			if player.get("head") is Node3D:
				(player.get("head") as Node3D).rotation = Vector3.ZERO
			var to := Vector3(0.0, 1.6, -8.0) - player.global_position
			player.rotation.y = atan2(-to.x, -to.z)
			var wm = player.get_node_or_null("WeaponManager")
			if is_instance_valid(wm):
				wm.select_slot(0)
			TouchInput.press("aim")
			await get_tree().create_timer(0.8).timeout
		await _snap(String(optic_pair[1]))
		TouchInput.release("aim")
		await get_tree().create_timer(0.15).timeout

	# 9c. Sniper ADS 4x (default) then 8x
	GameState.set_full_loadout(
		GameState.WeaponId.SNIPER,
		GameState.WeaponId.PISTOL,
		GameState.WeaponId.BOW,
		GameState.WeaponId.MOLOTOV,
		GameState.WeaponId.MACHETE
	)
	GameState.set_weapon_mod(GameState.WeaponId.SNIPER, "optic", "scope")
	get_tree().change_scene_to_file("res://scenes/levels/outpost.tscn")
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().create_timer(0.9).timeout
	player = get_tree().get_first_node_in_group("player") as Node3D
	if is_instance_valid(player):
		player.global_position = Vector3(2.0, 1.0, 22.0)
		player.look_at(Vector3(0.0, 1.6, -12.0), Vector3.UP)
		var wm_s = player.get_node_or_null("WeaponManager")
		if is_instance_valid(wm_s):
			wm_s.select_slot(0)
			wm_s.scope_zoom_step = 0
		TouchInput.press("aim")
		await get_tree().create_timer(0.85).timeout
	await _snap("13_sniper_4x")
	if is_instance_valid(player):
		var wm_s2 = player.get_node_or_null("WeaponManager")
		if is_instance_valid(wm_s2):
			wm_s2.scope_zoom_step = 2  # 8x
		await get_tree().create_timer(0.55).timeout
	await _snap("14_sniper_8x")
	TouchInput.release("aim")

	# 9d. Mobile HUD — decluttered (no takedown) vs takedown available
	TouchInput.force_touch_ui = true
	GameState.set_full_loadout(
		GameState.WeaponId.RIFLE,
		GameState.WeaponId.PISTOL,
		GameState.WeaponId.BOW,
		GameState.WeaponId.MOLOTOV,
		GameState.WeaponId.MACHETE
	)
	GameState.begin_world_load()
	get_tree().change_scene_to_file("res://scenes/levels/outpost.tscn")
	await GameState.wait_world_ready(60.0)
	await get_tree().create_timer(0.6).timeout
	# Dismiss any leftover loading overlay so HUD buttons read clearly
	var outpost_root := get_tree().current_scene
	if is_instance_valid(outpost_root):
		var loader := outpost_root.get_node_or_null("LoadingOverlay")
		if is_instance_valid(loader):
			loader.visible = false
	player = get_tree().get_first_node_in_group("player") as Node3D
	hud = get_tree().get_first_node_in_group("hud")
	if is_instance_valid(hud):
		var tc2 = hud.get_node_or_null("TouchControls")
		if is_instance_valid(tc2):
			tc2.visible = true
			var root_c2 = tc2.get_node_or_null("Root")
			if is_instance_valid(root_c2):
				root_c2.visible = true
	if is_instance_valid(player):
		# Far from enemies — no takedown button; no rocks → no ROCK
		player.global_position = Vector3(0.0, 0.2, 40.0)
		player.rotation = Vector3(0, PI, 0)
		if player.get("head") is Node3D:
			(player.get("head") as Node3D).rotation = Vector3.ZERO
		player.set("rock_count", 0)
		player.set("is_aiming", false)
	await get_tree().create_timer(0.35).timeout
	if is_instance_valid(hud):
		var tc3 = hud.get_node_or_null("TouchControls")
		if is_instance_valid(tc3) and tc3.has_method("_update_contextual_buttons"):
			tc3._update_contextual_buttons()
	await get_tree().process_frame
	await _snap("15_mobile_hud_no_takedown")

	# Place a nearby guard on the camera ray so can_takedown lights up TAKEDOWN
	var guard := get_tree().get_first_node_in_group("guards") as Node3D
	if is_instance_valid(player) and is_instance_valid(guard):
		var cam: Camera3D = player.get_node_or_null("Head/Camera3D") as Camera3D
		var forward := Vector3(0, 0, -1)
		if is_instance_valid(cam):
			forward = -cam.global_transform.basis.z
		else:
			forward = -player.global_transform.basis.z
		guard.global_position = player.global_position + forward * 1.7
		guard.global_position.y = player.global_position.y
		# Face player body toward guard; keep head pitch level for the melee ray
		var to_g := guard.global_position - player.global_position
		player.rotation.y = atan2(-to_g.x, -to_g.z)
		if player.get("head") is Node3D:
			(player.get("head") as Node3D).rotation.x = 0.0
	await get_tree().physics_frame
	await get_tree().physics_frame
	await get_tree().create_timer(0.25).timeout
	if is_instance_valid(hud):
		var tc4 = hud.get_node_or_null("TouchControls")
		if is_instance_valid(tc4) and tc4.has_method("_update_contextual_buttons"):
			tc4._update_contextual_buttons()
			# Ensure MeleeBtn is on-screen if can_takedown succeeded
			var melee := tc4.get_node_or_null("Root/MeleeBtn") as Control
			var wm_td = player.get_node_or_null("WeaponManager") if is_instance_valid(player) else null
			if is_instance_valid(melee) and is_instance_valid(wm_td) and wm_td.has_method("can_takedown"):
				print("AUTO_CAPTURE takedown_ready=", wm_td.can_takedown(player), " melee_vis=", melee.visible)
	await _snap("16_mobile_hud_takedown")
	TouchInput.force_touch_ui = false

	# 10. Hard compound — Eden's Gate Fortress with layered defences
	GameState.select_outpost("eden_fortress")
	GameState.begin_world_load()
	get_tree().change_scene_to_file("res://scenes/levels/outpost.tscn")
	await GameState.wait_world_ready(60.0)
	await get_tree().create_timer(0.6).timeout
	player = get_tree().get_first_node_in_group("player") as Node3D
	if is_instance_valid(player):
		player.global_position = Vector3(0.0, 1.5, 28.0)
		player.look_at(Vector3(0.0, 2.0, -8.0), Vector3.UP)
	await get_tree().create_timer(0.35).timeout
	await _snap("10_eden_fortress")

	# 11. Binoculars tagging overlay (force tags so the shot shows markers)
	var bino := get_tree().get_first_node_in_group("binoculars")
	if bino and bino.has_method("toggle"):
		bino.toggle()
		await get_tree().create_timer(0.35).timeout
		if bino.has_method("force_tag_visible_guards"):
			bino.force_tag_visible_guards()
		await get_tree().create_timer(0.35).timeout
	await _snap("11_binoculars_tagging")
	if bino and bino.has_method("toggle") and bool(bino.get("active")):
		bino.toggle()

	# 12. Weapon wheel (TAB radial) + Gadgets/Lethals HUD
	GameState.select_outpost("compound_alpha")
	GameState.begin_world_load()
	get_tree().change_scene_to_file("res://scenes/levels/outpost.tscn")
	await GameState.wait_world_ready(60.0)
	await get_tree().create_timer(0.5).timeout
	player = get_tree().get_first_node_in_group("player") as Node3D
	hud = get_tree().get_first_node_in_group("hud")
	if is_instance_valid(player):
		player.global_position = Vector3(0.0, 0.15, 34.0)
		player.look_at(Vector3(0.0, 1.5, 0.0), Vector3.UP)
	if is_instance_valid(hud):
		if hud.has_method("refresh_gadget_lethal_hud"):
			hud.refresh_gadget_lethal_hud()
		if hud.has_method("refresh_vitals"):
			hud.refresh_vitals()
		await get_tree().create_timer(0.25).timeout
		await _snap("18_gadgets_lethals_hud")
		if hud.has_method("open_weapon_wheel"):
			hud.open_weapon_wheel(0)
			await get_tree().create_timer(0.4).timeout
			await _snap("19_weapon_wheel")
			if hud.has_method("close_weapon_wheel"):
				hud.close_weapon_wheel(false)
		if hud.has_method("open_lethal_wheel"):
			hud.open_lethal_wheel()
			await get_tree().create_timer(0.35).timeout
			await _snap("26_lethal_mini_wheel")
			if hud.has_method("close_item_wheel"):
				hud.close_item_wheel(false)

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


func _snap_controls_and_bushes() -> void:
	## Controls settings UI + leafy bush clusters (after redo).
	await get_tree().process_frame
	await get_tree().create_timer(0.35).timeout
	SaveManager.clear_save()
	GameState.start_new_run()
	GameState.add_currency(500)
	GameState.select_outpost("compound_alpha")
	# Controls page from main menu
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().create_timer(0.4).timeout
	var menu := get_tree().current_scene
	if is_instance_valid(menu) and menu.has_method("_on_controls_from_menu"):
		menu._on_controls_from_menu()
	elif is_instance_valid(menu):
		var panel = load("res://scripts/ui/controls_settings.gd").new()
		panel.name = "ControlsSettings"
		menu.add_child(panel)
	await get_tree().create_timer(0.45).timeout
	# Scroll PC list so Combat binds are visible in the capture
	var ctrl := menu.get_node_or_null("ControlsSettings") if is_instance_valid(menu) else null
	if is_instance_valid(ctrl) and "_pc_scroll" in ctrl:
		await get_tree().process_frame
		(ctrl._pc_scroll as ScrollContainer).scroll_vertical = 160
	await get_tree().create_timer(0.25).timeout
	await _snap("28_controls_settings")
	# Bush clusters at south approach
	GameState.begin_world_load()
	get_tree().change_scene_to_file("res://scenes/levels/outpost.tscn")
	await GameState.wait_world_ready(60.0)
	await get_tree().create_timer(0.7).timeout
	var player := get_tree().get_first_node_in_group("player") as Node3D
	if is_instance_valid(player):
		player.global_position = Vector3(-6.0, 0.9, 36.0)
		player.look_at(Vector3(-8.0, 0.6, 32.0), Vector3.UP)
		if player.get("head") is Node3D:
			(player.get("head") as Node3D).rotation.x = deg_to_rad(-12.0)
		player.set("is_crouching", true)
	await get_tree().create_timer(0.4).timeout
	await _snap("29_bush_clusters_after")
	# Ranch entrance cluster for variety
	GameState.select_outpost("ranch_redbarn")
	GameState.begin_world_load()
	get_tree().change_scene_to_file("res://scenes/levels/outpost.tscn")
	await GameState.wait_world_ready(60.0)
	await get_tree().create_timer(0.6).timeout
	player = get_tree().get_first_node_in_group("player") as Node3D
	if is_instance_valid(player):
		player.global_position = Vector3(-8.0, 0.8, 36.0)
		player.look_at(Vector3(-10.0, 0.5, 33.0), Vector3.UP)
		if player.get("head") is Node3D:
			(player.get("head") as Node3D).rotation.x = deg_to_rad(-10.0)
	await get_tree().create_timer(0.35).timeout
	await _snap("30_ranch_bush_clusters")
	# Guard role looks — frame a few hostiles in compound
	GameState.select_outpost("compound_alpha")
	GameState.begin_world_load()
	get_tree().change_scene_to_file("res://scenes/levels/outpost.tscn")
	await GameState.wait_world_ready(60.0)
	await get_tree().create_timer(0.5).timeout
	player = get_tree().get_first_node_in_group("player") as Node3D
	if is_instance_valid(player):
		player.global_position = Vector3(0.0, 1.2, 22.0)
		player.look_at(Vector3(-12.0, 1.4, 10.0), Vector3.UP)
	await get_tree().create_timer(0.35).timeout
	await _snap("31_scaled_compound_guards")
	print("HAYDEN_SNAP complete")
	await get_tree().create_timer(0.15).timeout
	get_tree().quit()


func _snap_batch2() -> void:
	## Natural sets, overlook, iron sights, death frames, day/night, treeline.
	await get_tree().process_frame
	await get_tree().create_timer(0.35).timeout
	SaveManager.clear_save()
	GameState.start_new_run()
	GameState.add_currency(800)
	GameState.set_full_loadout(
		GameState.WeaponId.RIFLE,
		GameState.WeaponId.PISTOL,
		GameState.WeaponId.SMG,
		GameState.WeaponId.FRAG,
		GameState.WeaponId.MACHETE
	)
	# Force iron sights on firearms for ADS verification
	for wid in [GameState.WeaponId.RIFLE, GameState.WeaponId.PISTOL, GameState.WeaponId.SMG, GameState.WeaponId.SHOTGUN, GameState.WeaponId.LMG]:
		GameState.set_weapon_mod(wid, "optic", "iron")
	GameState.day_start_hour = 14.0
	GameState.select_outpost("compound_alpha")
	GameState.begin_world_load()
	get_tree().change_scene_to_file("res://scenes/levels/outpost.tscn")
	await GameState.wait_world_ready(90.0)
	await get_tree().create_timer(0.8).timeout
	var player := get_tree().get_first_node_in_group("player") as Node3D

	# 32 Natural lived-in courtyard
	if is_instance_valid(player):
		player.global_position = Vector3(2.0, 1.0, 18.0)
		player.look_at(Vector3(-4.0, 1.2, 4.0), Vector3.UP)
		if player.get("head") is Node3D:
			(player.get("head") as Node3D).rotation.x = deg_to_rad(-8.0)
	await get_tree().create_timer(0.4).timeout
	await _snap("32_natural_set_courtyard")

	# 33 Overlook house rooftop vantage
	if is_instance_valid(player):
		player.global_position = Vector3(1.0, 7.4, -12.0)
		player.look_at(Vector3(0.0, 1.0, 20.0), Vector3.UP)
		if player.get("head") is Node3D:
			(player.get("head") as Node3D).rotation.x = deg_to_rad(-18.0)
	await get_tree().create_timer(0.4).timeout
	await _snap("33_overlook_house_view")

	# Iron sights ADS per weapon — force full ADS pose + FOV
	var iron_weapons := [
		[GameState.WeaponId.RIFLE, "34_iron_rifle"],
		[GameState.WeaponId.PISTOL, "35_iron_pistol"],
		[GameState.WeaponId.SMG, "36_iron_smg"],
		[GameState.WeaponId.SHOTGUN, "37_iron_shotgun"],
	]
	if is_instance_valid(player):
		player.global_position = Vector3(0.0, 1.0, 30.0)
		player.look_at(Vector3(0.0, 1.2, 0.0), Vector3.UP)
		if player.get("head") is Node3D:
			(player.get("head") as Node3D).rotation.x = 0.0
		player.set("force_ads", true)
		player.set("is_aiming", true)
	var wm = player.get_node_or_null("WeaponManager") if is_instance_valid(player) else null
	for pair in iron_weapons:
		var wid = pair[0]
		var snap_name: String = pair[1]
		GameState.set_weapon_mod(wid, "optic", "iron")
		# Put weapon into primary slot so FOV / HUD match
		GameState.selected_primary = wid
		if is_instance_valid(wm):
			if wm.has_method("refresh_slot_from_loadout"):
				wm.refresh_slot_from_loadout(0)
			wm.select_slot(0)
			if is_instance_valid(wm.viewmodel_rig):
				var vr = wm.viewmodel_rig
				vr.rebuild_weapon(wid, GameState.get_weapon_mods(wid))
				await get_tree().process_frame
				vr.show_weapon(wid, false)
				vr.set_aiming(true, 0.01)
				vr._aim_blend = 1.0
				vr._aim_target = 1.0
		player.set("force_ads", true)
		player.set("is_aiming", true)
		# Let several frames settle ADS pose + FOV
		for _i in range(8):
			await get_tree().process_frame
			if is_instance_valid(wm) and is_instance_valid(wm.viewmodel_rig):
				wm.viewmodel_rig._aim_blend = 1.0
				wm.viewmodel_rig._aim_target = 1.0
		await get_tree().create_timer(0.25).timeout
		await _snap(snap_name)
	if is_instance_valid(player):
		player.set("force_ads", false)

	# Death animation frames — kill a nearby guard with head / body
	if is_instance_valid(player):
		player.set("is_aiming", false)
		player.set("aim_blend", 0.0)
		player.global_position = Vector3(0.0, 1.0, 16.0)
	var guards := get_tree().get_nodes_in_group("guards")
	var g0: Node = null
	for g in guards:
		if is_instance_valid(g) and g.has_method("apply_damage"):
			g0 = g
			break
	if is_instance_valid(g0):
		var gp0: Vector3 = (g0 as Node3D).global_position
		if is_instance_valid(player):
			player.global_position = gp0 + Vector3(1.6, 1.35, 2.2)
			player.look_at(gp0 + Vector3.UP * 1.0, Vector3.UP)
			if player.get("head") is Node3D:
				(player.get("head") as Node3D).rotation.x = deg_to_rad(-12.0)
		g0.apply_damage(9999.0, gp0 + Vector3.UP * 1.7, player, "HEAD")
		await get_tree().create_timer(0.38).timeout
		await _snap("38_death_headshot_frame")
	# Second guard — explosion death
	var g1: Node = null
	for g in get_tree().get_nodes_in_group("guards"):
		if is_instance_valid(g) and g != g0 and g.has_method("is_alive") and g.is_alive():
			g1 = g
			break
	if is_instance_valid(g1):
		var gp1: Vector3 = (g1 as Node3D).global_position
		if is_instance_valid(player):
			player.global_position = gp1 + Vector3(2.2, 1.4, 1.8)
			player.look_at(gp1 + Vector3.UP * 0.6, Vector3.UP)
			if player.get("head") is Node3D:
				(player.get("head") as Node3D).rotation.x = deg_to_rad(-8.0)
		g1.apply_damage(220.0, gp1, player, "BLAST")
		await get_tree().create_timer(0.42).timeout
		await _snap("39_death_explosion_frame")

	# Day vs night
	if DayNightCycle:
		DayNightCycle.set_hour(14.0)
	await get_tree().create_timer(0.3).timeout
	if is_instance_valid(player):
		player.global_position = Vector3(-8.0, 1.5, 28.0)
		player.look_at(Vector3(2.0, 2.0, 0.0), Vector3.UP)
		if player.get("head") is Node3D:
			(player.get("head") as Node3D).rotation.x = deg_to_rad(-10.0)
	await get_tree().create_timer(0.35).timeout
	await _snap("40_day_compound")
	if DayNightCycle:
		DayNightCycle.set_hour(22.5)
		DayNightCycle.bind_to_scene()
	await get_tree().create_timer(0.45).timeout
	await _snap("41_night_compound")

	# Treeline border — look north into the dense pine ring
	if DayNightCycle:
		DayNightCycle.set_hour(14.0)
		DayNightCycle.bind_to_scene()
	if is_instance_valid(player):
		player.global_position = Vector3(0.0, 2.2, 42.0)
		player.look_at(Vector3(8.0, 6.0, 72.0), Vector3.UP)
		if player.get("head") is Node3D:
			(player.get("head") as Node3D).rotation.x = deg_to_rad(-6.0)
	await get_tree().create_timer(0.5).timeout
	await _snap("42_treeline_border")

	print("HAYDEN_SNAP2 complete")
	await get_tree().create_timer(0.15).timeout
	get_tree().quit()


func _snap_wheels_only() -> void:

	await get_tree().process_frame
	await get_tree().create_timer(0.4).timeout
	SaveManager.clear_save()
	GameState.start_new_run()
	GameState.add_currency(2000)
	GameState.try_purchase("mod_pack")
	GameState.try_purchase("skin_pack")
	GameState.try_purchase("armour_t1")
	GameState.try_purchase("smoke")
	GameState.set_full_loadout(
		GameState.WeaponId.RIFLE,
		GameState.WeaponId.PISTOL,
		GameState.WeaponId.BOW,
		GameState.WeaponId.MOLOTOV,
		GameState.WeaponId.MACHETE
	)
	GameState.set_weapon_mod(GameState.WeaponId.RIFLE, "muzzle", "suppressor")
	GameState.set_weapon_mod(GameState.WeaponId.RIFLE, "optic", "holo")
	GameState.select_outpost("compound_alpha")
	GameState.begin_world_load()
	get_tree().change_scene_to_file("res://scenes/levels/outpost.tscn")
	await GameState.wait_world_ready(60.0)
	await get_tree().create_timer(0.6).timeout
	var player := get_tree().get_first_node_in_group("player") as Node3D
	var hud := get_tree().get_first_node_in_group("hud")
	if is_instance_valid(player):
		player.global_position = Vector3(0.0, 0.15, 34.0)
		player.look_at(Vector3(0.0, 1.5, 0.0), Vector3.UP)
	if is_instance_valid(hud):
		if hud.has_method("refresh_gadget_lethal_hud"):
			hud.refresh_gadget_lethal_hud()
		if hud.has_method("refresh_vitals"):
			hud.refresh_vitals()
	await get_tree().create_timer(0.25).timeout
	await _snap("18_gadgets_lethals_hud")
	if is_instance_valid(hud) and hud.has_method("open_weapon_wheel"):
		hud.open_weapon_wheel(0)
		await get_tree().create_timer(0.6, true, false, true).timeout
		await get_tree().process_frame
		await _snap("19_weapon_wheel")
		if hud.has_method("close_weapon_wheel"):
			hud.close_weapon_wheel(false)
		Engine.time_scale = 1.0
	if is_instance_valid(hud) and hud.has_method("open_lethal_wheel"):
		hud.open_lethal_wheel()
		await get_tree().create_timer(0.6, true, false, true).timeout
		await get_tree().process_frame
		await _snap("26_lethal_mini_wheel")
		if hud.has_method("close_item_wheel"):
			hud.close_item_wheel(false)
		Engine.time_scale = 1.0
	print("WHEEL_SNAP complete")
	await get_tree().create_timer(0.15).timeout
	get_tree().quit()
