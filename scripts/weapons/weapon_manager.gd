extends Node
class_name WeaponManager
## Two firearm slots (1/2) drawn from a carried pool of up to 3 weapons via the
## weapon wheel. Lethals and gadgets are separate (G / Q). Melee takedowns stay on F.

signal ammo_changed(mag: int, reserve: int, weapon_name: String)
signal weapon_switched(weapon_name: String)
signal lethal_changed(name: String, count: int)

const ARROW_SCENE := preload("res://scenes/items/arrow.tscn")
const KNIFE_SCENE := preload("res://scenes/items/thrown_knife.tscn")
const ThrowableOrdnance = preload("res://scripts/items/throwable_ordnance.gd")

@export var camera_path: NodePath

# 2-slot inventory (0: Slot 1, 1: Slot 2)
var slots: Array[WeaponData] = []
var mags: Array[int] = [0, 0]
var reserves: Array[int] = [0, 0]
var active_slot: int = 0

# Backward-compatible aliases for tests & HUD
var primary: WeaponData
var secondary: WeaponData
var active_is_primary: bool = true

## Separate lethal inventory (not a weapon slot).
var lethal: WeaponData
var lethal_count: int = 0

var _cooldown: float = 0.0
var _reloading: bool = false
var _reload_timer: float = 0.0

var viewmodel_rig: ViewmodelRig


func _ready() -> void:
	_equip_from_loadout()
	call_deferred("_bind_viewmodel_rig")


func _bind_viewmodel_rig() -> void:
	var cam := get_node_or_null(camera_path) as Camera3D
	if cam:
		viewmodel_rig = cam.get_node_or_null("Viewmodels") as ViewmodelRig
	_refresh_viewmodel(false)


func _refresh_viewmodel(animate_swap: bool = true) -> void:
	if is_instance_valid(viewmodel_rig):
		var active := get_active()
		viewmodel_rig.show_weapon(active.id, animate_swap)
		viewmodel_rig.set_bow_arrow_visible(active.id != GameState.WeaponId.BOW or _mag() > 0)


func _equip_from_loadout() -> void:
	slots.clear()
	mags = [0, 0]
	reserves = [0, 0]
	var ids: Array[GameState.WeaponId] = [
		GameState.selected_primary,
		GameState.selected_secondary,
	]
	for i in range(ids.size()):
		var wid := ids[i]
		if not GameState.is_carried_weapon_id(wid):
			wid = GameState.WeaponId.PISTOL if i == 1 else GameState.WeaponId.RIFLE
		var w := WeaponData.from_id(wid, GameState.get_weapon_mods(wid))
		slots.append(w)
		mags[i] = w.magazine_size
		reserves[i] = w.reserve_ammo
	primary = slots[0]
	secondary = slots[1]
	active_slot = 0
	active_is_primary = true
	_equip_lethal_from_loadout()
	_emit_ammo()


func _equip_lethal_from_loadout() -> void:
	var lid := GameState.selected_throwable
	if not GameState.is_lethal_weapon_id(lid):
		lid = GameState.WeaponId.KNIFE
	lethal = WeaponData.from_id(lid, {})
	# Throwing knives: silent, retrievable, headshot one-shots via HitZone
	if lid == GameState.WeaponId.KNIFE:
		lethal.display_name = "Throwing Knives"
		lethal.projectile_kind = "knife"
		lethal.is_silent = true
		lethal.noise_loudness = 2.5
		lethal.damage = 100.0
		lethal.retrievable_projectile = true
		lethal.magazine_size = 4
		lethal.reserve_ammo = 4
	lethal_count = lethal.magazine_size + lethal.reserve_ammo
	lethal_changed.emit(lethal.display_name, lethal_count)


func refresh_slot_from_loadout(slot_idx: int) -> void:
	var idx := clampi(slot_idx, 0, 1)
	var wid := GameState.selected_primary if idx == 0 else GameState.selected_secondary
	if not GameState.is_carried_weapon_id(wid):
		return
	var w := WeaponData.from_id(wid, GameState.get_weapon_mods(wid))
	while slots.size() <= idx:
		slots.append(WeaponData.make_pistol())
		mags.append(0)
		reserves.append(0)
	slots[idx] = w
	mags[idx] = w.magazine_size
	reserves[idx] = w.reserve_ammo
	if idx == 0:
		primary = w
	else:
		secondary = w
	if active_slot == idx:
		_refresh_viewmodel()
		_emit_ammo()


func set_lethal(wid: GameState.WeaponId) -> void:
	if not GameState.is_lethal_weapon_id(wid):
		return
	GameState.selected_throwable = wid
	var keep := lethal_count
	_equip_lethal_from_loadout()
	# Preserve remaining throws when cycling owned lethals mid-mission if possible
	lethal_count = mini(keep, lethal.magazine_size + lethal.reserve_ammo)
	if lethal_count <= 0:
		lethal_count = lethal.magazine_size
	lethal_changed.emit(lethal.display_name, lethal_count)


func try_throw_lethal() -> bool:
	if lethal == null or lethal_count <= 0 or _cooldown > 0.0:
		return false
	lethal_count -= 1
	_cooldown = maxf(lethal.fire_rate, 0.35)
	var cam := get_node_or_null(camera_path) as Camera3D
	var origin: Vector3
	var dir: Vector3
	if cam:
		origin = cam.global_position
		dir = -cam.global_transform.basis.z
	else:
		origin = get_parent().global_position + Vector3.UP * 1.6
		dir = -get_parent().global_transform.basis.z
	NoiseBus.emit_noise(origin, lethal.noise_loudness, lethal.display_name)
	if is_instance_valid(viewmodel_rig):
		viewmodel_rig.play_fire(lethal.id)
	match lethal.projectile_kind:
		"knife":
			_spawn_projectile(KNIFE_SCENE, origin, dir, lethal)
		"frag", "molotov", "c4", "prox_mine":
			ThrowableOrdnance.spawn_ordnance(get_tree().current_scene, origin + dir * 0.65, dir, lethal.projectile_kind, lethal.damage, lethal.explosion_radius, get_parent())
		_:
			# Throwing axe etc.
			if lethal.projectile_kind == "knife" or lethal.id == GameState.WeaponId.THROWING_AXE:
				_spawn_projectile(KNIFE_SCENE, origin, dir, lethal)
			else:
				ThrowableOrdnance.spawn_ordnance(get_tree().current_scene, origin + dir * 0.65, dir, "frag", lethal.damage, lethal.explosion_radius, get_parent())
	lethal_changed.emit(lethal.display_name, lethal_count)
	return true


func has_lethal() -> bool:
	return lethal != null and lethal_count > 0


func get_active() -> WeaponData:
	if slots.is_empty():
		return WeaponData.make_pistol()
	return slots[clampi(active_slot, 0, slots.size() - 1)]


## Sniper/variable-scope magnification steps (4x → 6x → 8x → 4x).
const SCOPE_ZOOM_MULTS := [4.0, 6.0, 8.0]
const HIP_FOV := 70.0
var scope_zoom_step: int = 0


func get_aim_fov() -> float:
	var w := get_active()
	if w.scope_overlay:
		var mult: float = float(SCOPE_ZOOM_MULTS[clampi(scope_zoom_step, 0, SCOPE_ZOOM_MULTS.size() - 1)])
		return HIP_FOV / mult
	return w.aim_fov


func get_scope_zoom_mult() -> float:
	if not has_scope_overlay():
		return 1.0
	return float(SCOPE_ZOOM_MULTS[clampi(scope_zoom_step, 0, SCOPE_ZOOM_MULTS.size() - 1)])


func cycle_scope_zoom(dir: int = 1) -> float:
	if not has_scope_overlay():
		return 1.0
	scope_zoom_step = (scope_zoom_step + dir) % SCOPE_ZOOM_MULTS.size()
	if scope_zoom_step < 0:
		scope_zoom_step = SCOPE_ZOOM_MULTS.size() - 1
	return get_scope_zoom_mult()


func has_scope_overlay() -> bool:
	return get_active().scope_overlay


func can_takedown(player: Node3D) -> bool:
	var cam := get_node_or_null(camera_path) as Camera3D
	if cam == null:
		return false
	var space := get_viewport().get_world_3d().direct_space_state
	var origin := cam.global_position
	var dir := -cam.global_transform.basis.z
	var query := PhysicsRayQueryParameters3D.create(origin, origin + dir * 2.4)
	query.collision_mask = 4
	query.exclude = [_player_rid()]
	var hit := space.intersect_ray(query)
	if hit.is_empty():
		return false
	var guard = hit.collider
	if guard == null:
		return false
	if guard.has_method("melee_takedown"):
		return guard.has_method("is_alive") == false or guard.is_alive()
	if guard.get_parent() and guard.get_parent().has_method("melee_takedown"):
		var p = guard.get_parent()
		return p.has_method("is_alive") == false or p.is_alive()
	return false


func needs_reload() -> bool:
	var w := get_active()
	if w.is_melee or w.magazine_size <= 0:
		return false
	return _mag() < w.magazine_size and _reserve() > 0


func _mag() -> int:
	return mags[clampi(active_slot, 0, mags.size() - 1)]


func _reserve() -> int:
	return reserves[clampi(active_slot, 0, reserves.size() - 1)]


func _set_mag(v: int) -> void:
	mags[clampi(active_slot, 0, mags.size() - 1)] = v


func _set_reserve(v: int) -> void:
	reserves[clampi(active_slot, 0, reserves.size() - 1)] = v


func _process(delta: float) -> void:
	_cooldown = maxf(0.0, _cooldown - delta)
	if _reloading:
		_reload_timer -= delta
		if _reload_timer <= 0.0:
			_finish_reload()


func try_fire() -> void:
	var w := get_active()
	if _reloading or _cooldown > 0.0:
		return
	if w.projectile_kind == "melee_swing":
		_fire_shot(w)
		return
	if _mag() <= 0:
		start_reload()
		return
	_fire_shot(w)


func try_fire_held() -> void:
	if get_active().automatic:
		try_fire()


func _fire_shot(w: WeaponData) -> void:
	if w.projectile_kind != "melee_swing":
		_set_mag(_mag() - 1)
	_cooldown = w.fire_rate
	var cam := get_node_or_null(camera_path) as Camera3D
	var origin: Vector3
	var dir: Vector3
	if cam:
		origin = cam.global_position
		dir = -cam.global_transform.basis.z
	else:
		origin = get_parent().global_position + Vector3.UP * 1.6
		dir = -get_parent().global_transform.basis.z

	NoiseBus.emit_noise(origin, w.noise_loudness, w.display_name)
	if is_instance_valid(viewmodel_rig):
		viewmodel_rig.play_fire(w.id)
		if w.id == GameState.WeaponId.BOW:
			viewmodel_rig.set_bow_arrow_visible(_mag() > 0)

	# Apply distinct weapon recoil to player view
	var p := get_parent()
	if is_instance_valid(p) and p.has_method("apply_recoil") and w.recoil_pitch > 0.0:
		var yaw_kick := randf_range(-w.recoil_yaw, w.recoil_yaw)
		p.apply_recoil(w.recoil_pitch, yaw_kick)

	var blend := float(p.get("aim_blend")) if is_instance_valid(p) else 0.0
	var aimed_dir := dir
	if w.spread_deg > 0.05:
		var spread := w.spread_deg
		if blend > 0.01:
			spread = lerpf(w.spread_deg, w.spread_deg * w.ads_spread_mult, blend)
		# Single-projectile weapons get one ADS-tightened direction; pellets each scatter below
		if w.pellet_count <= 1:
			aimed_dir = _apply_spread(dir, spread)

	match w.projectile_kind:
		"arrow", "bolt":
			_spawn_projectile(ARROW_SCENE, origin, aimed_dir, w)
			if _mag() <= 0 and _reserve() > 0:
				start_reload()
		"knife":
			_spawn_projectile(KNIFE_SCENE, origin, aimed_dir, w)
			if _mag() <= 0 and _reserve() > 0:
				start_reload()
		"frag", "molotov", "c4", "prox_mine":
			ThrowableOrdnance.spawn_ordnance(get_tree().current_scene, origin + aimed_dir * 0.65, aimed_dir, w.projectile_kind, w.damage, w.explosion_radius, get_parent())
			if _mag() <= 0 and _reserve() > 0:
				start_reload()
		"tranq":
			_hitscan_tranq(origin, aimed_dir, w)
			if _mag() <= 0 and _reserve() > 0:
				start_reload()
		"melee_swing":
			_melee_swing(origin, aimed_dir, w)
		_:
			var pellets := maxi(1, w.pellet_count)
			var spread := w.spread_deg
			if blend > 0.01:
				spread = lerpf(w.spread_deg, w.spread_deg * w.ads_spread_mult, blend)
			for _i in range(pellets):
				var shot_dir := _apply_spread(dir, spread)
				_hitscan(origin, shot_dir, w)

	_emit_ammo()


func _apply_spread(dir: Vector3, spread_deg: float) -> Vector3:
	if spread_deg <= 0.05:
		return dir
	var rad := deg_to_rad(spread_deg)
	var rx := randf_range(-rad, rad)
	var ry := randf_range(-rad, rad)
	return (dir + Vector3(rx, ry, 0.0)).normalized()


func _hitscan(origin: Vector3, dir: Vector3, w: WeaponData) -> void:
	var space := get_viewport().get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(origin, origin + dir * w.max_range)
	query.collision_mask = 1 | 16 | 32 | 128
	query.collide_with_areas = true
	query.collide_with_bodies = true
	query.exclude = [_player_rid()]
	var hit := space.intersect_ray(query)
	_spawn_tracer(origin, hit.get("position", origin + dir * minf(w.max_range, 42.0)))
	if hit.is_empty():
		return
	_apply_weapon_hit(hit.collider, w.damage, hit.position)


func _hitscan_tranq(origin: Vector3, dir: Vector3, w: WeaponData) -> void:
	var space := get_viewport().get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(origin, origin + dir * w.max_range)
	query.collision_mask = 1 | 4 | 128
	query.collide_with_areas = true
	query.collide_with_bodies = true
	query.exclude = [_player_rid()]
	var hit := space.intersect_ray(query)
	_spawn_tracer(origin, hit.get("position", origin + dir * minf(w.max_range, 42.0)))
	if hit.is_empty():
		return
	var node = hit.collider
	while node:
		if node.has_method("apply_tranq"):
			node.apply_tranq(45.0, get_parent())
			return
		if node is GuardAI:
			# Soft knockout: mark dead for clear count but wake later via timer on a decoy
			if node.has_method("apply_damage"):
				node.apply_damage(9999.0, hit.position, get_parent(), "HEAD")
			return
		node = node.get_parent()


func _melee_swing(origin: Vector3, dir: Vector3, w: WeaponData) -> void:
	var space := get_viewport().get_world_3d().direct_space_state
	# Check center + slight left/right arc rays so melee swings feel generous & crisp
	var offsets: Array[Vector3] = [Vector3.ZERO, Vector3(0.18, 0, 0), Vector3(-0.18, 0, 0)]
	for off in offsets:
		var ray_dir: Vector3 = (dir + off * 0.5).normalized()
		var q := PhysicsRayQueryParameters3D.create(origin, origin + ray_dir * w.max_range)
		q.collision_mask = 4 | 128
		q.collide_with_areas = true
		q.collide_with_bodies = true
		q.exclude = [_player_rid()]
		var hit := space.intersect_ray(q)
		if not hit.is_empty():
			_apply_weapon_hit(hit.collider, w.damage, hit.position)
			return


func _spawn_projectile(scene: PackedScene, origin: Vector3, dir: Vector3, w: WeaponData) -> void:
	var proj := scene.instantiate()
	get_tree().current_scene.add_child(proj)
	proj.global_position = origin + dir * 0.65
	if proj.has_method("launch"):
		proj.launch(dir, w.damage, w.projectile_speed, w.retrievable_projectile, get_parent(), w.arrow_type)


func _spawn_tracer(from: Vector3, to: Vector3) -> void:
	var mesh_inst := MeshInstance3D.new()
	var imm := ImmediateMesh.new()
	mesh_inst.mesh = imm
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1.0, 0.85, 0.3, 0.7)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh_inst.material_override = mat
	get_tree().current_scene.add_child(mesh_inst)
	imm.clear_surfaces()
	imm.surface_begin(Mesh.PRIMITIVE_LINES)
	imm.surface_add_vertex(from)
	imm.surface_add_vertex(to)
	imm.surface_end()
	get_tree().create_timer(0.05).timeout.connect(func():
		if is_instance_valid(mesh_inst):
			mesh_inst.queue_free()
	)


func start_reload() -> void:
	var w := get_active()
	if w.projectile_kind == "melee_swing":
		return
	if _reloading or _mag() >= w.magazine_size or _reserve() <= 0:
		return
	_reloading = true
	_reload_timer = w.reload_time
	if is_instance_valid(viewmodel_rig):
		viewmodel_rig.play_reload(_reload_timer)


func _finish_reload() -> void:
	_reloading = false
	var w := get_active()
	var need := w.magazine_size - _mag()
	var take := mini(need, _reserve())
	_set_mag(_mag() + take)
	_set_reserve(_reserve() - take)
	if is_instance_valid(viewmodel_rig) and w.id == GameState.WeaponId.BOW:
		viewmodel_rig.set_bow_arrow_visible(_mag() > 0)
	_emit_ammo()


func switch_slot(to_primary: bool) -> void:
	select_slot(0 if to_primary else 1)


func select_slot(slot_idx: int) -> void:
	var clamped := clampi(slot_idx, 0, maxi(0, slots.size() - 1))
	if active_slot == clamped:
		return
	active_slot = clamped
	active_is_primary = (active_slot == 0)
	_reloading = false
	# Fresh optic starts at base magnification (4x for scopes).
	scope_zoom_step = 0
	weapon_switched.emit(get_active().display_name)
	_refresh_viewmodel()
	_emit_ammo()


func cycle_slot() -> void:
	## Swap between the two firearm slots only.
	if slots.size() < 2:
		return
	select_slot(1 if active_slot == 0 else 0)


func select_weapon_index(index: int) -> void:
	select_slot(clampi(index - 1, 0, 1))


func _apply_weapon_hit(collider: Object, damage: float, hit_pos: Vector3) -> void:
	if collider == null:
		return
	if collider is HitZone:
		var zone := collider as HitZone
		var owner_node := zone.get_damage_owner()
		if owner_node and owner_node.has_method("apply_hit_zone"):
			owner_node.apply_hit_zone(zone, damage, hit_pos, get_parent())
		elif owner_node and owner_node.has_method("apply_damage"):
			owner_node.apply_damage(zone.resolve_damage(damage), hit_pos, get_parent(), zone.zone_name())
		return
	if collider.has_method("apply_damage"):
		collider.apply_damage(damage, hit_pos, get_parent())
	elif collider.get_parent() and collider.get_parent().has_method("apply_damage"):
		collider.get_parent().apply_damage(damage, hit_pos, get_parent())


func try_melee_takedown(player: Node3D) -> bool:
	var cam := get_node_or_null(camera_path) as Camera3D
	if cam == null:
		return false
	var space := get_viewport().get_world_3d().direct_space_state
	var origin := cam.global_position
	var dir := -cam.global_transform.basis.z
	var query := PhysicsRayQueryParameters3D.create(origin, origin + dir * 2.4)
	query.collision_mask = 4
	query.exclude = [_player_rid()]
	var hit := space.intersect_ray(query)
	if hit.is_empty():
		return false
	var guard = hit.collider
	if guard == null:
		return false
	if guard.has_method("melee_takedown"):
		var behind: bool = bool(guard.melee_takedown(player))
		if is_instance_valid(viewmodel_rig):
			viewmodel_rig.play_takedown(behind)
		var hud := get_tree().get_first_node_in_group("hud")
		if hud and hud.has_method("show_status"):
			hud.show_status("Stealth Back Takedown!" if behind else "Front CQC Takedown!", 1.6)
		NoiseBus.emit_noise(guard.global_position, 2.0 if behind else 6.0, "melee_takedown")
		return true
	if guard.get_parent() and guard.get_parent().has_method("melee_takedown"):
		var behind2: bool = bool(guard.get_parent().melee_takedown(player))
		if is_instance_valid(viewmodel_rig):
			viewmodel_rig.play_takedown(behind2)
		var hud2 := get_tree().get_first_node_in_group("hud")
		if hud2 and hud2.has_method("show_status"):
			hud2.show_status("Stealth Back Takedown!" if behind2 else "Front CQC Takedown!", 1.6)
		NoiseBus.emit_noise(guard.global_position, 2.0 if behind2 else 6.0, "melee_takedown")
		return true
	return false


func add_retrievable_ammo(weapon_hint: String = "") -> void:
	if weapon_hint == "knife" and lethal != null and lethal.projectile_kind == "knife":
		lethal_count += 1
		lethal_changed.emit(lethal.display_name, lethal_count)
		return
	for i in range(slots.size()):
		if weapon_hint == "arrow" and slots[i].id in [GameState.WeaponId.BOW, GameState.WeaponId.CROSSBOW, GameState.WeaponId.HUNTER_BOW]:
			reserves[i] += 1
			_emit_ammo()
			return
	if get_active().retrievable_projectile:
		_set_reserve(_reserve() + 1)
	_emit_ammo()


func _emit_ammo() -> void:
	var w := get_active()
	var slot_tag := "[%d/%d] %s" % [active_slot + 1, 2, w.display_name]
	ammo_changed.emit(_mag(), _reserve(), slot_tag)


func _player_rid() -> RID:
	var p := get_parent()
	if p is CollisionObject3D:
		return (p as CollisionObject3D).get_rid()
	return RID()
