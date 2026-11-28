extends Node3D
class_name GuardVisual
## Smooth humanoid (capsule limbs, sphere joints, head center at y=1.70).
## Procedural clips: idle, walk, run, crouch, aim, alert, cover, peek, shoot, death.
## Head center matches Guard/HitZones/Head. Alert and tag icons stay above the helmet.

signal animation_finished(anim_name: StringName)

@onready var placeholder_mesh: MeshInstance3D = get_node_or_null("PlaceholderMesh") as MeshInstance3D
@onready var anim_player: AnimationPlayer = $AnimationPlayer

const ANIM_IDLE := &"idle"
const ANIM_WALK := &"walk"
const ANIM_RUN := &"run"
const ANIM_SHOOT := &"shoot"
const ANIM_HIT := &"hit"
const ANIM_DEATH := &"death"
const ANIM_DEATH_HEAD := &"death_head"
const ANIM_DEATH_BACK := &"death_back"
const ANIM_DEATH_EXPLODE := &"death_explode"
const ANIM_INVESTIGATE := &"investigate"
const ANIM_LOOK_AROUND := &"look_around"
const ANIM_RADIO := &"radio"
const ANIM_ALARM_PRESS := &"alarm_press"
const ANIM_TAKEDOWN_BACK := &"takedown_back"
const ANIM_TAKEDOWN_FRONT := &"takedown_front"
const ANIM_CROUCH := &"crouch"
const ANIM_AIM := &"aim"
const ANIM_ALERT := &"alert"
const ANIM_COVER := &"cover"
const ANIM_PEEK := &"peek"
const LIB_NAME := &"guard"

var _rig: Node3D
var _pelvis: Node3D
var _torso: Node3D
var _head: Node3D
var _left_arm: Node3D
var _right_arm: Node3D
var _left_leg: Node3D
var _right_leg: Node3D
var _rifle_flash: Node3D
var _accent_meshes: Array[MeshInstance3D] = []

var _flash_timer: float = 0.0
var _oneshot_timer: float = 0.0
var _is_dead: bool = false
var _cover_pose: String = ""
var _cloth: Array[MeshInstance3D] = []
var _pants: Array[MeshInstance3D] = []
var _gear: Dictionary = {}


func _ready() -> void:
	if is_instance_valid(placeholder_mesh):
		placeholder_mesh.visible = false
	_build_humanoid()
	_build_animations()
	if is_instance_valid(anim_player) and not anim_player.animation_finished.is_connected(_on_anim_finished):
		anim_player.animation_finished.connect(_on_anim_finished)
	play(ANIM_IDLE, 0.0)


func _process(delta: float) -> void:
	if _flash_timer > 0.0:
		_flash_timer -= delta
		if _flash_timer <= 0.0 and is_instance_valid(_rifle_flash):
			_rifle_flash.visible = false
	if _oneshot_timer > 0.0:
		_oneshot_timer = maxf(0.0, _oneshot_timer - delta)


func _hi_detail() -> bool:
	if OS.has_feature("mobile"):
		return false
	if GraphicsQuality and GraphicsQuality.level == GraphicsQuality.LEVEL_LOW:
		return false
	return true


func _remember(bucket: Array[MeshInstance3D], mi: MeshInstance3D) -> MeshInstance3D:
	if mi != null:
		bucket.append(mi)
	return mi


func _build_humanoid() -> void:
	if get_node_or_null("Rig"):
		return
	var jacket := Color(0.30, 0.36, 0.24)
	var pants_col := Color(0.27, 0.25, 0.21)
	var vest := Color(0.14, 0.15, 0.14)
	var boot := Color(0.10, 0.09, 0.08)
	var skin := Color(0.72, 0.56, 0.44)
	var gun := Color(0.12, 0.13, 0.14)
	var accent := Color(0.62, 0.28, 0.16)

	_rig = Node3D.new()
	_rig.name = "Rig"
	add_child(_rig)

	# Pelvis at y=0.90. Head pivot is placed so the skull center is world y=1.70.
	_pelvis = Node3D.new()
	_pelvis.name = "Pelvis"
	_pelvis.position = Vector3(0, 0.90, 0)
	_rig.add_child(_pelvis)
	var hips := ProcMesh.add_part(_pelvis, ProcMesh.sphere_mesh(0.13, pants_col, 0.86, 0.0), Vector3(0, 0.02, 0))
	hips.scale = Vector3(1.35, 0.72, 1.05)
	_remember(_pants, hips)

	_torso = Node3D.new()
	_torso.name = "Torso"
	_torso.position = Vector3(0, 0.08, 0)
	_pelvis.add_child(_torso)
	var chest := ProcMesh.add_part(_torso, ProcMesh.capsule_mesh(0.17, 0.62, jacket, 0.84, 0.02), Vector3(0, 0.30, 0))
	chest.scale = Vector3(1.12, 1.0, 0.84)
	_remember(_cloth, chest)
	var vest_mi := ProcMesh.add_part(_torso, ProcMesh.capsule_mesh(0.16, 0.42, vest, 0.7, 0.08), Vector3(0, 0.30, -0.03))
	vest_mi.scale = Vector3(1.08, 0.82, 0.92)
	if _hi_detail():
		for i in range(3):
			ProcMesh.add_part(_torso, ProcMesh.box_mesh(Vector3(0.07, 0.10, 0.045), vest.lightened(0.08), 0.75, 0.1), Vector3(-0.08 + float(i) * 0.08, 0.12, -0.16))
	var belt := ProcMesh.add_part(_torso, ProcMesh.capsule_mesh(0.045, 0.34, boot, 0.6, 0.15), Vector3(0, 0.08, -0.12))
	belt.rotation_degrees = Vector3(0, 0, 90)
	var stripe := ProcMesh.add_part(_torso, ProcMesh.box_mesh(Vector3(0.28, 0.045, 0.02), accent, 0.6, 0.05), Vector3(0, 0.34, -0.16), Vector3.ZERO, "ChestAccent")
	_accent_meshes.append(stripe)
	ProcMesh.add_part(_torso, ProcMesh.capsule_mesh(0.08, 0.22, vest, 0.8, 0.05), Vector3(0, 0.28, 0.16))
	if _hi_detail():
		ProcMesh.add_part(_torso, ProcMesh.cylinder_mesh(0.008, 0.28, gun, 0.4, 0.6, 6), Vector3(-0.06, 0.48, 0.18))

	# Skull center == HitZones/Head (world y 1.70). Torso origin is world y 0.98.
	_head = Node3D.new()
	_head.name = "Head"
	_head.position = Vector3(0, 0.54, 0)
	_torso.add_child(_head)
	ProcMesh.add_part(_head, ProcMesh.capsule_mesh(0.072, 0.16, skin, 0.8, 0.0), Vector3(0, -0.02, 0))
	ProcMesh.add_part(_head, _smooth_sphere(0.125, skin, 0.7), Vector3(0, 0.16, 0.02))
	if _hi_detail():
		ProcMesh.add_part(_head, ProcMesh.sphere_mesh(0.016, Color(0.08, 0.08, 0.09), 0.3, 0.1), Vector3(-0.042, 0.17, -0.09))
		ProcMesh.add_part(_head, ProcMesh.sphere_mesh(0.016, Color(0.08, 0.08, 0.09), 0.3, 0.1), Vector3(0.042, 0.17, -0.09))
		ProcMesh.add_part(_head, ProcMesh.sphere_mesh(0.032, skin.darkened(0.08), 0.8, 0.0), Vector3(-0.12, 0.14, 0.0))
		ProcMesh.add_part(_head, ProcMesh.sphere_mesh(0.032, skin.darkened(0.08), 0.8, 0.0), Vector3(0.12, 0.14, 0.0))
	var mask := ProcMesh.add_part(_head, ProcMesh.box_mesh(Vector3(0.14, 0.045, 0.03), accent, 0.8, 0.0), Vector3(0, 0.12, -0.10), Vector3.ZERO, "MaskAccent")
	_accent_meshes.append(mask)
	_build_head_gear(gun)

	_left_arm = _build_arm("LeftArm", -1.0, jacket, boot, skin, false, gun, vest)
	_right_arm = _build_arm("RightArm", 1.0, jacket, boot, skin, true, gun, vest)
	_left_leg = _build_leg("LeftLeg", -0.09, pants_col, boot)
	_right_leg = _build_leg("RightLeg", 0.09, pants_col, boot)
	_wear_rig_materials(_rig)


func _smooth_sphere(radius: float, color: Color, roughness: float) -> MeshInstance3D:
	var sph := SphereMesh.new()
	sph.radius = radius
	sph.height = radius * 2.0
	sph.radial_segments = 16 if _hi_detail() else 8
	sph.rings = 8 if _hi_detail() else 4
	var mi := MeshInstance3D.new()
	mi.mesh = sph
	mi.material_override = ProcMesh.mat(color, roughness, 0.02)
	return mi


func _build_head_gear(gun: Color) -> void:
	var cap := Node3D.new()
	cap.name = "Cap"
	_head.add_child(cap)
	_gear["Cap"] = cap
	var crown := ProcMesh.add_part(cap, ProcMesh.sphere_mesh(0.132, Color(0.20, 0.24, 0.16), 0.75, 0.05), Vector3(0, 0.18, 0.02))
	crown.scale = Vector3(1.05, 0.42, 1.05)
	ProcMesh.add_part(cap, ProcMesh.box_mesh(Vector3(0.24, 0.012, 0.18), Color(0.16, 0.18, 0.12), 0.7, 0.05), Vector3(0, 0.14, -0.08))

	var helmet := Node3D.new()
	helmet.name = "Helmet"
	helmet.visible = false
	_head.add_child(helmet)
	_gear["Helmet"] = helmet
	var helm_shell := ProcMesh.add_part(helmet, ProcMesh.sphere_mesh(0.145, Color(0.16, 0.17, 0.18), 0.45, 0.35), Vector3(0, 0.18, 0.01))
	helm_shell.scale = Vector3(1.05, 0.85, 1.08)
	ProcMesh.add_part(helmet, ProcMesh.box_mesh(Vector3(0.18, 0.04, 0.035), Color(0.05, 0.06, 0.07), 0.25, 0.4), Vector3(0, 0.12, -0.12))

	var beret := Node3D.new()
	beret.name = "Beret"
	beret.visible = false
	_head.add_child(beret)
	_gear["Beret"] = beret
	var beret_mesh := ProcMesh.add_part(beret, ProcMesh.sphere_mesh(0.12, Color(0.55, 0.10, 0.10), 0.7, 0.05), Vector3(0.02, 0.20, 0.0))
	beret_mesh.scale = Vector3(1.2, 0.38, 1.05)
	beret_mesh.rotation_degrees = Vector3(0, 0, -18)
	ProcMesh.add_part(beret, ProcMesh.sphere_mesh(0.025, Color(0.85, 0.72, 0.28), 0.4, 0.6), Vector3(0.02, 0.07, -0.08))

	var boonie := Node3D.new()
	boonie.name = "Boonie"
	boonie.visible = false
	_head.add_child(boonie)
	_gear["Boonie"] = boonie
	var boonie_crown := ProcMesh.add_part(boonie, ProcMesh.sphere_mesh(0.125, Color(0.22, 0.28, 0.16), 0.8, 0.02), Vector3(0, 0.18, 0))
	boonie_crown.scale = Vector3(1.0, 0.42, 1.0)
	ProcMesh.add_part(boonie, ProcMesh.cylinder_mesh(0.20, 0.015, Color(0.20, 0.26, 0.14), 0.85, 0.02, 12), Vector3(0, 0.15, 0))

	var headset := Node3D.new()
	headset.name = "Headset"
	_head.add_child(headset)
	_gear["Headset"] = headset
	var band := ProcMesh.add_part(headset, ProcMesh.capsule_mesh(0.012, 0.24, gun, 0.45, 0.4), Vector3(0, 0.20, 0))
	band.rotation_degrees = Vector3(0, 0, 90)
	ProcMesh.add_part(headset, ProcMesh.sphere_mesh(0.038, gun, 0.45, 0.35), Vector3(-0.125, 0.14, 0.0))
	ProcMesh.add_part(headset, ProcMesh.sphere_mesh(0.038, gun, 0.45, 0.35), Vector3(0.125, 0.14, 0.0))
	ProcMesh.add_part(headset, ProcMesh.cylinder_mesh(0.007, 0.09, gun, 0.4, 0.4, 5), Vector3(-0.10, 0.10, -0.08), Vector3(70, 0, 0))

	var plate := Node3D.new()
	plate.name = "HeavyPlate"
	plate.visible = false
	_torso.add_child(plate)
	_gear["HeavyPlate"] = plate
	var plate_mi := ProcMesh.add_part(plate, ProcMesh.capsule_mesh(0.16, 0.32, Color(0.18, 0.19, 0.22), 0.45, 0.4), Vector3(0, 0.26, -0.06))
	plate_mi.scale = Vector3(1.15, 0.9, 0.55)

	var ghillie := Node3D.new()
	ghillie.name = "Ghillie"
	ghillie.visible = false
	_torso.add_child(ghillie)
	_gear["Ghillie"] = ghillie
	if _hi_detail():
		for i in range(9):
			var strand := ProcMesh.add_part(ghillie, ProcMesh.capsule_mesh(0.014, 0.34, Color(0.16, 0.28, 0.10), 0.95, 0.0), Vector3(-0.16 + float(i) * 0.04, 0.28, -0.02))
			strand.rotation_degrees = Vector3(18.0 + float(i % 3) * 8.0, float(i) * 6.0, 0)

	var boards := Node3D.new()
	boards.name = "Boards"
	boards.visible = false
	_torso.add_child(boards)
	_gear["Boards"] = boards
	ProcMesh.add_part(boards, ProcMesh.box_mesh(Vector3(0.08, 0.035, 0.06), Color(0.82, 0.68, 0.28), 0.4, 0.65), Vector3(-0.16, 0.42, -0.08))
	ProcMesh.add_part(boards, ProcMesh.box_mesh(Vector3(0.08, 0.035, 0.06), Color(0.82, 0.68, 0.28), 0.4, 0.65), Vector3(0.16, 0.42, -0.08))

	var armband := Node3D.new()
	armband.name = "Armband"
	armband.visible = false
	_torso.add_child(armband)
	_gear["Armband"] = armband
	ProcMesh.add_part(armband, ProcMesh.capsule_mesh(0.04, 0.08, Color(0.75, 0.18, 0.14), 0.6, 0.05), Vector3(-0.20, 0.30, -0.04))


func _build_arm(arm_name: String, side: float, jacket: Color, glove: Color, skin: Color, with_rifle: bool, gun: Color, vest: Color) -> Node3D:
	var arm := Node3D.new()
	arm.name = arm_name
	arm.position = Vector3(0.19 * side, 0.44, 0)
	# Low-ready carry. Idle/aim clips key this same shoulder pose so the rifle stays in the hands.
	arm.rotation_degrees = Vector3(38.0, 22.0 * side, -18.0 * side)
	_torso.add_child(arm)
	ProcMesh.add_part(arm, ProcMesh.sphere_mesh(0.055, jacket, 0.84, 0.02), Vector3(0, 0, 0))
	_remember(_cloth, ProcMesh.add_part(arm, ProcMesh.capsule_mesh(0.048, 0.26, jacket, 0.84, 0.02), Vector3(0, -0.13, 0)))
	var forearm := Node3D.new()
	forearm.name = "Forearm"
	forearm.position = Vector3(0, -0.24, 0)
	forearm.rotation_degrees = Vector3(46.0, -30.0 * side, 4.0 * side)
	arm.add_child(forearm)
	ProcMesh.add_part(forearm, ProcMesh.sphere_mesh(0.042, skin.darkened(0.05), 0.8, 0.0), Vector3.ZERO)
	ProcMesh.add_part(forearm, ProcMesh.capsule_mesh(0.04, 0.24, jacket, 0.84, 0.02), Vector3(0, -0.12, 0))
	ProcMesh.add_part(forearm, ProcMesh.sphere_mesh(0.04, glove, 0.75, 0.04), Vector3(0.01 * side, -0.24, 0))
	if with_rifle:
		_attach_rifle(forearm, gun, vest)
	return arm


func _attach_rifle(forearm: Node3D, gun: Color, vest: Color) -> void:
	var rifle := Node3D.new()
	rifle.name = "GuardRifle"
	rifle.position = Vector3(0, -0.24, 0)
	forearm.add_child(rifle)
	# Barrel mesh points along local -Z. Match the torso so the muzzle aims with the body.
	var body := forearm.get_parent().get_parent() as Node3D
	if is_instance_valid(body):
		rifle.global_basis = body.global_basis
		rifle.rotate_object_local(Vector3.RIGHT, deg_to_rad(6.0))
	ProcMesh.add_part(rifle, ProcMesh.box_mesh(Vector3(0.05, 0.07, 0.28), gun, 0.42, 0.55), Vector3(0, 0.02, -0.02))
	ProcMesh.add_part(rifle, ProcMesh.cylinder_mesh(0.012, 0.34, gun.darkened(0.1), 0.32, 0.72, 8), Vector3(0, 0.035, -0.30), Vector3(90, 0, 0))
	ProcMesh.add_part(rifle, ProcMesh.box_mesh(Vector3(0.045, 0.04, 0.16), vest, 0.55, 0.25), Vector3(0, 0.0, -0.10))
	ProcMesh.add_part(rifle, ProcMesh.box_mesh(Vector3(0.04, 0.12, 0.05), vest, 0.6, 0.2), Vector3(0, -0.06, 0.02), Vector3(14, 0, 0))
	ProcMesh.add_part(rifle, ProcMesh.box_mesh(Vector3(0.04, 0.07, 0.16), Color(0.28, 0.20, 0.12), 0.72, 0.08), Vector3(0, -0.01, 0.16))
	ProcMesh.add_part(rifle, ProcMesh.box_mesh(Vector3(0.02, 0.025, 0.06), Color(0.08, 0.09, 0.1), 0.4, 0.5), Vector3(0, 0.06, 0.02))
	var kit := Node3D.new()
	kit.name = "SniperKit"
	kit.visible = false
	ProcMesh.add_part(kit, ProcMesh.cylinder_mesh(0.02, 0.20, gun, 0.3, 0.65, 8), Vector3(0, 0.07, -0.06), Vector3(90, 0, 0))
	ProcMesh.add_part(kit, ProcMesh.cylinder_mesh(0.011, 0.28, gun, 0.3, 0.7, 6), Vector3(0, 0.035, -0.52), Vector3(90, 0, 0))
	var glint := ProcMesh.sphere_mesh(0.012, Color(0.55, 0.75, 0.85))
	glint.material_override = ProcMesh.emissive(Color(0.65, 0.82, 0.95), 0.35)
	ProcMesh.add_part(kit, glint, Vector3(0, 0.07, -0.16))
	rifle.add_child(kit)
	_rifle_flash = Node3D.new()
	_rifle_flash.name = "MuzzleFlash"
	_rifle_flash.position = Vector3(0, 0.035, -0.48)
	_rifle_flash.visible = false
	var mf_mat := ProcMesh.unshaded(Color(1.0, 0.78, 0.2, 0.95))
	for deg in [0.0, 60.0, 120.0]:
		var f := ProcMesh.box_mesh(Vector3(0.16, 0.035, 0.03), Color(1.0, 0.8, 0.25))
		f.material_override = mf_mat
		ProcMesh.add_part(_rifle_flash, f, Vector3.ZERO, Vector3(0, 0, deg))
	rifle.add_child(_rifle_flash)
	# Plant the support hand on the handguard so the rifle reads as held, not floating.
	var support := _torso.get_node_or_null("LeftArm/Forearm") as Node3D
	if is_instance_valid(support) and is_instance_valid(body):
		var grip_at := rifle.to_global(Vector3(-0.02, 0.0, -0.12))
		var reach := support.global_position.direction_to(grip_at)
		if reach.length_squared() > 0.01:
			var up := body.global_basis.y
			var x_axis := up.cross(reach).normalized()
			if x_axis.length_squared() < 0.01:
				x_axis = body.global_basis.x
			var y_axis := -reach.normalized()
			var z_axis := x_axis.cross(y_axis).normalized()
			x_axis = y_axis.cross(z_axis).normalized()
			support.global_basis = Basis(x_axis, y_axis, z_axis)


func _build_leg(leg_name: String, x: float, pants_col: Color, boot: Color) -> Node3D:
	var leg := Node3D.new()
	leg.name = leg_name
	leg.position = Vector3(x, -0.02, 0)
	_pelvis.add_child(leg)
	ProcMesh.add_part(leg, ProcMesh.sphere_mesh(0.07, pants_col, 0.86, 0.0), Vector3.ZERO)
	_remember(_pants, ProcMesh.add_part(leg, ProcMesh.capsule_mesh(0.078, 0.38, pants_col, 0.86, 0.0), Vector3(0, -0.18, 0)))
	var shin := Node3D.new()
	shin.name = "Shin"
	shin.position = Vector3(0, -0.36, 0)
	leg.add_child(shin)
	ProcMesh.add_part(shin, ProcMesh.sphere_mesh(0.058, pants_col.darkened(0.08), 0.86, 0.0), Vector3.ZERO)
	_remember(_pants, ProcMesh.add_part(shin, ProcMesh.capsule_mesh(0.058, 0.36, pants_col, 0.86, 0.0), Vector3(0, -0.16, 0)))
	var boot_mi := ProcMesh.add_part(shin, ProcMesh.capsule_mesh(0.06, 0.16, boot, 0.55, 0.08), Vector3(0, -0.34, -0.04))
	boot_mi.scale = Vector3(1.0, 0.7, 1.45)
	return leg


func _add_rot_track(anim: Animation, path: String, keys: Array) -> void:
	var t := anim.add_track(Animation.TYPE_VALUE)
	anim.track_set_path(t, NodePath(path + ":rotation_degrees"))
	for k in keys:
		anim.track_insert_key(t, k[0], k[1])


func _add_pos_track(anim: Animation, path: String, keys: Array) -> void:
	var t := anim.add_track(Animation.TYPE_VALUE)
	anim.track_set_path(t, NodePath(path + ":position"))
	for k in keys:
		anim.track_insert_key(t, k[0], k[1])


func _build_animations() -> void:
	if not is_instance_valid(anim_player):
		return
	var lib: AnimationLibrary
	if anim_player.has_animation_library(LIB_NAME):
		lib = anim_player.get_animation_library(LIB_NAME)
	else:
		lib = AnimationLibrary.new()
		anim_player.add_animation_library(LIB_NAME, lib)

	# 1. IDLE (gentle breathing & ready stance)
	if not lib.has_animation(ANIM_IDLE):
		var a := Animation.new()
		a.length = 1.6
		a.loop_mode = Animation.LOOP_LINEAR
		_add_pos_track(a, "Rig/Pelvis", [[0.0, Vector3(0, 0.90, 0)], [0.8, Vector3(0, 0.90, 0)], [1.6, Vector3(0, 0.90, 0)]])
		_add_rot_track(a, "Rig/Pelvis", [[0.0, Vector3.ZERO], [1.6, Vector3.ZERO]])
		_add_rot_track(a, "Rig/Pelvis/Torso", [[0.0, Vector3(0, 0, 0)], [0.8, Vector3(2, 0, 0)], [1.6, Vector3(0, 0, 0)]])
		_add_rot_track(a, "Rig/Pelvis/Torso/Head", [[0.0, Vector3(0, -6, 0)], [0.8, Vector3(0, 6, 0)], [1.6, Vector3(0, -6, 0)]])
		_add_rot_track(a, "Rig/Pelvis/LeftLeg", [[0.0, Vector3.ZERO], [1.6, Vector3.ZERO]])
		_add_rot_track(a, "Rig/Pelvis/RightLeg", [[0.0, Vector3.ZERO], [1.6, Vector3.ZERO]])
		_add_rot_track(a, "Rig/Pelvis/Torso/RightArm", [[0.0, Vector3(38, 22, -18)], [1.6, Vector3(38, 22, -18)]])
		_add_rot_track(a, "Rig/Pelvis/Torso/LeftArm", [[0.0, Vector3(38, -22, 18)], [1.6, Vector3(38, -22, 18)]])
		lib.add_animation(ANIM_IDLE, a)

	# 2. WALK (patrol stride)
	if not lib.has_animation(ANIM_WALK):
		var a := Animation.new()
		a.length = 0.8
		a.loop_mode = Animation.LOOP_LINEAR
		_add_pos_track(a, "Rig/Pelvis", [[0.0, Vector3(0, 0.90, 0)], [0.2, Vector3(0, 0.92, 0)], [0.4, Vector3(0, 0.90, 0)], [0.6, Vector3(0, 0.92, 0)], [0.8, Vector3(0, 0.90, 0)]])
		_add_rot_track(a, "Rig/Pelvis", [[0.0, Vector3.ZERO], [0.8, Vector3.ZERO]])
		_add_rot_track(a, "Rig/Pelvis/Torso", [[0.0, Vector3(-4, -3, 0)], [0.4, Vector3(-4, 3, 0)], [0.8, Vector3(-4, -3, 0)]])
		_add_rot_track(a, "Rig/Pelvis/LeftLeg", [[0.0, Vector3(24, 0, 0)], [0.4, Vector3(-24, 0, 0)], [0.8, Vector3(24, 0, 0)]])
		_add_rot_track(a, "Rig/Pelvis/RightLeg", [[0.0, Vector3(-24, 0, 0)], [0.4, Vector3(24, 0, 0)], [0.8, Vector3(-24, 0, 0)]])
		_add_rot_track(a, "Rig/Pelvis/LeftLeg/Shin", [[0.0, Vector3(-28, 0, 0)], [0.4, Vector3(-8, 0, 0)], [0.8, Vector3(-28, 0, 0)]])
		_add_rot_track(a, "Rig/Pelvis/RightLeg/Shin", [[0.0, Vector3(-8, 0, 0)], [0.4, Vector3(-28, 0, 0)], [0.8, Vector3(-8, 0, 0)]])
		_add_rot_track(a, "Rig/Pelvis/Torso/RightArm", [[0.0, Vector3(28, 22, -18)], [0.4, Vector3(48, 22, -18)], [0.8, Vector3(28, 22, -18)]])
		_add_rot_track(a, "Rig/Pelvis/Torso/LeftArm", [[0.0, Vector3(48, -22, 18)], [0.4, Vector3(28, -22, 18)], [0.8, Vector3(48, -22, 18)]])
		lib.add_animation(ANIM_WALK, a)

	# 3. RUN (alert / combat sprint)
	if not lib.has_animation(ANIM_RUN):
		var a := Animation.new()
		a.length = 0.52
		a.loop_mode = Animation.LOOP_LINEAR
		_add_pos_track(a, "Rig/Pelvis", [[0.0, Vector3(0, 0.84, 0)], [0.13, Vector3(0, 0.92, 0)], [0.26, Vector3(0, 0.84, 0)], [0.39, Vector3(0, 0.92, 0)], [0.52, Vector3(0, 0.84, 0)]])
		_add_rot_track(a, "Rig/Pelvis", [[0.0, Vector3.ZERO], [0.52, Vector3.ZERO]])
		_add_rot_track(a, "Rig/Pelvis/Torso", [[0.0, Vector3(-12, -5, 0)], [0.26, Vector3(-12, 5, 0)], [0.52, Vector3(-12, -5, 0)]])
		_add_rot_track(a, "Rig/Pelvis/LeftLeg", [[0.0, Vector3(42, 0, 0)], [0.26, Vector3(-42, 0, 0)], [0.52, Vector3(42, 0, 0)]])
		_add_rot_track(a, "Rig/Pelvis/RightLeg", [[0.0, Vector3(-42, 0, 0)], [0.26, Vector3(42, 0, 0)], [0.52, Vector3(-42, 0, 0)]])
		_add_rot_track(a, "Rig/Pelvis/LeftLeg/Shin", [[0.0, Vector3(-48, 0, 0)], [0.26, Vector3(-12, 0, 0)], [0.52, Vector3(-48, 0, 0)]])
		_add_rot_track(a, "Rig/Pelvis/RightLeg/Shin", [[0.0, Vector3(-12, 0, 0)], [0.26, Vector3(-48, 0, 0)], [0.52, Vector3(-12, 0, 0)]])
		_add_rot_track(a, "Rig/Pelvis/Torso/RightArm", [[0.0, Vector3(22, 18, -16)], [0.26, Vector3(52, 18, -16)], [0.52, Vector3(22, 18, -16)]])
		_add_rot_track(a, "Rig/Pelvis/Torso/LeftArm", [[0.0, Vector3(52, -18, 16)], [0.26, Vector3(22, -18, 16)], [0.52, Vector3(52, -18, 16)]])
		lib.add_animation(ANIM_RUN, a)

	# 4. SHOOT (aimed rifle recoil kick)
	if not lib.has_animation(ANIM_SHOOT):
		var a := Animation.new()
		a.length = 0.24
		a.loop_mode = Animation.LOOP_NONE
		_add_rot_track(a, "Rig/Pelvis/Torso", [[0.0, Vector3(-4, 0, 0)], [0.06, Vector3(8, 0, 0)], [0.24, Vector3(-2, 0, 0)]])
		_add_rot_track(a, "Rig/Pelvis/Torso/RightArm", [[0.0, Vector3(38, 22, -18)], [0.06, Vector3(52, 22, -18)], [0.24, Vector3(36, 22, -18)]])
		_add_rot_track(a, "Rig/Pelvis/Torso/LeftArm", [[0.0, Vector3(38, -22, 18)], [0.06, Vector3(50, -22, 18)], [0.24, Vector3(36, -22, 18)]])
		lib.add_animation(ANIM_SHOOT, a)

	# 5. HIT (flinch backward on damage)
	if not lib.has_animation(ANIM_HIT):
		var a := Animation.new()
		a.length = 0.24
		a.loop_mode = Animation.LOOP_NONE
		_add_rot_track(a, "Rig/Pelvis/Torso", [[0.0, Vector3.ZERO], [0.07, Vector3(24, -10, 6)], [0.24, Vector3.ZERO]])
		_add_rot_track(a, "Rig/Pelvis/Torso/Head", [[0.0, Vector3.ZERO], [0.07, Vector3(22, 12, 0)], [0.24, Vector3.ZERO]])
		lib.add_animation(ANIM_HIT, a)

	# 6. DEATH variants — body fall, headshot snap, back shot, explosion ragdoll
	if not lib.has_animation(ANIM_DEATH):
		var a := Animation.new()
		a.length = 0.75
		a.loop_mode = Animation.LOOP_NONE
		_add_pos_track(a, "Rig/Pelvis", [[0.0, Vector3(0, 0.90, 0)], [0.35, Vector3(0, 0.45, 0.15)], [0.75, Vector3(0, 0.18, 0.35)]])
		_add_rot_track(a, "Rig/Pelvis", [[0.0, Vector3.ZERO], [0.35, Vector3(52, 0, 8)], [0.75, Vector3(86, 0, 12)]])
		_add_rot_track(a, "Rig/Pelvis/Torso/RightArm", [[0.0, Vector3.ZERO], [0.75, Vector3(-18, 0, -45)]])
		_add_rot_track(a, "Rig/Pelvis/Torso/LeftArm", [[0.0, Vector3.ZERO], [0.75, Vector3(-14, 0, 40)]])
		_add_rot_track(a, "Rig/Pelvis/LeftLeg", [[0.0, Vector3.ZERO], [0.75, Vector3(-12, 0, 14)]])
		_add_rot_track(a, "Rig/Pelvis/RightLeg", [[0.0, Vector3.ZERO], [0.75, Vector3(10, 0, -12)]])
		lib.add_animation(ANIM_DEATH, a)
	if not lib.has_animation(ANIM_DEATH_HEAD):
		var ah := Animation.new()
		ah.length = 0.62
		ah.loop_mode = Animation.LOOP_NONE
		_add_pos_track(ah, "Rig/Pelvis", [[0.0, Vector3(0, 0.90, 0)], [0.18, Vector3(0, 0.72, 0.22)], [0.42, Vector3(0, 0.32, 0.48)], [0.62, Vector3(0, 0.14, 0.58)]])
		_add_rot_track(ah, "Rig/Pelvis", [[0.0, Vector3.ZERO], [0.18, Vector3(28, -8, 6)], [0.42, Vector3(78, -6, 10)], [0.62, Vector3(92, -4, 12)]])
		_add_rot_track(ah, "Rig/Pelvis/Torso/Head", [[0.0, Vector3.ZERO], [0.08, Vector3(-55, 28, -18)], [0.28, Vector3(22, -10, 8)], [0.62, Vector3(8, 0, 0)]])
		_add_rot_track(ah, "Rig/Pelvis/Torso/RightArm", [[0.0, Vector3.ZERO], [0.2, Vector3(40, -20, -55)], [0.62, Vector3(-22, 0, -50)]])
		_add_rot_track(ah, "Rig/Pelvis/Torso/LeftArm", [[0.0, Vector3.ZERO], [0.2, Vector3(36, 24, 58)], [0.62, Vector3(-18, 0, 48)]])
		lib.add_animation(ANIM_DEATH_HEAD, ah)
	if not lib.has_animation(ANIM_DEATH_BACK):
		var ab := Animation.new()
		ab.length = 0.7
		ab.loop_mode = Animation.LOOP_NONE
		_add_pos_track(ab, "Rig/Pelvis", [[0.0, Vector3(0, 0.90, 0)], [0.22, Vector3(0, 0.7, -0.18)], [0.48, Vector3(0, 0.28, -0.42)], [0.7, Vector3(0, 0.14, -0.55)]])
		_add_rot_track(ab, "Rig/Pelvis", [[0.0, Vector3.ZERO], [0.22, Vector3(-32, 6, -8)], [0.48, Vector3(-72, 10, -12)], [0.7, Vector3(-90, 12, -14)]])
		_add_rot_track(ab, "Rig/Pelvis/Torso/Head", [[0.0, Vector3.ZERO], [0.18, Vector3(28, 0, 0)], [0.7, Vector3(-12, 0, 0)]])
		_add_rot_track(ab, "Rig/Pelvis/Torso/RightArm", [[0.0, Vector3.ZERO], [0.25, Vector3(55, 0, -30)], [0.7, Vector3(10, 0, -42)]])
		_add_rot_track(ab, "Rig/Pelvis/Torso/LeftArm", [[0.0, Vector3.ZERO], [0.25, Vector3(50, 0, 35)], [0.7, Vector3(12, 0, 40)]])
		lib.add_animation(ANIM_DEATH_BACK, ab)
	if not lib.has_animation(ANIM_DEATH_EXPLODE):
		var ae := Animation.new()
		ae.length = 0.85
		ae.loop_mode = Animation.LOOP_NONE
		_add_pos_track(ae, "Rig/Pelvis", [[0.0, Vector3(0, 0.90, 0)], [0.12, Vector3(0.4, 1.35, 0.3)], [0.4, Vector3(0.9, 0.55, 0.8)], [0.85, Vector3(1.1, 0.12, 1.15)]])
		_add_rot_track(ae, "Rig/Pelvis", [[0.0, Vector3.ZERO], [0.12, Vector3(-40, 35, 50)], [0.4, Vector3(70, -40, 90)], [0.85, Vector3(110, -20, 120)]])
		_add_rot_track(ae, "Rig/Pelvis/Torso/RightArm", [[0.0, Vector3.ZERO], [0.15, Vector3(-80, 0, -70)], [0.85, Vector3(-40, 0, -90)]])
		_add_rot_track(ae, "Rig/Pelvis/Torso/LeftArm", [[0.0, Vector3.ZERO], [0.15, Vector3(-70, 0, 80)], [0.85, Vector3(-35, 0, 95)]])
		_add_rot_track(ae, "Rig/Pelvis/LeftLeg", [[0.0, Vector3.ZERO], [0.2, Vector3(60, 0, 30)], [0.85, Vector3(20, 0, 40)]])
		_add_rot_track(ae, "Rig/Pelvis/RightLeg", [[0.0, Vector3.ZERO], [0.2, Vector3(-50, 0, -35)], [0.85, Vector3(-15, 0, -45)]])
		lib.add_animation(ANIM_DEATH_EXPLODE, ae)

	# 7. INVESTIGATE (cautious crouched forward-leaning patrol stride, head scanning)
	if not lib.has_animation(ANIM_INVESTIGATE):
		var a := Animation.new()
		a.length = 0.95
		a.loop_mode = Animation.LOOP_LINEAR
		_add_pos_track(a, "Rig/Pelvis", [[0.0, Vector3(0, 0.78, 0)], [0.24, Vector3(0, 0.82, 0)], [0.48, Vector3(0, 0.78, 0)], [0.72, Vector3(0, 0.82, 0)], [0.95, Vector3(0, 0.78, 0)]])
		_add_rot_track(a, "Rig/Pelvis", [[0.0, Vector3.ZERO], [0.95, Vector3.ZERO]])
		_add_rot_track(a, "Rig/Pelvis/Torso", [[0.0, Vector3(-16, -6, 0)], [0.48, Vector3(-16, 6, 0)], [0.95, Vector3(-16, -6, 0)]])
		_add_rot_track(a, "Rig/Pelvis/Torso/Head", [[0.0, Vector3(10, -22, 0)], [0.48, Vector3(10, 22, 0)], [0.95, Vector3(10, -22, 0)]])
		_add_rot_track(a, "Rig/Pelvis/LeftLeg", [[0.0, Vector3(20, 0, 0)], [0.48, Vector3(-20, 0, 0)], [0.95, Vector3(20, 0, 0)]])
		_add_rot_track(a, "Rig/Pelvis/RightLeg", [[0.0, Vector3(-20, 0, 0)], [0.48, Vector3(20, 0, 0)], [0.95, Vector3(-20, 0, 0)]])
		_add_rot_track(a, "Rig/Pelvis/Torso/RightArm", [[0.0, Vector3(18, 0, 0)], [0.95, Vector3(18, 0, 0)]])
		_add_rot_track(a, "Rig/Pelvis/Torso/LeftArm", [[0.0, Vector3(18, 0, 0)], [0.95, Vector3(18, 0, 0)]])
		lib.add_animation(ANIM_INVESTIGATE, a)

	# 8. LOOK AROUND (stationary alert scan sweeping head & rifle left-right)
	if not lib.has_animation(ANIM_LOOK_AROUND):
		var a := Animation.new()
		a.length = 2.0
		a.loop_mode = Animation.LOOP_LINEAR
		_add_pos_track(a, "Rig/Pelvis", [[0.0, Vector3(0, 0.86, 0)], [1.0, Vector3(0, 0.90, 0)], [2.0, Vector3(0, 0.86, 0)]])
		_add_rot_track(a, "Rig/Pelvis/Torso", [[0.0, Vector3(-6, -16, 0)], [1.0, Vector3(-6, 16, 0)], [2.0, Vector3(-6, -16, 0)]])
		_add_rot_track(a, "Rig/Pelvis/Torso/Head", [[0.0, Vector3(4, -38, 0)], [0.5, Vector3(-4, 0, 0)], [1.0, Vector3(4, 38, 0)], [1.5, Vector3(-2, 0, 0)], [2.0, Vector3(4, -38, 0)]])
		_add_rot_track(a, "Rig/Pelvis/Torso/RightArm", [[0.0, Vector3(16, -8, 0)], [1.0, Vector3(16, 8, 0)], [2.0, Vector3(16, -8, 0)]])
		_add_rot_track(a, "Rig/Pelvis/Torso/LeftArm", [[0.0, Vector3(16, -8, 0)], [1.0, Vector3(16, 8, 0)], [2.0, Vector3(16, -8, 0)]])
		_add_rot_track(a, "Rig/Pelvis/LeftLeg", [[0.0, Vector3.ZERO], [2.0, Vector3.ZERO]])
		_add_rot_track(a, "Rig/Pelvis/RightLeg", [[0.0, Vector3.ZERO], [2.0, Vector3.ZERO]])
		lib.add_animation(ANIM_LOOK_AROUND, a)

	# 9. RADIO (left hand raised to shoulder mic, head tilted, rifle lowered)
	if not lib.has_animation(ANIM_RADIO):
		var a := Animation.new()
		a.length = 0.85
		a.loop_mode = Animation.LOOP_NONE
		_add_rot_track(a, "Rig/Pelvis/Torso", [[0.0, Vector3.ZERO], [0.2, Vector3(-4, -10, 0)], [0.65, Vector3(-4, -10, 0)], [0.85, Vector3.ZERO]])
		_add_rot_track(a, "Rig/Pelvis/Torso/Head", [[0.0, Vector3.ZERO], [0.2, Vector3(8, -14, -16)], [0.65, Vector3(10, -16, -16)], [0.85, Vector3.ZERO]])
		_add_rot_track(a, "Rig/Pelvis/Torso/LeftArm", [[0.0, Vector3.ZERO], [0.2, Vector3(72, 28, -24)], [0.65, Vector3(74, 30, -24)], [0.85, Vector3.ZERO]])
		_add_rot_track(a, "Rig/Pelvis/Torso/RightArm", [[0.0, Vector3.ZERO], [0.2, Vector3(-16, 0, 0)], [0.65, Vector3(-16, 0, 0)], [0.85, Vector3.ZERO]])
		lib.add_animation(ANIM_RADIO, a)

	# 10. ALARM PRESS (reaches forward and punches alarm panel button)
	if not lib.has_animation(ANIM_ALARM_PRESS):
		var a := Animation.new()
		a.length = 0.55
		a.loop_mode = Animation.LOOP_NONE
		_add_rot_track(a, "Rig/Pelvis/Torso", [[0.0, Vector3.ZERO], [0.2, Vector3(-14, 12, 0)], [0.38, Vector3(-18, 12, 0)], [0.55, Vector3.ZERO]])
		_add_rot_track(a, "Rig/Pelvis/Torso/LeftArm", [[0.0, Vector3.ZERO], [0.2, Vector3(84, -10, 8)], [0.35, Vector3(96, -12, 4)], [0.55, Vector3.ZERO]])
		_add_rot_track(a, "Rig/Pelvis/Torso/RightArm", [[0.0, Vector3.ZERO], [0.25, Vector3(-12, 0, 0)], [0.55, Vector3.ZERO]])
		lib.add_animation(ANIM_ALARM_PRESS, a)

	# 11. TAKEDOWN BACK (stealth grab/slash from behind: head snaps back, clutches neck, crumples forward)
	if not lib.has_animation(ANIM_TAKEDOWN_BACK):
		var a := Animation.new()
		a.length = 0.62
		a.loop_mode = Animation.LOOP_NONE
		_add_pos_track(a, "Rig/Pelvis", [[0.0, Vector3(0, 0.90, 0)], [0.22, Vector3(0, 0.82, 0.08)], [0.44, Vector3(0, 0.36, -0.10)], [0.62, Vector3(0, 0.16, -0.26)]])
		_add_rot_track(a, "Rig/Pelvis", [[0.0, Vector3.ZERO], [0.22, Vector3(18, 0, 0)], [0.44, Vector3(-52, 8, -10)], [0.62, Vector3(-86, 10, -14)]])
		_add_rot_track(a, "Rig/Pelvis/Torso/Head", [[0.0, Vector3.ZERO], [0.16, Vector3(44, 14, 10)], [0.44, Vector3(-12, 0, 0)], [0.62, Vector3(-20, 0, 0)]])
		_add_rot_track(a, "Rig/Pelvis/Torso/LeftArm", [[0.0, Vector3.ZERO], [0.18, Vector3(68, 35, -18)], [0.62, Vector3(12, 0, 38)]])
		_add_rot_track(a, "Rig/Pelvis/Torso/RightArm", [[0.0, Vector3.ZERO], [0.18, Vector3(68, -35, 18)], [0.62, Vector3(14, 0, -42)]])
		lib.add_animation(ANIM_TAKEDOWN_BACK, a)

	# 12. TAKEDOWN FRONT (frontal CQC strike/disarm: reels backward, arms flung wide, drops flat)
	if not lib.has_animation(ANIM_TAKEDOWN_FRONT):
		var a := Animation.new()
		a.length = 0.62
		a.loop_mode = Animation.LOOP_NONE
		_add_pos_track(a, "Rig/Pelvis", [[0.0, Vector3(0, 0.90, 0)], [0.18, Vector3(0, 0.86, 0.20)], [0.42, Vector3(0, 0.42, 0.34)], [0.62, Vector3(0, 0.16, 0.46)]])
		_add_rot_track(a, "Rig/Pelvis", [[0.0, Vector3.ZERO], [0.18, Vector3(28, -18, 8)], [0.42, Vector3(68, -10, 14)], [0.62, Vector3(88, -6, 16)]])
		_add_rot_track(a, "Rig/Pelvis/Torso/Head", [[0.0, Vector3.ZERO], [0.15, Vector3(42, -26, -12)], [0.62, Vector3(10, 0, 0)]])
		_add_rot_track(a, "Rig/Pelvis/Torso/LeftArm", [[0.0, Vector3.ZERO], [0.18, Vector3(45, -24, 58)], [0.62, Vector3(-10, 0, 62)]])
		_add_rot_track(a, "Rig/Pelvis/Torso/RightArm", [[0.0, Vector3.ZERO], [0.18, Vector3(52, 20, -64)], [0.62, Vector3(-12, 0, -60)]])
		lib.add_animation(ANIM_TAKEDOWN_FRONT, a)

	if not lib.has_animation(ANIM_CROUCH):
		var a := Animation.new()
		a.length = 1.1
		a.loop_mode = Animation.LOOP_LINEAR
		_add_pos_track(a, "Rig/Pelvis", [[0.0, Vector3(0, 0.62, 0)], [0.55, Vector3(0, 0.64, 0)], [1.1, Vector3(0, 0.62, 0)]])
		_add_rot_track(a, "Rig/Pelvis/Torso", [[0.0, Vector3(-18, 0, 0)], [0.55, Vector3(-16, 4, 0)], [1.1, Vector3(-18, 0, 0)]])
		_add_rot_track(a, "Rig/Pelvis/Torso/Head", [[0.0, Vector3(12, -8, 0)], [0.55, Vector3(12, 8, 0)], [1.1, Vector3(12, -8, 0)]])
		_add_rot_track(a, "Rig/Pelvis/LeftLeg", [[0.0, Vector3(48, 0, 0)], [1.1, Vector3(48, 0, 0)]])
		_add_rot_track(a, "Rig/Pelvis/RightLeg", [[0.0, Vector3(48, 0, 0)], [1.1, Vector3(48, 0, 0)]])
		_add_rot_track(a, "Rig/Pelvis/LeftLeg/Shin", [[0.0, Vector3(-78, 0, 0)], [1.1, Vector3(-78, 0, 0)]])
		_add_rot_track(a, "Rig/Pelvis/RightLeg/Shin", [[0.0, Vector3(-78, 0, 0)], [1.1, Vector3(-78, 0, 0)]])
		lib.add_animation(ANIM_CROUCH, a)
	if not lib.has_animation(ANIM_AIM):
		var a := Animation.new()
		a.length = 0.8
		a.loop_mode = Animation.LOOP_LINEAR
		_add_pos_track(a, "Rig/Pelvis", [[0.0, Vector3(0, 0.90, 0)], [0.8, Vector3(0, 0.90, 0)]])
		_add_rot_track(a, "Rig/Pelvis/Torso", [[0.0, Vector3(-6, 0, 0)], [0.4, Vector3(-4, 0, 0)], [0.8, Vector3(-6, 0, 0)]])
		_add_rot_track(a, "Rig/Pelvis/Torso/Head", [[0.0, Vector3(2, 0, 0)], [0.8, Vector3(2, 0, 0)]])
		_add_rot_track(a, "Rig/Pelvis/Torso/RightArm", [[0.0, Vector3(48, 16, -12)], [0.8, Vector3(48, 16, -12)]])
		_add_rot_track(a, "Rig/Pelvis/Torso/LeftArm", [[0.0, Vector3(48, -16, 12)], [0.8, Vector3(48, -16, 12)]])
		lib.add_animation(ANIM_AIM, a)
	if not lib.has_animation(ANIM_ALERT):
		var a := Animation.new()
		a.length = 1.2
		a.loop_mode = Animation.LOOP_LINEAR
		_add_pos_track(a, "Rig/Pelvis", [[0.0, Vector3(0, 0.90, 0)], [0.6, Vector3(0, 0.92, 0)], [1.2, Vector3(0, 0.90, 0)]])
		_add_rot_track(a, "Rig/Pelvis/Torso", [[0.0, Vector3(-4, -8, 0)], [0.6, Vector3(-4, 8, 0)], [1.2, Vector3(-4, -8, 0)]])
		_add_rot_track(a, "Rig/Pelvis/Torso/Head", [[0.0, Vector3(-4, -16, 0)], [0.6, Vector3(-4, 16, 0)], [1.2, Vector3(-4, -16, 0)]])
		_add_rot_track(a, "Rig/Pelvis/Torso/RightArm", [[0.0, Vector3(34, 20, -16)], [1.2, Vector3(34, 20, -16)]])
		_add_rot_track(a, "Rig/Pelvis/Torso/LeftArm", [[0.0, Vector3(34, -20, 16)], [1.2, Vector3(34, -20, 16)]])
		lib.add_animation(ANIM_ALERT, a)
	if not lib.has_animation(ANIM_COVER):
		var a := Animation.new()
		a.length = 1.0
		a.loop_mode = Animation.LOOP_LINEAR
		_add_pos_track(a, "Rig/Pelvis", [[0.0, Vector3(0, 0.52, 0.06)], [1.0, Vector3(0, 0.52, 0.06)]])
		_add_rot_track(a, "Rig/Pelvis/Torso", [[0.0, Vector3(-28, 22, 0)], [0.5, Vector3(-26, 22, 0)], [1.0, Vector3(-28, 22, 0)]])
		_add_rot_track(a, "Rig/Pelvis/Torso/Head", [[0.0, Vector3(8, -10, 0)], [1.0, Vector3(8, -10, 0)]])
		_add_rot_track(a, "Rig/Pelvis/LeftLeg", [[0.0, Vector3(62, 0, 0)], [1.0, Vector3(62, 0, 0)]])
		_add_rot_track(a, "Rig/Pelvis/RightLeg", [[0.0, Vector3(58, 0, 0)], [1.0, Vector3(58, 0, 0)]])
		_add_rot_track(a, "Rig/Pelvis/LeftLeg/Shin", [[0.0, Vector3(-90, 0, 0)], [1.0, Vector3(-90, 0, 0)]])
		_add_rot_track(a, "Rig/Pelvis/RightLeg/Shin", [[0.0, Vector3(-86, 0, 0)], [1.0, Vector3(-86, 0, 0)]])
		lib.add_animation(ANIM_COVER, a)
	if not lib.has_animation(ANIM_PEEK):
		var a := Animation.new()
		a.length = 0.7
		a.loop_mode = Animation.LOOP_LINEAR
		_add_pos_track(a, "Rig/Pelvis", [[0.0, Vector3(0, 0.66, 0)], [0.35, Vector3(0.06, 0.70, -0.02)], [0.7, Vector3(0, 0.66, 0)]])
		_add_rot_track(a, "Rig/Pelvis/Torso", [[0.0, Vector3(-12, -28, -8)], [0.35, Vector3(-8, -34, -10)], [0.7, Vector3(-12, -28, -8)]])
		_add_rot_track(a, "Rig/Pelvis/Torso/Head", [[0.0, Vector3(4, -12, 0)], [0.35, Vector3(2, -6, 0)], [0.7, Vector3(4, -12, 0)]])
		_add_rot_track(a, "Rig/Pelvis/LeftLeg", [[0.0, Vector3(40, 0, 0)], [0.7, Vector3(40, 0, 0)]])
		_add_rot_track(a, "Rig/Pelvis/RightLeg", [[0.0, Vector3(36, 0, 0)], [0.7, Vector3(36, 0, 0)]])
		_add_rot_track(a, "Rig/Pelvis/LeftLeg/Shin", [[0.0, Vector3(-55, 0, 0)], [0.7, Vector3(-55, 0, 0)]])
		_add_rot_track(a, "Rig/Pelvis/RightLeg/Shin", [[0.0, Vector3(-50, 0, 0)], [0.7, Vector3(-50, 0, 0)]])
		_add_rot_track(a, "Rig/Pelvis/Torso/RightArm", [[0.0, Vector3(42, 18, -14)], [0.7, Vector3(42, 18, -14)]])
		_add_rot_track(a, "Rig/Pelvis/Torso/LeftArm", [[0.0, Vector3(42, -18, 14)], [0.7, Vector3(42, -18, 14)]])
		lib.add_animation(ANIM_PEEK, a)


func play(anim_name: StringName, custom_blend: float = 0.18) -> void:
	if not is_instance_valid(anim_player):
		return
	var death_anims := [ANIM_DEATH, ANIM_DEATH_HEAD, ANIM_DEATH_BACK, ANIM_DEATH_EXPLODE, ANIM_TAKEDOWN_BACK, ANIM_TAKEDOWN_FRONT]
	if _is_dead and not death_anims.has(anim_name):
		return
	if not _has_anim(anim_name):
		return
	var full := StringName("%s/%s" % [LIB_NAME, anim_name])
	if anim_player.current_animation == String(full) and anim_player.is_playing():
		if anim_name != ANIM_SHOOT and anim_name != ANIM_HIT:
			return
	anim_player.play(full, custom_blend)


func play_state(state_name: String) -> void:
	match state_name:
		"PATROL":
			play(ANIM_WALK, 0.22)
		"SUSPICIOUS":
			play(ANIM_INVESTIGATE, 0.22)
		"ALERT":
			play(ANIM_RUN, 0.18)
		"COMBAT":
			play(ANIM_RUN, 0.14)
		"LOOK_AROUND":
			_oneshot_timer = 1.1
			play(ANIM_LOOK_AROUND, 0.18)
		"DEAD":
			_is_dead = true
			play(ANIM_DEATH, 0.08)
		_:
			play(ANIM_IDLE, 0.22)


func play_death(kind: String = "body") -> void:
	_is_dead = true
	_oneshot_timer = 1.0
	match kind:
		"head", "HEAD":
			play(ANIM_DEATH_HEAD, 0.04)
		"back", "BACK":
			play(ANIM_DEATH_BACK, 0.05)
		"explode", "explosion", "EXPLODE":
			play(ANIM_DEATH_EXPLODE, 0.03)
		_:
			play(ANIM_DEATH, 0.08)


func set_cover_pose(pose: String) -> void:
	_cover_pose = pose


func set_locomotion(moving: bool, running: bool, suspicious: bool = false, alert: bool = false) -> void:
	if _is_dead or _oneshot_timer > 0.0:
		return
	if _cover_pose == "peek":
		play(ANIM_PEEK, 0.16)
		return
	if _cover_pose == "cover":
		play(ANIM_COVER, 0.16)
		return
	if not moving:
		if suspicious:
			play(ANIM_LOOK_AROUND, 0.24)
		elif running:
			play(ANIM_AIM, 0.16)
		elif alert:
			play(ANIM_ALERT, 0.18)
		else:
			play(ANIM_IDLE, 0.22)
	elif running:
		play(ANIM_RUN, 0.16)
	elif suspicious:
		play(ANIM_INVESTIGATE, 0.20)
	elif alert:
		play(ANIM_WALK, 0.18)
	else:
		play(ANIM_WALK, 0.20)


func play_radio() -> void:
	if _is_dead:
		return
	_oneshot_timer = 0.85
	play(ANIM_RADIO, 0.12)


func play_alarm_press() -> void:
	if _is_dead:
		return
	_oneshot_timer = 0.55
	play(ANIM_ALARM_PRESS, 0.08)


func play_takedown(from_behind: bool) -> void:
	_is_dead = true
	_oneshot_timer = 0.65
	play(ANIM_TAKEDOWN_BACK if from_behind else ANIM_TAKEDOWN_FRONT, 0.05)


func play_shoot() -> void:
	if _is_dead:
		return
	_oneshot_timer = 0.24
	play(ANIM_SHOOT, 0.04)
	if is_instance_valid(_rifle_flash):
		_rifle_flash.visible = true
		_rifle_flash.rotation.z = randf() * TAU
		_flash_timer = 0.07


func play_hit() -> void:
	if _is_dead:
		return
	_oneshot_timer = 0.24
	play(ANIM_HIT, 0.03)


func set_sniper_look(enabled: bool) -> void:
	if is_instance_valid(_right_arm):
		var kit := _right_arm.get_node_or_null("Forearm/GuardRifle/SniperKit") as Node3D
		if is_instance_valid(kit):
			kit.visible = enabled


func _show_gear(gear_name: String, on: bool) -> void:
	var node: Node = _gear.get(gear_name)
	if node is Node3D:
		(node as Node3D).visible = on


func _tint_meshes(meshes: Array[MeshInstance3D], color: Color) -> void:
	var mat := ProcMesh.mat(color, 0.84, 0.02)
	for mi in meshes:
		if is_instance_valid(mi):
			mi.material_override = mat


func apply_role_look(role: String, heavy: bool = false, officer: bool = false, dog: bool = false) -> void:
	## Cult militia kits. Head stays on the y=1.70 hit sphere; gear only shows or hides.
	if dog:
		_build_dog_mesh()
		return
	if not is_instance_valid(_rig):
		return
	for gear_name in ["Cap", "Helmet", "Beret", "Boonie", "Headset", "HeavyPlate", "Ghillie", "Boards", "Armband"]:
		_show_gear(gear_name, false)
	var jacket := Color(0.30, 0.36, 0.24)
	var pants := Color(0.27, 0.25, 0.21)
	var accent := Color(0.55, 0.32, 0.16)
	if is_instance_valid(_torso):
		_torso.scale = Vector3.ONE
	if heavy:
		jacket = Color(0.22, 0.23, 0.27)
		pants = Color(0.18, 0.18, 0.20)
		accent = Color(0.45, 0.42, 0.55)
		_show_gear("Helmet", true)
		_show_gear("HeavyPlate", true)
		_show_gear("Headset", true)
		if is_instance_valid(_torso):
			_torso.scale = Vector3(1.12, 1.04, 1.14)
	elif role == "commander" or officer:
		jacket = Color(0.52, 0.44, 0.32)
		pants = Color(0.24, 0.22, 0.18)
		accent = Color(0.72, 0.18, 0.16)
		_show_gear("Beret", true)
		_show_gear("Boards", true)
	elif role == "handler":
		jacket = Color(0.26, 0.34, 0.22)
		accent = Color(0.75, 0.22, 0.16)
		_show_gear("Headset", true)
		_show_gear("Armband", true)
		_show_gear("Cap", true)
	elif role == "sniper":
		jacket = Color(0.20, 0.30, 0.16)
		pants = Color(0.18, 0.24, 0.14)
		accent = Color(0.30, 0.42, 0.18)
		_show_gear("Boonie", true)
		_show_gear("Ghillie", true)
	elif role == "sentry":
		jacket = Color(0.34, 0.32, 0.24)
		_show_gear("Cap", true)
		_show_gear("Headset", true)
	elif role == "interior":
		jacket = Color(0.40, 0.36, 0.30)
		_show_gear("Cap", true)
	else:
		_show_gear("Cap", true)
		_show_gear("Headset", true)
	_tint_meshes(_cloth, jacket)
	_tint_meshes(_pants, pants)
	set_placeholder_color(accent)


func _build_dog_mesh() -> void:
	if get_node_or_null("DogRig") != null:
		if is_instance_valid(_rig):
			_rig.visible = false
		return
	if is_instance_valid(_rig):
		_rig.visible = false
	var fur := Color(0.36, 0.28, 0.18)
	var dark := Color(0.16, 0.13, 0.11)
	var dog := Node3D.new()
	dog.name = "DogRig"
	add_child(dog)
	var body := ProcMesh.add_part(dog, ProcMesh.capsule_mesh(0.14, 0.62, fur, 0.9, 0.0), Vector3(0, 0.42, 0))
	body.rotation_degrees = Vector3(90, 0, 0)
	ProcMesh.add_part(dog, ProcMesh.sphere_mesh(0.12, fur, 0.9, 0.0), Vector3(0, 0.52, -0.32))
	var snout := ProcMesh.add_part(dog, ProcMesh.capsule_mesh(0.045, 0.16, dark, 0.85, 0.0), Vector3(0, 0.48, -0.44))
	snout.rotation_degrees = Vector3(90, 0, 0)
	ProcMesh.add_part(dog, ProcMesh.sphere_mesh(0.035, fur.darkened(0.1), 0.9, 0.0), Vector3(-0.07, 0.62, -0.30))
	ProcMesh.add_part(dog, ProcMesh.sphere_mesh(0.035, fur.darkened(0.1), 0.9, 0.0), Vector3(0.07, 0.62, -0.30))
	ProcMesh.add_part(dog, ProcMesh.sphere_mesh(0.015, Color(0.05, 0.05, 0.05), 0.3, 0.0), Vector3(-0.04, 0.56, -0.40))
	ProcMesh.add_part(dog, ProcMesh.sphere_mesh(0.015, Color(0.05, 0.05, 0.05), 0.3, 0.0), Vector3(0.04, 0.56, -0.40))
	for xz in [Vector2(-0.10, 0.16), Vector2(0.10, 0.16), Vector2(-0.10, -0.16), Vector2(0.10, -0.16)]:
		ProcMesh.add_part(dog, ProcMesh.capsule_mesh(0.035, 0.28, dark, 0.85, 0.0), Vector3(xz.x, 0.16, xz.y))
	var tail := ProcMesh.add_part(dog, ProcMesh.capsule_mesh(0.02, 0.22, fur, 0.9, 0.0), Vector3(0, 0.52, 0.32))
	tail.rotation_degrees = Vector3(50, 0, 0)


func _wear_rig_materials(root: Node) -> void:
	## High tier: cloth / kit gets wear + rim. Accents stay state-coloured later.
	if root == null or GraphicsQuality == null or GraphicsQuality.level < GraphicsQuality.LEVEL_HIGH:
		return
	for n in root.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if mi == null or mi.name.ends_with("Accent"):
			continue
		var sm := mi.material_override as StandardMaterial3D
		if sm == null or sm.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED:
			continue
		mi.material_override = GraphicsQuality.make_surface_material(sm.albedo_color, sm.roughness, sm.metallic)


func set_placeholder_color(color: Color) -> void:
	## Update militia accent strips (chest stripe + face mask) to keep AI state readable
	## while preserving realistic humanoid clothing colors.
	var m := ProcMesh.mat(color, 0.72, 0.08)
	for mesh_inst in _accent_meshes:
		if is_instance_valid(mesh_inst):
			mesh_inst.material_override = m


func _on_anim_finished(anim_name: StringName) -> void:
	animation_finished.emit(anim_name)


func _has_anim(anim_name: StringName) -> bool:
	if not is_instance_valid(anim_player):
		return false
	if not anim_player.has_animation_library(LIB_NAME):
		return false
	var lib := anim_player.get_animation_library(LIB_NAME)
	return lib != null and lib.has_animation(anim_name)
