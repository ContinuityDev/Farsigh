extends Node3D
class_name OutpostManager
## Loads the selected outpost from OutpostCatalog, builds its geometry, spawns
## guards/snipers/alarms/reinforcement points, and tracks per-outpost liberation.

signal liberation_achieved

const GUARD_SCENE: PackedScene = preload("res://scenes/enemies/guard.tscn")
const ALARM_SCENE: PackedScene = preload("res://scenes/levels/alarm_panel.tscn")
const OutpostCatalog = preload("res://scripts/levels/outpost_catalog.gd")

@export var outpost_id: String = "compound_alpha"
@export var outpost_display_name: String = "Hope County Compound"

var _guards: Array[GuardAI] = []
var _alarms: Array[Node3D] = []
var liberated: bool = false


func _ready() -> void:
	add_to_group("outpost")
	outpost_id = GameState.selected_outpost_id
	var def := OutpostCatalog.get_outpost(outpost_id)
	outpost_display_name = String(def.get("name", outpost_display_name))
	_setup_environment(def)
	var greybox := get_node_or_null("Greybox")
	if greybox and greybox.has_method("build_outpost"):
		greybox.build_outpost(outpost_id)
	_position_player(def)
	liberated = GameState.is_liberated(outpost_id)
	_rebuild_outpost_entities(def)
	call_deferred("_bake_navmesh")
	call_deferred("_bind_guards")
	if liberated:
		call_deferred("_show_already_liberated")


func _bake_navmesh() -> void:
	var greybox := get_node_or_null("Greybox") as Node3D
	if not is_instance_valid(greybox):
		return
	# Temporarily let navmesh bake through closed doors so rooms stay connected
	var doors := get_tree().get_nodes_in_group("doors")
	for d in doors:
		if d.has_method("set_nav_bake_passable"):
			d.set_nav_bake_passable(true)

	var nav_region := get_node_or_null("OutpostNavRegion") as NavigationRegion3D
	if nav_region == null:
		nav_region = NavigationRegion3D.new()
		nav_region.name = "OutpostNavRegion"
		add_child(nav_region)

	var nav_mesh := NavigationMesh.new()
	nav_mesh.agent_radius = 0.5
	nav_mesh.agent_height = 1.75
	nav_mesh.agent_max_climb = 0.5
	nav_mesh.agent_max_slope = 50.0
	nav_mesh.cell_size = 0.25
	nav_mesh.cell_height = 0.25
	nav_mesh.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	nav_mesh.geometry_collision_mask = 1
	nav_mesh.geometry_source_geometry_mode = NavigationMesh.SOURCE_GEOMETRY_ROOT_NODE_CHILDREN

	var src := NavigationMeshSourceGeometryData3D.new()
	NavigationServer3D.parse_source_geometry_data(nav_mesh, src, greybox)
	NavigationServer3D.bake_from_source_geometry_data(nav_mesh, src)
	nav_region.navigation_mesh = nav_mesh

	for d in doors:
		if d.has_method("set_nav_bake_passable"):
			d.set_nav_bake_passable(false)


func _setup_environment(def: Dictionary) -> void:
	var we := get_node_or_null("WorldEnvironment") as WorldEnvironment
	if we == null:
		return
	var env := Environment.new()
	var sky := Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = def.get("sky_top", Color(0.24, 0.44, 0.70))
	sky_mat.sky_horizon_color = def.get("sky_horizon", Color(0.76, 0.71, 0.59))
	sky_mat.ground_bottom_color = Color(0.18, 0.22, 0.16)
	sky_mat.ground_horizon_color = Color(0.40, 0.44, 0.34)
	sky_mat.sun_angle_max = 22.0
	sky.sky_material = sky_mat
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_sky_contribution = 0.65
	env.ambient_light_color = Color(0.62, 0.64, 0.56)
	env.ambient_light_energy = 0.68
	env.fog_enabled = true
	env.fog_light_color = def.get("fog_color", Color(0.64, 0.66, 0.62))
	env.fog_density = 0.0042
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	we.environment = env


func _position_player(def: Dictionary) -> void:
	var player := get_node_or_null("Player") as Node3D
	if is_instance_valid(player):
		player.global_position = def.get("player_spawn", Vector3(0, 0.1, 30))


func _rebuild_outpost_entities(def: Dictionary) -> void:
	# Clear static scene placeholders (guards, alarms, reinforcement markers)
	var guards_root := get_node_or_null("Guards") as Node3D
	if guards_root == null:
		guards_root = Node3D.new()
		guards_root.name = "Guards"
		add_child(guards_root)
	for c in guards_root.get_children():
		c.queue_free()

	for old_name in ["AlarmPanel", "ReinforceA", "ReinforceB", "DynamicAlarms", "DynamicReinforce"]:
		var old_n := get_node_or_null(old_name)
		if old_n:
			old_n.queue_free()

	# Spawn reinforcement points
	var reinf_root := Node3D.new()
	reinf_root.name = "DynamicReinforce"
	add_child(reinf_root)
	var reinf_markers: Array[Marker3D] = []
	var reinf_positions: Array = def.get("reinforce_points", [Vector3(20, 0, 20), Vector3(-20, 0, 18)])
	for i in range(reinf_positions.size()):
		var m := Marker3D.new()
		m.name = "Reinforce_%d" % i
		m.position = reinf_positions[i]
		reinf_root.add_child(m)
		reinf_markers.append(m)

	# Spawn alarm panels
	var alarms_root := Node3D.new()
	alarms_root.name = "DynamicAlarms"
	add_child(alarms_root)
	_alarms.clear()
	var alarm_positions: Array = def.get("alarms", [Vector3(1, 0, -11)])
	for i in range(alarm_positions.size()):
		var alarm := ALARM_SCENE.instantiate() as Node3D
		alarm.name = "AlarmPanel_%d" % i
		alarm.position = alarm_positions[i]
		alarms_root.add_child(alarm)
		var paths: Array[NodePath] = []
		for rm in reinf_markers:
			paths.append(alarm.get_path_to(rm))
		if "reinforcement_points" in alarm:
			alarm.set("reinforcement_points", paths)
		_alarms.append(alarm)

	if liberated:
		return

	# Spawn guards / snipers / heavies / officers / dogs from outpost catalog
	var guard_specs: Array = def.get("guards", [])
	for i in range(guard_specs.size()):
		var spec: Dictionary = guard_specs[i]
		var g := GUARD_SCENE.instantiate() as GuardAI
		g.name = "Guard_%d" % (i + 1)
		g.position = spec.get("pos", Vector3(0, 0.1, 0))
		var pts: Array[Vector3] = []
		for p in spec.get("patrol", []):
			if p is Vector3:
				pts.append(p)
		g.setup_patrol_points(pts)
		guards_root.add_child(g)
		if g.has_method("apply_spawn_spec"):
			g.apply_spawn_spec(spec)
		else:
			g.is_sniper = bool(spec.get("sniper", false))
		# Bind nearest alarm panel (dogs skip — they don't press alarms)
		if not _alarms.is_empty() and not bool(g.get("is_dog")):
			var best_alarm: Node3D = _alarms[0]
			var best_d := g.position.distance_to(best_alarm.position)
			for a in _alarms:
				var d := g.position.distance_to(a.position)
				if d < best_d:
					best_d = d
					best_alarm = a
			g.alarm_path = g.get_path_to(best_alarm)


func _bind_guards() -> void:
	_guards.clear()
	_collect_guards(self)
	_update_count()
	var hud := get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("show_status") and not liberated:
		hud.show_status("%s — %d hostiles" % [outpost_display_name, _guards.size()], 3.5)


func _collect_guards(node: Node) -> void:
	for c in node.get_children():
		if c is GuardAI and not c.is_queued_for_deletion():
			register_guard(c)
		_collect_guards(c)


func register_guard(g: GuardAI) -> void:
	if g in _guards:
		return
	_guards.append(g)
	if not g.died.is_connected(_on_guard_died):
		g.died.connect(_on_guard_died)
	_update_count()


func _on_guard_died(g: GuardAI) -> void:
	_guards.erase(g)
	_update_count()
	if _guards.is_empty() and not liberated:
		_liberate()


func _update_count() -> void:
	var alive := 0
	for g in _guards:
		if is_instance_valid(g) and not g.is_queued_for_deletion() and g.is_alive():
			alive += 1
	GameState.set_guards_remaining(alive, outpost_id)
	var hud := get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("set_guard_count"):
		hud.set_guard_count(alive)


func _liberate() -> void:
	liberated = true
	GameState.mark_liberated(outpost_id)
	liberation_achieved.emit()
	var hud := get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("show_liberation"):
		hud.show_liberation(outpost_display_name)


func _show_already_liberated() -> void:
	for g in get_tree().get_nodes_in_group("guards"):
		if g is GuardAI and is_ancestor_of(g):
			g.queue_free()
	var hud := get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("show_status"):
		hud.show_status("%s — Liberated" % outpost_display_name, 4.0)
	if hud and hud.has_method("set_liberated_banner"):
		hud.set_liberated_banner(true)
