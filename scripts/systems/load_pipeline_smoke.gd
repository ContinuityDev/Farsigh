extends SceneTree
## Headless smoke: staged outpost load finishes with geometry, guards, viewmodels,
## detection unfrozen after grace, and no OUTPOST_LOAD_ERROR.

const TIMEOUT_SEC := 45.0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	await process_frame
	var gs := root.get_node("GameState")
	gs.begin_world_load()
	gs.selected_outpost_id = "compound_alpha"
	change_scene_to_file("res://scenes/levels/outpost.tscn")
	await process_frame
	await process_frame

	var ok_wait: bool = await gs.wait_world_ready(TIMEOUT_SEC)
	if not ok_wait or gs.world_loading:
		push_error("LOAD_PIPELINE_SMOKE FAIL: still world_loading after timeout")
		print("LOAD_PIPELINE_SMOKE FAIL timeout")
		quit(1)
		return

	var outpost := get_first_node_in_group("outpost")
	var grey := outpost.get_node_or_null("Greybox") if outpost else null
	var grey_n := grey.get_child_count() if grey else 0
	var guards := 0
	for g in get_nodes_in_group("guards"):
		if is_instance_valid(g):
			guards += 1
	var player := outpost.get_node_or_null("Player") if outpost else null
	var vm_n := 0
	if player:
		var cam := player.get_node_or_null("Head/Camera3D")
		var vm := cam.get_node_or_null("Viewmodels") if cam else null
		if vm:
			for slot in vm.get_children():
				vm_n += slot.get_child_count()

	var frozen_during_grace: bool = gs.is_detection_frozen()
	await create_timer(1.7).timeout
	var frozen_after: bool = gs.is_detection_frozen()

	var ok: bool = grey_n >= 8 and guards >= 8 and vm_n >= 1 and player != null and not frozen_after
	print("LOAD_PIPELINE_SMOKE grey=%d guards=%d vm_parts=%d grace_frozen=%s after=%s" % [
		grey_n, guards, vm_n, frozen_during_grace, frozen_after
	])
	if ok:
		print("LOAD_PIPELINE_SMOKE PASS")
		quit(0)
	else:
		push_error("LOAD_PIPELINE_SMOKE FAIL")
		print("LOAD_PIPELINE_SMOKE FAIL")
		quit(1)
