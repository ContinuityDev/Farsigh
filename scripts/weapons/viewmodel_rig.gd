extends Node3D
class_name ViewmodelRig
## Procedural low-poly first-person weapon viewmodels for the full 14-weapon
## arsenal with live Gunsmith attachments (suppressor, compensator, red dot,
## holo, sniper scope, extended mag, grip, tactical laser, arrow tips, skins)
## plus smooth spring-damped animations (sway, ADS, fire, reload, swap, inspect,
## front/back takedown, vaulting, and body carry/drag).

const ProcMesh = preload("res://scripts/mesh/proc_mesh.gd")

const SKIN_PALETTES := {
	"default": {"body": Color(0.16, 0.17, 0.19), "accent": Color(0.22, 0.24, 0.21)},
	"olive": {"body": Color(0.24, 0.30, 0.20), "accent": Color(0.16, 0.20, 0.14)},
	"tan": {"body": Color(0.58, 0.50, 0.36), "accent": Color(0.42, 0.35, 0.25)},
	"crimson": {"body": Color(0.54, 0.14, 0.12), "accent": Color(0.16, 0.14, 0.14)},
	"arctic": {"body": Color(0.78, 0.82, 0.84), "accent": Color(0.32, 0.38, 0.42)},
	"gold": {"body": Color(0.78, 0.62, 0.22), "accent": Color(0.14, 0.14, 0.15)},
}

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

var _fire_t: float = 0.0
var _fire_dur: float = 0.18
var _flash_t: float = 0.0
var _reload_t: float = 0.0
var _reload_dur: float = 1.4
var _swap_t: float = 0.0
var _swap_dur: float = 0.26
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
var _aim_target: float = 0.0
var _ads_speed: float = 4.0
var _breath_hold: float = 0.0
var _sight_local: Dictionary = {}  # WeaponId -> Vector3 sight point in ModelRoot space
var _throw_arc: MeshInstance3D = null
var _throw_arc_mat: StandardMaterial3D = null


func _ready() -> void:
	_setup_poses()
	_ensure_slots()
	# During staged outpost load, OutpostManager rebuilds viewmodels in a later
	# chunk so we don't sync-build 14 weapons on the same frame as greybox.
	if GameState.world_loading:
		hide_all()
	else:
		rebuild_all_from_state()
		hide_all()


## Rebuild one weapon per frame so mobile WebGL can upload meshes.
func rebuild_all_async(host: Node) -> void:
	_ensure_slots()
	for wid in _slots.keys():
		rebuild_weapon(wid, GameState.get_weapon_mods(wid))
		if is_instance_valid(host):
			await host.get_tree().process_frame
	hide_all()


func _setup_poses() -> void:
	_base_pos = {
		GameState.WeaponId.PISTOL: Vector3(0.21, -0.19, -0.40),
		GameState.WeaponId.MACHINE_PISTOL: Vector3(0.21, -0.19, -0.41),
		GameState.WeaponId.RIFLE: Vector3(0.24, -0.21, -0.47),
		GameState.WeaponId.SMG: Vector3(0.22, -0.20, -0.43),
		GameState.WeaponId.SHOTGUN: Vector3(0.24, -0.22, -0.48),
		GameState.WeaponId.SNIPER: Vector3(0.25, -0.21, -0.50),
		GameState.WeaponId.LMG: Vector3(0.26, -0.23, -0.48),
		GameState.WeaponId.BOW: Vector3(0.19, -0.13, -0.45),
		GameState.WeaponId.CROSSBOW: Vector3(0.22, -0.20, -0.46),
		GameState.WeaponId.KNIFE: Vector3(0.23, -0.19, -0.37),
		GameState.WeaponId.FRAG: Vector3(0.22, -0.19, -0.36),
		GameState.WeaponId.MOLOTOV: Vector3(0.22, -0.19, -0.38),
		GameState.WeaponId.MACHETE: Vector3(0.25, -0.20, -0.40),
		GameState.WeaponId.BAT: Vector3(0.26, -0.22, -0.42),
	}
	_base_rot = {
		GameState.WeaponId.PISTOL: Vector3(0.0, 2.0, 0.0),
		GameState.WeaponId.MACHINE_PISTOL: Vector3(0.0, 2.5, 0.0),
		GameState.WeaponId.RIFLE: Vector3(0.0, 2.5, 0.0),
		GameState.WeaponId.SMG: Vector3(0.0, 3.0, 0.0),
		GameState.WeaponId.SHOTGUN: Vector3(0.0, 2.5, 0.0),
		GameState.WeaponId.SNIPER: Vector3(0.0, 2.0, 0.0),
		GameState.WeaponId.LMG: Vector3(0.0, 3.0, 0.0),
		GameState.WeaponId.BOW: Vector3(0.0, 6.0, 16.0),
		GameState.WeaponId.CROSSBOW: Vector3(0.0, 2.5, 0.0),
		GameState.WeaponId.KNIFE: Vector3(-12.0, 14.0, -8.0),
		GameState.WeaponId.FRAG: Vector3(0.0, 8.0, 0.0),
		GameState.WeaponId.MOLOTOV: Vector3(-4.0, 6.0, 4.0),
		GameState.WeaponId.MACHETE: Vector3(-16.0, 18.0, -10.0),
		GameState.WeaponId.BAT: Vector3(-24.0, 14.0, -16.0),
	}


func _ensure_slots() -> void:
	# Reuse the 4 scene slots if present and create additional slots dynamically
	var existing_map := {
		GameState.WeaponId.PISTOL: "PistolSlot",
		GameState.WeaponId.RIFLE: "RifleSlot",
		GameState.WeaponId.BOW: "BowSlot",
		GameState.WeaponId.KNIFE: "KnifeSlot",
	}
	for wid in _base_pos.keys():
		var slot: Node3D = null
		if existing_map.has(wid):
			slot = get_node_or_null(existing_map[wid]) as Node3D
		if slot == null:
			var sname := "Slot_%d" % int(wid)
			slot = get_node_or_null(sname) as Node3D
			if slot == null:
				slot = Node3D.new()
				slot.name = sname
				add_child(slot)
		_slots[wid] = slot


func rebuild_all_from_state() -> void:
	for wid in _slots.keys():
		rebuild_weapon(wid, GameState.get_weapon_mods(wid))


func rebuild_weapon(id: GameState.WeaponId, mods: Dictionary) -> void:
	var slot: Node3D = _slots.get(id)
	if not is_instance_valid(slot):
		return
	for c in slot.get_children():
		c.queue_free()
	var skin_key := String(mods.get("skin", "default"))
	var pal: Dictionary = SKIN_PALETTES.get(skin_key, SKIN_PALETTES["default"])
	var body_col: Color = pal["body"]
	var accent_col: Color = pal["accent"]

	match id:
		GameState.WeaponId.PISTOL:
			_build_pistol(slot, id, body_col, accent_col, mods, false)
		GameState.WeaponId.MACHINE_PISTOL:
			_build_pistol(slot, id, body_col, accent_col, mods, true)
		GameState.WeaponId.RIFLE:
			_build_long_gun(slot, id, body_col, accent_col, mods, 0.27, 0.25, 0.22, false, false, false)
		GameState.WeaponId.SMG:
			_build_long_gun(slot, id, body_col, accent_col, mods, 0.20, 0.16, 0.14, true, false, false)
		GameState.WeaponId.SHOTGUN:
			_build_shotgun(slot, body_col, accent_col, mods)
		GameState.WeaponId.SNIPER, GameState.WeaponId.SILENCED_SNIPER:
			_build_long_gun(slot, id, body_col, accent_col, mods, 0.30, 0.32, 0.42, false, true, false)
		GameState.WeaponId.LMG, GameState.WeaponId.FLAMETHROWER, GameState.WeaponId.GRENADE_LAUNCHER:
			_build_long_gun(slot, id, body_col, accent_col, mods, 0.32, 0.30, 0.28, false, false, true)
		GameState.WeaponId.BOW, GameState.WeaponId.HUNTER_BOW:
			_build_bow(slot, id, body_col, accent_col, mods)
		GameState.WeaponId.CROSSBOW:
			_build_crossbow(slot, body_col, accent_col, mods)
		GameState.WeaponId.KNIFE, GameState.WeaponId.THROWING_AXE:
			_build_knife(slot, body_col)
		GameState.WeaponId.FRAG, GameState.WeaponId.C4, GameState.WeaponId.PROX_MINE:
			_build_frag(slot)
		GameState.WeaponId.MOLOTOV:
			_build_molotov(slot)
		GameState.WeaponId.MACHETE:
			_build_machete(slot, body_col)
		GameState.WeaponId.BAT:
			_build_bat(slot, body_col, accent_col)
		GameState.WeaponId.TRANQ_PISTOL:
			_build_pistol(slot, id, body_col, accent_col, mods, false)


# ============================================================================
# PROCEDURAL MODULAR WEAPON BUILDERS
# ============================================================================
func _build_pistol(slot: Node3D, wid: GameState.WeaponId, body_col: Color, accent_col: Color, mods: Dictionary, is_auto: bool) -> void:
	var polymer := Color(0.11, 0.12, 0.13)
	var glove := Color(0.18, 0.17, 0.16)
	var sleeve := Color(0.24, 0.28, 0.20)
	var root := Node3D.new()
	root.name = "ModelRoot"
	slot.add_child(root)

	var slide := Node3D.new()
	slide.name = "Slide"
	root.add_child(slide)
	var slide_len := 0.24 if is_auto else 0.205
	ProcMesh.add_part(slide, ProcMesh.box_mesh(Vector3(0.042, 0.046, slide_len), body_col, 0.42, 0.55), Vector3(0, 0.032, -0.02))
	# No slide-mounted irons — _attach_optic owns the single iron/optic set so ADS centers correctly
	if not is_auto:
		_pistol_slide = slide

	ProcMesh.add_part(root, ProcMesh.box_mesh(Vector3(0.036, 0.028, slide_len - 0.01), accent_col, 0.72, 0.15), Vector3(0, 0.0, -0.015))
	ProcMesh.add_part(root, ProcMesh.box_mesh(Vector3(0.034, 0.105, 0.052), polymer, 0.85, 0.08), Vector3(0, -0.062, 0.048), Vector3(-14, 0, 0))

	# Magazine (longer if extended mag or machine pistol!)
	var ext := String(mods.get("mag", "standard")) == "extended"
	var mag := Node3D.new()
	mag.name = "Magazine"
	mag.position = Vector3(0, -0.112, 0.060)
	root.add_child(mag)
	var mag_h := 0.11 if (ext or is_auto) else 0.028
	if ext and is_auto:
		mag_h = 0.17
	ProcMesh.add_part(mag, ProcMesh.box_mesh(Vector3(0.030, mag_h, 0.048), body_col.darkened(0.15), 0.5, 0.45), Vector3(0, -mag_h * 0.35, 0), Vector3(-14, 0, 0))
	_magazines[wid] = mag

	# Muzzle attachment (suppressor or compensator)
	var muzzle_z := -0.13 if not is_auto else -0.155
	muzzle_z = _attach_muzzle(root, Vector3(0, 0.028, muzzle_z), String(mods.get("muzzle", "none")), 0.016, 0.18)
	_sight_local[wid] = _attach_optic(root, Vector3(0, 0.058, 0.01), String(mods.get("optic", "iron")), true)
	_attach_underbarrel(root, Vector3(0, -0.020, -0.095), String(mods.get("underbarrel", "none")), true)

	# Gloved hands
	ProcMesh.add_part(root, ProcMesh.box_mesh(Vector3(0.062, 0.075, 0.082), glove, 0.88, 0.04), Vector3(0.006, -0.062, 0.055), Vector3(-12, 0, 0))
	ProcMesh.add_part(root, ProcMesh.box_mesh(Vector3(0.070, 0.068, 0.24), sleeve, 0.90, 0.02), Vector3(0.035, -0.105, 0.185), Vector3(-16, -8, 0))

	var flash := _make_muzzle_flash(0.055 if String(mods.get("muzzle", "none")) == "suppressor" else 0.085, Color(1.0, 0.85, 0.45, 0.88))
	flash.position = Vector3(0, 0.028, muzzle_z - 0.03)
	root.add_child(flash)
	_muzzle_flashes[wid] = flash


func _gun_box(size: Vector3, color: Color, roughness: float = 0.5, metallic: float = 0.45) -> MeshInstance3D:
	var mi := ProcMesh.box_mesh(size, color, roughness, metallic)
	mi.material_override = ProcMesh.gun_mat(color, roughness, metallic)
	return mi


func _gun_cyl(radius: float, height: float, color: Color, roughness: float = 0.4, metallic: float = 0.65, segments: int = 10) -> MeshInstance3D:
	var mi := ProcMesh.cylinder_mesh(radius, height, color, roughness, metallic, segments)
	mi.material_override = ProcMesh.gun_mat(color, roughness, metallic)
	return mi


func _build_long_gun(slot: Node3D, id: GameState.WeaponId, body_col: Color, accent_col: Color, mods: Dictionary, rec_len: float, hg_len: float, brl_len: float, is_smg: bool, is_sniper: bool, is_lmg: bool) -> void:
	var polymer := Color(0.11, 0.12, 0.13)
	var glove := Color(0.18, 0.17, 0.16)
	var sleeve := Color(0.24, 0.28, 0.20)
	var root := Node3D.new()
	root.name = "ModelRoot"
	slot.add_child(root)

	# Receiver (wider/boxier for LMG, sleeker for SMG/Sniper) — rim materials on High
	var rw := 0.078 if is_lmg else (0.044 if is_smg else 0.054)
	var rh := 0.084 if is_lmg else (0.058 if is_smg else 0.068)
	ProcMesh.add_part(root, _gun_box(Vector3(rw, rh, rec_len), body_col, 0.45, 0.55), Vector3(0, 0.015, 0.0))
	ProcMesh.add_part(root, _gun_box(Vector3(0.030, 0.012, rec_len), polymer, 0.4, 0.5), Vector3(0, 0.015 + rh * 0.5 + 0.005, -0.01))
	# Detail: top rail segments + charging handle + ejection port for clearer silhouette
	ProcMesh.add_part(root, _gun_box(Vector3(0.022, 0.006, rec_len * 0.72), Color(0.14, 0.15, 0.16), 0.35, 0.7), Vector3(0, 0.015 + rh * 0.5 + 0.012, -0.02))
	ProcMesh.add_part(root, _gun_box(Vector3(0.012, 0.018, 0.028), Color(0.28, 0.29, 0.30), 0.4, 0.6), Vector3(rw * 0.42, 0.028, -0.02))
	ProcMesh.add_part(root, _gun_box(Vector3(0.006, 0.022, 0.04), Color(0.08, 0.08, 0.09), 0.55, 0.3), Vector3(rw * 0.48, 0.02, 0.02))

	# Handguard & Barrel
	var hg_z := -(rec_len * 0.5 + hg_len * 0.5)
	ProcMesh.add_part(root, _gun_box(Vector3(rw * 0.9, rh * 0.78, hg_len), accent_col, 0.68, 0.22), Vector3(0, 0.016, hg_z))
	# Handguard vent slots (side detail)
	ProcMesh.add_part(root, _gun_box(Vector3(0.004, rh * 0.35, hg_len * 0.55), polymer.darkened(0.2), 0.5, 0.4), Vector3(-rw * 0.48, 0.02, hg_z))
	ProcMesh.add_part(root, _gun_box(Vector3(0.004, rh * 0.35, hg_len * 0.55), polymer.darkened(0.2), 0.5, 0.4), Vector3(rw * 0.48, 0.02, hg_z))
	var brl_z := hg_z - hg_len * 0.5 - brl_len * 0.5 + 0.03
	var brl_r := 0.016 if is_sniper else (0.015 if is_lmg else 0.011)
	ProcMesh.add_part(root, _gun_cyl(brl_r, brl_len, body_col.darkened(0.2), 0.35, 0.72, 8), Vector3(0, 0.022, brl_z), Vector3(90, 0, 0))
	# Gas block / front sight base silhouette
	if not is_smg:
		ProcMesh.add_part(root, _gun_box(Vector3(0.018, 0.022, 0.028), polymer, 0.4, 0.55), Vector3(0, 0.034, brl_z + brl_len * 0.15))

	if is_lmg:
		# Carry handle + bipod legs folded under barrel
		ProcMesh.add_part(root, ProcMesh.box_mesh(Vector3(0.018, 0.05, 0.14), polymer), Vector3(0.03, 0.08, -0.10))
		ProcMesh.add_part(root, ProcMesh.cylinder_mesh(0.008, 0.20, polymer, 0.5, 0.5, 6), Vector3(-0.04, -0.02, hg_z - 0.12), Vector3(84, 0, 0))
		ProcMesh.add_part(root, ProcMesh.cylinder_mesh(0.008, 0.20, polymer, 0.5, 0.5, 6), Vector3(0.04, -0.02, hg_z - 0.12), Vector3(84, 0, 0))
	elif is_sniper:
		# Bolt handle on right side + cheek rest
		ProcMesh.add_part(root, ProcMesh.cylinder_mesh(0.007, 0.055, Color(0.65, 0.66, 0.68), 0.3, 0.8, 6), Vector3(0.042, 0.015, 0.05), Vector3(0, 0, 90))
		ProcMesh.add_part(root, ProcMesh.sphere_mesh(0.014, Color(0.65, 0.66, 0.68)), Vector3(0.072, 0.015, 0.05))
		ProcMesh.add_part(root, ProcMesh.box_mesh(Vector3(0.048, 0.036, 0.12), accent_col), Vector3(0, 0.045, 0.22))

	# Magazine (box drum for LMG, slim stick for SMG, extended mag visibly longer!)
	var ext := String(mods.get("mag", "standard")) == "extended"
	var mag := Node3D.new()
	mag.name = "Magazine"
	mag.position = Vector3(0, -0.078, -0.065)
	root.add_child(mag)
	if is_lmg:
		var box_w := 0.13 if ext else 0.095
		ProcMesh.add_part(mag, ProcMesh.box_mesh(Vector3(box_w, 0.125, 0.11), Color(0.24, 0.30, 0.18), 0.72, 0.22), Vector3(-0.02, -0.01, 0))
		# Brass ammo belt link strip entering receiver
		ProcMesh.add_part(mag, ProcMesh.box_mesh(Vector3(0.04, 0.06, 0.04), Color(0.80, 0.66, 0.24), 0.35, 0.75), Vector3(-0.04, 0.06, 0))
	else:
		var mh := (0.21 if ext else 0.14) if not is_sniper else (0.12 if ext else 0.075)
		var mw := 0.024 if is_smg else 0.032
		ProcMesh.add_part(mag, ProcMesh.box_mesh(Vector3(mw, mh, 0.052), polymer, 0.72, 0.18), Vector3(0, -(mh - 0.12) * 0.45, 0), Vector3(12, 0, 0))
	_magazines[id] = mag

	# Buttstock + Pistol Grip
	ProcMesh.add_part(root, ProcMesh.box_mesh(Vector3(0.044, 0.088, 0.22), accent_col, 0.78, 0.12), Vector3(0, -0.008, rec_len * 0.5 + 0.09))
	ProcMesh.add_part(root, ProcMesh.box_mesh(Vector3(0.034, 0.095, 0.046), polymer, 0.85, 0.08), Vector3(0, -0.055, 0.085), Vector3(-18, 0, 0))

	# Modular Gunsmith Attachments!
	var muzzle_tip := brl_z - brl_len * 0.5
	muzzle_tip = _attach_muzzle(root, Vector3(0, 0.022, muzzle_tip), String(mods.get("muzzle", "none")), brl_r + 0.008, 0.22 if is_sniper else 0.17)
	var default_optic := "scope" if is_sniper else "iron"
	var chosen_optic := String(mods.get("optic", default_optic))
	if is_sniper and chosen_optic == "iron":
		chosen_optic = "scope"
	_sight_local[id] = _attach_optic(root, Vector3(0, 0.015 + rh * 0.5 + 0.014, 0.01), chosen_optic, false)
	_attach_underbarrel(root, Vector3(0, -0.025, hg_z), String(mods.get("underbarrel", "none")), false)

	# Gloved hands + forearms
	ProcMesh.add_part(root, ProcMesh.box_mesh(Vector3(0.058, 0.068, 0.075), glove), Vector3(0.005, -0.055, 0.085), Vector3(-14, 0, 0))
	ProcMesh.add_part(root, ProcMesh.box_mesh(Vector3(0.068, 0.068, 0.22), sleeve), Vector3(0.038, -0.105, 0.21), Vector3(-18, -8, 0))
	ProcMesh.add_part(root, ProcMesh.box_mesh(Vector3(0.060, 0.062, 0.076), glove), Vector3(-0.015, -0.045, hg_z))
	ProcMesh.add_part(root, ProcMesh.box_mesh(Vector3(0.062, 0.060, 0.24), sleeve), Vector3(-0.08, -0.13, hg_z + 0.11), Vector3(-22, 22, 0))

	var flash_sz := 0.06 if String(mods.get("muzzle", "none")) == "suppressor" else (0.14 if is_lmg or is_sniper else 0.11)
	var flash := _make_muzzle_flash(flash_sz, Color(1.0, 0.78, 0.22, 0.95))
	flash.position = Vector3(0, 0.022, muzzle_tip - 0.03)
	root.add_child(flash)
	_muzzle_flashes[id] = flash


func _build_shotgun(slot: Node3D, body_col: Color, accent_col: Color, mods: Dictionary) -> void:
	var wood := Color(0.42, 0.25, 0.13) if accent_col == SKIN_PALETTES["default"]["accent"] else accent_col
	var glove := Color(0.18, 0.17, 0.16)
	var sleeve := Color(0.24, 0.28, 0.20)
	var root := Node3D.new()
	root.name = "ModelRoot"
	slot.add_child(root)

	# Heavy shotgun receiver + top barrel + lower tubular magazine
	ProcMesh.add_part(root, ProcMesh.box_mesh(Vector3(0.056, 0.072, 0.24), body_col, 0.42, 0.58), Vector3(0, 0.015, 0.02))
	ProcMesh.add_part(root, ProcMesh.cylinder_mesh(0.016, 0.44, body_col.darkened(0.12), 0.35, 0.72, 10), Vector3(0, 0.034, -0.30), Vector3(90, 0, 0))
	var tube_len := 0.44 if String(mods.get("mag", "standard")) == "extended" else 0.34
	ProcMesh.add_part(root, ProcMesh.cylinder_mesh(0.014, tube_len, body_col.darkened(0.22), 0.4, 0.65, 10), Vector3(0, 0.002, -0.10 - tube_len * 0.5), Vector3(90, 0, 0))
	# Ribbed pump forend
	ProcMesh.add_part(root, ProcMesh.box_mesh(Vector3(0.056, 0.056, 0.18), wood, 0.78, 0.08), Vector3(0, -0.002, -0.25))
	# Stock
	ProcMesh.add_part(root, ProcMesh.box_mesh(Vector3(0.048, 0.090, 0.26), wood, 0.78, 0.08), Vector3(0, -0.022, 0.22), Vector3(-8, 0, 0))

	var tip := _attach_muzzle(root, Vector3(0, 0.034, -0.52), String(mods.get("muzzle", "none")), 0.022, 0.18)
	_sight_local[GameState.WeaponId.SHOTGUN] = _attach_optic(root, Vector3(0, 0.056, 0.02), String(mods.get("optic", "iron")), false)
	_attach_underbarrel(root, Vector3(0, -0.038, -0.26), String(mods.get("underbarrel", "none")), false)

	ProcMesh.add_part(root, ProcMesh.box_mesh(Vector3(0.060, 0.068, 0.075), glove), Vector3(0.006, -0.04, 0.13))
	ProcMesh.add_part(root, ProcMesh.box_mesh(Vector3(0.068, 0.068, 0.22), sleeve), Vector3(0.04, -0.095, 0.25), Vector3(-16, -8, 0))
	ProcMesh.add_part(root, ProcMesh.box_mesh(Vector3(0.062, 0.062, 0.080), glove), Vector3(-0.012, -0.035, -0.25))

	var flash := _make_muzzle_flash(0.15, Color(1.0, 0.72, 0.18, 0.95))
	flash.position = Vector3(0, 0.034, tip - 0.04)
	root.add_child(flash)
	_muzzle_flashes[GameState.WeaponId.SHOTGUN] = flash


func _build_bow(slot: Node3D, wid: GameState.WeaponId, body_col: Color, accent_col: Color, mods: Dictionary) -> void:
	var wood := Color(0.42, 0.26, 0.14) if body_col == SKIN_PALETTES["default"]["body"] else body_col
	var carbon := accent_col
	var string_col := Color(0.84, 0.82, 0.76)
	var shaft_col := Color(0.55, 0.38, 0.20)
	var glove := Color(0.18, 0.17, 0.16)
	var sleeve := Color(0.24, 0.28, 0.20)
	var root := Node3D.new()
	root.name = "ModelRoot"
	slot.add_child(root)

	# Compound bow riser + machined cutouts + twin cam pulleys!
	ProcMesh.add_part(root, ProcMesh.box_mesh(Vector3(0.034, 0.24, 0.046), carbon, 0.65, 0.25), Vector3(0, 0, 0))
	ProcMesh.add_part(root, ProcMesh.box_mesh(Vector3(0.038, 0.11, 0.050), wood, 0.82, 0.05), Vector3(0, -0.02, 0.004))
	# Sight ring + glowing pin (upgrades with optic!) — SightPoint lines up on ADS
	ProcMesh.add_part(root, ProcMesh.box_mesh(Vector3(0.038, 0.010, 0.016), carbon), Vector3(-0.024, 0.068, -0.022))
	ProcMesh.add_part(root, ProcMesh.cylinder_mesh(0.019, 0.012, carbon, 0.5, 0.4, 10), Vector3(-0.042, 0.068, -0.024), Vector3(90, 0, 0))
	var pin_col := Color(1.0, 0.2, 0.15) if String(mods.get("optic", "iron")) != "iron" else Color(0.2, 1.0, 0.35)
	var pin := ProcMesh.sphere_mesh(0.0045, pin_col)
	pin.material_override = ProcMesh.emissive(pin_col, 2.3)
	ProcMesh.add_part(root, pin, Vector3(-0.042, 0.068, -0.024))
	_sight_local[wid] = Vector3(-0.042, 0.068, -0.024)

	# Upper & lower split limbs + compound cams
	ProcMesh.add_part(root, ProcMesh.box_mesh(Vector3(0.026, 0.21, 0.026), wood, 0.72, 0.08), Vector3(0, 0.19, 0.038), Vector3(22, 0, 0))
	ProcMesh.add_part(root, ProcMesh.box_mesh(Vector3(0.020, 0.18, 0.018), carbon, 0.60, 0.25), Vector3(0, 0.34, 0.125), Vector3(38, 0, 0))
	ProcMesh.add_part(root, ProcMesh.cylinder_mesh(0.032, 0.016, Color(0.28, 0.29, 0.31), 0.35, 0.7, 10), Vector3(0, 0.41, 0.18), Vector3(0, 0, 90))
	ProcMesh.add_part(root, ProcMesh.box_mesh(Vector3(0.026, 0.21, 0.026), wood, 0.72, 0.08), Vector3(0, -0.19, 0.038), Vector3(-22, 0, 0))
	ProcMesh.add_part(root, ProcMesh.box_mesh(Vector3(0.020, 0.18, 0.018), carbon, 0.60, 0.25), Vector3(0, -0.34, 0.125), Vector3(-38, 0, 0))
	ProcMesh.add_part(root, ProcMesh.cylinder_mesh(0.032, 0.016, Color(0.28, 0.29, 0.31), 0.35, 0.7, 10), Vector3(0, -0.41, 0.18), Vector3(0, 0, 90))

	_bow_string = Node3D.new()
	_bow_string.name = "BowString"
	root.add_child(_bow_string)
	ProcMesh.add_part(_bow_string, ProcMesh.cylinder_mesh(0.0026, 0.44, string_col, 0.9, 0.0, 6), Vector3(0, 0.21, 0.19), Vector3(-5, 0, 0))
	ProcMesh.add_part(_bow_string, ProcMesh.cylinder_mesh(0.0026, 0.44, string_col, 0.9, 0.0, 6), Vector3(0, -0.21, 0.19), Vector3(5, 0, 0))

	# Visible nocked arrow with Standard / Fire / Explosive warhead!
	_bow_arrow = _build_arrow_mesh(shaft_col, String(mods.get("arrow", "standard")))
	_bow_arrow.name = "BowArrow"
	_bow_arrow.position = Vector3(-0.022, 0.035, -0.04)
	root.add_child(_bow_arrow)

	ProcMesh.add_part(root, ProcMesh.box_mesh(Vector3(0.062, 0.074, 0.068), glove), Vector3(0.012, -0.025, 0.015))
	ProcMesh.add_part(root, ProcMesh.box_mesh(Vector3(0.068, 0.066, 0.22), sleeve), Vector3(0.065, -0.095, 0.145), Vector3(-18, -16, 0))


func _build_crossbow(slot: Node3D, body_col: Color, accent_col: Color, mods: Dictionary) -> void:
	var polymer := Color(0.11, 0.12, 0.13)
	var string_col := Color(0.84, 0.82, 0.76)
	var glove := Color(0.18, 0.17, 0.16)
	var sleeve := Color(0.24, 0.28, 0.20)
	var root := Node3D.new()
	root.name = "ModelRoot"
	slot.add_child(root)

	# Stock + bolt flight rail
	ProcMesh.add_part(root, ProcMesh.box_mesh(Vector3(0.048, 0.054, 0.48), body_col, 0.55, 0.35), Vector3(0, 0.01, -0.08))
	ProcMesh.add_part(root, ProcMesh.box_mesh(Vector3(0.044, 0.082, 0.20), accent_col, 0.75, 0.12), Vector3(0, -0.012, 0.22))
	ProcMesh.add_part(root, ProcMesh.box_mesh(Vector3(0.034, 0.090, 0.046), polymer), Vector3(0, -0.055, 0.08), Vector3(-16, 0, 0))
	# Horizontal crossbow prod limbs + cams
	ProcMesh.add_part(root, ProcMesh.box_mesh(Vector3(0.26, 0.024, 0.032), accent_col, 0.6, 0.25), Vector3(-0.14, 0.02, -0.27), Vector3(0, 24, 0))
	ProcMesh.add_part(root, ProcMesh.box_mesh(Vector3(0.26, 0.024, 0.032), accent_col, 0.6, 0.25), Vector3(0.14, 0.02, -0.27), Vector3(0, -24, 0))
	# Drawn bowstring across rail
	ProcMesh.add_part(root, ProcMesh.cylinder_mesh(0.0028, 0.26, string_col, 0.9, 0.0, 6), Vector3(-0.12, 0.035, -0.15), Vector3(0, 32, 90))
	ProcMesh.add_part(root, ProcMesh.cylinder_mesh(0.0028, 0.26, string_col, 0.9, 0.0, 6), Vector3(0.12, 0.035, -0.15), Vector3(0, -32, 90))
	# Loaded bolt with standard / fire / explosive tip
	var bolt := _build_arrow_mesh(Color(0.25, 0.26, 0.28), String(mods.get("arrow", "standard")))
	bolt.scale = Vector3(0.9, 0.9, 0.78)
	bolt.position = Vector3(0, 0.042, -0.16)
	root.add_child(bolt)

	_sight_local[GameState.WeaponId.CROSSBOW] = _attach_optic(root, Vector3(0, 0.048, 0.02), String(mods.get("optic", "red_dot")), false)
	ProcMesh.add_part(root, ProcMesh.box_mesh(Vector3(0.058, 0.068, 0.075), glove), Vector3(0.005, -0.055, 0.085))
	ProcMesh.add_part(root, ProcMesh.box_mesh(Vector3(0.068, 0.068, 0.22), sleeve), Vector3(0.038, -0.105, 0.21), Vector3(-18, -8, 0))


func _build_arrow_mesh(shaft_col: Color, arrow_type: String) -> Node3D:
	var a := Node3D.new()
	var steel := Color(0.75, 0.78, 0.82)
	ProcMesh.add_part(a, ProcMesh.cylinder_mesh(0.0055, 0.56, shaft_col, 0.7, 0.05, 8), Vector3(0, 0, 0), Vector3(90, 0, 0))
	if arrow_type == "fire":
		# Burning rag-wrapped incendiary tip!
		var tip := ProcMesh.sphere_mesh(0.022, Color(1.0, 0.48, 0.10))
		tip.material_override = ProcMesh.emissive(Color(1.0, 0.45, 0.08), 2.8)
		ProcMesh.add_part(a, tip, Vector3(0, 0, -0.30))
	elif arrow_type == "explosive":
		# Red/brass explosive warhead canister!
		ProcMesh.add_part(a, ProcMesh.cylinder_mesh(0.017, 0.075, Color(0.82, 0.16, 0.12), 0.4, 0.4, 8), Vector3(0, 0, -0.30), Vector3(90, 0, 0))
		var ring := ProcMesh.cylinder_mesh(0.019, 0.016, Color(0.95, 0.78, 0.18), 0.3, 0.6, 8)
		ring.material_override = ProcMesh.emissive(Color(1.0, 0.75, 0.15), 1.6)
		ProcMesh.add_part(a, ring, Vector3(0, 0, -0.32), Vector3(90, 0, 0))
	else:
		ProcMesh.add_part(a, ProcMesh.cone_mesh(0.014, 0.001, 0.068, steel, 0.28, 0.80, 6), Vector3(0, 0, -0.31), Vector3(-90, 0, 0))
		ProcMesh.add_part(a, ProcMesh.box_mesh(Vector3(0.030, 0.003, 0.052), steel, 0.25, 0.85), Vector3(0, 0, -0.295))
	var fletch_col := Color(0.95, 0.48, 0.12) if arrow_type == "fire" else (Color(0.95, 0.82, 0.18) if arrow_type == "explosive" else Color(0.88, 0.18, 0.14))
	ProcMesh.add_part(a, ProcMesh.box_mesh(Vector3(0.003, 0.024, 0.082), fletch_col, 0.85, 0.0), Vector3(0, 0.012, 0.21))
	ProcMesh.add_part(a, ProcMesh.box_mesh(Vector3(0.022, 0.003, 0.082), Color(0.95, 0.95, 0.92), 0.85, 0.0), Vector3(0.010, -0.007, 0.21), Vector3(0, 0, 28))
	return a


func _build_knife(slot: Node3D, body_col: Color) -> void:
	var steel := Color(0.76, 0.80, 0.84) if body_col == SKIN_PALETTES["default"]["body"] else body_col.lightened(0.25)
	var dark_steel := Color(0.32, 0.35, 0.39)
	var brass := Color(0.62, 0.50, 0.24)
	var handle := Color(0.24, 0.16, 0.10)
	var glove := Color(0.18, 0.17, 0.16)
	var sleeve := Color(0.24, 0.28, 0.20)
	var root := Node3D.new()
	root.name = "ModelRoot"
	slot.add_child(root)
	ProcMesh.add_part(root, ProcMesh.box_mesh(Vector3(0.007, 0.036, 0.165), steel, 0.25, 0.82), Vector3(0, 0.012, -0.105))
	ProcMesh.add_part(root, ProcMesh.box_mesh(Vector3(0.009, 0.012, 0.160), dark_steel, 0.42, 0.65), Vector3(0, 0.026, -0.102))
	ProcMesh.add_part(root, ProcMesh.cone_mesh(0.019, 0.001, 0.065, steel, 0.24, 0.85, 4), Vector3(0, 0.012, -0.218), Vector3(-90, 0, 45))
	ProcMesh.add_part(root, ProcMesh.box_mesh(Vector3(0.018, 0.068, 0.016), brass, 0.38, 0.72), Vector3(0, 0.010, -0.018))
	ProcMesh.add_part(root, ProcMesh.box_mesh(Vector3(0.022, 0.030, 0.115), handle, 0.88, 0.05), Vector3(0, 0.006, 0.046))
	ProcMesh.add_part(root, ProcMesh.box_mesh(Vector3(0.060, 0.066, 0.088), glove), Vector3(0.008, -0.002, 0.055))
	ProcMesh.add_part(root, ProcMesh.box_mesh(Vector3(0.068, 0.068, 0.24), sleeve), Vector3(0.055, -0.065, 0.185), Vector3(-16, -15, 0))


func _build_frag(slot: Node3D) -> void:
	var glove := Color(0.18, 0.17, 0.16)
	var sleeve := Color(0.24, 0.28, 0.20)
	var root := Node3D.new()
	root.name = "ModelRoot"
	slot.add_child(root)
	ProcMesh.add_part(root, ProcMesh.sphere_mesh(0.058, Color(0.24, 0.31, 0.20), 0.72, 0.2), Vector3(0, 0.01, -0.03))
	ProcMesh.add_part(root, ProcMesh.cylinder_mesh(0.059, 0.016, Color(0.88, 0.76, 0.18), 0.5, 0.1, 10), Vector3(0, 0.022, -0.03))
	ProcMesh.add_part(root, ProcMesh.box_mesh(Vector3(0.028, 0.036, 0.028), Color(0.45, 0.46, 0.44), 0.4, 0.6), Vector3(0, 0.072, -0.03))
	ProcMesh.add_part(root, ProcMesh.cylinder_mesh(0.018, 0.006, Color(0.76, 0.78, 0.80), 0.3, 0.8, 10), Vector3(-0.024, 0.075, -0.03), Vector3(90, 0, 0))
	ProcMesh.add_part(root, ProcMesh.box_mesh(Vector3(0.066, 0.066, 0.082), glove), Vector3(0.018, -0.022, 0.02))
	ProcMesh.add_part(root, ProcMesh.box_mesh(Vector3(0.070, 0.068, 0.22), sleeve), Vector3(0.06, -0.08, 0.16), Vector3(-18, -14, 0))


func _build_molotov(slot: Node3D) -> void:
	var glove := Color(0.18, 0.17, 0.16)
	var sleeve := Color(0.24, 0.28, 0.20)
	var root := Node3D.new()
	root.name = "ModelRoot"
	slot.add_child(root)
	ProcMesh.add_part(root, ProcMesh.cylinder_mesh(0.042, 0.16, Color(0.76, 0.42, 0.12), 0.22, 0.18, 10), Vector3(0, 0.0, -0.04))
	ProcMesh.add_part(root, ProcMesh.cylinder_mesh(0.016, 0.08, Color(0.68, 0.42, 0.16), 0.22, 0.18, 8), Vector3(0, 0.11, -0.04))
	ProcMesh.add_part(root, ProcMesh.box_mesh(Vector3(0.028, 0.065, 0.022), Color(0.86, 0.82, 0.74)), Vector3(0.006, 0.165, -0.04), Vector3(0, 0, -18))
	var flame := ProcMesh.cone_mesh(0.028, 0.004, 0.075, Color(1.0, 0.56, 0.10), 0.6, 0.0, 6)
	flame.material_override = ProcMesh.emissive(Color(1.0, 0.52, 0.08), 2.8)
	ProcMesh.add_part(root, flame, Vector3(0.015, 0.215, -0.04))
	ProcMesh.add_part(root, ProcMesh.box_mesh(Vector3(0.066, 0.066, 0.082), glove), Vector3(0.016, -0.018, 0.01))
	ProcMesh.add_part(root, ProcMesh.box_mesh(Vector3(0.070, 0.068, 0.22), sleeve), Vector3(0.06, -0.08, 0.16), Vector3(-18, -14, 0))


func _build_machete(slot: Node3D, body_col: Color) -> void:
	var steel := Color(0.64, 0.67, 0.70) if body_col == SKIN_PALETTES["default"]["body"] else body_col.lightened(0.22)
	var edge := Color(0.86, 0.89, 0.92)
	var handle := Color(0.24, 0.15, 0.09)
	var glove := Color(0.18, 0.17, 0.16)
	var sleeve := Color(0.24, 0.28, 0.20)
	var root := Node3D.new()
	root.name = "ModelRoot"
	slot.add_child(root)
	# Wide curved kukri machete blade
	ProcMesh.add_part(root, ProcMesh.box_mesh(Vector3(0.008, 0.056, 0.28), steel, 0.3, 0.78), Vector3(0, 0.025, -0.17))
	ProcMesh.add_part(root, ProcMesh.box_mesh(Vector3(0.006, 0.068, 0.14), edge, 0.2, 0.88), Vector3(0, 0.018, -0.35), Vector3(-12, 0, 0))
	ProcMesh.add_part(root, ProcMesh.box_mesh(Vector3(0.026, 0.036, 0.14), handle, 0.86, 0.05), Vector3(0, 0.004, 0.04))
	ProcMesh.add_part(root, ProcMesh.box_mesh(Vector3(0.062, 0.068, 0.088), glove), Vector3(0.008, -0.002, 0.05))
	ProcMesh.add_part(root, ProcMesh.box_mesh(Vector3(0.068, 0.068, 0.24), sleeve), Vector3(0.055, -0.065, 0.185), Vector3(-16, -15, 0))


func _build_bat(slot: Node3D, body_col: Color, accent_col: Color) -> void:
	var barrel_col := Color(0.74, 0.77, 0.80) if body_col == SKIN_PALETTES["default"]["body"] else body_col.lightened(0.18)
	var grip := Color(0.14, 0.14, 0.15)
	var glove := Color(0.18, 0.17, 0.16)
	var sleeve := Color(0.24, 0.28, 0.20)
	var root := Node3D.new()
	root.name = "ModelRoot"
	slot.add_child(root)
	# Tapered aluminum bat: handle + flared barrel + painted stripe + knob
	ProcMesh.add_part(root, ProcMesh.cylinder_mesh(0.017, 0.20, grip, 0.88, 0.05, 8), Vector3(0, 0.0, 0.02), Vector3(90, 0, 0))
	ProcMesh.add_part(root, ProcMesh.cone_mesh(0.036, 0.017, 0.42, barrel_col, 0.24, 0.82, 10), Vector3(0, 0.0, -0.28), Vector3(90, 0, 0))
	ProcMesh.add_part(root, ProcMesh.cylinder_mesh(0.037, 0.075, accent_col, 0.45, 0.35, 10), Vector3(0, 0.0, -0.36), Vector3(90, 0, 0))
	ProcMesh.add_part(root, ProcMesh.cylinder_mesh(0.024, 0.018, grip, 0.8, 0.1, 8), Vector3(0, 0.0, 0.125), Vector3(90, 0, 0))
	ProcMesh.add_part(root, ProcMesh.box_mesh(Vector3(0.062, 0.068, 0.090), glove), Vector3(0.008, -0.004, 0.04))
	ProcMesh.add_part(root, ProcMesh.box_mesh(Vector3(0.068, 0.068, 0.24), sleeve), Vector3(0.055, -0.065, 0.18), Vector3(-16, -15, 0))


# ============================================================================
# VISIBLE GUNSMITH ATTACHMENT BUILDERS
# ============================================================================
func _attach_muzzle(root: Node3D, pos: Vector3, muzzle: String, radius: float, length: float) -> float:
	if muzzle == "suppressor":
		var sup_col := Color(0.09, 0.10, 0.11)
		ProcMesh.add_part(root, ProcMesh.cylinder_mesh(radius, length, sup_col, 0.46, 0.52, 10), pos + Vector3(0, 0, -length * 0.5), Vector3(90, 0, 0))
		ProcMesh.add_part(root, ProcMesh.cylinder_mesh(radius + 0.003, 0.018, Color(0.24, 0.25, 0.27), 0.35, 0.68, 10), pos, Vector3(90, 0, 0))
		return pos.z - length
	elif muzzle == "compensator":
		var comp_col := Color(0.20, 0.21, 0.23)
		ProcMesh.add_part(root, ProcMesh.box_mesh(Vector3(radius * 2.1, radius * 1.9, 0.065), comp_col, 0.4, 0.65), pos + Vector3(0, 0, -0.032))
		return pos.z - 0.065
	return pos.z


func _tag_occlude(mi: MeshInstance3D) -> MeshInstance3D:
	## Housing that would fill the camera on ADS — faded out when fully aimed.
	if is_instance_valid(mi):
		mi.set_meta("optic_occlude", true)
	return mi


func _glass_disc(radius: float, depth: float = 0.004) -> MeshInstance3D:
	## Transparent lens plane (Compatibility-safe alpha). Keeps a see-through aperture.
	## High quality uses a fresnel scope-lens shader; Low/Med keep a flat glass disc.
	var disc := ProcMesh.cylinder_mesh(radius, depth, Color(0.55, 0.75, 0.95, 0.18), 0.15, 0.0, 10)
	if GraphicsQuality:
		disc.material_override = GraphicsQuality.make_scope_lens_material(Color(0.55, 0.78, 1.0, 0.16))
	else:
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_color = Color(0.55, 0.78, 1.0, 0.16)
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
		disc.material_override = mat
	return disc


func _attach_optic(root: Node3D, pos: Vector3, optic: String, compact: bool) -> Vector3:
	## Builds optic/iron sights and returns the local SightPoint used for ADS alignment.
	## Critical: never put a solid mesh on the eye line — that rendered as a black wall on ADS
	## under GL Compatibility (opaque cylinder filled the FOV).
	var housing := Color(0.11, 0.12, 0.13)
	var sight := pos + Vector3(0.0, 0.018, 0.0)
	match optic:
		"red_dot":
			var s := 0.72 if compact else 1.0
			# Rail mount only — open aperture, no solid tube through the eye.
			_tag_occlude(ProcMesh.add_part(root, ProcMesh.box_mesh(Vector3(0.034 * s, 0.010 * s, 0.055 * s), housing), pos))
			# Thin square hood (open window) instead of a filled cylinder
			var hood_y := 0.022 * s
			var hood_h := 0.028 * s
			var hood_w := 0.030 * s
			var hood_d := 0.040 * s
			_tag_occlude(ProcMesh.add_part(root, ProcMesh.box_mesh(Vector3(0.004 * s, hood_h, hood_d), housing), pos + Vector3(-hood_w * 0.5, hood_y, 0)))
			_tag_occlude(ProcMesh.add_part(root, ProcMesh.box_mesh(Vector3(0.004 * s, hood_h, hood_d), housing), pos + Vector3(hood_w * 0.5, hood_y, 0)))
			_tag_occlude(ProcMesh.add_part(root, ProcMesh.box_mesh(Vector3(hood_w, 0.004 * s, hood_d), housing), pos + Vector3(0, hood_y + hood_h * 0.5, 0)))
			# See-through glass + emissive reticle (never occluded)
			sight = pos + Vector3(0, hood_y, -0.002)
			ProcMesh.add_part(root, _glass_disc(0.012 * s), sight, Vector3(90, 0, 0), "OpticGlass")
			var dot := ProcMesh.sphere_mesh(0.0036 * s, Color(1.0, 0.18, 0.12))
			dot.material_override = ProcMesh.emissive(Color(1.0, 0.22, 0.12), 3.2)
			dot.set_meta("optic_reticle", true)
			ProcMesh.add_part(root, dot, sight, Vector3.ZERO, "OpticReticle")
		"holo":
			var s := 0.78 if compact else 1.0
			_tag_occlude(ProcMesh.add_part(root, ProcMesh.box_mesh(Vector3(0.042 * s, 0.012 * s, 0.072 * s), housing), pos))
			# Open window frame — hollow center so ADS looks through, not into black plastic
			_tag_occlude(ProcMesh.add_part(root, ProcMesh.box_mesh(Vector3(0.008 * s, 0.036 * s, 0.062 * s), housing), pos + Vector3(-0.018 * s, 0.024 * s, 0)))
			_tag_occlude(ProcMesh.add_part(root, ProcMesh.box_mesh(Vector3(0.008 * s, 0.036 * s, 0.062 * s), housing), pos + Vector3(0.018 * s, 0.024 * s, 0)))
			_tag_occlude(ProcMesh.add_part(root, ProcMesh.box_mesh(Vector3(0.044 * s, 0.009 * s, 0.062 * s), housing), pos + Vector3(0, 0.042 * s, 0)))
			sight = pos + Vector3(0, 0.024 * s, -0.004)
			ProcMesh.add_part(root, _glass_disc(0.014 * s), sight, Vector3(90, 0, 0), "OpticGlass")
			var ret := ProcMesh.sphere_mesh(0.0040 * s, Color(0.25, 1.0, 0.35))
			ret.material_override = ProcMesh.emissive(Color(0.3, 1.0, 0.4), 3.0)
			ret.set_meta("optic_reticle", true)
			ProcMesh.add_part(root, ret, sight, Vector3.ZERO, "OpticReticle")
		"scope":
			# Hollow tube look: mounts + thin rings only; solid barrel marked occlude
			# (sniper ADS hides the whole viewmodel under the 2D scope overlay anyway).
			var tube := ProcMesh.cylinder_mesh(0.017, 0.24, housing, 0.38, 0.55, 10)
			_tag_occlude(ProcMesh.add_part(root, tube, pos + Vector3(0, 0.032, -0.03), Vector3(90, 0, 0), "ScopeTube"))
			_tag_occlude(ProcMesh.add_part(root, ProcMesh.cylinder_mesh(0.024, 0.075, housing, 0.38, 0.55, 10), pos + Vector3(0, 0.032, -0.15), Vector3(90, 0, 0)))
			_tag_occlude(ProcMesh.add_part(root, ProcMesh.box_mesh(Vector3(0.026, 0.028, 0.016), housing), pos + Vector3(0, 0.014, 0.03)))
			_tag_occlude(ProcMesh.add_part(root, ProcMesh.box_mesh(Vector3(0.026, 0.028, 0.016), housing), pos + Vector3(0, 0.014, -0.08)))
			sight = pos + Vector3(0.0, 0.032, -0.03)
			ProcMesh.add_part(root, _glass_disc(0.015), sight + Vector3(0, 0, 0.11), Vector3(90, 0, 0), "ScopeLensFront")
			ProcMesh.add_part(root, _glass_disc(0.012), sight + Vector3(0, 0, -0.11), Vector3(90, 0, 0), "ScopeLensRear")
		_:
			# Iron sights: rear notch + glowing front post — same tip height so ADS lines up.
			var s := 0.78 if compact else 1.0
			var tip_y := 0.022 * s  # shared tip height for rear posts + front blade
			var rear_z := 0.045 * s
			var front_z := -0.085 if not compact else -0.055
			# Rear base + twin posts (notch aperture centered on tip_y)
			ProcMesh.add_part(root, ProcMesh.box_mesh(Vector3(0.030 * s, 0.012 * s, 0.014 * s), housing), pos + Vector3(0, tip_y * 0.35, rear_z))
			ProcMesh.add_part(root, ProcMesh.box_mesh(Vector3(0.0055 * s, tip_y * 0.95, 0.010 * s), housing), pos + Vector3(-0.011 * s, tip_y * 0.55, rear_z))
			ProcMesh.add_part(root, ProcMesh.box_mesh(Vector3(0.0055 * s, tip_y * 0.95, 0.010 * s), housing), pos + Vector3(0.011 * s, tip_y * 0.55, rear_z))
			# Front post — tip matches rear notch tip
			var fs := ProcMesh.box_mesh(Vector3(0.0045 * s, tip_y * 0.95, 0.009 * s), Color(0.2, 0.95, 0.45))
			fs.material_override = ProcMesh.emissive(Color(0.25, 1.0, 0.45), 1.6)
			fs.set_meta("optic_reticle", true)
			var front_pos := pos + Vector3(0, tip_y * 0.55, front_z)
			ProcMesh.add_part(root, fs, front_pos, Vector3.ZERO, "IronFront")
			# ADS sight point: midpoint between rear notch and front tip (same Y)
			sight = pos + Vector3(0.0, tip_y, (rear_z + front_z) * 0.5)
	var marker := Marker3D.new()
	marker.name = "SightPoint"
	marker.position = sight
	root.add_child(marker)
	return sight


func _attach_underbarrel(root: Node3D, pos: Vector3, underbarrel: String, compact: bool) -> void:
	var housing := Color(0.11, 0.12, 0.13)
	if underbarrel == "grip" and not compact:
		ProcMesh.add_part(root, ProcMesh.cylinder_mesh(0.015, 0.095, housing, 0.85, 0.08, 8), pos + Vector3(0, -0.045, 0))
	elif underbarrel == "laser":
		ProcMesh.add_part(root, ProcMesh.box_mesh(Vector3(0.024, 0.022, 0.065), housing, 0.5, 0.4), pos + Vector3(0.022 if not compact else 0.0, 0.0, 0.0))
		var beam := ProcMesh.cylinder_mesh(0.0022, 2.2, Color(0.15, 1.0, 0.25))
		beam.material_override = ProcMesh.emissive(Color(0.2, 1.0, 0.3), 2.8)
		ProcMesh.add_part(root, beam, pos + Vector3(0.022 if not compact else 0.0, 0.0, -1.14), Vector3(90, 0, 0))


func _make_muzzle_flash(size: float, color: Color) -> Node3D:
	var n := Node3D.new()
	n.name = "MuzzleFlash"
	var m_outer := ProcMesh.unshaded(color)
	var m_core := ProcMesh.unshaded(Color(1.0, 0.98, 0.85, 0.95))
	for deg in [0.0, 60.0, 120.0]:
		var fin := ProcMesh.box_mesh(Vector3(size * 1.4, size * 0.28, size * 0.18), color)
		fin.material_override = m_outer
		ProcMesh.add_part(n, fin, Vector3.ZERO, Vector3(0, 0, deg))
	var cone := ProcMesh.cone_mesh(size * 0.32, 0.002, size * 1.4, color, 0.5, 0.0, 6)
	cone.material_override = m_core
	ProcMesh.add_part(n, cone, Vector3(0, 0, -size * 0.55), Vector3(-90, 0, 0))
	n.visible = false
	return n


# ============================================================================
# ANIMATION API
# ============================================================================
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
	_inspect_t = 0.0
	if animate_swap:
		_swap_t = _swap_dur


func set_move_factor(factor: float) -> void:
	_move_factor = clampf(factor, 0.0, 1.5)


func set_bow_arrow_visible(has_arrow: bool) -> void:
	if is_instance_valid(_bow_arrow):
		_bow_arrow.visible = has_arrow


func play_fire(id: GameState.WeaponId) -> void:
	_active_id = id
	var is_swing := id in [GameState.WeaponId.KNIFE, GameState.WeaponId.MACHETE, GameState.WeaponId.BAT, GameState.WeaponId.FRAG, GameState.WeaponId.MOLOTOV]
	_fire_dur = 0.28 if is_swing else (0.24 if id in [GameState.WeaponId.BOW, GameState.WeaponId.SHOTGUN, GameState.WeaponId.SNIPER] else 0.13)
	_fire_t = _fire_dur
	_inspect_t = 0.0
	var flash: Node3D = _muzzle_flashes.get(id)
	if is_instance_valid(flash):
		flash.visible = true
		flash.rotation.z = randf() * TAU
		var s := randf_range(0.85, 1.25)
		flash.scale = Vector3(s, s, s)
		_flash_t = 0.08


func play_reload(duration: float = 1.4) -> void:
	_reload_dur = maxf(0.3, duration)
	_reload_t = _reload_dur
	_inspect_t = 0.0


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


func set_aiming(aiming: bool, ads_time: float = 0.28, breath_hold: float = 0.0) -> void:
	_aim_target = 1.0 if aiming else 0.0
	_ads_speed = 1.0 / maxf(0.08, ads_time)
	_breath_hold = clampf(breath_hold, 0.0, 1.0)


func get_aim_blend() -> float:
	return _aim_blend


func add_look_sway(delta_xy: Vector2) -> void:
	var damp := 1.0 - _aim_blend * 0.78
	_sway.x = clampf(_sway.x - delta_xy.x * 0.0028 * damp, -0.045, 0.045)
	_sway.y = clampf(_sway.y + delta_xy.y * 0.0022 * damp, -0.035, 0.035)


func get_slot(id: GameState.WeaponId) -> Node3D:
	return _slots.get(id) as Node3D


func _process(delta: float) -> void:
	_idle_time += delta
	_aim_blend = move_toward(_aim_blend, _aim_target, delta * _ads_speed)
	var sway_recover := 9.0 + _aim_blend * 6.0 + _breath_hold * 8.0
	_sway = _sway.lerp(Vector2.ZERO, clampf(delta * sway_recover, 0.0, 1.0))
	var slot: Node3D = _slots.get(_active_id)
	if not is_instance_valid(slot) or not slot.visible:
		_update_throw_arc(false)
		return

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

	# Smooth hip -> ADS raise that centers the fitted SightPoint on screen centre
	var ads := _aim_blend
	_update_optic_occlusion(slot, ads)
	if ads > 0.001 and not _carrying and _inspect_t <= 0.0:
		var ads_pose := _ads_pose_for(_active_id, base_p, base_r)
		offset_p += (ads_pose["pos"] - base_p) * ads
		offset_r += (ads_pose["rot"] - base_r) * ads
		# Subtle ADS idle sway + breath-hold stabilization
		var idle_sway := (1.0 - _breath_hold * 0.85) * ads
		offset_p.x += sin(_idle_time * 1.35) * 0.0018 * idle_sway
		offset_p.y += cos(_idle_time * 1.1) * 0.0014 * idle_sway
		offset_r.z += sin(_idle_time * 0.9) * 0.55 * idle_sway

	var aim_damp := 1.0 - ads * 0.82
	var bob_amp := (0.004 + _move_factor * 0.011) * aim_damp * (1.0 - _breath_hold * 0.5)
	var bob_freq := 2.2 + _move_factor * 6.5
	offset_p.x += sin(_idle_time * bob_freq * 0.5) * bob_amp
	offset_p.y += absf(cos(_idle_time * bob_freq * 0.5)) * bob_amp * 0.85

	# Bow / crossbow draw-and-aim string pull while ADS
	if ads > 0.01 and _active_id == GameState.WeaponId.BOW and is_instance_valid(_bow_string):
		_bow_string.position.z = lerpf(0.0, 0.085, ads)
		if is_instance_valid(_bow_arrow):
			_bow_arrow.position.z = lerpf(-0.04, 0.05, ads)
	elif is_instance_valid(_bow_string):
		_bow_string.position.z = move_toward(_bow_string.position.z, 0.0, delta * 4.0)

	if _swap_t > 0.0:
		_swap_t = maxf(0.0, _swap_t - delta)
		var u := _swap_t / _swap_dur
		var ease_u := u * u
		offset_p.y -= 0.24 * ease_u
		offset_r.x -= 35.0 * ease_u

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

	if _takedown_t > 0.0:
		_takedown_t = maxf(0.0, _takedown_t - delta)
		var p := 1.0 - (_takedown_t / _takedown_dur)
		var lunge := sin(p * PI)
		if _takedown_behind:
			offset_p.z -= 0.20 * lunge
			offset_p.x -= 0.16 * lunge
			offset_p.y += 0.04 * lunge
			offset_r.y += 65.0 * lunge
			offset_r.z -= 40.0 * lunge
		else:
			offset_p.z -= 0.24 * lunge
			offset_p.y += 0.08 * lunge
			offset_r.x -= 48.0 * lunge
			offset_r.z += 28.0 * lunge

	if _vault_p > 0.001:
		var v_arc := sin(_vault_p * PI)
		offset_p.y -= 0.22 * v_arc
		offset_p.z -= 0.08 * v_arc
		offset_r.x -= 38.0 * v_arc
		offset_r.z -= 16.0 * v_arc

	if _carrying:
		offset_p.y -= 0.28 if not _dragging else 0.32
		offset_r.x -= 44.0

	if _fire_t > 0.0:
		_fire_t = maxf(0.0, _fire_t - delta)
		var u := _fire_t / maxf(0.01, _fire_dur)
		# ADS fire recoil is snappier / shorter travel so the sight stays on target
		var kick := sin(u * PI) * lerpf(1.0, 0.42, ads)
		match _active_id:
			GameState.WeaponId.PISTOL, GameState.WeaponId.MACHINE_PISTOL:
				offset_p.z += 0.045 * kick
				offset_p.y += 0.012 * kick
				offset_r.x += 12.0 * kick
				if is_instance_valid(_pistol_slide) and _active_id == GameState.WeaponId.PISTOL:
					_pistol_slide.position.z = 0.042 * kick
			GameState.WeaponId.SHOTGUN, GameState.WeaponId.SNIPER:
				offset_p.z += 0.075 * kick
				offset_p.y += 0.025 * kick
				offset_r.x += 18.0 * kick
			GameState.WeaponId.BOW:
				offset_p.z += 0.05 * kick
				offset_r.x += 8.0 * kick
				if is_instance_valid(_bow_string):
					_bow_string.position.z = lerpf(0.0, 0.085, ads) - 0.035 * kick
			GameState.WeaponId.KNIFE, GameState.WeaponId.FRAG, GameState.WeaponId.MOLOTOV:
				offset_p.z -= 0.14 * kick
				offset_p.x -= 0.08 * kick
				offset_r.x -= 48.0 * kick
				offset_r.z += 22.0 * kick
			GameState.WeaponId.MACHETE, GameState.WeaponId.BAT:
				offset_p.z -= 0.18 * kick
				offset_p.x -= 0.22 * kick
				offset_r.y += 72.0 * kick
				offset_r.z += 44.0 * kick
				offset_r.x -= 28.0 * kick
			_:
				offset_p.z += 0.038 * kick
				offset_p.y += 0.010 * kick
				offset_r.x += 7.0 * kick
	else:
		if is_instance_valid(_pistol_slide):
			_pistol_slide.position.z = 0.0

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
			var rest_y := -0.112 if _active_id in [GameState.WeaponId.PISTOL, GameState.WeaponId.MACHINE_PISTOL] else -0.078
			mag.position.y = rest_y - 0.16 * mag_drop
	else:
		for wid in _magazines.keys():
			var m: Node3D = _magazines[wid]
			if is_instance_valid(m):
				m.position.y = -0.112 if wid in [GameState.WeaponId.PISTOL, GameState.WeaponId.MACHINE_PISTOL] else -0.078

	var target_p := base_p + offset_p
	var target_r := base_r + offset_r
	# Snap harder while raising into ADS so the sight settles cleanly
	var smooth := clampf(delta * lerpf(18.0, 28.0, ads), 0.0, 1.0)
	slot.position = slot.position.lerp(target_p, smooth)
	slot.rotation_degrees = slot.rotation_degrees.lerp(target_r, smooth)

	var show_arc := ads > 0.35 and _active_id in [GameState.WeaponId.FRAG, GameState.WeaponId.MOLOTOV, GameState.WeaponId.KNIFE]
	_update_throw_arc(show_arc)


func _update_optic_occlusion(slot: Node3D, ads: float) -> void:
	## Fade housing that would sit on the eye line once fully ADS — keeps reticle/glass.
	if not is_instance_valid(slot):
		return
	var hide_body := ads > 0.82
	for n in slot.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if not is_instance_valid(mi):
			continue
		if mi.has_meta("optic_reticle"):
			mi.visible = true
			continue
		if mi.has_meta("optic_occlude"):
			mi.visible = not hide_body


func _ads_pose_for(wid: GameState.WeaponId, _base_p: Vector3, _base_r: Vector3) -> Dictionary:
	## Returns the ADS slot position/rotation that lines the SightPoint up with
	## camera centre (0,0) looking down -Z. Melee/throwables get ready poses.
	match wid:
		GameState.WeaponId.MACHETE, GameState.WeaponId.BAT:
			return {
				"pos": Vector3(0.10, -0.12, -0.38),
				"rot": Vector3(-28.0, 8.0, -18.0),
			}
		GameState.WeaponId.FRAG, GameState.WeaponId.MOLOTOV:
			return {
				"pos": Vector3(0.14, -0.02, -0.42),
				"rot": Vector3(-42.0, 12.0, 18.0),
			}
		GameState.WeaponId.KNIFE:
			return {
				"pos": Vector3(0.06, -0.08, -0.40),
				"rot": Vector3(-18.0, 6.0, -6.0),
			}
		GameState.WeaponId.BOW, GameState.WeaponId.HUNTER_BOW:
			var bow_sight: Vector3 = _sight_local.get(wid, Vector3(-0.042, 0.068, -0.024))
			return {
				"pos": Vector3(-bow_sight.x, -bow_sight.y + 0.008, -0.50 - bow_sight.z),
				"rot": Vector3(0.0, 0.0, 0.0),
			}
		_:
			var sight: Vector3 = _sight_local.get(wid, Vector3(0.0, 0.06, 0.02))
			# Per-weapon hold distance — far enough to avoid clipping hands/receiver
			var hold_z := 0.52
			match wid:
				GameState.WeaponId.PISTOL, GameState.WeaponId.MACHINE_PISTOL, GameState.WeaponId.TRANQ_PISTOL:
					hold_z = 0.46
				GameState.WeaponId.SMG:
					hold_z = 0.50
				GameState.WeaponId.SHOTGUN, GameState.WeaponId.LMG:
					hold_z = 0.54
				GameState.WeaponId.SNIPER, GameState.WeaponId.SILENCED_SNIPER:
					hold_z = 0.44
				GameState.WeaponId.CROSSBOW:
					hold_z = 0.50
				_:
					hold_z = 0.52
			# Zero yaw/pitch so rear+front sit on screen centre; tiny pitch trim per family
			var pitch_trim := 0.0
			match wid:
				GameState.WeaponId.SHOTGUN:
					pitch_trim = -0.4
				GameState.WeaponId.PISTOL, GameState.WeaponId.MACHINE_PISTOL:
					pitch_trim = 0.3
			return {
				"pos": Vector3(-sight.x, -sight.y, -hold_z - sight.z),
				"rot": Vector3(pitch_trim, 0.0, 0.0),
			}


func _ensure_throw_arc() -> void:
	if is_instance_valid(_throw_arc):
		return
	_throw_arc = MeshInstance3D.new()
	_throw_arc.name = "ThrowArcPreview"
	_throw_arc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_throw_arc_mat = StandardMaterial3D.new()
	_throw_arc_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_throw_arc_mat.albedo_color = Color(1.0, 0.72, 0.18, 0.85)
	_throw_arc_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_throw_arc.material_override = _throw_arc_mat
	add_child(_throw_arc)


func _update_throw_arc(show: bool) -> void:
	_ensure_throw_arc()
	_throw_arc.visible = show
	if not show:
		return
	var speed := 16.0
	match _active_id:
		GameState.WeaponId.KNIFE:
			speed = 38.0
		GameState.WeaponId.FRAG:
			speed = 18.0
		GameState.WeaponId.MOLOTOV:
			speed = 16.0
	var gravity := float(ProjectSettings.get_setting("physics/3d/default_gravity"))
	var origin := Vector3(0.05, -0.05, -0.35)
	var vel := Vector3(0.0, 0.22, -1.0).normalized() * speed
	var imm := ImmediateMesh.new()
	imm.surface_begin(Mesh.PRIMITIVE_LINES)
	var prev := origin
	var steps := 18
	var dt := 0.055
	for i in range(steps):
		var t := float(i + 1) * dt
		var next := origin + vel * t + Vector3(0.0, -0.5 * gravity * t * t, 0.0)
		imm.surface_add_vertex(prev)
		imm.surface_add_vertex(next)
		prev = next
		if next.y < -2.5:
			break
	imm.surface_end()
	_throw_arc.mesh = imm
