extends Node3D
class_name OutpostManager
## Loads the selected outpost from OutpostCatalog in staged chunks with a
## loading screen, freezes AI until the player is placed, then opens a short
## detection grace window. Geometry / guards / weapons are built incrementally
## so mobile WebGL can upload meshes without starving the graphics context.

signal liberation_achieved

const GUARD_PATH := "res://scenes/enemies/guard.tscn"
const ALARM_PATH := "res://scenes/levels/alarm_panel.tscn"
const GUARD_SCENE: PackedScene = preload("res://scenes/enemies/guard.tscn")
const ALARM_SCENE: PackedScene = preload("res://scenes/levels/alarm_panel.tscn")
const LOADING_SCENE: PackedScene = preload("res://scenes/ui/loading_overlay.tscn")
const OutpostCatalog = preload("res://scripts/levels/outpost_catalog.gd")
const ThreadedLoader = preload("res://scripts/systems/threaded_loader.gd")

@export var outpost_id: String = "compound_alpha"
@export var outpost_display_name: String = "Hope County Compound"

var _guards: Array[GuardAI] = []
var _alarms: Array[Node3D] = []
var liberated: bool = false  # already beaten before this deploy (replay)
var _loader: Node = null
var _load_errors: PackedStringArray = []
var _clearing: bool = false
var _clear_failed: bool = false
var _results_shown: bool = false


func _ready() -> void:
	add_to_group("outpost")
	GameState.begin_world_load()
	GameState.begin_deploy_stats()
	outpost_id = GameState.selected_outpost_id
	var def := OutpostCatalog.get_outpost(outpost_id)
	outpost_display_name = String(def.get("name", outpost_display_name))
	liberated = GameState.is_liberated(outpost_id)  # replay if true
	_freeze_player(true)
	_freeze_hud(true)
	_ensure_loader()
	call_deferred("_run_load_pipeline", def)


func _ensure_loader() -> void:
	_loader = get_node_or_null("LoadingOverlay")
	if _loader == null:
		_loader = LOADING_SCENE.instantiate()
		_loader.name = "LoadingOverlay"
		add_child(_loader)


func _run_load_pipeline(def: Dictionary) -> void:
	_load_errors.clear()
	# 1. Environment
	_set_load_progress(0.05, "Environment & lighting")
	await get_tree().process_frame
	_stage_environment(def)
	await get_tree().process_frame

	# 2. Stage geometry (chunked + yields inside greybox)
	_set_load_progress(0.10, "Stage geometry")
	var geo_errs: PackedStringArray = await _stage_geometry_async()
	for e in geo_errs:
		_report_load_error(String(e))
	_set_load_progress(0.52, "Props & cover")
	await get_tree().process_frame
	await get_tree().process_frame

	# 3. Navmesh
	_set_load_progress(0.58, "Navigation mesh")
	await get_tree().process_frame
	_bake_navmesh()
	await get_tree().process_frame

	# 4. Guards / dogs / alarms
	_set_load_progress(0.68, "Guards & dogs")
	var guard_errs: PackedStringArray = await _stage_guards_async(def)
	for e2 in guard_errs:
		_report_load_error(String(e2))
	_set_load_progress(0.82, "Guards ready")
	await get_tree().process_frame

	# 5. Weapons / viewmodels
	_set_load_progress(0.88, "Weapons & viewmodels")
	await _stage_weapons()
	await get_tree().process_frame

	# 6. HUD
	_set_load_progress(0.94, "HUD")
	_freeze_hud(false)
	await get_tree().process_frame

	# 7. Player LAST
	_set_load_progress(0.98, "Spawning operative")
	await _stage_player(def)

	_bind_guards()
	# Beaten compounds still get a full garrison for replay (currency reduced).
	if liberated:
		var hud0 := get_tree().get_first_node_in_group("hud")
		if hud0 and hud0.has_method("show_status"):
			hud0.show_status("%s — REPLAY (best payout saved)" % outpost_display_name, 3.5)

	# Verify critical content landed
	var grey := get_node_or_null("Greybox")
	var grey_n := grey.get_child_count() if grey else -1
	var mesh_n := _count_meshes(grey) if grey else 0
	print("OUTPOST_LOAD_VERIFY grey_children=", grey_n, " meshes=", mesh_n, " guards=", _count_group("guards"))
	if grey == null or grey_n < 4 or mesh_n < 4:
		_report_load_error("Stage geometry missing or incomplete (parts=%d meshes=%d)" % [grey_n, mesh_n])
	var player := get_node_or_null("Player")
	if player == null:
		_report_load_error("Player failed to activate")
	else:
		var cam := player.get_node_or_null("Head/Camera3D") as Camera3D
		if cam:
			cam.current = true
		var vm := cam.get_node_or_null("Viewmodels") if cam else null
		var vm_meshes := _count_meshes(vm) if vm else 0
		print("OUTPOST_LOAD_VERIFY viewmodel_meshes=", vm_meshes)
		if vm == null or vm_meshes < 1:
			_report_load_error("Weapon viewmodels missing")

	GameState.finish_world_load()
	_set_guards_ai_enabled(true)

	if is_instance_valid(_loader):
		if _load_errors.is_empty():
			await _loader.finish_ok("%s ready" % outpost_display_name)
		else:
			await _loader.finish_failed("Some assets failed — see messages above. (%d)" % _load_errors.size())

	var hud := get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("show_status") and not liberated:
		hud.show_status("%s — %d hostiles" % [outpost_display_name, _guards.size()], 3.5)


func _count_meshes(node: Node) -> int:
	if node == null:
		return 0
	var n := 0
	if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
		n = 1
	for c in node.get_children():
		n += _count_meshes(c)
	return n


func _count_group(group_name: String) -> int:
	var n := 0
	for g in get_tree().get_nodes_in_group(group_name):
		if is_instance_valid(g):
			n += 1
	return n


func _set_load_progress(p: float, label: String, detail: String = "") -> void:
	if is_instance_valid(_loader) and _loader.has_method("set_progress"):
		_loader.set_progress(p, label, detail)


func _report_load_error(msg: String) -> void:
	_load_errors.append(msg)
	if is_instance_valid(_loader) and _loader.has_method("report_error"):
		_loader.report_error(msg)
	else:
		push_error("[OutpostLoad] %s" % msg)
		print("OUTPOST_LOAD_ERROR ", msg)


func _stage_environment(def: Dictionary) -> void:
	_setup_environment(def)


func _stage_geometry_async() -> PackedStringArray:
	var greybox := get_node_or_null("Greybox")
	if greybox == null:
		return PackedStringArray(["Greybox node missing from outpost scene"])
	if greybox.has_method("build_outpost_async"):
		var on_stage := func(label: String, t: float):
			if is_instance_valid(_loader) and _loader.has_method("set_progress"):
				# Geometry occupies ~8–50% of the overall bar
				_loader.set_progress(0.08 + t * 0.42, label)
		var errs: PackedStringArray = await greybox.build_outpost_async(outpost_id, on_stage)
		return errs
	if greybox.has_method("build_outpost"):
		greybox.build_outpost(outpost_id)
		await get_tree().process_frame
		return PackedStringArray()
	return PackedStringArray(["Greybox has no build method"])


func _stage_guards_async(def: Dictionary) -> PackedStringArray:
	var errs: PackedStringArray = []
	# Prefer threaded/chunked load of the guard packed scene (web falls back)
	var load_errs: Array = []
	var packed: Resource = await ThreadedLoader.load_async(self, GUARD_PATH, "PackedScene", load_errs)
	for le in load_errs:
		errs.append(String(le))
	var guard_scene: PackedScene = packed as PackedScene if packed is PackedScene else GUARD_SCENE
	if guard_scene == null:
		errs.append("Guard scene unavailable")
		return errs

	var alarm_errs: Array = []
	var alarm_res: Resource = await ThreadedLoader.load_async(self, ALARM_PATH, "PackedScene", alarm_errs)
	for ae in alarm_errs:
		errs.append(String(ae))
	var alarm_scene: PackedScene = alarm_res as PackedScene if alarm_res is PackedScene else ALARM_SCENE

	await _rebuild_outpost_entities_async(def, guard_scene, alarm_scene)
	_set_guards_ai_enabled(false)
	var expected := OutpostCatalog.guard_count(def)
	var got := 0
	var root := get_node_or_null("Guards")
	if root:
		for c in root.get_children():
			if c is GuardAI:
				got += 1
	if not liberated and got < expected:
		errs.append("Spawned %d/%d hostiles" % [got, expected])
	return errs


func _stage_weapons() -> void:
	var player := get_node_or_null("Player")
	if player == null:
		_report_load_error("No player for weapon bind")
		return
	var cam := player.get_node_or_null("Head/Camera3D")
	var vm := cam.get_node_or_null("Viewmodels") if cam else null
	if vm and vm.has_method("rebuild_all_async"):
		await vm.rebuild_all_async(self)
	elif vm and vm.has_method("rebuild_all_from_state"):
		vm.rebuild_all_from_state()
		await get_tree().process_frame
	var wm := player.get_node_or_null("WeaponManager")
	if wm and wm.has_method("_refresh_viewmodel"):
		wm._refresh_viewmodel(false)
	elif wm and wm.has_method("get_active") and vm and vm.has_method("show_weapon"):
		var active = wm.get_active()
		if active:
			vm.show_weapon(active.id, false)
	await get_tree().process_frame


func _stage_player(def: Dictionary) -> void:
	_position_player(def)
	_ensure_support_systems()
	_freeze_player(false)
	await get_tree().process_frame


func _ensure_support_systems() -> void:
	if get_node_or_null("StreakManager") == null:
		var sm := Node.new()
		sm.set_script(load("res://scripts/systems/streak_manager.gd"))
		sm.name = "StreakManager"
		add_child(sm)
	if get_node_or_null("Binoculars") == null:
		var bino := Node.new()
		bino.set_script(load("res://scripts/player/binoculars.gd"))
		bino.name = "Binoculars"
		add_child(bino)
	if get_node_or_null("AllyManager") == null:
		var am := Node.new()
		am.set_script(load("res://scripts/systems/ally_manager.gd"))
		am.name = "AllyManager"
		add_child(am)


func _freeze_player(frozen: bool) -> void:
	var player := get_node_or_null("Player")
	if not is_instance_valid(player):
		return
	if frozen:
		player.visible = false
		player.set_physics_process(false)
		player.set_process(false)
		player.process_mode = Node.PROCESS_MODE_DISABLED
	else:
		player.visible = true
		player.process_mode = Node.PROCESS_MODE_INHERIT
		player.set_physics_process(true)
		player.set_process(true)


func _freeze_hud(frozen: bool) -> void:
	var hud := get_node_or_null("HUD")
	if not is_instance_valid(hud):
		return
	# Keep CanvasLayer process for pause, but hide the root during load
	var root := hud.get_node_or_null("Root")
	if root:
		root.visible = not frozen
	var touch := hud.get_node_or_null("TouchControls")
	if touch and frozen:
		touch.visible = false
	elif touch and not frozen and TouchInput.is_touch_ui_desired() and not GameState.is_paused:
		touch.visible = true


func _set_guards_ai_enabled(enabled: bool) -> void:
	for g in get_tree().get_nodes_in_group("guards"):
		if not is_instance_valid(g):
			continue
		if enabled:
			g.process_mode = Node.PROCESS_MODE_INHERIT
			g.set_physics_process(true)
		else:
			g.set_physics_process(false)
			g.process_mode = Node.PROCESS_MODE_DISABLED


func _bake_navmesh() -> void:
	var greybox := get_node_or_null("Greybox") as Node3D
	if not is_instance_valid(greybox):
		_report_load_error("Navmesh bake skipped — no Greybox")
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
	# Slightly coarser on web/mobile for faster bake / less memory
	var webish := OS.has_feature("web") or OS.has_feature("mobile")
	nav_mesh.cell_size = 0.35 if webish else 0.25
	nav_mesh.cell_height = 0.35 if webish else 0.25
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
	var fog_scale := 1.0
	if GraphicsQuality:
		fog_scale = GraphicsQuality.fog_density_scale()
	env.fog_density = 0.0042 * fog_scale
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	we.environment = env
	if GraphicsQuality:
		GraphicsQuality.apply()
	# Day/night cycle binds sun/sky/compound lights after env is ready
	if DayNightCycle:
		DayNightCycle.cycle_hours_per_second = GameState.day_cycle_hours_per_second
		DayNightCycle.start_hour = GameState.day_start_hour
		DayNightCycle.reset_for_run(GameState.day_start_hour)
		DayNightCycle.call_deferred("bind_to_scene")


func _position_player(def: Dictionary) -> void:
	var player := get_node_or_null("Player") as Node3D
	if is_instance_valid(player):
		player.global_position = def.get("player_spawn", Vector3(0, 0.1, 30))


func _rebuild_outpost_entities_async(def: Dictionary, guard_scene: PackedScene, alarm_scene: PackedScene) -> void:
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
	await get_tree().process_frame

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
	var alarm_ps: PackedScene = alarm_scene if alarm_scene else ALARM_SCENE
	for i in range(alarm_positions.size()):
		var alarm := alarm_ps.instantiate() as Node3D
		alarm.name = "AlarmPanel_%d" % i
		alarm.position = alarm_positions[i]
		alarms_root.add_child(alarm)
		var paths: Array[NodePath] = []
		for rm in reinf_markers:
			paths.append(alarm.get_path_to(rm))
		if "reinforcement_points" in alarm:
			alarm.set("reinforcement_points", paths)
		_alarms.append(alarm)
	# Layered defences for hard compounds (cameras / searchlights / tripwires)
	var old_sec := get_node_or_null("SecurityProps")
	if old_sec:
		old_sec.queue_free()
	SecurityProps.spawn_all(self, def)
	await get_tree().process_frame

	# Always spawn full garrison (including replays of beaten compounds)

	# Spawn guards in small batches so mobile WebGL can upload meshes
	var guard_specs: Array = def.get("guards", [])
	var guard_ps: PackedScene = guard_scene if guard_scene else GUARD_SCENE
	for i in range(guard_specs.size()):
		var spec: Dictionary = guard_specs[i]
		var g := guard_ps.instantiate() as GuardAI
		if g == null:
			_report_load_error("Failed to instantiate guard %d" % (i + 1))
			continue
		g.name = "Guard_%d" % (i + 1)
		g.position = spec.get("pos", Vector3(0, 0.1, 0))
		var pts: Array[Vector3] = []
		for p in spec.get("patrol", []):
			if p is Vector3:
				pts.append(p)
		g.setup_patrol_points(pts)
		# Freeze AI until load completes (also gated by GameState)
		g.process_mode = Node.PROCESS_MODE_DISABLED
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
		if i % 2 == 1:
			await get_tree().process_frame
			_set_load_progress(0.68 + 0.12 * float(i + 1) / float(maxi(guard_specs.size(), 1)), "Guards & dogs", "Hostile %d/%d" % [i + 1, guard_specs.size()])


func _bind_guards() -> void:
	_guards.clear()
	_collect_guards(self)
	_update_count()


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
	if _guards.is_empty() and not _clearing and not _results_shown:
		_begin_clear_countdown()


func _update_count() -> void:
	var alive := 0
	for g in _guards:
		if is_instance_valid(g) and not g.is_queued_for_deletion() and g.is_alive():
			alive += 1
	GameState.set_guards_remaining(alive, outpost_id)
	var hud := get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("set_guard_count"):
		hud.set_guard_count(alive)


func _begin_clear_countdown() -> void:
	_clearing = true
	_clear_failed = false
	GameState.clearing_in_progress = true
	var hud := get_tree().get_first_node_in_group("hud")
	for i in range(3, 0, -1):
		if _clear_failed:
			break
		if hud and hud.has_method("show_clear_countdown"):
			hud.show_clear_countdown(i)
		elif hud and hud.has_method("show_status"):
			hud.show_status("Compound clearing… %d" % i, 1.05)
		await get_tree().create_timer(1.0).timeout
		# Fail if player died or reinforcements / new guards appeared
		if _player_is_down():
			_clear_failed = true
			break
		_refresh_alive_guards()
		if not _guards.is_empty():
			_clear_failed = true
			break
	_clearing = false
	GameState.clearing_in_progress = false
	if _clear_failed:
		if hud and hud.has_method("show_status"):
			hud.show_status("Clear interrupted — finish remaining hostiles", 3.5)
		return
	await _complete_clear()


func _player_is_down() -> bool:
	var player := get_node_or_null("Player")
	if player == null:
		return true
	if player.has_method("is_down") and player.is_down():
		return true
	if "is_down" in player and bool(player.get("is_down")):
		return true
	if "hp" in player and float(player.get("hp")) <= 0.0:
		return true
	return false


func _refresh_alive_guards() -> void:
	_guards.clear()
	_collect_guards(self)
	var alive: Array[GuardAI] = []
	for g in _guards:
		if is_instance_valid(g) and not g.is_queued_for_deletion() and g.is_alive():
			alive.append(g)
	_guards = alive


func _complete_clear() -> void:
	if _results_shown:
		return
	_results_shown = true
	var was_replay := liberated
	var stats: Dictionary = GameState.run_stats.to_dict() if GameState.run_stats else {}
	var payout_info: Dictionary = ShopCatalog.compute_payout(outpost_id, stats, was_replay)
	var total := int(payout_info.get("total", 0))
	GameState.add_currency(total)
	GameState.record_best_clear(outpost_id, stats, total)
	liberated = true
	liberation_achieved.emit()
	var hud := get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("show_clear_results"):
		hud.show_clear_results(outpost_display_name, payout_info, was_replay, GameState.currency)
	elif hud and hud.has_method("show_liberation"):
		hud.show_liberation(outpost_display_name)
