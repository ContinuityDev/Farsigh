class_name FpArms
extends RefCounted
## WRAD CC0 first-person arms, posed onto each gun. The source mesh is in its own
## unit scale; attach() scales it so the wrist is about as wide as a magazine.


const ARMS_SCENE := preload("res://assets/weapons/cc0/fps_arms.glb")
## Mean radial thickness of the wrist in the source mesh.
const SOURCE_WRIST_R := 0.30


static func attach(parent: Node3D, grip: Vector3, support: Vector3, style: String) -> void:
	var rig := ARMS_SCENE.instantiate()
	rig.name = "FPArms"
	parent.add_child(rig)
	var skel := rig.find_child("Skeleton3D", true, false) as Skeleton3D
	var mesh := rig.find_child("arms_mesh", true, false) as MeshInstance3D
	if skel == null:
		return
	# Wrist diameter tracks the gun. Grip-to-support is the handguard span on long guns.
	var span := grip.distance_to(support)
	var wrist_d := clampf(span * 0.16, 0.034, 0.055)
	if style == "pistol":
		wrist_d = 0.032
	elif style == "bow" or style == "melee" or style == "bat":
		wrist_d = 0.036
	var scale := wrist_d / (SOURCE_WRIST_R * 2.0)
	var arms := skel.get_parent() as Node3D
	arms.scale = Vector3.ONE * scale
	if mesh:
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mesh.extra_cull_margin = 8.0
		mesh.custom_aabb = AABB(Vector3(-8, -8, -8), Vector3(16, 16, 16))
	skel.set_meta("fp_scale", scale)
	skel.set_meta("fp_style", style)
	skel.set_meta("fp_grip", grip)
	_pose(skel, grip, support, style)


static func set_left(skel: Skeleton3D, support: Vector3) -> void:
	if skel == null or not skel.has_meta("fp_scale"):
		return
	var style := str(skel.get_meta("fp_style"))
	if style == "throw":
		return
	var scale := float(skel.get_meta("fp_scale"))
	var grip: Vector3 = skel.get_meta("fp_grip")
	_pose_arm(skel, "l", _left_wrist(support, style) / scale, _left_fingers(style), _left_palm(style), -1.0)
	_curl(skel, "l", 0.9 if style != "pistol" else 0.5, 1.25)
	# Right arm is left where attach() put it. Re-assert the grip so a reload can't drift it.
	_pose_arm(skel, "r", _right_wrist(grip, style) / scale, _right_fingers(style), _right_palm(style), 1.0)
	_curl(skel, "r", 1.0, 1.35 if style != "pistol" else 1.5)


static func _pose(skel: Skeleton3D, grip: Vector3, support: Vector3, style: String) -> void:
	var scale := float(skel.get_meta("fp_scale"))
	_pose_arm(skel, "r", _right_wrist(grip, style) / scale, _right_fingers(style), _right_palm(style), 1.0)
	_curl(skel, "r", 1.0 if style != "melee" and style != "bat" else 1.2, 1.35 if style != "pistol" else 1.5)
	if style == "throw":
		_park(skel, "l", Vector3(-2.0, -6.0, 2.0))
		return
	_pose_arm(skel, "l", _left_wrist(support, style) / scale, _left_fingers(style), _left_palm(style), -1.0)
	_curl(skel, "l", 1.3, 1.7)


static func _right_wrist(grip: Vector3, style: String) -> Vector3:
	# Sit the wrist on the camera side of the grip, slightly right, so the palm
	# wraps the grip instead of spawning inside the receiver.
	if style == "melee" or style == "bat":
		return grip + Vector3(0.02, 0.0, 0.03)
	if style == "pistol":
		return grip + Vector3(0.04, -0.01, 0.03)
	# Onto the grip from the camera side. +Z is toward the stock.
	return grip + Vector3(0.0, 0.02, 0.045)


static func _left_wrist(support: Vector3, style: String) -> Vector3:
	if style == "pistol":
		return support + Vector3(0.0, -0.015, 0.03)
	if style == "bow":
		return support + Vector3(-0.015, 0.0, 0.03)
	if style == "melee" or style == "bat":
		return support + Vector3(0.015, 0.0, 0.03)
	# Palm under the handguard. The fingers point up onto the barrel.
	return support + Vector3(0.0, -0.02, 0.012)


static func _right_fingers(style: String) -> Vector3:
	if style == "melee" or style == "bat":
		return Vector3(-0.2, -0.15, -1.0)
	# Into the grip: down and toward the muzzle.
	return Vector3(0.05, -0.55, -1.0)


static func _right_palm(style: String) -> Vector3:
	if style == "pistol":
		return Vector3(0.85, 0.1, 0.35)
	return Vector3(1.0, 0.15, 0.0)


static func _left_fingers(style: String) -> Vector3:
	if style == "bow" or style == "melee" or style == "bat":
		return Vector3(0.2, -0.2, -1.0)
	if style == "pistol":
		return Vector3(0.1, -0.8, -0.35)
	# Up and over the handguard so the curled fingers close on the barrel.
	return Vector3(-0.05, 1.0, -0.2)


static func _left_palm(style: String) -> Vector3:
	if style == "pistol" or style == "bow":
		return Vector3(-0.7, 0.2, 0.4)
	return Vector3(-1.0, 0.15, 0.1)


static func _pose_arm(skel: Skeleton3D, side: String, wrist: Vector3, finger_dir: Vector3, palm_dir: Vector3, pole_sign: float) -> void:
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
	# Elbows sit below and outboard, and slightly away from the camera, so aiming
	# down the barrel does not blow the forearms up into the lens.
	var drop := Vector3(0.78 * pole_sign, -1.05, -0.42).normalized()
	var shoulder := wrist + drop * (upper_len + fore_len) * 0.92
	var pole := Vector3(pole_sign, -0.2, -0.65)
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
	# Local pose rotations were not reaching the skin once the wrist had a global
	# override. Chain the same override down each finger so the curl is visible.
	skel.force_update_all_bone_transforms()
	var wrist := skel.find_bone("wrist." + side)
	if wrist < 0:
		return
	var wrist_g := skel.get_bone_global_pose(wrist)
	# Right fingers close around local Z. The left hand needs both axes: its mirror
	# sends a single-axis curl edge-on to the camera, which reads as an open palm.
	for digit in ["index", "middle", "ring", "pinky"]:
		var bend := index_amt if digit == "index" and side == "r" else amt
		var parent_g := wrist_g
		for joint in [1, 2, 3]:
			var falloff := 1.0 if joint == 1 else (0.85 if joint == 2 else 0.55)
			var euler := Vector3(bend * falloff, 0.0, bend * falloff) if side == "l" else Vector3(0.0, 0.0, -bend * falloff)
			parent_g = _bend_global(skel, "finger_%s%d.%s" % [digit, joint, side], parent_g, euler)
	var thumb_g := wrist_g
	var thumb_euler := Vector3(0.9, 0.0, 0.9) if side == "l" else Vector3(0.0, 0.0, -0.5)
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


static func _park(skel: Skeleton3D, side: String, at: Vector3) -> void:
	var upper := skel.find_bone("bicep." + side)
	if upper >= 0:
		skel.set_bone_global_pose_override(upper, Transform3D(Basis.IDENTITY, at), 1.0, true)
