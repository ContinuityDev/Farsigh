extends CharacterBody3D
class_name PlayerController
## First-person stealth controller: walk, sprint, crouch, jump, look, interact.
## Reads keyboard, mouse, gamepad, and TouchInput virtual controls via the same actions.

signal detection_changed(value: float)
signal carrying_changed(carrying: bool)

const WALK_SPEED := 4.2
const SPRINT_SPEED := 7.0
const CROUCH_SPEED := 2.2
const JUMP_VELOCITY := 4.6
const MOUSE_SENS := 0.0024
const GAMEPAD_LOOK_SENS := 2.8
const TOUCH_LOOK_SENS := 0.12
const STAND_HEIGHT := 1.8
const CROUCH_HEIGHT := 1.0
const FOOTSTEP_WALK := 7.5
const FOOTSTEP_SPRINT := 14.0
const FOOTSTEP_CROUCH := 2.5

@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D
@onready var collision_shape: CollisionShape3D = $CollisionShape3D
@onready var interact_ray: RayCast3D = $Head/Camera3D/InteractRay
@onready var weapons: WeaponManager = $WeaponManager
@onready var carry_point: Node3D = $Head/CarryPoint

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var is_crouching: bool = false
var is_aiming: bool = false
var aim_blend: float = 0.0
var _footstep_timer: float = 0.0
var carried_body: Node3D = null
var rock_count: int = 5
var max_detection_seen: float = 0.0
var hp: float = 100.0
var is_down: bool = false
var _capsule: CapsuleShape3D
var _crouch_toggled: bool = false
var _aim_toggled: bool = false
var _capture_fire_suppress: float = 0.0
var _lean_amount: float = 0.0  # -1 left .. +1 right
var _is_vaulting: bool = false
var _vault_t: float = 0.0
var _vault_dur: float = 0.34
var _vault_start: Vector3 = Vector3.ZERO
var _vault_apex: Vector3 = Vector3.ZERO
var _vault_end: Vector3 = Vector3.ZERO
var _carry_bob_t: float = 0.0
var _head_target_y: float = 1.65
var _breath_sway: Vector2 = Vector2.ZERO
var _breath_t: float = 0.0


func _ready() -> void:
	# Browsers require a user gesture before pointer lock — don't auto-capture on web.
	if TouchInput.is_touch_ui_desired() or OS.has_feature("web"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	else:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if is_instance_valid(collision_shape) and collision_shape.shape is CapsuleShape3D:
		# Duplicate so changing crouch height never mutates a shared sub-resource.
		_capsule = (collision_shape.shape as CapsuleShape3D).duplicate() as CapsuleShape3D
		collision_shape.shape = _capsule
	floor_max_angle = deg_to_rad(52.0)
	floor_snap_length = 0.35
	add_to_group("player")
	if is_instance_valid(weapons) and is_instance_valid(camera):
		weapons.camera_path = weapons.get_path_to(camera)
	process_mode = Node.PROCESS_MODE_PAUSABLE
	var hud := get_tree().get_first_node_in_group("hud")
	if is_instance_valid(hud) and hud.has_method("set_click_to_capture_hint"):
		hud.set_click_to_capture_hint(TouchInput.is_web_desktop())


func _unhandled_input(event: InputEvent) -> void:
	if GameState.is_paused or is_down:
		return
	# Desktop browser: click/tap canvas to capture mouse for look without firing
	if OS.has_feature("web") and not TouchInput.is_touch_ui_desired():
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
				Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
				_capture_fire_suppress = 0.15
				var hud := get_tree().get_first_node_in_group("hud")
				if is_instance_valid(hud) and hud.has_method("set_click_to_capture_hint"):
					hud.set_click_to_capture_hint(false)
				get_viewport().set_input_as_handled()
				return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var sens := MOUSE_SENS * _look_sensitivity_mult()
		_apply_look(-event.relative.x * sens, -event.relative.y * sens)
	if event.is_action_pressed("pause_menu"):
		_toggle_pause()


func _physics_process(delta: float) -> void:
	if GameState.is_paused or is_down:
		return
	if _capture_fire_suppress > 0.0:
		_capture_fire_suppress = maxf(0.0, _capture_fire_suppress - delta)
	# Keep desktop-web pointer lock hint synced if browser released lock (e.g. Esc)
	if TouchInput.is_web_desktop():
		var hud_hint := get_tree().get_first_node_in_group("hud")
		if is_instance_valid(hud_hint) and hud_hint.has_method("set_click_to_capture_hint"):
			hud_hint.set_click_to_capture_hint(Input.mouse_mode != Input.MOUSE_MODE_CAPTURED)

	# Touch look swipe + gamepad stick (ADS sensitivity applied)
	var look_mult := _look_sensitivity_mult()
	var touch_look := TouchInput.consume_look_relative()
	if touch_look != Vector2.ZERO:
		_apply_look(-touch_look.x * TOUCH_LOOK_SENS * 0.01 * look_mult, -touch_look.y * TOUCH_LOOK_SENS * 0.01 * look_mult)
	var pad_look := TouchInput.get_look_axis()
	if pad_look.length() > 0.1:
		_apply_look(-pad_look.x * GAMEPAD_LOOK_SENS * delta * look_mult, -pad_look.y * GAMEPAD_LOOK_SENS * delta * look_mult)

	if _is_vaulting:
		_step_vault(delta)
		return

	if not is_on_floor():
		velocity.y -= gravity * delta

	_handle_crouch()
	_update_lean(delta)
	_update_aim_state(delta)

	var input_dir := TouchInput.get_move_axis()
	var direction := (transform.basis * Vector3(input_dir.x, 0.0, input_dir.y)).normalized()
	var speed := WALK_SPEED
	var sprinting := TouchInput.is_action_pressed("sprint") and not is_crouching and carried_body == null and input_dir.length() > 0.1 and not is_aiming
	if carried_body != null:
		speed = CROUCH_SPEED * 0.72 if is_crouching else WALK_SPEED * 0.68
	elif is_crouching:
		speed = CROUCH_SPEED
	elif sprinting:
		speed = SPRINT_SPEED
	if is_aiming and carried_body == null:
		var ads_move := 0.55
		if is_instance_valid(weapons):
			ads_move = weapons.get_active().ads_move_mult
		speed *= lerpf(1.0, ads_move, aim_blend)

	if direction:
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
	else:
		velocity.x = move_toward(velocity.x, 0.0, speed)
		velocity.z = move_toward(velocity.z, 0.0, speed)

	if TouchInput.is_action_just_pressed("jump"):
		if carried_body == null and _try_start_vault():
			return
		if is_on_floor() and not is_crouching:
			velocity.y = JUMP_VELOCITY

	move_and_slide()
	var horiz_speed := Vector2(velocity.x, velocity.z).length()
	if is_instance_valid(weapons) and is_instance_valid(weapons.viewmodel_rig):
		weapons.viewmodel_rig.set_move_factor(horiz_speed / WALK_SPEED if is_on_floor() else 0.0)
		weapons.viewmodel_rig.set_carrying_body(carried_body != null, carried_body != null and is_crouching)
	_update_carry_animation(delta, horiz_speed)
	_update_footsteps(delta, direction.length() > 0.1 and is_on_floor(), sprinting)
	_handle_combat_input()
	_handle_interact_input()


func _apply_look(yaw: float, pitch: float) -> void:
	rotate_y(yaw)
	head.rotate_x(pitch)
	head.rotation.x = clampf(head.rotation.x, deg_to_rad(-85.0), deg_to_rad(85.0))
	if is_instance_valid(weapons) and is_instance_valid(weapons.viewmodel_rig):
		weapons.viewmodel_rig.add_look_sway(Vector2(yaw * 18.0, pitch * 18.0))


func apply_recoil(pitch_deg: float, yaw_deg: float) -> void:
	var ads_mult := 1.0
	if is_instance_valid(weapons) and aim_blend > 0.01:
		ads_mult = lerpf(1.0, weapons.get_active().ads_recoil_mult, aim_blend)
	if is_instance_valid(head):
		head.rotate_x(deg_to_rad(pitch_deg * 0.45 * ads_mult))
		head.rotation.x = clampf(head.rotation.x, deg_to_rad(-85.0), deg_to_rad(85.0))
	rotate_y(deg_to_rad(yaw_deg * 0.35 * ads_mult))


func _look_sensitivity_mult() -> float:
	# Lower mouse / stick / touch sensitivity while ADS (setting from pause menu).
	return lerpf(1.0, GameState.ads_sensitivity, aim_blend)


func _update_aim_state(delta: float) -> void:
	# Touch Aim can be Hold (default) or Toggle via pause-menu setting.
	if carried_body != null:
		_aim_toggled = false
		is_aiming = false
	elif GameState.touch_aim_toggle and TouchInput.is_touch_ui_desired():
		if TouchInput.is_action_just_pressed("aim"):
			_aim_toggled = not _aim_toggled
		# Keyboard/gamepad RMB still works as hold alongside toggle for mixed input
		is_aiming = _aim_toggled or Input.is_action_pressed("aim")
	else:
		_aim_toggled = false
		is_aiming = TouchInput.is_action_pressed("aim")

	var w: WeaponData = weapons.get_active() if is_instance_valid(weapons) else null
	var ads_time := 0.28
	if w != null:
		ads_time = w.ads_time
	# Breath-hold: hold Sprint while ADS to steady the scope (Shift / SprintBtn)
	var breath := 0.0
	if is_aiming and TouchInput.is_action_pressed("sprint") and not is_crouching:
		breath = 1.0
	if is_instance_valid(weapons) and is_instance_valid(weapons.viewmodel_rig):
		weapons.viewmodel_rig.set_aiming(is_aiming, ads_time, breath)
		aim_blend = weapons.viewmodel_rig.get_aim_blend()
	else:
		aim_blend = move_toward(aim_blend, 1.0 if is_aiming else 0.0, delta / maxf(0.08, ads_time))

	var hip_fov := 70.0
	var target_fov := hip_fov
	var scoped := false
	if w != null and aim_blend > 0.01:
		target_fov = lerpf(hip_fov, w.aim_fov, aim_blend)
		scoped = w.scope_overlay and aim_blend > 0.72
	# Breath-hold slightly tightens zoom further for sniper / scoped optics
	if scoped and breath > 0.5:
		target_fov = maxf(14.0, target_fov - 2.5)
	camera.fov = lerpf(camera.fov, target_fov, clampf(delta * 14.0, 0.0, 1.0))

	# Scope sway when ADS without breath-hold
	_breath_t += delta
	if scoped and breath < 0.5:
		_breath_sway.x = sin(_breath_t * 1.15) * 0.00035
		_breath_sway.y = cos(_breath_t * 0.95) * 0.00028
		_apply_look(_breath_sway.x, _breath_sway.y)
	else:
		_breath_sway = Vector2.ZERO

	var hud_scope := get_tree().get_first_node_in_group("hud")
	if is_instance_valid(hud_scope):
		if hud_scope.has_method("set_scope_overlay"):
			hud_scope.set_scope_overlay(scoped)
		if hud_scope.has_method("set_ads_crosshair"):
			hud_scope.set_ads_crosshair(aim_blend > 0.18)
	if is_instance_valid(weapons) and is_instance_valid(weapons.viewmodel_rig):
		# Hide viewmodel under full scope overlay; keep it for iron/red-dot/holo ADS
		weapons.viewmodel_rig.visible = not scoped


func _update_lean(delta: float) -> void:
	var target_lean := 0.0
	if TouchInput.is_action_pressed("lean_left"):
		target_lean -= 1.0
	if TouchInput.is_action_pressed("lean_right"):
		target_lean += 1.0
	# Prevent leaning through walls via short lateral raycast
	if absf(target_lean) > 0.05 and is_inside_tree():
		var space := get_world_3d().direct_space_state
		var origin := global_position + Vector3.UP * _head_target_y
		var side_dir := transform.basis.x * signf(target_lean)
		var q := PhysicsRayQueryParameters3D.create(origin, origin + side_dir * 0.56)
		q.collision_mask = 1
		q.exclude = [get_rid()]
		var hit := space.intersect_ray(q)
		if not hit.is_empty():
			var clearance := maxf(0.0, origin.distance_to(hit.position) - 0.16)
			target_lean = signf(target_lean) * clampf(clearance / 0.42, 0.0, 1.0)
	_lean_amount = lerpf(_lean_amount, target_lean, clampf(delta * 12.0, 0.0, 1.0))
	if is_instance_valid(head):
		head.position.x = _lean_amount * 0.42
		head.position.y = lerpf(head.position.y, _head_target_y - absf(_lean_amount) * 0.06, clampf(delta * 14.0, 0.0, 1.0))
	if is_instance_valid(camera):
		camera.rotation.z = lerpf(camera.rotation.z, deg_to_rad(-9.5 * _lean_amount), clampf(delta * 12.0, 0.0, 1.0))


func _try_start_vault() -> bool:
	if not is_inside_tree():
		return false
	var space := get_world_3d().direct_space_state
	var fwd := -transform.basis.z
	fwd.y = 0.0
	if fwd.length() < 0.01:
		return false
	fwd = fwd.normalized()
	# 1. Check for a low-to-chest obstacle right ahead (y = 0.45..1.25)
	var waist := global_position + Vector3.UP * 0.68
	var q_front := PhysicsRayQueryParameters3D.create(waist, waist + fwd * 1.15)
	q_front.collision_mask = 1
	q_front.exclude = [get_rid()]
	var hit_front := space.intersect_ray(q_front)
	if hit_front.is_empty():
		return false
	# 2. Confirm headroom above the obstacle at y + 1.65 is clear
	var high := global_position + Vector3.UP * 1.65
	var q_high := PhysicsRayQueryParameters3D.create(high, high + fwd * 1.35)
	q_high.collision_mask = 1
	q_high.exclude = [get_rid()]
	if not space.intersect_ray(q_high).is_empty():
		return false
	# 3. Probe down onto the top surface of the obstacle to find climb/vault height
	var probe_top := global_position + fwd * 0.95 + Vector3.UP * 1.85
	var q_down := PhysicsRayQueryParameters3D.create(probe_top, probe_top + Vector3.DOWN * 1.6)
	q_down.collision_mask = 1
	q_down.exclude = [get_rid()]
	var hit_top := space.intersect_ray(q_down)
	if hit_top.is_empty():
		return false
	var climb_h: float = hit_top.position.y - global_position.y
	if climb_h < 0.35 or climb_h > 1.52:
		return false
	_is_vaulting = true
	_vault_t = 0.0
	_vault_start = global_position
	_vault_end = Vector3(hit_top.position.x, hit_top.position.y + 0.08, hit_top.position.z) + fwd * 0.25
	_vault_apex = (_vault_start + _vault_end) * 0.5 + Vector3.UP * (maxf(climb_h * 0.5, 0.45))
	velocity = Vector3.ZERO
	NoiseBus.emit_noise(global_position, 5.0, "vault")
	return true


func _step_vault(delta: float) -> void:
	_vault_t += delta
	var u := clampf(_vault_t / _vault_dur, 0.0, 1.0)
	# Quadratic Bezier arc from start -> apex -> landing
	var a := _vault_start.lerp(_vault_apex, u)
	var b := _vault_apex.lerp(_vault_end, u)
	global_position = a.lerp(b, u)
	if is_instance_valid(camera):
		camera.rotation.x = deg_to_rad(-8.0 * sin(u * PI))
	if is_instance_valid(weapons) and is_instance_valid(weapons.viewmodel_rig):
		weapons.viewmodel_rig.set_vault_progress(u)
	if u >= 1.0:
		_is_vaulting = false
		if is_instance_valid(camera):
			camera.rotation.x = 0.0
		if is_instance_valid(weapons) and is_instance_valid(weapons.viewmodel_rig):
			weapons.viewmodel_rig.set_vault_progress(0.0)


func _update_carry_animation(delta: float, horiz_speed: float) -> void:
	if carried_body == null or not is_instance_valid(carry_point):
		return
	if horiz_speed > 0.15:
		_carry_bob_t += delta * (6.2 if not is_crouching else 4.2)
	var target_pos := Vector3(0.36, -0.52, -0.78) if is_crouching else Vector3(0.42, -0.18, -0.76)
	target_pos.x += sin(_carry_bob_t) * 0.035
	target_pos.y += absf(cos(_carry_bob_t)) * 0.03
	carry_point.position = carry_point.position.lerp(target_pos, clampf(delta * 10.0, 0.0, 1.0))
	var target_rot_x := deg_to_rad(-25.0) if is_crouching else deg_to_rad(-80.0)
	carried_body.rotation.x = lerpf(carried_body.rotation.x, target_rot_x, clampf(delta * 10.0, 0.0, 1.0))


func _handle_crouch() -> void:
	# Toggle on C / gamepad B / touch button so players never hold Ctrl+W on web.
	if TouchInput.is_action_just_pressed("crouch"):
		_crouch_toggled = not _crouch_toggled
	if TouchInput.is_action_just_pressed("jump") and _crouch_toggled:
		_crouch_toggled = false
	var want := _crouch_toggled
	if want == is_crouching:
		return
	is_crouching = want
	var target_h := CROUCH_HEIGHT if is_crouching else STAND_HEIGHT
	if is_instance_valid(_capsule):
		_capsule.height = maxf(target_h, _capsule.radius * 2.0 + 0.05)
	if is_instance_valid(collision_shape):
		collision_shape.position.y = target_h * 0.5
	_head_target_y = target_h - 0.15
	if is_instance_valid(head):
		head.position.y = _head_target_y


func _update_footsteps(delta: float, moving: bool, sprinting: bool) -> void:
	if not moving:
		_footstep_timer = 0.0
		return
	var interval := 0.55
	var loudness := FOOTSTEP_WALK
	if is_crouching:
		interval = 0.7
		loudness = FOOTSTEP_CROUCH
	elif sprinting:
		interval = 0.32
		loudness = FOOTSTEP_SPRINT
	_footstep_timer -= delta
	if _footstep_timer <= 0.0:
		_footstep_timer = interval
		NoiseBus.emit_noise(global_position, loudness, "footstep")


func _handle_combat_input() -> void:
	var can_fire := _capture_fire_suppress <= 0.0
	if can_fire and TouchInput.is_action_just_pressed("fire"):
		weapons.try_fire()
	elif can_fire and TouchInput.is_action_pressed("fire"):
		weapons.try_fire_held()
	if TouchInput.is_action_just_pressed("reload"):
		weapons.start_reload()
	if TouchInput.is_action_just_pressed("melee"):
		weapons.try_melee_takedown(self)
	if TouchInput.is_action_just_pressed("weapon_1"):
		weapons.select_slot(0)
	if TouchInput.is_action_just_pressed("weapon_2"):
		weapons.select_slot(1)
	if TouchInput.is_action_just_pressed("weapon_3"):
		weapons.select_slot(2)
	if TouchInput.is_action_just_pressed("weapon_4"):
		weapons.select_slot(3)
	if TouchInput.is_action_just_pressed("weapon_5"):
		weapons.select_slot(4)
	if TouchInput.is_action_just_pressed("weapon_next"):
		weapons.cycle_slot()
	if TouchInput.is_action_just_pressed("inspect_weapon"):
		if is_instance_valid(weapons) and is_instance_valid(weapons.viewmodel_rig):
			weapons.viewmodel_rig.play_inspect()
	if TouchInput.is_action_just_pressed("throw_item"):
		_throw_rock()


func _handle_interact_input() -> void:
	if TouchInput.is_action_just_pressed("drop_body") and carried_body:
		_drop_body()
		return
	if not TouchInput.is_action_just_pressed("interact"):
		return
	if carried_body:
		_drop_body()
		return
	if not interact_ray.is_colliding():
		return
	var col := interact_ray.get_collider()
	if not (col is Node):
		return
	var cur: Node = col as Node
	for _depth in range(4):
		if cur == null:
			break
		if cur.has_method("interact"):
			cur.interact(self)
			return
		cur = cur.get_parent()


func _throw_rock() -> void:
	if rock_count <= 0:
		return
	rock_count -= 1
	var rock_scene: PackedScene = preload("res://scenes/items/rock.tscn")
	var rock := rock_scene.instantiate()
	get_tree().current_scene.add_child(rock)
	rock.global_position = camera.global_position + (-camera.global_transform.basis.z) * 0.8
	if rock.has_method("launch"):
		rock.launch(-camera.global_transform.basis.z, 18.0, self)
	NoiseBus.emit_noise(global_position, 3.0, "throw")


func pick_up_body(body: Node3D) -> void:
	if carried_body:
		return
	carried_body = body
	if body.get_parent():
		body.get_parent().remove_child(body)
	carry_point.add_child(body)
	body.position = Vector3.ZERO
	body.rotation = Vector3(deg_to_rad(-80.0), 0.0, 0.0)
	if body.has_method("set_carried"):
		body.set_carried(true)
	carrying_changed.emit(true)
	var hud := get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("show_status"):
		hud.show_status("Dragging body (crouched) — [E/X] Drop" if is_crouching else "Carrying body — [E/X] Drop", 2.2)


func _drop_body() -> void:
	if carried_body == null:
		return
	var body := carried_body
	carry_point.remove_child(body)
	get_tree().current_scene.add_child(body)
	body.global_position = global_position + (-transform.basis.z) * 1.2 + Vector3.UP * 0.2
	body.rotation = Vector3.ZERO
	if body.has_method("set_carried"):
		body.set_carried(false)
	carried_body = null
	carrying_changed.emit(false)


func get_visibility_profile() -> float:
	var profile := 1.0
	if is_crouching:
		profile *= 0.45
	if velocity.length() < 0.2:
		profile *= 0.85
	if is_aiming:
		profile *= 1.05
	return profile


func notify_detection(value: float) -> void:
	max_detection_seen = maxf(max_detection_seen, value)
	detection_changed.emit(value)
	GameState.last_detection = value
	GameState.detection_max_changed.emit(value)


func apply_damage(amount: float, _hit_pos: Vector3 = Vector3.ZERO, _source: Node = null) -> void:
	if is_down or amount <= 0.0:
		return
	hp = maxf(0.0, hp - amount)
	var hud := get_tree().get_first_node_in_group("hud")
	if is_instance_valid(hud) and hud.has_method("show_status"):
		hud.show_status("Taking fire! HP %d" % int(hp), 1.2)
	if hp <= 0.0:
		_on_player_down()


func _on_player_down() -> void:
	## Must be one-shot: multiple guards can shoot the same frame on web and
	## concurrent change_scene_to_file calls will crash the HTML5 build.
	if is_down:
		return
	is_down = true
	set_physics_process(false)
	collision_layer = 0
	var hud := get_tree().get_first_node_in_group("hud")
	if is_instance_valid(hud) and hud.has_method("show_status"):
		hud.show_status("You were dropped — returning to menu…", 2.5)
	await get_tree().create_timer(2.0).timeout
	if not is_inside_tree():
		return
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")


func _toggle_pause() -> void:
	GameState.is_paused = not GameState.is_paused
	get_tree().paused = GameState.is_paused
	if GameState.is_paused or TouchInput.is_touch_ui_desired() or OS.has_feature("web"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		if not GameState.is_paused and TouchInput.is_web_desktop():
			var hud2 := get_tree().get_first_node_in_group("hud")
			if hud2 and hud2.has_method("set_click_to_capture_hint"):
				hud2.set_click_to_capture_hint(true)
	else:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	var hud := get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("set_paused"):
		hud.set_paused(GameState.is_paused)
