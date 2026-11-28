extends Node
## Equipped scorestreaks: earn via undetected kill chain, activate from HUD/touch.


var _used: Array = [false, false, false]
var _active_until: Dictionary = {}  # streak_id -> msec
var _dog: Node3D = null
var placing_id: String = ""
var aim_point: Vector3 = Vector3.ZERO
var _marker: Node3D
var _gunship_center: Vector3 = Vector3.ZERO


func _ready() -> void:
	add_to_group("streak_manager")
	name = "StreakManager"
	set_process(true)


var _hud_refresh_acc: float = 0.0


func _process(delta: float) -> void:
	if placing_id != "":
		_update_aim()
	_tick_companions()
	_hud_refresh_acc += delta
	if _hud_refresh_acc >= 0.35:
		_hud_refresh_acc = 0.0
		_refresh_hud()


func is_placing() -> bool:
	return placing_id != ""


func request_use() -> bool:
	## Tap: fire the selected support, or arm a ground marker for mortar / gunship.
	if placing_id != "":
		return confirm_place()
	var sid := GameState.ensure_selected_streak()
	if sid == "":
		return false
	if StreakCatalog.is_targeted(sid):
		begin_place(sid)
		return true
	return try_activate_id(sid)


func begin_place(sid: String) -> void:
	if sid == "" or GameState.get_streak_charges(sid) <= 0:
		return
	placing_id = sid
	GameState.select_streak(sid)
	_ensure_marker()
	_update_aim()
	if is_instance_valid(_marker):
		_marker.visible = true
	var info := StreakCatalog.by_id(sid)
	var hud := get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("show_status"):
		hud.show_status("%s — aim the marker, press again to strike" % String(info.get("name", sid)), 3.0)
	_refresh_hud()


func confirm_place() -> bool:
	if placing_id == "":
		return false
	var sid := placing_id
	var point := aim_point
	if not GameState.consume_streak_charge(sid):
		cancel_place()
		return false
	placing_id = ""
	if is_instance_valid(_marker):
		_marker.visible = false
	_fire_streak(sid, point, true)
	_announce(sid)
	return true


func cancel_place() -> void:
	if placing_id == "":
		return
	placing_id = ""
	if is_instance_valid(_marker):
		_marker.visible = false
	var hud := get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("show_status"):
		hud.show_status("Strike cancelled", 1.2)
	_refresh_hud()


func streak_progress() -> int:
	## Charges remaining on the active slot's ability (HUD display).
	return 0


func charges_for_slot(slot: int) -> int:
	var sid := _slot_id(slot)
	if sid == "":
		return 0
	return GameState.get_streak_charges(sid)


func can_activate(slot: int) -> bool:
	if slot < 0 or slot > 2:
		return false
	var sid := _slot_id(slot)
	if sid == "" or not GameState.owns_streak(sid):
		return false
	return GameState.get_streak_charges(sid) > 0


func try_activate(slot: int) -> bool:
	if not can_activate(slot):
		return false
	var sid := _slot_id(slot)
	GameState.select_streak(sid)
	if placing_id != "" and placing_id != sid:
		cancel_place()
	if StreakCatalog.is_targeted(sid):
		if placing_id == sid:
			return confirm_place()
		begin_place(sid)
		return true
	if placing_id != "":
		cancel_place()
	return try_activate_id(sid)


func try_activate_id(sid: String) -> bool:
	if sid == "" or GameState.get_streak_charges(sid) <= 0:
		return false
	if not GameState.consume_streak_charge(sid):
		return false
	_fire_streak(sid, Vector3.ZERO, false)
	_announce(sid)
	return true


func _announce(sid: String) -> void:
	var hud := get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("show_status"):
		var info := StreakCatalog.by_id(sid)
		hud.show_status("%s — %d left" % [String(info.get("name", sid)), GameState.get_streak_charges(sid)], 3.0)
	_refresh_hud()


func _refresh_hud() -> void:
	var hud := get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("refresh_streak_buttons"):
		hud.refresh_streak_buttons()


func _slot_id(slot: int) -> String:
	if slot < 0 or slot >= GameState.equipped_streaks.size():
		return ""
	return String(GameState.equipped_streaks[slot])


func _fire_streak(sid: String, point: Vector3, aimed: bool) -> void:
	var at := point if aimed else _look_point()
	match sid:
		"recon_drone":
			_tag_all_guards(12.0)
		"mortar":
			_mortar_at(at)
		"fangs":
			_spawn_dog(40.0)
		"emp":
			_emp_alarms()
		"overwatch":
			_sniper_overwatch(3)
		"gunship":
			_gunship(8.0, at)
		_:
			pass


func _look_point() -> Vector3:
	var player := get_tree().get_first_node_in_group("player") as Node3D
	if player == null:
		return Vector3.ZERO
	var cam: Camera3D = player.get_node_or_null("Head/Camera3D") as Camera3D
	if cam == null:
		cam = player.get_viewport().get_camera_3d()
	if cam == null:
		return player.global_position
	var origin := cam.global_position
	var dir := -cam.global_transform.basis.z
	var space: PhysicsDirectSpaceState3D = player.get_world_3d().direct_space_state
	if space == null:
		return origin + dir * 18.0
	var q := PhysicsRayQueryParameters3D.create(origin, origin + dir * 120.0)
	q.collision_mask = 1 | 4
	var hit: Dictionary = space.intersect_ray(q)
	return hit.get("position", origin + dir * 28.0)


func _update_aim() -> void:
	aim_point = _look_point()
	if is_instance_valid(_marker):
		_marker.global_position = aim_point + Vector3(0, 0.06, 0)


func _ensure_marker() -> void:
	if is_instance_valid(_marker):
		return
	var host := get_tree().current_scene
	if host == null:
		return
	_marker = Node3D.new()
	_marker.name = "SupportAimMarker"
	host.add_child(_marker)
	var ring := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = 1.7
	disc.bottom_radius = 1.7
	disc.height = 0.06
	ring.mesh = disc
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1.0, 0.45, 0.12, 0.55)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ring.material_override = mat
	_marker.add_child(ring)
	var beam := MeshInstance3D.new()
	var col := CylinderMesh.new()
	col.top_radius = 0.07
	col.bottom_radius = 0.07
	col.height = 7.0
	beam.mesh = col
	beam.position = Vector3(0, 3.5, 0)
	var beam_mat := StandardMaterial3D.new()
	beam_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	beam_mat.albedo_color = Color(1.0, 0.72, 0.25, 0.85)
	beam_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	beam.material_override = beam_mat
	_marker.add_child(beam)
	_marker.visible = false


func _tag_all_guards(duration: float) -> void:
	_active_until["recon_drone"] = Time.get_ticks_msec() + int(duration * 1000.0)
	for g in get_tree().get_nodes_in_group("guards"):
		if is_instance_valid(g) and g.has_method("set_tagged"):
			g.set_tagged(true)
		elif is_instance_valid(g) and "tagged" in g:
			g.tagged = true
		if is_instance_valid(g) and g.get("label"):
			var lbl = g.get("label")
			if lbl is Label3D:
				(lbl as Label3D).modulate = Color(0.3, 0.95, 1.0)
	# Untag later
	get_tree().create_timer(duration).timeout.connect(_untag_guards)


func _untag_guards() -> void:
	for g in get_tree().get_nodes_in_group("guards"):
		if is_instance_valid(g) and g.has_method("set_tagged"):
			g.set_tagged(false)
		if is_instance_valid(g) and g.get("label"):
			var lbl = g.get("label")
			if lbl is Label3D:
				(lbl as Label3D).modulate = Color.WHITE


func _mortar_at(target: Vector3) -> void:
	var player := get_tree().get_first_node_in_group("player")
	NoiseBus.emit_noise(target, 90.0, "mortar")
	for g in get_tree().get_nodes_in_group("guards"):
		if not is_instance_valid(g) or not (g is Node3D):
			continue
		var d := (g as Node3D).global_position.distance_to(target)
		if d <= 8.0 and g.has_method("apply_damage"):
			g.apply_damage(180.0 * (1.0 - d / 8.0), target, player, "BLAST")
	var Ordnance = load("res://scripts/items/throwable_ordnance.gd")
	if Ordnance and Ordnance.has_method("spawn_explosion_fx"):
		Ordnance.spawn_explosion_fx(get_tree().current_scene, target, 8.0)


func _spawn_dog(duration: float) -> void:
	var player := get_tree().get_first_node_in_group("player") as Node3D
	if player == null:
		return
	if is_instance_valid(_dog):
		_dog.queue_free()
	_dog = Node3D.new()
	_dog.name = "FangsDog"
	get_tree().current_scene.add_child(_dog)
	_dog.global_position = player.global_position + Vector3(1.2, 0, 0.5)
	# Simple visual
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.45, 0.55, 0.9)
	mesh.mesh = box
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.35, 0.22, 0.12)
	mesh.material_override = mat
	_dog.add_child(mesh)
	_active_until["fangs"] = Time.get_ticks_msec() + int(duration * 1000.0)
	get_tree().create_timer(duration).timeout.connect(func():
		if is_instance_valid(_dog):
			_dog.queue_free()
			_dog = null
	)


func _tick_companions() -> void:
	if not is_instance_valid(_dog):
		return
	var player := get_tree().get_first_node_in_group("player") as Node3D
	if player == null:
		return
	# Chase nearest guard
	var nearest: Node3D = null
	var best := 9999.0
	for g in get_tree().get_nodes_in_group("guards"):
		if not is_instance_valid(g) or not (g is Node3D):
			continue
		if g.has_method("is_alive") and not g.is_alive():
			continue
		var d := (g as Node3D).global_position.distance_to(_dog.global_position)
		if d < best:
			best = d
			nearest = g as Node3D
	var target_pos := player.global_position + Vector3(1.0, 0, 0.4)
	if nearest:
		target_pos = nearest.global_position
		if best < 1.4 and nearest.has_method("apply_damage"):
			nearest.apply_damage(35.0, _dog.global_position, player, "LIMBS")
	_dog.global_position = _dog.global_position.lerp(target_pos + Vector3(0, 0.2, 0), 0.08)


func _emp_alarms() -> void:
	for a in get_tree().get_nodes_in_group("alarms"):
		if is_instance_valid(a):
			if "disabled" in a:
				a.disabled = true
			if "triggered" in a:
				a.triggered = false
			if a.has_method("_update_visual"):
				a._update_visual()
			if a.has_method("jam"):
				a.jam()
	var hud := get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("show_status"):
		hud.show_status("EMP — alarms offline", 2.5)


func _sniper_overwatch(count: int) -> void:
	var player := get_tree().get_first_node_in_group("player") as Node3D
	var killed := 0
	var candidates: Array = []
	for g in get_tree().get_nodes_in_group("guards"):
		if not is_instance_valid(g) or not (g is Node3D):
			continue
		if g.has_method("is_alive") and not g.is_alive():
			continue
		var d := 999.0
		if player:
			d = (g as Node3D).global_position.distance_to(player.global_position)
		if d > 12.0:
			candidates.append({"g": g, "d": d})
	candidates.sort_custom(func(a, b): return float(a["d"]) > float(b["d"]))
	for c in candidates:
		if killed >= count:
			break
		var g = c["g"]
		if g.has_method("apply_damage"):
			g.apply_damage(9999.0, (g as Node3D).global_position + Vector3(0, 1.6, 0), player, "HEAD")
			killed += 1


func _gunship(duration: float, center: Vector3) -> void:
	_gunship_center = center
	_active_until["gunship"] = Time.get_ticks_msec() + int(duration * 1000.0)
	var ticks := int(duration / 0.45)
	for i in range(ticks):
		get_tree().create_timer(0.45 * float(i)).timeout.connect(_gunship_burst)


func _gunship_burst() -> void:
	var player := get_tree().get_first_node_in_group("player") as Node3D
	if player == null:
		return
	var center := _gunship_center
	NoiseBus.emit_noise(center, 55.0, "gunship")
	for g in get_tree().get_nodes_in_group("guards"):
		if not is_instance_valid(g) or not (g is Node3D):
			continue
		var d := (g as Node3D).global_position.distance_to(center)
		if d <= 18.0 and g.has_method("apply_damage"):
			g.apply_damage(28.0, (g as Node3D).global_position, player, "TORSO")
