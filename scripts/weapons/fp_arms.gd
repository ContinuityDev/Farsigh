class_name FpArms
extends RefCounted
## WRAD CC0 arms. Shoulders stay fixed in camera space. Two-bone IK puts the
## hands on the gun every frame, including aim, sway, bob and reloads.


const ARMS_SCENE := preload("res://assets/weapons/cc0/fps_arms.glb")
## One body for every gun. Matches the hip scale Hayden kept.
const BODY_SCALE := 0.085

# Camera space: +X right, +Y up, -Z forward.
# Hip right sits lower and less wide so the forearm rises at about 45 degrees
# from the bottom-right corner. Left sits further back so that arm runs
# longer and straighter under the handguard.
const SHOULDER_R := Vector3(0.50, -0.62, -0.34)
const SHOULDER_L := Vector3(-0.36, -0.46, -0.46)
# ADS drops the shoulders and pulls them back so the forearms fall below
# the frame and only the wrists stay in view.
const SHOULDER_R_ADS := Vector3(0.20, -0.72, -0.14)
const SHOULDER_L_ADS := Vector3(-0.16, -0.68, -0.18)


static func attach(host: Node3D) -> Skeleton3D:
	var rig := ARMS_SCENE.instantiate()
	rig.name = "FPArms"
	host.add_child(rig)
	var skel := rig.find_child("Skeleton3D", true, false) as Skeleton3D
	var mesh := rig.find_child("arms_mesh", true, false) as MeshInstance3D
	if skel == null:
		return null
	var arms := skel.get_parent() as Node3D
	arms.scale = Vector3.ONE * BODY_SCALE
	if mesh:
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mesh.extra_cull_margin = 8.0
		mesh.custom_aabb = AABB(Vector3(-8, -8, -8), Vector3(16, 16, 16))
		# The sleeve faces the camera on one side of the bend and away on the
		# other. Keep both so a tucked elbow never disappears.
		for s in mesh.mesh.get_surface_count():
			var mat := mesh.get_active_material(s)
			if mat == null:
				mat = mesh.mesh.surface_get_material(s)
			if mat is BaseMaterial3D:
				var copy := (mat as BaseMaterial3D).duplicate()
				copy.cull_mode = BaseMaterial3D.CULL_DISABLED
				mesh.set_surface_override_material(s, copy)
	return skel


static func solve(skel: Skeleton3D, gun: Node3D, camera: Node3D, right_local: Vector3, left_local: Vector3, ads: float, style: String) -> void:
	if skel == null or gun == null or camera == null:
		return
	var u := clampf(ads, 0.0, 1.0)
	# The rig is a child of the gun, scaled by BODY_SCALE, so gun-local / scale
	# is skeleton space. That is the space the skin was bound in.
	var to_gun := gun.global_transform.affine_inverse()
	var sh_r := (to_gun * (camera.global_transform * SHOULDER_R.lerp(SHOULDER_R_ADS, u))) / BODY_SCALE
	var sh_l := (to_gun * (camera.global_transform * SHOULDER_L.lerp(SHOULDER_L_ADS, u))) / BODY_SCALE
	var wr_r := right_local / BODY_SCALE
	var wr_l := left_local / BODY_SCALE
	var pole_basis := gun.global_transform.basis.orthonormalized().inverse() * camera.global_transform.basis
	# Right pole is mostly downward, with only a little outward bias,
	# so the elbow tucks instead of flaring into a chicken wing.
	var pole_r: Vector3 = pole_basis * Vector3(0.16, -0.7, 0.04).lerp(Vector3(0.08, -1.35, 0.02), u)
	var pole_l: Vector3 = pole_basis * Vector3(-0.22, -0.7, 0.12).lerp(Vector3(-0.1, -1.2, 0.04), u)
	_pose_arm(skel, "r", sh_r, wr_r, _right_fingers(style), _right_palm(style), pole_r)
	if style == "pistol":
		_curl(skel, "r", 0.85, 1.45)
	elif style == "melee" or style == "bat":
		_curl(skel, "r", 1.1, 1.35)
	else:
		# Index stays along the trigger guard; the other fingers close on the grip.
		_curl(skel, "r", 0.62, 1.85)
	if style == "throw":
		_pose_arm(skel, "l", sh_l, sh_l + Vector3(-0.4, -2.2, 0.4), Vector3(0, -1, 0), Vector3(-1, 0, 0), pole_l)
		_curl(skel, "l", 0.4, 0.5)
		return
	_pose_arm(skel, "l", sh_l, wr_l, _left_fingers(style), _left_palm(style), pole_l)
	_curl(skel, "l", 0.7 if style != "pistol" else 0.45, 1.35)
	skel.force_update_all_bone_transforms()


static func right_offset(style: String) -> Vector3:
	if style == "melee" or style == "bat":
		return Vector3(0.02, 0.0, 0.03)
	if style == "pistol":
		return Vector3(0.03, -0.02, 0.02)
	# Right side of the handle, low, and a little toward the trigger
	# so the fingers close on the grip instead of sitting behind it.
	return Vector3(0.04, -0.055, -0.015)


static func left_offset(style: String) -> Vector3:
	if style == "pistol":
		return Vector3(0.0, -0.012, 0.02)
	if style == "bow":
		return Vector3(-0.015, 0.0, 0.03)
	if style == "melee" or style == "bat":
		return Vector3(0.015, 0.0, 0.03)
	return Vector3(0.0, -0.018, 0.01)


static func _right_fingers(style: String) -> Vector3:
	if style == "melee" or style == "bat":
		return Vector3(-0.2, -0.15, -1.0)
	if style == "pistol":
		return Vector3(0.1, -0.85, -0.4)
	# Across the front of the grip, toward the trigger guard.
	return Vector3(-0.35, -0.85, -0.4)


static func _right_palm(style: String) -> Vector3:
	if style == "pistol":
		return Vector3(0.85, 0.1, 0.35)
	# Thumb back along the grip so the palm faces into it and the curl wraps.
	return Vector3(0.05, 0.35, 1.0)


static func _left_fingers(style: String) -> Vector3:
	if style == "bow" or style == "melee" or style == "bat":
		return Vector3(0.2, -0.2, -1.0)
	if style == "pistol":
		return Vector3(0.1, -0.8, -0.35)
	return Vector3(-0.05, 1.0, -0.2)


static func _left_palm(style: String) -> Vector3:
	if style == "pistol" or style == "bow":
		return Vector3(-0.7, 0.2, 0.4)
	return Vector3(-1.0, 0.15, 0.1)


static func _pose_arm(skel: Skeleton3D, side: String, shoulder: Vector3, wrist: Vector3, finger_dir: Vector3, palm_dir: Vector3, pole: Vector3) -> void:
	var shoulder_b := skel.find_bone("shoulder." + side)
	var upper := skel.find_bone("bicep." + side)
	var fore := skel.find_bone("forearm." + side)
	var wrist_b := skel.find_bone("wrist." + side)
	if upper < 0 or fore < 0 or wrist_b < 0:
		return
	var upper_len := skel.get_bone_global_rest(upper).origin.distance_to(skel.get_bone_global_rest(fore).origin)
	var fore_len := skel.get_bone_global_rest(fore).origin.distance_to(skel.get_bone_global_rest(wrist_b).origin)
	var clav_len := 0.4
	if shoulder_b >= 0:
		clav_len = skel.get_bone_global_rest(shoulder_b).origin.distance_to(skel.get_bone_global_rest(upper).origin)
	# Clamp to the real bone length. The elbow bends; the arm does not stretch.
	var elbow := _elbow(shoulder, wrist, pole, upper_len, fore_len)
	if shoulder_b >= 0:
		var clav := shoulder - (elbow - shoulder).normalized() * clav_len
		skel.set_bone_global_pose_override(shoulder_b, Transform3D(_look_y(shoulder - clav, pole), clav), 1.0, true)
	skel.set_bone_global_pose_override(upper, Transform3D(_look_y(elbow - shoulder, pole), shoulder), 1.0, true)
	skel.set_bone_global_pose_override(fore, Transform3D(_look_y(wrist - elbow, pole), elbow), 1.0, true)
	var hand := _hand_basis(skel, wrist_b, side, finger_dir, palm_dir)
	skel.set_bone_global_pose_override(wrist_b, Transform3D(hand, wrist), 1.0, true)


static func _hand_basis(skel: Skeleton3D, wrist_b: int, side: String, finger_dir: Vector3, palm_dir: Vector3) -> Basis:
	var rest := skel.get_bone_global_rest(wrist_b)
	var mid := skel.find_bone("finger_middle1." + side)
	var thumb := skel.find_bone("finger_thumb1." + side)
	var fwd := Vector3(0, 1, 0)
	var side_axis := Vector3(1, 0, 0)
	if mid >= 0:
		fwd = rest.basis.inverse() * (skel.get_bone_global_rest(mid).origin - rest.origin)
	if thumb >= 0:
		side_axis = rest.basis.inverse() * (skel.get_bone_global_rest(thumb).origin - rest.origin)
	if fwd.length_squared() < 0.0001:
		fwd = Vector3(0, 1, 0)
	fwd = fwd.normalized()
	side_axis = (side_axis - fwd * side_axis.dot(fwd))
	if side_axis.length_squared() < 0.0001:
		side_axis = Vector3(1, 0, 0)
	side_axis = side_axis.normalized()
	var up := fwd.cross(side_axis).normalized()
	var local_b := Basis(side_axis, up, fwd)
	var wz := finger_dir.normalized()
	if wz.length_squared() < 0.0001:
		wz = Vector3(0, -1, 0)
	var wx := palm_dir - wz * palm_dir.dot(wz)
	if wx.length_squared() < 0.0001:
		wx = Vector3.UP.cross(wz)
	wx = wx.normalized()
	var wy := wz.cross(wx).normalized()
	wx = wy.cross(wz).normalized()
	return Basis(wx, wy, wz) * local_b.inverse()


static func _look_y(dir: Vector3, pole: Vector3) -> Basis:
	var y := dir.normalized()
	if y.length_squared() < 0.0001:
		y = Vector3.UP
	var z := pole - y * pole.dot(y)
	if z.length_squared() < 0.0001:
		z = Vector3.FORWARD.cross(y)
	z = z.normalized()
	var x := y.cross(z).normalized()
	z = x.cross(y).normalized()
	return Basis(x, y, z)


static func _elbow(shoulder: Vector3, target: Vector3, pole: Vector3, upper_len: float, fore_len: float) -> Vector3:
	var to_target := target - shoulder
	var reach := upper_len + fore_len - 0.001
	var dist := clampf(to_target.length(), 0.05, reach)
	var dir := to_target / maxf(to_target.length(), 0.0001)
	var cos_a := clampf((dist * dist + upper_len * upper_len - fore_len * fore_len) / (2.0 * dist * upper_len), -1.0, 1.0)
	var sin_a := sqrt(maxf(0.0, 1.0 - cos_a * cos_a))
	var pole_flat := pole - dir * pole.dot(dir)
	if pole_flat.length_squared() < 0.0001:
		pole_flat = dir.cross(Vector3.UP)
	pole_flat = pole_flat.normalized()
	return shoulder + dir * (upper_len * cos_a) + pole_flat * (upper_len * sin_a)


static func _curl(skel: Skeleton3D, side: String, index_amt: float, amt: float) -> void:
	skel.force_update_all_bone_transforms()
	var wrist := skel.find_bone("wrist." + side)
	if wrist < 0:
		return
	var wrist_g := skel.get_bone_global_pose(wrist)
	for digit in ["index", "middle", "ring", "pinky"]:
		var bend := index_amt if digit == "index" and side == "r" else amt
		var parent_g := wrist_g
		for joint in [1, 2, 3]:
			var falloff := 1.0 if joint == 1 else (0.85 if joint == 2 else 0.55)
			var euler := Vector3(bend * falloff, 0.0, bend * falloff) if side == "l" else Vector3(0.0, 0.0, -bend * falloff)
			parent_g = _bend_global(skel, "finger_%s%d.%s" % [digit, joint, side], parent_g, euler)
	var thumb_g := wrist_g
	var thumb_euler := Vector3(0.8, 0.0, 0.8) if side == "l" else Vector3(0.0, 0.0, -0.72)
	thumb_g = _bend_global(skel, "finger_thumb1." + side, thumb_g, thumb_euler)
	thumb_g = _bend_global(skel, "finger_thumb2." + side, thumb_g, thumb_euler * 0.7)
	_bend_global(skel, "finger_thumb3." + side, thumb_g, thumb_euler * 0.45)


static func _bend_global(skel: Skeleton3D, bone_name: String, parent_g: Transform3D, euler: Vector3) -> Transform3D:
	var idx := skel.find_bone(bone_name)
	if idx < 0:
		return parent_g
	var rest := skel.get_bone_rest(idx)
	var local := Transform3D(Basis(rest.basis.get_rotation_quaternion() * Quaternion.from_euler(euler)), rest.origin)
	var global := parent_g * local
	skel.set_bone_global_pose_override(idx, global, 1.0, true)
	return global
