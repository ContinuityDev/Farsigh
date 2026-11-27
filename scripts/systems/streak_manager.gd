extends Node
## Equipped scorestreaks: earn via undetected kill chain, activate from HUD/touch.


var _used: Array = [false, false, false]
var _active_until: Dictionary = {}  # streak_id -> msec
var _dog: Node3D = null


func _ready() -> void:
	add_to_group("streak_manager")
	name = "StreakManager"
	set_process(true)


var _key_latch: Array = [false, false, false]
var _hud_refresh_acc: float = 0.0


func _process(delta: float) -> void:
	_poll_hotkeys()
	_tick_companions()
	_hud_refresh_acc += delta
	if _hud_refresh_acc >= 0.35:
		_hud_refresh_acc = 0.0
		var hud := get_tree().get_first_node_in_group("hud")
		if hud and hud.has_method("refresh_streak_buttons"):
			hud.refresh_streak_buttons()


func _poll_hotkeys() -> void:
	var keys := [KEY_7, KEY_8, KEY_9]
	for i in range(3):
		var down := Input.is_physical_key_pressed(keys[i])
		if down and not _key_latch[i]:
			try_activate(i)
		_key_latch[i] = down


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
	if not GameState.consume_streak_charge(sid):
		return false
	_fire_streak(sid)
	var hud := get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("show_status"):
		var info := StreakCatalog.by_id(sid)
		hud.show_status("%s — %d left" % [String(info.get("name", sid)), GameState.get_streak_charges(sid)], 3.0)
	if hud and hud.has_method("refresh_streak_buttons"):
		hud.refresh_streak_buttons()
	return true


func _slot_id(slot: int) -> String:
	if slot < 0 or slot >= GameState.equipped_streaks.size():
		return ""
	return String(GameState.equipped_streaks[slot])


func _fire_streak(sid: String) -> void:
	match sid:
		"recon_drone":
			_tag_all_guards(12.0)
		"mortar":
			_mortar_look_point()
		"fangs":
			_spawn_dog(40.0)
		"emp":
			_emp_alarms()
		"overwatch":
			_sniper_overwatch(3)
		"gunship":
			_gunship(8.0)
		_:
			pass


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


func _mortar_look_point() -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player == null:
		return
	var cam: Camera3D = player.get_node_or_null("CameraPivot/Camera3D") as Camera3D
	if cam == null:
		cam = player.get_viewport().get_camera_3d()
	if cam == null:
		return
	var origin := cam.global_position
	var dir := -cam.global_transform.basis.z
	var space: PhysicsDirectSpaceState3D = player.get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(origin, origin + dir * 120.0)
	q.collision_mask = 1 | 4
	var hit: Dictionary = space.intersect_ray(q)
	var target: Vector3 = hit.get("position", origin + dir * 40.0)
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


func _gunship(duration: float) -> void:
	_active_until["gunship"] = Time.get_ticks_msec() + int(duration * 1000.0)
	var ticks := int(duration / 0.45)
	for i in range(ticks):
		get_tree().create_timer(0.45 * float(i)).timeout.connect(_gunship_burst)


func _gunship_burst() -> void:
	var player := get_tree().get_first_node_in_group("player") as Node3D
	if player == null:
		return
	var center := player.global_position
	NoiseBus.emit_noise(center, 55.0, "gunship")
	for g in get_tree().get_nodes_in_group("guards"):
		if not is_instance_valid(g) or not (g is Node3D):
			continue
		var d := (g as Node3D).global_position.distance_to(center)
		if d <= 18.0 and g.has_method("apply_damage"):
			g.apply_damage(28.0, (g as Node3D).global_position, player, "TORSO")
