extends SceneTree
## Verifies consumable streaks start empty, buy/equip/consume, New Run wipe, catalog.


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	await process_frame
	var gs := root.get_node("GameState")
	gs.start_new_run()
	if gs.get_streak_charges("recon_drone") != 0 or gs.currency != 0:
		print("PROG_SMOKE FAIL starter charges/currency")
		quit(1)
		return
	gs.add_currency(500)
	var err: String = gs.try_purchase("streak_recon")
	if err != "":
		print("PROG_SMOKE FAIL buy ", err)
		quit(1)
		return
	if gs.get_streak_charges("recon_drone") != 1:
		print("PROG_SMOKE FAIL charge count")
		quit(1)
		return
	gs.set_equipped_streak(0, "recon_drone")
	if not gs.consume_streak_charge("recon_drone"):
		print("PROG_SMOKE FAIL consume")
		quit(1)
		return
	root.get_node("SaveManager").clear_save()
	gs.start_new_run()
	if gs.get_streak_charges("recon_drone") != 0 or String(gs.equipped_streaks[0]) != "":
		print("PROG_SMOKE FAIL new run wipe")
		quit(1)
		return
	const Cat = preload("res://scripts/levels/outpost_catalog.gd")
	for o in Cat.get_all():
		print("OUTPOST ", o["id"], " guards=", Cat.guard_count(o), " diff=", o.get("difficulty_label"))
	print("PROG_SMOKE PASS")
	quit(0)
