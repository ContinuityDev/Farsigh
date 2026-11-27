extends Control
## On-screen virtual controls. Auto-shown on touch devices; hidden on desktop.
##
## Action buttons (Fire, Aim, Crouch, …) are driven by InputEventScreenTouch +
## touch index → TouchInput.press/release. They do NOT depend on
## emulate_mouse_from_touch or BaseButton.button_down — that path was broken on
## mobile web when LookPad (STOP) overlapped the buttons and ate emulated LMB.
##
## Look / move stick also use ScreenTouch indices (multi-touch safe).
## emulate_mouse_from_touch stays ON globally so menu Buttons still receive taps.
## Look-swipes never call press("fire").

const ACTION_BUTTONS := [
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
	["BinoBtn", "binoculars"],
]

@onready var root: Control = $Root
@onready var stick_base: Control = $Root/LeftStick
@onready var stick_knob: Control = $Root/LeftStick/Knob
@onready var look_pad: Control = $Root/LookPad

var _stick_touch_idx: int = -1
var _look_touch_idx: int = -1
## touch_index -> action string (held action buttons)
var _button_touches: Dictionary = {}
var _stick_center: Vector2 = Vector2.ZERO
var _stick_radius: float = 70.0
var _last_look_pos: Vector2 = Vector2.ZERO
var _look_start_pos: Vector2 = Vector2.ZERO
var _look_start_msec: int = 0
var _look_dragged: bool = false
var _action_btns: Array = []  # Array of [Control, String]


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process_input(true)
	# Never blanket-stop the full screen — pause/menu Controls must stay tappable.
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if is_instance_valid(root):
		root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_refresh_visibility()
	# Look pad is visual + hit-test only via ScreenTouch — never steal GUI.
	if is_instance_valid(look_pad):
		look_pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if is_instance_valid(stick_base):
		# Stick also driven by ScreenTouch; IGNORE so it can't block streak HUD.
		stick_base.mouse_filter = Control.MOUSE_FILTER_IGNORE
	await get_tree().process_frame
	_stick_center = stick_base.size * 0.5
	_stick_radius = minf(stick_base.size.x, stick_base.size.y) * 0.42
	_action_btns.clear()
	for b in ACTION_BUTTONS:
		var btn := root.get_node_or_null(b[0]) as BaseButton
		if btn == null:
			continue
		# Visual only — presses come from ScreenTouch hit-tests below.
		btn.focus_mode = Control.FOCUS_NONE
		btn.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn.disabled = false
		# Keep button_down as a desktop/fallback path (force_touch_ui + real mouse).
		var action: String = b[1]
		btn.button_down.connect(_on_btn_down.bind(action))
		btn.button_up.connect(_on_btn_up.bind(action))
		_action_btns.append([btn, action])


func _on_btn_down(action: String) -> void:
	TouchInput.press(action)


func _on_btn_up(action: String) -> void:
	TouchInput.release(action)


func _process(_delta: float) -> void:
	_refresh_visibility()


func _refresh_visibility() -> void:
	var want := TouchInput.is_touch_ui_desired() and not GameState.is_paused
	if visible != want:
		visible = want
	if is_instance_valid(root) and root.visible != want:
		root.visible = want
	if not want:
		_release_all_holds()


func _release_all_holds() -> void:
	if _stick_touch_idx >= 0:
		_stick_touch_idx = -1
		TouchInput.set_move_vector(Vector2.ZERO)
	_look_touch_idx = -1
	for idx in _button_touches.keys():
		var action: String = String(_button_touches[idx])
		TouchInput.release(action)
	_button_touches.clear()


func _input(event: InputEvent) -> void:
	if not visible or GameState.is_paused:
		return
	if event is InputEventScreenTouch:
		_handle_touch(event as InputEventScreenTouch)
	elif event is InputEventScreenDrag:
		_handle_drag(event as InputEventScreenDrag)


func _handle_touch(event: InputEventScreenTouch) -> void:
	var pos: Vector2 = event.position
	if event.pressed:
		# 1) Action buttons first — independent of mouse emulation.
		var hit := _action_at(pos)
		if hit != "":
			_button_touches[event.index] = hit
			TouchInput.press(hit)
			get_viewport().set_input_as_handled()
			return
		# 2) Move stick
		if _stick_touch_idx < 0 and _in_control(stick_base, pos):
			_stick_touch_idx = event.index
			_update_stick(pos)
			get_viewport().set_input_as_handled()
			return
		# 3) Look (never on a button; never fires)
		if _look_touch_idx < 0 and _is_look_area(pos):
			_look_touch_idx = event.index
			_last_look_pos = pos
			_look_start_pos = pos
			_look_start_msec = Time.get_ticks_msec()
			_look_dragged = false
			get_viewport().set_input_as_handled()
			return
	else:
		if _button_touches.has(event.index):
			var action: String = String(_button_touches[event.index])
			_button_touches.erase(event.index)
			TouchInput.release(action)
			get_viewport().set_input_as_handled()
			return
		if event.index == _stick_touch_idx:
			_stick_touch_idx = -1
			TouchInput.set_move_vector(Vector2.ZERO)
			stick_knob.position = _stick_center - stick_knob.size * 0.5
			get_viewport().set_input_as_handled()
			return
		if event.index == _look_touch_idx:
			_look_touch_idx = -1
			_maybe_tap_to_fire(pos)
			get_viewport().set_input_as_handled()
			return


func _handle_drag(event: InputEventScreenDrag) -> void:
	if _button_touches.has(event.index):
		# Finger slid off a hold button — keep action held until release (sticky).
		get_viewport().set_input_as_handled()
		return
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
	## Optional (off by default): short non-dragged look-pad tap fires once.
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
	TouchInput.set_move_vector(Vector2(offset.x / _stick_radius, offset.y / _stick_radius))


func _in_control(ctrl: Control, screen_pos: Vector2) -> bool:
	if not is_instance_valid(ctrl) or not ctrl.visible:
		return false
	return ctrl.get_global_rect().has_point(screen_pos)


func _is_look_area(screen_pos: Vector2) -> bool:
	if _in_control(look_pad, screen_pos):
		return true
	var vp := get_viewport().get_visible_rect()
	return screen_pos.x >= vp.size.x * 0.42 and not _in_control(stick_base, screen_pos)


func _action_at(screen_pos: Vector2) -> String:
	for pair in _action_btns:
		var btn: Control = pair[0]
		if is_instance_valid(btn) and btn.visible and btn.get_global_rect().has_point(screen_pos):
			return String(pair[1])
	return ""
