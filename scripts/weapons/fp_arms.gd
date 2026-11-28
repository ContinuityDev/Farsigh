class_name FpArms
extends RefCounted
## Skinned first-person arms. Tubes are bound to one bone each, so the grip
## pose is a real skeleton pose instead of floating capsules.


static func attach(parent: Node3D, grip: Vector3, support: Vector3, style: String) -> void:
	var skel := Skeleton3D.new()
	skel.name = "FPArms"
	parent.add_child(skel)
	var built := _build_skeleton(skel)
	var mesh := _build_mesh(skel, built)
	skel.add_child(mesh)
	_pose(skel, built, grip, support, style)
	skel.set_meta("fp_built", built)
	skel.set_meta("fp_style", style)
	skel.set_meta("fp_support", support)


static func set_left(skel: Skeleton3D, support: Vector3) -> void:
	## Move only the support hand. The right hand stays on the grip.
	if skel == null or not skel.has_meta("fp_built"):
		return
	var built: Dictionary = skel.get_meta("fp_built")
	var style := str(skel.get_meta("fp_style"))
	if style == "throw":
		return
	var pistol := style == "pistol"
	var shaft := style == "melee" or style == "bat"
	var l_wrist: Vector3
	var l_basis: Basis
	if pistol or style == "bow":
		l_wrist = support + Vector3(-0.02, -0.016, 0.06)
		l_basis = _grip_basis()
	elif shaft:
		l_wrist = support + Vector3(-0.016, 0.012, 0.05)
		l_basis = _shaft_basis(-1.0)
	else:
		l_wrist = support + Vector3(0.0, 0.032, 0.06)
		l_basis = _handguard_basis()
	var l_reach: float = float(built["l_upper_len"]) + float(built["l_fore_len"])
	var l_shoulder: Vector3 = l_wrist + Vector3(-0.45, -1.15, 0.32).normalized() * l_reach * 0.93
	_solve_arm(skel, int(built["l_upper"]), int(built["l_fore"]), int(built["l_hand"]), l_shoulder, l_wrist, Vector3(-0.35, -0.15, 0.2), float(built["l_upper_len"]), float(built["l_fore_len"]), l_basis)


static func _pose(skel: Skeleton3D, built: Dictionary, grip: Vector3, support: Vector3, style: String) -> void:
	var two := style != "throw"
	var shaft := style == "melee" or style == "bat"
	var pistol := style == "pistol"
	var r_basis := _shaft_basis(1.0) if shaft else _grip_basis()
	# Wrist sits on the camera side of the grip (+Z) so the glove is in front of the gun.
	var r_wrist: Vector3 = grip + (Vector3(0.02, -0.02, 0.055) if shaft else Vector3(0.03, -0.028, 0.07))
	var r_reach: float = built["r_upper_len"] + built["r_fore_len"]
	var r_shoulder: Vector3 = r_wrist + Vector3(0.45, -1.15, 0.35).normalized() * r_reach * 0.93
	_solve_arm(skel, built["r_upper"], built["r_fore"], built["r_hand"], r_shoulder, r_wrist, Vector3(0.35, -0.15, 0.2), built["r_upper_len"], built["r_fore_len"], r_basis)
	_curl_hand(skel, "r", 0.45 if not shaft else 0.9, 1.15 if not pistol else 1.25)
	if not two:
		_park(skel, built["l_upper"], Vector3(-0.4, -1.6, 0.8))
		return
	var l_wrist: Vector3
	var l_basis: Basis
	if pistol:
		l_wrist = support + Vector3(-0.02, -0.016, 0.06)
		l_basis = _grip_basis()
	elif style == "bow":
		l_wrist = support + Vector3(-0.016, 0.0, 0.055)
		l_basis = _grip_basis()
	elif shaft:
		l_wrist = support + Vector3(-0.016, 0.012, 0.05)
		l_basis = _shaft_basis(-1.0)
	else:
		l_wrist = support + Vector3(0.0, 0.032, 0.06)
		l_basis = _handguard_basis()
	var l_reach: float = built["l_upper_len"] + built["l_fore_len"]
	var l_shoulder: Vector3 = l_wrist + Vector3(-0.45, -1.15, 0.32).normalized() * l_reach * 0.93
	_solve_arm(skel, built["l_upper"], built["l_fore"], built["l_hand"], l_shoulder, l_wrist, Vector3(-0.35, -0.15, 0.2), built["l_upper_len"], built["l_fore_len"], l_basis)
	_curl_hand(skel, "l", 0.85, 1.05)


static func _grip_basis() -> Basis:
	# Curl axis runs up the pistol grip. Fingers start pointing forward and close to the left.
	var x := Vector3.UP
	var y := Vector3(0, 0, -1)
	return Basis(x, y, x.cross(y).normalized())


static func _handguard_basis() -> Basis:
	# Curl axis runs along the barrel. Fingers start on the left and close over the top.
	var x := Vector3(0, 0, -1)
	var y := Vector3(-1, 0, 0)
	return Basis(x, y, x.cross(y).normalized())


static func _shaft_basis(side: float) -> Basis:
	# Melee handles point forward. The palm faces inward and the fingers close under the shaft.
	var x := Vector3(0, 0, -1)
	var y := Vector3(0, -1, 0)
	var z := x.cross(y).normalized()
	if side < 0.0:
		y = Vector3(0, 1, 0)
		z = x.cross(y).normalized()
	return Basis(x, y, z)


static func _solve_arm(skel: Skeleton3D, upper: int, fore: int, hand: int, shoulder: Vector3, wrist: Vector3, pole: Vector3, upper_len: float, fore_len: float, hand_basis: Basis) -> void:
	var elbow := _elbow(shoulder, wrist, pole, upper_len, fore_len)
	var up_basis := _y_basis(skel.get_bone_global_rest(upper).basis, shoulder, elbow)
	var fore_basis := _y_basis(skel.get_bone_global_rest(fore).basis, elbow, wrist)
	skel.set_bone_global_pose_override(upper, Transform3D(up_basis, shoulder), 1.0, true)
	skel.set_bone_global_pose_override(fore, Transform3D(fore_basis, elbow), 1.0, true)
	skel.set_bone_global_pose_override(hand, Transform3D(hand_basis, wrist), 1.0, true)


static func _y_basis(hint: Basis, origin: Vector3, target: Vector3) -> Basis:
	var y := target - origin
	if y.length_squared() < 0.000001:
		return hint
	y = y.normalized()
	var x := hint.x
	if absf(x.dot(y)) > 0.92:
		x = hint.z
	var z := x.cross(y)
	if z.length_squared() < 0.000001:
		z = Vector3.UP.cross(y)
	z = z.normalized()
	x = y.cross(z).normalized()
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


static func _curl_hand(skel: Skeleton3D, side: String, trigger: float, curl: float) -> void:
	for digit in ["index", "middle", "ring", "pinky"]:
		var bends: Array[float] = [curl, curl, curl * 0.8]
		if digit == "index" and side == "r":
			bends = [trigger, trigger * 1.25, trigger * 1.5]
		for joint in [1, 2, 3]:
			_bend(skel, "%s_%s_%d" % [side, digit, joint], bends[joint - 1])
	_bend(skel, "%s_thumb_1" % side, 0.65)
	_bend(skel, "%s_thumb_2" % side, 0.5)


static func _bend(skel: Skeleton3D, bone: String, amount: float) -> void:
	var idx := skel.find_bone(bone)
	if idx < 0:
		return
	var rest := skel.get_bone_rest(idx).basis.get_rotation_quaternion()
	skel.set_bone_pose_rotation(idx, rest * Quaternion.from_euler(Vector3(amount, 0.0, 0.0)))


static func _park(skel: Skeleton3D, bone: int, at: Vector3) -> void:
	skel.set_bone_global_pose_override(bone, Transform3D(Basis.IDENTITY, at), 1.0, true)


static func _build_skeleton(skel: Skeleton3D) -> Dictionary:
	var info := {}
	for side in ["r", "l"]:
		var sign := 1.0 if side == "r" else -1.0
		var upper_len := 0.18
		var fore_len := 0.16
		var shoulder := Vector3(0.16 * sign, -0.18, 0.05)
		var elbow := shoulder + Vector3(-0.04 * sign, 0.18, -0.03).normalized() * upper_len
		var wrist := elbow + Vector3(-0.05 * sign, 0.12, -0.08).normalized() * fore_len
		var upper := _add_bone(skel, "%s_upper" % side, -1, _look(shoulder, elbow))
		var fore := _add_bone(skel, "%s_fore" % side, upper, _look(elbow, wrist))
		var hand_basis := _grip_basis() if side == "r" else _handguard_basis()
		var hand := _add_bone(skel, "%s_hand" % side, fore, Transform3D(hand_basis, wrist))
		_add_fingers(skel, side, hand)
		info["%s_upper" % side] = upper
		info["%s_fore" % side] = fore
		info["%s_hand" % side] = hand
		info["%s_upper_len" % side] = upper_len
		info["%s_fore_len" % side] = fore_len
	return info


static func _add_fingers(skel: Skeleton3D, side: String, hand: int) -> void:
	var names := ["index", "middle", "ring", "pinky"]
	for i in names.size():
		var along := 0.04 - float(i) * 0.016
		var prev := hand
		var local := Transform3D(Basis.IDENTITY, Vector3(0.0, along, 0.03))
		for joint in [1, 2, 3]:
			var length := 0.028 if joint == 1 else 0.022
			var idx := _add_bone(skel, "%s_%s_%d" % [side, names[i], joint], prev, local)
			prev = idx
			local = Transform3D(Basis.IDENTITY, Vector3(0.0, length, 0.0))
	var thumb_aim := Vector3(0.72, 0.2, 0.55).normalized()
	var t1 := _add_bone(skel, "%s_thumb_1" % side, hand, Transform3D(_aim_basis(thumb_aim), Vector3(0.006, 0.018, 0.01)))
	_add_bone(skel, "%s_thumb_2" % side, t1, Transform3D(Basis.IDENTITY, Vector3(0.0, 0.026, 0.0)))


static func _aim_basis(y: Vector3) -> Basis:
	y = y.normalized()
	var x := y.cross(Vector3(0, 0, 1))
	if x.length_squared() < 0.0004:
		x = y.cross(Vector3.RIGHT)
	x = x.normalized()
	return Basis(x, y, x.cross(y).normalized())


static func _look(origin: Vector3, target: Vector3) -> Transform3D:
	return Transform3D(_aim_basis((target - origin).normalized() if origin.distance_squared_to(target) > 0.000001 else Vector3.UP), origin)


static func _add_bone(skel: Skeleton3D, bone_name: String, parent: int, local: Transform3D) -> int:
	var idx := skel.add_bone(bone_name)
	if parent >= 0:
		skel.set_bone_parent(idx, parent)
	skel.set_bone_rest(idx, local)
	return idx


static func _build_mesh(skel: Skeleton3D, built: Dictionary) -> MeshInstance3D:
	var sleeve := _Surf.new()
	var glove := _Surf.new()
	var skin := _Surf.new()
	for side in ["r", "l"]:
		_limb(skel, sleeve, built["%s_upper" % side], built["%s_fore" % side], 0.030, 0.026, 0.04)
		_limb(skel, sleeve, built["%s_fore" % side], built["%s_hand" % side], 0.026, 0.022, 0.11)
		_band(skel, skin, built["%s_hand" % side], -0.012, 0.018, 0.016)
		_palm(skel, glove, built["%s_hand" % side])
		for digit in ["index", "middle", "ring", "pinky"]:
			var a := skel.find_bone("%s_%s_1" % [side, digit])
			var b := skel.find_bone("%s_%s_2" % [side, digit])
			var c := skel.find_bone("%s_%s_3" % [side, digit])
			_limb(skel, glove, a, b, 0.014, 0.012, 0.005)
			_limb(skel, glove, b, c, 0.012, 0.010, 0.005)
			_tip(skel, glove, c, 0.022, 0.010)
		var th1 := skel.find_bone("%s_thumb_1" % side)
		var th2 := skel.find_bone("%s_thumb_2" % side)
		_limb(skel, glove, th1, th2, 0.013, 0.011, 0.004)
		_tip(skel, glove, th2, 0.022, 0.010)
	var mesh := ArrayMesh.new()
	sleeve.commit(mesh)
	glove.commit(mesh)
	skin.commit(mesh)
	var binds := Skin.new()
	for i in skel.get_bone_count():
		binds.add_bind(i, skel.get_bone_global_rest(i).affine_inverse())
	var mi := MeshInstance3D.new()
	mi.name = "ArmMesh"
	mi.mesh = mesh
	mi.skin = binds
	mi.skeleton = NodePath("..")
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.extra_cull_margin = 8.0
	mi.custom_aabb = AABB(Vector3(-1.6, -1.6, -1.6), Vector3(3.2, 3.2, 3.2))
	mi.set_surface_override_material(0, _sleeve_mat())
	mi.set_surface_override_material(1, _glove_mat())
	mi.set_surface_override_material(2, _skin_mat())
	return mi


static func _limb(skel: Skeleton3D, surf: _Surf, bone: int, child: int, r0: float, r1: float, overlap: float = 0.02) -> void:
	var a: Vector3 = skel.get_bone_global_rest(bone).origin
	var b: Vector3 = skel.get_bone_global_rest(child).origin
	var dir := b - a
	if dir.length_squared() < 0.000001:
		return
	var n := dir.normalized()
	# Sleeves overlap the wrist. Finger segments stay short so they read as separate digits.
	_tube(surf, bone, a - n * minf(overlap, 0.04), b + n * overlap, r0, r1)


static func _band(skel: Skeleton3D, surf: _Surf, bone: int, along: float, radius: float, length: float) -> void:
	var rest := skel.get_bone_global_rest(bone)
	var y := rest.basis.y.normalized()
	var origin: Vector3 = rest.origin + y * along
	_tube(surf, bone, origin, origin + y * length, radius, radius)


static func _tip(skel: Skeleton3D, surf: _Surf, bone: int, length: float, radius: float) -> void:
	var rest := skel.get_bone_global_rest(bone)
	var y := rest.basis.y.normalized()
	var origin: Vector3 = rest.origin
	_tube(surf, bone, origin, origin + y * length, radius, radius * 0.45)


static func _palm(skel: Skeleton3D, surf: _Surf, hand: int) -> void:
	var rest := skel.get_bone_global_rest(hand)
	var center: Vector3 = rest.origin + rest.basis.y * 0.008 + rest.basis.z * 0.008
	_box(surf, hand, center, rest.basis.x.normalized() * 0.014, rest.basis.y.normalized() * 0.016, rest.basis.z.normalized() * 0.012)


static func _tube(surf: _Surf, bone: int, a: Vector3, b: Vector3, r0: float, r1: float) -> void:
	var dir := b - a
	if dir.length_squared() < 0.000001:
		return
	var y := dir.normalized()
	var x := y.cross(Vector3.UP)
	if x.length_squared() < 0.0004:
		x = y.cross(Vector3.RIGHT)
	x = x.normalized()
	var z := x.cross(y).normalized()
	var sides := 8
	var base := surf.verts.size()
	for ring in 2:
		var t := float(ring)
		var center := a.lerp(b, t)
		var radius := lerpf(r0, r1, t)
		for s in sides:
			var ang := TAU * float(s) / float(sides)
			var nrm := (x * cos(ang) + z * sin(ang)).normalized()
			surf.verts.append(center + nrm * radius)
			surf.norms.append(nrm)
			surf.uvs.append(Vector2(float(s) / float(sides) * 2.0, t * 5.0))
			surf.bone(bone)
	for s in sides:
		var s2 := (s + 1) % sides
		surf.quad(base + s, base + s2, base + sides + s2, base + sides + s)
	_fan(surf, bone, b, y, x, z, r1, sides, false)
	_fan(surf, bone, a, -y, x, z, r0, sides, true)


static func _fan(surf: _Surf, bone: int, center: Vector3, normal: Vector3, x: Vector3, z: Vector3, radius: float, sides: int, flip: bool) -> void:
	var hub := surf.verts.size()
	surf.verts.append(center)
	surf.norms.append(normal.normalized())
	surf.uvs.append(Vector2(0.5, 0.5))
	surf.bone(bone)
	var ring := surf.verts.size()
	for s in sides:
		var ang := TAU * float(s) / float(sides)
		var nrm := (x * cos(ang) + z * sin(ang)).normalized()
		surf.verts.append(center + nrm * radius)
		surf.norms.append(normal.normalized())
		surf.uvs.append(Vector2(0.5 + cos(ang) * 0.5, 0.5 + sin(ang) * 0.5))
		surf.bone(bone)
	for s in sides:
		var s2 := (s + 1) % sides
		if flip:
			surf.tri(hub, ring + s2, ring + s)
		else:
			surf.tri(hub, ring + s, ring + s2)


static func _box(surf: _Surf, bone: int, center: Vector3, ax: Vector3, ay: Vector3, az: Vector3) -> void:
	var corners: Array[Vector3] = []
	for ix in [-1.0, 1.0]:
		for iy in [-1.0, 1.0]:
			for iz in [-1.0, 1.0]:
				corners.append(center + ax * ix + ay * iy + az * iz)
	var faces := [
		[0, 1, 3, 2], [4, 6, 7, 5],
		[0, 4, 5, 1], [2, 3, 7, 6],
		[0, 2, 6, 4], [1, 5, 7, 3],
	]
	for face in faces:
		var i0: int = face[0]
		var i1: int = face[1]
		var i2: int = face[2]
		var i3: int = face[3]
		var nrm: Vector3 = ((corners[i1] - corners[i0]).cross(corners[i3] - corners[i0])).normalized()
		var base := surf.verts.size()
		for corner_i in [i0, i1, i2, i3]:
			surf.verts.append(corners[corner_i])
			surf.norms.append(nrm)
			surf.uvs.append(Vector2(0.2, 0.8))
			surf.bone(bone)
		surf.quad(base, base + 1, base + 2, base + 3)


static func _sleeve_mat() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.72, 0.64, 0.60)
	mat.albedo_texture = load("res://assets/textures/weapons/flannel.png")
	mat.roughness = 0.86
	mat.metallic = 0.0
	mat.uv1_scale = Vector3(2.2, 2.6, 2.2)
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	return mat


static func _glove_mat() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	# Flat leather, so the fingers do not pick up the gun's mottled polymer texture.
	mat.albedo_color = Color(0.62, 0.40, 0.22)
	mat.roughness = 0.78
	mat.metallic = 0.0
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	return mat


static func _skin_mat() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.82, 0.62, 0.48)
	mat.albedo_texture = load("res://assets/textures/weapons/skin.png")
	mat.roughness = 0.62
	mat.metallic = 0.0
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	return mat


class _Surf:
	var verts: PackedVector3Array = PackedVector3Array()
	var norms: PackedVector3Array = PackedVector3Array()
	var uvs: PackedVector2Array = PackedVector2Array()
	var idx: PackedInt32Array = PackedInt32Array()
	var bones: PackedInt32Array = PackedInt32Array()
	var weights: PackedFloat32Array = PackedFloat32Array()

	func bone(bone_idx: int) -> void:
		bones.append_array(PackedInt32Array([bone_idx, 0, 0, 0]))
		weights.append_array(PackedFloat32Array([1.0, 0.0, 0.0, 0.0]))

	func tri(a: int, b: int, c: int) -> void:
		idx.append_array(PackedInt32Array([a, b, c]))

	func quad(a: int, b: int, c: int, d: int) -> void:
		tri(a, b, c)
		tri(a, c, d)

	func commit(mesh: ArrayMesh) -> void:
		if verts.is_empty():
			return
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = verts
		arrays[Mesh.ARRAY_NORMAL] = norms
		arrays[Mesh.ARRAY_TEX_UV] = uvs
		arrays[Mesh.ARRAY_INDEX] = idx
		arrays[Mesh.ARRAY_BONES] = bones
		arrays[Mesh.ARRAY_WEIGHTS] = weights
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
