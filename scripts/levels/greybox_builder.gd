extends Node3D
## Hope County–style outpost compound: hollow buildings, watchtower, parked
## vehicles, wooden supply crates, fuel drums, sandbag walls, Montana pines,
## and Kenney CC0 foliage/barricade accents. Low-poly & cached-material for WebGL.

const KENNEY_GRASS: PackedScene = preload("res://assets/kenney/grass.glb")
const KENNEY_GRASS_SMALL: PackedScene = preload("res://assets/kenney/grass-small.glb")
const KENNEY_WALL_LOW: PackedScene = preload("res://assets/kenney/wall-low.glb")


func _ready() -> void:
	_build()


func _build() -> void:
	_terrain_and_roads()
	_perimeter()
	_buildings()
	_courtyard_cover()
	_vehicles()
	_watchtower()
	_approach_cover()
	_trees_and_foliage()


func _terrain_and_roads() -> void:
	# Grassy valley floor
	_box(Vector3(0, -0.5, 0), Vector3(130, 1.0, 130), Color(0.24, 0.31, 0.20), true)
	# Packed gravel compound courtyard
	_box(Vector3(0, 0.015, 0), Vector3(47, 0.03, 47), Color(0.37, 0.35, 0.30), false)
	# Dirt approach road through south gate toward HQ
	_box(Vector3(0, 0.025, 16), Vector3(6.0, 0.03, 38), Color(0.42, 0.36, 0.27), false)
	_box(Vector3(-12, 0.025, 2), Vector3(30, 0.03, 4.4), Color(0.42, 0.36, 0.27), false)
	# Soft approach berms outside the fence
	_box(Vector3(-8, 0.38, 32), Vector3(14, 0.76, 6), Color(0.26, 0.33, 0.22))
	_box(Vector3(9, 0.38, 32), Vector3(14, 0.76, 6), Color(0.26, 0.33, 0.22))
	_box(Vector3(-29, 0.35, 0), Vector3(6, 0.7, 14), Color(0.26, 0.33, 0.22))
	_box(Vector3(8, 0.3, -30), Vector3(12, 0.6, 5), Color(0.26, 0.33, 0.22))


func _perimeter() -> void:
	var h := 3.0
	var t := 0.45
	var s := 24.0
	var wall_col := Color(0.39, 0.40, 0.37)
	var post_col := Color(0.24, 0.25, 0.23)

	# South wall — main gate gap around x=0
	_fence_segment(Vector3(-12, 0, s), Vector3(16, h, t), wall_col, post_col)
	_fence_segment(Vector3(12, 0, s), Vector3(16, h, t), wall_col, post_col)
	# Main gate steel archway overhead
	_box(Vector3(-4.0, 2.3, s), Vector3(0.4, 4.6, 0.4), post_col)
	_box(Vector3(4.0, 2.3, s), Vector3(0.4, 4.6, 0.4), post_col)
	_box(Vector3(0.0, 4.45, s), Vector3(8.6, 0.35, 0.45), Color(0.48, 0.24, 0.16), false)
	# Gate floodlight lamp (emissive accent)
	var lamp := ProcMesh.box_mesh(Vector3(0.8, 0.18, 0.22), Color(1.0, 0.85, 0.55))
	lamp.material_override = ProcMesh.emissive(Color(1.0, 0.82, 0.45), 1.6)
	ProcMesh.add_part(self, lamp, Vector3(0, 4.2, s + 0.22))

	# North wall — service gap around x=6
	_fence_segment(Vector3(-10, 0, -s), Vector3(18, h, t), wall_col, post_col)
	_fence_segment(Vector3(14, 0, -s), Vector3(12, h, t), wall_col, post_col)
	# West wall — breach around z=2
	_fence_segment(Vector3(-s, 0, -12), Vector3(t, h, 18), wall_col, post_col)
	_fence_segment(Vector3(-s, 0, 14), Vector3(t, h, 16), wall_col, post_col)
	# East wall — solid
	_fence_segment(Vector3(s, 0, 0), Vector3(t, h, 48), wall_col, post_col)

	# Concrete corner pillars
	for p in [
		Vector3(-s, 1.75, -s), Vector3(s, 1.75, -s), Vector3(-s, 1.75, s), Vector3(s, 1.75, s)
	]:
		_box(p, Vector3(1.15, 3.5, 1.15), Color(0.32, 0.33, 0.31))
		_box(p + Vector3(0, 1.85, 0), Vector3(1.3, 0.2, 1.3), post_col, false)


func _fence_segment(base_center: Vector3, size: Vector3, wall_col: Color, post_col: Color) -> void:
	_box(base_center + Vector3(0, size.y * 0.5, 0), size, wall_col, true)
	# Top dark metal trim / barbed-wire frame rail
	var top_size := Vector3(size.x, 0.18, size.z + 0.12) if size.x >= size.z else Vector3(size.x + 0.12, 0.18, size.z)
	_box(base_center + Vector3(0, size.y + 0.08, 0), top_size, post_col, false)


func _buildings() -> void:
	# Barracks — west, hollow with south doorway
	_hollow_building(Vector3(-11, 0, -4), Vector3(9, 3.6, 7), Color(0.44, 0.42, 0.38), Color(0.30, 0.25, 0.20), "S")
	# Armory — east, hollow with west doorway facing courtyard
	_hollow_building(Vector3(12, 0, -6), Vector3(7, 3.4, 9), Color(0.42, 0.39, 0.35), Color(0.28, 0.30, 0.28), "W")
	# HQ / radio — north-central, alarm sits nearby; doorway south into yard
	_hollow_building(Vector3(1, 0, -14), Vector3(11, 3.8, 7), Color(0.38, 0.41, 0.43), Color(0.26, 0.24, 0.22), "S")
	# Radio antenna mast on HQ roof with blinking-style glowing red beacon
	var mast_base := Vector3(4.5, 3.9, -14.5)
	ProcMesh.add_part(self, ProcMesh.cylinder_mesh(0.08, 5.2, Color(0.26, 0.27, 0.29), 0.5, 0.6, 8), mast_base + Vector3(0, 2.6, 0))
	ProcMesh.add_part(self, ProcMesh.box_mesh(Vector3(1.8, 0.08, 0.08), Color(0.3, 0.3, 0.32)), mast_base + Vector3(0, 4.2, 0))
	ProcMesh.add_part(self, ProcMesh.box_mesh(Vector3(0.08, 0.08, 1.4), Color(0.3, 0.3, 0.32)), mast_base + Vector3(0, 3.4, 0))
	var beacon := ProcMesh.sphere_mesh(0.14, Color(1.0, 0.15, 0.1))
	beacon.material_override = ProcMesh.emissive(Color(1.0, 0.18, 0.1), 2.4)
	ProcMesh.add_part(self, beacon, mast_base + Vector3(0, 5.25, 0))

	# Garage lean-to — southeast cover nest
	_hollow_building(Vector3(10, 0, 12), Vector3(8, 2.9, 5), Color(0.40, 0.38, 0.34), Color(0.32, 0.22, 0.18), "N")

	# Interior cover tables & supply crates
	_crate(Vector3(-11, 0, -4), 1.15, 0.0)
	_crate(Vector3(12, 0, -6), 1.15, 90.0)
	_box(Vector3(1, 0.55, -14), Vector3(3.0, 1.1, 0.7), Color(0.35, 0.27, 0.19))


func _hollow_building(pos: Vector3, size: Vector3, wall_col: Color, roof_col: Color, door: String) -> void:
	var wall_t := 0.35
	var hx := size.x * 0.5
	var hz := size.z * 0.5
	var h := size.y
	# Concrete foundation slab
	_box(pos + Vector3(0, 0.06, 0), Vector3(size.x + 0.3, 0.12, size.z + 0.3), Color(0.30, 0.31, 0.30))
	# Corrugated metal roof overhang + ridge beam
	_box(pos + Vector3(0, h + 0.08, 0), Vector3(size.x + 0.7, 0.24, size.z + 0.7), roof_col)
	_box(pos + Vector3(0, h + 0.28, 0), Vector3(size.x + 0.2, 0.22, size.z * 0.45), roof_col.darkened(0.1), false)
	# Walls with optional doorway gap
	_wall_with_door(pos, Vector3(0, 0, -hz), Vector3(size.x, h, wall_t), door == "N", wall_col)
	_wall_with_door(pos, Vector3(0, 0, hz), Vector3(size.x, h, wall_t), door == "S", wall_col)
	_wall_with_door(pos, Vector3(-hx, 0, 0), Vector3(wall_t, h, size.z), door == "W", wall_col)
	_wall_with_door(pos, Vector3(hx, 0, 0), Vector3(wall_t, h, size.z), door == "E", wall_col)
	# Decorative dark framed windows on solid faces
	var win_col := Color(0.12, 0.16, 0.19)
	var frame_col := Color(0.24, 0.20, 0.16)
	if door != "S":
		_window_accent(pos + Vector3(0, 2.0, hz + 0.19), Vector3(1.6, 0.9, 0.08), win_col, frame_col)
	if door != "N":
		_window_accent(pos + Vector3(0, 2.0, -hz - 0.19), Vector3(1.6, 0.9, 0.08), win_col, frame_col)


func _window_accent(pos: Vector3, size: Vector3, glass_col: Color, frame_col: Color) -> void:
	ProcMesh.add_part(self, ProcMesh.box_mesh(size + Vector3(0.18, 0.18, 0.02), frame_col), pos)
	ProcMesh.add_part(self, ProcMesh.box_mesh(size, glass_col, 0.2, 0.3), pos + Vector3(0, 0, 0.02))


func _wall_with_door(origin: Vector3, offset: Vector3, size: Vector3, has_door: bool, color: Color) -> void:
	var center := origin + offset + Vector3(0, size.y * 0.5, 0)
	if not has_door:
		_box(center, size, color)
		return
	var door_w := 1.4
	var frame_col := Color(0.24, 0.20, 0.16)
	if size.x >= size.z:
		var remain := (size.x - door_w) * 0.5
		_box(center + Vector3(-(door_w * 0.5 + remain * 0.5), 0, 0), Vector3(remain, size.y, size.z), color)
		_box(center + Vector3(door_w * 0.5 + remain * 0.5, 0, 0), Vector3(remain, size.y, size.z), color)
		_box(center + Vector3(0, size.y * 0.35, 0), Vector3(door_w + 0.1, size.y * 0.3, size.z), color)
		# Doorframe trim
		_box(center + Vector3(-door_w * 0.5, -size.y * 0.15, 0), Vector3(0.12, size.y * 0.7, size.z + 0.08), frame_col, false)
		_box(center + Vector3(door_w * 0.5, -size.y * 0.15, 0), Vector3(0.12, size.y * 0.7, size.z + 0.08), frame_col, false)
	else:
		var remain_z := (size.z - door_w) * 0.5
		_box(center + Vector3(0, 0, -(door_w * 0.5 + remain_z * 0.5)), Vector3(size.x, size.y, remain_z), color)
		_box(center + Vector3(0, 0, door_w * 0.5 + remain_z * 0.5), Vector3(size.x, size.y, remain_z), color)
		_box(center + Vector3(0, size.y * 0.35, 0), Vector3(size.x, size.y * 0.3, door_w + 0.1), color)
		_box(center + Vector3(0, -size.y * 0.15, -door_w * 0.5), Vector3(size.x + 0.08, size.y * 0.7, 0.12), frame_col, false)
		_box(center + Vector3(0, -size.y * 0.15, door_w * 0.5), Vector3(size.x + 0.08, size.y * 0.7, 0.12), frame_col, false)


func _courtyard_cover() -> void:
	# Multi-part wooden supply crates forming stealth lanes
	var crate_specs := [
		[Vector3(-3.2, 0, 6.0), 1.2, 5.0],
		[Vector3(-1.7, 0, 6.3), 1.05, -12.0],
		[Vector3(3.0, 0, 2.0), 1.2, 8.0],
		[Vector3(4.5, 0, 2.2), 1.35, -4.0],
		[Vector3(4.5, 1.35, 2.2), 0.9, 14.0],
		[Vector3(-6.0, 0, -1.0), 1.2, 2.0],
		[Vector3(0.0, 0, -2.0), 1.2, 0.0],
		[Vector3(7.0, 0, 6.0), 1.2, -10.0],
		[Vector3(-8.0, 0, 10.0), 1.2, 15.0],
		[Vector3(2.0, 0, 14.0), 1.15, -6.0],
		[Vector3(-2.0, 0, -8.0), 1.3, 4.0],
	]
	for spec in crate_specs:
		_crate(spec[0], spec[1], spec[2])

	# Stacked sandbag emplacements
	_sandbag_wall(Vector3(-5.0, 0, 3.0), 3.4, 0.0)
	_sandbag_wall(Vector3(5.0, 0, -2.0), 3.0, 90.0)
	_sandbag_wall(Vector3(0.0, 0, 10.0), 3.8, 0.0)

	# Red hazard fuel drums & olive oil barrels (clusters of 1-2)
	_barrel(Vector3(8.0, 0, -10.0), true)
	_barrel(Vector3(8.75, 0, -9.6), false)
	_barrel(Vector3(-9.0, 0, 6.0), true)
	_barrel(Vector3(-8.3, 0, 6.5), true)
	_barrel(Vector3(4.0, 0, 8.0), false)
	_barrel(Vector3(4.7, 0, 8.4), true)
	_barrel(Vector3(-3.8, 0, -11.5), true)


func _crate(base_pos: Vector3, size: float, rot_y_deg: float) -> void:
	var wood := Color(0.50, 0.37, 0.22)
	var trim := Color(0.36, 0.25, 0.14)
	var iron := Color(0.18, 0.19, 0.20)
	var holder := Node3D.new()
	holder.position = base_pos + Vector3(0, size * 0.5, 0)
	holder.rotation_degrees.y = rot_y_deg
	add_child(holder)

	# Main slatted crate body
	ProcMesh.add_part(holder, ProcMesh.box_mesh(Vector3(size * 0.92, size * 0.92, size * 0.92), wood))
	# Raised edge framing bars (top/bottom rims + vertical corner posts)
	var bt := size * 0.11
	ProcMesh.add_part(holder, ProcMesh.box_mesh(Vector3(size, bt, size), trim), Vector3(0, size * 0.45, 0))
	ProcMesh.add_part(holder, ProcMesh.box_mesh(Vector3(size, bt, size), trim), Vector3(0, -size * 0.45, 0))
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			ProcMesh.add_part(holder, ProcMesh.box_mesh(Vector3(bt, size, bt), trim), Vector3(sx * size * 0.45, 0, sz * size * 0.45))
			# Dark iron corner bracket
			ProcMesh.add_part(holder, ProcMesh.box_mesh(Vector3(bt * 1.15, bt * 1.15, bt * 1.15), iron, 0.5, 0.6), Vector3(sx * size * 0.45, size * 0.45, sz * size * 0.45))
	# Diagonal cross-brace on front & back faces
	ProcMesh.add_part(holder, ProcMesh.box_mesh(Vector3(size * 1.1, bt * 0.85, 0.04), trim), Vector3(0, 0, size * 0.47), Vector3(0, 0, 42))
	ProcMesh.add_part(holder, ProcMesh.box_mesh(Vector3(size * 1.1, bt * 0.85, 0.04), trim), Vector3(0, 0, -size * 0.47), Vector3(0, 0, -42))

	_add_box_collider(base_pos + Vector3(0, size * 0.5, 0), Vector3(size, size, size), rot_y_deg)


func _barrel(base_pos: Vector3, is_red_fuel: bool) -> void:
	var body_col := Color(0.68, 0.16, 0.12) if is_red_fuel else Color(0.28, 0.34, 0.24)
	var rib_col := body_col.darkened(0.22)
	var stripe_col := Color(0.92, 0.74, 0.18) if is_red_fuel else Color(0.38, 0.36, 0.30)
	var holder := Node3D.new()
	holder.position = base_pos
	add_child(holder)

	# Cylindrical steel drum (h=1.18, r=0.36)
	ProcMesh.add_part(holder, ProcMesh.cylinder_mesh(0.35, 1.16, body_col, 0.55, 0.45, 10), Vector3(0, 0.58, 0))
	# Rolling ribs & top/bottom rims
	for ry in [0.04, 0.38, 0.78, 1.14]:
		ProcMesh.add_part(holder, ProcMesh.cylinder_mesh(0.375, 0.055, rib_col, 0.5, 0.55, 10), Vector3(0, ry, 0))
	# Hazard stripe band
	ProcMesh.add_part(holder, ProcMesh.cylinder_mesh(0.356, 0.16, stripe_col, 0.65, 0.1, 10), Vector3(0, 0.58, 0))
	# Filler bung cap on top
	ProcMesh.add_part(holder, ProcMesh.cylinder_mesh(0.05, 0.06, Color(0.14, 0.15, 0.16), 0.4, 0.7, 6), Vector3(0.14, 1.18, 0.05))

	_add_box_collider(base_pos + Vector3(0, 0.59, 0), Vector3(0.72, 1.18, 0.72), 0.0)


func _sandbag_wall(base_pos: Vector3, length: float, rot_y_deg: float) -> void:
	var bag_col := Color(0.58, 0.51, 0.38)
	var bag_alt := Color(0.52, 0.46, 0.34)
	var holder := Node3D.new()
	holder.position = base_pos
	holder.rotation_degrees.y = rot_y_deg
	add_child(holder)

	var bag_len := 0.72
	var count := maxi(2, int(round(length / 0.66)))
	for row in range(3):
		var row_y := 0.13 + row * 0.23
		var row_count := count - (1 if row == 2 else 0)
		var start_x := -((row_count - 1) * 0.66) * 0.5
		for i in range(row_count):
			var c := bag_col if (i + row) % 2 == 0 else bag_alt
			var bag := ProcMesh.capsule_mesh(0.15, bag_len, c, 0.92, 0.0)
			ProcMesh.add_part(holder, bag, Vector3(start_x + i * 0.66, row_y, (0.04 if row == 1 else 0.0)), Vector3(0, 0, 90))

	_add_box_collider(base_pos + Vector3(0, 0.42, 0), Vector3(length, 0.84, 0.55), rot_y_deg)


func _vehicles() -> void:
	# 1. Weathered red militia pickup truck parked near the south-east garage
	_pickup_truck(Vector3(7.2, 0, 17.2), -24.0, Color(0.58, 0.19, 0.14), false)
	# 2. Olive military 4x4 utility truck parked in the north-west yard
	_pickup_truck(Vector3(-7.2, 0, -10.5), 32.0, Color(0.28, 0.34, 0.23), true)


func _pickup_truck(base_pos: Vector3, rot_y_deg: float, paint: Color, has_canopy: bool) -> void:
	var dark := Color(0.14, 0.15, 0.16)
	var tire := Color(0.09, 0.09, 0.10)
	var rim := Color(0.55, 0.57, 0.58)
	var glass := Color(0.14, 0.20, 0.25)
	var bumper := Color(0.25, 0.26, 0.27)

	var v := Node3D.new()
	v.position = base_pos
	v.rotation_degrees.y = rot_y_deg
	add_child(v)

	# Undercarriage chassis
	ProcMesh.add_part(v, ProcMesh.box_mesh(Vector3(1.85, 0.28, 4.4), dark), Vector3(0, 0.52, 0))
	# Front hood & fenders
	ProcMesh.add_part(v, ProcMesh.box_mesh(Vector3(1.92, 0.62, 1.50), paint, 0.55, 0.28), Vector3(0, 0.96, -1.42))
	# Front grille + bumper + glowing headlights
	ProcMesh.add_part(v, ProcMesh.box_mesh(Vector3(1.55, 0.42, 0.12), dark), Vector3(0, 0.92, -2.18))
	ProcMesh.add_part(v, ProcMesh.box_mesh(Vector3(2.04, 0.22, 0.24), bumper, 0.5, 0.55), Vector3(0, 0.62, -2.24))
	ProcMesh.add_part(v, ProcMesh.box_mesh(Vector3(2.02, 0.22, 0.20), bumper, 0.5, 0.55), Vector3(0, 0.62, 2.26))
	var hl_mat := ProcMesh.emissive(Color(1.0, 0.94, 0.72), 1.4)
	for sx in [-0.66, 0.66]:
		var hl := ProcMesh.box_mesh(Vector3(0.30, 0.18, 0.08), Color(1.0, 0.95, 0.75))
		hl.material_override = hl_mat
		ProcMesh.add_part(v, hl, Vector3(sx, 0.98, -2.20))

	# Cab lower + cab roof + tinted windshield & side windows
	ProcMesh.add_part(v, ProcMesh.box_mesh(Vector3(1.94, 0.65, 1.38), paint, 0.55, 0.28), Vector3(0, 0.98, -0.02))
	ProcMesh.add_part(v, ProcMesh.box_mesh(Vector3(1.80, 0.66, 1.24), glass, 0.18, 0.4), Vector3(0, 1.56, 0.02))
	ProcMesh.add_part(v, ProcMesh.box_mesh(Vector3(1.88, 0.12, 1.36), paint, 0.55, 0.28), Vector3(0, 1.92, 0.04))

	# Open pickup truck bed (floor + 3 side walls + cargo crate)
	ProcMesh.add_part(v, ProcMesh.box_mesh(Vector3(1.92, 0.16, 1.68), dark), Vector3(0, 0.74, 1.44))
	ProcMesh.add_part(v, ProcMesh.box_mesh(Vector3(0.14, 0.56, 1.72), paint, 0.6, 0.22), Vector3(-0.90, 1.02, 1.44))
	ProcMesh.add_part(v, ProcMesh.box_mesh(Vector3(0.14, 0.56, 1.72), paint, 0.6, 0.22), Vector3(0.90, 1.02, 1.44))
	ProcMesh.add_part(v, ProcMesh.box_mesh(Vector3(1.92, 0.56, 0.14), paint, 0.6, 0.22), Vector3(0, 1.02, 2.22))
	# Cargo box inside bed
	ProcMesh.add_part(v, ProcMesh.box_mesh(Vector3(0.95, 0.62, 0.95), Color(0.46, 0.34, 0.20)), Vector3(-0.15, 1.12, 1.38))

	if has_canopy:
		# Canvas military troop canopy over truck bed
		var canvas := Color(0.36, 0.38, 0.29)
		ProcMesh.add_part(v, ProcMesh.box_mesh(Vector3(1.84, 0.75, 1.66), canvas, 0.92, 0.0), Vector3(0, 1.66, 1.44))
	else:
		# Steel rollbar behind cab
		ProcMesh.add_part(v, ProcMesh.cylinder_mesh(0.05, 0.80, dark, 0.4, 0.6, 6), Vector3(-0.82, 1.62, 0.74))
		ProcMesh.add_part(v, ProcMesh.cylinder_mesh(0.05, 0.80, dark, 0.4, 0.6, 6), Vector3(0.82, 1.62, 0.74))
		ProcMesh.add_part(v, ProcMesh.cylinder_mesh(0.05, 1.70, dark, 0.4, 0.6, 6), Vector3(0, 2.0, 0.74), Vector3(0, 0, 90))

	# 4 Wheels with hubcaps
	for wx in [-0.98, 0.98]:
		for wz in [-1.42, 1.42]:
			ProcMesh.add_part(v, ProcMesh.cylinder_mesh(0.42, 0.28, tire, 0.92, 0.05, 10), Vector3(wx, 0.42, wz), Vector3(0, 0, 90))
			ProcMesh.add_part(v, ProcMesh.cylinder_mesh(0.21, 0.30, rim, 0.4, 0.65, 8), Vector3(wx, 0.42, wz), Vector3(0, 0, 90))

	_add_box_collider(base_pos + Vector3(0, 0.95, 0), Vector3(2.15, 1.9, 4.55), rot_y_deg)


func _watchtower() -> void:
	var c := Vector3(-15.25, 0, -15.25)
	var timber := Color(0.34, 0.25, 0.17)
	var plank := Color(0.45, 0.34, 0.22)
	var tin := Color(0.33, 0.36, 0.38)
	var steel := Color(0.22, 0.24, 0.25)
	var span := 1.65

	# 4 tall corner timber legs (ground to roof)
	for sx in [-span, span]:
		for sz in [-span, span]:
			_box(c + Vector3(sx, 3.0, sz), Vector3(0.28, 6.0, 0.28), timber, true)

	# Cross-bracing struts between legs (visual X-braces)
	for sz in [-span, span]:
		ProcMesh.add_part(self, ProcMesh.box_mesh(Vector3(3.9, 0.14, 0.12), timber), c + Vector3(0, 1.65, sz), Vector3(0, 0, 42))
		ProcMesh.add_part(self, ProcMesh.box_mesh(Vector3(3.9, 0.14, 0.12), timber), c + Vector3(0, 1.65, sz), Vector3(0, 0, -42))
	for sx in [-span, span]:
		ProcMesh.add_part(self, ProcMesh.box_mesh(Vector3(0.12, 0.14, 3.9), timber), c + Vector3(sx, 1.65, 0), Vector3(42, 0, 0))
		ProcMesh.add_part(self, ProcMesh.box_mesh(Vector3(0.12, 0.14, 3.9), timber), c + Vector3(sx, 1.65, 0), Vector3(-42, 0, 0))

	# Elevated timber deck platform at y=3.3
	_box(c + Vector3(0, 3.3, 0), Vector3(4.3, 0.32, 4.3), plank, true)
	# Waist-high defensive parapet walls around deck (gap on south side for ladder)
	_box(c + Vector3(0, 3.95, -2.0), Vector3(4.2, 1.05, 0.22), plank)
	_box(c + Vector3(-2.0, 3.95, 0), Vector3(0.22, 1.05, 4.2), plank)
	_box(c + Vector3(2.0, 3.95, 0), Vector3(0.22, 1.05, 4.2), plank)
	_box(c + Vector3(-1.3, 3.95, 2.0), Vector3(1.5, 1.05, 0.22), plank)
	_box(c + Vector3(1.3, 3.95, 2.0), Vector3(1.5, 1.05, 0.22), plank)
	# Slanted corrugated tin roof
	var roof := ProcMesh.box_mesh(Vector3(4.8, 0.18, 4.8), tin, 0.55, 0.45)
	ProcMesh.add_part(self, roof, c + Vector3(0, 6.05, 0), Vector3(6, 0, 0))
	# Mounted spotlight housing on front edge
	var spot_lamp := ProcMesh.box_mesh(Vector3(0.42, 0.26, 0.24), Color(1.0, 0.9, 0.6))
	spot_lamp.material_override = ProcMesh.emissive(Color(1.0, 0.88, 0.55), 1.8)
	ProcMesh.add_part(self, spot_lamp, c + Vector3(1.2, 5.75, 2.15))

	# Ladder side rails + climbing rungs on south face
	_box(c + Vector3(-0.34, 1.7, 2.15), Vector3(0.08, 3.4, 0.08), steel, false)
	_box(c + Vector3(0.34, 1.7, 2.15), Vector3(0.08, 3.4, 0.08), steel, false)
	for i in range(6):
		_box(c + Vector3(0, 0.35 + i * 0.52, 2.15), Vector3(0.72, 0.10, 0.14), steel, true)


func _approach_cover() -> void:
	# Concrete Jersey barricades (Kenney CC0 wall-low.glb) flanking the south approach
	for spec in [
		[Vector3(-4.2, 0, 26.8), 18.0],
		[Vector3(4.4, 0, 26.8), -15.0],
		[Vector3(-26.5, 0, 5.2), 82.0],
		[Vector3(9.5, 0, -26.5), 10.0],
	]:
		var inst := KENNEY_WALL_LOW.instantiate()
		if inst is Node3D:
			var n := inst as Node3D
			n.position = spec[0]
			n.rotation_degrees.y = spec[1]
			n.scale = Vector3(1.25, 1.1, 1.25)
			add_child(n)
			_add_box_collider(spec[0] + Vector3(0, 0.55, 0), Vector3(2.2, 1.1, 0.65), spec[1])

	# Natural mossy boulders outside perimeter for stealth infiltration
	var rock_col := Color(0.36, 0.35, 0.32)
	for p in [
		Vector3(-8.0, 0.5, 26.5), Vector3(-27.0, 0.5, -2.0),
		Vector3(-26.2, 0.45, 10.5), Vector3(2.0, 0.5, -28.0), Vector3(12.5, 0.45, -26.5),
	]:
		ProcMesh.add_part(self, ProcMesh.sphere_mesh(0.85, rock_col, 0.92, 0.02), p, Vector3(12, 35, 8))
		_add_box_collider(p, Vector3(1.5, 1.0, 1.4), 0.0)


func _trees_and_foliage() -> void:
	# Montana conifer pine trees framing the perimeter outside the compound
	var pine_positions := [
		Vector3(-20, 0, 34), Vector3(-13, 0, 37), Vector3(14, 0, 35), Vector3(22, 0, 32),
		Vector3(-33, 0, 18), Vector3(-35, 0, 6), Vector3(-34, 0, -10), Vector3(-32, 0, -24),
		Vector3(-18, 0, -33), Vector3(-4, 0, -35), Vector3(18, 0, -33), Vector3(31, 0, -24),
		Vector3(33, 0, -6), Vector3(32, 0, 12), Vector3(30, 0, 25),
	]
	for i in range(pine_positions.size()):
		var scale_h := 0.85 + float(i % 4) * 0.18
		_pine_tree(pine_positions[i], scale_h)

	# Kenney CC0 stylized grass tufts around berms, rocks, and fence bases
	var grass_spots := [
		Vector3(-5.5, 0, 29.0), Vector3(5.2, 0, 29.4), Vector3(-10.0, 0, 25.4),
		Vector3(10.5, 0, 25.4), Vector3(-25.2, 0, 8.5), Vector3(-25.4, 0, -5.0),
		Vector3(3.0, 0, -25.4), Vector3(13.0, 0, -25.4), Vector3(-19.0, 0, 25.4),
		Vector3(18.0, 0, 25.4), Vector3(-2.5, 0, 27.2), Vector3(2.8, 0, 27.6),
		Vector3(-14.0, 0, 18.0), Vector3(16.0, 0, 18.5), Vector3(-19.0, 0, -18.0),
	]
	for i in range(grass_spots.size()):
		var scene := KENNEY_GRASS if i % 2 == 0 else KENNEY_GRASS_SMALL
		var tuft := scene.instantiate()
		if tuft is Node3D:
			var n := tuft as Node3D
			n.position = grass_spots[i]
			n.rotation_degrees.y = float(i * 47 % 360)
			var s := 1.4 if i % 2 == 0 else 1.7
			n.scale = Vector3(s, s, s)
			add_child(n)


func _pine_tree(pos: Vector3, scale_h: float) -> void:
	var trunk_col := Color(0.30, 0.21, 0.14)
	var leaf_dark := Color(0.15, 0.28, 0.14)
	var leaf_mid := Color(0.19, 0.34, 0.16)
	var t := Node3D.new()
	t.position = pos
	t.scale = Vector3(scale_h, scale_h, scale_h)
	add_child(t)
	ProcMesh.add_part(t, ProcMesh.cylinder_mesh(0.28, 2.6, trunk_col, 0.92, 0.0, 7), Vector3(0, 1.3, 0))
	ProcMesh.add_part(t, ProcMesh.cone_mesh(2.1, 0.35, 3.0, leaf_dark, 0.9, 0.0, 7), Vector3(0, 3.2, 0))
	ProcMesh.add_part(t, ProcMesh.cone_mesh(1.65, 0.22, 2.6, leaf_mid, 0.9, 0.0, 7), Vector3(0, 5.0, 0))
	ProcMesh.add_part(t, ProcMesh.cone_mesh(1.1, 0.05, 2.2, leaf_dark, 0.9, 0.0, 7), Vector3(0, 6.6, 0))


func _add_box_collider(pos: Vector3, size: Vector3, rot_y_deg: float) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	cs.shape = shape
	body.add_child(cs)
	body.position = pos
	body.rotation_degrees.y = rot_y_deg
	add_child(body)


func _box(pos: Vector3, size: Vector3, color: Color, collide: bool = true) -> void:
	var mi := ProcMesh.box_mesh(size, color)
	mi.position = pos
	add_child(mi)
	if collide:
		_add_box_collider(pos, size, 0.0)
