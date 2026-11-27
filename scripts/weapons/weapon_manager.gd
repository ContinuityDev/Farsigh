extends Node
class_name WeaponManager
## Owns equipped weapons, firing, reloading, and ammo HUD updates.

signal ammo_changed(mag: int, reserve: int, weapon_name: String)
signal weapon_switched(weapon_name: String)

@export var camera_path: NodePath

var primary: WeaponData
var secondary: WeaponData
var active_is_primary: bool = true

var primary_mag: int = 0
var primary_reserve: int = 0
var secondary_mag: int = 0
var secondary_reserve: int = 0

var _cooldown: float = 0.0
var _reloading: bool = false
var _reload_timer: float = 0.0

const RELOAD_TIME := 1.4
const ARROW_SCENE := preload("res://scenes/items/arrow.tscn")
const KNIFE_SCENE := preload("res://scenes/items/thrown_knife.tscn")


func _ready() -> void:
	_equip_from_loadout()


func _equip_from_loadout() -> void:
	primary = WeaponData.from_id(GameState.selected_primary)
	secondary = WeaponData.from_id(GameState.selected_secondary)
	primary_mag = primary.magazine_size
	primary_reserve = primary.reserve_ammo
	secondary_mag = secondary.magazine_size
	secondary_reserve = secondary.reserve_ammo
	_emit_ammo()


func get_active() -> WeaponData:
	return primary if active_is_primary else secondary


func _mag() -> int:
	return primary_mag if active_is_primary else secondary_mag


func _reserve() -> int:
	return primary_reserve if active_is_primary else secondary_reserve


func _set_mag(v: int) -> void:
	if active_is_primary:
		primary_mag = v
	else:
		secondary_mag = v


func _set_reserve(v: int) -> void:
	if active_is_primary:
		primary_reserve = v
	else:
		secondary_reserve = v


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
	if _mag() <= 0:
		start_reload()
		return
	_fire_shot(w)


func try_fire_held() -> void:
	if get_active().automatic:
		try_fire()


func _fire_shot(w: WeaponData) -> void:
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

	match w.id:
		GameState.WeaponId.BOW:
			_spawn_projectile(ARROW_SCENE, origin, dir, w)
		GameState.WeaponId.KNIFE:
			_spawn_projectile(KNIFE_SCENE, origin, dir, w)
		_:
			_hitscan(origin, dir, w)

	_emit_ammo()


func _hitscan(origin: Vector3, dir: Vector3, w: WeaponData) -> void:
	var space := get_viewport().get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(origin, origin + dir * w.max_range)
	query.collision_mask = 1 | 4 | 16 | 32
	query.exclude = [_player_rid()]
	var hit := space.intersect_ray(query)
	_spawn_tracer(origin, hit.get("position", origin + dir * minf(w.max_range, 40.0)))
	if hit.is_empty():
		return
	var collider = hit.collider
	if collider and collider.has_method("apply_damage"):
		collider.apply_damage(w.damage, hit.position, get_parent())
	elif collider and collider.get_parent() and collider.get_parent().has_method("apply_damage"):
		collider.get_parent().apply_damage(w.damage, hit.position, get_parent())


func _spawn_projectile(scene: PackedScene, origin: Vector3, dir: Vector3, w: WeaponData) -> void:
	var proj := scene.instantiate()
	get_tree().current_scene.add_child(proj)
	proj.global_position = origin + dir * 0.6
	if proj.has_method("launch"):
		proj.launch(dir, w.damage, w.projectile_speed, w.retrievable_projectile, get_parent())


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
	get_tree().create_timer(0.05).timeout.connect(mesh_inst.queue_free)


func start_reload() -> void:
	var w := get_active()
	if _reloading or _mag() >= w.magazine_size or _reserve() <= 0:
		return
	_reloading = true
	_reload_timer = RELOAD_TIME


func _finish_reload() -> void:
	_reloading = false
	var w := get_active()
	var need := w.magazine_size - _mag()
	var take := mini(need, _reserve())
	_set_mag(_mag() + take)
	_set_reserve(_reserve() - take)
	_emit_ammo()


func switch_slot(to_primary: bool) -> void:
	if active_is_primary == to_primary:
		return
	active_is_primary = to_primary
	_reloading = false
	weapon_switched.emit(get_active().display_name)
	_emit_ammo()


func select_weapon_index(index: int) -> void:
	match index:
		1, 3:
			switch_slot(true)
		2, 4:
			switch_slot(false)


func try_melee_takedown(player: Node3D) -> bool:
	var cam := get_node_or_null(camera_path) as Camera3D
	if cam == null:
		return false
	var space := get_viewport().get_world_3d().direct_space_state
	var origin := cam.global_position
	var dir := -cam.global_transform.basis.z
	var query := PhysicsRayQueryParameters3D.create(origin, origin + dir * 2.2)
	query.collision_mask = 4
	query.exclude = [_player_rid()]
	var hit := space.intersect_ray(query)
	if hit.is_empty():
		return false
	var guard = hit.collider
	if guard == null:
		return false
	if guard.has_method("melee_takedown"):
		guard.melee_takedown(player)
		NoiseBus.emit_noise(guard.global_position, 2.0, "melee_takedown")
		return true
	if guard.get_parent() and guard.get_parent().has_method("melee_takedown"):
		guard.get_parent().melee_takedown(player)
		NoiseBus.emit_noise(guard.global_position, 2.0, "melee_takedown")
		return true
	return false


func add_retrievable_ammo(weapon_hint: String = "") -> void:
	# Picked up arrow / knife
	if weapon_hint == "arrow" and primary.id == GameState.WeaponId.BOW:
		primary_reserve += 1
	elif weapon_hint == "knife" and secondary.id == GameState.WeaponId.KNIFE:
		secondary_reserve += 1
	elif get_active().retrievable_projectile:
		_set_reserve(_reserve() + 1)
	_emit_ammo()


func _emit_ammo() -> void:
	ammo_changed.emit(_mag(), _reserve(), get_active().display_name)


func _player_rid() -> RID:
	var p := get_parent()
	if p is CollisionObject3D:
		return (p as CollisionObject3D).get_rid()
	return RID()
