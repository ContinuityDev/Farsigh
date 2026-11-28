extends CharacterBody3D
class_name GuardAI
## Modular guard: patrol → suspicious → alert/search → combat.
## Per-guard awareness (? filling / ! spotted). Hearing → INVESTIGATE only
## (never instant spot). Delayed interruptible shout/radio warn to nearby.

signal died(guard: GuardAI)
signal state_changed(new_state: String)

enum State { PATROL, SUSPICIOUS, ALERT, COMBAT, DEAD }

const MOVE_SPEED := 2.4
const ALERT_SPEED := 3.6
const COMBAT_SPEED := 4.0
const VISION_RANGE := 28.0
const VISION_ANGLE := 55.0  # degrees half-angle
const HEARING_SCALE := 1.0
const DETECTION_RATE := 0.55
const DETECTION_DECAY := 0.35
const SEARCH_TIME := 12.0
const SUSPICIOUS_TIME := 5.0
const MAX_HP := 100.0
const HEAVY_HP := 220.0
const DOG_HP := 55.0
const WARN_DELAY_MIN := 1.5
const WARN_DELAY_MAX := 3.0
const WARN_SHOUT_RANGE := 28.0
const WARN_RADIO_RANGE := 55.0
const BUMP_NOTICE_DIST := 1.55
## AI LOD distances (metres) for mobile / web performance
const LOD_NEAR := 28.0
const LOD_MID := 48.0
const LOD_FAR := 72.0

@export var patrol_path: NodePath
@export var alarm_path: NodePath
@export var is_sniper: bool = false
@export var is_heavy: bool = false
@export var is_officer: bool = false
@export var is_dog: bool = false
@export var is_sentry: bool = false
@export var role: String = "patrol"
@export var chat_pair: String = ""
@export var dog_id: String = ""

var state: State = State.PATROL
var hp: float = MAX_HP
var max_hp: float = MAX_HP
var detection: float = 0.0
var last_known_pos: Vector3 = Vector3.ZERO
var investigate_pos: Vector3 = Vector3.ZERO
var _state_timer: float = 0.0
var _patrol_index: int = 0
var _patrol_points: Array[Vector3] = []
var _fire_cooldown: float = 0.0
var _going_to_alarm: bool = false
var _alarm_used: bool = false
var _spotted_emitted: bool = false
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

@onready var vision_ray: RayCast3D = $VisionRay
@onready var label: Label3D = $StateLabel
@onready var visual: GuardVisual = $Visual
@onready var hit_zones: Node3D = $HitZones
@onready var nav_agent: NavigationAgent3D = get_node_or_null("NavigationAgent3D") as NavigationAgent3D

var _nav_last_target: Vector3 = Vector3(1e9, 1e9, 1e9)
var _door_check_cd: float = 0.0
var _lod_accum: float = 0.0
var _lod_tier: int = 0  # 0 near, 1 mid, 2 far, 3 cull
var _chat_timer: float = 0.0
var _hearing_scale: float = HEARING_SCALE
var _move_mult: float = 1.0
var _vision_mult: float = 1.0
var _body_armor: float = 1.0  # multiplies non-head damage taken (heavies < 1)

var _body_scene: PackedScene = preload("res://scenes/items/body.tscn")
var _last_hit_zone: String = ""
var _death_kind: String = "body"  # body | head | back | explode
var tagged: bool = false
var _has_los: bool = false
var _lost_los_t: float = 0.0
var _cover_pose: String = ""
var _cover_pos: Vector3 = Vector3.ZERO
var _cover_refresh: float = 0.0
var _peek_t: float = 0.0
var _combat_role: String = "hold"  # hold (suppress) | flank
var _escalated_search: bool = false
var _search_spots: Array[Vector3] = []
var _search_idx: int = 0
var _ghost: Node3D = null
var _tag_icon: Label3D = null
var _alert_icon: Label3D = null
var _meter_bg: MeshInstance3D = null
var _meter_fill: MeshInstance3D = null
var _warn_timer: float = -1.0
var _warned: bool = false
var _role_prefix: String = ""


func _ready() -> void:
	add_to_group("guards")
	collision_layer = 4
	collision_mask = 1 | 2
	floor_max_angle = deg_to_rad(52.0)
	floor_snap_length = 0.35
	NoiseBus.noise_emitted.connect(_on_noise)
	_apply_role_stats()
	if is_instance_valid(visual):
		visual.set_placeholder_color(Color(0.55, 0.25, 0.2))
		visual.set_sniper_look(is_sniper)
		if visual.has_method("apply_role_look"):
			visual.apply_role_look(role if role != "" else ("sniper" if is_sniper else "patrol"), is_heavy, is_officer, is_dog)
	if _patrol_points.is_empty():
		_cache_patrol()
	_set_state(State.PATROL)


func setup_patrol_points(points: Array[Vector3]) -> void:
	_patrol_points = points.duplicate()
	_patrol_index = 0


func set_tagged(on: bool) -> void:
	tagged = on
	if not on:
		if is_instance_valid(_tag_icon):
			_tag_icon.queue_free()
			_tag_icon = null
		return
	if not is_instance_valid(_tag_icon):
		_tag_icon = Label3D.new()
		_tag_icon.name = "TagIcon"
		_tag_icon.font_size = 40
		_tag_icon.outline_size = 8
		_tag_icon.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		# Sit above the ?/! meter so binocular tags coexist cleanly
		_tag_icon.position = Vector3(0, 2.55, 0)
		_tag_icon.no_depth_test = true
		add_child(_tag_icon)
	_refresh_tag_icon()
	_ensure_alert_meter()


func _refresh_tag_icon() -> void:
	if not is_instance_valid(_tag_icon):
		return
	var icon := "◎"
	if is_sniper:
		icon = "◎ S"
	elif is_dog or role == "dog":
		icon = "◎ D"
	elif is_heavy or role == "heavy":
		icon = "◎ H"
	elif role == "commander":
		icon = "◎ BOSS"
	elif is_officer or role == "officer":
		icon = "◎ O"
	_tag_icon.text = icon
	match state:
		State.COMBAT:
			_tag_icon.modulate = Color(1.0, 0.28, 0.22)
		State.ALERT:
			_tag_icon.modulate = Color(1.0, 0.72, 0.18)
		State.SUSPICIOUS:
			_tag_icon.modulate = Color(0.95, 0.88, 0.35)
		_:
			_tag_icon.modulate = Color(0.3, 0.95, 1.0)


func apply_spawn_spec(spec: Dictionary) -> void:
	role = String(spec.get("role", "patrol"))
	is_sniper = bool(spec.get("sniper", false))
	is_sentry = bool(spec.get("sentry", false)) or role == "sentry"
	is_heavy = bool(spec.get("heavy", false)) or role == "heavy"
	is_officer = bool(spec.get("officer", false)) or role == "officer" or role == "commander"
	is_dog = bool(spec.get("dog", false)) or role == "dog"
	chat_pair = String(spec.get("chat_pair", ""))
	dog_id = String(spec.get("dog_id", ""))
	if role == "handler":
		is_officer = false
	rotation_degrees.y = float(spec.get("rot", 0.0))
	_apply_role_stats()
	if is_instance_valid(visual):
		visual.set_sniper_look(is_sniper)
		if visual.has_method("apply_role_look"):
			visual.apply_role_look(role if role != "" else ("sniper" if is_sniper else "patrol"), is_heavy, is_officer, is_dog)


func _apply_role_stats() -> void:
	max_hp = MAX_HP
	_hearing_scale = HEARING_SCALE
	_move_mult = 1.0
	_vision_mult = 1.0
	_body_armor = 1.0
	if is_sniper:
		_vision_mult = 1.65
	if is_heavy:
		max_hp = HEAVY_HP
		_body_armor = 0.55  # tougher body; headshots still one-shot
		_move_mult = 0.82
	if is_officer:
		_hearing_scale = 1.25
		_move_mult = 1.08
	if role == "commander":
		max_hp = HEAVY_HP + 40.0
		_hearing_scale = 1.4
		_vision_mult = 1.35
		_move_mult = 1.05
		_body_armor = 0.65
	if is_dog:
		max_hp = DOG_HP
		_hearing_scale = 1.85
		_move_mult = 1.45
		_vision_mult = 0.72
	hp = max_hp


func set_sniper(enabled: bool) -> void:
	is_sniper = enabled
	if is_instance_valid(visual):
		visual.set_sniper_look(is_sniper)


func _cache_patrol() -> void:
	_patrol_points.clear()
	var path_node := get_node_or_null(patrol_path)
	if path_node:
		for c in path_node.get_children():
			if c is Node3D:
				_patrol_points.append((c as Node3D).global_position)
	if _patrol_points.is_empty():
		_patrol_points.append(global_position)
		_patrol_points.append(global_position + transform.basis.x * 6.0)
		_patrol_points.append(global_position - transform.basis.z * 6.0)


func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		return
	# Frozen during staged outpost load + short post-spawn grace
	if GameState.is_detection_frozen():
		velocity = Vector3.ZERO
		return
	if not is_on_floor():
		velocity.y -= gravity * delta

	_update_lod_tier()
	# Far AI: throttle expensive vision / awareness ticks for mobile browsers
	var tick_vision := true
	if _lod_tier >= 2:
		_lod_accum += delta
		var interval := 0.28 if _lod_tier == 2 else 0.55
		if _lod_accum < interval:
			tick_vision = false
		else:
			_lod_accum = 0.0
	elif _lod_tier == 1:
		_lod_accum += delta
		if _lod_accum < 0.12:
			tick_vision = false
		else:
			_lod_accum = 0.0

	_fire_cooldown = maxf(0.0, _fire_cooldown - delta)
	if tick_vision:
		_update_vision(delta)
		if _lod_tier < 3:
			_update_world_awareness(delta)

	match state:
		State.PATROL:
			_do_patrol(delta)
		State.SUSPICIOUS:
			_do_investigate(delta)
		State.ALERT:
			_do_search(delta)
		State.COMBAT:
			_do_combat(delta)
			_tick_warn(delta)

	move_and_slide()
	if state != State.COMBAT:
		_cover_pose = ""
	if is_instance_valid(visual) and _lod_tier < 3:
		var horiz := Vector2(velocity.x, velocity.z).length()
		if visual.has_method("set_cover_pose"):
			visual.set_cover_pose(_cover_pose)
		visual.set_locomotion(horiz > 0.25, state == State.COMBAT, state == State.SUSPICIOUS, state == State.ALERT)
	if _lod_tier < 2:
		_update_label()
	elif is_instance_valid(label):
		label.visible = false


func _update_lod_tier() -> void:
	var player := get_tree().get_first_node_in_group("player") as Node3D
	if not is_instance_valid(player):
		_lod_tier = 1
		return
	var d := global_position.distance_to(player.global_position)
	if d < LOD_NEAR or state == State.COMBAT or state == State.ALERT:
		_lod_tier = 0
	elif d < LOD_MID:
		_lod_tier = 1
	elif d < LOD_FAR:
		_lod_tier = 2
	else:
		_lod_tier = 3


func _set_state(s: State) -> void:
	if state == s:
		return
	var prev := state
	state = s
	_state_timer = 0.0
	_going_to_alarm = false
	var color := Color(0.55, 0.25, 0.2)
	match s:
		State.PATROL:
			color = Color(0.55, 0.25, 0.2)
			_warn_timer = -1.0
		State.SUSPICIOUS:
			color = Color(0.75, 0.6, 0.15)
		State.ALERT:
			color = Color(0.85, 0.45, 0.1)
		State.COMBAT:
			color = Color(0.9, 0.15, 0.1)
			# Delayed shout/radio — interruptible if killed first
			if prev != State.COMBAT and not _warned:
				_warn_timer = randf_range(WARN_DELAY_MIN, WARN_DELAY_MAX)
			if prev != State.COMBAT:
				_assign_combat_role()
				_cover_refresh = 0.0
				_lost_los_t = 0.0
				_ensure_ghost()
		State.DEAD:
			color = Color(0.2, 0.2, 0.2)
			_warn_timer = -1.0
	if is_instance_valid(visual):
		visual.set_placeholder_color(color)
		if s == State.ALERT and prev != State.COMBAT:
			visual.play_radio()
		else:
			visual.play_state(State.keys()[s])
	if tagged:
		_refresh_tag_icon()
	_refresh_alert_meter()
	state_changed.emit(State.keys()[s])


func _ensure_alert_meter() -> void:
	if is_instance_valid(_alert_icon):
		return
	_alert_icon = Label3D.new()
	_alert_icon.name = "AlertIcon"
	_alert_icon.font_size = 64
	_alert_icon.outline_size = 10
	_alert_icon.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_alert_icon.position = Vector3(0, 2.35, 0)
	_alert_icon.no_depth_test = true
	_alert_icon.visible = false
	add_child(_alert_icon)
	# Thin fill meter under the icon (world-space quads)
	var bg := MeshInstance3D.new()
	bg.name = "AlertMeterBg"
	var bg_mesh := BoxMesh.new()
	bg_mesh.size = Vector3(0.55, 0.06, 0.01)
	bg.mesh = bg_mesh
	var bg_mat := StandardMaterial3D.new()
	bg_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bg_mat.albedo_color = Color(0.08, 0.08, 0.1, 0.85)
	bg_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	bg.material_override = bg_mat
	bg.position = Vector3(0, 1.92, 0)
	bg.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	bg.visible = false
	add_child(bg)
	_meter_bg = bg
	var fill := MeshInstance3D.new()
	fill.name = "AlertMeterFill"
	var fill_mesh := BoxMesh.new()
	fill_mesh.size = Vector3(0.52, 0.045, 0.012)
	fill.mesh = fill_mesh
	var fill_mat := StandardMaterial3D.new()
	fill_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fill_mat.albedo_color = Color(0.95, 0.85, 0.2)
	fill.material_override = fill_mat
	fill.position = Vector3(0, 1.92, 0.002)
	fill.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	fill.visible = false
	add_child(fill)
	_meter_fill = fill


func _refresh_alert_meter() -> void:
	_ensure_alert_meter()
	if state == State.DEAD:
		_alert_icon.visible = false
		if _meter_bg:
			_meter_bg.visible = false
		if _meter_fill:
			_meter_fill.visible = false
		return
	var show_q := state == State.SUSPICIOUS or state == State.ALERT or (detection > 0.08 and state == State.PATROL)
	var show_bang := state == State.COMBAT or detection >= 0.98
	if show_bang:
		_alert_icon.text = "!"
		_alert_icon.modulate = Color(1.0, 0.25, 0.18)
		_alert_icon.visible = true
		if _meter_bg:
			_meter_bg.visible = false
		if _meter_fill:
			_meter_fill.visible = false
	elif show_q:
		_alert_icon.text = "?"
		var t := clampf(detection, 0.0, 1.0)
		_alert_icon.modulate = Color(0.95, 0.88, 0.25).lerp(Color(1.0, 0.55, 0.12), t)
		_alert_icon.visible = true
		if _meter_bg:
			_meter_bg.visible = true
		if _meter_fill:
			_meter_fill.visible = true
			_meter_fill.scale = Vector3(maxf(0.05, t), 1.0, 1.0)
			_meter_fill.position.x = -0.26 * (1.0 - t)
			var fm := _meter_fill.material_override as StandardMaterial3D
			if fm:
				fm.albedo_color = Color(0.95, 0.85, 0.2).lerp(Color(1.0, 0.35, 0.12), t)
	else:
		_alert_icon.visible = false
		if _meter_bg:
			_meter_bg.visible = false
		if _meter_fill:
			_meter_fill.visible = false


func _update_label() -> void:
	## Role badge stays subtle; awareness is shown via ?/! meter (and bino tags).
	_ensure_alert_meter()
	_refresh_alert_meter()
	if not is_instance_valid(label):
		return
	if is_dog:
		_role_prefix = "DOG"
	elif is_sniper:
		_role_prefix = "SNIPER"
	elif is_heavy:
		_role_prefix = "HEAVY"
	elif role == "commander":
		_role_prefix = "BOSS"
	elif is_officer:
		_role_prefix = "OFFICER"
	elif role == "handler":
		_role_prefix = "HANDLER"
	else:
		_role_prefix = ""
	# Keep role text small under the meter; hide verbose PATROL/etc when calm
	if state == State.DEAD:
		label.text = "DEAD"
		label.modulate = Color(0.45, 0.45, 0.45)
		label.visible = true
		return
	if _role_prefix != "":
		label.text = _role_prefix
		label.visible = true
		label.modulate = Color(0.85, 0.8, 0.65, 0.85)
		label.position.y = 1.72
	else:
		label.visible = false


func _player_is_down(player: Node) -> bool:
	return is_instance_valid(player) and bool(player.get("is_down"))


func _player_target_pos(player: Node3D) -> Vector3:
	var crouched: bool = bool(player.get("is_crouching"))
	return player.global_position + Vector3.UP * (0.72 if crouched else 1.25)


func _update_vision(delta: float) -> void:
	var player := get_tree().get_first_node_in_group("player") as Node3D
	if not is_instance_valid(player) or _player_is_down(player):
		detection = maxf(0.0, detection - DETECTION_DECAY * delta)
		_push_detection_to_player()
		return

	var eye_pos := global_position + Vector3.UP * 1.5
	var target_pos := _player_target_pos(player)
	var to_player := target_pos - eye_pos
	var dist := to_player.length()
	var seen := false
	var day_vis := 1.0
	if DayNightCycle:
		day_vis = DayNightCycle.vision_mult()
	var v_range := VISION_RANGE * _vision_mult * day_vis
	var v_angle := VISION_ANGLE * (0.75 if is_dog else 1.0) * lerpf(0.85, 1.0, day_vis)
	if dist > 0.001 and dist < v_range:
		var forward := -global_transform.basis.z
		var angle := rad_to_deg(forward.angle_to(to_player / dist))
		if angle < v_angle:
			if is_instance_valid(vision_ray) and vision_ray.is_inside_tree():
				vision_ray.global_position = eye_pos
				vision_ray.target_position = vision_ray.to_local(target_pos)
				vision_ray.force_raycast_update()
				var blocked := vision_ray.is_colliding()
				var collider = vision_ray.get_collider() if blocked else null
				var hit_player := false
				if is_instance_valid(collider) and collider is Node:
					var cnode := collider as Node
					if cnode == player or player.is_ancestor_of(cnode) or cnode.get_parent() == player:
						hit_player = true
				if not blocked or hit_player:
					seen = _has_line_of_sight(player)
			else:
				seen = _has_line_of_sight(player)
	elif dist <= 0.001:
		seen = true

	# Point-blank bump: foliage hide doesn't save you if a guard walks into you
	if dist < BUMP_NOTICE_DIST and state != State.COMBAT:
		seen = true

	_has_los = seen
	if seen:
		var profile := 1.0
		if player.has_method("get_visibility_profile"):
			profile = player.get_visibility_profile()
		# Light/distance modifiers
		var dist_factor := 1.0 - clampf(dist / VISION_RANGE, 0.0, 1.0)
		var rate := DETECTION_RATE * profile * (0.35 + dist_factor)
		if dist < BUMP_NOTICE_DIST:
			rate = maxf(rate, 2.2)
		detection = clampf(detection + rate * delta, 0.0, 1.0)
		# Only a real sighting updates last-seen — never wallhack the live position
		last_known_pos = player.global_position
		_lost_los_t = 0.0
		_move_ghost(last_known_pos)
		if detection >= 1.0:
			_set_state(State.COMBAT)
			if not _spotted_emitted:
				_spotted_emitted = true
				GameState.player_spotted.emit()
				if GameState.run_stats:
					GameState.run_stats.on_spotted()
		elif detection > 0.35 and state == State.PATROL:
			investigate_pos = last_known_pos
			_set_state(State.SUSPICIOUS)
	else:
		if state != State.COMBAT and state != State.ALERT:
			detection = maxf(0.0, detection - DETECTION_DECAY * delta * (0.45 if _escalated_search else 1.0))

	_refresh_alert_meter()
	_push_detection_to_player()


func _has_line_of_sight(player: Node3D) -> bool:
	if not is_instance_valid(player) or get_world_3d() == null:
		return false
	var space := get_world_3d().direct_space_state
	if space == null:
		return false
	var from := global_position + Vector3.UP * 1.5
	var to := _player_target_pos(player)
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.collision_mask = 1 | 2
	query.exclude = [get_rid()]
	var hit := space.intersect_ray(query)
	if hit.is_empty():
		return true
	var c = hit.collider
	if not is_instance_valid(c):
		return true
	return c == player or (c is Node and (player.is_ancestor_of(c as Node) or (c as Node).get_parent() == player))


func _push_detection_to_player() -> void:
	var player := get_tree().get_first_node_in_group("player")
	if not is_instance_valid(player) or _player_is_down(player):
		return
	if player.has_method("notify_detection"):
		# Use max detection among guards — outpost manager aggregates ideally;
		# for prototype, each guard pushes; HUD keeps max for a short time.
		player.notify_detection(detection)


func _update_world_awareness(_delta: float) -> void:
	if state == State.COMBAT or state == State.DEAD:
		return
	# Spot bodies and suspicious items
	for body in get_tree().get_nodes_in_group("bodies"):
		if body is Node3D and _can_see_point((body as Node3D).global_position):
			if body.has_method("is_hidden") and body.is_hidden():
				continue
			investigate_pos = (body as Node3D).global_position
			detection = maxf(detection, 0.6)
			if state == State.PATROL:
				_set_state(State.SUSPICIOUS)
			elif state == State.SUSPICIOUS:
				_set_state(State.ALERT)
			return
	for item in get_tree().get_nodes_in_group("suspicious_items"):
		if item is Node3D and _can_see_point((item as Node3D).global_position):
			investigate_pos = (item as Node3D).global_position
			detection = maxf(detection, 0.45)
			if state == State.PATROL:
				_set_state(State.SUSPICIOUS)
			return


func _can_see_point(point: Vector3) -> bool:
	var to := point - (global_position + Vector3.UP * 1.5)
	if to.length() > VISION_RANGE * 0.85:
		return false
	var forward := -global_transform.basis.z
	if rad_to_deg(forward.angle_to(to.normalized())) > VISION_ANGLE:
		return false
	var space := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(global_position + Vector3.UP * 1.5, point + Vector3.UP * 0.3)
	query.collision_mask = 1
	query.exclude = [get_rid()]
	var hit := space.intersect_ray(query)
	return hit.is_empty()


func _on_noise(pos: Vector3, loudness: float, _source: String) -> void:
	## Sound alone never instantly spots the player — always INVESTIGATE (?).
	## Loud gunshots escalate to ALERT (search / alarm) but not COMBAT.
	if state == State.DEAD or state == State.COMBAT or not is_inside_tree():
		return
	var dist := global_position.distance_to(pos)
	var hear_range := loudness * _hearing_scale
	if hear_range <= 0.001 or dist > hear_range:
		return
	investigate_pos = pos
	last_known_pos = pos
	var strength := 1.0 - (dist / hear_range)
	# Cap below full detection so hearing never flips to "!" / combat
	detection = maxf(detection, minf(0.82, 0.28 + strength * 0.45))
	if state == State.PATROL or state == State.SUSPICIOUS:
		# Officers / loud shots escalate to ALERT (search area / race to alarm)
		if is_officer and loudness >= 10.0:
			_set_state(State.ALERT)
		elif loudness >= 18.0:
			_set_state(State.ALERT)
		else:
			_set_state(State.SUSPICIOUS)
	_refresh_alert_meter()


func _do_patrol(_delta: float) -> void:
	if is_sniper or is_sentry:
		velocity.x = 0
		velocity.z = 0
		rotate_y(_delta * (0.35 if is_sniper else 0.22))
		return
	# Idle chat pairs: face partner and idle when both calm & nearby
	if chat_pair != "" and _try_chat_idle(_delta):
		return
	# Dogs leash toward their handler when idle
	if is_dog and dog_id != "":
		var handler := _find_handler()
		if is_instance_valid(handler) and global_position.distance_to(handler.global_position) > 4.5:
			_move_toward(handler.global_position, MOVE_SPEED * _move_mult * 1.1)
			return
	if _patrol_points.is_empty():
		return
	var target := _patrol_points[_patrol_index]
	_move_toward(target, MOVE_SPEED * _move_mult)
	if global_position.distance_to(target) < 1.2:
		_patrol_index = (_patrol_index + 1) % _patrol_points.size()


func _try_chat_idle(delta: float) -> bool:
	var partner := _find_chat_partner()
	if not is_instance_valid(partner):
		return false
	if partner.state != State.PATROL:
		return false
	if global_position.distance_to(partner.global_position) > 3.6:
		return false
	velocity.x = 0
	velocity.z = 0
	_look_at_pos(partner.global_position)
	_chat_timer += delta
	if _chat_timer > 2.8 and is_instance_valid(visual):
		_chat_timer = 0.0
		if randf() > 0.45:
			visual.play_state("LOOK_AROUND")
		else:
			visual.play_radio()
	return true


func _find_chat_partner() -> GuardAI:
	if chat_pair == "":
		return null
	for g in get_tree().get_nodes_in_group("guards"):
		if g == self or not (g is GuardAI):
			continue
		var other := g as GuardAI
		if other.chat_pair == chat_pair and other.state != State.DEAD:
			return other
	return null


func _find_handler() -> GuardAI:
	if dog_id == "":
		return null
	for g in get_tree().get_nodes_in_group("guards"):
		if g == self or not (g is GuardAI):
			continue
		var other := g as GuardAI
		if other.dog_id == dog_id and other.role == "handler" and other.state != State.DEAD:
			return other
	return null


func _do_investigate(delta: float) -> void:
	_state_timer += delta
	if is_sniper or is_sentry:
		velocity.x = 0
		velocity.z = 0
		_look_at_pos(investigate_pos)
	else:
		_move_toward(investigate_pos, MOVE_SPEED * 1.15 * _move_mult)
		if global_position.distance_to(investigate_pos) < 1.5:
			rotate_y(delta * 1.2)
	var sus_limit := SUSPICIOUS_TIME * (0.55 if is_officer else 1.0)
	if _state_timer > sus_limit:
		if detection > 0.5 or is_officer:
			_set_state(State.ALERT)
		else:
			_set_state(State.PATROL)


func _do_search(delta: float) -> void:
	_state_timer += delta
	if is_sniper:
		velocity.x = 0
		velocity.z = 0
		_look_at_pos(last_known_pos)
		if _state_timer > SEARCH_TIME:
			_set_state(State.PATROL)
			detection = 0.2
		return
	# Officers race to the alarm immediately; others try once when first alerted
	if not _alarm_used and not _going_to_alarm and not alarm_path.is_empty():
		var alarm := get_node_or_null(alarm_path)
		if is_instance_valid(alarm) and alarm.has_method("is_disabled") and not alarm.is_disabled():
			_going_to_alarm = true
	if _going_to_alarm and not _alarm_used and not alarm_path.is_empty():
		var alarm := get_node_or_null(alarm_path)
		if is_instance_valid(alarm):
			_move_toward(alarm.global_position, ALERT_SPEED * (1.35 if is_officer else 1.0) * _move_mult)
			if global_position.distance_to(alarm.global_position) < 1.8:
				_look_at_pos(alarm.global_position)
				if is_instance_valid(visual):
					visual.play_alarm_press()
				if alarm.has_method("trigger"):
					alarm.trigger(self)
				_alarm_used = true
				_going_to_alarm = false
		else:
			_going_to_alarm = false
	else:
		_advance_search(delta)
	# Escalated search (lost the target) lasts much longer, then cools to suspicious
	var search_limit := SEARCH_TIME * (0.7 if is_officer else 1.0)
	if _escalated_search:
		search_limit *= 2.4
	if _state_timer > search_limit:
		_escalated_search = false
		_hide_ghost()
		if detection > 0.25:
			detection = 0.3
			_set_state(State.SUSPICIOUS)
		else:
			_set_state(State.PATROL)
			detection = 0.15


func _tick_warn(delta: float) -> void:
	## After spotting, shout/radio after 1.5–3s unless killed first.
	if _warned or _warn_timer < 0.0:
		return
	_warn_timer -= delta
	if _warn_timer > 0.0:
		return
	_warned = true
	_warn_timer = -1.0
	if is_instance_valid(visual):
		visual.play_radio()
	_broadcast_warn()


func _broadcast_warn() -> void:
	## Only guards within shout/radio range escalate — alarms still escalate compound.
	for g in get_tree().get_nodes_in_group("guards"):
		if g == self or not (g is GuardAI):
			continue
		var other := g as GuardAI
		if other.state == State.DEAD or other.state == State.COMBAT:
			continue
		var d := global_position.distance_to(other.global_position)
		var radio_ok := (is_officer or other.is_officer or role == "commander") and d <= WARN_RADIO_RANGE
		var shout_ok := d <= WARN_SHOUT_RANGE
		if not radio_ok and not shout_ok:
			continue
		other.receive_warn(last_known_pos, radio_ok)


func receive_warn(from_pos: Vector3, via_radio: bool = false) -> void:
	## Called by a spotted guard's delayed shout/radio. Investigate / engage LKP.
	if state == State.DEAD or state == State.COMBAT:
		return
	investigate_pos = from_pos
	last_known_pos = from_pos
	detection = maxf(detection, 0.55 if via_radio else 0.45)
	if via_radio or is_officer:
		_set_state(State.ALERT)
	elif state == State.PATROL:
		_set_state(State.SUSPICIOUS)
	_refresh_alert_meter()


func _do_combat(delta: float) -> void:
	var player := get_tree().get_first_node_in_group("player") as Node3D
	if not is_instance_valid(player) or _player_is_down(player):
		_begin_lost_search()
		return
	_state_timer += delta
	_move_ghost(last_known_pos)
	# Lost the target: stop tracking the live body and search the last-seen area
	if not _has_los:
		_lost_los_t += delta
		if _lost_los_t > 2.8:
			_begin_lost_search()
			return
	# Snipers hold the perch — fire only with a real sightline, else watch the ghost
	if is_sniper:
		velocity.x = 0.0
		velocity.z = 0.0
		var aim_s: Vector3 = player.global_position if _has_los else last_known_pos
		_look_at_pos(aim_s)
		if _has_los and _fire_cooldown <= 0.0 and global_position.distance_to(player.global_position) < VISION_RANGE * 1.8:
			_fire_at(player)
			_fire_cooldown = 1.15
		return
	# Dogs rush the last seen spot, bite only in contact
	if is_dog:
		var bite_at: Vector3 = player.global_position if _has_los else last_known_pos
		if global_position.distance_to(bite_at) > 1.6:
			_move_toward(bite_at, COMBAT_SPEED * _move_mult)
		else:
			velocity.x = 0.0
			velocity.z = 0.0
			_look_at_pos(bite_at)
			if _has_los and _fire_cooldown <= 0.0 and global_position.distance_to(player.global_position) < 1.8:
				_bite_at(player)
				_fire_cooldown = 0.55
		return
	# Officers still hit the alarm once, then take cover
	if not _alarm_used and is_officer and not alarm_path.is_empty() and _state_timer < 6.0:
		var alarm := get_node_or_null(alarm_path)
		if is_instance_valid(alarm) and alarm.has_method("is_disabled") and not alarm.is_disabled():
			_move_toward(alarm.global_position, COMBAT_SPEED * 1.15 * _move_mult)
			if global_position.distance_to(alarm.global_position) < 1.8:
				if is_instance_valid(visual):
					visual.play_alarm_press()
				if alarm.has_method("trigger"):
					alarm.trigger(self)
				_alarm_used = true
			return
	_fight_from_cover(delta, player)


func _assign_combat_role() -> void:
	# Stable mix: heavies and sentries hold; officers and a name-hash slice flank
	if is_heavy or is_sentry or is_sniper:
		_combat_role = "hold"
	elif is_officer or role == "commander":
		_combat_role = "flank"
	else:
		_combat_role = "flank" if (hash(name) % 5) >= 3 else "hold"


func _fight_from_cover(delta: float, player: Node3D) -> void:
	## Move between cover, peek to shoot, suppress the last-seen ghost. Far LOD skips peek lean.
	_cover_refresh -= delta
	if _cover_pos == Vector3.ZERO or _cover_refresh <= 0.0:
		_cover_pos = _pick_cover(_combat_role == "flank")
		_cover_refresh = 4.5 if _combat_role == "hold" else 3.2
	var at_cover := global_position.distance_to(_cover_pos) < 1.35
	if not at_cover:
		_cover_pose = ""
		var spd := (ALERT_SPEED if _combat_role == "hold" else COMBAT_SPEED * 0.92) * _move_mult
		if _lod_tier >= 2:
			spd *= 0.85
		_move_toward(_cover_pos, spd)
		return
	velocity.x = 0.0
	velocity.z = 0.0
	_peek_t += delta
	var peeking := _lod_tier >= 2 or fmod(_peek_t, 2.4) > 1.15
	_cover_pose = "peek" if peeking else "cover"
	var aim_at: Vector3 = player.global_position if _has_los else last_known_pos
	if peeking:
		_look_at_pos(aim_at)
		if is_instance_valid(visual):
			visual.rotation.z = deg_to_rad(7.0 if _combat_role == "flank" else -6.0)
		if _fire_cooldown <= 0.0:
			if _has_los:
				_fire_at(player)
				_fire_cooldown = 0.55 if _combat_role == "hold" else 0.72
			else:
				_suppress_at(last_known_pos)
				_fire_cooldown = 0.85
	else:
		# Tucked behind cover, watching the ghost
		_look_at_pos(last_known_pos)
		if is_instance_valid(visual):
			visual.rotation.z = 0.0


func _pick_cover(flank: bool) -> Vector3:
	var best := last_known_pos + (global_position - last_known_pos).normalized() * 6.0
	if best.distance_to(global_position) < 0.5:
		best = global_position + Vector3(2.5, 0, 1.5)
	var best_score := -1e9
	var to_lk := last_known_pos - global_position
	to_lk.y = 0.0
	var side := Vector3(-to_lk.z, 0.0, to_lk.x)
	if side.length() > 0.1:
		side = side.normalized()
	else:
		side = Vector3.RIGHT
	var max_d := 18.0 if _lod_tier >= 2 else 26.0
	for n in get_tree().get_nodes_in_group("cover_points"):
		if not (n is Node3D):
			continue
		var pos: Vector3 = (n as Node3D).global_position
		var d_self := global_position.distance_to(pos)
		if d_self > max_d or d_self < 0.8:
			continue
		var d_lk := pos.distance_to(last_known_pos)
		if d_lk < 4.0 or d_lk > 32.0:
			continue
		var score := -d_self * 0.35 - d_lk * 0.08
		var off := pos - last_known_pos
		off.y = 0.0
		var side_dot := 0.0
		if off.length() > 0.1:
			side_dot = absf(side.dot(off.normalized()))
			score += side_dot * (9.0 if flank else 2.0)
		if not flank:
			score -= side_dot * 2.0
		if score > best_score:
			best_score = score
			best = pos
	best.y = global_position.y
	return best


func _begin_lost_search() -> void:
	_escalated_search = true
	_search_spots.clear()
	_search_spots.append(last_known_pos)
	for n in get_tree().get_nodes_in_group("cover_points"):
		if _search_spots.size() >= 5:
			break
		if n is Node3D and (n as Node3D).global_position.distance_to(last_known_pos) < 16.0:
			_search_spots.append((n as Node3D).global_position)
	# Flank offset + a couple of nearby hide checks
	var side := Vector3(4.5 if _combat_role == "flank" else -3.5, 0, 3.0)
	_search_spots.append(last_known_pos + side)
	_search_spots.append(last_known_pos + Vector3(-side.x, 0, 5.0))
	_search_idx = 0
	investigate_pos = last_known_pos
	detection = maxf(detection, 0.72)
	_set_state(State.ALERT)


func _advance_search(delta: float) -> void:
	if _search_spots.is_empty():
		_search_spots.append(last_known_pos)
	var spot: Vector3 = _search_spots[_search_idx % _search_spots.size()]
	_move_toward(spot, ALERT_SPEED * (0.82 if _escalated_search else 1.0) * _move_mult)
	if global_position.distance_to(spot) < 1.6:
		rotate_y(delta * 1.6)
		_search_idx += 1
		if _search_idx % _search_spots.size() == 0:
			_state_timer += 1.2  # lingering at a sweep completion


func _suppress_at(pos: Vector3) -> void:
	## Fire at the last-seen ghost — noise + muzzle, no damage without a sightline.
	_look_at_pos(pos)
	NoiseBus.emit_noise(global_position, 36.0, "guard_suppress")
	if is_instance_valid(visual):
		visual.play_shoot()


func _ensure_ghost() -> void:
	if is_instance_valid(_ghost):
		return
	var g := MeshInstance3D.new()
	g.name = "LastSeenGhost"
	var mesh := SphereMesh.new()
	mesh.radius = 0.28
	mesh.height = 0.56
	g.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.85, 0.25, 0.35)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.7, 0.2)
	mat.emission_energy_multiplier = 0.6
	g.material_override = mat
	g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var scene := get_tree().current_scene
	if scene:
		scene.add_child(g)
	_ghost = g
	_move_ghost(last_known_pos)


func _move_ghost(pos: Vector3) -> void:
	if not is_instance_valid(_ghost):
		return
	_ghost.visible = state == State.COMBAT or state == State.ALERT
	_ghost.global_position = Vector3(pos.x, pos.y + 0.15, pos.z)


func _hide_ghost() -> void:
	if is_instance_valid(_ghost):
		_ghost.visible = false


func _bite_at(player: Node3D) -> void:
	if not is_instance_valid(player) or _player_is_down(player):
		return
	NoiseBus.emit_noise(global_position, 8.0, "dog_bark")
	if player.has_method("apply_damage"):
		player.apply_damage(9.0, global_position, self)
	if is_instance_valid(visual):
		visual.play_hit()


func _fire_at(player: Node3D) -> void:
	if not is_instance_valid(self) or state == State.DEAD or is_dog:
		return
	if not is_instance_valid(player) or _player_is_down(player):
		return
	# Damage only with a live sightline — suppression handles the no-LOS case
	if not _has_line_of_sight(player):
		_suppress_at(last_known_pos)
		return
	NoiseBus.emit_noise(global_position, 55.0 if is_sniper else 40.0, "guard_sniper" if is_sniper else "guard_rifle")
	if player.has_method("apply_damage"):
		var dmg := 18.0 if is_sniper else (14.0 if is_heavy else 10.0)
		player.apply_damage(dmg, global_position, self)
	if is_instance_valid(visual):
		visual.play_shoot()
		visual.set_placeholder_color(Color(1, 0.4, 0.3))
		var tree := get_tree()
		if tree:
			tree.create_timer(0.08).timeout.connect(_on_muzzle_flash_end)


func _move_toward(target: Vector3, speed: float) -> void:
	var steer := target
	if is_instance_valid(nav_agent) and is_inside_tree():
		var nav_map := nav_agent.get_navigation_map()
		if nav_map.is_valid() and NavigationServer3D.map_get_iteration_id(nav_map) > 0:
			if _nav_last_target.distance_to(target) > 0.45:
				nav_agent.target_position = target
				_nav_last_target = target
			if not nav_agent.is_navigation_finished():
				var next_pt := nav_agent.get_next_path_position()
				if next_pt.distance_to(global_position) > 0.08:
					steer = next_pt
	# Auto-open nearby hinged doors so guards traverse rooms & interiors smoothly
	_door_check_cd -= get_physics_process_delta_time()
	if _door_check_cd <= 0.0:
		_door_check_cd = 0.25
		for d in get_tree().get_nodes_in_group("doors"):
			if d is Node3D and (d as Node3D).global_position.distance_to(global_position) < 2.2:
				if d.has_method("open_for_guard"):
					d.open_for_guard()
	var flat := Vector3(steer.x, global_position.y, steer.z)
	var dir := flat - global_position
	if dir.length() < 0.1:
		velocity.x = 0
		velocity.z = 0
		return
	dir = dir.normalized()
	velocity.x = dir.x * speed
	velocity.z = dir.z * speed
	_look_at_pos(flat)


func _look_at_pos(pos: Vector3) -> void:
	var p := Vector3(pos.x, global_position.y, pos.z)
	var flat := p - global_position
	flat.y = 0.0
	# look_at() errors (and can abort HTML5) if target is coincident or
	# direction is parallel to the up vector.
	if flat.length() < 0.05:
		return
	look_at(global_position + flat.normalized(), Vector3.UP)


func _on_muzzle_flash_end() -> void:
	if not is_instance_valid(self) or state != State.COMBAT:
		return
	if is_instance_valid(visual):
		visual.set_placeholder_color(Color(0.9, 0.15, 0.1))


func apply_damage(amount: float, hit_pos: Vector3 = Vector3.ZERO, source: Node = null, zone_name: String = "") -> void:
	if state == State.DEAD:
		return
	# Fallback if caller didn't resolve a HitZone: infer from height
	if zone_name == "" and hit_pos != Vector3.ZERO:
		zone_name = _infer_zone_from_point(hit_pos)
		amount = _damage_for_inferred_zone(amount, zone_name)
	_last_hit_zone = zone_name
	# Explosion / blast flag from AoE or explicit zone
	if zone_name in ["EXPLODE", "EXPLOSION", "BLAST"] or (amount >= 160.0 and zone_name != "HEAD"):
		_death_kind = "explode"
	elif zone_name == "HEAD":
		_death_kind = "head"
	elif source is Node3D and is_behind_guard(source as Node3D):
		_death_kind = "back"
	else:
		_death_kind = "body"
	# Heavies shrug off body shots; headshots stay one-shot via HitZone.HEAD → 9999
	if is_heavy and zone_name != "HEAD" and amount < 9000.0:
		amount *= _body_armor
	hp -= amount
	detection = 1.0
	if source is Node3D:
		last_known_pos = (source as Node3D).global_position
	_set_state(State.COMBAT)
	if hp <= 0.0:
		_die(false)
	elif is_instance_valid(visual):
		visual.play_hit()


func apply_hit_zone(zone: HitZone, base_damage: float, hit_pos: Vector3 = Vector3.ZERO, source: Node = null) -> void:
	if zone == null:
		apply_damage(base_damage, hit_pos, source)
		return
	var dmg := zone.resolve_damage(base_damage)
	apply_damage(dmg, hit_pos, source, zone.zone_name())


func _infer_zone_from_point(hit_pos: Vector3) -> String:
	var local_y := to_local(hit_pos).y
	if local_y >= 1.45:
		return "HEAD"
	if local_y >= 0.7:
		return "TORSO"
	return "LIMBS"


func _damage_for_inferred_zone(base: float, zone_name: String) -> float:
	match zone_name:
		"HEAD":
			return 9999.0
		"LIMBS":
			return base * 0.55
		_:
			return base


func is_behind_guard(attacker: Node3D) -> bool:
	if not is_instance_valid(attacker):
		return true
	var guard_fwd := -global_transform.basis.z
	guard_fwd.y = 0.0
	var to_guard := global_position - attacker.global_position
	to_guard.y = 0.0
	if guard_fwd.length() < 0.01 or to_guard.length() < 0.01:
		return true
	return guard_fwd.normalized().dot(to_guard.normalized()) > 0.0


func melee_takedown(player: Node3D) -> bool:
	if state == State.DEAD:
		return false
	var from_behind := is_behind_guard(player)
	_die_takedown(from_behind)
	return from_behind


func _die_takedown(from_behind: bool) -> void:
	if state == State.DEAD:
		return
	state = State.DEAD
	velocity = Vector3.ZERO
	if GameState.run_stats:
		GameState.run_stats.on_kill(false, true)
	died.emit(self)
	collision_layer = 0
	collision_mask = 0
	if is_instance_valid(hit_zones):
		for hz in hit_zones.get_children():
			if hz is Area3D:
				(hz as Area3D).monitorable = false
	if is_instance_valid(visual):
		visual.set_placeholder_color(Color(0.2, 0.2, 0.2))
		visual.play_takedown(from_behind)
	state_changed.emit("DEAD")
	var tree := get_tree()
	if tree:
		tree.create_timer(0.62).timeout.connect(_spawn_body_and_free)


func _spawn_body_and_free() -> void:
	if not is_instance_valid(self) or not is_inside_tree():
		return
	var body_scene: PackedScene = preload("res://scenes/items/body.tscn")
	var body := body_scene.instantiate() as Node3D
	if body:
		get_tree().current_scene.add_child(body)
		body.global_position = global_position + Vector3.UP * 0.1
		body.global_rotation.y = global_rotation.y
	queue_free()


func _die(silent: bool) -> void:
	if state == State.DEAD:
		return
	_set_state(State.DEAD)
	velocity = Vector3.ZERO
	if GameState.run_stats:
		GameState.run_stats.on_kill(_last_hit_zone == "HEAD", false)
	died.emit(self)
	collision_layer = 0
	collision_mask = 0
	if is_instance_valid(hit_zones):
		for hz in hit_zones.get_children():
			if hz is Area3D:
				(hz as Area3D).monitorable = false
	if is_instance_valid(label):
		label.visible = false
	if is_instance_valid(visual) and visual.has_method("play_death"):
		visual.play_death(_death_kind)
	set_physics_process(false)
	var tree := get_tree()
	if tree == null:
		queue_free()
		return
	# Longer hold for explosion ragdoll; headshots settle quicker
	var hold := 0.78
	match _death_kind:
		"head":
			hold = 0.68
		"back":
			hold = 0.75
		"explode":
			hold = 0.95
	await tree.create_timer(hold).timeout
	if not is_instance_valid(self):
		return
	var scene := tree.current_scene
	if is_instance_valid(scene) and _body_scene:
		var body := _body_scene.instantiate()
		scene.add_child(body)
		if body is Node3D:
			(body as Node3D).global_position = global_position + Vector3.UP * 0.16
			(body as Node3D).rotation.y = rotation.y
		if body.has_method("setup"):
			body.setup(silent)
	queue_free()


func is_alive() -> bool:
	return state != State.DEAD
