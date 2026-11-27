extends Node3D
class_name ViewmodelRig
## First-person weapon viewmodels (suppressed pistol, rifle, hunting bow + arrow,
## throwing knife) with idle/walk-bob, fire, reload, swap animations and muzzle flash.

@onready var pistol_slot: Node3D = $PistolSlot
@onready var rifle_slot: Node3D = $RifleSlot
@onready var bow_slot: Node3D = $BowSlot
@onready var knife_slot: Node3D = $KnifeSlot

var _slots: Dictionary = {}
var _base_pos: Dictionary = {}
var _base_rot: Dictionary = {}
var _muzzle_flashes: Dictionary = {}
var _magazines: Dictionary = {}
var _pistol_slide: Node3D = null
var _bow_arrow: Node3D = null
var _bow_string: Node3D = null

var _active_id: GameState.WeaponId = GameState.WeaponId.PISTOL
var _idle_time: float = 0.0
var _move_factor: float = 0.0

# Animation state timers (kept lightweight & deterministic for WebGL)
var _fire_t: float = 0.0
var _fire_dur: float = 0.18
var _flash_t: float = 0.0
var _reload_t: float = 0.0
var _reload_dur: float = 1.4
var _swap_t: float = 0.0
var _swap_dur: float = 0.28
var _inspect_t: float = 0.0
var _inspect_dur: float = 1.65
var _takedown_t: float = 0.0
var _takedown_dur: float = 0.45
var _takedown_behind: bool = true
var _vault_p: float = 0.0
var _carrying: bool = false
var _dragging: bool = false
var _sway: Vector2 = Vector2.ZERO
var _aim_blend: float = 0.0


func _ready() -> void:
	_slots = {
		GameState.WeaponId.PISTOL: pistol_slot,
		GameState.WeaponId.RIFLE: rifle_slot,
		GameState.WeaponId.BOW: bow_slot,
		GameState.WeaponId.KNIFE: knife_slot,
	}
	_base_pos = {
		GameState.WeaponId.PISTOL: Vector3(0.21, -0.19, -0.40),
		GameState.WeaponId.RIFLE: Vector3(0.24, -0.21, -0.47),
		GameState.WeaponId.BOW: Vector3(0.19, -0.13, -0.45),
		GameState.WeaponId.KNIFE: Vector3(0.23, -0.19, -0.37),
	}
	_base_rot = {
		GameState.WeaponId.PISTOL: Vector3(0.0, 2.0, 0.0),
		GameState.WeaponId.RIFLE: Vector3(0.0, 2.5, 0.0),
		GameState.WeaponId.BOW: Vector3(0.0, 6.0, 16.0),
		GameState.WeaponId.KNIFE: Vector3(-12.0, 14.0, -8.0),
	}
	_build_all_viewmodels()
	hide_all()


func _build_all_viewmodels() -> void:
	_build_pistol(pistol_slot)
	_build_rifle(rifle_slot)
	_build_bow(bow_slot)
	_build_knife(knife_slot)


func _clear_slot(slot: Node3D) -> void:
	if not is_instance_valid(slot):
		return
	for c in slot.get_children():
		c.queue_free()


func _build_pistol(slot: Node3D) -> void:
	if not is_instance_valid(slot):
		return
	_clear_slot(slot)
	var gunmetal := Color(0.16, 0.17, 0.19)
	var polymer := Color(0.11, 0.12, 0.13)
	var suppressor_col := Color(0.10, 0.11, 0.12)
	var glove := Color(0.18, 0.17, 0.16)
	var sleeve := Color(0.24, 0.28, 0.20)

	var root := Node3D.new()
	root.name = "ModelRoot"
	slot.add_child(root)

	# Slide (animated blowback on fire)
	_pistol_slide = Node3D.new()
	_pistol_slide.name = "Slide"
	root.add_child(_pistol_slide)
	ProcMesh.add_part(_pistol_slide, ProcMesh.box_mesh(Vector3(0.040, 0.044, 0.205), gunmetal, 0.42, 0.55), Vector3(0, 0.032, -0.02))
	# Rear sight posts + glowing tritium front sight
	ProcMesh.add_part(_pistol_slide, ProcMesh.box_mesh(Vector3(0.008, 0.010, 0.012), polymer), Vector3(-0.011, 0.058, 0.072))
	ProcMesh.add_part(_pistol_slide, ProcMesh.box_mesh(Vector3(0.008, 0.010, 0.012), polymer), Vector3(0.011, 0.058, 0.072))
	var front_sight := ProcMesh.box_mesh(Vector3(0.006, 0.011, 0.010), Color(0.2, 0.95, 0.45))
	front_sight.material_override = ProcMesh.emissive(Color(0.25, 1.0, 0.45), 1.8)
	ProcMesh.add_part(_pistol_slide, front_sight, Vector3(0, 0.059, -0.11))

	# Lower frame & rail
	ProcMesh.add_part(root, ProcMesh.box_mesh(Vector3(0.036, 0.028, 0.19), polymer, 0.72, 0.15), Vector3(0, 0.0, -0.015))
	ProcMesh.add_part(root, ProcMesh.box_mesh(Vector3(0.012, 0.028, 0.055), polymer), Vector3(0, -0.026, -0.02))
	# Grip
	ProcMesh.add_part(root, ProcMesh.box_mesh(Vector3(0.034, 0.105, 0.052), polymer, 0.85, 0.08), Vector3(0, -0.062, 0.048), Vector3(-14, 0, 0))

	# Detachable magazine (drops during reload)
	var mag := Node3D.new()
	mag.name = "Magazine"
	mag.position = Vector3(0, -0.112, 0.060)
	root.add_child(mag)
	ProcMesh.add_part(mag, ProcMesh.box_mesh(Vector3(0.032, 0.024, 0.054), gunmetal, 0.5, 0.45), Vector3.ZERO, Vector3(-14, 0, 0))
	_magazines[GameState.WeaponId.PISTOL] = mag

	# Threaded suppressor barrel
	ProcMesh.add_part(root, ProcMesh.cylinder_mesh(0.017, 0.185, suppressor_col, 0.48, 0.50, 10), Vector3(0, 0.028, -0.21), Vector3(90, 0, 0))
	ProcMesh.add_part(root, ProcMesh.cylinder_mesh(0.020, 0.016, gunmetal, 0.35, 0.65, 10), Vector3(0, 0.028, -0.125), Vector3(90, 0, 0))

	# Gloved hands + forearms
	ProcMesh.add_part(root, ProcMesh.box_mesh(Vector3(0.062, 0.075, 0.082), glove, 0.88, 0.04), Vector3(0.006, -0.062, 0.055), Vector3(-12, 0, 0))
	ProcMesh.add_part(root, ProcMesh.box_mesh(Vector3(0.070, 0.068, 0.24), sleeve, 0.90, 0.02), Vector3(0.035, -0.105, 0.185), Vector3(-16, -8, 0))
	ProcMesh.add_part(root, ProcMesh.box_mesh(Vector3(0.058, 0.064, 0.078), glove, 0.88, 0.04), Vector3(-0.026, -0.070, 0.045), Vector3(-8, 12, 0))

	# Compact suppressed muzzle flash at suppressor tip
	var flash := _make_muzzle_flash(0.055, Color(1.0, 0.85, 0.45, 0.85))
	flash.position = Vector3(0, 0.028, -0.315)
	root.add_child(flash)
	_muzzle_flashes[GameState.WeaponId.PISTOL] = flash


func _build_rifle(slot: Node3D) -> void:
	if not is_instance_valid(slot):
		return
	_clear_slot(slot)
	var steel := Color(0.15, 0.16, 0.18)
	var handguard := Color(0.20, 0.22, 0.19)
	var polymer := Color(0.11, 0.12, 0.13)
	var glove := Color(0.18, 0.17, 0.16)
	var sleeve := Color(0.24, 0.28, 0.20)

	var root := Node3D.new()
	root.name = "ModelRoot"
	slot.add_child(root)

	# Upper + lower receiver
	ProcMesh.add_part(root, ProcMesh.box_mesh(Vector3(0.052, 0.068, 0.27), steel, 0.45, 0.55), Vector3(0, 0.015, 0.0))
	# Top rail
	ProcMesh.add_part(root, ProcMesh.box_mesh(Vector3(0.032, 0.012, 0.26), polymer), Vector3(0, 0.055, -0.01))
	# Red-dot holographic sight housing + glowing reticle
	ProcMesh.add_part(root, ProcMesh.box_mesh(Vector3(0.042, 0.012, 0.072), polymer), Vector3(0, 0.066, 0.02))
	ProcMesh.add_part(root, ProcMesh.box_mesh(Vector3(0.008, 0.036, 0.062), polymer), Vector3(-0.018, 0.088, 0.02))
	ProcMesh.add_part(root, ProcMesh.box_mesh(Vector3(0.008, 0.036, 0.062), polymer), Vector3(0.018, 0.088, 0.02))
	ProcMesh.add_part(root, ProcMesh.box_mesh(Vector3(0.044, 0.009, 0.062), polymer), Vector3(0, 0.106, 0.02))
	var dot := ProcMesh.sphere_mesh(0.004, Color(1.0, 0.18, 0.12))
	dot.material_override = ProcMesh.emissive(Color(1.0, 0.2, 0.12), 2.5)
	ProcMesh.add_part(root, dot, Vector3(0, 0.088, 0.018))

	# Tactical handguard & barrel + flash hider
	ProcMesh.add_part(root, ProcMesh.box_mesh(Vector3(0.048, 0.054, 0.25), handguard, 0.70, 0.22), Vector3(0, 0.016, -0.255))
	ProcMesh.add_part(root, ProcMesh.cylinder_mesh(0.011, 0.22, steel, 0.35, 0.72, 8), Vector3(0, 0.022, -0.44), Vector3(90, 0, 0))
	ProcMesh.add_part(root, ProcMesh.cylinder_mesh(0.015, 0.045, polymer, 0.45, 0.6, 8), Vector3(0, 0.022, -0.54), Vector3(90, 0, 0))
	# Front iron sight post
	ProcMesh.add_part(root, ProcMesh.box_mesh(Vector3(0.012, 0.034, 0.016), steel), Vector3(0, 0.052, -0.365))

	# Curved detachable magazine
	var mag := Node3D.new()
	mag.name = "Magazine"
	mag.position = Vector3(0, -0.078, -0.075)
	root.add_child(mag)
	ProcMesh.add_part(mag, ProcMesh.box_mesh(Vector3(0.030, 0.135, 0.058), polymer, 0.72, 0.18), Vector3.ZERO, Vector3(12, 0, 0))
	_magazines[GameState.WeaponId.RIFLE] = mag

	# Buttstock, pistol grip, angled foregrip
	ProcMesh.add_part(root, ProcMesh.box_mesh(Vector3(0.044, 0.088, 0.22), polymer, 0.78, 0.12), Vector3(0, -0.008, 0.23))
	ProcMesh.add_part(root, ProcMesh.box_mesh(Vector3(0.034, 0.095, 0.046), polymer, 0.85, 0.08), Vector3(0, -0.055, 0.085), Vector3(-18, 0, 0))
	ProcMesh.add_part(root, ProcMesh.box_mesh(Vector3(0.030, 0.078, 0.036), polymer, 0.85, 0.08), Vector3(0, -0.042, -0.25), Vector3(8, 0, 0))

	# Gloved hands + forearms
	ProcMesh.add_part(root, ProcMesh.box_mesh(Vector3(0.058, 0.068, 0.075), glove), Vector3(0.005, -0.055, 0.085), Vector3(-14, 0, 0))
	ProcMesh.add_part(root, ProcMesh.box_mesh(Vector3(0.068, 0.068, 0.22), sleeve), Vector3(0.038, -0.105, 0.21), Vector3(-18, -8, 0))
	ProcMesh.add_part(root, ProcMesh.box_mesh(Vector3(0.060, 0.062, 0.076), glove), Vector3(-0.015, -0.045, -0.25))
	ProcMesh.add_part(root, ProcMesh.box_mesh(Vector3(0.062, 0.060, 0.24), sleeve), Vector3(-0.08, -0.13, -0.14), Vector3(-22, 22, 0))

	# Bright rifle muzzle flash
	var flash := _make_muzzle_flash(0.115, Color(1.0, 0.78, 0.22, 0.95))
	flash.position = Vector3(0, 0.022, -0.585)
	root.add_child(flash)
	_muzzle_flashes[GameState.WeaponId.RIFLE] = flash


func _build_bow(slot: Node3D) -> void:
	if not is_instance_valid(slot):
		return
	_clear_slot(slot)
	var wood := Color(0.42, 0.26, 0.14)
	var carbon := Color(0.16, 0.17, 0.18)
	var string_col := Color(0.84, 0.82, 0.76)
	var shaft_col := Color(0.55, 0.38, 0.20)
	var fletch_col := Color(0.88, 0.18, 0.14)
	var steel := Color(0.75, 0.78, 0.82)
	var glove := Color(0.18, 0.17, 0.16)
	var sleeve := Color(0.24, 0.28, 0.20)

	var root := Node3D.new()
	root.name = "ModelRoot"
	slot.add_child(root)

	# Riser handle
	ProcMesh.add_part(root, ProcMesh.box_mesh(Vector3(0.034, 0.22, 0.046), carbon, 0.65, 0.25), Vector3(0, 0, 0))
	ProcMesh.add_part(root, ProcMesh.box_mesh(Vector3(0.038, 0.11, 0.050), wood, 0.82, 0.05), Vector3(0, -0.02, 0.004))

	# Sight ring + glowing green pin on left of riser
	ProcMesh.add_part(root, ProcMesh.box_mesh(Vector3(0.038, 0.010, 0.016), carbon), Vector3(-0.024, 0.068, -0.022))
	ProcMesh.add_part(root, ProcMesh.cylinder_mesh(0.018, 0.010, carbon, 0.5, 0.4, 10), Vector3(-0.042, 0.068, -0.024), Vector3(90, 0, 0))
	var pin := ProcMesh.sphere_mesh(0.0038, Color(0.2, 1.0, 0.35))
	pin.material_override = ProcMesh.emissive(Color(0.25, 1.0, 0.35), 2.2)
	ProcMesh.add_part(root, pin, Vector3(-0.042, 0.068, -0.024))

	# Upper curved limbs (two segments) + cam tip
	ProcMesh.add_part(root, ProcMesh.box_mesh(Vector3(0.026, 0.21, 0.026), wood, 0.72, 0.08), Vector3(0, 0.19, 0.038), Vector3(22, 0, 0))
	ProcMesh.add_part(root, ProcMesh.box_mesh(Vector3(0.020, 0.18, 0.018), carbon, 0.60, 0.25), Vector3(0, 0.34, 0.125), Vector3(38, 0, 0))
	# Lower curved limbs (two segments)
	ProcMesh.add_part(root, ProcMesh.box_mesh(Vector3(0.026, 0.21, 0.026), wood, 0.72, 0.08), Vector3(0, -0.19, 0.038), Vector3(-22, 0, 0))
	ProcMesh.add_part(root, ProcMesh.box_mesh(Vector3(0.020, 0.18, 0.018), carbon, 0.60, 0.25), Vector3(0, -0.34, 0.125), Vector3(-38, 0, 0))

	# Bowstring (continuous taut segments meeting at nock point)
	_bow_string = Node3D.new()
	_bow_string.name = "BowString"
	root.add_child(_bow_string)
	ProcMesh.add_part(_bow_string, ProcMesh.cylinder_mesh(0.0026, 0.44, string_col, 0.9, 0.0, 6), Vector3(0, 0.21, 0.19), Vector3(-5, 0, 0))
	ProcMesh.add_part(_bow_string, ProcMesh.cylinder_mesh(0.0026, 0.44, string_col, 0.9, 0.0, 6), Vector3(0, -0.21, 0.19), Vector3(5, 0, 0))

	# Visible nocked arrow resting on the bow!
	_bow_arrow = Node3D.new()
	_bow_arrow.name = "BowArrow"
	_bow_arrow.position = Vector3(-0.022, 0.035, -0.04)
	root.add_child(_bow_arrow)
	# Arrow shaft
	ProcMesh.add_part(_bow_arrow, ProcMesh.cylinder_mesh(0.0055, 0.56, shaft_col, 0.7, 0.05, 8), Vector3(0, 0, 0), Vector3(90, 0, 0))
	# Broadhead arrowhead (cone + razor blades) clearly visible ahead of the riser
	ProcMesh.add_part(_bow_arrow, ProcMesh.cone_mesh(0.014, 0.001, 0.068, steel, 0.28, 0.80, 6), Vector3(0, 0, -0.31), Vector3(-90, 0, 0))
	ProcMesh.add_part(_bow_arrow, ProcMesh.box_mesh(Vector3(0.030, 0.003, 0.052), steel, 0.25, 0.85), Vector3(0, 0, -0.295))
	ProcMesh.add_part(_bow_arrow, ProcMesh.box_mesh(Vector3(0.003, 0.030, 0.052), steel, 0.25, 0.85), Vector3(0, 0, -0.295))
	# Red & white fletching feathers near the nock
	ProcMesh.add_part(_bow_arrow, ProcMesh.box_mesh(Vector3(0.003, 0.024, 0.082), fletch_col, 0.85, 0.0), Vector3(0, 0.012, 0.21))
	ProcMesh.add_part(_bow_arrow, ProcMesh.box_mesh(Vector3(0.022, 0.003, 0.082), Color(0.95, 0.95, 0.92), 0.85, 0.0), Vector3(0.010, -0.007, 0.21), Vector3(0, 0, 28))
	ProcMesh.add_part(_bow_arrow, ProcMesh.box_mesh(Vector3(0.022, 0.003, 0.082), fletch_col, 0.85, 0.0), Vector3(-0.010, -0.007, 0.21), Vector3(0, 0, -28))

	# Gloved bow hand gripping riser
	ProcMesh.add_part(root, ProcMesh.box_mesh(Vector3(0.062, 0.074, 0.068), glove), Vector3(0.012, -0.025, 0.015))
	ProcMesh.add_part(root, ProcMesh.box_mesh(Vector3(0.068, 0.066, 0.22), sleeve), Vector3(0.065, -0.095, 0.145), Vector3(-18, -16, 0))


func _build_knife(slot: Node3D) -> void:
	if not is_instance_valid(slot):
		return
	_clear_slot(slot)
	var steel := Color(0.76, 0.80, 0.84)
	var dark_steel := Color(0.32, 0.35, 0.39)
	var brass := Color(0.62, 0.50, 0.24)
	var handle := Color(0.24, 0.16, 0.10)
	var glove := Color(0.18, 0.17, 0.16)
	var sleeve := Color(0.24, 0.28, 0.20)

	var root := Node3D.new()
	root.name = "ModelRoot"
	slot.add_child(root)

	# Blade + dark spine + tapered point
	ProcMesh.add_part(root, ProcMesh.box_mesh(Vector3(0.007, 0.036, 0.165), steel, 0.25, 0.82), Vector3(0, 0.012, -0.105))
	ProcMesh.add_part(root, ProcMesh.box_mesh(Vector3(0.009, 0.012, 0.160), dark_steel, 0.42, 0.65), Vector3(0, 0.026, -0.102))
	ProcMesh.add_part(root, ProcMesh.cone_mesh(0.019, 0.001, 0.065, steel, 0.24, 0.85, 4), Vector3(0, 0.012, -0.218), Vector3(-90, 0, 45))
	# Crossguard
	ProcMesh.add_part(root, ProcMesh.box_mesh(Vector3(0.018, 0.068, 0.016), brass, 0.38, 0.72), Vector3(0, 0.010, -0.018))
	# Wrapped handle & pommel
	ProcMesh.add_part(root, ProcMesh.box_mesh(Vector3(0.022, 0.030, 0.115), handle, 0.88, 0.05), Vector3(0, 0.006, 0.046))
	ProcMesh.add_part(root, ProcMesh.box_mesh(Vector3(0.026, 0.034, 0.020), brass, 0.40, 0.70), Vector3(0, 0.006, 0.108))

	# Gloved hand & forearm
	ProcMesh.add_part(root, ProcMesh.box_mesh(Vector3(0.060, 0.066, 0.088), glove), Vector3(0.008, -0.002, 0.055))
	ProcMesh.add_part(root, ProcMesh.box_mesh(Vector3(0.068, 0.068, 0.24), sleeve), Vector3(0.055, -0.065, 0.185), Vector3(-16, -15, 0))


func _make_muzzle_flash(size: float, color: Color) -> Node3D:
	var n := Node3D.new()
	n.name = "MuzzleFlash"
	var m_outer := ProcMesh.unshaded(color)
	var m_core := ProcMesh.unshaded(Color(1.0, 0.98, 0.85, 0.95))
	# Three intersecting star planes + forward cone
	for deg in [0.0, 60.0, 120.0]:
		var fin := ProcMesh.box_mesh(Vector3(size * 1.4, size * 0.28, size * 0.18), color)
		fin.material_override = m_outer
		ProcMesh.add_part(n, fin, Vector3.ZERO, Vector3(0, 0, deg))
	var cone := ProcMesh.cone_mesh(size * 0.32, 0.002, size * 1.4, color, 0.5, 0.0, 6)
	cone.material_override = m_core
	ProcMesh.add_part(n, cone, Vector3(0, 0, -size * 0.55), Vector3(-90, 0, 0))
	n.visible = false
	return n


func hide_all() -> void:
	for slot in _slots.values():
		if is_instance_valid(slot):
			slot.visible = false


func show_weapon(id: GameState.WeaponId, animate_swap: bool = true) -> void:
	_active_id = id
	hide_all()
	var slot: Node3D = _slots.get(id)
	if is_instance_valid(slot):
		slot.visible = true
		slot.position = _base_pos.get(id, Vector3(0.22, -0.18, -0.4))
		slot.rotation_degrees = _base_rot.get(id, Vector3.ZERO)
	_reload_t = 0.0
	_fire_t = 0.0
	if animate_swap:
		_swap_t = _swap_dur


func set_move_factor(factor: float) -> void:
	_move_factor = clampf(factor, 0.0, 1.5)


func set_bow_arrow_visible(has_arrow: bool) -> void:
	if is_instance_valid(_bow_arrow):
		_bow_arrow.visible = has_arrow


func play_fire(id: GameState.WeaponId) -> void:
	_active_id = id
	_fire_dur = 0.24 if id == GameState.WeaponId.KNIFE or id == GameState.WeaponId.BOW else 0.14
	_fire_t = _fire_dur
	var flash: Node3D = _muzzle_flashes.get(id)
	if is_instance_valid(flash):
		flash.visible = true
		flash.rotation.z = randf() * TAU
		var s := randf_range(0.85, 1.25)
		flash.scale = Vector3(s, s, s)
		_flash_t = 0.085


func play_reload(duration: float = 1.4) -> void:
	_reload_dur = maxf(0.3, duration)
	_reload_t = _reload_dur


func play_swap() -> void:
	_swap_t = _swap_dur
	_inspect_t = 0.0


func play_inspect() -> void:
	if _reload_t > 0.0 or _carrying:
		return
	_inspect_t = _inspect_dur


func play_takedown(from_behind: bool) -> void:
	_takedown_behind = from_behind
	_takedown_t = _takedown_dur
	_inspect_t = 0.0


func set_vault_progress(p: float) -> void:
	_vault_p = clampf(p, 0.0, 1.0)


func set_carrying_body(carrying: bool, dragging: bool = false) -> void:
	_carrying = carrying
	_dragging = dragging


func set_aiming(aiming: bool) -> void:
	_aim_blend = 1.0 if aiming else 0.0


func add_look_sway(delta_xy: Vector2) -> void:
	_sway.x = clampf(_sway.x - delta_xy.x * 0.0028, -0.045, 0.045)
	_sway.y = clampf(_sway.y + delta_xy.y * 0.0022, -0.035, 0.035)


func get_slot(id: GameState.WeaponId) -> Node3D:
	return _slots.get(id) as Node3D


func _process(delta: float) -> void:
	_idle_time += delta
	_sway = _sway.lerp(Vector2.ZERO, clampf(delta * 9.0, 0.0, 1.0))
	var slot: Node3D = _slots.get(_active_id)
	if not is_instance_valid(slot) or not slot.visible:
		return

	# Muzzle flash fade-out
	if _flash_t > 0.0:
		_flash_t -= delta
		if _flash_t <= 0.0:
			for f in _muzzle_flashes.values():
				if is_instance_valid(f):
					f.visible = false

	var base_p: Vector3 = _base_pos.get(_active_id, Vector3(0.22, -0.18, -0.4))
	var base_r: Vector3 = _base_rot.get(_active_id, Vector3.ZERO)
	var offset_p := Vector3(_sway.x, _sway.y, 0.0)
	var offset_r := Vector3(_sway.y * 160.0, _sway.x * 220.0, -_sway.x * 180.0)

	# ADS centering
	if _aim_blend > 0.01 and not _carrying and _inspect_t <= 0.0:
		offset_p.x -= base_p.x * 0.62 * _aim_blend
		offset_p.y += 0.042 * _aim_blend
		offset_p.z += 0.04 * _aim_blend

	# Subtle breathing idle + walk bob (dampened when aiming)
	var aim_damp := 1.0 - _aim_blend * 0.72
	var bob_amp := (0.004 + _move_factor * 0.011) * aim_damp
	var bob_freq := 2.2 + _move_factor * 6.5
	offset_p.x += sin(_idle_time * bob_freq * 0.5) * bob_amp
	offset_p.y += absf(cos(_idle_time * bob_freq * 0.5)) * bob_amp * 0.85

	# Swap-in raise animation
	if _swap_t > 0.0:
		_swap_t = maxf(0.0, _swap_t - delta)
		var u := _swap_t / _swap_dur
		var ease_u := u * u
		offset_p.y -= 0.24 * ease_u
		offset_r.x -= 35.0 * ease_u

	# Weapon inspect showcase animation (rotate to inspect receiver, attachments, and finish)
	if _inspect_t > 0.0:
		_inspect_t = maxf(0.0, _inspect_t - delta)
		var p := 1.0 - (_inspect_t / _inspect_dur)
		var env := sin(p * PI)
		var twist := sin(p * TAU)
		offset_p.x -= 0.11 * env
		offset_p.y += 0.045 * env
		offset_p.z += 0.06 * env
		offset_r.y += 42.0 * env + 18.0 * twist
		offset_r.z += 28.0 * env - 24.0 * twist
		offset_r.x += 12.0 * env

	# Close-quarters front/back takedown strike animation
	if _takedown_t > 0.0:
		_takedown_t = maxf(0.0, _takedown_t - delta)
		var p := 1.0 - (_takedown_t / _takedown_dur)
		var lunge := sin(p * PI)
		if _takedown_behind:
			# Stealth sweep across throat/neck
			offset_p.z -= 0.20 * lunge
			offset_p.x -= 0.16 * lunge
			offset_p.y += 0.04 * lunge
			offset_r.y += 65.0 * lunge
			offset_r.z -= 40.0 * lunge
		else:
			# Frontal CQC jab & follow-through
			offset_p.z -= 0.24 * lunge
			offset_p.y += 0.08 * lunge
			offset_r.x -= 48.0 * lunge
			offset_r.z += 28.0 * lunge

	# Vaulting / climbing low wall hands-brace dip
	if _vault_p > 0.001:
		var v_arc := sin(_vault_p * PI)
		offset_p.y -= 0.22 * v_arc
		offset_p.z -= 0.08 * v_arc
		offset_r.x -= 38.0 * v_arc
		offset_r.z -= 16.0 * v_arc

	# Carrying / dragging body lowers weapon smoothly out of the way
	if _carrying:
		offset_p.y -= 0.28 if not _dragging else 0.32
		offset_r.x -= 44.0

	# Fire recoil / throw swing
	if _fire_t > 0.0:
		_fire_t = maxf(0.0, _fire_t - delta)
		var u := _fire_t / maxf(0.01, _fire_dur)
		var kick := sin(u * PI)
		match _active_id:
			GameState.WeaponId.PISTOL:
				offset_p.z += 0.045 * kick
				offset_p.y += 0.012 * kick
				offset_r.x += 12.0 * kick
				if is_instance_valid(_pistol_slide):
					_pistol_slide.position.z = 0.042 * kick
			GameState.WeaponId.RIFLE:
				offset_p.z += 0.036 * kick
				offset_p.y += 0.008 * kick
				offset_r.x += 6.5 * kick
			GameState.WeaponId.BOW:
				offset_p.z += 0.05 * kick
				offset_r.x += 8.0 * kick
				if is_instance_valid(_bow_string):
					_bow_string.position.z = -0.035 * kick
			GameState.WeaponId.KNIFE:
				offset_p.z -= 0.14 * kick
				offset_p.x -= 0.08 * kick
				offset_r.x -= 48.0 * kick
				offset_r.z += 22.0 * kick
			_:
				offset_p.z += 0.042 * kick
				offset_p.y += 0.012 * kick
				offset_r.x += 8.5 * kick
	else:
		if is_instance_valid(_pistol_slide):
			_pistol_slide.position.z = 0.0
		if is_instance_valid(_bow_string):
			_bow_string.position.z = 0.0

	# Reload dip & magazine / arrow cycle
	if _reload_t > 0.0:
		_reload_t = maxf(0.0, _reload_t - delta)
		var p := 1.0 - (_reload_t / maxf(0.01, _reload_dur))
		var dip := sin(p * PI)
		offset_p.y -= 0.12 * dip
		offset_p.x -= 0.05 * dip
		offset_r.z += 26.0 * dip
		offset_r.x -= 14.0 * dip
		var mag: Node3D = _magazines.get(_active_id)
		if is_instance_valid(mag):
			var mag_drop := sin(clampf((p - 0.15) / 0.7, 0.0, 1.0) * PI)
			mag.position.y = (-0.112 if _active_id == GameState.WeaponId.PISTOL else -0.078) - 0.16 * mag_drop
	else:
		var pmag: Node3D = _magazines.get(GameState.WeaponId.PISTOL)
		if is_instance_valid(pmag):
			pmag.position.y = -0.112
		var rmag: Node3D = _magazines.get(GameState.WeaponId.RIFLE)
		if is_instance_valid(rmag):
			rmag.position.y = -0.078

	# Smooth spring-damped transition into final pose
	var target_p := base_p + offset_p
	var target_r := base_r + offset_r
	var smooth := clampf(delta * 20.0, 0.0, 1.0)
	slot.position = slot.position.lerp(target_p, smooth)
	slot.rotation_degrees = slot.rotation_degrees.lerp(target_r, smooth)
