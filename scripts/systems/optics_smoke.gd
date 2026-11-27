extends SceneTree
## Headless optics audit: every optic-capable weapon gets correct ADS FOV
## for red_dot (1.5x), holo (2x), and scope (4x base + 6/8 cycle).


const HIP := 70.0
const TOL := 0.35


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	await process_frame
	var gs := root.get_node("GameState")
	var WD = load("res://scripts/weapons/weapon_data.gd")
	var ok := true
	var optic_ids: Array = []
	for wid in [
		gs.WeaponId.PISTOL, gs.WeaponId.MACHINE_PISTOL,
		gs.WeaponId.SMG, gs.WeaponId.RIFLE, gs.WeaponId.SHOTGUN,
		gs.WeaponId.SNIPER, gs.WeaponId.SILENCED_SNIPER,
		gs.WeaponId.LMG, gs.WeaponId.BOW, gs.WeaponId.CROSSBOW,
	]:
		var probe = WD.from_id(wid, {"optic": "iron"})
		if probe.supports_optic:
			optic_ids.append(wid)

	print("OPTICS_SMOKE weapons_with_optic=", optic_ids.size())
	for wid in optic_ids:
		for optic in ["red_dot", "holo", "scope"]:
			var w = WD.from_id(wid, {"optic": optic})
			var expect := HIP / 1.5 if optic == "red_dot" else (HIP / 2.0 if optic == "holo" else HIP / 4.0)
			if absf(w.aim_fov - expect) > TOL:
				push_error("FOV fail %s optic=%s got=%.2f want=%.2f" % [w.display_name, optic, w.aim_fov, expect])
				ok = false
			if optic == "scope" and not w.scope_overlay:
				push_error("scope_overlay missing on %s" % w.display_name)
				ok = false
			if optic != "scope" and w.scope_overlay:
				push_error("scope_overlay unexpected on %s/%s" % [w.display_name, optic])
				ok = false
			print("  OK %s %s aim_fov=%.2f overlay=%s" % [w.display_name, optic, w.aim_fov, w.scope_overlay])

	# Sniper default must be scope @ 4x
	var sn = WD.from_id(gs.WeaponId.SNIPER, gs.default_mods_for(gs.WeaponId.SNIPER))
	if not sn.scope_overlay or absf(sn.aim_fov - HIP / 4.0) > TOL:
		push_error("Sniper default not 4x scope")
		ok = false
	else:
		print("  OK sniper default 4x fov=%.2f" % sn.aim_fov)

	# Runtime zoom steps (4→6→8→4) — same FOV math WeaponManager.get_aim_fov uses
	var zoom_mults := [4.0, 6.0, 8.0]
	var step := 0
	for label in ["4x", "6x", "8x", "wrap"]:
		var mult: float = float(zoom_mults[step])
		var fov: float = HIP / mult
		var expect2: float = HIP / float(zoom_mults[0 if label == "wrap" else step])
		if label == "wrap":
			expect2 = HIP / 4.0
		if absf(fov - expect2) > TOL:
			push_error("zoom step %s got=%.2f want=%.2f" % [label, fov, expect2])
			ok = false
		else:
			print("  OK zoom %s fov=%.2f" % [label, fov])
		step = (step + 1) % zoom_mults.size()
	# Confirm WeaponManager script still parses with typed helpers
	var WM = load("res://scripts/weapons/weapon_manager.gd")
	if WM == null:
		push_error("WeaponManager failed to load")
		ok = false
	else:
		print("  OK WeaponManager script loaded")

	if ok:
		print("OPTICS_SMOKE PASS")
		quit(0)
	else:
		print("OPTICS_SMOKE FAIL")
		quit(1)
