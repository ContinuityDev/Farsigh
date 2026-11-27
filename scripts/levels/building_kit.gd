extends RefCounted
class_name BuildingKit
## Modular procedural builder for larger Far Cry–style buildings:
## - Multi-room interiors with partition walls & hinged InteractiveDoors
## - Multi-storey layouts with walkable interior & exterior stairs
## - Real cutout see-through glass windows (transparent, non-blocking to vision)
## - Reachable rooftops with defensive parapets & stairwells
## - Drive-in garages and recessed walk-down concrete basements

const ProcMesh = preload("res://scripts/mesh/proc_mesh.gd")
const InteractiveDoor = preload("res://scripts/levels/door.gd")

static var _glass_mat: StandardMaterial3D = null


static func _get_glass_mat() -> StandardMaterial3D:
	if _glass_mat == null:
		_glass_mat = StandardMaterial3D.new()
		_glass_mat.albedo_color = Color(0.58, 0.78, 0.88, 0.24)
		_glass_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_glass_mat.roughness = 0.08
		_glass_mat.metallic = 0.2
		_glass_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	return _glass_mat


## Builds a 2-storey, multi-room building with see-through windows, hinged doors,
## walkable interior staircase to floor 2, exterior/interior access to a reachable
## rooftop with parapet walls, and basic interior furniture.
static func build_multi_storey(
	parent: Node3D,
	origin: Vector3,
	width: float,
	depth: float,
	floor_h: float,
	wall_col: Color,
	trim_col: Color,
	door_side: String = "S",
	add_rooftop: bool = true,
	ext_stair_side: String = "E"
) -> void:
	var wt := 0.32
	var hx := width * 0.5
	var hz := depth * 0.5
	var floor_col := Color(0.32, 0.31, 0.29)
	var upper_floor_col := Color(0.38, 0.32, 0.24)
	var stair_w := 1.75

	# Foundation slab
	_box(parent, origin + Vector3(0, 0.06, 0), Vector3(width + 0.3, 0.12, depth + 0.3), floor_col, true)

	# --- GROUND FLOOR (y = 0 .. floor_h) ---
	_build_wall_face(parent, origin, Vector3(0, 0, hz), width, floor_h, wt, true, wall_col, trim_col, door_side == "S", door_side != "S")
	_build_wall_face(parent, origin, Vector3(0, 0, -hz), width, floor_h, wt, true, wall_col, trim_col, door_side == "N", door_side != "N")
	_build_wall_face(parent, origin, Vector3(-hx, 0, 0), depth, floor_h, wt, false, wall_col, trim_col, door_side == "W", door_side != "W")
	_build_wall_face(parent, origin, Vector3(hx, 0, 0), depth, floor_h, wt, false, wall_col, trim_col, door_side == "E", door_side != "E")

	# Ground-floor interior partition dividing into 2 rooms (with interior hinged door)
	var part_x := -width * 0.12
	_build_wall_face(parent, origin, Vector3(part_x, 0, 0), depth - wt * 2.0, floor_h, 0.22, false, wall_col.darkened(0.08), trim_col, true, false)

	# Interior furniture on ground floor (tactical table, wall shelves, warm ceiling lamp)
	_box(parent, origin + Vector3(-hx + 2.1, 0.45, -hz + 1.8), Vector3(2.2, 0.9, 0.9), Color(0.36, 0.27, 0.18), true)
	_box(parent, origin + Vector3(hx - 2.2, 0.45, -hz + 1.6), Vector3(1.8, 0.9, 0.8), Color(0.34, 0.36, 0.34), true)
	_ceiling_lamp(parent, origin + Vector3(-hx * 0.5, floor_h - 0.16, 0.0))
	_ceiling_lamp(parent, origin + Vector3(hx * 0.45, floor_h - 0.16, 0.0))

	# --- 2ND FLOOR SLAB (leaves stairwell cutout along the east/north-east interior edge) ---
	var f2_y := floor_h
	var slab_t := 0.24
	var hole_w := stair_w + 0.35
	var hole_len := minf(depth - 1.8, 4.8)
	var stair_x := hx - hole_w * 0.5 - wt
	var main_slab_w := width - hole_w - wt
	# Main 2nd floor slab (west portion)
	_box(parent, origin + Vector3(-hole_w * 0.5 - wt * 0.5, f2_y, 0.0), Vector3(main_slab_w, slab_t, depth - wt), upper_floor_col, true)
	# Landing slab in front/behind stairwell on east strip
	var rem_z := (depth - wt) - hole_len
	if rem_z > 0.6:
		_box(parent, origin + Vector3(stair_x, f2_y, -hz + wt * 0.5 + rem_z * 0.5), Vector3(hole_w, slab_t, rem_z), upper_floor_col, true)

	# Walkable interior staircase (ascending from south toward north on east side)
	var st_start := origin + Vector3(stair_x, 0.12, hz - 1.1)
	var st_end := origin + Vector3(stair_x, f2_y + slab_t * 0.5, hz - 1.1 - hole_len + 0.6)
	build_stairs(parent, st_start, st_end, stair_w, Color(0.42, 0.33, 0.23))

	# --- 2ND FLOOR WALLS (y = floor_h .. 2*floor_h) with see-through windows all around ---
	var f2_origin := origin + Vector3(0, f2_y, 0)
	_build_wall_face(parent, f2_origin, Vector3(0, 0, hz), width, floor_h, wt, true, wall_col.lightened(0.04), trim_col, false, true)
	_build_wall_face(parent, f2_origin, Vector3(0, 0, -hz), width, floor_h, wt, true, wall_col.lightened(0.04), trim_col, false, true)
	_build_wall_face(parent, f2_origin, Vector3(-hx, 0, 0), depth, floor_h, wt, false, wall_col.lightened(0.04), trim_col, ext_stair_side == "W", ext_stair_side != "W")
	_build_wall_face(parent, f2_origin, Vector3(hx, 0, 0), depth, floor_h, wt, false, wall_col.lightened(0.04), trim_col, ext_stair_side == "E", ext_stair_side != "E")

	# 2nd floor room partition (creates lookout office + stairwell hall)
	_build_wall_face(parent, f2_origin, Vector3(0.0, 0, 0), depth - wt * 2.0, floor_h, 0.22, false, wall_col.darkened(0.05), trim_col, true, false)
	# 2nd floor furniture (radio console & crates)
	_box(parent, f2_origin + Vector3(-hx + 1.8, 0.55, 0.0), Vector3(1.1, 1.1, 2.4), Color(0.26, 0.29, 0.28), true)
	_ceiling_lamp(parent, f2_origin + Vector3(-hx * 0.45, floor_h - 0.16, 0.0))

	# --- REACHABLE ROOFTOP (y = 2*floor_h) + Exterior Steel/Timber Stairs from Ground -> 2nd -> Roof ---
	var roof_y := floor_h * 2.0
	_box(parent, origin + Vector3(0, roof_y, 0), Vector3(width + 0.4, 0.26, depth + 0.4), trim_col, true)
	if add_rooftop:
		# Waist-high parapet walls with opening on stair side
		var ph := 1.05
		var pt := 0.24
		_box(parent, origin + Vector3(0, roof_y + ph * 0.5, hz), Vector3(width + 0.2, ph, pt), wall_col.darkened(0.1), true)
		_box(parent, origin + Vector3(0, roof_y + ph * 0.5, -hz), Vector3(width + 0.2, ph, pt), wall_col.darkened(0.1), true)
		if ext_stair_side == "E":
			_box(parent, origin + Vector3(-hx, roof_y + ph * 0.5, 0), Vector3(pt, ph, depth), wall_col.darkened(0.1), true)
			# East parapet leaves stair entry gap near north end
			_box(parent, origin + Vector3(hx, roof_y + ph * 0.5, depth * 0.2), Vector3(pt, ph, depth * 0.58), wall_col.darkened(0.1), true)
			# Exterior stairs along east wall: Ground -> 2nd landing -> Rooftop
			var ex := hx + 1.15
			_box(parent, origin + Vector3(ex, f2_y, 0.0), Vector3(2.0, 0.22, 2.2), Color(0.32, 0.34, 0.36), true)
			build_stairs(parent, origin + Vector3(ex, 0.08, hz - 0.2), origin + Vector3(ex, f2_y + 0.1, 0.9), 1.6, Color(0.32, 0.34, 0.36))
			build_stairs(parent, origin + Vector3(ex, f2_y + 0.1, -0.9), origin + Vector3(ex, roof_y + 0.12, -hz + 0.8), 1.6, Color(0.32, 0.34, 0.36))
			_box(parent, origin + Vector3(ex, roof_y, -hz + 0.4), Vector3(2.0, 0.24, 1.8), Color(0.32, 0.34, 0.36), true)
		else:
			_box(parent, origin + Vector3(hx, roof_y + ph * 0.5, 0), Vector3(pt, ph, depth), wall_col.darkened(0.1), true)
			_box(parent, origin + Vector3(-hx, roof_y + ph * 0.5, depth * 0.2), Vector3(pt, ph, depth * 0.58), wall_col.darkened(0.1), true)
			var wx := -hx - 1.15
			_box(parent, origin + Vector3(wx, f2_y, 0.0), Vector3(2.0, 0.22, 2.2), Color(0.32, 0.34, 0.36), true)
			build_stairs(parent, origin + Vector3(wx, 0.08, hz - 0.2), origin + Vector3(wx, f2_y + 0.1, 0.9), 1.6, Color(0.32, 0.34, 0.36))
			build_stairs(parent, origin + Vector3(wx, f2_y + 0.1, -0.9), origin + Vector3(wx, roof_y + 0.12, -hz + 0.8), 1.6, Color(0.32, 0.34, 0.36))
			_box(parent, origin + Vector3(wx, roof_y, -hz + 0.4), Vector3(2.0, 0.24, 1.8), Color(0.32, 0.34, 0.36), true)
		# Rooftop AC unit cover
		_box(parent, origin + Vector3(-hx + 2.2, roof_y + 0.65, -hz + 2.0), Vector3(1.5, 1.0, 1.2), Color(0.45, 0.47, 0.48), true)


## Builds a drive-in garage with wide open vehicle bay, side personnel hinged door,
## see-through workshop windows, interior partition toolroom, and walkable roof deck.
static func build_garage(
	parent: Node3D,
	origin: Vector3,
	width: float,
	depth: float,
	height: float,
	wall_col: Color,
	roof_col: Color,
	bay_side: String = "N"
) -> void:
	var wt := 0.32
	var hx := width * 0.5
	var hz := depth * 0.5
	_box(parent, origin + Vector3(0, 0.06, 0), Vector3(width + 0.3, 0.12, depth + 0.3), Color(0.30, 0.31, 0.31), true)
	# Flat walkable garage roof
	_box(parent, origin + Vector3(0, height, 0), Vector3(width + 0.5, 0.24, depth + 0.5), roof_col, true)
	# Wide roll-up garage bay opening (4.2m wide) on bay_side, side personnel door + windows on others
	if bay_side == "N":
		_build_bay_wall(parent, origin + Vector3(0, 0, -hz), width, height, wt, true, wall_col)
		_build_wall_face(parent, origin, Vector3(0, 0, hz), width, height, wt, true, wall_col, roof_col, false, true)
		_build_wall_face(parent, origin, Vector3(-hx, 0, 0), depth, height, wt, false, wall_col, roof_col, true, false)
		_build_wall_face(parent, origin, Vector3(hx, 0, 0), depth, height, wt, false, wall_col, roof_col, false, true)
	elif bay_side == "S":
		_build_bay_wall(parent, origin + Vector3(0, 0, hz), width, height, wt, true, wall_col)
		_build_wall_face(parent, origin, Vector3(0, 0, -hz), width, height, wt, true, wall_col, roof_col, false, true)
		_build_wall_face(parent, origin, Vector3(-hx, 0, 0), depth, height, wt, false, wall_col, roof_col, true, false)
		_build_wall_face(parent, origin, Vector3(hx, 0, 0), depth, height, wt, false, wall_col, roof_col, false, true)
	else:
		_build_bay_wall(parent, origin + Vector3(-hx, 0, 0), depth, height, wt, false, wall_col)
		_build_wall_face(parent, origin, Vector3(hx, 0, 0), depth, height, wt, false, wall_col, roof_col, true, false)
		_build_wall_face(parent, origin, Vector3(0, 0, hz), width, height, wt, true, wall_col, roof_col, false, true)
		_build_wall_face(parent, origin, Vector3(0, 0, -hz), width, height, wt, true, wall_col, roof_col, false, true)
	# Garage workbench & warm ceiling light
	_box(parent, origin + Vector3(hx - 1.2, 0.5, hz - 1.2), Vector3(1.8, 0.95, 0.75), Color(0.42, 0.30, 0.18), true)
	_ceiling_lamp(parent, origin + Vector3(0, height - 0.16, 0))


## Builds a true subterranean walk-down concrete basement cellar under a bunker/building
## (caller leaves a matching opening in the ground plane for [origin.x +/- width/2, origin.z +/- depth/2]).
static func build_basement(
	parent: Node3D,
	origin: Vector3,
	width: float,
	depth: float,
	basement_depth: float = 2.8
) -> void:
	var conc := Color(0.35, 0.36, 0.35)
	var floor_c := Color(0.26, 0.27, 0.28)
	var hx := width * 0.5
	var hz := depth * 0.5
	var y_floor := -basement_depth

	# Basement floor slab
	_box(parent, origin + Vector3(0, y_floor - 0.15, 0), Vector3(width + 0.6, 0.3, depth + 0.6), floor_c, true)
	# 4 concrete retaining walls
	_box(parent, origin + Vector3(0, y_floor * 0.5, -hz), Vector3(width, basement_depth, 0.35), conc, true)
	_box(parent, origin + Vector3(0, y_floor * 0.5, hz), Vector3(width, basement_depth, 0.35), conc, true)
	_box(parent, origin + Vector3(-hx, y_floor * 0.5, 0), Vector3(0.35, basement_depth, depth), conc, true)
	_box(parent, origin + Vector3(hx, y_floor * 0.5, 0), Vector3(0.35, basement_depth, depth), conc, true)

	# Walkable concrete stairs descending from ground (y=0) at south-west edge down to basement floor
	var st_x := -hx + 1.35
	build_stairs(parent, origin + Vector3(st_x, y_floor, -0.8), origin + Vector3(st_x, 0.05, hz - 0.8), 1.9, Color(0.40, 0.41, 0.40))
	# Second escape staircase on east side
	var st_x2 := hx - 1.35
	build_stairs(parent, origin + Vector3(st_x2, y_floor, -0.8), origin + Vector3(st_x2, 0.05, hz - 0.8), 1.9, Color(0.40, 0.41, 0.40))

	# Basement interior armory table, generator box, warm amber bunker ceiling lights
	_box(parent, origin + Vector3(0, y_floor + 0.5, -hz + 1.5), Vector3(3.4, 1.0, 1.0), Color(0.32, 0.34, 0.30), true)
	_box(parent, origin + Vector3(0, y_floor + 0.7, 1.4), Vector3(1.6, 1.4, 1.2), Color(0.52, 0.22, 0.16), true)
	_ceiling_lamp(parent, origin + Vector3(-1.8, -0.25, -1.5))
	_ceiling_lamp(parent, origin + Vector3(1.8, -0.25, -1.5))


## Walkable staircase: visual treads + single smooth tilted ramp BoxShape3D so
## both CharacterBody3D players and NavMesh guards glide cleanly up and down.
static func build_stairs(parent: Node3D, start_pos: Vector3, end_pos: Vector3, width: float, color: Color) -> void:
	var delta := end_pos - start_pos
	var horiz := Vector3(delta.x, 0.0, delta.z)
	var run := horiz.length()
	var rise := delta.y
	if run < 0.2:
		return
	var steps := maxi(4, int(ceil(absf(rise) / 0.24)))
	var yaw := atan2(horiz.x, horiz.z)
	var holder := Node3D.new()
	holder.position = start_pos
	holder.rotation.y = yaw
	parent.add_child(holder)

	# Visual steps (no per-step collision so movement never stutters)
	var step_run := run / float(steps)
	var step_rise := rise / float(steps)
	for i in range(steps):
		var cy := step_rise * (float(i) + 0.5)
		var cz := step_run * (float(i) + 0.5)
		ProcMesh.add_part(holder, ProcMesh.box_mesh(Vector3(width, absf(step_rise) + 0.08, step_run + 0.05), color), Vector3(0, cy, cz))

	# Side stringer rails
	var slope_len := sqrt(run * run + rise * rise)
	var pitch := -atan2(rise, run)
	for sx in [-width * 0.5, width * 0.5]:
		var rail := ProcMesh.box_mesh(Vector3(0.08, 0.14, slope_len), color.darkened(0.18))
		var rnode := Node3D.new()
		rnode.position = Vector3(sx, rise * 0.5 + 0.85, run * 0.5)
		rnode.rotation.x = pitch
		rnode.add_child(rail)
		holder.add_child(rnode)

	# Smooth walkable ramp collider aligned to the step surface
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(width, 0.22, slope_len + 0.25)
	cs.shape = shape
	body.add_child(cs)
	body.position = Vector3(0.0, rise * 0.5 - 0.08, run * 0.5)
	body.rotation.x = pitch
	holder.add_child(body)


static func _build_bay_wall(parent: Node3D, base_center: Vector3, length: float, height: float, wt: float, along_x: bool, color: Color) -> void:
	var bay_w := minf(4.2, length - 1.6)
	var bay_h := minf(2.6, height - 0.5)
	var side_len := (length - bay_w) * 0.5
	var roll_col := Color(0.56, 0.57, 0.58)
	if along_x:
		_box(parent, base_center + Vector3(-(bay_w * 0.5 + side_len * 0.5), height * 0.5, 0), Vector3(side_len, height, wt), color, true)
		_box(parent, base_center + Vector3(bay_w * 0.5 + side_len * 0.5, height * 0.5, 0), Vector3(side_len, height, wt), color, true)
		_box(parent, base_center + Vector3(0, bay_h + (height - bay_h) * 0.5, 0), Vector3(bay_w + 0.1, height - bay_h, wt), color, true)
		# Partially rolled-up shutter slats at top of bay
		_box(parent, base_center + Vector3(0, bay_h - 0.18, 0), Vector3(bay_w, 0.36, 0.10), roll_col, false)
	else:
		_box(parent, base_center + Vector3(0, height * 0.5, -(bay_w * 0.5 + side_len * 0.5)), Vector3(wt, height, side_len), color, true)
		_box(parent, base_center + Vector3(0, height * 0.5, bay_w * 0.5 + side_len * 0.5), Vector3(wt, height, side_len), color, true)
		_box(parent, base_center + Vector3(0, bay_h + (height - bay_h) * 0.5, 0), Vector3(wt, height - bay_h, bay_w + 0.1), color, true)
		_box(parent, base_center + Vector3(0, bay_h - 0.18, 0), Vector3(0.10, 0.36, bay_w), roll_col, false)


static func _build_wall_face(
	parent: Node3D,
	origin: Vector3,
	offset: Vector3,
	length: float,
	height: float,
	wt: float,
	along_x: bool,
	color: Color,
	frame_col: Color,
	has_door: bool,
	has_window: bool
) -> void:
	var base := origin + offset
	if not has_door and not has_window:
		var sz := Vector3(length, height, wt) if along_x else Vector3(wt, height, length)
		_box(parent, base + Vector3(0, height * 0.5, 0), sz, color, true)
		return

	if has_door:
		var door_w := 1.32
		var door_h := 2.32
		var side := maxf(0.2, (length - door_w) * 0.5)
		var hdr := maxf(0.2, height - door_h)
		if along_x:
			_box(parent, base + Vector3(-(door_w * 0.5 + side * 0.5), height * 0.5, 0), Vector3(side, height, wt), color, true)
			_box(parent, base + Vector3(door_w * 0.5 + side * 0.5, height * 0.5, 0), Vector3(side, height, wt), color, true)
			_box(parent, base + Vector3(0, door_h + hdr * 0.5, 0), Vector3(door_w + 0.08, hdr, wt), color, true)
			# Trim + Interactive hinged door
			_box(parent, base + Vector3(-door_w * 0.5, door_h * 0.5, 0), Vector3(0.10, door_h, wt + 0.06), frame_col, false)
			_box(parent, base + Vector3(door_w * 0.5, door_h * 0.5, 0), Vector3(0.10, door_h, wt + 0.06), frame_col, false)
			InteractiveDoor.create(parent, base + Vector3(-door_w * 0.5 + 0.04, 0.04, 0.0), 0.0, door_w - 0.08, door_h - 0.06, frame_col.lightened(0.12))
		else:
			_box(parent, base + Vector3(0, height * 0.5, -(door_w * 0.5 + side * 0.5)), Vector3(wt, height, side), color, true)
			_box(parent, base + Vector3(0, height * 0.5, door_w * 0.5 + side * 0.5), Vector3(wt, height, side), color, true)
			_box(parent, base + Vector3(0, door_h + hdr * 0.5, 0), Vector3(wt, hdr, door_w + 0.08), color, true)
			_box(parent, base + Vector3(0, door_h * 0.5, -door_w * 0.5), Vector3(wt + 0.06, door_h, 0.10), frame_col, false)
			_box(parent, base + Vector3(0, door_h * 0.5, door_w * 0.5), Vector3(wt + 0.06, door_h, 0.10), frame_col, false)
			InteractiveDoor.create(parent, base + Vector3(0.0, 0.04, -door_w * 0.5 + 0.04), -90.0, door_w - 0.08, door_h - 0.06, frame_col.lightened(0.12))
		return

	# Real cutout see-through window!
	var win_w := clampf(length * 0.36, 1.4, 2.6)
	var sill_h := 1.05
	var win_h := minf(1.25, height - sill_h - 0.45)
	var hdr_h := height - sill_h - win_h
	var side_w := maxf(0.25, (length - win_w) * 0.5)
	if along_x:
		_box(parent, base + Vector3(-(win_w * 0.5 + side_w * 0.5), height * 0.5, 0), Vector3(side_w, height, wt), color, true)
		_box(parent, base + Vector3(win_w * 0.5 + side_w * 0.5, height * 0.5, 0), Vector3(side_w, height, wt), color, true)
		_box(parent, base + Vector3(0, sill_h * 0.5, 0), Vector3(win_w + 0.04, sill_h, wt), color, true)
		_box(parent, base + Vector3(0, sill_h + win_h + hdr_h * 0.5, 0), Vector3(win_w + 0.04, hdr_h, wt), color, true)
		# Sill ledge + frame mullions
		_box(parent, base + Vector3(0, sill_h + 0.04, 0), Vector3(win_w + 0.14, 0.08, wt + 0.12), frame_col, false)
		_box(parent, base + Vector3(0, sill_h + win_h * 0.5, 0), Vector3(0.06, win_h, 0.08), frame_col, false)
		# Transparent see-through glass pane (visual only — players & guards see right through!)
		var pane := ProcMesh.box_mesh(Vector3(win_w, win_h, 0.03), Color(0.6, 0.8, 0.9))
		pane.material_override = _get_glass_mat()
		ProcMesh.add_part(parent, pane, base + Vector3(0, sill_h + win_h * 0.5, 0))
	else:
		_box(parent, base + Vector3(0, height * 0.5, -(win_w * 0.5 + side_w * 0.5)), Vector3(wt, height, side_w), color, true)
		_box(parent, base + Vector3(0, height * 0.5, win_w * 0.5 + side_w * 0.5), Vector3(wt, height, side_w), color, true)
		_box(parent, base + Vector3(0, sill_h * 0.5, 0), Vector3(wt, sill_h, win_w + 0.04), color, true)
		_box(parent, base + Vector3(0, sill_h + win_h + hdr_h * 0.5, 0), Vector3(wt, hdr_h, win_w + 0.04), color, true)
		_box(parent, base + Vector3(0, sill_h + 0.04, 0), Vector3(wt + 0.12, 0.08, win_w + 0.14), frame_col, false)
		_box(parent, base + Vector3(0, sill_h + win_h * 0.5, 0), Vector3(0.08, win_h, 0.06), frame_col, false)
		var pane := ProcMesh.box_mesh(Vector3(0.03, win_h, win_w), Color(0.6, 0.8, 0.9))
		pane.material_override = _get_glass_mat()
		ProcMesh.add_part(parent, pane, base + Vector3(0, sill_h + win_h * 0.5, 0))


static func _ceiling_lamp(parent: Node3D, pos: Vector3) -> void:
	var lamp := ProcMesh.box_mesh(Vector3(0.75, 0.08, 0.24), Color(1.0, 0.92, 0.72))
	lamp.material_override = ProcMesh.emissive(Color(1.0, 0.90, 0.65), 1.6)
	ProcMesh.add_part(parent, lamp, pos)


static func _box(parent: Node3D, pos: Vector3, size: Vector3, color: Color, collide: bool) -> void:
	var mi := ProcMesh.box_mesh(size, color)
	mi.position = pos
	parent.add_child(mi)
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
		parent.add_child(body)
