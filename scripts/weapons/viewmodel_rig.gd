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
var _reload_p: float = 0.0
var _reload_kind: String = "mag"
var _reload_empty: bool = false
var _reload_committed: bool = false
var _reload_sfx: int = 0
var _mag_drop: Node3D = null
var _swap_t: float = 0.0
var _swap_dur: float = 0.26
var _holster_slot: Node3D = null
var _holster_pos: Vector3 = Vector3.ZERO
var _holster_rot: Vector3 = Vector3.ZERO
var _draw_sounded: bool = false
var _inspect_t: float = 0.0
var _inspect_dur: float = 1.65
var _takedown_t: float = 0.0
var _takedown_dur: float = 0.45
var _takedown_behind: bool = true
var _vault_p: float = 0.0
var _carrying: bool = false
var _dragging: bool = false
var _sway: Vector2 = Vector2.ZERO
var _sprint: float = 0.0
var _sprint_target: float = 0.0
var _aim_blend: float = 0.0
var _aim_target: float = 0.0
var _ads_speed: float = 4.0
var _left_local := Vector3.ZERO
var _left_override := false
var _breath_hold: float = 0.0
var _sight_local: Dictionary = {}  # WeaponId -> Vector3 sight point in ModelRoot space
var _throw_arc: MeshInstance3D = null
var _throw_arc_mat: StandardMaterial3D = null


func _ready() -> void:
	# Captures freeze the player with PROCESS_MODE_DISABLED. The arms still have
	# to solve, or the hands stay where they were on the first frame.
	process_mode = Node.PROCESS_MODE_ALWAYS
	var cam := get_parent() as Camera3D
	if cam != null and cam.near > 0.02:
		cam.near = 0.02
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
	# Hip pose sits in the lower-right third. Negative pitch points the muzzle down,
	# positive yaw brings it toward the centre without crossing the crosshair.
	# Yaw ~60° lays the barrel across the lower right so the length reads on screen.
	# Positive yaw swings the -Z muzzle toward screen centre. Receiver stays low-right.
	_base_pos = {
		GameState.WeaponId.PISTOL: Vector3(0.18, -0.16, -0.40),
		GameState.WeaponId.MACHINE_PISTOL: Vector3(0.18, -0.16, -0.40),
		GameState.WeaponId.RIFLE: Vector3(0.14, -0.20, -0.56),
		GameState.WeaponId.SMG: Vector3(0.16, -0.18, -0.50),
		GameState.WeaponId.SHOTGUN: Vector3(0.16, -0.22, -0.54),
		GameState.WeaponId.SNIPER: Vector3(0.14, -0.20, -0.58),
		GameState.WeaponId.LMG: Vector3(0.16, -0.22, -0.54),
		GameState.WeaponId.BOW: Vector3(0.18, -0.16, -0.50),
		GameState.WeaponId.CROSSBOW: Vector3(0.24, -0.18, -0.48),
		GameState.WeaponId.KNIFE: Vector3(0.20, -0.16, -0.40),
		GameState.WeaponId.FRAG: Vector3(0.18, -0.16, -0.40),
		GameState.WeaponId.MOLOTOV: Vector3(0.18, -0.16, -0.42),
		GameState.WeaponId.MACHETE: Vector3(0.22, -0.18, -0.44),
		GameState.WeaponId.BAT: Vector3(0.22, -0.18, -0.46),
	}
	_base_rot = {
		GameState.WeaponId.PISTOL: Vector3(6.0, 40.0, 4.0),
		GameState.WeaponId.MACHINE_PISTOL: Vector3(6.0, 40.0, 4.0),
		GameState.WeaponId.RIFLE: Vector3(4.0, 44.0, 0.0),
		GameState.WeaponId.SMG: Vector3(6.0, 46.0, 2.0),
		GameState.WeaponId.SHOTGUN: Vector3(4.0, 42.0, 0.0),
		GameState.WeaponId.SNIPER: Vector3(4.0, 40.0, 0.0),
		GameState.WeaponId.LMG: Vector3(5.0, 44.0, 0.0),
		GameState.WeaponId.BOW: Vector3(4.0, 28.0, 6.0),
		GameState.WeaponId.CROSSBOW: Vector3(4.0, 40.0, 2.0),
		GameState.WeaponId.KNIFE: Vector3(-8.0, 30.0, -8.0),
		GameState.WeaponId.FRAG: Vector3(-4.0, 24.0, 6.0),
		GameState.WeaponId.MOLOTOV: Vector3(-6.0, 22.0, 8.0),
		GameState.WeaponId.MACHETE: Vector3(-10.0, 36.0, -6.0),
		GameState.WeaponId.BAT: Vector3(-12.0, 28.0, -8.0),
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
	# queue_free leaves the old ModelRoot in the tree for the rest of the frame,
	# so the replacement gets renamed and later lookups miss it.
	var stale := slot.get_children()
	for c in stale:
		slot.remove_child(c)
		c.free()
	var skin_key := String(mods.get("skin", "default"))
	var pal: Dictionary = SKIN_PALETTES.get(skin_key, SKIN_PALETTES["default"])
	var body_col: Color = pal["body"]
	var accent_col: Color = pal["accent"]

	match id:
		GameState.WeaponId.PISTOL, GameState.WeaponId.MACHINE_PISTOL, GameState.WeaponId.TRANQ_PISTOL, \
		GameState.WeaponId.RIFLE, GameState.WeaponId.SMG, GameState.WeaponId.SHOTGUN, \
		GameState.WeaponId.SNIPER, GameState.WeaponId.SILENCED_SNIPER, \
		GameState.WeaponId.LMG, GameState.WeaponId.FLAMETHROWER, GameState.WeaponId.GRENADE_LAUNCHER:
			_build_cc0_firearm(slot, id, mods)
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
	_disable_viewmodel_shadows(slot)


func _disable_viewmodel_shadows(n: Node) -> void:
	if n is GeometryInstance3D:
		(n as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for c in n.get_children():
		_disable_viewmodel_shadows(c)


# ============================================================================
# CC0 FIREARMS (Quaternius Ultimate Gun Pack) + WRAD first-person arms
# ============================================================================
const CC0_DIR := "res://assets/weapons/cc0/"


func _cc0_file(id: GameState.WeaponId) -> String:
	match id:
		GameState.WeaponId.PISTOL, GameState.WeaponId.TRANQ_PISTOL:
			return "Pistol_1.fbx"
		GameState.WeaponId.MACHINE_PISTOL:
			return "Pistol_2.fbx"
		GameState.WeaponId.SMG:
			return "SubmachineGun_1.fbx"
		GameState.WeaponId.SHOTGUN:
			return "Shotgun_1.fbx"
		GameState.WeaponId.SNIPER, GameState.WeaponId.SILENCED_SNIPER:
			return "SniperRifle_1.fbx"
		GameState.WeaponId.LMG, GameState.WeaponId.FLAMETHROWER:
			return "AssaultRifle2_1.fbx"
		GameState.WeaponId.GRENADE_LAUNCHER:
			return "Bullpup_1.fbx"
		_:
			return "AssaultRifle_1.fbx"


func _cc0_fit(id: GameState.WeaponId) -> Dictionary:
	## Fractions of the imported bounds. Muzzle is +X, up is +Y, stock is -X.
	var pistol := {
		"length": 0.30, "grip_x": 0.16, "grip_y": 0.24,
		"sight_x": 0.42, "sight_y": 0.78, "muzzle_y": 0.62,
		"mag_x": 0.22, "support_x": 0.52, "support_y": 0.55,
		"two_hand": true, "compact": true,
	}
	var rifle := {
		"length": 0.68, "grip_x": 0.17, "grip_y": 0.62,
		"sight_x": 0.26, "sight_y": 0.78, "muzzle_y": 0.55,
		"mag_x": 0.38, "support_x": 0.60, "support_y": 0.70,
		"two_hand": true, "compact": false,
	}
	match id:
		GameState.WeaponId.PISTOL, GameState.WeaponId.TRANQ_PISTOL, GameState.WeaponId.MACHINE_PISTOL:
			return pistol
		GameState.WeaponId.SMG:
			return {
				"length": 0.52, "grip_x": 0.34, "grip_y": 0.66,
				"sight_x": 0.40, "sight_y": 0.76, "muzzle_y": 0.58,
				"mag_x": 0.50, "support_x": 0.68, "support_y": 0.74,
				"two_hand": true, "compact": true,
			}
		GameState.WeaponId.SHOTGUN:
			return {
				"length": 0.76, "grip_x": 0.38, "grip_y": 0.70,
				"sight_x": 0.46, "sight_y": 0.72, "muzzle_y": 0.55,
				"mag_x": 0.40, "support_x": 0.68, "support_y": 0.58,
				"two_hand": true, "compact": false,
			}
		GameState.WeaponId.SNIPER, GameState.WeaponId.SILENCED_SNIPER:
			return {
				"length": 0.80, "grip_x": 0.24, "grip_y": 0.58,
				"sight_x": 0.40, "sight_y": 0.70, "muzzle_y": 0.52,
				"mag_x": 0.36, "support_x": 0.55, "support_y": 0.66,
				"two_hand": true, "compact": false,
			}
		GameState.WeaponId.LMG, GameState.WeaponId.FLAMETHROWER:
			return {
				"length": 0.76, "grip_x": 0.32, "grip_y": 0.60,
				"sight_x": 0.42, "sight_y": 0.72, "muzzle_y": 0.52,
				"mag_x": 0.47, "support_x": 0.62, "support_y": 0.66,
				"two_hand": true, "compact": false,
			}
		GameState.WeaponId.GRENADE_LAUNCHER:
			return {
				"length": 0.74, "grip_x": 0.42, "grip_y": 0.36,
				"sight_x": 0.50, "sight_y": 0.74, "muzzle_y": 0.55,
				"mag_x": 0.48, "support_x": 0.72, "support_y": 0.58,
				"two_hand": true, "compact": false,
			}
		_:
			return rifle


func _build_cc0_firearm(slot: Node3D, id: GameState.WeaponId, mods: Dictionary) -> void:
	var packed := load(CC0_DIR + _cc0_file(id)) as PackedScene
	if packed == null:
		_build_long_gun(slot, id, Color(0.16, 0.17, 0.19), Color(0.22, 0.24, 0.21), mods, 0.27, 0.25, 0.22, false, false, false)
		return
	var root := Node3D.new()
	root.name = "ModelRoot"
	slot.add_child(root)
	var gun := packed.instantiate()
	gun.name = "CC0Gun"
	root.add_child(gun)
	var fit := _cc0_fit(id)
	if id != GameState.WeaponId.SHOTGUN:
		_strip_builtin_mag(gun, fit)
	var bounds := _local_aabb(gun)
	var length: float = fit["length"]
	var scale := length / maxf(bounds.size.x, 0.001)
	var basis := Basis(Vector3.UP, PI * 0.5).scaled(Vector3.ONE * scale)
	var grip := _aabb_point(bounds, fit["grip_x"], fit["grip_y"])
	var hold := Vector3(0.0, -0.02, 0.03)
	gun.transform = Transform3D(basis, hold - basis * grip)
	_finish_cc0_materials(gun)
	var sight_local: Vector3 = gun.transform * _aabb_point(bounds, fit["sight_x"], fit["sight_y"])
	var muzzle_local: Vector3 = gun.transform * _aabb_point(bounds, 1.0, fit["muzzle_y"])
	var mag_local: Vector3 = gun.transform * _aabb_point(bounds, fit["mag_x"], 0.28)
	# The handguard's underside sits near 70% of the mesh height. muzzle_y is the bore, which is empty air under the barrel.
	var support_y := float(fit.get("support_y", 0.70))
	var support: Vector3 = gun.transform * _aabb_point(bounds, fit["support_x"], support_y)
	var optic := String(mods.get("optic", "iron"))
	var compact: bool = fit["compact"]
	_sight_local[id] = _attach_optic(root, sight_local, optic, compact, optic != "iron")
	var muzzle_z: float = _attach_muzzle(root, muzzle_local, String(mods.get("muzzle", "none")), 0.014 if compact else 0.018, 0.16 if compact else 0.2)
	_attach_underbarrel(root, support + Vector3(0, -0.04, 0), String(mods.get("underbarrel", "none")), compact)
	var mag := Node3D.new()
	mag.name = "Magazine"
	mag.position = mag_local
	mag.set_meta("rest_pos", mag_local)
	var feed := "shell" if id == GameState.WeaponId.SHOTGUN else "mag"
	mag.set_meta("feed", feed)
	root.add_child(mag)
	if feed == "shell":
		# A shotshell the support hand carries to the port. Hidden until a reload.
		var shell_r := clampf(length * 0.016, 0.012, 0.022)
		var shell_l := clampf(length * 0.065, 0.05, 0.09)
		ProcMesh.add_part(mag, ProcMesh.cylinder_mesh(shell_r, shell_l, Color(0.72, 0.32, 0.16), 0.55, 0.08, 8), Vector3.ZERO, Vector3(0, 0, 90))
		ProcMesh.add_part(mag, ProcMesh.cylinder_mesh(shell_r * 1.05, shell_l * 0.22, Color(0.82, 0.72, 0.28), 0.4, 0.2, 8), Vector3(0, 0, -shell_l * 0.28), Vector3(0, 0, 90))
		mag.visible = false
	else:
		var mag_h := length * (0.26 if String(mods.get("mag", "standard")) == "extended" else 0.20)
		var mag_w := length * 0.040
		var mag_d := length * 0.055
		ProcMesh.add_part(mag, ProcMesh.box_mesh(Vector3(mag_w, mag_h, mag_d), Color(0.38, 0.36, 0.32), 0.55, 0.04), Vector3(0, -mag_h * 0.42, 0))
		mag.visible = true
	_magazines[id] = mag
	var charge := hold + Vector3(0.0, length * 0.07, length * 0.05)
	if compact:
		charge = hold + Vector3(0.0, length * 0.06, length * 0.04)
	if id == GameState.WeaponId.SHOTGUN:
		charge = mag_local + Vector3(0.02, 0.03, 0.02)
	_mount_arms(root, hold, support, _arm_style(id), mag_local, charge)
	var flash := _make_muzzle_flash(0.05 if String(mods.get("muzzle", "none")) == "suppressor" else 0.08, Color(1.0, 0.85, 0.45, 0.88))
	flash.position = Vector3(muzzle_local.x, muzzle_local.y, muzzle_z - 0.02)
	root.add_child(flash)
	_muzzle_flashes[id] = flash


func _strip_builtin_mag(gun: Node3D, fit: Dictionary) -> void:
	## The Quaternius mesh bakes its magazine into the same surfaces as the receiver.
	## Drop triangles in the mag well so the separate Magazine node is the only one.
	var mag_along := float(fit["mag_x"])
	for mi in gun.find_children("*", "MeshInstance3D", true, false):
		var src := (mi as MeshInstance3D).mesh
		if src == null or src.has_meta("mag_stripped"):
			continue
		# The imported node rotates the mesh, so test the hanging mag in node space.
		# The grip is the narrow drop just behind the mag; only the mag's X slice is removed.
		var xform := (mi as MeshInstance3D).transform
		var local_box: AABB = xform * (mi as MeshInstance3D).get_aabb()
		var mag_x := local_box.position.x + local_box.size.x * mag_along
		var half := local_box.size.x * 0.028
		var y_cut := local_box.position.y + local_box.size.y * 0.48
		var built := ArrayMesh.new()
		var changed := false
		for s in src.get_surface_count():
			var arrays: Array = src.surface_get_arrays(s)
			var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			if indices.is_empty():
				indices = PackedInt32Array()
				for i in verts.size():
					indices.append(i)
			var keep := PackedInt32Array()
			var t := 0
			while t + 2 < indices.size():
				var c: Vector3 = xform * ((verts[indices[t]] + verts[indices[t + 1]] + verts[indices[t + 2]]) / 3.0)
				var in_mag := absf(c.x - mag_x) < half and c.y < y_cut
				if in_mag:
					changed = true
				else:
					keep.append(indices[t])
					keep.append(indices[t + 1])
					keep.append(indices[t + 2])
				t += 3
			arrays[Mesh.ARRAY_INDEX] = keep
			built.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
			var mat := (mi as MeshInstance3D).get_active_material(s)
			if mat:
				built.surface_set_material(built.get_surface_count() - 1, mat)
		if changed:
			built.set_meta("mag_stripped", true)
			(mi as MeshInstance3D).mesh = built


func _aabb_point(bounds: AABB, along_x: float, up_y: float) -> Vector3:
	return bounds.position + Vector3(bounds.size.x * along_x, bounds.size.y * up_y, bounds.size.z * 0.5)


func _local_aabb(node: Node3D) -> AABB:
	var box := AABB()
	var first := true
	var inv := node.global_transform.affine_inverse()
	for n in node.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if mi.mesh == null:
			continue
		var local: AABB = inv * (mi.global_transform * mi.get_aabb())
		if first:
			box = local
			first = false
		else:
			box = box.merge(local)
	return box


func _finish_cc0_materials(node: Node) -> void:
	## Compatibility has no real reflections, so a dark metallic albedo reads as flat grey.
	for n in node.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if mi.mesh == null:
			continue
		for i in mi.mesh.get_surface_count():
			var src := mi.get_active_material(i)
			var sm := StandardMaterial3D.new()
			var label := ""
			var albedo := Color(0.55, 0.56, 0.58)
			if src is StandardMaterial3D:
				var old := src as StandardMaterial3D
				label = old.resource_name.to_lower()
				albedo = old.albedo_color
				sm.albedo_texture = old.albedo_texture
			var wood := label.find("wood") >= 0
			var polymer := label.find("polymer") >= 0 or label.find("plastic") >= 0 or label.find("rubber") >= 0
			if wood:
				if albedo.get_luminance() < 0.35:
					albedo = albedo.lerp(Color(0.62, 0.38, 0.18), 0.65)
				if sm.albedo_texture == null:
					sm.albedo_texture = _surface_tex("wood")
				sm.metallic = 0.0
				sm.roughness = 0.62
			elif polymer:
				if albedo.get_luminance() < 0.22:
					albedo = albedo.lerp(Color(0.30, 0.31, 0.32), 0.6)
				if sm.albedo_texture == null:
					sm.albedo_texture = _surface_tex("polymer")
				sm.metallic = 0.04
				sm.roughness = 0.55
			else:
				if albedo.get_luminance() < 0.42:
					albedo = albedo.lerp(Color(0.62, 0.64, 0.66), 0.62)
				if sm.albedo_texture == null:
					sm.albedo_texture = _surface_tex("metal")
				sm.metallic = 0.2
				sm.roughness = 0.42
			sm.albedo_color = albedo
			sm.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
			mi.set_surface_override_material(i, sm)


func _arm_style(id: GameState.WeaponId) -> String:
	match id:
		GameState.WeaponId.PISTOL, GameState.WeaponId.MACHINE_PISTOL, GameState.WeaponId.TRANQ_PISTOL:
			return "pistol"
		GameState.WeaponId.BOW, GameState.WeaponId.HUNTER_BOW:
			return "bow"
		GameState.WeaponId.KNIFE, GameState.WeaponId.MACHETE:
			return "melee"
		GameState.WeaponId.BAT:
			return "bat"
		GameState.WeaponId.FRAG, GameState.WeaponId.MOLOTOV, GameState.WeaponId.C4, GameState.WeaponId.PROX_MINE, GameState.WeaponId.THROWING_AXE:
			return "throw"
		_:
			return "rifle"


func _mount_arms(root: Node3D, grip: Vector3, support: Vector3, style: String, mag_pos: Vector3, charge: Vector3) -> void:
	var skel := FpArms.attach(root)
	root.set_meta("fp_skel", skel)
	root.set_meta("fp_grip", grip)
	root.set_meta("fp_support", support)
	root.set_meta("fp_mag", mag_pos)
	root.set_meta("fp_charge", charge)
	root.set_meta("fp_style", style)


func _build_pistol(slot: Node3D, wid: GameState.WeaponId, body_col: Color, accent_col: Color, mods: Dictionary, is_auto: bool) -> void:
	var polymer := Color(0.10, 0.10, 0.11)
	var root := Node3D.new()
	root.name = "ModelRoot"
	slot.add_child(root)

	var slide := Node3D.new()
	slide.name = "Slide"
	root.add_child(slide)
	var slide_len := 0.24 if is_auto else 0.205
	var steel := body_col.lightened(0.08)
	ProcMesh.add_part(slide, _gun_box(Vector3(0.04, 0.028, slide_len), steel, 0.32, 0.86), Vector3(0, 0.038, -0.02))
	ProcMesh.add_part(slide, _gun_box(Vector3(0.034, 0.012, slide_len * 0.72), steel.darkened(0.15), 0.4, 0.7), Vector3(0, 0.026, -0.01))
	ProcMesh.add_part(slide, _gun_cyl(0.008, 0.04, steel.darkened(0.25), 0.28, 0.9, 8), Vector3(0, 0.034, -slide_len * 0.48), Vector3(90, 0, 0))
	# No slide-mounted irons — _attach_optic owns the single iron/optic set so ADS centers correctly
	if not is_auto:
		_pistol_slide = slide

	ProcMesh.add_part(root, _gun_box(Vector3(0.036, 0.028, slide_len - 0.01), accent_col, 0.55, 0.45), Vector3(0, 0.0, -0.015))
	ProcMesh.add_part(root, _gun_box(Vector3(0.034, 0.105, 0.052), polymer, 0.82, 0.04, "polymer"), Vector3(0, -0.062, 0.048), Vector3(-14, 0, 0))

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

	_mount_arms(root, Vector3(0.006, -0.05, 0.05), Vector3(0.01, -0.01, -0.06), "pistol", Vector3(0, -0.1, 0.05), Vector3(0, 0.04, 0.02))

	var flash := _make_muzzle_flash(0.055 if String(mods.get("muzzle", "none")) == "suppressor" else 0.085, Color(1.0, 0.85, 0.45, 0.88))
	flash.position = Vector3(0, 0.028, muzzle_z - 0.03)
	root.add_child(flash)
	_muzzle_flashes[wid] = flash


var _surface_cache: Dictionary = {}


func _surface_tex(kind: String) -> Texture2D:
	if _surface_cache.has(kind):
		return _surface_cache[kind]
	var tex := load("res://assets/textures/weapons/%s.png" % kind) as Texture2D
	_surface_cache[kind] = tex
	return tex


func _surface_material(color: Color, roughness: float, metallic: float, kind: String) -> Material:
	if GraphicsQuality:
		return GraphicsQuality.make_gun_material(color, metallic, roughness, _surface_tex(kind))
	return ProcMesh.gun_mat(color, roughness, metallic)


func _gun_box(size: Vector3, color: Color, roughness: float = 0.5, metallic: float = 0.45, surface: String = "metal") -> MeshInstance3D:
	var mi := ProcMesh.box_mesh(size, color, roughness, metallic)
	mi.material_override = _surface_material(color, roughness, metallic, surface)
	return mi


func _gun_cyl(radius: float, height: float, color: Color, roughness: float = 0.4, metallic: float = 0.65, segments: int = 10, surface: String = "metal") -> MeshInstance3D:
	var mi := ProcMesh.cylinder_mesh(radius, height, color, roughness, metallic, segments)
	mi.material_override = _surface_material(color, roughness, metallic, surface)
	return mi


func _build_long_gun(slot: Node3D, id: GameState.WeaponId, body_col: Color, accent_col: Color, mods: Dictionary, rec_len: float, hg_len: float, brl_len: float, is_smg: bool, is_sniper: bool, is_lmg: bool) -> void:
	var polymer := Color(0.09, 0.09, 0.1)
	var root := Node3D.new()
	root.name = "ModelRoot"
	slot.add_child(root)

	# Receiver (wider/boxier for LMG, sleeker for SMG/Sniper) — rim materials on High
	var rw := 0.078 if is_lmg else (0.044 if is_smg else 0.054)
	var rh := 0.084 if is_lmg else (0.058 if is_smg else 0.068)
	var steel := body_col.lightened(0.05)
	ProcMesh.add_part(root, _gun_box(Vector3(rw, rh * 0.62, rec_len), steel, 0.34, 0.82), Vector3(0, 0.028, 0.0))
	ProcMesh.add_part(root, _gun_box(Vector3(rw * 0.92, rh * 0.48, rec_len * 0.72), polymer, 0.72, 0.06, "polymer"), Vector3(0, -0.012, 0.03))
	ProcMesh.add_part(root, _gun_box(Vector3(0.030, 0.012, rec_len), polymer, 0.4, 0.5, "polymer"), Vector3(0, 0.015 + rh * 0.5 + 0.005, -0.01))
	# Detail: top rail segments + charging handle + ejection port for clearer silhouette
	ProcMesh.add_part(root, _gun_box(Vector3(0.022, 0.006, rec_len * 0.72), Color(0.14, 0.15, 0.16), 0.35, 0.7), Vector3(0, 0.015 + rh * 0.5 + 0.012, -0.02))
	ProcMesh.add_part(root, _gun_box(Vector3(0.012, 0.018, 0.028), Color(0.28, 0.29, 0.30), 0.4, 0.6), Vector3(rw * 0.42, 0.028, -0.02))
	ProcMesh.add_part(root, _gun_box(Vector3(0.006, 0.022, 0.04), Color(0.08, 0.08, 0.09), 0.55, 0.3), Vector3(rw * 0.48, 0.02, 0.02))

	# Handguard & Barrel — cylinder shroud plus a lower rail so it isn't one brick
	var hg_z := -(rec_len * 0.5 + hg_len * 0.5)
	ProcMesh.add_part(root, _gun_cyl(rw * 0.46, hg_len, accent_col, 0.62, 0.28, 8, "polymer"), Vector3(0, 0.02, hg_z), Vector3(90, 0, 0))
	ProcMesh.add_part(root, _gun_box(Vector3(rw * 0.72, rh * 0.28, hg_len * 0.92), accent_col.darkened(0.08), 0.7, 0.18, "polymer"), Vector3(0, -0.006, hg_z))
	# Handguard vent slots (side detail)
	ProcMesh.add_part(root, _gun_box(Vector3(0.004, rh * 0.35, hg_len * 0.55), polymer.darkened(0.2), 0.5, 0.4), Vector3(-rw * 0.48, 0.02, hg_z))
	ProcMesh.add_part(root, _gun_box(Vector3(0.004, rh * 0.35, hg_len * 0.55), polymer.darkened(0.2), 0.5, 0.4), Vector3(rw * 0.48, 0.02, hg_z))
	if not is_smg:
		for rib in 5:
			var rz := hg_z - hg_len * 0.35 + float(rib) * hg_len * 0.16
			ProcMesh.add_part(root, _gun_box(Vector3(rw * 0.98, 0.006, 0.008), polymer.lightened(0.08), 0.45, 0.35), Vector3(0, 0.02 + rh * 0.22, rz))
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

	# Tapered stock, buttplate, and a swept grip. The old stock was one box.
	ProcMesh.add_part(root, _gun_box(Vector3(0.034, 0.048, 0.16), accent_col, 0.7, 0.16, "polymer"), Vector3(0, 0.02, rec_len * 0.5 + 0.06), Vector3(-8, 0, 0))
	ProcMesh.add_part(root, _gun_box(Vector3(0.03, 0.07, 0.11), accent_col.darkened(0.06), 0.72, 0.14, "polymer"), Vector3(0, -0.02, rec_len * 0.5 + 0.14), Vector3(-16, 0, 0))
	ProcMesh.add_part(root, _gun_box(Vector3(0.038, 0.09, 0.022), polymer, 0.45, 0.35, "polymer"), Vector3(0, -0.012, rec_len * 0.5 + 0.2))
	ProcMesh.add_part(root, _gun_box(Vector3(0.028, 0.09, 0.04), polymer, 0.8, 0.1, "polymer"), Vector3(0, -0.05, 0.07), Vector3(-22, 0, 0))
	ProcMesh.add_part(root, _gun_box(Vector3(0.008, 0.03, 0.01), polymer, 0.4, 0.55), Vector3(0, 0.046, brl_z - brl_len * 0.28))

	# Modular Gunsmith Attachments!
	var muzzle_tip := brl_z - brl_len * 0.5
	muzzle_tip = _attach_muzzle(root, Vector3(0, 0.022, muzzle_tip), String(mods.get("muzzle", "none")), brl_r + 0.008, 0.22 if is_sniper else 0.17)
	var default_optic := "scope" if is_sniper else "iron"
	var chosen_optic := String(mods.get("optic", default_optic))
	if is_sniper and chosen_optic == "iron":
		chosen_optic = "scope"
	_sight_local[id] = _attach_optic(root, Vector3(0, 0.015 + rh * 0.5 + 0.014, 0.01), chosen_optic, false)
	_attach_underbarrel(root, Vector3(0, -0.025, hg_z), String(mods.get("underbarrel", "none")), false)

	_mount_arms(root, Vector3(0.004, -0.04, 0.08), Vector3(0.0, 0.0, hg_z), "rifle", Vector3(0, -0.06, 0.04), Vector3(0.0, 0.05, 0.12))

	var flash_sz := 0.06 if String(mods.get("muzzle", "none")) == "suppressor" else (0.14 if is_lmg or is_sniper else 0.11)
	var flash := _make_muzzle_flash(flash_sz, Color(1.0, 0.78, 0.22, 0.95))
	flash.position = Vector3(0, 0.022, muzzle_tip - 0.03)
	root.add_child(flash)
	_muzzle_flashes[id] = flash


func _build_shotgun(slot: Node3D, body_col: Color, accent_col: Color, mods: Dictionary) -> void:
	var wood := Color(0.38, 0.22, 0.11) if accent_col == SKIN_PALETTES["default"]["accent"] else accent_col
	var root := Node3D.new()
	root.name = "ModelRoot"
	slot.add_child(root)

	# Heavy shotgun receiver + top barrel + lower tubular magazine
	ProcMesh.add_part(root, _gun_box(Vector3(0.056, 0.072, 0.24), body_col, 0.42, 0.58, "metal"), Vector3(0, 0.015, 0.02))
	ProcMesh.add_part(root, _gun_cyl(0.016, 0.44, body_col.darkened(0.12), 0.35, 0.72, 10, "metal"), Vector3(0, 0.034, -0.30), Vector3(90, 0, 0))
	var tube_len := 0.44 if String(mods.get("mag", "standard")) == "extended" else 0.34
	ProcMesh.add_part(root, _gun_cyl(0.014, tube_len, body_col.darkened(0.22), 0.4, 0.65, 10, "metal"), Vector3(0, 0.002, -0.10 - tube_len * 0.5), Vector3(90, 0, 0))
	# Ribbed pump forend
	ProcMesh.add_part(root, _gun_box(Vector3(0.056, 0.056, 0.18), wood, 0.78, 0.08, "wood"), Vector3(0, -0.002, -0.25))
	# Stock
	ProcMesh.add_part(root, _gun_box(Vector3(0.048, 0.090, 0.26), wood, 0.78, 0.08, "wood"), Vector3(0, -0.022, 0.22), Vector3(-8, 0, 0))

	var tip := _attach_muzzle(root, Vector3(0, 0.034, -0.52), String(mods.get("muzzle", "none")), 0.022, 0.18)
	_sight_local[GameState.WeaponId.SHOTGUN] = _attach_optic(root, Vector3(0, 0.056, 0.02), String(mods.get("optic", "iron")), false)
	_attach_underbarrel(root, Vector3(0, -0.038, -0.26), String(mods.get("underbarrel", "none")), false)

	_mount_arms(root, Vector3(0.006, -0.03, 0.12), Vector3(0.0, 0.0, -0.25), "rifle", Vector3(0, -0.04, 0.02), Vector3(0.02, 0.0, 0.0))

	var flash := _make_muzzle_flash(0.15, Color(1.0, 0.72, 0.18, 0.95))
	flash.position = Vector3(0, 0.034, tip - 0.04)
	root.add_child(flash)
	_muzzle_flashes[GameState.WeaponId.SHOTGUN] = flash


func _build_bow(slot: Node3D, wid: GameState.WeaponId, body_col: Color, accent_col: Color, mods: Dictionary) -> void:
	var wood := Color(0.42, 0.26, 0.14) if body_col == SKIN_PALETTES["default"]["body"] else body_col
	var carbon := accent_col
	var string_col := Color(0.84, 0.82, 0.76)
	var shaft_col := Color(0.55, 0.38, 0.20)
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

	_mount_arms(root, Vector3(0.01, -0.03, 0.02), Vector3(-0.01, 0.03, 0.14), "bow", Vector3.ZERO, Vector3(-0.02, 0.04, 0.12))


func _build_crossbow(slot: Node3D, body_col: Color, accent_col: Color, mods: Dictionary) -> void:
	var polymer := Color(0.11, 0.12, 0.13)
	var string_col := Color(0.84, 0.82, 0.76)
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
	_mount_arms(root, Vector3(0.0, -0.05, 0.08), Vector3(0.0, 0.02, -0.12), "rifle", Vector3(0, -0.02, 0.02), Vector3(0.0, 0.04, 0.02))


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
	var root := Node3D.new()
	root.name = "ModelRoot"
	slot.add_child(root)
	ProcMesh.add_part(root, ProcMesh.box_mesh(Vector3(0.007, 0.036, 0.165), steel, 0.25, 0.82), Vector3(0, 0.012, -0.105))
	ProcMesh.add_part(root, ProcMesh.box_mesh(Vector3(0.009, 0.012, 0.160), dark_steel, 0.42, 0.65), Vector3(0, 0.026, -0.102))
	ProcMesh.add_part(root, ProcMesh.cone_mesh(0.019, 0.001, 0.065, steel, 0.24, 0.85, 4), Vector3(0, 0.012, -0.218), Vector3(-90, 0, 45))
	ProcMesh.add_part(root, ProcMesh.box_mesh(Vector3(0.018, 0.068, 0.016), brass, 0.38, 0.72), Vector3(0, 0.010, -0.018))
	ProcMesh.add_part(root, ProcMesh.box_mesh(Vector3(0.022, 0.030, 0.115), handle, 0.88, 0.05), Vector3(0, 0.006, 0.046))
	_mount_arms(root, Vector3(0.0, 0.0, 0.05), Vector3(0.0, 0.0, -0.02), "melee", Vector3.ZERO, Vector3.ZERO)


func _build_frag(slot: Node3D) -> void:
	var root := Node3D.new()
	root.name = "ModelRoot"
	slot.add_child(root)
	ProcMesh.add_part(root, ProcMesh.sphere_mesh(0.058, Color(0.24, 0.31, 0.20), 0.72, 0.2), Vector3(0, 0.01, -0.03))
	ProcMesh.add_part(root, ProcMesh.cylinder_mesh(0.059, 0.016, Color(0.88, 0.76, 0.18), 0.5, 0.1, 10), Vector3(0, 0.022, -0.03))
	ProcMesh.add_part(root, ProcMesh.box_mesh(Vector3(0.028, 0.036, 0.028), Color(0.45, 0.46, 0.44), 0.4, 0.6), Vector3(0, 0.072, -0.03))
	ProcMesh.add_part(root, ProcMesh.cylinder_mesh(0.018, 0.006, Color(0.76, 0.78, 0.80), 0.3, 0.8, 10), Vector3(-0.024, 0.075, -0.03), Vector3(90, 0, 0))
	_mount_arms(root, Vector3(0.0, -0.01, 0.0), Vector3.ZERO, "throw", Vector3.ZERO, Vector3.ZERO)


func _build_molotov(slot: Node3D) -> void:
	var root := Node3D.new()
	root.name = "ModelRoot"
	slot.add_child(root)
	ProcMesh.add_part(root, ProcMesh.cylinder_mesh(0.042, 0.16, Color(0.76, 0.42, 0.12), 0.22, 0.18, 10), Vector3(0, 0.0, -0.04))
	ProcMesh.add_part(root, ProcMesh.cylinder_mesh(0.016, 0.08, Color(0.68, 0.42, 0.16), 0.22, 0.18, 8), Vector3(0, 0.11, -0.04))
	ProcMesh.add_part(root, ProcMesh.box_mesh(Vector3(0.028, 0.065, 0.022), Color(0.86, 0.82, 0.74)), Vector3(0.006, 0.165, -0.04), Vector3(0, 0, -18))
	var flame := ProcMesh.cone_mesh(0.028, 0.004, 0.075, Color(1.0, 0.56, 0.10), 0.6, 0.0, 6)
	flame.material_override = ProcMesh.emissive(Color(1.0, 0.52, 0.08), 2.8)
	ProcMesh.add_part(root, flame, Vector3(0.015, 0.215, -0.04))
	_mount_arms(root, Vector3(0.0, -0.01, -0.02), Vector3.ZERO, "throw", Vector3.ZERO, Vector3.ZERO)


func _build_machete(slot: Node3D, body_col: Color) -> void:
	var steel := Color(0.64, 0.67, 0.70) if body_col == SKIN_PALETTES["default"]["body"] else body_col.lightened(0.22)
	var edge := Color(0.86, 0.89, 0.92)
	var handle := Color(0.24, 0.15, 0.09)
	var root := Node3D.new()
	root.name = "ModelRoot"
	slot.add_child(root)
	# Wide curved kukri machete blade
	ProcMesh.add_part(root, ProcMesh.box_mesh(Vector3(0.008, 0.056, 0.28), steel, 0.3, 0.78), Vector3(0, 0.025, -0.17))
	ProcMesh.add_part(root, ProcMesh.box_mesh(Vector3(0.006, 0.068, 0.14), edge, 0.2, 0.88), Vector3(0, 0.018, -0.35), Vector3(-12, 0, 0))
	ProcMesh.add_part(root, ProcMesh.box_mesh(Vector3(0.026, 0.036, 0.14), handle, 0.86, 0.05), Vector3(0, 0.004, 0.04))
	_mount_arms(root, Vector3(0.0, 0.0, 0.04), Vector3(0.0, 0.02, -0.12), "melee", Vector3.ZERO, Vector3.ZERO)


func _build_bat(slot: Node3D, body_col: Color, accent_col: Color) -> void:
	var barrel_col := Color(0.74, 0.77, 0.80) if body_col == SKIN_PALETTES["default"]["body"] else body_col.lightened(0.18)
	var grip := Color(0.14, 0.14, 0.15)
	var root := Node3D.new()
	root.name = "ModelRoot"
	slot.add_child(root)
	# Tapered aluminum bat: handle + flared barrel + painted stripe + knob
	ProcMesh.add_part(root, ProcMesh.cylinder_mesh(0.017, 0.20, grip, 0.88, 0.05, 8), Vector3(0, 0.0, 0.02), Vector3(90, 0, 0))
	ProcMesh.add_part(root, ProcMesh.cone_mesh(0.036, 0.017, 0.42, barrel_col, 0.24, 0.82, 10), Vector3(0, 0.0, -0.28), Vector3(90, 0, 0))
	ProcMesh.add_part(root, ProcMesh.cylinder_mesh(0.037, 0.075, accent_col, 0.45, 0.35, 10), Vector3(0, 0.0, -0.36), Vector3(90, 0, 0))
	ProcMesh.add_part(root, ProcMesh.cylinder_mesh(0.024, 0.018, grip, 0.8, 0.1, 8), Vector3(0, 0.0, 0.125), Vector3(90, 0, 0))
	_mount_arms(root, Vector3(0.0, 0.0, 0.02), Vector3(0.0, 0.0, -0.16), "bat", Vector3.ZERO, Vector3.ZERO)


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


func _attach_optic(root: Node3D, pos: Vector3, optic: String, compact: bool, build_iron: bool = true) -> Vector3:
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
			if not build_iron:
				# The firearm mesh already has irons. Only the SightPoint is needed.
				sight = pos
			else:
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
	var previous: Node3D = _slots.get(_active_id)
	var changing := animate_swap and previous != null and _active_id != id and previous.visible
	_active_id = id
	_reload_t = 0.0
	_reload_p = 0.0
	_fire_t = 0.0
	_inspect_t = 0.0
	_left_override = false
	_seat_mag()
	var slot: Node3D = _slots.get(id)
	if changing and is_instance_valid(slot):
		_holster_slot = previous
		_holster_pos = previous.position
		_holster_rot = previous.rotation_degrees
		_swap_dur = 0.48
		_swap_t = _swap_dur
		_draw_sounded = false
		slot.visible = false
		Foley.play(self, "holster")
		return
	_holster_slot = null
	hide_all()
	if is_instance_valid(slot):
		slot.visible = true
		slot.position = _base_pos.get(id, Vector3(0.22, -0.18, -0.4))
		slot.rotation_degrees = _base_rot.get(id, Vector3.ZERO)
	if animate_swap:
		_swap_dur = 0.28
		_swap_t = _swap_dur
		_draw_sounded = true
		Foley.play(self, "draw")


func set_sprinting(on: bool) -> void:
	_sprint_target = 1.0 if on else 0.0


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


func play_reload(duration: float = 1.4, kind: String = "mag", empty: bool = false) -> void:
	_reload_dur = maxf(0.28, duration)
	_reload_t = _reload_dur
	_reload_p = 0.0
	_reload_kind = kind
	_reload_empty = empty
	_reload_committed = false
	_reload_sfx = 0
	_inspect_t = 0.0
	_clear_mag_drop()


func scrub_reload(p: float, kind: String = "mag", empty: bool = false) -> void:
	## Hold one reload frame. A long duration keeps _process from walking off it.
	_reload_kind = kind
	_reload_empty = empty
	_reload_committed = false
	_reload_sfx = 0
	_reload_dur = 100.0
	_reload_p = clampf(p, 0.0, 1.0)
	_reload_t = (1.0 - _reload_p) * _reload_dur
	var sample: Dictionary = FpReload.sample(_reload_kind, _reload_p, _reload_empty)
	_drive_reload(str(sample["stage"]), float(sample["u"]))
	_solve_view_arms(_aim_blend)


func cancel_reload() -> void:
	_reload_t = 0.0
	_reload_p = 0.0
	_seat_mag()
	_rest_left_hand()
	_clear_mag_drop()


func consume_reload_commit() -> bool:
	## True once, at the frame the mag, shell, or arrow actually seats.
	if _reload_committed:
		return false
	if _reload_p + 0.0001 < FpReload.commit_at(_reload_kind, _reload_empty):
		return false
	_reload_committed = true
	return true


func force_reload_commit() -> bool:
	## The cycle ended before the seat frame was observed. Still commit once.
	if _reload_committed:
		return false
	_reload_committed = true
	return true


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


func snap_presentation(aiming: bool) -> void:
	## Put the gun and the arms on the hip or ADS pose in one step. Captures
	## freeze the player, which also freezes this node's _process.
	_aim_target = 1.0 if aiming else 0.0
	_aim_blend = _aim_target
	var slot: Node3D = _slots.get(_active_id)
	if not is_instance_valid(slot):
		_solve_view_arms(_aim_blend)
		return
	var base_p: Vector3 = _base_pos.get(_active_id, Vector3(0.22, -0.18, -0.4))
	var base_r: Vector3 = _base_rot.get(_active_id, Vector3.ZERO)
	var pos := base_p
	var rot := base_r
	if aiming:
		var ads_pose := _ads_pose_for(_active_id, base_p, base_r)
		pos = ads_pose["pos"]
		rot = ads_pose["rot"]
	slot.position = pos
	slot.rotation_degrees = rot
	_solve_view_arms(_aim_blend)


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
	if not is_instance_valid(slot):
		_update_throw_arc(false)
		return
	if not slot.visible:
		if is_instance_valid(_holster_slot) and _swap_t > 0.0:
			_swap_t = maxf(0.0, _swap_t - delta)
			var holster_span := _swap_dur * 0.46
			if _swap_t > _swap_dur - holster_span:
				var k := 1.0 - ((_swap_t - (_swap_dur - holster_span)) / maxf(0.001, holster_span))
				k = clampf(k, 0.0, 1.0)
				_holster_slot.visible = true
				_holster_slot.position = _holster_pos + Vector3(0.05, -0.36, 0.05) * k
				_holster_slot.rotation_degrees = _holster_rot + Vector3(46.0, 8.0, 16.0) * k
				_update_throw_arc(false)
				return
			_holster_slot.visible = false
			_holster_slot = null
			slot.visible = true
			if not _draw_sounded:
				_draw_sounded = true
				var rest_p: Vector3 = _base_pos.get(_active_id, Vector3(0.22, -0.18, -0.45))
				var rest_r: Vector3 = _base_rot.get(_active_id, Vector3.ZERO)
				slot.position = rest_p + Vector3(0.04, -0.34, 0.05)
				slot.rotation_degrees = rest_r + Vector3(34.0, 6.0, 0.0)
				Foley.play(self, "draw")
		else:
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

	if _swap_t > 0.0 and _holster_slot == null:
		_swap_t = maxf(0.0, _swap_t - delta)
		var draw_u := 1.0 - (_swap_t / maxf(0.05, _swap_dur * 0.54))
		draw_u = clampf(draw_u, 0.0, 1.0)
		var rise := 1.0 - draw_u
		offset_p.y -= 0.34 * rise
		offset_p.z += 0.04 * rise
		offset_r.x -= 34.0 * rise

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

	_sprint = move_toward(_sprint, _sprint_target, delta * 5.0)
	if _sprint > 0.001 and ads < 0.25 and not _carrying:
		# Gun drops across the body the way a sprinting rifle sits in FC5.
		offset_p.y -= 0.2 * _sprint
		offset_p.x += 0.06 * _sprint
		offset_p.z += 0.05 * _sprint
		offset_r.x += 36.0 * _sprint
		offset_r.z += 22.0 * _sprint
		offset_p.y += sin(_idle_time * 13.0) * 0.014 * _sprint

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
		_reload_p = 1.0 - (_reload_t / maxf(0.01, _reload_dur))
		var sample: Dictionary = FpReload.sample(_reload_kind, _reload_p, _reload_empty)
		offset_p += sample["pos"]
		offset_r += sample["rot"]
		_drive_reload(str(sample["stage"]), float(sample["u"]))
		_tick_mag_drop(delta)
	else:
		if _reload_p > 0.0:
			_reload_p = 0.0
			_seat_mag()
			_rest_left_hand()
		_tick_mag_drop(delta)

	var target_p := base_p + offset_p
	var target_r := base_r + offset_r
	# Snap harder while raising into ADS so the sight settles cleanly
	var smooth := clampf(delta * lerpf(18.0, 28.0, ads), 0.0, 1.0)
	slot.position = slot.position.lerp(target_p, smooth)
	slot.rotation_degrees = slot.rotation_degrees.lerp(target_r, smooth)

	var show_arc := ads > 0.35 and _active_id in [GameState.WeaponId.FRAG, GameState.WeaponId.MOLOTOV, GameState.WeaponId.KNIFE]
	_update_throw_arc(show_arc)
	_solve_view_arms(ads)


func _active_root() -> Node3D:
	var slot: Node3D = _slots.get(_active_id)
	if slot == null:
		return null
	return slot.get_node_or_null("ModelRoot") as Node3D


func _drive_reload(stage: String, u: float) -> void:
	var root := _active_root()
	if root == null:
		return
	var support: Vector3 = root.get_meta("fp_support", Vector3.ZERO)
	var well: Vector3 = root.get_meta("fp_mag", support)
	var charge: Vector3 = root.get_meta("fp_charge", well + Vector3(0, 0.05, 0.12))
	var low: Vector3 = well + Vector3(0.05, -0.18, 0.08)
	var mag: Node3D = _magazines.get(_active_id)
	if _reload_kind == "arrow":
		_drive_arrow(stage, u, support)
		return
	var feed := str(mag.get_meta("feed", "mag")) if is_instance_valid(mag) else "mag"
	if feed == "shell" or _reload_kind == "shell":
		var port: Vector3 = well + Vector3(0.035, 0.02, 0.0)
		var pouch: Vector3 = port + Vector3(0.09, -0.14, 0.07)
		var hand := support
		var mag_at := port
		var show := false
		if stage == "to_port":
			hand = support.lerp(port, u)
			mag_at = pouch.lerp(port, u)
			show = true
		elif stage == "insert":
			hand = port.lerp(port + Vector3(-0.01, 0.015, -0.01), u)
			mag_at = port.lerp(port + Vector3(-0.012, 0.012, 0.0), u)
			show = u < 0.82
			if u > 0.35 and _reload_sfx < 1:
				_reload_sfx = 1
				Foley.play(self, "shell")
		else:
			hand = port.lerp(support, u)
			mag_at = well
			show = false
		_left_local = hand
		_left_override = true
		if is_instance_valid(mag):
			mag.visible = show
			mag.position = mag_at
		return
	var hand := support
	var mag_at := well
	var show := true
	if stage == "to_well":
		hand = support.lerp(well, u)
		mag_at = well
	elif stage == "to_low":
		hand = well.lerp(low, u)
		# Pull the loose mag toward the camera so it clears the receiver.
		mag_at = hand + Vector3(0.0, -0.02, 0.05)
		if u > 0.2 and _reload_sfx < 1:
			_reload_sfx = 1
			Foley.play(self, "mag_out")
	elif stage == "drop":
		hand = low
		if _mag_drop == null and is_instance_valid(mag):
			_spawn_mag_drop(mag)
		show = false
		mag_at = low
	elif stage == "to_seat":
		hand = low.lerp(well, u)
		mag_at = hand
		show = true
		if u > 0.8 and _reload_sfx < 2:
			_reload_sfx = 2
			Foley.play(self, "mag_in")
	elif stage == "charge":
		var haul := sin(clampf(u, 0.0, 1.0) * PI)
		hand = well.lerp(charge, minf(1.0, u * 1.35)) + Vector3(0.0, 0.012, 0.055) * haul
		mag_at = well
		if u > 0.28 and _reload_sfx < 3:
			_reload_sfx = 3
			Foley.play(self, "bolt")
	else:
		var from: Vector3 = charge if _reload_empty else well
		hand = from.lerp(support, u)
		mag_at = well
	_left_local = hand
	_left_override = true
	if is_instance_valid(mag):
		mag.visible = show
		mag.position = mag_at


func _drive_arrow(stage: String, u: float, support: Vector3) -> void:
	var nock := Vector3(-0.022, 0.035, -0.04)
	var reach := nock + Vector3(0.14, -0.1, 0.12)
	_left_override = true
	if stage == "reach":
		_left_local = support.lerp(reach, u)
	elif stage == "nock":
		_left_local = reach.lerp(nock, u)
	else:
		_left_local = nock.lerp(support, u)
	if not is_instance_valid(_bow_arrow):
		return
	_bow_arrow.visible = true
	if stage == "reach":
		_bow_arrow.position = reach
	elif stage == "nock":
		_bow_arrow.position = reach.lerp(nock, u)
		if u > 0.72 and _reload_sfx < 1:
			_reload_sfx = 1
			Foley.play(self, "nock")
	else:
		_bow_arrow.position = nock


func _spawn_mag_drop(mag: Node3D) -> void:
	_clear_mag_drop()
	var drop := mag.duplicate() as Node3D
	drop.name = "MagDrop"
	mag.get_parent().add_child(drop)
	drop.global_transform = mag.global_transform
	drop.visible = true
	drop.set_meta("fall", 0.0)
	_mag_drop = drop


func _tick_mag_drop(delta: float) -> void:
	if not is_instance_valid(_mag_drop):
		_mag_drop = null
		return
	var fall := float(_mag_drop.get_meta("fall", 0.0)) + delta
	_mag_drop.set_meta("fall", fall)
	_mag_drop.position += Vector3(0.02, -0.7, 0.05) * delta
	_mag_drop.rotation_degrees.x += 220.0 * delta
	if fall > 0.48:
		_mag_drop.queue_free()
		_mag_drop = null


func _clear_mag_drop() -> void:
	if is_instance_valid(_mag_drop):
		_mag_drop.queue_free()
	_mag_drop = null


func _seat_mag() -> void:
	var mag: Node3D = _magazines.get(_active_id)
	if not is_instance_valid(mag):
		return
	if mag.has_meta("rest_pos"):
		mag.position = mag.get_meta("rest_pos")
	mag.visible = str(mag.get_meta("feed", "mag")) != "shell"


func _rest_left_hand() -> void:
	_left_override = false


func _solve_view_arms(ads: float) -> void:
	var root := _active_root()
	var slot: Node3D = _slots.get(_active_id)
	if root == null or not is_instance_valid(slot) or not slot.visible or not root.has_meta("fp_grip"):
		return
	var skel: Skeleton3D = root.get_meta("fp_skel")
	if skel == null or not is_instance_valid(skel):
		return
	var style := str(root.get_meta("fp_style", "rifle"))
	var grip: Vector3 = root.get_meta("fp_grip")
	var support: Vector3 = root.get_meta("fp_support")
	var right_local := grip + FpArms.right_offset(style)
	var left_point: Vector3 = _left_local if _left_override else support
	var left_local := left_point + FpArms.left_offset(style)
	var cam := get_parent() as Node3D
	FpArms.solve(skel, root, cam if cam != null else self, right_local, left_local, ads, style)


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
			# Closer than the hip hold so the grip sits near the bottom edge
			# while the sight stays on the crosshair.
			var hold_z := 0.42
			# Positive yaw swings the muzzle left so the right side of the
			# receiver and the handguard read, instead of a rear-on stick.
			# Negative pitch drops the barrel so the hands sit low in the frame.
			var yaw_trim := 14.0
			var pitch_trim := -18.0
			match wid:
				GameState.WeaponId.PISTOL, GameState.WeaponId.MACHINE_PISTOL, GameState.WeaponId.TRANQ_PISTOL:
					hold_z = 0.34
					yaw_trim = 12.0
					pitch_trim = -6.0
				GameState.WeaponId.SMG:
					hold_z = 0.40
					yaw_trim = 15.0
					pitch_trim = -10.0
				GameState.WeaponId.SHOTGUN, GameState.WeaponId.LMG:
					hold_z = 0.46
					yaw_trim = 14.0
					pitch_trim = -8.0
				GameState.WeaponId.SNIPER, GameState.WeaponId.SILENCED_SNIPER:
					hold_z = 0.50
					yaw_trim = 6.0
					pitch_trim = -4.0
				GameState.WeaponId.CROSSBOW:
					hold_z = 0.44
					yaw_trim = 8.0
					pitch_trim = -6.0
			var turned := Basis.from_euler(Vector3(deg_to_rad(pitch_trim), deg_to_rad(yaw_trim), 0.0)) * sight
			return {
				"pos": Vector3(-turned.x, -turned.y, -hold_z - turned.z),
				"rot": Vector3(pitch_trim, yaw_trim, 0.0),
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
