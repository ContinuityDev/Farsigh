extends Node3D
## Procedural low-poly outpost geometry builder for all 5 Far Cry 5–inspired
## Hope County outposts. Uses cached materials via ProcMesh + Kenney CC0 accents
## so draw calls and memory stay light for mobile WebGL browsers.

const KENNEY_GRASS: PackedScene = preload("res://assets/kenney/grass.glb")
const KENNEY_GRASS_SMALL: PackedScene = preload("res://assets/kenney/grass-small.glb")
const KENNEY_WALL_LOW: PackedScene = preload("res://assets/kenney/wall-low.glb")

var current_outpost_id: String = ""


func _ready() -> void:
	if current_outpost_id == "":
		build_outpost(GameState.selected_outpost_id)


func build_outpost(outpost_id: String) -> void:
	if current_outpost_id == outpost_id and get_child_count() > 0:
		return
	current_outpost_id = outpost_id
	for c in get_children():
		c.queue_free()
	match outpost_id:
		"ranch_redbarn":
			_build_ranch()
		"lumber_mill":
			_build_lumber_mill()
		"river_dock":
			_build_river_dock()
		"hilltop_bunker":
			_build_hilltop_bunker()
		_:
			_build_compound_alpha()


# ============================================================================
# 1. HOPE COUNTY COMPOUND (original militia compound)
# ============================================================================
func _build_compound_alpha() -> void:
	_terrain_and_roads()
	_perimeter()
	_buildings()
	_courtyard_cover()
	_vehicles()
	_watchtower_at(Vector3(-15.25, 0, -15.25))
	_approach_cover()
	_trees_and_foliage()


func _terrain_and_roads() -> void:
	_box(Vector3(0, -0.5, 0), Vector3(130, 1.0, 130), Color(0.24, 0.31, 0.20), true)
	_box(Vector3(0, 0.015, 0), Vector3(47, 0.03, 47), Color(0.37, 0.35, 0.30), false)
	_box(Vector3(0, 0.025, 16), Vector3(6.0, 0.03, 38), Color(0.42, 0.36, 0.27), false)
	_box(Vector3(-12, 0.025, 2), Vector3(30, 0.03, 4.4), Color(0.42, 0.36, 0.27), false)
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

	_fence_segment(Vector3(-12, 0, s), Vector3(16, h, t), wall_col, post_col)
	_fence_segment(Vector3(12, 0, s), Vector3(16, h, t), wall_col, post_col)
	_gate_arch(Vector3(0, 0, s), post_col, Color(0.48, 0.24, 0.16))

	_fence_segment(Vector3(-10, 0, -s), Vector3(18, h, t), wall_col, post_col)
	_fence_segment(Vector3(14, 0, -s), Vector3(12, h, t), wall_col, post_col)
	_fence_segment(Vector3(-s, 0, -12), Vector3(t, h, 18), wall_col, post_col)
	_fence_segment(Vector3(-s, 0, 14), Vector3(t, h, 16), wall_col, post_col)
	_fence_segment(Vector3(s, 0, 0), Vector3(t, h, 48), wall_col, post_col)

	for p in [
		Vector3(-s, 1.75, -s), Vector3(s, 1.75, -s), Vector3(-s, 1.75, s), Vector3(s, 1.75, s)
	]:
		_box(p, Vector3(1.15, 3.5, 1.15), Color(0.32, 0.33, 0.31))
		_box(p + Vector3(0, 1.85, 0), Vector3(1.3, 0.2, 1.3), post_col, false)


func _gate_arch(center: Vector3, post_col: Color, sign_col: Color) -> void:
	_box(center + Vector3(-4.0, 2.3, 0), Vector3(0.4, 4.6, 0.4), post_col)
	_box(center + Vector3(4.0, 2.3, 0), Vector3(0.4, 4.6, 0.4), post_col)
	_box(center + Vector3(0.0, 4.45, 0), Vector3(8.6, 0.35, 0.45), sign_col, false)
	var lamp := ProcMesh.box_mesh(Vector3(0.8, 0.18, 0.22), Color(1.0, 0.85, 0.55))
	lamp.material_override = ProcMesh.emissive(Color(1.0, 0.82, 0.45), 1.6)
	ProcMesh.add_part(self, lamp, center + Vector3(0, 4.2, 0.22))


func _fence_segment(base_center: Vector3, size: Vector3, wall_col: Color, post_col: Color) -> void:
	_box(base_center + Vector3(0, size.y * 0.5, 0), size, wall_col, true)
	var top_size := Vector3(size.x, 0.18, size.z + 0.12) if size.x >= size.z else Vector3(size.x + 0.12, 0.18, size.z)
	_box(base_center + Vector3(0, size.y + 0.08, 0), top_size, post_col, false)


func _buildings() -> void:
	_hollow_building(Vector3(-11, 0, -4), Vector3(9, 3.6, 7), Color(0.44, 0.42, 0.38), Color(0.30, 0.25, 0.20), "S")
	_hollow_building(Vector3(12, 0, -6), Vector3(7, 3.4, 9), Color(0.42, 0.39, 0.35), Color(0.28, 0.30, 0.28), "W")
	_hollow_building(Vector3(1, 0, -14), Vector3(11, 3.8, 7), Color(0.38, 0.41, 0.43), Color(0.26, 0.24, 0.22), "S")
	_radio_mast(Vector3(4.5, 3.9, -14.5))
	_hollow_building(Vector3(10, 0, 12), Vector3(8, 2.9, 5), Color(0.40, 0.38, 0.34), Color(0.32, 0.22, 0.18), "N")
	_crate(Vector3(-11, 0, -4), 1.15, 0.0)
	_crate(Vector3(12, 0, -6), 1.15, 90.0)
	_box(Vector3(1, 0.55, -14), Vector3(3.0, 1.1, 0.7), Color(0.35, 0.27, 0.19))


func _courtyard_cover() -> void:
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

	_sandbag_wall(Vector3(-5.0, 0, 3.0), 3.4, 0.0)
	_sandbag_wall(Vector3(5.0, 0, -2.0), 3.0, 90.0)
	_sandbag_wall(Vector3(0.0, 0, 10.0), 3.8, 0.0)

	_barrel(Vector3(8.0, 0, -10.0), true)
	_barrel(Vector3(8.75, 0, -9.6), false)
	_barrel(Vector3(-9.0, 0, 6.0), true)
	_barrel(Vector3(-8.3, 0, 6.5), true)
	_barrel(Vector3(4.0, 0, 8.0), false)
	_barrel(Vector3(4.7, 0, 8.4), true)
	_barrel(Vector3(-3.8, 0, -11.5), true)


func _vehicles() -> void:
	_pickup_truck(Vector3(7.2, 0, 17.2), -24.0, Color(0.58, 0.19, 0.14), false)
	_pickup_truck(Vector3(-7.2, 0, -10.5), 32.0, Color(0.28, 0.34, 0.23), true)


func _approach_cover() -> void:
	for spec in [
		[Vector3(-4.2, 0, 26.8), 18.0],
		[Vector3(4.4, 0, 26.8), -15.0],
		[Vector3(-26.5, 0, 5.2), 82.0],
		[Vector3(9.5, 0, -26.5), 10.0],
	]:
		_jersey_barrier(spec[0], spec[1])

	for p in [
		Vector3(-8.0, 0.5, 26.5), Vector3(-27.0, 0.5, -2.0),
		Vector3(-26.2, 0.45, 10.5), Vector3(2.0, 0.5, -28.0), Vector3(12.5, 0.45, -26.5),
	]:
		_boulder(p, 0.85)


func _trees_and_foliage() -> void:
	var pine_positions := [
		Vector3(-20, 0, 34), Vector3(-13, 0, 37), Vector3(14, 0, 35), Vector3(22, 0, 32),
		Vector3(-33, 0, 18), Vector3(-35, 0, 6), Vector3(-34, 0, -10), Vector3(-32, 0, -24),
		Vector3(-18, 0, -33), Vector3(-4, 0, -35), Vector3(18, 0, -33), Vector3(31, 0, -24),
		Vector3(33, 0, -6), Vector3(32, 0, 12), Vector3(30, 0, 25),
	]
	for i in range(pine_positions.size()):
		_pine_tree(pine_positions[i], 0.85 + float(i % 4) * 0.18)

	var grass_spots := [
		Vector3(-5.5, 0, 29.0), Vector3(5.2, 0, 29.4), Vector3(-10.0, 0, 25.4),
		Vector3(10.5, 0, 25.4), Vector3(-25.2, 0, 8.5), Vector3(-25.4, 0, -5.0),
		Vector3(3.0, 0, -25.4), Vector3(13.0, 0, -25.4), Vector3(-19.0, 0, 25.4),
		Vector3(18.0, 0, 25.4), Vector3(-2.5, 0, 27.2), Vector3(2.8, 0, 27.6),
		Vector3(-14.0, 0, 18.0), Vector3(16.0, 0, 18.5), Vector3(-19.0, 0, -18.0),
	]
	_scatter_grass(grass_spots)


# ============================================================================
# 2. SEED FAMILY RANCH (Big red barn, twin grain silos, farmhouse, hay bales)
# ============================================================================
func _build_ranch() -> void:
	# Golden farmland pasture & dirt barnyard
	_box(Vector3(0, -0.5, 0), Vector3(140, 1.0, 140), Color(0.34, 0.39, 0.21), true)
	_box(Vector3(0, 0.015, 0), Vector3(52, 0.03, 52), Color(0.45, 0.37, 0.26), false)
	_box(Vector3(0, 0.025, 22), Vector3(6.5, 0.03, 34), Color(0.48, 0.39, 0.27), false)
	# Golden wheat field strips flanking the road
	_box(Vector3(-18, 0.08, 30), Vector3(18, 0.16, 12), Color(0.68, 0.56, 0.22), false)
	_box(Vector3(18, 0.08, 30), Vector3(18, 0.16, 12), Color(0.66, 0.54, 0.21), false)

	# Wooden split-rail ranch fences (with south gate, east orchard breach, north hayfield gap)
	var rail_col := Color(0.46, 0.34, 0.21)
	_ranch_fence(Vector3(-15, 0, 24), Vector3(18, 1.35, 0.3), rail_col)
	_ranch_fence(Vector3(15, 0, 24), Vector3(18, 1.35, 0.3), rail_col)
	_gate_arch(Vector3(0, 0, 24), rail_col, Color(0.56, 0.16, 0.12))
	_ranch_fence(Vector3(-24, 0, 0), Vector3(0.3, 1.35, 48), rail_col)
	_ranch_fence(Vector3(24, 0, -10), Vector3(0.3, 1.35, 22), rail_col)
	_ranch_fence(Vector3(24, 0, 15), Vector3(0.3, 1.35, 16), rail_col)
	_ranch_fence(Vector3(-10, 0, -24), Vector3(24, 1.35, 0.3), rail_col)
	_ranch_fence(Vector3(14, 0, -24), Vector3(14, 1.35, 0.3), rail_col)

	# Iconic Big Red Barn (center-north) with gabled roof + white X barn trim
	var barn_red := Color(0.58, 0.15, 0.12)
	var barn_roof := Color(0.24, 0.25, 0.27)
	_hollow_building(Vector3(-2, 0, -6), Vector3(13, 5.4, 10), barn_red, barn_roof, "S")
	# White trim stripes & loft window on south face of barn
	_box(Vector3(-2, 4.4, -0.85), Vector3(2.2, 1.5, 0.15), Color(0.14, 0.12, 0.10), false)
	_box(Vector3(-2, 5.2, -0.82), Vector3(2.5, 0.16, 0.18), Color(0.9, 0.88, 0.84), false)
	_box(Vector3(-2, 3.6, -0.82), Vector3(2.5, 0.16, 0.18), Color(0.9, 0.88, 0.84), false)
	# Barn roof peak
	_box(Vector3(-2, 6.2, -6), Vector3(13.4, 1.2, 5.2), barn_roof.darkened(0.08), false)

	# Twin Silver Galvanized Grain Silos (east of barn) + sniper catwalk perch
	_grain_silo(Vector3(14, 0, -12), 2.5, 8.8)
	_grain_silo(Vector3(14, 0, -5), 2.5, 8.2)
	# Steel catwalk platform wrapping the silos at y=5.5 (sniper stands at 14, 5.6, -12)
	_box(Vector3(14, 5.4, -12), Vector3(6.2, 0.28, 6.2), Color(0.32, 0.34, 0.36), true)
	_box(Vector3(14, 5.4, -8.5), Vector3(2.2, 0.25, 5.0), Color(0.32, 0.34, 0.36), true)
	# Ladder up silo west face
	for i in range(9):
		_box(Vector3(11.1, 0.5 + i * 0.58, -12), Vector3(0.14, 0.10, 0.72), Color(0.24, 0.25, 0.27), true)

	# White Clapboard Ranch Farmhouse (west) + porch
	_hollow_building(Vector3(-15, 0, 4), Vector3(8.5, 3.8, 9), Color(0.82, 0.80, 0.74), Color(0.28, 0.24, 0.22), "E")
	_box(Vector3(-9.8, 0.15, 4), Vector3(2.0, 0.3, 8.5), Color(0.44, 0.34, 0.24))
	# Equipment Tool Shed (southeast)
	_hollow_building(Vector3(14, 0, 12), Vector3(8, 3.2, 6), Color(0.46, 0.38, 0.29), Color(0.30, 0.28, 0.26), "W")

	# Ranch Windmill tower (northeast)
	_windmill(Vector3(-16, 0, -16))

	# Stacked Golden Hay Bales & Corral Cover
	for spec in [
		[Vector3(-4, 0, 8), 0.0], [Vector3(-2.3, 0, 8.3), 12.0], [Vector3(-3.1, 1.05, 8.1), 5.0],
		[Vector3(5, 0, 6), 80.0], [Vector3(6.4, 0, 6.2), -10.0],
		[Vector3(0, 0, 15), 4.0], [Vector3(8, 0, -1), 22.0],
		[Vector3(-10, 0, -8), -15.0], [Vector3(-10, 1.05, -8), 8.0],
		[Vector3(4, 0, -16), 0.0], [Vector3(-8, 0, 16), 30.0],
	]:
		_hay_bale(spec[0], spec[1])

	_sandbag_wall(Vector3(-6, 0, 18), 3.4, 15.0)
	_sandbag_wall(Vector3(7, 0, 17), 3.4, -18.0)
	_crate(Vector3(-2, 0, -5), 1.2, 8.0)
	_barrel(Vector3(9, 0, 10), true)
	_barrel(Vector3(9.8, 0, 10.4), true)
	_barrel(Vector3(-8, 0, -12), false)

	# Vehicles: blue farm pickup + red utility truck
	_pickup_truck(Vector3(4.5, 0, 11.5), -35.0, Color(0.18, 0.35, 0.56), false)
	_pickup_truck(Vector3(-14.0, 0, -8.0), 75.0, Color(0.58, 0.20, 0.14), true)

	# Perimeter Montana pines & grass
	for i in range(14):
		var ang := float(i) * TAU / 14.0
		var r := 33.0 + float(i % 3) * 4.0
		_pine_tree(Vector3(cos(ang) * r, 0, sin(ang) * r), 0.9 + float(i % 3) * 0.22)
	_scatter_grass([
		Vector3(-6, 0, 26), Vector3(6, 0, 26), Vector3(-16, 0, 20), Vector3(16, 0, 20),
		Vector3(26, 0, 2), Vector3(-26, 0, -4), Vector3(0, 0, -26), Vector3(10, 0, 4),
	])


# ============================================================================
# 3. BARON LUMBER MILL (Saw shed, log pyramids, drying kiln, logging trucks)
# ============================================================================
func _build_lumber_mill() -> void:
	# Sawdust & dark forest earth
	_box(Vector3(0, -0.5, 0), Vector3(140, 1.0, 140), Color(0.20, 0.27, 0.17), true)
	_box(Vector3(0, 0.015, 0), Vector3(54, 0.03, 50), Color(0.46, 0.38, 0.26), false)
	_box(Vector3(0, 0.025, 0), Vector3(8.0, 0.03, 52), Color(0.38, 0.31, 0.22), false)

	# Corrugated timber/steel yard wall with multiple log-chute gaps
	var wall_col := Color(0.35, 0.28, 0.21)
	var post_col := Color(0.20, 0.18, 0.16)
	_fence_segment(Vector3(-15, 0, 25), Vector3(18, 2.8, 0.4), wall_col, post_col)
	_fence_segment(Vector3(15, 0, 25), Vector3(18, 2.8, 0.4), wall_col, post_col)
	_gate_arch(Vector3(0, 0, 25), post_col, Color(0.55, 0.34, 0.12))
	_fence_segment(Vector3(-25, 0, -8), Vector3(0.4, 2.8, 26), wall_col, post_col)
	_fence_segment(Vector3(-25, 0, 17), Vector3(0.4, 2.8, 14), wall_col, post_col)
	_fence_segment(Vector3(25, 0, -10), Vector3(0.4, 2.8, 24), wall_col, post_col)
	_fence_segment(Vector3(25, 0, 15), Vector3(0.4, 2.8, 16), wall_col, post_col)
	_fence_segment(Vector3(0, 0, -25), Vector3(38, 2.8, 0.4), wall_col, post_col)

	# Main Saw Shed (open timber sides with steel circular saw + log conveyor)
	_hollow_building(Vector3(0, 0, -10), Vector3(16, 4.8, 9), Color(0.44, 0.33, 0.22), Color(0.25, 0.28, 0.30), "S")
	# Circular saw table & shining steel blade inside/front of saw shed
	_box(Vector3(0, 0.6, -10), Vector3(8.0, 1.2, 1.4), Color(0.28, 0.29, 0.31))
	ProcMesh.add_part(self, ProcMesh.cylinder_mesh(0.85, 0.08, Color(0.76, 0.78, 0.80), 0.25, 0.85, 14), Vector3(0, 1.45, -10), Vector3(90, 0, 0))
	# Steel smokestack on saw shed
	ProcMesh.add_part(self, ProcMesh.cylinder_mesh(0.42, 6.5, Color(0.22, 0.23, 0.24), 0.6, 0.5, 10), Vector3(6.5, 7.2, -12.5))

	# Lumber Drying Kiln (west) & Foreman Office (east)
	_hollow_building(Vector3(-16, 0, -2), Vector3(8, 3.8, 11), Color(0.40, 0.37, 0.33), Color(0.26, 0.24, 0.22), "E")
	_hollow_building(Vector3(16, 0, -2), Vector3(8, 3.6, 8), Color(0.48, 0.39, 0.28), Color(0.29, 0.25, 0.21), "W")

	# Elevated Catwalk / Sniper Watchtower on NE corner (-16, 0, 14) & (16, 0, -14)
	_watchtower_at(Vector3(16, 0, -14))
	_watchtower_at(Vector3(-16, 0, 14))

	# Stacked Timber Log Pyramids forming tight stealth lanes
	_log_pile(Vector3(-8, 0, 8), 0.0)
	_log_pile(Vector3(8, 0, 8), 12.0)
	_log_pile(Vector3(0, 0, 2), 90.0)
	_log_pile(Vector3(-8, 0, -16), 5.0)
	_log_pile(Vector3(9, 0, 16), -18.0)
	_log_pile(Vector3(-4, 0, 17), 85.0)

	# Logging Trucks & Yard Props
	_pickup_truck(Vector3(-12, 0, 18), 25.0, Color(0.62, 0.36, 0.12), false)
	_pickup_truck(Vector3(14, 0, 10), -65.0, Color(0.26, 0.32, 0.24), true)
	_crate(Vector3(-4, 0, 8), 1.2, 6.0)
	_crate(Vector3(4, 0, -2), 1.3, -10.0)
	_barrel(Vector3(11, 0, -5), true)
	_barrel(Vector3(11.8, 0, -4.5), true)
	_barrel(Vector3(-10, 0, 2), false)
	_sandbag_wall(Vector3(0, 0, 14), 3.6, 0.0)

	# Dense Montana conifer timber surrounding mill
	for i in range(20):
		var ang := float(i) * TAU / 20.0
		var r := 31.0 + float(i % 4) * 3.5
		_pine_tree(Vector3(cos(ang) * r, 0, sin(ang) * r), 1.0 + float(i % 3) * 0.24)
	_scatter_grass([
		Vector3(-10, 0, 28), Vector3(10, 0, 28), Vector3(-28, 0, 6), Vector3(28, 0, -4),
		Vector3(-14, 0, 22), Vector3(14, 0, 22),
	])


# ============================================================================
# 4. WHITETAIL BAIT & DOCK (River, wooden pier, patrol boat, bait shop, boathouse)
# ============================================================================
func _build_river_dock() -> void:
	# Shoreline ground on south half (z >= -6)
	_box(Vector3(0, -0.5, 22), Vector3(140, 1.0, 62), Color(0.24, 0.32, 0.21), true)
	# Gravel parking lot & dockside road
	_box(Vector3(0, 0.015, 11), Vector3(44, 0.03, 24), Color(0.39, 0.37, 0.33), false)
	_box(Vector3(0, 0.025, 24), Vector3(6.5, 0.03, 22), Color(0.42, 0.38, 0.31), false)
	# Wooden riverfront seawall bulkhead along z = -6
	_box(Vector3(0, -0.1, -6.2), Vector3(70, 1.4, 0.7), Color(0.32, 0.24, 0.16), true)

	# Shimmering Montana River Water (north half, z < -6)
	var water_mat := StandardMaterial3D.new()
	water_mat.albedo_color = Color(0.11, 0.34, 0.44, 0.92)
	water_mat.roughness = 0.15
	water_mat.metallic = 0.25
	var water_mi := ProcMesh.box_mesh(Vector3(140, 0.2, 68), Color(0.11, 0.34, 0.44))
	water_mi.material_override = water_mat
	water_mi.position = Vector3(0, -0.45, -40)
	add_child(water_mi)
	# Invisible riverbed floor so nothing falls forever
	_add_box_collider(Vector3(0, -1.2, -40), Vector3(140, 0.5, 68), 0.0)

	# Main Wooden Pier extending out over the river + T-dock crosshead
	var plank := Color(0.45, 0.34, 0.23)
	var piling := Color(0.28, 0.20, 0.13)
	_box(Vector3(0, 0.12, -12.5), Vector3(4.8, 0.24, 14.0), plank, true)
	_box(Vector3(0, 0.12, -18.5), Vector3(16.0, 0.24, 4.2), plank, true)
	# Pier timber pilings
	for px in [-7.2, -2.2, 2.2, 7.2]:
		for pz in [-8.0, -13.0, -18.5]:
			if absf(px) > 3.0 and pz > -16.0:
				continue
			ProcMesh.add_part(self, ProcMesh.cylinder_mesh(0.22, 2.6, piling, 0.9, 0.0, 8), Vector3(px, -0.4, pz))
			ProcMesh.add_part(self, ProcMesh.cylinder_mesh(0.24, 0.85, piling, 0.88, 0.0, 8), Vector3(px, 0.65, pz))

	# Moored Militia Patrol Boat tied beside the east T-dock
	_patrol_boat(Vector3(10.5, -0.15, -16.0), -12.0)

	# Bait & Tackle Shop (southeast shore) with glowing BAIT neon bar
	_hollow_building(Vector3(11, 0, 7), Vector3(9.5, 3.6, 7.5), Color(0.32, 0.44, 0.42), Color(0.28, 0.22, 0.18), "W")
	var neon := ProcMesh.box_mesh(Vector3(3.0, 0.55, 0.14), Color(1.0, 0.38, 0.16))
	neon.material_override = ProcMesh.emissive(Color(1.0, 0.42, 0.18), 2.0)
	ProcMesh.add_part(self, neon, Vector3(11, 3.25, 10.95))

	# 2-Storey Boathouse (west shore) with sniper roof/balcony perch at (-12, 3.6, 0)
	_hollow_building(Vector3(-12, 0, 0), Vector3(9.5, 3.6, 10.5), Color(0.48, 0.40, 0.31), Color(0.26, 0.28, 0.30), "E")
	# Walkable flat deck roof railing on boathouse + ladder on south wall
	_box(Vector3(-12, 3.65, 0), Vector3(10.0, 0.25, 11.0), Color(0.36, 0.30, 0.23), true)
	_box(Vector3(-7.1, 4.25, 0), Vector3(0.2, 1.0, 10.6), plank)
	_box(Vector3(-12, 4.25, -5.3), Vector3(9.8, 1.0, 0.2), plank)
	for i in range(6):
		_box(Vector3(-12, 0.45 + i * 0.55, 5.55), Vector3(0.75, 0.10, 0.15), Color(0.22, 0.23, 0.25), true)

	# Fuel Pump Canopy & Dockside Cover
	_box(Vector3(0, 3.3, 6), Vector3(6.8, 0.26, 4.2), Color(0.55, 0.20, 0.16))
	_box(Vector3(-2.8, 1.65, 6), Vector3(0.25, 3.3, 0.25), Color(0.8, 0.8, 0.78))
	_box(Vector3(2.8, 1.65, 6), Vector3(0.25, 3.3, 0.25), Color(0.8, 0.8, 0.78))
	_box(Vector3(-0.8, 0.8, 6), Vector3(0.7, 1.6, 0.55), Color(0.68, 0.18, 0.14))
	_box(Vector3(0.8, 0.8, 6), Vector3(0.7, 1.6, 0.55), Color(0.68, 0.18, 0.14))

	# Low perimeter wood/chainlink fence on landward sides
	_fence_segment(Vector3(-14, 0, 22), Vector3(16, 2.2, 0.35), Color(0.36, 0.35, 0.31), Color(0.22, 0.22, 0.20))
	_fence_segment(Vector3(14, 0, 22), Vector3(16, 2.2, 0.35), Color(0.36, 0.35, 0.31), Color(0.22, 0.22, 0.20))
	_gate_arch(Vector3(0, 0, 22), Color(0.24, 0.25, 0.24), Color(0.18, 0.42, 0.45))

	# Crates, fish coolers, fuel drums, pickup truck
	for spec in [
		[Vector3(-4, 0, 12), 1.15, 10.0], [Vector3(5, 0, 13), 1.2, -15.0],
		[Vector3(-3, 0, -2), 1.15, 4.0], [Vector3(4, 0, -2), 1.2, -6.0],
		[Vector3(-5, 0.24, -18), 1.0, 8.0], [Vector3(5, 0.24, -18), 1.0, -12.0],
	]:
		_crate(spec[0], spec[1], spec[2])
	_barrel(Vector3(5.5, 0, 3.5), true)
	_barrel(Vector3(6.2, 0, 4.0), true)
	_barrel(Vector3(-6.0, 0, 6.0), false)
	_sandbag_wall(Vector3(0, 0, 15.5), 3.6, 0.0)
	_pickup_truck(Vector3(-12.5, 0, 14.5), 22.0, Color(0.24, 0.42, 0.36), false)

	# Shore boulders & pines
	for p in [Vector3(-22, 0.4, -4), Vector3(22, 0.4, -4), Vector3(-24, 0.5, 12), Vector3(24, 0.5, 14)]:
		_boulder(p, 1.1)
	for p in [
		Vector3(-24, 0, 26), Vector3(-16, 0, 28), Vector3(15, 0, 28), Vector3(24, 0, 24),
		Vector3(-28, 0, 6), Vector3(-26, 0, -2), Vector3(26, 0, 4), Vector3(27, 0, -3),
	]:
		_pine_tree(p, 1.05)
	_scatter_grass([
		Vector3(-8, 0, 24), Vector3(8, 0, 24), Vector3(-18, 0, 18), Vector3(18, 0, 18),
	])


# ============================================================================
# 5. JACOB'S RIDGE BUNKER (Concrete bunker, radar dishes, helipad, trenches)
# ============================================================================
func _build_hilltop_bunker() -> void:
	# Rocky highland ridge gravel
	_box(Vector3(0, -0.5, 0), Vector3(140, 1.0, 140), Color(0.32, 0.31, 0.27), true)
	_box(Vector3(0, 0.015, 0), Vector3(54, 0.03, 54), Color(0.37, 0.36, 0.34), false)
	_box(Vector3(0, 0.025, 22), Vector3(6.2, 0.03, 30), Color(0.30, 0.30, 0.29), false)

	# Heavy reinforced concrete perimeter walls with 3 tactical breaches
	var conc := Color(0.44, 0.45, 0.43)
	var steel := Color(0.20, 0.21, 0.22)
	_fence_segment(Vector3(-15, 0, 25), Vector3(18, 3.2, 0.6), conc, steel)
	_fence_segment(Vector3(15, 0, 25), Vector3(18, 3.2, 0.6), conc, steel)
	_gate_arch(Vector3(0, 0, 25), steel, Color(0.32, 0.34, 0.28))
	_fence_segment(Vector3(-25, 0, -10), Vector3(0.6, 3.2, 24), conc, steel)
	_fence_segment(Vector3(-25, 0, 15), Vector3(0.6, 3.2, 16), conc, steel)
	_fence_segment(Vector3(25, 0, -10), Vector3(0.6, 3.2, 24), conc, steel)
	_fence_segment(Vector3(25, 0, 15), Vector3(0.6, 3.2, 16), conc, steel)
	_fence_segment(Vector3(-8, 0, -25), Vector3(26, 3.2, 0.6), conc, steel)
	_fence_segment(Vector3(16, 0, -25), Vector3(14, 3.2, 0.6), conc, steel)

	# Central Reinforced Concrete Militia Bunker (north-center) + Radar Dishes
	_hollow_building(Vector3(0, 0, -14), Vector3(14, 4.0, 9), Color(0.45, 0.46, 0.44), Color(0.32, 0.33, 0.32), "S")
	# Concrete blast hood over bunker roof + twin radar dishes + radio mast
	_box(Vector3(0, 4.4, -14), Vector3(12.5, 0.8, 7.5), Color(0.38, 0.39, 0.38), true)
	_radar_dish(Vector3(-4.0, 4.8, -14.0), -25.0)
	_radar_dish(Vector3(4.0, 4.8, -14.0), 30.0)
	_radio_mast(Vector3(0, 4.8, -16.5))

	# Raised Concrete Helipad (center-south courtyard) with crisp "H" & corner lights
	_box(Vector3(0, 0.14, 4), Vector3(11.5, 0.28, 11.5), Color(0.30, 0.31, 0.32), true)
	# Painted yellow H markings
	var yellow := Color(0.92, 0.76, 0.18)
	_box(Vector3(-1.8, 0.29, 4), Vector3(0.6, 0.04, 5.2), yellow, false)
	_box(Vector3(1.8, 0.29, 4), Vector3(0.6, 0.04, 5.2), yellow, false)
	_box(Vector3(0, 0.29, 4), Vector3(3.6, 0.04, 0.6), yellow, false)
	for hx in [-5.2, 5.2]:
		for hz in [-1.2, 9.2]:
			var pad_light := ProcMesh.sphere_mesh(0.18, Color(1.0, 0.45, 0.15))
			pad_light.material_override = ProcMesh.emissive(Color(1.0, 0.45, 0.15), 2.2)
			ProcMesh.add_part(self, pad_light, Vector3(hx, 0.36, hz))

	# Twin Overwatch Sniper Watchtowers (NW and NE corners)
	_watchtower_at(Vector3(-17, 0, -16))
	_watchtower_at(Vector3(17, 0, -16))

	# Side Munitions Depot (west) & Comms Barrack (east)
	_hollow_building(Vector3(-15, 0, 4), Vector3(7.5, 3.4, 8), Color(0.42, 0.43, 0.40), Color(0.28, 0.29, 0.28), "E")
	_hollow_building(Vector3(15, 0, 4), Vector3(7.5, 3.4, 8), Color(0.42, 0.43, 0.40), Color(0.28, 0.29, 0.28), "W")

	# Interlocking Sandbag Trench Emplacements + Barricades
	_sandbag_wall(Vector3(-8, 0, 14), 4.0, 18.0)
	_sandbag_wall(Vector3(8, 0, 14), 4.0, -18.0)
	_sandbag_wall(Vector3(0, 0, 17.5), 4.2, 0.0)
	_sandbag_wall(Vector3(-8, 0, -5), 3.6, 80.0)
	_sandbag_wall(Vector3(8, 0, -5), 3.6, -80.0)

	for spec in [
		[Vector3(-4.5, 0, 27.5), 14.0], [Vector3(4.5, 0, 27.5), -14.0],
		[Vector3(-27.5, 0, 3.0), 85.0], [Vector3(27.5, 0, 3.0), -85.0],
	]:
		_jersey_barrier(spec[0], spec[1])

	# Armored Utility Trucks + Munitions Crates + Red Fuel Drums
	_pickup_truck(Vector3(-14, 0, 17), 35.0, Color(0.26, 0.30, 0.24), true)
	_pickup_truck(Vector3(14, 0, 16), -30.0, Color(0.28, 0.30, 0.28), true)
	for spec in [
		[Vector3(-5, 0, -6), 1.25, 4.0], [Vector3(5, 0, -6), 1.25, -8.0],
		[Vector3(-9, 0, 10), 1.2, 12.0], [Vector3(9, 0, 10), 1.2, -12.0],
	]:
		_crate(spec[0], spec[1], spec[2])
	_barrel(Vector3(-10, 0, -9), true)
	_barrel(Vector3(-9.2, 0, -8.5), true)
	_barrel(Vector3(10, 0, -9), true)
	_barrel(Vector3(10.8, 0, -8.5), false)

	# Craggy mountain boulders & sparse alpine pines
	for i in range(12):
		var ang := float(i) * TAU / 12.0
		var r := 31.0 + float(i % 3) * 3.0
		_boulder(Vector3(cos(ang) * r, 0.65, sin(ang) * r), 1.35)
		if i % 2 == 0:
			_pine_tree(Vector3(cos(ang + 0.2) * (r + 3.5), 0, sin(ang + 0.2) * (r + 3.5)), 0.85)


# ============================================================================
# SHARED ARCHITECTURAL & PROP HELPERS
# ============================================================================
func _radio_mast(mast_base: Vector3) -> void:
	ProcMesh.add_part(self, ProcMesh.cylinder_mesh(0.08, 5.2, Color(0.26, 0.27, 0.29), 0.5, 0.6, 8), mast_base + Vector3(0, 2.6, 0))
	ProcMesh.add_part(self, ProcMesh.box_mesh(Vector3(1.8, 0.08, 0.08), Color(0.3, 0.3, 0.32)), mast_base + Vector3(0, 4.2, 0))
	ProcMesh.add_part(self, ProcMesh.box_mesh(Vector3(0.08, 0.08, 1.4), Color(0.3, 0.3, 0.32)), mast_base + Vector3(0, 3.4, 0))
	var beacon := ProcMesh.sphere_mesh(0.14, Color(1.0, 0.15, 0.1))
	beacon.material_override = ProcMesh.emissive(Color(1.0, 0.18, 0.1), 2.4)
	ProcMesh.add_part(self, beacon, mast_base + Vector3(0, 5.25, 0))


func _radar_dish(base_pos: Vector3, yaw_deg: float) -> void:
	var h := Node3D.new()
	h.position = base_pos
	h.rotation_degrees.y = yaw_deg
	add_child(h)
	ProcMesh.add_part(h, ProcMesh.cylinder_mesh(0.25, 1.4, Color(0.30, 0.32, 0.33), 0.5, 0.5, 8), Vector3(0, 0.7, 0))
	ProcMesh.add_part(h, ProcMesh.cone_mesh(1.5, 0.2, 0.55, Color(0.78, 0.80, 0.78), 0.45, 0.4, 12), Vector3(0, 1.75, 0.15), Vector3(68, 0, 0))
	ProcMesh.add_part(h, ProcMesh.cylinder_mesh(0.05, 1.1, Color(0.22, 0.23, 0.24), 0.4, 0.7, 6), Vector3(0, 1.85, 0.55), Vector3(68, 0, 0))


func _grain_silo(base_pos: Vector3, radius: float, height: float) -> void:
	var galv := Color(0.68, 0.70, 0.72)
	var seam := Color(0.50, 0.52, 0.54)
	ProcMesh.add_part(self, ProcMesh.cylinder_mesh(radius, height, galv, 0.45, 0.55, 14), base_pos + Vector3(0, height * 0.5, 0))
	for ry in [2.0, 4.2, 6.4]:
		if ry < height:
			ProcMesh.add_part(self, ProcMesh.cylinder_mesh(radius + 0.05, 0.12, seam, 0.4, 0.6, 14), base_pos + Vector3(0, ry, 0))
	ProcMesh.add_part(self, ProcMesh.cone_mesh(radius + 0.18, 0.15, 2.2, seam, 0.4, 0.6, 14), base_pos + Vector3(0, height + 1.1, 0))
	_add_box_collider(base_pos + Vector3(0, height * 0.5, 0), Vector3(radius * 1.9, height, radius * 1.9), 0.0)


func _windmill(base_pos: Vector3) -> void:
	var steel := Color(0.45, 0.46, 0.44)
	var vane := Color(0.68, 0.22, 0.16)
	for sx in [-0.7, 0.7]:
		for sz in [-0.7, 0.7]:
			ProcMesh.add_part(self, ProcMesh.box_mesh(Vector3(0.14, 9.0, 0.14), steel), base_pos + Vector3(sx, 4.5, sz))
	ProcMesh.add_part(self, ProcMesh.cylinder_mesh(0.22, 0.6, steel, 0.5, 0.6, 8), base_pos + Vector3(0, 8.8, 0.4), Vector3(90, 0, 0))
	for a in [0, 45, 90, 135]:
		ProcMesh.add_part(self, ProcMesh.box_mesh(Vector3(3.8, 0.26, 0.06), vane), base_pos + Vector3(0, 8.8, 0.75), Vector3(0, 0, a))
	_add_box_collider(base_pos + Vector3(0, 2.0, 0), Vector3(1.6, 4.0, 1.6), 0.0)


func _hay_bale(base_pos: Vector3, rot_y_deg: float) -> void:
	var hay := Color(0.76, 0.62, 0.24)
	var twine := Color(0.38, 0.26, 0.14)
	var h := Node3D.new()
	h.position = base_pos + Vector3(0, 0.52, 0)
	h.rotation_degrees.y = rot_y_deg
	add_child(h)
	ProcMesh.add_part(h, ProcMesh.box_mesh(Vector3(1.55, 1.02, 1.05), hay, 0.96, 0.0))
	ProcMesh.add_part(h, ProcMesh.box_mesh(Vector3(0.06, 1.05, 1.08), twine), Vector3(-0.38, 0, 0))
	ProcMesh.add_part(h, ProcMesh.box_mesh(Vector3(0.06, 1.05, 1.08), twine), Vector3(0.38, 0, 0))
	_add_box_collider(base_pos + Vector3(0, 0.52, 0), Vector3(1.55, 1.02, 1.05), rot_y_deg)


func _ranch_fence(base_center: Vector3, size: Vector3, color: Color) -> void:
	var horiz := size.x >= size.z
	var length := size.x if horiz else size.z
	var posts := maxi(2, int(length / 3.2) + 1)
	for i in range(posts):
		var t := -length * 0.5 + (float(i) / float(posts - 1)) * length
		var off := Vector3(t, size.y * 0.5, 0) if horiz else Vector3(0, size.y * 0.5, t)
		ProcMesh.add_part(self, ProcMesh.box_mesh(Vector3(0.16, size.y, 0.16), color.darkened(0.1)), base_center + off)
	for ry in [0.42, 0.88, 1.25]:
		var rail_size := Vector3(length, 0.11, 0.10) if horiz else Vector3(0.10, 0.11, length)
		ProcMesh.add_part(self, ProcMesh.box_mesh(rail_size, color), base_center + Vector3(0, ry, 0))
	_add_box_collider(base_center + Vector3(0, size.y * 0.5, 0), size, 0.0)


func _log_pile(base_pos: Vector3, rot_y_deg: float) -> void:
	var bark := Color(0.35, 0.24, 0.15)
	var cut := Color(0.68, 0.54, 0.34)
	var h := Node3D.new()
	h.position = base_pos
	h.rotation_degrees.y = rot_y_deg
	add_child(h)
	var rows := [
		[-0.75, 0.0, 0.75],
		[-0.38, 0.38],
		[0.0],
	]
	for r in range(rows.size()):
		var y := 0.32 + r * 0.52
		for lx in rows[r]:
			ProcMesh.add_part(h, ProcMesh.cylinder_mesh(0.30, 4.4, bark, 0.92, 0.0, 8), Vector3(lx, y, 0), Vector3(90, 0, 0))
			ProcMesh.add_part(h, ProcMesh.cylinder_mesh(0.24, 4.44, cut, 0.85, 0.0, 8), Vector3(lx, y, 0), Vector3(90, 0, 0))
	_add_box_collider(base_pos + Vector3(0, 0.82, 0), Vector3(2.2, 1.65, 4.4), rot_y_deg)


func _patrol_boat(base_pos: Vector3, rot_y_deg: float) -> void:
	var hull := Color(0.24, 0.30, 0.34)
	var deck := Color(0.55, 0.56, 0.54)
	var cabin := Color(0.76, 0.75, 0.72)
	var b := Node3D.new()
	b.position = base_pos
	b.rotation_degrees.y = rot_y_deg
	add_child(b)
	ProcMesh.add_part(b, ProcMesh.box_mesh(Vector3(2.4, 0.85, 6.4), hull, 0.5, 0.3), Vector3(0, 0.25, 0))
	ProcMesh.add_part(b, ProcMesh.cone_mesh(1.3, 0.15, 1.8, hull, 0.5, 0.3, 6), Vector3(0, 0.35, -3.9), Vector3(-90, 0, 0))
	ProcMesh.add_part(b, ProcMesh.box_mesh(Vector3(2.2, 0.14, 5.8), deck), Vector3(0, 0.72, 0.1))
	ProcMesh.add_part(b, ProcMesh.box_mesh(Vector3(1.75, 1.35, 2.2), cabin), Vector3(0, 1.45, -0.4))
	ProcMesh.add_part(b, ProcMesh.box_mesh(Vector3(1.82, 0.55, 1.8), Color(0.12, 0.19, 0.24), 0.15, 0.4), Vector3(0, 1.68, -0.55))
	_add_box_collider(base_pos + Vector3(0, 0.9, 0), Vector3(2.5, 1.8, 6.8), rot_y_deg)


func _hollow_building(pos: Vector3, size: Vector3, wall_col: Color, roof_col: Color, door: String) -> void:
	var wall_t := 0.35
	var hx := size.x * 0.5
	var hz := size.z * 0.5
	var h := size.y
	_box(pos + Vector3(0, 0.06, 0), Vector3(size.x + 0.3, 0.12, size.z + 0.3), Color(0.30, 0.31, 0.30))
	_box(pos + Vector3(0, h + 0.08, 0), Vector3(size.x + 0.7, 0.24, size.z + 0.7), roof_col)
	_box(pos + Vector3(0, h + 0.28, 0), Vector3(size.x + 0.2, 0.22, size.z * 0.45), roof_col.darkened(0.1), false)
	_wall_with_door(pos, Vector3(0, 0, -hz), Vector3(size.x, h, wall_t), door == "N", wall_col)
	_wall_with_door(pos, Vector3(0, 0, hz), Vector3(size.x, h, wall_t), door == "S", wall_col)
	_wall_with_door(pos, Vector3(-hx, 0, 0), Vector3(wall_t, h, size.z), door == "W", wall_col)
	_wall_with_door(pos, Vector3(hx, 0, 0), Vector3(wall_t, h, size.z), door == "E", wall_col)
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
		_box(center + Vector3(-door_w * 0.5, -size.y * 0.15, 0), Vector3(0.12, size.y * 0.7, size.z + 0.08), frame_col, false)
		_box(center + Vector3(door_w * 0.5, -size.y * 0.15, 0), Vector3(0.12, size.y * 0.7, size.z + 0.08), frame_col, false)
	else:
		var remain_z := (size.z - door_w) * 0.5
		_box(center + Vector3(0, 0, -(door_w * 0.5 + remain_z * 0.5)), Vector3(size.x, size.y, remain_z), color)
		_box(center + Vector3(0, 0, door_w * 0.5 + remain_z * 0.5), Vector3(size.x, size.y, remain_z), color)
		_box(center + Vector3(0, size.y * 0.35, 0), Vector3(size.x, size.y * 0.3, door_w + 0.1), color)
		_box(center + Vector3(0, -size.y * 0.15, -door_w * 0.5), Vector3(size.x + 0.08, size.y * 0.7, 0.12), frame_col, false)
		_box(center + Vector3(0, -size.y * 0.15, door_w * 0.5), Vector3(size.x + 0.08, size.y * 0.7, 0.12), frame_col, false)


func _crate(base_pos: Vector3, size: float, rot_y_deg: float) -> void:
	var wood := Color(0.50, 0.37, 0.22)
	var trim := Color(0.36, 0.25, 0.14)
	var iron := Color(0.18, 0.19, 0.20)
	var holder := Node3D.new()
	holder.position = base_pos + Vector3(0, size * 0.5, 0)
	holder.rotation_degrees.y = rot_y_deg
	add_child(holder)

	ProcMesh.add_part(holder, ProcMesh.box_mesh(Vector3(size * 0.92, size * 0.92, size * 0.92), wood))
	var bt := size * 0.11
	ProcMesh.add_part(holder, ProcMesh.box_mesh(Vector3(size, bt, size), trim), Vector3(0, size * 0.45, 0))
	ProcMesh.add_part(holder, ProcMesh.box_mesh(Vector3(size, bt, size), trim), Vector3(0, -size * 0.45, 0))
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			ProcMesh.add_part(holder, ProcMesh.box_mesh(Vector3(bt, size, bt), trim), Vector3(sx * size * 0.45, 0, sz * size * 0.45))
			ProcMesh.add_part(holder, ProcMesh.box_mesh(Vector3(bt * 1.15, bt * 1.15, bt * 1.15), iron, 0.5, 0.6), Vector3(sx * size * 0.45, size * 0.45, sz * size * 0.45))
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

	ProcMesh.add_part(holder, ProcMesh.cylinder_mesh(0.35, 1.16, body_col, 0.55, 0.45, 10), Vector3(0, 0.58, 0))
	for ry in [0.04, 0.38, 0.78, 1.14]:
		ProcMesh.add_part(holder, ProcMesh.cylinder_mesh(0.375, 0.055, rib_col, 0.5, 0.55, 10), Vector3(0, ry, 0))
	ProcMesh.add_part(holder, ProcMesh.cylinder_mesh(0.356, 0.16, stripe_col, 0.65, 0.1, 10), Vector3(0, 0.58, 0))
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

	ProcMesh.add_part(v, ProcMesh.box_mesh(Vector3(1.85, 0.28, 4.4), dark), Vector3(0, 0.52, 0))
	ProcMesh.add_part(v, ProcMesh.box_mesh(Vector3(1.92, 0.62, 1.50), paint, 0.55, 0.28), Vector3(0, 0.96, -1.42))
	ProcMesh.add_part(v, ProcMesh.box_mesh(Vector3(1.55, 0.42, 0.12), dark), Vector3(0, 0.92, -2.18))
	ProcMesh.add_part(v, ProcMesh.box_mesh(Vector3(2.04, 0.22, 0.24), bumper, 0.5, 0.55), Vector3(0, 0.62, -2.24))
	ProcMesh.add_part(v, ProcMesh.box_mesh(Vector3(2.02, 0.22, 0.20), bumper, 0.5, 0.55), Vector3(0, 0.62, 2.26))
	var hl_mat := ProcMesh.emissive(Color(1.0, 0.94, 0.72), 1.4)
	for sx in [-0.66, 0.66]:
		var hl := ProcMesh.box_mesh(Vector3(0.30, 0.18, 0.08), Color(1.0, 0.95, 0.75))
		hl.material_override = hl_mat
		ProcMesh.add_part(v, hl, Vector3(sx, 0.98, -2.20))

	ProcMesh.add_part(v, ProcMesh.box_mesh(Vector3(1.94, 0.65, 1.38), paint, 0.55, 0.28), Vector3(0, 0.98, -0.02))
	ProcMesh.add_part(v, ProcMesh.box_mesh(Vector3(1.80, 0.66, 1.24), glass, 0.18, 0.4), Vector3(0, 1.56, 0.02))
	ProcMesh.add_part(v, ProcMesh.box_mesh(Vector3(1.88, 0.12, 1.36), paint, 0.55, 0.28), Vector3(0, 1.92, 0.04))

	ProcMesh.add_part(v, ProcMesh.box_mesh(Vector3(1.92, 0.16, 1.68), dark), Vector3(0, 0.74, 1.44))
	ProcMesh.add_part(v, ProcMesh.box_mesh(Vector3(0.14, 0.56, 1.72), paint, 0.6, 0.22), Vector3(-0.90, 1.02, 1.44))
	ProcMesh.add_part(v, ProcMesh.box_mesh(Vector3(0.14, 0.56, 1.72), paint, 0.6, 0.22), Vector3(0.90, 1.02, 1.44))
	ProcMesh.add_part(v, ProcMesh.box_mesh(Vector3(1.92, 0.56, 0.14), paint, 0.6, 0.22), Vector3(0, 1.02, 2.22))
	ProcMesh.add_part(v, ProcMesh.box_mesh(Vector3(0.95, 0.62, 0.95), Color(0.46, 0.34, 0.20)), Vector3(-0.15, 1.12, 1.38))

	if has_canopy:
		var canvas := Color(0.36, 0.38, 0.29)
		ProcMesh.add_part(v, ProcMesh.box_mesh(Vector3(1.84, 0.75, 1.66), canvas, 0.92, 0.0), Vector3(0, 1.66, 1.44))
	else:
		ProcMesh.add_part(v, ProcMesh.cylinder_mesh(0.05, 0.80, dark, 0.4, 0.6, 6), Vector3(-0.82, 1.62, 0.74))
		ProcMesh.add_part(v, ProcMesh.cylinder_mesh(0.05, 0.80, dark, 0.4, 0.6, 6), Vector3(0.82, 1.62, 0.74))
		ProcMesh.add_part(v, ProcMesh.cylinder_mesh(0.05, 1.70, dark, 0.4, 0.6, 6), Vector3(0, 2.0, 0.74), Vector3(0, 0, 90))

	for wx in [-0.98, 0.98]:
		for wz in [-1.42, 1.42]:
			ProcMesh.add_part(v, ProcMesh.cylinder_mesh(0.42, 0.28, tire, 0.92, 0.05, 10), Vector3(wx, 0.42, wz), Vector3(0, 0, 90))
			ProcMesh.add_part(v, ProcMesh.cylinder_mesh(0.21, 0.30, rim, 0.4, 0.65, 8), Vector3(wx, 0.42, wz), Vector3(0, 0, 90))

	_add_box_collider(base_pos + Vector3(0, 0.95, 0), Vector3(2.15, 1.9, 4.55), rot_y_deg)


func _watchtower_at(c: Vector3) -> void:
	var timber := Color(0.34, 0.25, 0.17)
	var plank := Color(0.45, 0.34, 0.22)
	var tin := Color(0.33, 0.36, 0.38)
	var steel := Color(0.22, 0.24, 0.25)
	var span := 1.65

	for sx in [-span, span]:
		for sz in [-span, span]:
			_box(c + Vector3(sx, 3.0, sz), Vector3(0.28, 6.0, 0.28), timber, true)

	for sz in [-span, span]:
		ProcMesh.add_part(self, ProcMesh.box_mesh(Vector3(3.9, 0.14, 0.12), timber), c + Vector3(0, 1.65, sz), Vector3(0, 0, 42))
		ProcMesh.add_part(self, ProcMesh.box_mesh(Vector3(3.9, 0.14, 0.12), timber), c + Vector3(0, 1.65, sz), Vector3(0, 0, -42))
	for sx in [-span, span]:
		ProcMesh.add_part(self, ProcMesh.box_mesh(Vector3(0.12, 0.14, 3.9), timber), c + Vector3(sx, 1.65, 0), Vector3(42, 0, 0))
		ProcMesh.add_part(self, ProcMesh.box_mesh(Vector3(0.12, 0.14, 3.9), timber), c + Vector3(sx, 1.65, 0), Vector3(-42, 0, 0))

	_box(c + Vector3(0, 3.3, 0), Vector3(4.3, 0.32, 4.3), plank, true)
	_box(c + Vector3(0, 3.95, -2.0), Vector3(4.2, 1.05, 0.22), plank)
	_box(c + Vector3(-2.0, 3.95, 0), Vector3(0.22, 1.05, 4.2), plank)
	_box(c + Vector3(2.0, 3.95, 0), Vector3(0.22, 1.05, 4.2), plank)
	_box(c + Vector3(-1.3, 3.95, 2.0), Vector3(1.5, 1.05, 0.22), plank)
	_box(c + Vector3(1.3, 3.95, 2.0), Vector3(1.5, 1.05, 0.22), plank)
	var roof := ProcMesh.box_mesh(Vector3(4.8, 0.18, 4.8), tin, 0.55, 0.45)
	ProcMesh.add_part(self, roof, c + Vector3(0, 6.05, 0), Vector3(6, 0, 0))
	var spot_lamp := ProcMesh.box_mesh(Vector3(0.42, 0.26, 0.24), Color(1.0, 0.9, 0.6))
	spot_lamp.material_override = ProcMesh.emissive(Color(1.0, 0.88, 0.55), 1.8)
	ProcMesh.add_part(self, spot_lamp, c + Vector3(1.2, 5.75, 2.15))

	_box(c + Vector3(-0.34, 1.7, 2.15), Vector3(0.08, 3.4, 0.08), steel, false)
	_box(c + Vector3(0.34, 1.7, 2.15), Vector3(0.08, 3.4, 0.08), steel, false)
	for i in range(6):
		_box(c + Vector3(0, 0.35 + i * 0.52, 2.15), Vector3(0.72, 0.10, 0.14), steel, true)


func _jersey_barrier(pos: Vector3, rot_y_deg: float) -> void:
	var inst := KENNEY_WALL_LOW.instantiate()
	if inst is Node3D:
		var n := inst as Node3D
		n.position = pos
		n.rotation_degrees.y = rot_y_deg
		n.scale = Vector3(1.25, 1.1, 1.25)
		add_child(n)
		_add_box_collider(pos + Vector3(0, 0.55, 0), Vector3(2.2, 1.1, 0.65), rot_y_deg)


func _boulder(pos: Vector3, radius: float) -> void:
	var rock_col := Color(0.36, 0.35, 0.32)
	ProcMesh.add_part(self, ProcMesh.sphere_mesh(radius, rock_col, 0.92, 0.02), pos, Vector3(12, 35, 8))
	_add_box_collider(pos, Vector3(radius * 1.7, radius * 1.15, radius * 1.6), 0.0)


func _scatter_grass(grass_spots: Array) -> void:
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
