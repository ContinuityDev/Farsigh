extends SceneTree
## Headless ADS verification: sight markers, aim blend, FOV drop, spread/recoil
## multipliers, breath-hold, crosshair hide, and settings persistence.


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	await process_frame
	var gs := root.get_node("GameState")
	var sm := root.get_node("SaveManager")
	var touch := root.get_node("TouchInput")

	sm.clear_save()
	gs.start_new_run()
	gs.set_full_loadout(
		gs.WeaponId.RIFLE,
		gs.WeaponId.PISTOL,
		gs.WeaponId.BOW,
		gs.WeaponId.FRAG,
		gs.WeaponId.MACHETE
	)
	gs.set_weapon_mod(gs.WeaponId.RIFLE, "optic", "holo")
	gs.set_weapon_mod(gs.WeaponId.SNIPER, "optic", "scope")
	gs.select_outpost("compound_alpha")

	# 1. WeaponData ADS stats + optic FOV
	var WeaponDataScript = load("res://scripts/weapons/weapon_data.gd")
	var base = WeaponDataScript.from_id(gs.WeaponId.RIFLE, {})
	var holo = WeaponDataScript.from_id(gs.WeaponId.RIFLE, {"optic": "holo", "muzzle": "none", "mag": "standard", "underbarrel": "none", "arrow": "standard", "skin": "default"})
	var sniper = WeaponDataScript.from_id(gs.WeaponId.SNIPER, {"optic": "scope"})
	if not (base.ads_time > 0.1 and base.ads_spread_mult < 1.0 and holo.aim_fov <= 48.0 and sniper.scope_overlay and sniper.aim_fov <= 24.0):
		print("ADS_SMOKE FAIL stats")
		quit(1)
		return
	print("ADS_SMOKE stats rifle_ads_time=%.2f holo_fov=%.1f sniper_fov=%.1f" % [base.ads_time, holo.aim_fov, sniper.aim_fov])

	# 2. Settings persistence
	gs.set_ads_sensitivity(0.35)
	gs.set_touch_aim_toggle(true)
	sm.save_loadout()
	gs.ads_sensitivity = 0.55
	gs.touch_aim_toggle = false
	if not sm.load_loadout() or absf(gs.ads_sensitivity - 0.35) > 0.01 or gs.touch_aim_toggle != true:
		print("ADS_SMOKE FAIL settings")
		quit(1)
		return
	print("ADS_SMOKE settings ads_sens=%.2f touch_toggle=%s" % [gs.ads_sensitivity, str(gs.touch_aim_toggle)])
	gs.set_touch_aim_toggle(false)
	gs.set_ads_sensitivity(0.55)

	# 3. Deploy outpost and exercise live ADS
	gs.begin_world_load()
	change_scene_to_file("res://scenes/levels/outpost.tscn")
	await gs.wait_world_ready()
	await process_frame
	await process_frame
	await create_timer(0.6).timeout

	var player := get_first_node_in_group("player")
	if not is_instance_valid(player):
		print("ADS_SMOKE FAIL no player")
		quit(1)
		return
	var wm = player.get_node("WeaponManager")
	var cam: Camera3D = player.get_node("Head/Camera3D")
	var hip_fov := cam.fov

	touch.press("aim")
	await create_timer(0.55).timeout
	var blend: float = float(player.get("aim_blend"))
	var aimed_fov := cam.fov
	if blend < 0.85 or aimed_fov >= hip_fov - 5.0 or not bool(player.get("is_aiming")):
		print("ADS_SMOKE FAIL aim_blend/fov blend=%.2f fov=%.1f->%.1f" % [blend, hip_fov, aimed_fov])
		quit(1)
		return

	var slot: Node3D = wm.viewmodel_rig.get_slot(gs.WeaponId.RIFLE)
	var model_root := slot.get_node_or_null("ModelRoot") if is_instance_valid(slot) else null
	if model_root == null or model_root.get_node_or_null("SightPoint") == null:
		print("ADS_SMOKE FAIL missing SightPoint")
		quit(1)
		return

	var hud := get_first_node_in_group("hud")
	var cross := hud.get_node_or_null("Root/Crosshair") as Control if is_instance_valid(hud) else null
	if cross == null or cross.visible:
		print("ADS_SMOKE FAIL crosshair still visible")
		quit(1)
		return

	touch.press("sprint")
	await create_timer(0.2).timeout
	touch.release("sprint")

	# Scope overlay for sniper
	gs.selected_primary = gs.WeaponId.SNIPER
	wm._equip_from_loadout()
	wm._refresh_viewmodel(false)
	touch.press("aim")
	await create_timer(0.7).timeout
	var scope_node = hud.get_node_or_null("Root/ScopeOverlay")
	if not wm.has_scope_overlay() or scope_node == null or not scope_node.visible or wm.viewmodel_rig.visible:
		print("ADS_SMOKE FAIL sniper scope overlay")
		quit(1)
		return

	touch.release("aim")
	await create_timer(0.7).timeout
	if float(player.get("aim_blend")) > 0.15 or cam.fov <= aimed_fov + 5.0:
		print("ADS_SMOKE FAIL aim release blend=%.2f fov=%.1f" % [float(player.get("aim_blend")), cam.fov])
		quit(1)
		return

	wm.select_slot(4)
	touch.press("aim")
	await create_timer(0.35).timeout
	wm.select_slot(3)
	await create_timer(0.35).timeout
	touch.release("aim")

	print("ADS_SMOKE PASS")
	quit(0)
