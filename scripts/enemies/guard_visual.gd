extends Node3D
class_name GuardVisual
## Skinned Quaternius militia (CC0 universal humanoid) driven by an AnimationTree.
## Clips are a subset of the Universal Animation Library. The rifle is parented to
## hand_r and the left hand reaches the handguard while a gun pose is active.

signal animation_finished(anim_name: StringName)

const ACTOR_SCENE := "res://assets/characters/militia_male.glb"

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

## Short names the AI and the smoke test already use, mapped onto real clips.
const CLIP := {
	"idle": "Idle",
	"walk": "Walk",
	"run": "Sprint",
	"shoot": "Pistol_Shoot",
	"hit": "Hit_Chest",
	"death": "Death01",
	"death_head": "Death01",
	"death_back": "Death01",
	"death_explode": "Death01",
	"investigate": "Crouch_Fwd",
	"look_around": "Interact",
	"radio": "Interact",
	"alarm_press": "Interact",
	"takedown_back": "Death01",
	"takedown_front": "Hit_Chest",
	"crouch": "Crouch_Idle",
	"aim": "Pistol_Aim_Neutral",
	"alert": "Pistol_Idle",
	"cover": "Crouch_Idle",
	"peek": "Pistol_Aim_Up",
	"reload": "Pistol_Reload",
	"throw": "Punch_Jab",
	"signal": "Interact",
	"jog": "Jog_Fwd",
	"strafe": "Jog_Fwd",
}

const ONESHOT := {
	"shoot": "shoot",
	"hit": "hit",
	"death": "death",
	"death_head": "death",
	"death_back": "death",
	"death_explode": "death",
	"look_around": "signal",
	"radio": "signal",
	"alarm_press": "signal",
	"takedown_back": "death",
	"takedown_front": "hit",
	"throw": "throw",
	"signal": "signal",
	"reload": "reload",
}

const LOOP_CLIPS := [
	"Idle", "Walk", "Jog_Fwd", "Sprint",
	"Crouch_Idle", "Crouch_Fwd", "Pistol_Idle",
	"Pistol_Aim_Neutral", "Pistol_Aim_Up",
]
const UPPER_HINTS := [
	"spine_02", "spine_03", "neck_01", "Head",
	"clavicle_", "upperarm_", "lowerarm_", "hand_",
	"index_", "middle_", "pinky_", "ring_", "thumb_",
]

var anim_player: AnimationPlayer
var _tree: AnimationTree
var _skeleton: Skeleton3D
var _actor: Node3D
var _body: MeshInstance3D
var _cloth_surface := -1
var _rifle: Node3D
var _rifle_flash: Node3D
var _sniper_kit: Node3D
var _hold_rifle := false
var _arm_upper := -1
var _arm_lower := -1
var _arm_hand := -1
var _arm_upper_len := 0.25
var _arm_lower_len := 0.24
var _arm_upper_r := -1
var _arm_lower_r := -1
var _arm_hand_r := -1
var _arm_upper_r_len := 0.25
var _arm_lower_r_len := 0.24
var _gear: Dictionary = {}
var _attachments: Array[BoneAttachment3D] = []
var _flash_timer := 0.0
var _oneshot_timer := 0.0
var _look_cooldown := 0.0
var _is_dead := false
var _cover_pose := ""
var _ready_weight := 1.0
var _aim_weight := 0.0
var _peek_weight := 0.0
var _crouch_weight := 0.0
var _speed := 0.0
var _tree_state := ""


func _ready() -> void:
	_spawn_actor()
	if anim_player == null or _skeleton == null:
		push_error("GuardVisual: militia glb did not produce a skeleton")
		return
	_force_loop_modes()
	_paint_defaults()
	_attach_rifle()
	_attach_gear()
	_build_tree()
	align_hit_zones()
	_apply_blends()
	# Run after AnimationTree and SkeletonIK so grips land on the posed hands.
	process_priority = 100


func _process(delta: float) -> void:
	if _look_cooldown > 0.0:
		_look_cooldown = maxf(0.0, _look_cooldown - delta)
	if _flash_timer > 0.0:
		_flash_timer -= delta
		if _flash_timer <= 0.0 and is_instance_valid(_rifle_flash):
			_rifle_flash.visible = false
	if _oneshot_timer > 0.0:
		_oneshot_timer = maxf(0.0, _oneshot_timer - delta)
		if _oneshot_timer <= 0.0 and not _is_dead:
			_travel("loco")
	_pose_rifle_arms()
	_sync_attachments()
	_solve_left_hand()
	_curl_grip_fingers()


func _spawn_actor() -> void:
	var packed := load(ACTOR_SCENE) as PackedScene
	if packed == null:
		return
	_actor = packed.instantiate()
	_actor.name = "Militia"
	# The Quaternius mesh looks along +Z. Godot characters face -Z, so turn the actor around.
	_actor.rotation.y = PI
	add_child(_actor)
	anim_player = _actor.find_child("AnimationPlayer", true, false) as AnimationPlayer
	_skeleton = _actor.find_child("Skeleton3D", true, false) as Skeleton3D
	for n in _actor.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if mi.name.find("SuperHero") >= 0 or mi.name.find("Male") >= 0:
			_body = mi


func _force_loop_modes() -> void:
	for clip_name in LOOP_CLIPS:
		if anim_player.has_animation(clip_name):
			anim_player.get_animation(clip_name).loop_mode = Animation.LOOP_LINEAR
	for clip_name in ["Pistol_Shoot", "Pistol_Reload", "Hit_Chest", "Hit_Head", "Death01", "Interact", "Punch_Jab"]:
		if anim_player.has_animation(clip_name):
			anim_player.get_animation(clip_name).loop_mode = Animation.LOOP_NONE


func _uses_authored_materials() -> bool:
	if _actor == null:
		return false
	for n in _actor.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		var label := str(mi.name)
		if label.find("Peasant") >= 0 or label.find("HeadSkin") >= 0 or label.find("Hair") >= 0:
			return true
		if mi.mesh == null:
			continue
		for i in mi.mesh.get_surface_count():
			var mat := mi.mesh.surface_get_material(i)
			if mat is BaseMaterial3D and (mat as BaseMaterial3D).albedo_texture != null:
				return true
	return false


func _paint_defaults() -> void:
	if _uses_authored_materials():
		return
	_retint_named("Eyes", Color(0.12, 0.09, 0.08), 0.3)
	_retint_named("Eyebrows", Color(0.16, 0.1, 0.07), 0.75)
	if _body == null or _body.mesh == null:
		return
	for i in _body.mesh.get_surface_count():
		var mat := _body.mesh.surface_get_material(i)
		var label := str(mat.resource_name) if mat else ""
		if label.find("Cloth") >= 0:
			_cloth_surface = i
	if _cloth_surface < 0 and _body.mesh.get_surface_count() > 1:
		_cloth_surface = 1
	_tint_cloth(Color(0.28, 0.34, 0.22))
	_tint_named_surface("Skin", Color(0.46, 0.31, 0.23), 0.72)
	_tint_named_surface("Boots", Color(0.07, 0.06, 0.055), 0.55)
	_emphasize_face()


func _retint_named(node_name: String, color: Color, rough: float) -> void:
	if _actor == null:
		return
	var node := _actor.find_child(node_name, true, false) as MeshInstance3D
	if node == null:
		return
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = rough
	node.material_override = mat


func _tint_named_surface(label_part: String, color: Color, rough: float) -> void:
	if _body == null or _body.mesh == null:
		return
	for i in _body.mesh.get_surface_count():
		var mat := _body.mesh.surface_get_material(i)
		var label := str(mat.resource_name) if mat else ""
		if label.find(label_part) < 0:
			continue
		var over := StandardMaterial3D.new()
		over.albedo_color = color
		over.roughness = rough
		_body.set_surface_override_material(i, over)


func _emphasize_face() -> void:
	if _actor == null:
		return
	var eyes := _actor.find_child("Eyes", true, false) as MeshInstance3D
	if eyes:
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.04, 0.03, 0.03)
		mat.roughness = 0.3
		eyes.material_override = mat
	var brows := _actor.find_child("Eyebrows", true, false) as MeshInstance3D
	if brows:
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.1, 0.07, 0.05)
		mat.roughness = 0.8
		brows.material_override = mat


func _tint_cloth(color: Color) -> void:
	if _uses_authored_materials():
		return
	if _body == null or _cloth_surface < 0:
		return
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.82
	_body.set_surface_override_material(_cloth_surface, mat)


func _clip_node(clip_name: String) -> AnimationNodeAnimation:
	var node := AnimationNodeAnimation.new()
	node.animation = StringName(clip_name)
	return node


func _build_tree() -> void:
	var loco := AnimationNodeBlendTree.new()
	var stand := AnimationNodeBlendSpace1D.new()
	stand.add_blend_point(_clip_node("Idle"), 0.0)
	stand.add_blend_point(_clip_node("Walk"), 0.38)
	stand.add_blend_point(_clip_node("Jog_Fwd"), 0.7)
	stand.add_blend_point(_clip_node("Sprint"), 1.0)
	var crouch := AnimationNodeBlendSpace1D.new()
	crouch.add_blend_point(_clip_node("Crouch_Idle"), 0.0)
	crouch.add_blend_point(_clip_node("Crouch_Fwd"), 1.0)
	var stance := AnimationNodeBlend2.new()
	var ready := AnimationNodeBlend2.new()
	var aim := AnimationNodeBlend2.new()
	var peek := AnimationNodeBlend2.new()
	_filter_upper(ready)
	_filter_upper(aim)
	_filter_upper(peek)
	loco.add_node("stand", stand, Vector2(0, 80))
	loco.add_node("crouch", crouch, Vector2(0, 180))
	loco.add_node("stance", stance, Vector2(200, 120))
	loco.add_node("ready_pose", _clip_node("Pistol_Idle"), Vector2(200, 0))
	loco.add_node("ready", ready, Vector2(400, 80))
	loco.add_node("aim_pose", _clip_node("Pistol_Aim_Neutral"), Vector2(400, 200))
	loco.add_node("aim", aim, Vector2(600, 120))
	loco.add_node("peek_pose", _clip_node("Pistol_Aim_Up"), Vector2(600, 260))
	loco.add_node("peek", peek, Vector2(800, 160))
	loco.connect_node("stance", 0, "stand")
	loco.connect_node("stance", 1, "crouch")
	loco.connect_node("ready", 0, "stance")
	loco.connect_node("ready", 1, "ready_pose")
	loco.connect_node("aim", 0, "ready")
	loco.connect_node("aim", 1, "aim_pose")
	loco.connect_node("peek", 0, "aim")
	loco.connect_node("peek", 1, "peek_pose")
	loco.connect_node("output", 0, "peek")

	var machine := AnimationNodeStateMachine.new()
	machine.add_node("loco", loco, Vector2(0, 0))
	_add_oneshot(machine, "shoot", "Pistol_Shoot", Vector2(280, -80))
	_add_oneshot(machine, "reload", "Pistol_Reload", Vector2(280, 40))
	_add_oneshot(machine, "hit", "Hit_Chest", Vector2(280, 160))
	_add_oneshot(machine, "throw", "Punch_Jab", Vector2(280, 280))
	_add_oneshot(machine, "signal", "Interact", Vector2(480, -40))
	machine.add_node("death", _clip_node("Death01"), Vector2(480, 200))
	var into_death := AnimationNodeStateMachineTransition.new()
	into_death.xfade_time = 0.12
	machine.add_transition("loco", "death", into_death)

	_tree = AnimationTree.new()
	_tree.name = "MilitiaTree"
	add_child(_tree)
	_tree.anim_player = _tree.get_path_to(anim_player)
	_tree.tree_root = machine
	_tree.active = true
	_travel("loco")


func _add_oneshot(machine: AnimationNodeStateMachine, state_name: String, clip_name: String, pos: Vector2) -> void:
	machine.add_node(state_name, _clip_node(clip_name), pos)
	var go := AnimationNodeStateMachineTransition.new()
	go.xfade_time = 0.08
	machine.add_transition("loco", state_name, go)
	var back := AnimationNodeStateMachineTransition.new()
	back.xfade_time = 0.18
	back.switch_mode = AnimationNodeStateMachineTransition.SWITCH_MODE_AT_END
	back.advance_mode = AnimationNodeStateMachineTransition.ADVANCE_MODE_AUTO
	machine.add_transition(state_name, "loco", back)


func _filter_upper(blend: AnimationNodeBlend2) -> void:
	if anim_player == null or not anim_player.has_animation("Pistol_Aim_Neutral"):
		return
	blend.filter_enabled = true
	var anim := anim_player.get_animation("Pistol_Aim_Neutral")
	var kept := 0
	for i in anim.get_track_count():
		var path := str(anim.track_get_path(i))
		var bone := path.get_slice(":", 1) if path.find(":") >= 0 else path
		for hint in UPPER_HINTS:
			if bone.find(hint) >= 0:
				blend.set_filter_path(anim.track_get_path(i), true)
				kept += 1
				break
	if kept == 0:
		push_warning("GuardVisual: aim filter matched no tracks (%s)" % str(anim.track_get_path(0)))


func _travel(state_name: String) -> void:
	if _tree == null:
		return
	if state_name == "loco" and _tree_state == "loco":
		return
	var playback := _tree.get("parameters/playback") as AnimationNodeStateMachinePlayback
	if playback:
		playback.travel(state_name)
		_tree_state = state_name


func _apply_blends() -> void:
	if _tree == null:
		return
	_tree.set("parameters/loco/stand/blend_position", _speed)
	_tree.set("parameters/loco/crouch/blend_position", clampf(_speed * 1.6, 0.0, 1.0))
	_tree.set("parameters/loco/stance/blend_amount", _crouch_weight)
	_tree.set("parameters/loco/ready/blend_amount", _ready_weight)
	_tree.set("parameters/loco/aim/blend_amount", _aim_weight)
	_tree.set("parameters/loco/peek/blend_amount", _peek_weight)
	_hold_rifle = (_ready_weight > 0.35 or _aim_weight > 0.35) and not _is_dead


func align_hit_zones() -> void:
	var guard := get_parent() as Node3D
	if guard == null or _skeleton == null:
		return
	var zones := guard.get_node_or_null("HitZones") as Node3D
	if zones == null:
		return
	_move_zone(zones, "Head", "Head", 0.1)
	_move_zone(zones, "Torso", "spine_02", 0.02)
	_move_zone(zones, "LeftArm", "lowerarm_l", 0.0)
	_move_zone(zones, "RightArm", "lowerarm_r", 0.0)
	var head := zones.get_node_or_null("Head") as Node3D
	var limbs := zones.get_node_or_null("Limbs") as Node3D
	if head and limbs:
		limbs.position = Vector3(0, head.position.y * 0.28, 0)


func _move_zone(zones: Node3D, zone_name: String, bone: String, lift: float) -> void:
	var zone := zones.get_node_or_null(zone_name) as Node3D
	var idx := _skeleton.find_bone(bone)
	if zone == null or idx < 0:
		return
	var global_pt: Vector3 = _skeleton.global_transform * _skeleton.get_bone_global_pose(idx).origin
	global_pt.y += lift
	zone.position = zones.to_local(global_pt)


func head_height() -> float:
	var guard := get_parent() as Node3D
	if guard == null:
		return 1.7
	var head := guard.get_node_or_null("HitZones/Head") as Node3D
	if head:
		return head.position.y
	return 1.7


func _attach_rifle() -> void:
	var hand := _bone_attach("hand_r", "RightHand")
	_rifle = Node3D.new()
	_rifle.name = "GuardRifle"
	hand.add_child(_rifle)
	var packed := load("res://assets/weapons/cc0/AssaultRifle_1.fbx") as PackedScene
	var gun := packed.instantiate() if packed else null
	if gun == null:
		return
	gun.name = "CC0Rifle"
	_rifle.add_child(gun)
	var bounds := _rifle_bounds(gun)
	var length := 0.56
	var scale := length / maxf(bounds.size.x, 0.001)
	# Muzzle (gun +X) follows hand +X. Gun up follows hand -Y, which the pose keeps world-up.
	# Fingers (hand +Y) then point down the front of the grip.
	var basis := Basis(Vector3(1, 0, 0), Vector3(0, -1, 0), Vector3(0, 0, -1)).scaled(Vector3.ONE * scale)
	var grip_pt := bounds.position + Vector3(bounds.size.x * 0.34, bounds.size.y * 0.22, bounds.size.z * 0.5)
	var palm := Vector3(0.0, 0.055, 0.0)
	gun.transform = Transform3D(basis, palm - basis * grip_pt)
	_guard_gun_materials(gun)
	var support := bounds.position + Vector3(bounds.size.x * 0.48, bounds.size.y * 0.48, bounds.size.z * 0.5)
	var muzzle := bounds.position + Vector3(bounds.size.x * 0.98, bounds.size.y * 0.55, bounds.size.z * 0.5)
	var grip := Marker3D.new()
	grip.name = "LeftGrip"
	grip.position = gun.transform * support
	_rifle.add_child(grip)
	_sniper_kit = Node3D.new()
	_sniper_kit.name = "SniperKit"
	_sniper_kit.visible = false
	gun.add_child(_sniper_kit)
	var scope_scene := load("res://assets/weapons/cc0/Scope_2.fbx") as PackedScene
	if scope_scene:
		var scope := scope_scene.instantiate()
		_sniper_kit.add_child(scope)
		var scope_bounds := _rifle_bounds(scope)
		var scope_scale := (bounds.size.x * 0.22) / maxf(scope_bounds.size.x, 0.001)
		var scope_mid := scope_bounds.position + scope_bounds.size * 0.5
		var mount := bounds.position + Vector3(bounds.size.x * 0.42, bounds.size.y * 0.86, bounds.size.z * 0.5)
		scope.scale = Vector3.ONE * scope_scale
		scope.position = mount - scope_mid * scope_scale
	_rifle_flash = Node3D.new()
	_rifle_flash.name = "MuzzleFlash"
	_rifle_flash.position = gun.transform * muzzle
	_rifle_flash.visible = false
	_rifle.add_child(_rifle_flash)
	var flash := ProcMesh.sphere_mesh(0.04, Color(1.0, 0.82, 0.35))
	flash.material_override = ProcMesh.emissive(Color(1.0, 0.75, 0.25), 2.2)
	ProcMesh.add_part(_rifle_flash, flash, Vector3.ZERO)
	# SkeletonIK3D solves before AnimationTree and the clip overwrites it.
	# Lengths are measured from the rest pose; the solve itself runs after the clip.
	_arm_upper = _skeleton.find_bone("upperarm_l")
	_arm_lower = _skeleton.find_bone("lowerarm_l")
	_arm_hand = _skeleton.find_bone("hand_l")
	if _arm_upper >= 0 and _arm_lower >= 0 and _arm_hand >= 0:
		var shoulder: Vector3 = _skeleton.get_bone_global_rest(_arm_upper).origin
		var elbow: Vector3 = _skeleton.get_bone_global_rest(_arm_lower).origin
		var wrist: Vector3 = _skeleton.get_bone_global_rest(_arm_hand).origin
		_arm_upper_len = shoulder.distance_to(elbow)
		_arm_lower_len = elbow.distance_to(wrist)
	_arm_upper_r = _skeleton.find_bone("upperarm_r")
	_arm_lower_r = _skeleton.find_bone("lowerarm_r")
	_arm_hand_r = _skeleton.find_bone("hand_r")
	if _arm_upper_r >= 0 and _arm_lower_r >= 0 and _arm_hand_r >= 0:
		var shoulder_r: Vector3 = _skeleton.get_bone_global_rest(_arm_upper_r).origin
		var elbow_r: Vector3 = _skeleton.get_bone_global_rest(_arm_lower_r).origin
		var wrist_r: Vector3 = _skeleton.get_bone_global_rest(_arm_hand_r).origin
		_arm_upper_r_len = shoulder_r.distance_to(elbow_r)
		_arm_lower_r_len = elbow_r.distance_to(wrist_r)


func _rifle_bounds(node: Node3D) -> AABB:
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
	if first:
		for n in node.find_children("*", "MeshInstance3D", true, false):
			var mi2 := n as MeshInstance3D
			if mi2.mesh:
				return mi2.get_aabb()
	return box


func _guard_gun_materials(node: Node) -> void:
	for n in node.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if mi.mesh == null:
			continue
		for i in mi.mesh.get_surface_count():
			var mat := mi.mesh.surface_get_material(i)
			if not (mat is StandardMaterial3D):
				continue
			var sm := (mat as StandardMaterial3D).duplicate() as StandardMaterial3D
			var label := sm.resource_name.to_lower()
			if label.find("wood") >= 0:
				sm.metallic = 0.0
				sm.roughness = 0.58
			elif label.find("metal") >= 0:
				sm.metallic = 0.7
				sm.roughness = 0.36
			else:
				sm.metallic = 0.08
				sm.roughness = 0.52
			mi.set_surface_override_material(i, sm)


func _attach_gear() -> void:
	var head := _bone_attach("Head", "HeadGear")
	_gear["Cap"] = _make_cap(head)
	_gear["Helmet"] = _make_helmet(head)
	_gear["Beret"] = _make_beret(head)
	_gear["Boonie"] = _make_boonie(head)
	_gear["Headset"] = _make_headset(head)
	var chest := _bone_attach("spine_03", "ChestGear")
	_gear["ChestRig"] = _make_chestrig(chest)
	_gear["HeavyPlate"] = _make_plate(chest)
	_gear["Ghillie"] = _make_ghillie(chest)
	_gear["Boards"] = _make_boards(chest)
	var arm := _bone_attach("upperarm_l", "ArmGear")
	_gear["Armband"] = _make_band(arm)
	_gear["BootL"] = _make_boot(_bone_attach("foot_l", "BootL"))
	_gear["BootR"] = _make_boot(_bone_attach("foot_r", "BootR"))
	for gear_name in ["Helmet", "Beret", "Boonie", "HeavyPlate", "Ghillie", "Boards", "Armband"]:
		_show_gear(gear_name, false)


func _bone_attach(bone: String, node_name: String) -> BoneAttachment3D:
	var att := BoneAttachment3D.new()
	att.name = node_name
	_skeleton.add_child(att)
	# Set the bone after the node is in the tree. Setting it earlier leaves bone_idx at -1
	# and the attachment stays on the rest pose while the clip moves the hand.
	att.bone_name = bone
	att.bone_idx = _skeleton.find_bone(bone)
	_attachments.append(att)
	return att


func _sync_attachments() -> void:
	if _skeleton == null:
		return
	for att in _attachments:
		if not is_instance_valid(att) or att.bone_idx < 0:
			continue
		att.transform = _skeleton.get_bone_global_pose(att.bone_idx)


func _pose_rifle_arms() -> void:
	## The free clips are pistol poses, which park the rifle overhead.
	## Replace the right arm each frame with a shouldered aim or a low ready.
	if not _hold_rifle or _is_dead or _skeleton == null:
		return
	if _arm_upper_r < 0 or _arm_lower_r < 0 or _arm_hand_r < 0:
		return
	var shouldered := clampf(_aim_weight, 0.0, 1.0)
	if _tree_state == "shoot":
		shouldered = 1.0
	var shoulder: Vector3 = _skeleton.get_bone_global_pose(_arm_upper_r).origin
	# Wrist positions. The stock sits back along the barrel from here, into the shoulder when aiming.
	var aim_hand := Vector3(-0.08, 1.42, 0.18)
	var low_hand := Vector3(-0.03, 1.18, 0.14)
	var aim_barrel := Vector3(0.02, 0.03, 1.0)
	var low_barrel := Vector3(0.10, -0.12, 0.98)
	var hand_pos := low_hand.lerp(aim_hand, shouldered)
	var barrel := low_barrel.lerp(aim_barrel, shouldered).normalized()
	var reach := _arm_upper_r_len + _arm_lower_r_len - 0.02
	var to_hand := hand_pos - shoulder
	if to_hand.length() > reach:
		hand_pos = shoulder + to_hand.normalized() * reach
	var elbow := _elbow_point(shoulder, hand_pos, Vector3(-0.55, -1.0, 0.05), _arm_upper_r_len, _arm_lower_r_len)
	var upper_basis := _basis_y_toward(_skeleton.get_bone_global_pose(_arm_upper_r).basis, shoulder, elbow)
	var lower_basis := _basis_y_toward(_skeleton.get_bone_global_pose(_arm_lower_r).basis, elbow, hand_pos)
	# Fingers (hand +Y) drape down the front of the grip. Curl pulls the tips back into it.
	# Hand +X is the barrel, which is where the rifle mesh points its muzzle.
	var x := barrel
	var down := (-Vector3.UP - x * (-Vector3.UP).dot(x))
	if down.length_squared() < 0.0004:
		down = Vector3(0, 0, -1)
	var y := down.normalized()
	var z := x.cross(y).normalized()
	y = z.cross(x).normalized()
	_skeleton.set_bone_global_pose(_arm_upper_r, Transform3D(upper_basis, shoulder))
	_skeleton.set_bone_global_pose(_arm_lower_r, Transform3D(lower_basis, elbow))
	_skeleton.set_bone_global_pose(_arm_hand_r, Transform3D(Basis(x, y, z), hand_pos))


func _curl_grip_fingers() -> void:
	if not _hold_rifle or _is_dead or _skeleton == null:
		return
	for side in ["r", "l"]:
		for digit in ["index", "middle", "ring", "pinky"]:
			# Local +X closes both hands. The right index stays straighter on the trigger.
			var bend := 1.05 if digit == "index" and side == "r" else 1.9
			for joint in ["01", "02", "03"]:
				_bend_finger("%s_%s_%s" % [digit, joint, side], bend)
		for joint in ["01", "02"]:
			_bend_finger("thumb_%s_%s" % [joint, side], 0.7)


func _bend_finger(bone: String, amount: float) -> void:
	var idx := _skeleton.find_bone(bone)
	if idx < 0:
		return
	var rest := _skeleton.get_bone_rest(idx).basis.get_rotation_quaternion()
	_skeleton.set_bone_pose_rotation(idx, rest * Quaternion.from_euler(Vector3(amount, 0.0, 0.0)))


func _solve_left_hand() -> void:
	if not _hold_rifle or _skeleton == null or _rifle == null:
		return
	if _arm_upper < 0 or _arm_lower < 0 or _arm_hand < 0:
		return
	var grip := _rifle.get_node_or_null("LeftGrip") as Node3D
	if grip == null:
		return
	var on_gun: Vector3 = _skeleton.global_transform.affine_inverse() * grip.global_position
	var barrel := Vector3(0, 0, 1)
	if _arm_hand_r >= 0:
		barrel = _skeleton.get_bone_global_pose(_arm_hand_r).basis.x
	# Palm rests on top of the handguard. Fingers run forward along it.
	var target := on_gun + Vector3(0.0, 0.04, 0.0) - barrel * 0.02
	var shoulder_xf := _skeleton.get_bone_global_pose(_arm_upper)
	var shoulder: Vector3 = shoulder_xf.origin
	var pole := Vector3(0.45, -1.0, 0.1)
	var elbow := _elbow_point(shoulder, target, pole, _arm_upper_len, _arm_lower_len)
	var upper_basis := _basis_y_toward(shoulder_xf.basis, shoulder, elbow)
	var lower_basis := _basis_y_toward(_skeleton.get_bone_global_pose(_arm_lower).basis, elbow, target)
	var y := (barrel + Vector3(0, -0.35, 0)).normalized()
	var x := (Vector3.UP - y * Vector3.UP.dot(y))
	if x.length_squared() < 0.0004:
		x = y.cross(Vector3.RIGHT)
	x = x.normalized()
	var z := x.cross(y).normalized()
	y = z.cross(x).normalized()
	_skeleton.set_bone_global_pose(_arm_upper, Transform3D(upper_basis, shoulder))
	_skeleton.set_bone_global_pose(_arm_lower, Transform3D(lower_basis, elbow))
	_skeleton.set_bone_global_pose(_arm_hand, Transform3D(Basis(x, y, z), target))


func _elbow_point(shoulder: Vector3, target: Vector3, pole: Vector3, upper_len: float, lower_len: float) -> Vector3:
	var to_target := target - shoulder
	var reach := upper_len + lower_len - 0.001
	var dist := clampf(to_target.length(), 0.05, reach)
	var dir := to_target / maxf(to_target.length(), 0.0001)
	var cos_a := clampf((dist * dist + upper_len * upper_len - lower_len * lower_len) / (2.0 * dist * upper_len), -1.0, 1.0)
	var sin_a := sqrt(maxf(0.0, 1.0 - cos_a * cos_a))
	var pole_flat := pole - dir * pole.dot(dir)
	if pole_flat.length_squared() < 0.0001:
		pole_flat = dir.cross(Vector3.UP)
	pole_flat = pole_flat.normalized()
	return shoulder + dir * (upper_len * cos_a) + pole_flat * (upper_len * sin_a)


func _basis_y_toward(hint: Basis, origin: Vector3, target: Vector3) -> Basis:
	var y := target - origin
	if y.length_squared() < 0.000001:
		return hint
	y = y.normalized()
	var x := hint.x
	if absf(x.dot(y)) > 0.95:
		x = hint.z
	var z := x.cross(y)
	if z.length_squared() < 0.000001:
		z = Vector3.UP.cross(y)
	z = z.normalized()
	x = y.cross(z).normalized()
	return Basis(x, y, z)


func _make_cap(parent: Node3D) -> Node3D:
	var cap := Node3D.new()
	parent.add_child(cap)
	var crown := ProcMesh.add_part(cap, ProcMesh.sphere_mesh(0.1, Color(0.12, 0.15, 0.09), 0.8, 0.02), Vector3(0, 0.13, 0.0))
	crown.scale = Vector3(1.02, 0.36, 1.02)
	ProcMesh.add_part(cap, ProcMesh.cylinder_mesh(0.125, 0.01, Color(0.1, 0.12, 0.07), 0.8, 0.02, 10), Vector3(0, 0.08, 0.02))
	return cap


func _make_helmet(parent: Node3D) -> Node3D:
	var helm := Node3D.new()
	parent.add_child(helm)
	var shell := ProcMesh.add_part(helm, ProcMesh.sphere_mesh(0.13, Color(0.16, 0.17, 0.18), 0.42, 0.35), Vector3(0, 0.08, 0.0))
	shell.scale = Vector3(1.05, 0.72, 1.08)
	return helm


func _make_beret(parent: Node3D) -> Node3D:
	var beret := Node3D.new()
	parent.add_child(beret)
	var mesh := ProcMesh.add_part(beret, ProcMesh.sphere_mesh(0.11, Color(0.55, 0.1, 0.1), 0.7, 0.05), Vector3(0.02, 0.1, 0))
	mesh.scale = Vector3(1.15, 0.32, 1.0)
	mesh.rotation_degrees = Vector3(0, 0, -14)
	return beret


func _make_boonie(parent: Node3D) -> Node3D:
	var hat := Node3D.new()
	parent.add_child(hat)
	var crown := ProcMesh.add_part(hat, ProcMesh.sphere_mesh(0.1, Color(0.22, 0.28, 0.16), 0.82, 0.02), Vector3(0, 0.09, 0))
	crown.scale = Vector3(1.0, 0.38, 1.0)
	ProcMesh.add_part(hat, ProcMesh.cylinder_mesh(0.17, 0.012, Color(0.2, 0.26, 0.14), 0.85, 0.02, 10), Vector3(0, 0.05, 0))
	return hat


func _make_headset(parent: Node3D) -> Node3D:
	var set := Node3D.new()
	parent.add_child(set)
	var band := ProcMesh.add_part(set, ProcMesh.capsule_mesh(0.012, 0.22, Color(0.1, 0.1, 0.11), 0.4, 0.4), Vector3(0, 0.08, 0))
	band.rotation_degrees = Vector3(0, 0, 90)
	ProcMesh.add_part(set, ProcMesh.sphere_mesh(0.032, Color(0.1, 0.1, 0.11), 0.4, 0.3), Vector3(-0.1, 0.02, 0))
	ProcMesh.add_part(set, ProcMesh.sphere_mesh(0.032, Color(0.1, 0.1, 0.11), 0.4, 0.3), Vector3(0.1, 0.02, 0))
	return set


func _make_chestrig(parent: Node3D) -> Node3D:
	var rig := Node3D.new()
	parent.add_child(rig)
	var canvas := Color(0.16, 0.2, 0.13)
	var pouch := Color(0.14, 0.16, 0.11)
	ProcMesh.add_part(rig, ProcMesh.box_mesh(Vector3(0.22, 0.14, 0.025), canvas, 0.8, 0.05), Vector3(0, 0.02, 0.11))
	ProcMesh.add_part(rig, ProcMesh.box_mesh(Vector3(0.065, 0.08, 0.03), pouch, 0.75, 0.08), Vector3(-0.055, -0.02, 0.125))
	ProcMesh.add_part(rig, ProcMesh.box_mesh(Vector3(0.065, 0.08, 0.03), pouch, 0.75, 0.08), Vector3(0.055, -0.02, 0.125))
	ProcMesh.add_part(rig, ProcMesh.box_mesh(Vector3(0.022, 0.14, 0.018), canvas, 0.8, 0.05), Vector3(-0.08, 0.1, 0.07))
	ProcMesh.add_part(rig, ProcMesh.box_mesh(Vector3(0.022, 0.14, 0.018), canvas, 0.8, 0.05), Vector3(0.08, 0.1, 0.07))
	return rig


func _make_plate(parent: Node3D) -> Node3D:
	var plate := Node3D.new()
	parent.add_child(plate)
	var mesh := ProcMesh.add_part(plate, ProcMesh.box_mesh(Vector3(0.28, 0.32, 0.08), Color(0.16, 0.17, 0.2), 0.45, 0.35), Vector3(0, -0.02, 0.12))
	mesh.rotation_degrees = Vector3(-8, 0, 0)
	return plate


func _make_ghillie(parent: Node3D) -> Node3D:
	var ghillie := Node3D.new()
	parent.add_child(ghillie)
	if not _hi_detail():
		return ghillie
	for i in range(6):
		var strand := ProcMesh.add_part(ghillie, ProcMesh.capsule_mesh(0.012, 0.22, Color(0.16, 0.28, 0.1), 0.95, 0.0), Vector3(-0.1 + float(i) * 0.04, -0.02, 0.1))
		strand.rotation_degrees = Vector3(50, float(i) * 9.0, 0)
	return ghillie


func _make_boards(parent: Node3D) -> Node3D:
	var boards := Node3D.new()
	parent.add_child(boards)
	ProcMesh.add_part(boards, ProcMesh.box_mesh(Vector3(0.06, 0.028, 0.04), Color(0.82, 0.68, 0.28), 0.4, 0.5), Vector3(-0.1, 0.08, 0.12))
	ProcMesh.add_part(boards, ProcMesh.box_mesh(Vector3(0.06, 0.028, 0.04), Color(0.82, 0.68, 0.28), 0.4, 0.5), Vector3(0.1, 0.08, 0.12))
	return boards


func _make_boot(parent: Node3D) -> Node3D:
	var boot := Node3D.new()
	parent.add_child(boot)
	var leather := Color(0.07, 0.06, 0.055)
	# foot bone +Y runs toward the toes.
	var sole := ProcMesh.add_part(boot, ProcMesh.box_mesh(Vector3(0.095, 0.28, 0.08), leather, 0.62, 0.12), Vector3(0, 0.1, -0.01))
	sole.rotation_degrees = Vector3(8, 0, 0)
	return boot


func _make_band(parent: Node3D) -> Node3D:
	var band := Node3D.new()
	parent.add_child(band)
	ProcMesh.add_part(band, ProcMesh.capsule_mesh(0.04, 0.05, Color(0.75, 0.16, 0.12), 0.6, 0.05), Vector3(0, 0.0, 0))
	return band


func _hi_detail() -> bool:
	if OS.has_feature("mobile"):
		return false
	if GraphicsQuality and GraphicsQuality.level == GraphicsQuality.LEVEL_LOW:
		return false
	return true


func _show_gear(gear_name: String, on: bool) -> void:
	var node: Node = _gear.get(gear_name)
	if node is Node3D:
		(node as Node3D).visible = on


func apply_role_look(role: String, heavy: bool = false, officer: bool = false, dog: bool = false) -> void:
	if dog:
		_build_dog_mesh()
		return
	if _actor == null:
		return
	for gear_name in ["Cap", "Helmet", "Beret", "Boonie", "Headset", "HeavyPlate", "Ghillie", "Boards", "Armband"]:
		_show_gear(gear_name, false)
	var jacket := Color(0.28, 0.34, 0.22)
	if heavy:
		jacket = Color(0.2, 0.21, 0.24)
		_show_gear("Helmet", true)
		_show_gear("HeavyPlate", true)
		_show_gear("Headset", true)
	elif role == "commander" or officer:
		jacket = Color(0.5, 0.42, 0.3)
		_show_gear("Beret", true)
		_show_gear("Boards", true)
	elif role == "handler":
		jacket = Color(0.26, 0.33, 0.22)
		_show_gear("Headset", true)
		_show_gear("Armband", true)
		_show_gear("Cap", true)
	elif role == "sniper":
		jacket = Color(0.2, 0.28, 0.16)
		_show_gear("Boonie", true)
		_show_gear("Ghillie", true)
	elif role == "sentry":
		jacket = Color(0.32, 0.3, 0.22)
		_show_gear("Cap", true)
		_show_gear("Headset", true)
	elif role == "interior":
		jacket = Color(0.38, 0.34, 0.28)
		_show_gear("Cap", true)
	else:
		_show_gear("Cap", true)
		_show_gear("Headset", true)
	_tint_cloth(jacket)


func _build_dog_mesh() -> void:
	if is_instance_valid(_actor):
		_actor.visible = false
	if is_instance_valid(_tree):
		_tree.active = false
	_hold_rifle = false
	if get_node_or_null("DogRig") != null:
		return
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
	ProcMesh.add_part(dog, ProcMesh.sphere_mesh(0.035, fur.darkened(0.1), 0.9, 0.0), Vector3(-0.07, 0.62, -0.3))
	ProcMesh.add_part(dog, ProcMesh.sphere_mesh(0.035, fur.darkened(0.1), 0.9, 0.0), Vector3(0.07, 0.62, -0.3))
	for xz in [Vector2(-0.1, 0.16), Vector2(0.1, 0.16), Vector2(-0.1, -0.16), Vector2(0.1, -0.16)]:
		ProcMesh.add_part(dog, ProcMesh.capsule_mesh(0.035, 0.28, dark, 0.85, 0.0), Vector3(xz.x, 0.16, xz.y))
	var tail := ProcMesh.add_part(dog, ProcMesh.capsule_mesh(0.02, 0.22, fur, 0.9, 0.0), Vector3(0, 0.52, 0.32))
	tail.rotation_degrees = Vector3(50, 0, 0)


func set_placeholder_color(_color: Color) -> void:
	pass


func set_sniper_look(enabled: bool) -> void:
	if is_instance_valid(_sniper_kit):
		_sniper_kit.visible = enabled


func set_cover_pose(pose: String) -> void:
	_cover_pose = pose


func set_locomotion(moving: bool, running: bool, suspicious: bool = false, alert: bool = false) -> void:
	if _is_dead or _oneshot_timer > 0.0:
		return
	_speed = 0.0
	_crouch_weight = 0.0
	_aim_weight = 0.0
	_peek_weight = 0.0
	_ready_weight = 0.95
	if _cover_pose == "cover":
		_crouch_weight = 1.0
		_speed = 0.0
		_ready_weight = 0.7
	elif _cover_pose == "peek":
		_crouch_weight = 1.0
		_ready_weight = 1.0
		_aim_weight = 1.0
		_peek_weight = 0.0
	elif not moving and suspicious:
		_crouch_weight = 0.35
		if _look_cooldown <= 0.0:
			_travel("signal")
			_oneshot_timer = 1.15
			_look_cooldown = 3.6
			return
	elif moving and suspicious:
		_crouch_weight = 1.0
		_speed = 0.55
	elif moving and running:
		# Combat advance. Legs jog; upper body stays on the aim pose (reads as a strafe).
		_speed = 0.72
		_ready_weight = 1.0
		_aim_weight = 1.0
	elif not moving and running:
		_ready_weight = 1.0
		_aim_weight = 1.0
	elif moving and alert:
		_speed = 0.48
		_ready_weight = 1.0
		_aim_weight = 0.25
	elif not moving and alert:
		_ready_weight = 1.0
		_aim_weight = 0.2
	elif moving:
		_speed = 0.4
		_ready_weight = 1.0
	else:
		# Still patrol keeps the rifle in both hands at low ready.
		_ready_weight = 1.0
	if _speed > 0.9:
		_ready_weight = 0.75
	_apply_blends()
	_travel("loco")


func _clear_pose() -> void:
	_speed = 0.0
	_crouch_weight = 0.0
	_aim_weight = 0.0
	_peek_weight = 0.0
	_ready_weight = 0.35


func _force_state(state_name: String) -> void:
	if _tree == null:
		return
	var playback := _tree.get("parameters/playback") as AnimationNodeStateMachinePlayback
	if playback:
		playback.start(state_name)
		_tree_state = state_name


func play(anim_name: StringName, _custom_blend: float = 0.18) -> void:
	var key := String(anim_name)
	if not _has_anim(anim_name):
		return
	if _is_dead and key.find("death") < 0 and key.find("takedown") < 0:
		return
	_clear_pose()
	if ONESHOT.has(key):
		# Reload, hit, and signal take the support hand off the handguard so the clip can play.
		# The shot keeps both hands on the rifle.
		_hold_rifle = key == "shoot"
		if String(ONESHOT[key]) == "death":
			_is_dead = true
			_hold_rifle = false
		_travel(String(ONESHOT[key]))
		_oneshot_timer = _clip_length(String(CLIP.get(key, "Idle")))
		return
	if key == "crouch" or key == "cover":
		_crouch_weight = 1.0
		_speed = 0.0
		_ready_weight = 0.8
	elif key == "walk":
		_speed = 0.4
		_ready_weight = 1.0
		_crouch_weight = 0.0
	elif key == "investigate":
		_speed = 0.5
		_crouch_weight = 1.0
		_ready_weight = 0.9
	elif key == "run":
		_speed = 1.0
		_ready_weight = 0.7
	elif key == "aim" or key == "strafe":
		_aim_weight = 1.0
		_ready_weight = 1.0
		_speed = 0.6 if key == "strafe" else 0.0
	elif key == "peek":
		# Aim_Up points the pistol at the sky. A peek is a crouch with the rifle at the shoulder.
		_crouch_weight = 1.0
		_peek_weight = 0.0
		_aim_weight = 1.0
		_ready_weight = 1.0
	elif key == "alert":
		_ready_weight = 1.0
		_aim_weight = 0.25
		_speed = 0.0
	elif key == "idle":
		_speed = 0.0
		_ready_weight = 1.0
		_aim_weight = 0.0
		_crouch_weight = 0.0
	_apply_blends()
	_travel("loco")


func pose_for_shot(which: String) -> void:
	## Still frame for screenshots. One-shots are travelled; locomotion is blended.
	_oneshot_timer = 0.0
	_is_dead = false
	_cover_pose = ""
	if is_instance_valid(_tree):
		_tree.active = true
	_hold_rifle = true
	_force_state("loco")
	_clear_pose()
	match which:
		"idle":
			play(ANIM_IDLE)
		"walk":
			play(ANIM_WALK)
		"alert":
			_speed = 0.5
			_ready_weight = 1.0
			_aim_weight = 0.3
			_crouch_weight = 0.0
			_apply_blends()
			_travel("loco")
		"run":
			play(ANIM_RUN)
		"crouch":
			_crouch_weight = 1.0
			_speed = 0.45
			_ready_weight = 0.9
			_apply_blends()
			_travel("loco")
		"aim":
			play(ANIM_AIM)
		"strafe":
			play(&"strafe")
		"peek":
			play(ANIM_PEEK)
		"look":
			play(ANIM_LOOK_AROUND)
		"shoot":
			_aim_weight = 1.0
			_ready_weight = 1.0
			_apply_blends()
			play(ANIM_SHOOT)
		"reload":
			play(&"reload")
		"hit":
			play(ANIM_HIT)
		"death":
			play(ANIM_DEATH)
		_:
			play(ANIM_IDLE)


func hand_debug() -> String:
	if _skeleton == null:
		return "no-skeleton"
	var idx := _skeleton.find_bone("hand_r")
	if idx < 0:
		return "no-hand"
	var pose := _skeleton.get_bone_global_pose(idx)
	var wrist: Vector3 = _skeleton.global_transform * pose.origin
	var gun := _rifle.global_position if is_instance_valid(_rifle) else Vector3.ZERO
	var left_i := _skeleton.find_bone("hand_l")
	var left: Vector3 = _skeleton.global_transform * _skeleton.get_bone_global_pose(left_i).origin
	var grip := _rifle.get_node_or_null("LeftGrip") as Node3D
	var grip_at := grip.global_position if grip else Vector3.ZERO
	return "wrist=%s gun=%s delta=%s left=%s grip=%s ldelta=%s hold=%s" % [wrist, gun, gun - wrist, left, grip_at, left - grip_at, _hold_rifle]


func play_state(state_name: String) -> void:
	match state_name:
		"PATROL":
			play(ANIM_WALK)
		"SUSPICIOUS":
			play(ANIM_INVESTIGATE)
		"ALERT":
			play(ANIM_ALERT)
		"COMBAT":
			play(ANIM_AIM)
		"LOOK_AROUND":
			play(ANIM_LOOK_AROUND)
		"DEAD":
			play(ANIM_DEATH)
		_:
			play(ANIM_IDLE)


func play_death(kind: String = "body") -> void:
	_is_dead = true
	match kind:
		"head", "HEAD":
			play(ANIM_DEATH_HEAD)
		"back", "BACK":
			play(ANIM_DEATH_BACK)
		"explode", "explosion", "EXPLODE":
			play(ANIM_DEATH_EXPLODE)
		_:
			play(ANIM_DEATH)


func play_radio() -> void:
	if _is_dead:
		return
	play(ANIM_RADIO)


func play_alarm_press() -> void:
	if _is_dead:
		return
	play(ANIM_ALARM_PRESS)


func play_takedown(from_behind: bool) -> void:
	_is_dead = true
	play(ANIM_TAKEDOWN_BACK if from_behind else ANIM_TAKEDOWN_FRONT)


func play_reload() -> void:
	if _is_dead:
		return
	play(&"reload")


func play_throw() -> void:
	if _is_dead:
		return
	play(&"throw")


func play_shoot() -> void:
	if _is_dead:
		return
	play(ANIM_SHOOT)
	if is_instance_valid(_rifle_flash):
		_rifle_flash.visible = true
		_flash_timer = 0.07


func play_hit() -> void:
	if _is_dead:
		return
	play(ANIM_HIT)


func _clip_length(clip_name: String) -> float:
	if anim_player and anim_player.has_animation(clip_name):
		return maxf(0.35, anim_player.get_animation(clip_name).length)
	return 0.6


func _on_anim_finished(anim_name: StringName) -> void:
	animation_finished.emit(anim_name)


func _has_anim(anim_name: StringName) -> bool:
	if anim_player == null:
		return false
	var clip_name: String = CLIP.get(String(anim_name), "")
	return clip_name != "" and anim_player.has_animation(clip_name)
