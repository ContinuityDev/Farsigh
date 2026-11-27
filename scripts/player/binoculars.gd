extends Node
## Free always-on binoculars: raise with B / gamepad / touch, zoom levels,
## auto-tag hostiles with clear LOS after dwell time.


const ZOOM_FOVS := [55.0, 35.0, 22.0, 14.0]
const TAG_DWELL_SEC := 0.5
const TAG_DWELL_PRO := 0.25

var active: bool = false
var zoom_idx: int = 1
var _dwell: Dictionary = {}  # instance_id -> seconds
var _overlay: Control
var _cam: Camera3D
var _base_fov: float = 70.0


func _ready() -> void:
	add_to_group("binoculars")
	set_process(true)
	set_process_unhandled_input(true)
	call_deferred("_bind_camera")


func _bind_camera() -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player == null:
		return
	_cam = player.get_node_or_null("Head/Camera3D") as Camera3D
	if _cam == null:
		_cam = player.get_viewport().get_camera_3d()
	if _cam:
		_base_fov = _cam.fov


func _unhandled_input(event: InputEvent) -> void:
	if GameState.is_paused:
		return
	if event.is_action_pressed("binoculars") or (event is InputEventKey and event.pressed and event.keycode == KEY_B):
		toggle()
		get_viewport().set_input_as_handled()
	elif active and event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom(-1)
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom(1)
			get_viewport().set_input_as_handled()
	elif active and event.is_action_pressed("weapon_next"):
		# Don't steal weapon swap while binos — use +/- style via lean keys as fallback
		pass


func _process(delta: float) -> void:
	if TouchInput.is_action_just_pressed("binoculars"):
		toggle()
	if not active:
		return
	if TouchInput.is_action_just_pressed("binoculars_zoom_in"):
		_zoom(-1)
	elif TouchInput.is_action_just_pressed("binoculars_zoom_out"):
		_zoom(1)
	_update_tagging(delta)


func toggle() -> void:
	active = not active
	if not is_instance_valid(_cam):
		_bind_camera()
	var player := get_tree().get_first_node_in_group("player")
	if active:
		_dwell.clear()
		_ensure_overlay()
		if _overlay:
			_overlay.visible = true
		if is_instance_valid(_cam):
			_cam.fov = ZOOM_FOVS[zoom_idx]
		if player and "move_speed_mult" in player:
			player.set("binoculars_slow", true)
		var hud := get_tree().get_first_node_in_group("hud")
		if hud and hud.has_method("show_status"):
			hud.show_status("Binoculars — scroll/+- zoom · tag hostiles", 2.2)
	else:
		if _overlay:
			_overlay.visible = false
		if is_instance_valid(_cam):
			_cam.fov = _base_fov
		if player:
			player.set("binoculars_slow", false)


func _zoom(dir: int) -> void:
	zoom_idx = clampi(zoom_idx + dir, 0, ZOOM_FOVS.size() - 1)
	if is_instance_valid(_cam):
		_cam.fov = ZOOM_FOVS[zoom_idx]


func _dwell_need() -> float:
	if GameState.owns_item("binoculars_pro"):
		return TAG_DWELL_PRO
	return TAG_DWELL_SEC


func _update_tagging(delta: float) -> void:
	if not is_instance_valid(_cam):
		return
	var space := _cam.get_world_3d().direct_space_state
	var origin := _cam.global_position
	var forward := -_cam.global_transform.basis.z
	var need := _dwell_need()
	var seen: Dictionary = {}
	for g in get_tree().get_nodes_in_group("guards"):
		if not is_instance_valid(g) or not (g is Node3D):
			continue
		if g.has_method("is_alive") and not g.is_alive():
			continue
		var gp := (g as Node3D).global_position + Vector3(0, 1.4, 0)
		var to := gp - origin
		var dist := to.length()
		if dist < 2.0 or dist > 120.0:
			continue
		var dir := to / dist
		if dir.dot(forward) < 0.92:  # roughly in view cone
			continue
		var q := PhysicsRayQueryParameters3D.create(origin, gp)
		q.collision_mask = 1 | 4
		q.exclude = [_player_rid()]
		var hit := space.intersect_ray(q)
		if hit.is_empty():
			continue
		var collider = hit.get("collider")
		var ok := false
		if collider == g or (collider is Node and g.is_ancestor_of(collider)) or (collider is Node and (collider as Node).get_parent() == g):
			ok = true
		elif collider is Node:
			var n: Node = collider
			while n:
				if n == g:
					ok = true
					break
				n = n.get_parent()
		if not ok:
			continue
		var id := g.get_instance_id()
		seen[id] = true
		_dwell[id] = float(_dwell.get(id, 0.0)) + delta
		if float(_dwell[id]) >= need:
			_tag_node(g)
	# Decay unseen
	for id in _dwell.keys():
		if not seen.has(id):
			_dwell[id] = maxf(0.0, float(_dwell[id]) - delta * 2.0)


func _tag_node(g: Node) -> void:
	if g.has_method("set_tagged"):
		g.set_tagged(true)
	elif "tagged" in g:
		g.set("tagged", true)
	if g.get("label") is Label3D:
		var lbl: Label3D = g.get("label")
		lbl.modulate = Color(0.25, 0.95, 1.0)
		lbl.visible = true
	# Persist tag marker
	if not g.has_meta("farsigh_tagged"):
		g.set_meta("farsigh_tagged", true)
		var marker := Label3D.new()
		marker.name = "TagIcon"
		marker.text = _role_icon(g)
		marker.font_size = 48
		marker.outline_size = 8
		marker.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		marker.position = Vector3(0, 2.35, 0)
		marker.modulate = Color(0.3, 0.95, 1.0)
		marker.no_depth_test = true
		g.add_child(marker)


func _role_icon(g: Node) -> String:
	var role := String(g.get("role")) if "role" in g else ""
	if bool(g.get("is_sniper")) if "is_sniper" in g else false:
		return "◎ S"
	match role:
		"heavy":
			return "◎ H"
		"officer":
			return "◎ O"
		"dog":
			return "◎ D"
		_:
			return "◎"


func _player_rid() -> RID:
	var player := get_tree().get_first_node_in_group("player")
	if player is CollisionObject3D:
		return (player as CollisionObject3D).get_rid()
	return RID()


func _ensure_overlay() -> void:
	if is_instance_valid(_overlay):
		return
	var hud := get_tree().get_first_node_in_group("hud")
	if hud == null:
		return
	_overlay = Control.new()
	_overlay.name = "BinoOverlay"
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Dual circles vignette
	for spec in [[0.0, 0.0, 1.0, 0.18], [0.0, 0.82, 1.0, 1.0], [0.0, 0.18, 0.18, 0.82], [0.82, 0.18, 1.0, 0.82]]:
		var bar := ColorRect.new()
		bar.color = Color(0.02, 0.03, 0.02, 0.88)
		bar.anchor_left = spec[0]
		bar.anchor_top = spec[1]
		bar.anchor_right = spec[2]
		bar.anchor_bottom = spec[3]
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_overlay.add_child(bar)
	var hint := Label.new()
	hint.text = "BINOCULARS  ·  wheel zoom  ·  tagging…"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	hint.offset_top = -48
	hint.offset_bottom = -16
	hint.offset_left = -200
	hint.offset_right = 200
	hint.add_theme_font_size_override("font_size", 16)
	_overlay.add_child(hint)
	# Zoom buttons for touch
	var zin := Button.new()
	zin.text = "+"
	zin.custom_minimum_size = Vector2(56, 56)
	zin.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	zin.offset_left = -90
	zin.offset_right = -30
	zin.offset_top = -70
	zin.offset_bottom = -14
	zin.pressed.connect(func(): _zoom(-1))
	_overlay.add_child(zin)
	var zout := Button.new()
	zout.text = "−"
	zout.custom_minimum_size = Vector2(56, 56)
	zout.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	zout.offset_left = -90
	zout.offset_right = -30
	zout.offset_top = 14
	zout.offset_bottom = 70
	zout.pressed.connect(func(): _zoom(1))
	_overlay.add_child(zout)
	var root := hud.get_node_or_null("Root")
	if root:
		root.add_child(_overlay)
	else:
		hud.add_child(_overlay)
