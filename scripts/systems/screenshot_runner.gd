extends Node
## Boot helper: AUTO_CAPTURE=1 drives menu → loadout → outpost screenshots.


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
	await get_tree().create_timer(2.5).timeout
	await _snap("03_outpost")

	# Force touch UI overlay shot for docs (hidden on PC during normal play)
	TouchInput.force_touch_ui = true
	var hud := get_tree().get_first_node_in_group("hud")
	if hud:
		var tc = hud.get_node_or_null("TouchControls")
		if tc:
			tc.visible = true
			var root = tc.get_node_or_null("Root")
			if root:
				root.visible = true
	await get_tree().create_timer(0.8).timeout
	await _snap("04_touch_controls")

	print("AUTO_CAPTURE complete")
	await get_tree().create_timer(0.3).timeout
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
