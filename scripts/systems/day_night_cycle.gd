extends Node
## Dynamic day/night cycle: sun/moon, sky colours, fog, compound lights,
## guard vision scaling, and darker player shadows at night.


signal time_changed(hour: float, is_night: bool)
signal night_changed(is_night: bool)

## Hours of game-time per real second (default: 24h cycle ≈ 8 real minutes)
@export var cycle_hours_per_second: float = 24.0 / 480.0
## Starting hour for a new run (0–24). 14 = mid-afternoon.
@export var start_hour: float = 14.0

var hour: float = 14.0
var paused: bool = false
var _was_night: bool = false
var _sun: DirectionalLight3D
var _fill: OmniLight3D
var _sky_mat: ProceduralSkyMaterial
var _env: Environment
var _compound_lights: Array = []  # OmniLight3D / SpotLight3D
var _bound: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	set_process(true)


func reset_for_run(start: float = -1.0) -> void:
	hour = start if start >= 0.0 else start_hour
	_was_night = is_night()
	_bound = false
	call_deferred("bind_to_scene")


func bind_to_scene() -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return
	_sun = scene.get_node_or_null("Sun") as DirectionalLight3D
	_fill = scene.get_node_or_null("FillLight") as OmniLight3D
	var we := scene.get_node_or_null("WorldEnvironment") as WorldEnvironment
	if we and we.environment:
		_env = we.environment
		if _env.sky and _env.sky.sky_material is ProceduralSkyMaterial:
			_sky_mat = _env.sky.sky_material as ProceduralSkyMaterial
	_compound_lights.clear()
	for n in scene.get_tree().get_nodes_in_group("compound_lights"):
		_compound_lights.append(n)
	_bound = true
	_apply_visuals(true)
	time_changed.emit(hour, is_night())


func is_night() -> bool:
	return hour < 5.5 or hour >= 20.0


func is_dusk_or_dawn() -> bool:
	return (hour >= 5.5 and hour < 7.5) or (hour >= 18.0 and hour < 20.0)


## 1.0 = full day vision, ~0.45 at deep night.
func vision_mult() -> float:
	if is_night():
		return 0.42
	if is_dusk_or_dawn():
		return 0.72
	return 1.0


## Extra shadow hide bonus for the player at night (0–1).
func hide_shadow_bonus() -> float:
	if is_night():
		return 0.55
	if is_dusk_or_dawn():
		return 0.25
	return 0.0


func set_hour(h: float) -> void:
	hour = fposmod(h, 24.0)
	_apply_visuals(true)


func _process(delta: float) -> void:
	if paused or GameState.is_paused:
		return
	if not _bound:
		bind_to_scene()
		return
	hour = fposmod(hour + cycle_hours_per_second * delta, 24.0)
	var night_now := is_night()
	if night_now != _was_night:
		_was_night = night_now
		night_changed.emit(night_now)
	_apply_visuals(false)
	time_changed.emit(hour, night_now)


func _apply_visuals(force: bool) -> void:
	# Sun angle: noon at 12 → overhead, midnight below horizon
	var sun_angle := (hour - 6.0) / 24.0 * TAU  # 6am sunrise
	var elev := sin(sun_angle)
	var azim := cos(sun_angle)
	if is_instance_valid(_sun):
		var pitch := -elev * 75.0  # degrees down when elevated
		var yaw := azim * 60.0
		_sun.rotation_degrees = Vector3(pitch, yaw, 0.0)
		if elev > 0.05:
			_sun.light_energy = lerpf(0.22, 0.85, clampf(elev, 0.0, 1.0))
			_sun.light_color = Color(1.0, 0.96, 0.88).lerp(Color(1.0, 0.55, 0.28), clampf(1.0 - elev * 1.6, 0.0, 1.0))
			_sun.visible = true
		else:
			# Moon-ish cool dim light
			_sun.light_energy = lerpf(0.06, 0.16, clampf(-elev, 0.0, 1.0))
			_sun.light_color = Color(0.55, 0.65, 0.95)
			_sun.visible = true
		# Shadows on Med/High only, shorter distance on Med
		if GraphicsQuality and GraphicsQuality.wants_shadows():
			_sun.shadow_enabled = true
			_sun.directional_shadow_max_distance = GraphicsQuality.shadow_distance()
			_sun.directional_shadow_blend_splits = GraphicsQuality.level >= GraphicsQuality.LEVEL_HIGH
		else:
			_sun.shadow_enabled = false

	if is_instance_valid(_fill):
		_fill.light_energy = 0.22 if not is_night() else 0.08
		_fill.light_color = Color(0.75, 0.82, 0.95) if not is_night() else Color(0.35, 0.42, 0.7)

	if is_instance_valid(_sky_mat):
		if is_night():
			_sky_mat.sky_top_color = Color(0.04, 0.06, 0.14)
			_sky_mat.sky_horizon_color = Color(0.10, 0.12, 0.22)
			_sky_mat.ground_horizon_color = Color(0.08, 0.09, 0.12)
			_sky_mat.ground_bottom_color = Color(0.04, 0.05, 0.06)
		elif is_dusk_or_dawn():
			_sky_mat.sky_top_color = Color(0.28, 0.32, 0.55)
			_sky_mat.sky_horizon_color = Color(0.92, 0.55, 0.32)
			_sky_mat.ground_horizon_color = Color(0.45, 0.35, 0.28)
		else:
			# Keep catalog daytime colours if already set; gently push clear day
			_sky_mat.sky_top_color = _sky_mat.sky_top_color.lerp(Color(0.30, 0.52, 0.82), 0.15 if force else 0.02)
			_sky_mat.sky_horizon_color = _sky_mat.sky_horizon_color.lerp(Color(0.78, 0.74, 0.62), 0.15 if force else 0.02)

	if is_instance_valid(_env):
		if is_night():
			_env.ambient_light_energy = 0.22
			_env.ambient_light_color = Color(0.22, 0.28, 0.42)
			_env.fog_light_color = Color(0.08, 0.10, 0.16)
			_env.fog_density = 0.0048 * (GraphicsQuality.fog_density_scale() if GraphicsQuality else 1.0)
			_env.tonemap_exposure = 0.92
		elif is_dusk_or_dawn():
			_env.ambient_light_energy = 0.32
			_env.ambient_light_color = Color(0.72, 0.48, 0.32)
			_env.fog_light_color = Color(0.62, 0.32, 0.18)
			_env.fog_density = 0.0036 * (GraphicsQuality.fog_density_scale() if GraphicsQuality else 1.0)
			_env.tonemap_exposure = 0.9
		else:
			_env.ambient_light_energy = 0.38
			_env.ambient_light_color = Color(0.55, 0.58, 0.52)
			_env.fog_light_color = Color(0.50, 0.56, 0.50)
			_env.fog_density = 0.0024 * (GraphicsQuality.fog_density_scale() if GraphicsQuality else 1.0)
			_env.tonemap_exposure = 0.86

	if GraphicsQuality and is_instance_valid(_env):
		GraphicsQuality.apply_sky(_env, hour, elev)

	# Compound / flashlight lights — on at night
	var want_lights := is_night() or is_dusk_or_dawn()
	for l in _compound_lights:
		if is_instance_valid(l) and l is Light3D:
			(l as Light3D).visible = want_lights
			if want_lights:
				(l as Light3D).light_energy = 1.4 if is_night() else 0.7
