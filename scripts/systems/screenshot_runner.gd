extends Node
## Boot helper: AUTO_CAPTURE=1 captures showcase screenshots into docs/screenshots/
## covering Map Select, Gunsmith Workbench, all new Far Cry 5–inspired outposts,
## multi-storey interiors, customized weapons/mods, animations, and touch controls.


func _ready() -> void:
	if OS.get_environment("BAKE_COMPOUNDS") == "1":
		await get_tree().process_frame
		load("res://scripts/tools/bake_prefabs.gd").bake(get_tree())
		get_tree().quit()
		return
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
	if OS.get_environment("GFX_SNAP") == "1":
		process_mode = Node.PROCESS_MODE_ALWAYS
		await _snap_graphics_and_ai()
		return
	if OS.get_environment("ASSET_SNAP") == "1":
		process_mode = Node.PROCESS_MODE_ALWAYS
		await _snap_assets()
		return
	if OS.get_environment("OVERLOOK_SNAP") == "1":
		process_mode = Node.PROCESS_MODE_ALWAYS
		await _snap_overlook()
		return
	if OS.get_environment("GUARD_SNAP") == "1":
		process_mode = Node.PROCESS_MODE_ALWAYS
		await _snap_guards()
		return
	if OS.get_environment("SUPPORT_SNAP") == "1":
		process_mode = Node.PROCESS_MODE_ALWAYS
		await _snap_support()
		return
	if OS.get_environment("FC5_SNAP") == "1":
		process_mode = Node.PROCESS_MODE_ALWAYS
		await _snap_fc5()
		return
	if OS.get_environment("CC0_SNAP") == "1":
		process_mode = Node.PROCESS_MODE_ALWAYS
		await _snap_cc0()
		return
	if OS.get_environment("ARMS_SNAP") == "1":
		process_mode = Node.PROCESS_MODE_ALWAYS
		await _snap_arms()
		return
	if _web_wants_arms():
		process_mode = Node.PROCESS_MODE_ALWAYS
		await _web_arms_view()
		return
	if _web_wants_overlook():
		process_mode = Node.PROCESS_MODE_ALWAYS
		await _web_overlook_view()
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


func _snap_cc0() -> void:
	## Close-ups of the clothed guard and each CC0 firearm at the hip and in ADS.
	await get_tree().process_frame
	SaveManager.clear_save()
	GameState.start_new_run()
	GameState.set_graphics_quality(2)
	GameState.set_day_start_hour(15.0)
	GameState.set_full_loadout(GameState.WeaponId.RIFLE, GameState.WeaponId.PISTOL, GameState.WeaponId.SHOTGUN, GameState.WeaponId.FRAG, GameState.WeaponId.MACHETE)
	GameState.select_outpost("compound_alpha")
	GameState.begin_world_load()
	get_tree().change_scene_to_file("res://scenes/levels/outpost.tscn")
	await GameState.wait_world_ready(90.0)
	await get_tree().create_timer(0.6).timeout
	if DayNightCycle:
		DayNightCycle.set_hour(15.0)
	var overlay := get_tree().current_scene.get_node_or_null("LoadingOverlay")
	if is_instance_valid(overlay):
		overlay.visible = false
	for existing in get_tree().get_nodes_in_group("guards"):
		if existing is Node3D:
			(existing as Node3D).visible = false
		existing.set_process(false)
		existing.set_physics_process(false)
	var player := get_tree().get_first_node_in_group("player") as Node3D
	var hud := get_tree().current_scene.get_node_or_null("HUD")
	if is_instance_valid(hud):
		var tc := hud.get_node_or_null("TouchControls")
		if is_instance_valid(tc):
			tc.visible = false
	var packed := load("res://scenes/enemies/guard.tscn") as PackedScene
	var guard := packed.instantiate() as Node3D
	guard.name = "CC0Guard"
	guard.set("role", "patrol")
	guard.position = Vector3(0.0, 0.15, 6.0)
	guard.rotation_degrees = Vector3(0, 0, 0)
	get_tree().current_scene.add_child(guard)
	await get_tree().process_frame
	await get_tree().process_frame
	guard.set_physics_process(false)
	guard.set_process(false)
	var badge := guard.get_node_or_null("StateLabel") as Label3D
	if is_instance_valid(badge):
		badge.visible = false
	var vis := guard.get_node_or_null("Visual")
	if vis and vis.has_method("set_locomotion"):
		vis.set_locomotion(false, false)
	await get_tree().create_timer(0.35).timeout
	# Actor faces -Z, so the camera sits on that side.
	_frame_shot(player, guard.global_position + Vector3(1.05, 1.2, -0.85), guard.global_position + Vector3(-0.02, 1.2, 0.1))
	await _snap("125_guard_idle")
	if vis and vis.has_method("set_locomotion"):
		vis.set_locomotion(true, false)
	await get_tree().create_timer(0.3).timeout
	_frame_shot(player, guard.global_position + Vector3(0.85, 1.25, -1.05), guard.global_position + Vector3(0.0, 1.18, 0.1))
	await _snap("126_guard_patrol")
	if vis and vis.has_method("set_locomotion"):
		vis.set_locomotion(false, true)
	await get_tree().create_timer(0.3).timeout
	_frame_shot(player, guard.global_position + Vector3(1.15, 1.35, -0.75), guard.global_position + Vector3(-0.04, 1.35, 0.15))
	await _snap("127_guard_aim")
	if vis and vis.has_method("play_shoot"):
		vis.play_shoot()
	await get_tree().create_timer(0.12).timeout
	_frame_shot(player, guard.global_position + Vector3(0.65, 1.4, -1.0), guard.global_position + Vector3(-0.02, 1.32, 0.18))
	await _snap("128_guard_shoot")
	# Firearms, from the player's own camera so the viewmodel is in frame.
	if is_instance_valid(hud):
		hud.visible = true
		var tc2 := hud.get_node_or_null("TouchControls")
		if is_instance_valid(tc2):
			tc2.visible = false
	guard.visible = false
	var vm := player.get_node_or_null("Head/Camera3D/Viewmodels")
	if is_instance_valid(vm):
		vm.visible = true
		vm.set_process(true)
	var wm = player.get_node_or_null("WeaponManager")
	var guns := [
		{"id": GameState.WeaponId.RIFLE, "name": "rifle", "optic": "iron"},
		{"id": GameState.WeaponId.RIFLE, "name": "rifle_dot", "optic": "red_dot"},
		{"id": GameState.WeaponId.RIFLE, "name": "rifle_holo", "optic": "holo"},
		{"id": GameState.WeaponId.SMG, "name": "smg", "optic": "iron"},
		{"id": GameState.WeaponId.SHOTGUN, "name": "shotgun", "optic": "iron"},
		{"id": GameState.WeaponId.SNIPER, "name": "sniper", "optic": "scope"},
		{"id": GameState.WeaponId.PISTOL, "name": "pistol", "optic": "iron"},
		{"id": GameState.WeaponId.LMG, "name": "lmg", "optic": "iron"},
	]
	player.global_position = Vector3(2.0, 0.2, 18.0)
	player.rotation = Vector3(0, PI, 0)
	var head := player.get_node_or_null("Head") as Node3D
	if head:
		head.rotation = Vector3.ZERO
	var shot_i := 129
	for spec in guns:
		var wid: GameState.WeaponId = spec["id"]
		GameState.selected_primary = wid
		if is_instance_valid(wm):
			wm.refresh_slot_from_loadout(0)
			if wm.active_slot != 0:
				wm.select_slot(0)
			var mods := {
				"muzzle": "suppressor" if wid == GameState.WeaponId.PISTOL else "none",
				"optic": spec["optic"],
				"mag": "standard",
				"underbarrel": "none",
				"arrow": "standard",
				"skin": "factory",
			}
			wm.viewmodel_rig.rebuild_weapon(wid, mods)
			wm.viewmodel_rig.show_weapon(wid, false)
			wm.viewmodel_rig.set_sprinting(false)
			wm.viewmodel_rig.set_aiming(false)
		await get_tree().create_timer(0.3).timeout
		await _snap("%d_%s_hip" % [shot_i, spec["name"]])
		shot_i += 1
		if is_instance_valid(wm):
			wm.viewmodel_rig.set_aiming(true, 0.2)
		await get_tree().create_timer(0.55).timeout
		await _snap("%d_%s_ads" % [shot_i, spec["name"]])
		shot_i += 1
		if is_instance_valid(wm):
			wm.viewmodel_rig.set_aiming(false, 0.12)
			wm.viewmodel_rig.set_sprinting(true)
		await get_tree().create_timer(0.35).timeout
		await _snap("%d_%s_sprint" % [shot_i, spec["name"]])
		shot_i += 1
		if is_instance_valid(wm):
			wm.viewmodel_rig.set_sprinting(false)
			wm.viewmodel_rig.play_reload(1.1)
		await get_tree().create_timer(0.42).timeout
		await _snap("%d_%s_reload" % [shot_i, spec["name"]])
		shot_i += 1
	print("CC0_SNAP complete")
	get_tree().quit()


func _resize_snap(w: int, h: int) -> void:
	DisplayServer.window_set_size(Vector2i(w, h))
	var win := get_tree().root
	win.size = Vector2i(w, h)
	await get_tree().process_frame
	await get_tree().process_frame


func _snap_arms() -> void:
	## Player-camera shots at the live hip FOV, then ADS FOV, then reload frames.
	await get_tree().process_frame
	await _resize_snap(1024, 576)
	SaveManager.clear_save()
	GameState.start_new_run()
	GameState.set_graphics_quality(2)
	GameState.set_day_start_hour(15.0)
	GameState.set_full_loadout(GameState.WeaponId.RIFLE, GameState.WeaponId.PISTOL, GameState.WeaponId.SHOTGUN, GameState.WeaponId.FRAG, GameState.WeaponId.MACHETE)
	GameState.select_outpost("compound_alpha")
	GameState.begin_world_load()
	get_tree().change_scene_to_file("res://scenes/levels/outpost.tscn")
	await GameState.wait_world_ready(90.0)
	await get_tree().create_timer(0.5).timeout
	if DayNightCycle:
		DayNightCycle.set_hour(15.0)
	var overlay := get_tree().current_scene.get_node_or_null("LoadingOverlay")
	if is_instance_valid(overlay):
		overlay.visible = false
	for existing in get_tree().get_nodes_in_group("guards"):
		if existing is Node3D:
			(existing as Node3D).visible = false
		existing.set_process(false)
		existing.set_physics_process(false)
	var player := get_tree().get_first_node_in_group("player") as Node3D
	var hud := get_tree().current_scene.get_node_or_null("HUD")
	if is_instance_valid(hud):
		var tc := hud.get_node_or_null("TouchControls")
		if is_instance_valid(tc):
			tc.visible = false
	player.global_position = Vector3(2.0, 0.2, 18.0)
	player.rotation = Vector3(0, PI, 0)
	var head := player.get_node_or_null("Head") as Node3D
	if head:
		head.rotation = Vector3.ZERO
	player.set_process(false)
	player.set_physics_process(false)
	var cam := player.get_node_or_null("Head/Camera3D") as Camera3D
	if cam:
		cam.fov = 70.0
	var vm := player.get_node_or_null("Head/Camera3D/Viewmodels")
	var wm = player.get_node_or_null("WeaponManager")
	if is_instance_valid(wm):
		wm.set_process(false)
	if is_instance_valid(vm):
		vm.visible = true
		vm.set_process(true)
	var guns := [
		{"id": GameState.WeaponId.RIFLE, "name": "rifle", "optic": "iron", "aim": 56.0},
		{"id": GameState.WeaponId.SMG, "name": "smg", "optic": "iron", "aim": 52.0},
		{"id": GameState.WeaponId.SHOTGUN, "name": "shotgun", "optic": "iron", "aim": 58.0},
		{"id": GameState.WeaponId.SNIPER, "name": "sniper", "optic": "scope", "aim": 17.5},
		{"id": GameState.WeaponId.PISTOL, "name": "pistol", "optic": "iron", "aim": 54.0},
		{"id": GameState.WeaponId.LMG, "name": "lmg", "optic": "iron", "aim": 54.0},
		{"id": GameState.WeaponId.BOW, "name": "bow", "optic": "iron", "aim": 48.0},
		{"id": GameState.WeaponId.KNIFE, "name": "knife", "optic": "iron", "aim": 58.0},
		{"id": GameState.WeaponId.MACHETE, "name": "machete", "optic": "iron", "aim": 58.0},
		{"id": GameState.WeaponId.BAT, "name": "bat", "optic": "iron", "aim": 58.0},
	]
	var n := 161
	for spec in guns:
		await _arms_show(wm, vm, cam, spec, false)
		await _snap("%d_%s_hip" % [n, spec["name"]])
		n += 1
		if spec["name"] in ["knife", "machete", "bat"]:
			continue
		await _arms_show(wm, vm, cam, spec, true)
		await _snap("%d_%s_ads" % [n, spec["name"]])
		n += 1
	# Reload sequences. Progress is the same clock the ammo refill uses.
	var sequences := [
		{"id": GameState.WeaponId.RIFLE, "name": "rifle_tac", "optic": "iron", "kind": "mag", "empty": false, "frames": [0.18, 0.36, 0.62, 0.88]},
		{"id": GameState.WeaponId.RIFLE, "name": "rifle_empty", "optic": "iron", "kind": "mag", "empty": true, "frames": [0.2, 0.42, 0.66, 0.84]},
		{"id": GameState.WeaponId.PISTOL, "name": "pistol_empty", "optic": "iron", "kind": "mag", "empty": true, "frames": [0.2, 0.42, 0.66, 0.84]},
		{"id": GameState.WeaponId.SMG, "name": "smg_tac", "optic": "iron", "kind": "mag", "empty": false, "frames": [0.2, 0.4, 0.66, 0.9]},
		{"id": GameState.WeaponId.SNIPER, "name": "sniper_empty", "optic": "iron", "kind": "mag", "empty": true, "frames": [0.2, 0.42, 0.66, 0.84]},
		{"id": GameState.WeaponId.LMG, "name": "lmg_tac", "optic": "iron", "kind": "mag", "empty": false, "frames": [0.2, 0.4, 0.66, 0.9]},
		{"id": GameState.WeaponId.SHOTGUN, "name": "shotgun_shell", "optic": "iron", "kind": "shell", "empty": true, "frames": [0.16, 0.4, 0.6, 0.86]},
		{"id": GameState.WeaponId.BOW, "name": "bow_nock", "optic": "iron", "kind": "arrow", "empty": true, "frames": [0.2, 0.5, 0.78, 0.94]},
	]
	for seq in sequences:
		await _arms_show(wm, vm, cam, {"id": seq["id"], "optic": seq["optic"]}, false)
		var fi := 1
		for p in seq["frames"]:
			if is_instance_valid(vm) and vm.has_method("scrub_reload"):
				vm.scrub_reload(float(p), str(seq["kind"]), bool(seq["empty"]))
			await get_tree().process_frame
			await get_tree().process_frame
			await _snap("%d_%s_%d" % [n, seq["name"], fi])
			n += 1
			fi += 1
	# Holster the rifle and draw the pistol, three beats.
	await _arms_show(wm, vm, cam, {"id": GameState.WeaponId.RIFLE, "optic": "iron"}, false)
	if is_instance_valid(vm):
		vm.show_weapon(GameState.WeaponId.PISTOL, true)
	await get_tree().create_timer(0.08).timeout
	await _snap("%d_swap_holster" % n)
	n += 1
	await get_tree().create_timer(0.16).timeout
	await _snap("%d_swap_low" % n)
	n += 1
	await get_tree().create_timer(0.22).timeout
	await _snap("%d_swap_draw" % n)
	n += 1
	# Mobile landscape, same renderer, the rifle and a tactical reload frame.
	await _resize_snap(844, 390)
	await _arms_show(wm, vm, cam, {"id": GameState.WeaponId.RIFLE, "optic": "iron", "aim": 56.0}, false)
	await _snap("%d_mobile_rifle_hip" % n)
	n += 1
	await _arms_show(wm, vm, cam, {"id": GameState.WeaponId.RIFLE, "optic": "iron", "aim": 56.0}, true)
	await _snap("%d_mobile_rifle_ads" % n)
	n += 1
	await _arms_show(wm, vm, cam, {"id": GameState.WeaponId.RIFLE, "optic": "iron"}, false)
	if is_instance_valid(vm) and vm.has_method("scrub_reload"):
		vm.scrub_reload(0.36, "mag", false)
	await get_tree().process_frame
	await _snap("%d_mobile_rifle_reload" % n)
	n += 1
	await _arms_show(wm, vm, cam, {"id": GameState.WeaponId.SHOTGUN, "optic": "iron", "aim": 58.0}, false)
	await _snap("%d_mobile_shotgun_hip" % n)
	n += 1
	await _arms_show(wm, vm, cam, {"id": GameState.WeaponId.PISTOL, "optic": "iron", "aim": 54.0}, false)
	await _snap("%d_mobile_pistol_hip" % n)
	print("ARMS_SNAP complete")
	get_tree().quit()


func _arms_show(wm, vm, cam: Camera3D, spec: Dictionary, ads: bool) -> void:
	var wid: GameState.WeaponId = spec["id"]
	GameState.selected_primary = wid
	if is_instance_valid(wm):
		wm.refresh_slot_from_loadout(0)
		if wm.active_slot != 0:
			wm.select_slot(0)
		var optic := str(spec.get("optic", "iron"))
		wm.viewmodel_rig.rebuild_weapon(wid, {
			"muzzle": "none",
			"optic": optic,
			"mag": "standard",
			"underbarrel": "none",
			"arrow": "standard",
			"skin": "factory",
		})
		wm.viewmodel_rig.show_weapon(wid, false)
		wm.viewmodel_rig.set_sprinting(false)
		wm.viewmodel_rig.set_aiming(ads, 0.05)
	if cam:
		cam.fov = float(spec.get("aim", 70.0)) if ads else 70.0
	await get_tree().create_timer(0.35).timeout


func _web_arms_view() -> void:
	## https://.../?view=arms&gun=rifle&ads=1&reload=0.4  holds one first-person pose.
	await get_tree().process_frame
	var q := _web_search()
	SaveManager.clear_save()
	GameState.start_new_run()
	GameState.set_graphics_quality(0 if "quality=low" in q else 2)
	GameState.set_day_start_hour(15.0)
	GameState.set_full_loadout(GameState.WeaponId.RIFLE, GameState.WeaponId.PISTOL, GameState.WeaponId.SHOTGUN, GameState.WeaponId.FRAG, GameState.WeaponId.MACHETE)
	GameState.select_outpost("compound_alpha")
	GameState.begin_world_load()
	get_tree().change_scene_to_file("res://scenes/levels/outpost.tscn")
	await GameState.wait_world_ready(120.0)
	var player := get_tree().get_first_node_in_group("player") as Node3D
	if player == null:
		return
	player.set_meta("capture_lock", true)
	for existing in get_tree().get_nodes_in_group("guards"):
		if existing is Node3D:
			(existing as Node3D).visible = false
		existing.set_process(false)
		existing.set_physics_process(false)
	await get_tree().create_timer(0.6).timeout
	if DayNightCycle:
		DayNightCycle.set_hour(15.0)
		DayNightCycle.set_process(false)
		DayNightCycle.set_physics_process(false)
	var overlay := get_tree().current_scene.get_node_or_null("LoadingOverlay")
	if is_instance_valid(overlay):
		overlay.visible = false
	player.global_position = Vector3(2.0, 0.2, 18.0)
	player.rotation = Vector3(0, PI, 0)
	var head := player.get_node_or_null("Head") as Node3D
	if head:
		head.rotation = Vector3.ZERO
	var gun := "rifle"
	for part in q.trim_prefix("?").split("&"):
		if part.begins_with("gun="):
			gun = part.trim_prefix("gun=")
	var ids := {
		"rifle": GameState.WeaponId.RIFLE,
		"smg": GameState.WeaponId.SMG,
		"shotgun": GameState.WeaponId.SHOTGUN,
		"sniper": GameState.WeaponId.SNIPER,
		"pistol": GameState.WeaponId.PISTOL,
		"lmg": GameState.WeaponId.LMG,
		"bow": GameState.WeaponId.BOW,
	}
	var wid: GameState.WeaponId = ids.get(gun, GameState.WeaponId.RIFLE)
	var wm = player.get_node_or_null("WeaponManager")
	var vm = player.get_node_or_null("Head/Camera3D/Viewmodels")
	var cam := player.get_node_or_null("Head/Camera3D") as Camera3D
	await _arms_show(wm, vm, cam, {"id": wid, "optic": "scope" if gun == "sniper" else "iron", "aim": 56.0}, "ads=1" in q)
	if "reload=" in q and is_instance_valid(vm) and vm.has_method("scrub_reload"):
		var rp := 0.4
		for part in q.trim_prefix("?").split("&"):
			if part.begins_with("reload="):
				rp = float(part.trim_prefix("reload="))
		var kind := "shell" if gun == "shotgun" else ("arrow" if gun == "bow" else "mag")
		vm.scrub_reload(rp, kind, "empty=1" in q)
	player.set_process(false)
	player.set_physics_process(false)
	print("WEB_ARMS gun=", gun)
	if not OS.has_feature("web"):
		return
	# One page load, then the browser sets window.armsCmd to "gun,ads,reload,empty".
	JavaScriptBridge.eval("window.armsReady=1;window.armsCmd='';window.armsAck='';", true)
	print("WEB_ARMS ready")
	var last := ""
	while is_inside_tree():
		var cmd := str(JavaScriptBridge.eval("String(window.armsCmd||'')", true))
		if cmd != "" and cmd != last:
			last = cmd
			await _apply_web_cmd(wm, vm, cam, cmd)
			JavaScriptBridge.eval("window.armsAck=" + JSON.stringify(cmd) + ";", true)
		await get_tree().process_frame


func _apply_web_cmd(wm, vm, cam: Camera3D, cmd: String) -> void:
	var parts := cmd.split(",")
	var gun := parts[0] if parts.size() > 0 else "rifle"
	var ads := parts.size() > 1 and parts[1] == "1"
	var reload_p := float(parts[2]) if parts.size() > 2 else -1.0
	var empty := parts.size() > 3 and parts[3] == "1"
	var ids := {
		"rifle": GameState.WeaponId.RIFLE,
		"smg": GameState.WeaponId.SMG,
		"shotgun": GameState.WeaponId.SHOTGUN,
		"sniper": GameState.WeaponId.SNIPER,
		"pistol": GameState.WeaponId.PISTOL,
		"lmg": GameState.WeaponId.LMG,
		"bow": GameState.WeaponId.BOW,
		"knife": GameState.WeaponId.KNIFE,
	}
	var aims := {"rifle": 56.0, "smg": 52.0, "shotgun": 58.0, "sniper": 17.5, "pistol": 54.0, "lmg": 54.0, "bow": 48.0, "knife": 58.0}
	var wid: GameState.WeaponId = ids.get(gun, GameState.WeaponId.RIFLE)
	var optic := "scope" if gun == "sniper" and ads else "iron"
	await _arms_show(wm, vm, cam, {"id": wid, "optic": optic, "aim": float(aims.get(gun, 56.0))}, ads)
	if reload_p >= 0.0 and is_instance_valid(vm) and vm.has_method("scrub_reload"):
		var kind := "shell" if gun == "shotgun" else ("arrow" if gun == "bow" else "mag")
		vm.scrub_reload(reload_p, kind, empty)
	await get_tree().process_frame
	await get_tree().process_frame
	print("WEB_ARMS pose ", cmd)


func _snap_fc5() -> void:
	## Player-view shots of the new Hope County station and the redesigned rifle.
	await get_tree().process_frame
	SaveManager.clear_save()
	GameState.start_new_run()
	GameState.set_graphics_quality(2)
	GameState.set_day_start_hour(15.0)
	GameState.set_full_loadout(GameState.WeaponId.RIFLE, GameState.WeaponId.PISTOL, GameState.WeaponId.SHOTGUN, GameState.WeaponId.FRAG, GameState.WeaponId.MACHETE)
	GameState.select_outpost("falls_end")
	GameState.begin_world_load()
	get_tree().change_scene_to_file("res://scenes/levels/outpost.tscn")
	await GameState.wait_world_ready(90.0)
	await get_tree().create_timer(0.8).timeout
	if DayNightCycle:
		DayNightCycle.set_hour(15.0)
	var overlay := get_tree().current_scene.get_node_or_null("LoadingOverlay")
	if is_instance_valid(overlay):
		overlay.visible = false
	var player := get_tree().get_first_node_in_group("player") as Node3D
	var hud := get_tree().current_scene.get_node_or_null("HUD")
	if is_instance_valid(hud):
		var tc := hud.get_node_or_null("TouchControls")
		if is_instance_valid(tc):
			tc.visible = false
	if player == null:
		print("FC5_SNAP missing player")
		get_tree().quit(1)
		return
	player.global_position = Vector3(0.0, 0.2, 36.0)
	player.rotation = Vector3.ZERO
	var head := player.get("head") as Node3D
	if head:
		head.rotation = Vector3.ZERO
	var wm = player.get_node_or_null("WeaponManager")
	if is_instance_valid(wm):
		wm.select_slot(0)
	await get_tree().create_timer(0.6).timeout
	await _snap("95_falls_gate")
	player.global_position = Vector3(-20.0, 1.4, 16.0)
	var to := Vector3(-4.0, 2.0, 0.0) - player.global_position
	player.rotation.y = atan2(-to.x, -to.z)
	await get_tree().create_timer(0.35).timeout
	await _snap("96_falls_overlook")
	player.global_position = Vector3(-2.0, 0.2, 8.0)
	player.rotation.y = atan2(-(-12.0 - player.global_position.x), - (2.0 - player.global_position.z))
	await get_tree().create_timer(0.35).timeout
	await _snap("97_falls_yard")
	player.global_position = Vector3(1.5, 0.2, 10.0)
	to = Vector3(0.0, 4.0, -6.0) - player.global_position
	player.rotation.y = atan2(-to.x, -to.z)
	await get_tree().create_timer(0.35).timeout
	await _snap("98_falls_chapel")
	player.global_position = Vector3(-4.0, 0.2, 8.0)
	to = Vector3(-12.0, 1.4, 2.0) - player.global_position
	player.rotation.y = atan2(-to.x, -to.z)
	await get_tree().create_timer(0.35).timeout
	await _snap("103_falls_alarm")
	# Hip, ADS, and sprint of the rifle, aimed down the haul road.
	player.global_position = Vector3(0.2, 0.2, 30.0)
	player.rotation.y = PI
	if head:
		head.rotation = Vector3.ZERO
	if is_instance_valid(wm) and is_instance_valid(wm.viewmodel_rig):
		wm.viewmodel_rig.set_sprinting(false)
		wm.viewmodel_rig.set_aiming(false)
	await get_tree().create_timer(0.45).timeout
	await _snap("99_rifle_hip")
	TouchInput.press("aim")
	await get_tree().create_timer(0.7).timeout
	await _snap("100_rifle_ads")
	TouchInput.release("aim")
	TouchInput.press("sprint")
	TouchInput.set_move_vector(Vector2(0, -1))
	await get_tree().create_timer(0.45).timeout
	await _snap("101_rifle_sprint")
	TouchInput.release("sprint")
	TouchInput.set_move_vector(Vector2.ZERO)
	if is_instance_valid(wm):
		wm.select_slot(1)
		if is_instance_valid(wm.viewmodel_rig):
			wm.viewmodel_rig.set_aiming(false)
	await get_tree().create_timer(0.45).timeout
	await _snap("102_pistol_hip")
	player.global_position = Vector3(0.0, 0.2, 30.0)
	player.rotation.y = 0.0
	if head:
		head.rotation = Vector3.ZERO
	if is_instance_valid(wm):
		wm.select_slot(0)
	if is_instance_valid(hud) and hud.has_method("set_liberated_banner"):
		hud.set_liberated_banner(true)
	await get_tree().create_timer(0.35).timeout
	await _snap("104_falls_liberated")
	print("FC5_SNAP complete")
	get_tree().quit()


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


func _note_fps(tag: String) -> void:
	var fps := Performance.get_monitor(Performance.TIME_FPS)
	var frame_ms := Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
	print("FPS_NOTE %s fps=%.1f process_ms=%.2f quality=%s" % [tag, fps, frame_ms, GraphicsQuality.level_name() if GraphicsQuality else "?"])


func _web_search() -> String:
	if not OS.has_feature("web"):
		return ""
	var raw = JavaScriptBridge.eval("window.location.search", true)
	return str(raw)


func _web_wants_overlook() -> bool:
	return "view=overlook" in _web_search()


func _web_wants_arms() -> bool:
	return "view=arms" in _web_search()


func _place_overlook(player: Node3D) -> void:
	if not is_instance_valid(player):
		return
	# HQ roof nest, looking south over the yard, the gate, and the treeline.
	player.global_position = Vector3(1.0, 7.05, -11.4)
	player.look_at(Vector3(0.0, 1.3, 22.0), Vector3.UP)


func _hide_viewmodel(player: Node3D) -> void:
	if not is_instance_valid(player):
		return
	player.set_process(false)
	player.set_physics_process(false)
	var weapons := player.get_node_or_null("WeaponManager")
	if is_instance_valid(weapons):
		weapons.set_process(false)
		weapons.set_physics_process(false)
	var vm := player.get_node_or_null("Head/Camera3D/Viewmodels")
	if is_instance_valid(vm):
		vm.set_process(false)
		vm.visible = false


func _frame_shot(player: Node3D, eye: Vector3, focus: Vector3) -> void:
	## Eye height is the camera (Head is 1.65 above the body). Pitch lives on Head.
	if not is_instance_valid(player):
		return
	_hide_viewmodel(player)
	player.global_position = Vector3(eye.x, eye.y - 1.65, eye.z)
	var head := player.get_node_or_null("Head") as Node3D
	if not is_instance_valid(head):
		player.look_at(focus, Vector3.UP)
		return
	head.rotation = Vector3.ZERO
	var flat := Vector3(focus.x, player.global_position.y, focus.z)
	if flat.distance_squared_to(player.global_position) > 0.04:
		player.look_at(flat, Vector3.UP)
	var to := focus - head.global_position
	head.rotation.x = atan2(to.y, Vector2(to.x, to.z).length())


func _snap_support() -> void:
	## Purchased support charges: HUD card, wheel, mobile button, mortar marker, then a real strike.
	await get_tree().process_frame
	SaveManager.clear_save()
	GameState.start_new_run()
	GameState.add_currency(2000)
	GameState.set_graphics_quality(2)
	GameState.set_day_start_hour(14.0)
	var buy_recon := GameState.try_purchase("streak_recon")
	var buy_mortar := GameState.try_purchase("streak_mortar")
	var buy_fangs := GameState.try_purchase("streak_fangs")
	GameState.select_outpost("compound_alpha")
	GameState.begin_world_load()
	get_tree().change_scene_to_file("res://scenes/levels/outpost.tscn")
	await GameState.wait_world_ready(90.0)
	await get_tree().create_timer(0.6).timeout
	if DayNightCycle:
		DayNightCycle.set_hour(14.0)
	var player := get_tree().get_first_node_in_group("player") as Node3D
	var hud := get_tree().get_first_node_in_group("hud")
	var sm := get_tree().get_first_node_in_group("streak_manager")
	GameState.select_streak("mortar")
	if hud and hud.has_method("refresh_streak_buttons"):
		hud.refresh_streak_buttons()
	_frame_shot(player, Vector3(2.0, 2.4, 18.0), Vector3(2.0, 0.2, 10.0))
	await get_tree().create_timer(0.25).timeout
	await _snap("74_support_card")
	var card_text := ""
	if hud:
		var card := hud.get_node_or_null("Root/SupportCard/SupportLabel") as Label
		if card:
			card_text = card.text
	if hud and hud.has_method("open_support_wheel"):
		hud.open_support_wheel()
	await get_tree().process_frame
	await _snap("75_support_wheel")
	if hud and hud.has_method("close_item_wheel"):
		hud.close_item_wheel(false)
	TouchInput.force_touch_ui = true
	await get_tree().create_timer(0.35).timeout
	await _snap("77_support_touch")
	TouchInput.force_touch_ui = false
	GameState.select_streak("mortar")
	var before := GameState.get_streak_charges("mortar")
	var recon_before := GameState.get_streak_charges("recon_drone")
	var recon_ok := false
	if sm and sm.has_method("try_activate_id"):
		recon_ok = bool(sm.try_activate_id("recon_drone"))
	var recon_after := GameState.get_streak_charges("recon_drone")
	if sm and sm.has_method("begin_place"):
		sm.begin_place("mortar")
	await get_tree().process_frame
	await get_tree().process_frame
	var marker := get_tree().current_scene.get_node_or_null("SupportAimMarker") as Node3D
	var marker_was_up := is_instance_valid(marker) and marker.visible
	await _snap("76_mortar_marker")
	var fired := false
	if sm and sm.has_method("confirm_place"):
		fired = bool(sm.confirm_place())
	var after := GameState.get_streak_charges("mortar")
	await get_tree().process_frame
	await _snap("78_mortar_fired")
	var tagged := 0
	for g in get_tree().get_nodes_in_group("guards"):
		if is_instance_valid(g) and bool(g.get("tagged")):
			tagged += 1
	var pass_ok := (
		buy_recon == ""
		and buy_mortar == ""
		and buy_fangs == ""
		and card_text.find("SUPPORT") >= 0
		and card_text.find("×") >= 0
		and recon_ok
		and recon_after == recon_before - 1
		and tagged > 0
		and marker_was_up
		and is_instance_valid(marker)
		and marker.visible == false
		and fired
		and after == before - 1
	)
	print("SUPPORT_SNAP card=", card_text.replace("\n", " | "))
	print("SUPPORT_SNAP recon ", recon_before, "->", recon_after, " tagged=", tagged, " mortar ", before, "->", after, " fired=", fired)
	print("SUPPORT_SNAP ", "PASS" if pass_ok else "FAIL")
	get_tree().quit()


func _snap_militia_closeups(player: Node3D, spawned: Array[Node3D]) -> void:
	## Crouching rifleman, sandbags, and a real bush in the foreground, plus a pose strip.
	for i in range(1, spawned.size()):
		spawned[i].visible = false
	var rifleman := spawned[0]
	rifleman.global_position = Vector3(0.0, 0.15, 6.0)
	rifleman.rotation_degrees = Vector3(0, 180, 0)
	var root := get_tree().current_scene
	var bush_scene := load("res://prefabs/foliage/bush_cluster.tscn") as PackedScene
	if bush_scene:
		var bush_a := bush_scene.instantiate() as Node3D
		bush_a.name = "CloseBush"
		bush_a.position = Vector3(-1.45, 0.0, 7.55)
		bush_a.scale = Vector3(0.8, 0.8, 0.8)
		root.add_child(bush_a)
		var bush_b := bush_scene.instantiate() as Node3D
		bush_b.position = Vector3(1.55, 0.0, 6.15)
		bush_b.scale = Vector3(0.7, 0.7, 0.7)
		root.add_child(bush_b)
	var bags := load("res://prefabs/props/sandbag_wall.tscn") as PackedScene
	if bags:
		var wall := bags.instantiate() as Node3D
		wall.position = Vector3(0.0, 0.0, 7.35)
		wall.rotation_degrees = Vector3(0, 0, 0)
		root.add_child(wall)
	var vis := rifleman.get_node_or_null("Visual")
	var shots := [
		["idle", 0.35],
		["walk", 0.45],
		["alert", 0.4],
		["run", 0.4],
		["crouch", 0.45],
		["aim", 0.35],
		["strafe", 0.4],
		["peek", 0.4],
		["look", 0.45],
		["shoot", 0.18],
		["reload", 0.55],
		["hit", 0.2],
		["death", 1.1],
	]
	var alert := rifleman.get_node_or_null("AlertIcon") as Node3D
	if is_instance_valid(alert):
		alert.visible = false
	var tag := rifleman.get_node_or_null("TagIcon") as Node3D
	if is_instance_valid(tag):
		tag.visible = false
	for meter_name in ["AlertMeterBg", "AlertMeterFill"]:
		var meter := rifleman.get_node_or_null(meter_name) as Node3D
		if is_instance_valid(meter):
			meter.visible = false
	var focus := rifleman.global_position + Vector3(0, 1.15, 0)
	var eye := rifleman.global_position + Vector3(0.75, 1.4, 1.85)
	for spec in shots:
		var pose := String(spec[0])
		if vis and vis.has_method("pose_for_shot"):
			vis.pose_for_shot(pose)
		var origin := rifleman.global_position
		if pose == "death":
			focus = origin + Vector3(0, 0.4, 0)
			eye = origin + Vector3(1.15, 1.15, 1.7)
		elif pose == "crouch" or pose == "peek":
			focus = origin + Vector3(0, 0.75, 0)
			eye = origin + Vector3(0.7, 1.15, 1.75)
		else:
			focus = origin + Vector3(0, 1.15, 0.05)
			eye = origin + Vector3(0.72, 1.38, 1.8)
		_frame_shot(player, eye, focus)
		await get_tree().create_timer(float(spec[1])).timeout
		await _snap("80_rifleman_%s" % pose)
		if pose == "idle" and vis and vis.has_method("hand_debug"):
			print("HAND_AXES ", vis.hand_debug())
	# Bush fill, camera low and close so the leaf volume is the subject.
	_frame_shot(player, Vector3(-2.3, 1.15, 9.35), Vector3(-1.45, 0.6, 7.55))
	await get_tree().create_timer(0.2).timeout
	await _snap("93_bush_closeup")
	if vis and vis.has_method("pose_for_shot"):
		vis.pose_for_shot("aim")
	_frame_shot(player, rifleman.global_position + Vector3(0.28, 1.62, 0.95), rifleman.global_position + Vector3(0, 1.55, 0))
	await get_tree().create_timer(0.25).timeout
	await _snap("80_rifleman_face")
	if vis and vis.has_method("pose_for_shot"):
		vis.pose_for_shot("crouch")
	_frame_shot(player, Vector3(1.15, 1.2, 8.15), rifleman.global_position + Vector3(0, 0.8, 0))
	await get_tree().create_timer(0.35).timeout
	await _snap("94_rifleman_crouch_bush")


func _snap_guards() -> void:
	await get_tree().process_frame
	SaveManager.clear_save()
	GameState.start_new_run()
	GameState.set_graphics_quality(2)
	GameState.set_day_start_hour(14.0)
	GameState.select_outpost("compound_alpha")
	GameState.begin_world_load()
	get_tree().change_scene_to_file("res://scenes/levels/outpost.tscn")
	await GameState.wait_world_ready(90.0)
	await get_tree().create_timer(0.5).timeout
	if DayNightCycle:
		DayNightCycle.set_hour(14.0)
	for existing in get_tree().get_nodes_in_group("guards"):
		if existing is Node3D:
			(existing as Node3D).visible = false
		existing.set_process(false)
		existing.set_physics_process(false)
	var packed := load("res://scenes/enemies/guard.tscn") as PackedScene
	var specs := [
		{"role": "patrol", "label": "rifleman"},
		{"role": "sniper", "sniper": true, "label": "sniper"},
		{"role": "heavy", "heavy": true, "label": "heavy"},
		{"role": "officer", "officer": true, "label": "officer"},
		{"role": "handler", "label": "handler"},
		{"role": "dog", "dog": true, "label": "dog"},
	]
	var spawned: Array[Node3D] = []
	var root := get_tree().current_scene
	for i in range(specs.size()):
		var spec: Dictionary = specs[i]
		var guard := packed.instantiate() as Node3D
		guard.name = "Lineup_" + String(spec["label"])
		guard.set("role", spec["role"])
		guard.set("is_sniper", bool(spec.get("sniper", false)))
		guard.set("is_heavy", bool(spec.get("heavy", false)))
		guard.set("is_officer", bool(spec.get("officer", false)))
		guard.set("is_dog", bool(spec.get("dog", false)))
		guard.position = Vector3(-6.25 + float(i) * 2.5, 0.15, 4.0)
		guard.rotation_degrees = Vector3(0, 180, 0)
		root.add_child(guard)
		spawned.append(guard)
	await get_tree().process_frame
	await get_tree().process_frame
	for guard in spawned:
		guard.set_physics_process(false)
		guard.set_process(false)
		var badge := guard.get_node_or_null("StateLabel") as Label3D
		if is_instance_valid(badge):
			badge.visible = false
		var vis := guard.get_node_or_null("Visual")
		if vis and vis.has_method("play"):
			vis.play(&"idle", 0.0)
	# Question mark and binocular tag sit above the rifleman's head.
	var first := spawned[0]
	first.set("detection", 0.55)
	if first.has_method("set_tagged"):
		first.call("set_tagged", true)
	if first.has_method("_refresh_alert_meter"):
		first.call("_refresh_alert_meter")
	var player := get_tree().get_first_node_in_group("player") as Node3D
	var hud := get_tree().current_scene.get_node_or_null("HUD")
	if is_instance_valid(hud):
		hud.visible = false
	_frame_shot(player, Vector3(0.0, 1.55, 9.2), Vector3(0.0, 1.05, 4.0))
	await get_tree().create_timer(0.35).timeout
	await _snap("60_guards_lineup")
	var shots := ["61_rifleman", "62_sniper", "63_heavy", "64_officer", "65_handler", "66_dog"]
	for i in range(spawned.size()):
		var guard: Node3D = spawned[i]
		var dog := String(specs[i]["role"]) == "dog"
		var focus := guard.global_position + Vector3(0, 0.38 if dog else (1.45 if i == 0 else 1.15), 0)
		var eye := guard.global_position + Vector3(0.35 if dog else -0.62, 0.62 if dog else (1.05 if i == 0 else 1.22), 1.05 if dog else (2.55 if i == 0 else 1.45))
		_frame_shot(player, eye, focus)
		await get_tree().create_timer(0.15).timeout
		await _snap(shots[i])
	# Same rifleman, aim and cover, so the skeletal clips are visible up close.
	var rifleman := spawned[0]
	var rifle_vis := rifleman.get_node_or_null("Visual")
	var focus_r := rifleman.global_position + Vector3(0, 1.05, 0)
	var eye_r := rifleman.global_position + Vector3(-0.7, 1.15, 1.45)
	if rifle_vis and rifle_vis.has_method("play"):
		rifle_vis.play(&"aim", 0.0)
		_frame_shot(player, eye_r, focus_r)
		await get_tree().create_timer(0.12).timeout
		await _snap("67_rifleman_aim")
		rifle_vis.play(&"cover", 0.0)
		_frame_shot(player, eye_r + Vector3(0, -0.15, 0.1), focus_r + Vector3(0, -0.35, 0))
		await get_tree().create_timer(0.12).timeout
		await _snap("68_rifleman_cover")
	await _snap_militia_closeups(player, spawned)
	print("GUARD_SNAP complete")
	get_tree().quit()


func _snap_overlook() -> void:
	await get_tree().process_frame
	SaveManager.clear_save()
	GameState.start_new_run()
	GameState.set_graphics_quality(2)
	GameState.day_start_hour = 14.0
	GameState.set_full_loadout(GameState.WeaponId.RIFLE, GameState.WeaponId.PISTOL, GameState.WeaponId.SHOTGUN, GameState.WeaponId.FRAG, GameState.WeaponId.MACHETE)
	GameState.select_outpost("compound_alpha")
	GameState.begin_world_load()
	get_tree().change_scene_to_file("res://scenes/levels/outpost.tscn")
	await GameState.wait_world_ready(90.0)
	await get_tree().create_timer(0.7).timeout
	if DayNightCycle:
		DayNightCycle.set_hour(14.0)
	var player := get_tree().get_first_node_in_group("player") as Node3D
	_place_overlook(player)
	await get_tree().create_timer(0.45).timeout
	_note_fps("overlook_high")
	await _snap("54_overlook_day")
	if is_instance_valid(player):
		player.global_position = Vector3(4.0, 1.45, 8.0)
		player.look_at(Vector3(6.5, 0.7, 4.0), Vector3.UP)
	await get_tree().create_timer(0.3).timeout
	await _snap("55_bush_day")
	GameState.set_graphics_quality(0)
	GameState.day_start_hour = 14.0
	GameState.begin_world_load()
	get_tree().change_scene_to_file("res://scenes/levels/outpost.tscn")
	await GameState.wait_world_ready(90.0)
	await get_tree().create_timer(0.6).timeout
	if DayNightCycle:
		DayNightCycle.set_hour(14.0)
	player = get_tree().get_first_node_in_group("player") as Node3D
	_place_overlook(player)
	await get_tree().create_timer(0.4).timeout
	_note_fps("overlook_low")
	await _snap("56_overlook_low")
	print("OVERLOOK_SNAP complete quality=", GraphicsQuality.level_name() if GraphicsQuality else "?")
	get_tree().quit()


func _web_overlook_view() -> void:
	## https://.../Farsigh/?view=overlook  places a daytime PC-quality camera on the HQ roof.
	await get_tree().process_frame
	await get_tree().create_timer(0.3).timeout
	var low := "quality=low" in _web_search()
	SaveManager.clear_save()
	GameState.start_new_run()
	GameState.set_graphics_quality(0 if low else 2)
	GameState.set_day_start_hour(14.0)
	GameState.select_outpost("compound_alpha")
	GameState.begin_world_load()
	get_tree().change_scene_to_file("res://scenes/levels/outpost.tscn")
	await GameState.wait_world_ready(120.0)
	await get_tree().create_timer(0.8).timeout
	if DayNightCycle:
		DayNightCycle.set_hour(14.0)
	var player := get_tree().get_first_node_in_group("player") as Node3D
	_place_overlook(player)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	print("WEB_OVERLOOK quality=", GraphicsQuality.level_name() if GraphicsQuality else "?")


func _snap_assets() -> void:
	await get_tree().process_frame
	SaveManager.clear_save()
	GameState.start_new_run()
	GameState.set_graphics_quality(2)
	GameState.day_start_hour = 14.0
	GameState.set_full_loadout(GameState.WeaponId.RIFLE, GameState.WeaponId.PISTOL, GameState.WeaponId.SHOTGUN, GameState.WeaponId.FRAG, GameState.WeaponId.MACHETE)
	GameState.select_outpost("compound_alpha")
	GameState.begin_world_load()
	get_tree().change_scene_to_file("res://scenes/levels/outpost.tscn")
	await GameState.wait_world_ready(90.0)
	await get_tree().create_timer(0.6).timeout
	var player := get_tree().get_first_node_in_group("player") as Node3D
	if is_instance_valid(player):
		player.global_position = Vector3(0.0, 1.35, 16.0)
		player.look_at(Vector3(0.0, 0.15, 6.0), Vector3.UP)
	await get_tree().create_timer(0.45).timeout
	_note_fps("ground_day")
	await _snap("50_ground_day")
	if is_instance_valid(player):
		player.global_position = Vector3(0.0, 8.0, 42.0)
		player.look_at(Vector3(0.0, 2.0, 0.0), Vector3.UP)
	await get_tree().create_timer(0.35).timeout
	_note_fps("compound_day")
	await _snap("51_compound_day")
	var spawns := 0
	var covers := 0
	for n in get_tree().get_nodes_in_group("guard_spawn"):
		spawns += 1
	for n in get_tree().get_nodes_in_group("cover_points"):
		covers += 1
	print("ASSET_NOTE spawns=", spawns, " covers=", covers, " guards=", get_tree().get_nodes_in_group("guards").size())
	print("ASSET_SNAP complete")
	get_tree().quit()


func _snap_graphics_and_ai() -> void:
	await get_tree().process_frame
	SaveManager.clear_save()
	GameState.start_new_run()
	GameState.set_graphics_quality(2)
	GameState.day_start_hour = 14.0
	GameState.set_full_loadout(GameState.WeaponId.RIFLE, GameState.WeaponId.PISTOL, GameState.WeaponId.SHOTGUN, GameState.WeaponId.FRAG, GameState.WeaponId.MACHETE)
	GameState.set_weapon_mod(GameState.WeaponId.RIFLE, "optic", "iron")
	GameState.select_outpost("compound_alpha")
	GameState.begin_world_load()
	get_tree().change_scene_to_file("res://scenes/levels/outpost.tscn")
	await GameState.wait_world_ready(90.0)
	await get_tree().create_timer(0.8).timeout
	var player := get_tree().get_first_node_in_group("player") as Node3D
	if is_instance_valid(player):
		player.global_position = Vector3(2.0, 1.4, 20.0)
		player.look_at(Vector3(0.0, 1.5, 0.0), Vector3.UP)
	await get_tree().create_timer(0.45).timeout
	_note_fps("day_high")
	await _snap("43_gfx_day")
	if DayNightCycle:
		DayNightCycle.set_hour(17.55)
		DayNightCycle.bind_to_scene()
	if is_instance_valid(player):
		player.look_at(Vector3(0.0, 6.5, -4.0), Vector3.UP)
	await get_tree().create_timer(0.4).timeout
	_note_fps("sunset_high")
	await _snap("44_gfx_sunset")
	if DayNightCycle:
		DayNightCycle.set_hour(22.5)
	if is_instance_valid(player):
		player.global_position = Vector3(2.0, 1.4, 20.0)
		player.look_at(Vector3(0.0, 2.2, 0.0), Vector3.UP)
	await get_tree().create_timer(0.4).timeout
	_note_fps("night_high")
	await _snap("45_gfx_night")
	if DayNightCycle:
		DayNightCycle.set_hour(14.0)
	if is_instance_valid(player):
		player.global_position = Vector3(-4.0, 1.7, 36.0)
		player.look_at(Vector3(10.0, 4.0, 68.0), Vector3.UP)
	await get_tree().create_timer(0.35).timeout
	_note_fps("forest_high")
	await _snap("46_gfx_forest")
	if is_instance_valid(player):
		player.global_position = Vector3(0.0, 1.2, 26.0)
		player.look_at(Vector3(0.0, 1.4, 0.0), Vector3.UP)
		player.set("force_ads", true)
	var wm = player.get_node_or_null("WeaponManager") if is_instance_valid(player) else null
	if is_instance_valid(wm) and is_instance_valid(wm.viewmodel_rig):
		wm.viewmodel_rig.rebuild_weapon(GameState.WeaponId.RIFLE, GameState.get_weapon_mods(GameState.WeaponId.RIFLE))
		wm.viewmodel_rig.show_weapon(GameState.WeaponId.RIFLE, false)
		wm.viewmodel_rig.set_aiming(true, 0.01)
		wm.viewmodel_rig._aim_blend = 1.0
		wm.viewmodel_rig._aim_target = 1.0
	for _i in range(6):
		await get_tree().process_frame
	_note_fps("guns_high")
	await _snap("47_gfx_guns")
	if is_instance_valid(player):
		player.set("force_ads", false)
	# Provoke the guard already nearest a cover marker, then hide so they hold that spot
	var g0: Node = null
	var g0_cover_d := 9999.0
	for g in get_tree().get_nodes_in_group("guards"):
		if not is_instance_valid(g) or not g.has_method("apply_damage"):
			continue
		if bool(g.get("is_sniper")) or bool(g.get("is_dog")) or bool(g.get("is_officer")):
			continue
		var gn := g as Node3D
		var nearest := 9999.0
		for c in get_tree().get_nodes_in_group("cover_points"):
			if c is Node3D:
				nearest = minf(nearest, gn.global_position.distance_to((c as Node3D).global_position))
		if nearest < g0_cover_d:
			g0_cover_d = nearest
			g0 = g
	if is_instance_valid(g0) and is_instance_valid(player):
		var gp: Vector3 = (g0 as Node3D).global_position
		player.global_position = gp + Vector3(0, 1.2, 6.5)
		player.look_at(gp + Vector3.UP, Vector3.UP)
		g0.apply_damage(12.0, gp + Vector3.UP, player, "TORSO")
		# Break line of sight immediately so they hold the ghost, not the live body
		player.global_position = Vector3(48.0, 1.2, -40.0)
		await get_tree().create_timer(2.1).timeout
		var focus := g0 as Node3D
		var fp := focus.global_position
		print("COVER_NOTE state=", focus.get("state"), " role=", focus.get("_combat_role"), " start_cover_d=", g0_cover_d, " pos=", fp)
		player.global_position = fp + Vector3(4.8, 1.55, 3.6)
		player.look_at(fp + Vector3(0, 1.2, 0), Vector3.UP)
		_note_fps("cover_ai")
		await _snap("48_guards_cover")
	# Mobile Low — rebuild world so unshaded / no shadow path is what loads
	GameState.set_graphics_quality(0)
	GameState.day_start_hour = 14.0
	GameState.begin_world_load()
	get_tree().change_scene_to_file("res://scenes/levels/outpost.tscn")
	await GameState.wait_world_ready(90.0)
	await get_tree().create_timer(0.7).timeout
	player = get_tree().get_first_node_in_group("player") as Node3D
	if is_instance_valid(player):
		player.global_position = Vector3(2.0, 1.4, 20.0)
		player.look_at(Vector3(0.0, 1.5, 0.0), Vector3.UP)
	await get_tree().create_timer(0.35).timeout
	_note_fps("mobile_low")
	await _snap("49_gfx_low")
	print("GFX_SNAP complete")
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
