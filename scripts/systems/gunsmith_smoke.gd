extends SceneTree
## Headless smoke test for Feature 5: Loadout & Gunsmith UI, mod attachment,
## live 3D preview rebuild, and persistent loadout saving across sessions & New Run.


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	await process_frame
	var gs := root.get_node("GameState")
	var sm := root.get_node("SaveManager")
	sm.clear_save()
	gs.start_new_run()

	# 1. Load the Gunsmith UI scene
	change_scene_to_file("res://scenes/ui/loadout.tscn")
	await process_frame
	await process_frame
	var ui := current_scene
	if ui == null:
		print("GUNSMITH_SMOKE FAIL scene failed to load")
		quit(2)
		return

	# 2. Customize all 5 slots and attach mods via UI handlers
	ui._on_slot_tab("primary")
	ui._select_weapon_for_slot(gs.WeaponId.SMG)
	ui._on_mod_picked(gs.WeaponId.SMG, "muzzle", "suppressor")
	ui._on_mod_picked(gs.WeaponId.SMG, "optic", "holo")
	ui._on_mod_picked(gs.WeaponId.SMG, "mag", "extended")
	ui._on_mod_picked(gs.WeaponId.SMG, "underbarrel", "laser")
	ui._on_mod_picked(gs.WeaponId.SMG, "skin", "crimson")

	ui._on_slot_tab("special")
	ui._select_weapon_for_slot(gs.WeaponId.BOW)
	ui._on_mod_picked(gs.WeaponId.BOW, "arrow", "explosive")
	ui._on_mod_picked(gs.WeaponId.BOW, "skin", "gold")

	ui._on_slot_tab("throwable")
	ui._select_weapon_for_slot(gs.WeaponId.MOLOTOV)
	ui._on_slot_tab("melee")
	ui._select_weapon_for_slot(gs.WeaponId.BAT)
	await process_frame

	# 3. Clear campaign save (simulate New Run) and reload from disk to prove loadout persists!
	sm.clear_save()
	gs.selected_primary = gs.WeaponId.RIFLE
	gs.weapon_mods.clear()
	var loaded: bool = sm.load_loadout()
	var smg_mods: Dictionary = gs.get_weapon_mods(gs.WeaponId.SMG)
	var bow_mods: Dictionary = gs.get_weapon_mods(gs.WeaponId.BOW)
	print("GUNSMITH_SMOKE loaded=", loaded, " primary=", gs.selected_primary, " smg_muzzle=", smg_mods.get("muzzle"), " bow_arrow=", bow_mods.get("arrow"), " skin=", smg_mods.get("skin"))
	if not (loaded and gs.selected_primary == gs.WeaponId.SMG and smg_mods.get("muzzle") == "suppressor" and smg_mods.get("skin") == "crimson" and bow_mods.get("arrow") == "explosive"):
		print("GUNSMITH_SMOKE FAIL persistence")
		quit(3)
		return

	# 4. Deploy to outpost and verify WeaponManager picked up modded SMG (extended mag + suppressed)
	gs.begin_world_load()
	change_scene_to_file("res://scenes/levels/outpost.tscn")
	await gs.wait_world_ready()
	await process_frame
	await process_frame
	await create_timer(0.35).timeout
	var player := get_first_node_in_group("player")
	var wm := player.get_node("WeaponManager")
	var active = wm.get_active()
	print("GUNSMITH_SMOKE deployed_active=", active.display_name, " mag=", active.magazine_size, " suppressed=", active.is_suppressed)
	if active.id != gs.WeaponId.SMG or not active.is_suppressed or active.magazine_size <= 32:
		print("GUNSMITH_SMOKE FAIL deployed stats")
		quit(4)
		return

	print("GUNSMITH_SMOKE PASS")
	quit(0)
