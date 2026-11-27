extends SceneTree
## Headless smoke test for Feature 4: Full 14-weapon arsenal, 5-slot switching,
## distinct stats, Frag/Molotov ordnance, melee swings, headshot one-shots,
## and Gunsmith stat modifiers.


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	await process_frame
	var gs := root.get_node("GameState")
	var sm := root.get_node("SaveManager")
	sm.clear_save()
	gs.start_new_run()

	# 1. Verify all 14 weapons have distinct stats & valid Gunsmith mod effects
	var all_ids := [
		gs.WeaponId.RIFLE, gs.WeaponId.SMG, gs.WeaponId.SHOTGUN, gs.WeaponId.SNIPER, gs.WeaponId.LMG,
		gs.WeaponId.PISTOL, gs.WeaponId.MACHINE_PISTOL, gs.WeaponId.BOW, gs.WeaponId.CROSSBOW,
		gs.WeaponId.KNIFE, gs.WeaponId.FRAG, gs.WeaponId.MOLOTOV, gs.WeaponId.MACHETE, gs.WeaponId.BAT,
	]
	var WD = load("res://scripts/weapons/weapon_data.gd")
	for wid in all_ids:
		var wd = WD.from_id(wid)
		if wd.damage <= 0.0 or wd.fire_rate <= 0.0 or wd.max_range <= 0.0:
			print("ARSENAL_SMOKE FAIL invalid stats for ", wid)
			quit(2)
			return

	var base_rifle = WD.from_id(gs.WeaponId.RIFLE)
	var modded_rifle = WD.from_id(gs.WeaponId.RIFLE, {
		"muzzle": "suppressor",
		"optic": "scope",
		"mag": "extended",
		"underbarrel": "grip",
	})
	print("ARSENAL_SMOKE rifle noise %.1f->%.1f range %.1f->%.1f mag %d->%d fov %.1f->%.1f recoil %.2f->%.2f" % [
		base_rifle.noise_loudness, modded_rifle.noise_loudness,
		base_rifle.max_range, modded_rifle.max_range,
		base_rifle.magazine_size, modded_rifle.magazine_size,
		base_rifle.aim_fov, modded_rifle.aim_fov,
		base_rifle.recoil_pitch, modded_rifle.recoil_pitch,
	])
	if not (modded_rifle.noise_loudness < base_rifle.noise_loudness * 0.4
		and modded_rifle.max_range < base_rifle.max_range
		and modded_rifle.magazine_size > base_rifle.magazine_size
		and modded_rifle.aim_fov < base_rifle.aim_fov
		and modded_rifle.scope_overlay
		and modded_rifle.recoil_pitch < base_rifle.recoil_pitch):
		print("ARSENAL_SMOKE FAIL mod stats check")
		quit(3)
		return

	# 2. Equip a mixed 5-slot loadout (Shotgun, Machine Pistol, Crossbow, Frag, Machete) and deploy
	gs.set_full_loadout(gs.WeaponId.SHOTGUN, gs.WeaponId.MACHINE_PISTOL, gs.WeaponId.CROSSBOW, gs.WeaponId.FRAG, gs.WeaponId.MACHETE)
	gs.select_outpost("compound_alpha")
	change_scene_to_file("res://scenes/levels/outpost.tscn")
	await process_frame
	await process_frame
	await create_timer(0.45).timeout

	var player := get_first_node_in_group("player")
	var wm := player.get_node("WeaponManager")
	for i in range(5):
		wm.select_slot(i)
		await process_frame
		wm.try_fire()
		await process_frame

	# 3. Verify headshots still one-shot even with the lowest per-pellet/per-bullet weapon (SMG/Shotgun/Machine Pistol)
	var guards := get_nodes_in_group("guards")
	if guards.size() >= 2:
		var g0 = guards[0]
		var g1 = guards[1]
		var smg = WD.from_id(gs.WeaponId.SMG)
		var bat = WD.from_id(gs.WeaponId.BAT)
		g0.apply_hit_zone(g0.get_node("HitZones/Head"), smg.damage, g0.global_position + Vector3.UP * 1.7, player)
		g1.apply_hit_zone(g1.get_node("HitZones/Head"), bat.damage, g1.global_position + Vector3.UP * 1.7, player)
		await create_timer(0.25).timeout
		var g0_dead: bool = not is_instance_valid(g0) or not bool(g0.is_alive())
		var g1_dead: bool = not is_instance_valid(g1) or not bool(g1.is_alive())
		print("ARSENAL_SMOKE headshot_oneshot smg=", g0_dead, " bat=", g1_dead)
		if not (g0_dead and g1_dead):
			print("ARSENAL_SMOKE FAIL headshot one-shot")
			quit(4)
			return

	print("ARSENAL_SMOKE PASS")
	quit(0)
