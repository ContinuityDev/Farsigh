extends CharacterBody3D
class_name GuardAI
## Modular guard: patrol → suspicious → alert/search → combat.
## Vision cone + hearing via NoiseBus. Spots player, bodies, and left items.

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


func apply_spawn_spec(spec: Dictionary) -> void:
	role = String(spec.get("role", "patrol"))
	is_sniper = bool(spec.get("sniper", false))
	is_sentry = bool(spec.get("sentry", false)) or role == "sentry"
	is_heavy = bool(spec.get("heavy", false)) or role == "heavy"
	is_officer = bool(spec.get("officer", false)) or role == "officer"
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

	move_and_slide()
	if is_instance_valid(visual) and _lod_tier < 3:
		var horiz := Vector2(velocity.x, velocity.z).length()
		visual.set_locomotion(horiz > 0.25, state == State.ALERT or state == State.COMBAT, state == State.SUSPICIOUS)
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
		State.SUSPICIOUS:
			color = Color(0.75, 0.6, 0.15)
		State.ALERT:
			color = Color(0.85, 0.45, 0.1)
		State.COMBAT:
			color = Color(0.9, 0.15, 0.1)
		State.DEAD:
			color = Color(0.2, 0.2, 0.2)
	if is_instance_valid(visual):
		visual.set_placeholder_color(color)
		if s == State.ALERT and prev != State.COMBAT:
			visual.play_radio()
		else:
			visual.play_state(State.keys()[s])
	state_changed.emit(State.keys()[s])


func _update_label() -> void:
	if is_instance_valid(label):
		label.visible = true
		var prefix := ""
		if is_dog:
			prefix = "DOG "
		elif is_sniper:
			prefix = "SNIPER "
		elif is_heavy:
			prefix = "HEAVY "
		elif is_officer:
			prefix = "OFFICER "
		elif role == "handler":
			prefix = "HANDLER "
		var zone_suffix := (" [%s]" % _last_hit_zone) if _last_hit_zone != "" and state != State.DEAD else ""
		label.text = prefix + State.keys()[state] + zone_suffix
		if is_sniper:
			label.modulate = Color(1.0, 0.85, 0.55)
		elif is_heavy:
			label.modulate = Color(0.85, 0.75, 0.95)
		elif is_officer:
			label.modulate = Color(0.95, 0.75, 0.35)
		elif is_dog:
			label.modulate = Color(0.75, 0.9, 0.65)
		else:
			label.modulate = Color(0.9, 0.85, 0.7)


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
	var v_range := VISION_RANGE * _vision_mult
	var v_angle := VISION_ANGLE * (0.75 if is_dog else 1.0)
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

	if seen:
		var profile := 1.0
		if player.has_method("get_visibility_profile"):
			profile = player.get_visibility_profile()
		# Light/distance modifiers
		var dist_factor := 1.0 - clampf(dist / VISION_RANGE, 0.0, 1.0)
		var rate := DETECTION_RATE * profile * (0.35 + dist_factor)
		# Night-ish compound: slightly harder at long range
		detection = clampf(detection + rate * delta, 0.0, 1.0)
		last_known_pos = player.global_position
		if detection >= 1.0:
			_set_state(State.COMBAT)
			if not _spotted_emitted:
				_spotted_emitted = true
				GameState.player_spotted.emit()
		elif detection > 0.35 and state == State.PATROL:
			investigate_pos = last_known_pos
			_set_state(State.SUSPICIOUS)
	else:
		if state != State.COMBAT and state != State.ALERT:
			detection = maxf(0.0, detection - DETECTION_DECAY * delta)

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
	if state == State.DEAD or not is_inside_tree():
		return
	var dist := global_position.distance_to(pos)
	var hear_range := loudness * _hearing_scale
	if hear_range <= 0.001 or dist > hear_range:
		return
	investigate_pos = pos
	last_known_pos = pos
	var strength := 1.0 - (dist / hear_range)
	if loudness >= 30.0 or strength > 0.7:
		detection = 1.0
		_set_state(State.COMBAT)
	elif state == State.PATROL or state == State.SUSPICIOUS:
		detection = maxf(detection, 0.4 + strength * 0.4)
		# Officers escalate noise faster toward alarm / alert
		if is_officer and loudness >= 10.0:
			_set_state(State.ALERT)
		else:
			_set_state(State.SUSPICIOUS if loudness < 15.0 else State.ALERT)


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
		_move_toward(last_known_pos, ALERT_SPEED * _move_mult)
		if global_position.distance_to(last_known_pos) < 1.5:
			rotate_y(delta * 2.0)
	var search_limit := SEARCH_TIME * (0.7 if is_officer else 1.0)
	if _state_timer > search_limit:
		_set_state(State.PATROL)
		detection = 0.2


func _do_combat(delta: float) -> void:
	var player := get_tree().get_first_node_in_group("player") as Node3D
	if not is_instance_valid(player) or _player_is_down(player):
		_set_state(State.ALERT)
		return
	last_known_pos = player.global_position
	var dist := global_position.distance_to(player.global_position)
	# Snipers hold their overwatch perch and snipe at long range
	if is_sniper:
		velocity.x = 0
		velocity.z = 0
		_look_at_pos(player.global_position)
		if _fire_cooldown <= 0.0 and dist < VISION_RANGE * 1.8 and _has_line_of_sight(player):
			_fire_at(player)
			_fire_cooldown = 1.15
		_state_timer += delta
		return
	# Dogs rush and bite — no gun, no alarm
	if is_dog:
		if dist > 1.6:
			_move_toward(player.global_position, COMBAT_SPEED * _move_mult)
		else:
			velocity.x = 0
			velocity.z = 0
			_look_at_pos(player.global_position)
			if _fire_cooldown <= 0.0:
				_bite_at(player)
				_fire_cooldown = 0.55
		_state_timer += delta
		return
	# Still try alarm if not used (officers sprint harder)
	if not _alarm_used and not alarm_path.is_empty():
		var alarm := get_node_or_null(alarm_path)
		if is_instance_valid(alarm) and alarm.has_method("is_disabled") and not alarm.is_disabled():
			_move_toward(alarm.global_position, COMBAT_SPEED * (1.4 if is_officer else 1.0) * _move_mult)
			if global_position.distance_to(alarm.global_position) < 1.8:
				_look_at_pos(alarm.global_position)
				if is_instance_valid(visual):
					visual.play_alarm_press()
				if alarm.has_method("trigger"):
					alarm.trigger(self)
				_alarm_used = true
			return
	if dist > 12.0:
		_move_toward(player.global_position, COMBAT_SPEED * _move_mult)
	else:
		velocity.x = 0
		velocity.z = 0
		_look_at_pos(player.global_position)
		if _fire_cooldown <= 0.0 and _has_line_of_sight(player):
			_fire_at(player)
			_fire_cooldown = 0.45 if not is_heavy else 0.55
	_state_timer += delta


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
	NoiseBus.emit_noise(global_position, 55.0 if is_sniper else 40.0, "guard_sniper" if is_sniper else "guard_rifle")
	if player.has_method("apply_damage"):
		var dmg := 22.0 if is_sniper else (16.0 if is_heavy else 12.0)
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
	died.emit(self)
	collision_layer = 0
	collision_mask = 0
	if is_instance_valid(hit_zones):
		for hz in hit_zones.get_children():
			if hz is Area3D:
				(hz as Area3D).monitorable = false
	if is_instance_valid(label):
		label.visible = false
	set_physics_process(false)
	var tree := get_tree()
	if tree == null:
		queue_free()
		return
	# Let the humanoid collapse death animation play before swapping to lootable body
	await tree.create_timer(0.72).timeout
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
