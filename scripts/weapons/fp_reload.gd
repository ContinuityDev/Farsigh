class_name FpReload
extends RefCounted
## Reload poses as a function of progress, so the viewmodel and the ammo
## counter share one clock. Progress is 0 at the start and 1 at the end.


static func commit_at(kind: String, empty: bool) -> float:
	if kind == "shell":
		return 0.62
	if kind == "arrow":
		return 0.8
	if empty:
		return 0.9
	return 0.74


static func sample(kind: String, p: float, empty: bool) -> Dictionary:
	p = clampf(p, 0.0, 1.0)
	if kind == "shell":
		return _shell(p)
	if kind == "arrow":
		return _arrow(p)
	return _mag(p, empty)


static func _mag(p: float, empty: bool) -> Dictionary:
	var tilt_out := _smooth(0.0, 0.12, p)
	var tilt_back := 1.0 - _smooth(0.9 if empty else 0.8, 1.0, p)
	var tilt := minf(tilt_out, tilt_back)
	var pos := Vector3(-0.045 * tilt, -0.04 * tilt, 0.02 * tilt)
	var rot := Vector3(-18.0 * tilt, 4.0 * tilt, 22.0 * tilt)
	var stage := "back"
	var u := 1.0
	if p < 0.16:
		stage = "to_well"
		u = _smooth(0.0, 0.16, p)
	elif p < 0.38:
		stage = "to_low"
		u = _smooth(0.16, 0.38, p)
	elif p < 0.48:
		stage = "drop"
		u = _smooth(0.38, 0.48, p)
	elif p < 0.72:
		stage = "to_seat"
		u = _smooth(0.48, 0.72, p)
	elif empty and p < 0.9:
		stage = "charge"
		u = _smooth(0.72, 0.9, p)
		# The support hand hauls the handle back, then lets it go.
		var haul := sin(u * PI)
		pos.z += 0.03 * haul
		rot.y += 8.0 * haul
	else:
		stage = "back"
		u = _smooth(0.9 if empty else 0.72, 1.0, p)
	return {"pos": pos, "rot": rot, "stage": stage, "u": u}


static func _shell(p: float) -> Dictionary:
	var tilt := _hold(p, 0.0, 0.12, 0.78, 1.0)
	var pos := Vector3(0.02 * tilt, -0.03 * tilt, 0.015 * tilt)
	var rot := Vector3(8.0 * tilt, -6.0 * tilt, -28.0 * tilt)
	var stage := "back"
	var u := 1.0
	if p < 0.22:
		stage = "to_port"
		u = _smooth(0.0, 0.22, p)
	elif p < 0.62:
		stage = "insert"
		u = _smooth(0.22, 0.62, p)
	else:
		stage = "back"
		u = _smooth(0.62, 1.0, p)
	return {"pos": pos, "rot": rot, "stage": stage, "u": u}


static func _arrow(p: float) -> Dictionary:
	var tilt := _hold(p, 0.0, 0.1, 0.84, 1.0)
	var pos := Vector3(0.03 * tilt, -0.02 * tilt, 0.04 * tilt)
	var rot := Vector3(0.0, -10.0 * tilt, 6.0 * tilt)
	var stage := "back"
	var u := 1.0
	if p < 0.28:
		stage = "reach"
		u = _smooth(0.0, 0.28, p)
	elif p < 0.8:
		stage = "nock"
		u = _smooth(0.28, 0.8, p)
	else:
		stage = "back"
		u = _smooth(0.8, 1.0, p)
	return {"pos": pos, "rot": rot, "stage": stage, "u": u}


static func _smooth(a: float, b: float, p: float) -> float:
	var t := clampf((p - a) / maxf(0.0001, b - a), 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)


static func _hold(p: float, a: float, b: float, c: float, d: float) -> float:
	return minf(_smooth(a, b, p), 1.0 - _smooth(c, d, p))
