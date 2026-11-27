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
var _footstep_timer: float = 0.0
var carried_body: Node3D = null
var rock_count: int = 5
var max_detection_seen: float = 0.0
var hp: float = 100.0
var is_down: bool = false
var _capsule: CapsuleShape3D
var _crouch_toggled: bool = false


func _ready() -> void:
	# Browsers require a user gesture before pointer lock — don't auto-capture on web.
	if TouchInput.is_touch_ui_desired() or OS.has_feature("web"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	else:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_capsule = collision_shape.shape as CapsuleShape3D
	add_to_group("player")
	weapons.camera_path = weapons.get_path_to(camera)
	process_mode = Node.PROCESS_MODE_PAUSABLE
	var hud := get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("set_click_to_capture_hint"):
		hud.set_click_to_capture_hint(TouchInput.is_web_desktop())


func _unhandled_input(event: InputEvent) -> void:
	if GameState.is_paused:
		return
	# Desktop browser: click/tap canvas to capture mouse for look
	if OS.has_feature("web") and not TouchInput.is_touch_ui_desired():
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
				Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
				var hud := get_tree().get_first_node_in_group("hud")
				if hud and hud.has_method("set_click_to_capture_hint"):
					hud.set_click_to_capture_hint(false)
				get_viewport().set_input_as_handled()
				return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_apply_look(-event.relative.x * MOUSE_SENS, -event.relative.y * MOUSE_SENS)
	if event.is_action_pressed("pause_menu"):
		_toggle_pause()


func _physics_process(delta: float) -> void:
	if GameState.is_paused or is_down:
		return

	# Touch look swipe + gamepad stick
	var touch_look := TouchInput.consume_look_relative()
	if touch_look != Vector2.ZERO:
		_apply_look(-touch_look.x * TOUCH_LOOK_SENS * 0.01, -touch_look.y * TOUCH_LOOK_SENS * 0.01)
	var pad_look := TouchInput.get_look_axis()
	if pad_look.length() > 0.1:
		_apply_look(-pad_look.x * GAMEPAD_LOOK_SENS * delta, -pad_look.y * GAMEPAD_LOOK_SENS * delta)

	if not is_on_floor():
		velocity.y -= gravity * delta

	_handle_crouch()
	is_aiming = TouchInput.is_action_pressed("aim")
	camera.fov = lerpf(camera.fov, 55.0 if is_aiming else 70.0, 10.0 * delta)

	var input_dir := TouchInput.get_move_axis()
	var direction := (transform.basis * Vector3(input_dir.x, 0.0, input_dir.y)).normalized()
	var speed := WALK_SPEED
	var sprinting := TouchInput.is_action_pressed("sprint") and not is_crouching and input_dir.length() > 0.1
	if is_crouching:
		speed = CROUCH_SPEED
	elif sprinting:
		speed = SPRINT_SPEED

	if direction:
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
	else:
		velocity.x = move_toward(velocity.x, 0.0, speed)
		velocity.z = move_toward(velocity.z, 0.0, speed)

	if TouchInput.is_action_just_pressed("jump") and is_on_floor() and not is_crouching:
		velocity.y = JUMP_VELOCITY

	move_and_slide()
	_update_footsteps(delta, direction.length() > 0.1 and is_on_floor(), sprinting)
	_handle_combat_input()
	_handle_interact_input()


func _apply_look(yaw: float, pitch: float) -> void:
	rotate_y(yaw)
	head.rotate_x(pitch)
	head.rotation.x = clampf(head.rotation.x, deg_to_rad(-85.0), deg_to_rad(85.0))


func _handle_crouch() -> void:
	# Hold on PC / gamepad; toggle-friendly on touch (button hold also works)
	var want := TouchInput.is_action_pressed("crouch")
	if want == is_crouching:
		return
	is_crouching = want
	var target_h := CROUCH_HEIGHT if is_crouching else STAND_HEIGHT
	_capsule.height = target_h
	collision_shape.position.y = target_h * 0.5
	head.position.y = target_h - 0.15


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
	if TouchInput.is_action_just_pressed("fire"):
		weapons.try_fire()
	elif TouchInput.is_action_pressed("fire"):
		weapons.try_fire_held()
	if TouchInput.is_action_just_pressed("reload"):
		weapons.start_reload()
	if TouchInput.is_action_just_pressed("melee"):
		weapons.try_melee_takedown(self)
	if TouchInput.is_action_just_pressed("weapon_1"):
		weapons.switch_slot(true)
	if TouchInput.is_action_just_pressed("weapon_2"):
		weapons.switch_slot(false)
	if TouchInput.is_action_just_pressed("weapon_next"):
		weapons.switch_slot(not weapons.active_is_primary)
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
	if col == null:
		return
	var target: Node = col
	if target.has_method("interact"):
		target.interact(self)
	elif target.get_parent() and target.get_parent().has_method("interact"):
		target.get_parent().interact(self)


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
