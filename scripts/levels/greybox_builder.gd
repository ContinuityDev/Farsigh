extends Node3D
## Hope County–style greybox compound: multiple approaches, hollow buildings,
## layered cover, and clear sightlines for stealth routes.


func _ready() -> void:
	_build()


func _build() -> void:
	# Terrain
	_box(Vector3(0, -0.5, 0), Vector3(110, 1.0, 110), Color(0.30, 0.34, 0.27), true)
	# Soft approach berms outside the fence
	_box(Vector3(0, 0.4, 30), Vector3(18, 0.8, 6), Color(0.32, 0.36, 0.28))
	_box(Vector3(-28, 0.35, 0), Vector3(6, 0.7, 14), Color(0.32, 0.36, 0.28))
	_box(Vector3(8, 0.3, -30), Vector3(12, 0.6, 5), Color(0.33, 0.37, 0.29))

	_perimeter()
	_buildings()
	_courtyard_cover()
	_watchtower()
	_approach_cover()
	# Gate pads
	_box(Vector3(0, 0.04, 24.5), Vector3(5, 0.08, 3), Color(0.42, 0.5, 0.34), false)
	_box(Vector3(-24.5, 0.04, 2), Vector3(3, 0.08, 5), Color(0.42, 0.5, 0.34), false)
	_box(Vector3(6, 0.04, -24.5), Vector3(5, 0.08, 3), Color(0.42, 0.5, 0.34), false)


func _perimeter() -> void:
	var h := 3.0
	var t := 0.45
	var s := 24.0
	# South wall — main gate gap around x=0
	_box(Vector3(-10, h * 0.5, s), Vector3(14, h, t), Color(0.4, 0.42, 0.38))
	_box(Vector3(11, h * 0.5, s), Vector3(16, h, t), Color(0.4, 0.42, 0.38))
	# North wall — service gap around x=6
	_box(Vector3(-10, h * 0.5, -s), Vector3(18, h, t), Color(0.4, 0.42, 0.38))
	_box(Vector3(14, h * 0.5, -s), Vector3(12, h, t), Color(0.4, 0.42, 0.38))
	# West wall — breach around z=2
	_box(Vector3(-s, h * 0.5, -12), Vector3(t, h, 18), Color(0.4, 0.42, 0.38))
	_box(Vector3(-s, h * 0.5, 14), Vector3(t, h, 16), Color(0.4, 0.42, 0.38))
	# East wall — solid (forces flanking through other gates)
	_box(Vector3(s, h * 0.5, 0), Vector3(t, h, 48), Color(0.4, 0.42, 0.38))
	# Corner posts
	for p in [
		Vector3(-s, 1.7, -s), Vector3(s, 1.7, -s), Vector3(-s, 1.7, s), Vector3(s, 1.7, s)
	]:
		_box(p, Vector3(1.1, 3.4, 1.1), Color(0.35, 0.36, 0.34))


func _buildings() -> void:
	# Barracks — west, hollow with south doorway
	_hollow_building(Vector3(-11, 0, -4), Vector3(9, 3.6, 7), "Barracks", Color(0.38, 0.4, 0.43), "S")
	# Armory — east, hollow with west doorway facing courtyard
	_hollow_building(Vector3(12, 0, -6), Vector3(7, 3.4, 9), "Armory", Color(0.4, 0.38, 0.36), "W")
	# HQ / radio — north-central, alarm sits nearby; doorway south into yard
	_hollow_building(Vector3(1, 0, -14), Vector3(11, 3.8, 7), "HQ", Color(0.36, 0.39, 0.42), "S")
	# Garage lean-to — southeast cover nest
	_hollow_building(Vector3(10, 0, 12), Vector3(8, 2.8, 5), "Garage", Color(0.37, 0.37, 0.35), "N")
	# Interior partitions / furniture cover
	_box(Vector3(-11, 0.7, -4), Vector3(2.2, 1.4, 0.5), Color(0.45, 0.4, 0.32))
	_box(Vector3(12, 0.7, -6), Vector3(0.5, 1.4, 2.5), Color(0.42, 0.36, 0.3))
	_box(Vector3(1, 0.75, -14), Vector3(3.0, 1.5, 0.5), Color(0.4, 0.35, 0.3))


func _hollow_building(pos: Vector3, size: Vector3, _name: String, color: Color, door: String) -> void:
	## Four walls + roof; `door` is which side gets a doorway gap (N/S/E/W).
	var wall_t := 0.35
	var hx := size.x * 0.5
	var hz := size.z * 0.5
	var h := size.y
	# Floor slab
	_box(pos + Vector3(0, 0.05, 0), Vector3(size.x, 0.1, size.z), color.darkened(0.15))
	# Roof
	_box(pos + Vector3(0, h, 0), Vector3(size.x + 0.4, 0.25, size.z + 0.4), color.lightened(0.05))
	# Walls with optional door gap (two segments)
	_wall_with_door(pos, Vector3(0, 0, -hz), Vector3(size.x, h, wall_t), door == "N", color)  # north face
	_wall_with_door(pos, Vector3(0, 0, hz), Vector3(size.x, h, wall_t), door == "S", color)  # south
	_wall_with_door(pos, Vector3(-hx, 0, 0), Vector3(wall_t, h, size.z), door == "W", color)  # west
	_wall_with_door(pos, Vector3(hx, 0, 0), Vector3(wall_t, h, size.z), door == "E", color)  # east


func _wall_with_door(origin: Vector3, offset: Vector3, size: Vector3, has_door: bool, color: Color) -> void:
	var center := origin + offset + Vector3(0, size.y * 0.5, 0)
	if not has_door:
		_box(center, size, color)
		return
	# Door opening ~1.2m wide in the middle; keep lintel above
	var door_w := 1.3
	if size.x >= size.z:
		# Wall runs along X
		var remain := (size.x - door_w) * 0.5
		_box(center + Vector3(-(door_w * 0.5 + remain * 0.5), 0, 0), Vector3(remain, size.y, size.z), color)
		_box(center + Vector3(door_w * 0.5 + remain * 0.5, 0, 0), Vector3(remain, size.y, size.z), color)
		_box(center + Vector3(0, size.y * 0.35, 0), Vector3(door_w + 0.1, size.y * 0.3, size.z), color)  # lintel
	else:
		# Wall runs along Z
		var remain_z := (size.z - door_w) * 0.5
		_box(center + Vector3(0, 0, -(door_w * 0.5 + remain_z * 0.5)), Vector3(size.x, size.y, remain_z), color)
		_box(center + Vector3(0, 0, door_w * 0.5 + remain_z * 0.5), Vector3(size.x, size.y, remain_z), color)
		_box(center + Vector3(0, size.y * 0.35, 0), Vector3(size.x, size.y * 0.3, door_w + 0.1), color)


func _courtyard_cover() -> void:
	# Crate clusters forming stealth lanes through the yard
	for p in [
		Vector3(-3, 0.55, 6), Vector3(-1.4, 0.55, 6.2),
		Vector3(3, 0.55, 2), Vector3(4.5, 0.9, 2.2),
		Vector3(-6, 0.55, -1), Vector3(0, 0.55, -2),
		Vector3(7, 0.55, 6), Vector3(-8, 0.55, 10),
		Vector3(2, 0.55, 14), Vector3(-2, 0.9, -8),
	]:
		_box(p, Vector3(1.3, 1.1, 1.3), Color(0.45, 0.4, 0.32))
	# Sandbag lines
	_box(Vector3(-5, 0.35, 3), Vector3(3.5, 0.7, 0.7), Color(0.5, 0.45, 0.35))
	_box(Vector3(5, 0.35, -2), Vector3(0.7, 0.7, 3.2), Color(0.5, 0.45, 0.35))
	_box(Vector3(0, 0.35, 10), Vector3(4.0, 0.7, 0.7), Color(0.5, 0.45, 0.35))
	# Fuel drums / tall thin cover
	for p in [Vector3(8, 0.7, -10), Vector3(-9, 0.7, 6), Vector3(4, 0.7, 8)]:
		_box(p, Vector3(0.7, 1.4, 0.7), Color(0.55, 0.35, 0.2))


func _watchtower() -> void:
	# Southwest overwatch — climbable-looking stack with platform
	_box(Vector3(-16, 1.5, -16), Vector3(1.2, 3.0, 1.2), Color(0.34, 0.36, 0.38))
	_box(Vector3(-14.5, 1.5, -16), Vector3(1.2, 3.0, 1.2), Color(0.34, 0.36, 0.38))
	_box(Vector3(-16, 1.5, -14.5), Vector3(1.2, 3.0, 1.2), Color(0.34, 0.36, 0.38))
	_box(Vector3(-14.5, 1.5, -14.5), Vector3(1.2, 3.0, 1.2), Color(0.34, 0.36, 0.38))
	_box(Vector3(-15.25, 3.3, -15.25), Vector3(4.2, 0.35, 4.2), Color(0.4, 0.42, 0.4))
	_box(Vector3(-15.25, 4.2, -15.25), Vector3(3.2, 1.4, 0.25), Color(0.38, 0.4, 0.38))
	# Ladder blocks on the south face
	for i in range(5):
		_box(Vector3(-15.25, 0.35 + i * 0.55, -13.1), Vector3(0.6, 0.2, 0.35), Color(0.45, 0.4, 0.3))


func _approach_cover() -> void:
	# Rocks / scrub outside for infiltration
	for p in [
		Vector3(-4, 0.5, 28), Vector3(3, 0.45, 27), Vector3(-8, 0.55, 26),
		Vector3(-27, 0.5, -2), Vector3(-27, 0.55, 6), Vector3(-26, 0.4, 10),
		Vector3(2, 0.5, -28), Vector3(8, 0.55, -27), Vector3(12, 0.45, -26),
	]:
		_box(p, Vector3(1.6, 1.0, 1.2), Color(0.36, 0.34, 0.3))


func _box(pos: Vector3, size: Vector3, color: Color, collide: bool = true) -> void:
	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mi.mesh = box
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mi.material_override = mat
	mi.position = pos
	add_child(mi)
	if collide:
		var body := StaticBody3D.new()
		body.collision_layer = 1
		body.collision_mask = 0
		var cs := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = size
		cs.shape = shape
		body.add_child(cs)
		body.position = pos
		add_child(body)
