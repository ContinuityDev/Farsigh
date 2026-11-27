extends Control
## On-screen virtual controls. Auto-shown on touch devices; hidden on desktop.
## Look-swipes and the move stick never fire the gun — only FireBtn (and optional
## tap-to-fire) call TouchInput.press("fire"). Multi-touch: stick + look + fire
## can all be active at once via separate touch indices.

@onready var root: Control = $Root
@onready var stick_base: Control = $Root/LeftStick
@onready var stick_knob: Control = $Root/LeftStick/Knob
@onready var look_pad: Control = $Root/LookPad

var _stick_touch_idx: int = -1
var _look_touch_idx: int = -1
var _stick_center: Vector2 = Vector2.ZERO
var _stick_radius: float = 70.0
var _last_look_pos: Vector2 = Vector2.ZERO
var _look_start_pos: Vector2 = Vector2.ZERO
var _look_start_msec: int = 0
var _look_dragged: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = TouchInput.is_touch_ui_desired()
	root.visible = visible
	# STOP so look/stick owns the pointer; buttons still receive their own events.
	mouse_filter = Control.MOUSE_FILTER_IGNORE if not visible else Control.MOUSE_FILTER_STOP
	if is_instance_valid(look_pad):
		look_pad.mouse_filter = Control.MOUSE_FILTER_STOP
	if is_instance_valid(stick_base):
		stick_base.mouse_filter = Control.MOUSE_FILTER_STOP
	await get_tree().process_frame
	_stick_center = stick_base.size * 0.5
	_stick_radius = minf(stick_base.size.x, stick_base.size.y) * 0.42
	for b in [
		["FireBtn", "fire"],
		["AimBtn", "aim"],
		["CrouchBtn", "crouch"],
		["SprintBtn", "sprint"],
		["JumpBtn", "jump"],
		["InteractBtn", "interact"],
		["ThrowBtn", "throw_item"],
		["ReloadBtn", "reload"],
		["WeaponBtn", "weapon_next"],
		["MeleeBtn", "melee"],
		["InspectBtn", "inspect_weapon"],
		["LeanLeftBtn", "lean_left"],
		["LeanRightBtn", "lean_right"],
	]:
		var alt := root.get_node_or_null(b[0]) as BaseButton
		if alt:
			_wire_button(alt, b[1])


func _wire_button(btn: BaseButton, action: String) -> void:
	btn.focus_mode = Control.FOCUS_NONE
	btn.button_down.connect(func(): TouchInput.press(action))
	btn.button_up.connect(func(): TouchInput.release(action))
	# Swallow the button's events so they never fall through as look/fire mouse synth.
	btn.gui_input.connect(func(event: InputEvent):
		if event is InputEventScreenTouch or event is InputEventScreenDrag or event is InputEventMouseButton:
			accept_event()
	)


func _input(event: InputEvent) -> void:
	if not visible or GameState.is_paused:
		return
	if event is InputEventScreenTouch:
		_handle_touch(event)
	elif event is InputEventScreenDrag:
		_handle_drag(event)


func _handle_touch(event: InputEventScreenTouch) -> void:
	var pos: Vector2 = event.position
	if event.pressed:
		if _stick_touch_idx < 0 and _in_control(stick_base, pos):
			_stick_touch_idx = event.index
			_update_stick(pos)
			get_viewport().set_input_as_handled()
		elif _look_touch_idx < 0 and _is_look_area(pos) and not _over_action_button(pos):
			_look_touch_idx = event.index
			_last_look_pos = pos
			_look_start_pos = pos
			_look_start_msec = Time.get_ticks_msec()
			_look_dragged = false
			get_viewport().set_input_as_handled()
	else:
		if event.index == _stick_touch_idx:
			_stick_touch_idx = -1
			TouchInput.set_move_vector(Vector2.ZERO)
			stick_knob.position = _stick_center - stick_knob.size * 0.5
			get_viewport().set_input_as_handled()
		if event.index == _look_touch_idx:
			_look_touch_idx = -1
			_maybe_tap_to_fire(pos)
			get_viewport().set_input_as_handled()


func _handle_drag(event: InputEventScreenDrag) -> void:
	if event.index == _stick_touch_idx:
		_update_stick(event.position)
		get_viewport().set_input_as_handled()
	elif event.index == _look_touch_idx:
		var delta := event.position - _last_look_pos
		_last_look_pos = event.position
		if event.position.distance_to(_look_start_pos) > 12.0:
			_look_dragged = true
		TouchInput.add_look_relative(delta)
		get_viewport().set_input_as_handled()


func _maybe_tap_to_fire(release_pos: Vector2) -> void:
	## Optional (off by default): a short, non-dragged tap on the look pad fires once.
	if not GameState.tap_to_fire:
		return
	if _look_dragged:
		return
	if release_pos.distance_to(_look_start_pos) > 18.0:
		return
	if Time.get_ticks_msec() - _look_start_msec > 280:
		return
	TouchInput.pulse("fire")


func _update_stick(screen_pos: Vector2) -> void:
	var local := stick_base.get_global_transform_with_canvas().affine_inverse() * screen_pos
	var offset := local - _stick_center
	if offset.length() > _stick_radius:
		offset = offset.limit_length(_stick_radius)
	stick_knob.position = _stick_center + offset - stick_knob.size * 0.5
	# Godot move_forward is negative Y in get_vector mapping — use y flipped for stick up = forward
	TouchInput.set_move_vector(Vector2(offset.x / _stick_radius, offset.y / _stick_radius))


func _in_control(ctrl: Control, screen_pos: Vector2) -> bool:
	var r := ctrl.get_global_rect()
	return r.has_point(screen_pos)


func _is_look_area(screen_pos: Vector2) -> bool:
	## Prefer the dedicated LookPad; also allow any right-half swipe that isn't
	## on the stick or a button so looking feels natural on phones.
	if _in_control(look_pad, screen_pos):
		return true
	var vp := get_viewport().get_visible_rect()
	return screen_pos.x >= vp.size.x * 0.42 and not _in_control(stick_base, screen_pos)


func _over_action_button(screen_pos: Vector2) -> bool:
	for name in ["FireBtn", "AimBtn", "CrouchBtn", "SprintBtn", "JumpBtn", "InteractBtn", "ThrowBtn", "ReloadBtn", "WeaponBtn", "MeleeBtn", "InspectBtn", "LeanLeftBtn", "LeanRightBtn"]:
		var btn := root.get_node_or_null(name) as Control
		if btn and btn.get_global_rect().has_point(screen_pos):
			return true
	return false
