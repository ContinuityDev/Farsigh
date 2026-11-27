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

@export var patrol_path: NodePath
@export var alarm_path: NodePath

var state: State = State.PATROL
var hp: float = MAX_HP
var detection: float = 0.0
var last_known_pos: Vector3 = Vector3.ZERO
var investigate_pos: Vector3 = Vector3.ZERO
var _state_timer: float = 0.0
var _patrol_index: int = 0
var _patrol_points: Array[Vector3] = []
var _fire_cooldown: float = 0.0
var _going_to_alarm: bool = false
var _alarm_used: bool = false
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

@onready var vision_ray: RayCast3D = $VisionRay
@onready var mesh: MeshInstance3D = $MeshInstance3D
@onready var label: Label3D = $StateLabel

var _mat: StandardMaterial3D
var _body_scene: PackedScene = preload("res://scenes/items/body.tscn")


func _ready() -> void:
	add_to_group("guards")
	collision_layer = 4
	collision_mask = 1 | 2
	NoiseBus.noise_emitted.connect(_on_noise)
	_mat = StandardMaterial3D.new()
	_mat.albedo_color = Color(0.55, 0.25, 0.2)
	mesh.material_override = _mat
	_cache_patrol()
	_set_state(State.PATROL)


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
	if not is_on_floor():
		velocity.y -= gravity * delta

	_fire_cooldown = maxf(0.0, _fire_cooldown - delta)
	_update_vision(delta)
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
	_update_label()


func _set_state(s: State) -> void:
	if state == s:
		return
	state = s
	_state_timer = 0.0
	_going_to_alarm = false
	match s:
		State.PATROL:
			_mat.albedo_color = Color(0.55, 0.25, 0.2)
		State.SUSPICIOUS:
			_mat.albedo_color = Color(0.75, 0.6, 0.15)
		State.ALERT:
			_mat.albedo_color = Color(0.85, 0.45, 0.1)
		State.COMBAT:
			_mat.albedo_color = Color(0.9, 0.15, 0.1)
		State.DEAD:
			_mat.albedo_color = Color(0.2, 0.2, 0.2)
	state_changed.emit(State.keys()[s])


func _update_label() -> void:
	if label:
		label.text = State.keys()[state]
		label.modulate = _mat.albedo_color


func _update_vision(delta: float) -> void:
	var player := get_tree().get_first_node_in_group("player") as Node3D
	if player == null:
		detection = maxf(0.0, detection - DETECTION_DECAY * delta)
		_push_detection_to_player()
		return

	var to_player := player.global_position + Vector3.UP * 1.2 - (global_position + Vector3.UP * 1.5)
	var dist := to_player.length()
	var seen := false
	if dist < VISION_RANGE:
		var forward := -global_transform.basis.z
		var angle := rad_to_deg(forward.angle_to(to_player.normalized()))
		if angle < VISION_ANGLE:
			vision_ray.global_position = global_position + Vector3.UP * 1.5
			vision_ray.target_position = vision_ray.to_local(player.global_position + Vector3.UP * 1.2)
			vision_ray.force_raycast_update()
			var blocked := vision_ray.is_colliding()
			var collider = vision_ray.get_collider() if blocked else null
			var hit_player := false
			if collider:
				if collider == player or (collider is Node and player.is_ancestor_of(collider)):
					hit_player = true
				elif collider.get_parent() == player:
					hit_player = true
			# Also allow clear LOS if nothing blocks or we hit the player body
			if not blocked or hit_player:
				# Re-check with exclude self only via space state for reliability
				seen = _has_line_of_sight(player)

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
			GameState.player_spotted.emit()
		elif detection > 0.35 and state == State.PATROL:
			investigate_pos = last_known_pos
			_set_state(State.SUSPICIOUS)
	else:
		if state != State.COMBAT and state != State.ALERT:
			detection = maxf(0.0, detection - DETECTION_DECAY * delta)

	_push_detection_to_player()


func _has_line_of_sight(player: Node3D) -> bool:
	var space := get_world_3d().direct_space_state
	var from := global_position + Vector3.UP * 1.5
	var to := player.global_position + Vector3.UP * 1.2
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.collision_mask = 1 | 2
	query.exclude = [get_rid()]
	var hit := space.intersect_ray(query)
	if hit.is_empty():
		return true
	var c = hit.collider
	return c == player or (c is Node and (player.is_ancestor_of(c) or c.get_parent() == player))


func _push_detection_to_player() -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player and player.has_method("notify_detection"):
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
	if state == State.DEAD:
		return
	var dist := global_position.distance_to(pos)
	var hear_range := loudness * HEARING_SCALE
	if dist > hear_range:
		return
	investigate_pos = pos
	last_known_pos = pos
	var strength := 1.0 - (dist / hear_range)
	if loudness >= 30.0 or strength > 0.7:
		detection = 1.0
		_set_state(State.COMBAT)
	elif state == State.PATROL or state == State.SUSPICIOUS:
		detection = maxf(detection, 0.4 + strength * 0.4)
		_set_state(State.SUSPICIOUS if loudness < 15.0 else State.ALERT)


func _do_patrol(_delta: float) -> void:
	if _patrol_points.is_empty():
		return
	var target := _patrol_points[_patrol_index]
	_move_toward(target, MOVE_SPEED)
	if global_position.distance_to(target) < 1.2:
		_patrol_index = (_patrol_index + 1) % _patrol_points.size()


func _do_investigate(delta: float) -> void:
	_state_timer += delta
	_move_toward(investigate_pos, MOVE_SPEED * 1.15)
	if global_position.distance_to(investigate_pos) < 1.5:
		# Look around
		rotate_y(delta * 1.2)
	if _state_timer > SUSPICIOUS_TIME:
		if detection > 0.5:
			_set_state(State.ALERT)
		else:
			_set_state(State.PATROL)


func _do_search(delta: float) -> void:
	_state_timer += delta
	# Try alarm once when first alerted
	if not _alarm_used and not _going_to_alarm:
		var alarm := get_node_or_null(alarm_path)
		if alarm and alarm.has_method("is_disabled") and not alarm.is_disabled():
			_going_to_alarm = true
	if _going_to_alarm and not _alarm_used:
		var alarm := get_node_or_null(alarm_path)
		if alarm:
			_move_toward(alarm.global_position, ALERT_SPEED)
			if global_position.distance_to(alarm.global_position) < 1.8:
				if alarm.has_method("trigger"):
					alarm.trigger(self)
				_alarm_used = true
				_going_to_alarm = false
		else:
			_going_to_alarm = false
	else:
		_move_toward(last_known_pos, ALERT_SPEED)
		if global_position.distance_to(last_known_pos) < 1.5:
			rotate_y(delta * 2.0)
	if _state_timer > SEARCH_TIME:
		_set_state(State.PATROL)
		detection = 0.2


func _do_combat(delta: float) -> void:
	var player := get_tree().get_first_node_in_group("player") as Node3D
	if player == null:
		_set_state(State.ALERT)
		return
	last_known_pos = player.global_position
	var dist := global_position.distance_to(player.global_position)
	# Still try alarm if not used
	if not _alarm_used:
		var alarm := get_node_or_null(alarm_path)
		if alarm and alarm.has_method("is_disabled") and not alarm.is_disabled():
			_move_toward(alarm.global_position, COMBAT_SPEED)
			if global_position.distance_to(alarm.global_position) < 1.8:
				alarm.trigger(self)
				_alarm_used = true
			return
	if dist > 12.0:
		_move_toward(player.global_position, COMBAT_SPEED)
	else:
		velocity.x = 0
		velocity.z = 0
		_look_at_pos(player.global_position)
		if _fire_cooldown <= 0.0 and _has_line_of_sight(player):
			_fire_at(player)
			_fire_cooldown = 0.45
	_state_timer += delta


func _fire_at(player: Node3D) -> void:
	NoiseBus.emit_noise(global_position, 40.0, "guard_rifle")
	if player.has_method("apply_damage"):
		player.apply_damage(12.0)
	# Soft feedback: flash
	_mat.albedo_color = Color(1, 0.4, 0.3)
	get_tree().create_timer(0.08).timeout.connect(func():
		if state == State.COMBAT:
			_mat.albedo_color = Color(0.9, 0.15, 0.1)
	)


func _move_toward(target: Vector3, speed: float) -> void:
	var flat := Vector3(target.x, global_position.y, target.z)
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
	if p.distance_to(global_position) > 0.05:
		look_at(p, Vector3.UP)


func apply_damage(amount: float, _hit_pos: Vector3 = Vector3.ZERO, _source: Node = null) -> void:
	if state == State.DEAD:
		return
	hp -= amount
	detection = 1.0
	if _source is Node3D:
		last_known_pos = (_source as Node3D).global_position
	_set_state(State.COMBAT)
	if hp <= 0.0:
		_die(false)


func melee_takedown(_player: Node3D) -> void:
	if state == State.DEAD:
		return
	# Must be relatively unaware for clean takedown bonus — always lethal in prototype
	_die(true)


func _die(silent: bool) -> void:
	_set_state(State.DEAD)
	velocity = Vector3.ZERO
	died.emit(self)
	# Spawn body
	var body := _body_scene.instantiate()
	get_tree().current_scene.add_child(body)
	body.global_position = global_position + Vector3.UP * 0.2
	if body.has_method("setup"):
		body.setup(silent)
	hide()
	collision_layer = 0
	collision_mask = 0
	set_physics_process(false)
	await get_tree().create_timer(0.05).timeout
	queue_free()


func is_alive() -> bool:
	return state != State.DEAD
