extends Node3D
class_name GuardVisual
## Articulated low-poly humanoid guard with procedural AnimationPlayer clips:
## idle, walk, run, shoot, hit, death + rifle muzzle flash.
## Proportions align directly with Guard/HitZones (Head y=1.70, Torso y=1.15, Limbs y=0.42 + arms).

signal animation_finished(anim_name: StringName)

@onready var placeholder_mesh: MeshInstance3D = get_node_or_null("PlaceholderMesh") as MeshInstance3D
@onready var anim_player: AnimationPlayer = $AnimationPlayer

const ANIM_IDLE := &"idle"
const ANIM_WALK := &"walk"
const ANIM_RUN := &"run"
const ANIM_SHOOT := &"shoot"
const ANIM_HIT := &"hit"
const ANIM_DEATH := &"death"
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


func _build_humanoid() -> void:
	if get_node_or_null("Rig"):
		return
	var jacket := Color(0.28, 0.31, 0.25)
	var pants := Color(0.24, 0.23, 0.20)
	var vest := Color(0.16, 0.17, 0.18)
	var boot := Color(0.11, 0.10, 0.09)
	var skin := Color(0.76, 0.60, 0.48)
	var helmet := Color(0.20, 0.22, 0.19)
	var goggles := Color(0.08, 0.10, 0.12)
	var gun := Color(0.14, 0.15, 0.17)
	var accent := Color(0.72, 0.22, 0.16)

	_rig = Node3D.new()
	_rig.name = "Rig"
	add_child(_rig)

	# Pelvis pivot at y=0.88 (legs extend down to y=0.0, torso extends up to y=1.48)
	_pelvis = Node3D.new()
	_pelvis.name = "Pelvis"
	_pelvis.position = Vector3(0, 0.88, 0)
	_rig.add_child(_pelvis)
	ProcMesh.add_part(_pelvis, ProcMesh.box_mesh(Vector3(0.36, 0.16, 0.24), pants), Vector3(0, 0.0, 0))
	ProcMesh.add_part(_pelvis, ProcMesh.box_mesh(Vector3(0.39, 0.07, 0.26), boot), Vector3(0, 0.06, 0))

	# Torso pivot
	_torso = Node3D.new()
	_torso.name = "Torso"
	_torso.position = Vector3(0, 0.06, 0)
	_pelvis.add_child(_torso)
	# Jacket chest (world y ~ 0.94..1.48)
	ProcMesh.add_part(_torso, ProcMesh.box_mesh(Vector3(0.42, 0.50, 0.25), jacket), Vector3(0, 0.27, 0))
	# Plate carrier tactical vest + mag pouches
	ProcMesh.add_part(_torso, ProcMesh.box_mesh(Vector3(0.45, 0.38, 0.29), vest, 0.78, 0.12), Vector3(0, 0.27, 0))
	ProcMesh.add_part(_torso, ProcMesh.box_mesh(Vector3(0.10, 0.14, 0.06), vest), Vector3(-0.10, 0.18, -0.16))
	ProcMesh.add_part(_torso, ProcMesh.box_mesh(Vector3(0.10, 0.14, 0.06), vest), Vector3(0.0, 0.18, -0.16))
	ProcMesh.add_part(_torso, ProcMesh.box_mesh(Vector3(0.10, 0.14, 0.06), vest), Vector3(0.10, 0.18, -0.16))
	# Militia bandana/chest stripe accent (reflects AI alert state clearly)
	var chest_badge := ProcMesh.box_mesh(Vector3(0.46, 0.07, 0.30), accent, 0.65, 0.05)
	ProcMesh.add_part(_torso, chest_badge, Vector3(0, 0.45, 0), Vector3.ZERO, "ChestAccent")
	_accent_meshes.append(chest_badge)
	# Back radio pack + antenna
	ProcMesh.add_part(_torso, ProcMesh.box_mesh(Vector3(0.24, 0.32, 0.13), vest), Vector3(0, 0.28, 0.19))
	ProcMesh.add_part(_torso, ProcMesh.cylinder_mesh(0.008, 0.34, gun, 0.4, 0.6, 6), Vector3(-0.08, 0.56, 0.22))

	# Head pivot (world y = 1.50..1.92, center 1.70 → aligns with HitZones/Head y=1.70)
	_head = Node3D.new()
	_head.name = "Head"
	_head.position = Vector3(0, 0.54, 0)
	_torso.add_child(_head)
	ProcMesh.add_part(_head, ProcMesh.cylinder_mesh(0.065, 0.10, skin, 0.85, 0.0, 8), Vector3(0, 0.05, 0))
	ProcMesh.add_part(_head, ProcMesh.box_mesh(Vector3(0.21, 0.24, 0.22), skin, 0.82, 0.02), Vector3(0, 0.20, 0))
	# Dark face mask / bandana across lower face
	var mask := ProcMesh.box_mesh(Vector3(0.22, 0.10, 0.23), accent, 0.85, 0.0)
	ProcMesh.add_part(_head, mask, Vector3(0, 0.13, -0.005), Vector3.ZERO, "MaskAccent")
	_accent_meshes.append(mask)
	# Tactical helmet + brim + dark goggles
	ProcMesh.add_part(_head, ProcMesh.sphere_mesh(0.155, helmet, 0.68, 0.18), Vector3(0, 0.28, 0.005))
	ProcMesh.add_part(_head, ProcMesh.box_mesh(Vector3(0.24, 0.04, 0.12), helmet, 0.68, 0.18), Vector3(0, 0.27, -0.10))
	ProcMesh.add_part(_head, ProcMesh.box_mesh(Vector3(0.22, 0.06, 0.05), goggles, 0.25, 0.45), Vector3(0, 0.22, -0.115))

	# Left arm (support arm holding rifle handguard)
	_left_arm = Node3D.new()
	_left_arm.name = "LeftArm"
	_left_arm.position = Vector3(-0.27, 0.44, 0)
	_torso.add_child(_left_arm)
	ProcMesh.add_part(_left_arm, ProcMesh.box_mesh(Vector3(0.13, 0.28, 0.13), jacket), Vector3(0, -0.12, -0.04), Vector3(24, 0, 8))
	ProcMesh.add_part(_left_arm, ProcMesh.box_mesh(Vector3(0.11, 0.26, 0.11), jacket), Vector3(0.06, -0.26, -0.18), Vector3(72, -18, 0))
	ProcMesh.add_part(_left_arm, ProcMesh.box_mesh(Vector3(0.09, 0.09, 0.11), boot), Vector3(0.12, -0.28, -0.32))

	# Right arm + guard assault rifle
	_right_arm = Node3D.new()
	_right_arm.name = "RightArm"
	_right_arm.position = Vector3(0.27, 0.44, 0)
	_torso.add_child(_right_arm)
	ProcMesh.add_part(_right_arm, ProcMesh.box_mesh(Vector3(0.13, 0.28, 0.13), jacket), Vector3(0, -0.12, -0.04), Vector3(26, 0, -6))
	ProcMesh.add_part(_right_arm, ProcMesh.box_mesh(Vector3(0.11, 0.26, 0.11), jacket), Vector3(-0.04, -0.26, -0.18), Vector3(78, 12, 0))
	ProcMesh.add_part(_right_arm, ProcMesh.box_mesh(Vector3(0.09, 0.09, 0.11), boot), Vector3(-0.06, -0.27, -0.30))

	# Guard rifle held in right arm
	var rifle := Node3D.new()
	rifle.name = "GuardRifle"
	rifle.position = Vector3(-0.08, -0.25, -0.32)
	_right_arm.add_child(rifle)
	ProcMesh.add_part(rifle, ProcMesh.box_mesh(Vector3(0.06, 0.08, 0.46), gun, 0.45, 0.55), Vector3(0, 0, -0.06))
	ProcMesh.add_part(rifle, ProcMesh.cylinder_mesh(0.014, 0.26, gun, 0.35, 0.7, 6), Vector3(0, 0.01, -0.40), Vector3(90, 0, 0))
	ProcMesh.add_part(rifle, ProcMesh.box_mesh(Vector3(0.04, 0.14, 0.07), vest), Vector3(0, -0.09, -0.10), Vector3(12, 0, 0))
	ProcMesh.add_part(rifle, ProcMesh.box_mesh(Vector3(0.05, 0.09, 0.20), boot), Vector3(0, -0.01, 0.24))
	# Sniper optic + subtle scope glint (hidden unless sniper guard)
	var sniper_kit := Node3D.new()
	sniper_kit.name = "SniperKit"
	sniper_kit.visible = false
	ProcMesh.add_part(sniper_kit, ProcMesh.cylinder_mesh(0.022, 0.24, gun, 0.35, 0.65, 8), Vector3(0, 0.065, -0.08), Vector3(90, 0, 0))
	ProcMesh.add_part(sniper_kit, ProcMesh.cylinder_mesh(0.014, 0.24, gun, 0.35, 0.7, 6), Vector3(0, 0.01, -0.60), Vector3(90, 0, 0))
	var glint := ProcMesh.sphere_mesh(0.045, Color(1.0, 0.96, 0.75))
	glint.material_override = ProcMesh.emissive(Color(1.0, 0.95, 0.7), 2.4)
	ProcMesh.add_part(sniper_kit, glint, Vector3(0, 0.065, -0.22))
	rifle.add_child(sniper_kit)

	_rifle_flash = Node3D.new()
	_rifle_flash.name = "MuzzleFlash"
	_rifle_flash.position = Vector3(0, 0.01, -0.56)
	var mf_mat := ProcMesh.unshaded(Color(1.0, 0.78, 0.2, 0.95))
	for deg in [0.0, 60.0, 120.0]:
		var f := ProcMesh.box_mesh(Vector3(0.24, 0.05, 0.04), Color(1.0, 0.8, 0.25))
		f.material_override = mf_mat
		ProcMesh.add_part(_rifle_flash, f, Vector3.ZERO, Vector3(0, 0, deg))
	_rifle_flash.visible = false
	rifle.add_child(_rifle_flash)

	# Left & right legs (world y = 0.0 .. 0.84 → aligns with HitZones/Limbs y=0.42)
	_left_leg = Node3D.new()
	_left_leg.name = "LeftLeg"
	_left_leg.position = Vector3(-0.11, -0.04, 0)
	_pelvis.add_child(_left_leg)
	ProcMesh.add_part(_left_leg, ProcMesh.box_mesh(Vector3(0.15, 0.42, 0.16), pants), Vector3(0, -0.21, 0))
	ProcMesh.add_part(_left_leg, ProcMesh.box_mesh(Vector3(0.13, 0.36, 0.14), pants), Vector3(0, -0.58, 0))
	ProcMesh.add_part(_left_leg, ProcMesh.box_mesh(Vector3(0.14, 0.12, 0.23), boot), Vector3(0, -0.78, -0.03))

	_right_leg = Node3D.new()
	_right_leg.name = "RightLeg"
	_right_leg.position = Vector3(0.11, -0.04, 0)
	_pelvis.add_child(_right_leg)
	ProcMesh.add_part(_right_leg, ProcMesh.box_mesh(Vector3(0.15, 0.42, 0.16), pants), Vector3(0, -0.21, 0))
	ProcMesh.add_part(_right_leg, ProcMesh.box_mesh(Vector3(0.13, 0.36, 0.14), pants), Vector3(0, -0.58, 0))
	ProcMesh.add_part(_right_leg, ProcMesh.box_mesh(Vector3(0.14, 0.12, 0.23), boot), Vector3(0, -0.78, -0.03))


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
		_add_pos_track(a, "Rig/Pelvis", [[0.0, Vector3(0, 0.88, 0)], [0.8, Vector3(0, 0.90, 0)], [1.6, Vector3(0, 0.88, 0)]])
		_add_rot_track(a, "Rig/Pelvis", [[0.0, Vector3.ZERO], [1.6, Vector3.ZERO]])
		_add_rot_track(a, "Rig/Pelvis/Torso", [[0.0, Vector3(0, 0, 0)], [0.8, Vector3(2, 0, 0)], [1.6, Vector3(0, 0, 0)]])
		_add_rot_track(a, "Rig/Pelvis/Torso/Head", [[0.0, Vector3(0, -6, 0)], [0.8, Vector3(0, 6, 0)], [1.6, Vector3(0, -6, 0)]])
		_add_rot_track(a, "Rig/Pelvis/LeftLeg", [[0.0, Vector3.ZERO], [1.6, Vector3.ZERO]])
		_add_rot_track(a, "Rig/Pelvis/RightLeg", [[0.0, Vector3.ZERO], [1.6, Vector3.ZERO]])
		_add_rot_track(a, "Rig/Pelvis/Torso/RightArm", [[0.0, Vector3.ZERO], [1.6, Vector3.ZERO]])
		_add_rot_track(a, "Rig/Pelvis/Torso/LeftArm", [[0.0, Vector3.ZERO], [1.6, Vector3.ZERO]])
		lib.add_animation(ANIM_IDLE, a)

	# 2. WALK (patrol stride)
	if not lib.has_animation(ANIM_WALK):
		var a := Animation.new()
		a.length = 0.8
		a.loop_mode = Animation.LOOP_LINEAR
		_add_pos_track(a, "Rig/Pelvis", [[0.0, Vector3(0, 0.88, 0)], [0.2, Vector3(0, 0.92, 0)], [0.4, Vector3(0, 0.88, 0)], [0.6, Vector3(0, 0.92, 0)], [0.8, Vector3(0, 0.88, 0)]])
		_add_rot_track(a, "Rig/Pelvis", [[0.0, Vector3.ZERO], [0.8, Vector3.ZERO]])
		_add_rot_track(a, "Rig/Pelvis/Torso", [[0.0, Vector3(-4, -3, 0)], [0.4, Vector3(-4, 3, 0)], [0.8, Vector3(-4, -3, 0)]])
		_add_rot_track(a, "Rig/Pelvis/LeftLeg", [[0.0, Vector3(24, 0, 0)], [0.4, Vector3(-24, 0, 0)], [0.8, Vector3(24, 0, 0)]])
		_add_rot_track(a, "Rig/Pelvis/RightLeg", [[0.0, Vector3(-24, 0, 0)], [0.4, Vector3(24, 0, 0)], [0.8, Vector3(-24, 0, 0)]])
		_add_rot_track(a, "Rig/Pelvis/Torso/RightArm", [[0.0, Vector3(-6, 0, 0)], [0.4, Vector3(4, 0, 0)], [0.8, Vector3(-6, 0, 0)]])
		_add_rot_track(a, "Rig/Pelvis/Torso/LeftArm", [[0.0, Vector3(4, 0, 0)], [0.4, Vector3(-6, 0, 0)], [0.8, Vector3(4, 0, 0)]])
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
		_add_rot_track(a, "Rig/Pelvis/Torso/RightArm", [[0.0, Vector3(16, 0, 0)], [0.26, Vector3(24, 0, 0)], [0.52, Vector3(16, 0, 0)]])
		_add_rot_track(a, "Rig/Pelvis/Torso/LeftArm", [[0.0, Vector3(24, 0, 0)], [0.26, Vector3(16, 0, 0)], [0.52, Vector3(24, 0, 0)]])
		lib.add_animation(ANIM_RUN, a)

	# 4. SHOOT (aimed rifle recoil kick)
	if not lib.has_animation(ANIM_SHOOT):
		var a := Animation.new()
		a.length = 0.24
		a.loop_mode = Animation.LOOP_NONE
		_add_rot_track(a, "Rig/Pelvis/Torso", [[0.0, Vector3(-4, 0, 0)], [0.06, Vector3(8, 0, 0)], [0.24, Vector3(-2, 0, 0)]])
		_add_rot_track(a, "Rig/Pelvis/Torso/RightArm", [[0.0, Vector3(26, 0, 0)], [0.06, Vector3(40, 0, 0)], [0.24, Vector3(24, 0, 0)]])
		_add_rot_track(a, "Rig/Pelvis/Torso/LeftArm", [[0.0, Vector3(26, 0, 0)], [0.06, Vector3(38, 0, 0)], [0.24, Vector3(24, 0, 0)]])
		lib.add_animation(ANIM_SHOOT, a)

	# 5. HIT (flinch backward on damage)
	if not lib.has_animation(ANIM_HIT):
		var a := Animation.new()
		a.length = 0.24
		a.loop_mode = Animation.LOOP_NONE
		_add_rot_track(a, "Rig/Pelvis/Torso", [[0.0, Vector3.ZERO], [0.07, Vector3(24, -10, 6)], [0.24, Vector3.ZERO]])
		_add_rot_track(a, "Rig/Pelvis/Torso/Head", [[0.0, Vector3.ZERO], [0.07, Vector3(22, 12, 0)], [0.24, Vector3.ZERO]])
		lib.add_animation(ANIM_HIT, a)

	# 6. DEATH (collapse backward to ground)
	if not lib.has_animation(ANIM_DEATH):
		var a := Animation.new()
		a.length = 0.7
		a.loop_mode = Animation.LOOP_NONE
		_add_pos_track(a, "Rig/Pelvis", [[0.0, Vector3(0, 0.88, 0)], [0.35, Vector3(0, 0.45, 0.15)], [0.7, Vector3(0, 0.18, 0.35)]])
		_add_rot_track(a, "Rig/Pelvis", [[0.0, Vector3.ZERO], [0.35, Vector3(52, 0, 8)], [0.7, Vector3(86, 0, 12)]])
		_add_rot_track(a, "Rig/Pelvis/Torso/RightArm", [[0.0, Vector3.ZERO], [0.7, Vector3(-18, 0, -45)]])
		_add_rot_track(a, "Rig/Pelvis/Torso/LeftArm", [[0.0, Vector3.ZERO], [0.7, Vector3(-14, 0, 40)]])
		_add_rot_track(a, "Rig/Pelvis/LeftLeg", [[0.0, Vector3.ZERO], [0.7, Vector3(-12, 0, 14)]])
		_add_rot_track(a, "Rig/Pelvis/RightLeg", [[0.0, Vector3.ZERO], [0.7, Vector3(10, 0, -12)]])
		lib.add_animation(ANIM_DEATH, a)


func play(anim_name: StringName, custom_blend: float = 0.12) -> void:
	if not is_instance_valid(anim_player):
		return
	if _is_dead and anim_name != ANIM_DEATH:
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
		"PATROL", "SUSPICIOUS":
			play(ANIM_WALK)
		"ALERT", "COMBAT":
			play(ANIM_RUN)
		"DEAD":
			_is_dead = true
			play(ANIM_DEATH, 0.05)
		_:
			play(ANIM_IDLE)


func set_locomotion(moving: bool, running: bool) -> void:
	if _is_dead or _oneshot_timer > 0.0:
		return
	if not moving:
		play(ANIM_IDLE, 0.15)
	elif running:
		play(ANIM_RUN, 0.12)
	else:
		play(ANIM_WALK, 0.15)


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
		var kit := _right_arm.get_node_or_null("GuardRifle/SniperKit") as Node3D
		if is_instance_valid(kit):
			kit.visible = enabled


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
