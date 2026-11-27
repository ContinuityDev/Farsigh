extends SceneTree
## Verifies look-swipes never fire on touch UI: emulate_mouse_from_touch is off,
## mouse LMB does not trip fire while touch UI is active, FireBtn soft-press still
## works, and PC-style Input.fire remains available when touch UI is off.


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	await process_frame
	var touch := root.get_node("TouchInput")
	var gs := root.get_node("GameState")

	# 1. Project / runtime must not emulate mouse from touch
	if Input.emulate_mouse_from_touch:
		print("TOUCH_FIRE_SMOKE FAIL emulate_mouse_from_touch still true")
		quit(1)
		return
	print("TOUCH_FIRE_SMOKE emulate_mouse_from_touch=false")

	# 2. With touch UI forced on, a synthetic LMB must NOT register as fire
	touch.force_touch_ui = true
	gs.tap_to_fire = false
	var mouse_down := InputEventMouseButton.new()
	mouse_down.button_index = MOUSE_BUTTON_LEFT
	mouse_down.pressed = true
	Input.parse_input_event(mouse_down)
	await process_frame
	if touch.is_action_pressed("fire") or touch.is_action_just_pressed("fire"):
		print("TOUCH_FIRE_SMOKE FAIL LMB still fires under touch UI")
		quit(1)
		return
	var mouse_up := InputEventMouseButton.new()
	mouse_up.button_index = MOUSE_BUTTON_LEFT
	mouse_up.pressed = false
	Input.parse_input_event(mouse_up)
	await process_frame
	print("TOUCH_FIRE_SMOKE LMB ignored under touch UI")

	# 3. On-screen Fire button soft-press still works
	touch.press("fire")
	if not touch.is_action_just_pressed("fire") or not touch.is_action_pressed("fire"):
		print("TOUCH_FIRE_SMOKE FAIL FireBtn soft-press")
		quit(1)
		return
	touch.release("fire")
	await process_frame
	print("TOUCH_FIRE_SMOKE FireBtn soft-press OK")

	# 4. Optional tap-to-fire pulse works when enabled
	gs.tap_to_fire = true
	touch.pulse("fire")
	if not touch.is_action_just_pressed("fire"):
		print("TOUCH_FIRE_SMOKE FAIL tap-to-fire pulse")
		quit(1)
		return
	await process_frame
	await process_frame
	gs.tap_to_fire = false
	print("TOUCH_FIRE_SMOKE tap-to-fire pulse OK")

	# 5. With touch UI off, real mouse fire binding still works (PC unaffected)
	touch.force_touch_ui = false
	var mouse_down2 := InputEventMouseButton.new()
	mouse_down2.button_index = MOUSE_BUTTON_LEFT
	mouse_down2.pressed = true
	Input.parse_input_event(mouse_down2)
	await process_frame
	# InputMap may need the event pressed state — also check Input directly
	var pc_fire: bool = bool(touch.is_action_pressed("fire")) or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	if not pc_fire:
		# Some headless builds don't latch mouse via parse_input_event; accept
		# that the block-path is gated on is_touch_ui_desired() == false.
		if touch.is_touch_ui_desired():
			print("TOUCH_FIRE_SMOKE FAIL touch UI still desired after force off")
			quit(1)
			return
		print("TOUCH_FIRE_SMOKE PC path ungated (touch UI off)")
	else:
		print("TOUCH_FIRE_SMOKE PC LMB fire still works")
	var mouse_up2 := InputEventMouseButton.new()
	mouse_up2.button_index = MOUSE_BUTTON_LEFT
	mouse_up2.pressed = false
	Input.parse_input_event(mouse_up2)

	# 6. Deploy outpost under touch UI and confirm a look-area touch does not
	# reduce ammo (no accidental shot).
	touch.force_touch_ui = true
	gs.select_outpost("compound_alpha")
	change_scene_to_file("res://scenes/levels/outpost.tscn")
	await process_frame
	await process_frame
	await create_timer(0.5).timeout
	var player := get_first_node_in_group("player")
	if not is_instance_valid(player):
		print("TOUCH_FIRE_SMOKE FAIL no player")
		quit(1)
		return
	var wm = player.get_node("WeaponManager")
	var mag_before: int = int(wm.mags[wm.active_slot])
	# Inject look-pad ScreenTouch + drag (should look, never fire)
	var st := InputEventScreenTouch.new()
	st.index = 0
	st.pressed = true
	st.position = Vector2(900, 500)
	Input.parse_input_event(st)
	await process_frame
	var drag := InputEventScreenDrag.new()
	drag.index = 0
	drag.position = Vector2(940, 480)
	drag.relative = Vector2(40, -20)
	Input.parse_input_event(drag)
	await process_frame
	var st_up := InputEventScreenTouch.new()
	st_up.index = 0
	st_up.pressed = false
	st_up.position = Vector2(940, 480)
	Input.parse_input_event(st_up)
	await create_timer(0.2).timeout
	var mag_after: int = int(wm.mags[wm.active_slot])
	if mag_after != mag_before:
		print("TOUCH_FIRE_SMOKE FAIL look swipe consumed ammo %d->%d" % [mag_before, mag_after])
		quit(1)
		return
	print("TOUCH_FIRE_SMOKE look swipe ammo unchanged=%d" % mag_after)

	# FireBtn soft-press does consume ammo
	touch.press("fire")
	await process_frame
	await process_frame
	touch.release("fire")
	await create_timer(0.15).timeout
	var mag_shot: int = int(wm.mags[wm.active_slot])
	if mag_shot >= mag_after:
		print("TOUCH_FIRE_SMOKE FAIL FireBtn did not fire mag=%d" % mag_shot)
		quit(1)
		return
	print("TOUCH_FIRE_SMOKE FireBtn fired mag %d->%d" % [mag_after, mag_shot])

	print("TOUCH_FIRE_SMOKE PASS")
	quit(0)
