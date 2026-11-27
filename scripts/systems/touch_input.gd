extends Node
## Bridges on-screen touch controls into InputMap actions and look deltas.
## Visible on native mobile, and on web builds when a touchscreen is available.
##
## Mobile web safety: keep emulate_mouse_from_touch ON so Buttons / sliders /
## OptionButtons / ScrollContainers receive taps. `fire` / `aim` are still bound
## to mouse buttons, so while the virtual controls are up we ignore mouse (and
## emulated-mouse) bindings for those actions — look-swipes never shoot.

signal look_delta(relative: Vector2)

## Actions that must only come from on-screen buttons (or non-mouse hardware)
## while the touch UI is up — never from emulated / real mouse clicks.
const TOUCH_UI_MOUSE_BLOCKED := ["fire", "aim"]

var move_vector: Vector2 = Vector2.ZERO
var look_relative: Vector2 = Vector2.ZERO
var force_touch_ui: bool = false

## Soft action presses driven by touch buttons (cleared each frame after consume).
var _pressed: Dictionary = {}
var _just_pressed: Dictionary = {}
var _just_released: Dictionary = {}


func _ready() -> void:
	# Menus need mouse-from-touch. Fire/aim safety is handled in is_action_*.
	Input.emulate_mouse_from_touch = true
	Input.emulate_touch_from_mouse = false


func is_touch_ui_desired() -> bool:
	## Show virtual controls on phones/tablets and touch-capable mobile browsers.
	## Set force_touch_ui / TOUCH_UI=1 to preview on desktop.
	if force_touch_ui or OS.get_environment("TOUCH_UI") == "1":
		return true
	if OS.has_feature("mobile") or OS.has_feature("android") or OS.has_feature("ios"):
		return true
	# GitHub Pages / any web build: detect real touch hardware (phones & tablets
	# in the browser). Desktop browsers without a touchscreen stay mouse-only.
	if OS.has_feature("web") and DisplayServer.is_touchscreen_available():
		return true
	return false


func is_web_desktop() -> bool:
	return OS.has_feature("web") and not is_touch_ui_desired()


func set_move_vector(v: Vector2) -> void:
	move_vector = v.limit_length(1.0)


func add_look_relative(v: Vector2) -> void:
	look_relative += v
	look_delta.emit(v)


func consume_look_relative() -> Vector2:
	var v := look_relative
	look_relative = Vector2.ZERO
	return v


func press(action: String) -> void:
	if not _pressed.get(action, false):
		_just_pressed[action] = true
	_pressed[action] = true


func release(action: String) -> void:
	if _pressed.get(action, false):
		_just_released[action] = true
	_pressed[action] = false


func pulse(action: String) -> void:
	## One-frame tap (used by optional tap-to-fire).
	_just_pressed[action] = true
	_pressed[action] = true
	# Release next frame via deferred so just_pressed is visible this frame.
	call_deferred("_deferred_pulse_release", action)


func _deferred_pulse_release(action: String) -> void:
	release(action)


func is_action_pressed(action: String) -> bool:
	if bool(_pressed.get(action, false)):
		return true
	if not Input.is_action_pressed(action):
		return false
	if _should_ignore_mouse_binding(action):
		return _is_non_mouse_action_pressed(action)
	return true


func is_action_just_pressed(action: String) -> bool:
	if bool(_just_pressed.get(action, false)):
		return true
	if not Input.is_action_just_pressed(action):
		return false
	if _should_ignore_mouse_binding(action):
		return _is_non_mouse_action_just_pressed(action)
	return true


func is_action_just_released(action: String) -> bool:
	if bool(_just_released.get(action, false)):
		return true
	if not Input.is_action_just_released(action):
		return false
	if _should_ignore_mouse_binding(action):
		# Don't report mouse-button releases as aim/fire releases on touch UI
		return false
	return true


func _should_ignore_mouse_binding(action: String) -> bool:
	## While virtual controls are showing, never treat mouse clicks as fire/aim.
	## Covers DEVICE_ID_EMULATION and any browser that synthesizes real LMB from touch.
	## PC mouse play keeps touch UI off, so LMB still fires there.
	return is_touch_ui_desired() and action in TOUCH_UI_MOUSE_BLOCKED


func is_emulated_mouse_event(event: InputEvent) -> bool:
	return event is InputEventMouse and event.device == InputEvent.DEVICE_ID_EMULATION


func _is_non_mouse_action_pressed(action: String) -> bool:
	for ev in InputMap.action_get_events(action):
		if ev is InputEventMouseButton:
			continue
		if ev is InputEventJoypadButton:
			var jb := ev as InputEventJoypadButton
			for pad in Input.get_connected_joypads():
				if Input.is_joy_button_pressed(pad, jb.button_index):
					return true
		elif ev is InputEventJoypadMotion:
			var jm := ev as InputEventJoypadMotion
			for pad in Input.get_connected_joypads():
				var axis_v := Input.get_joy_axis(pad, jm.axis)
				if absf(axis_v) >= 0.5 and signf(axis_v) == signf(jm.axis_value):
					return true
		elif ev is InputEventKey:
			var key := ev as InputEventKey
			if key.keycode != KEY_NONE and Input.is_key_pressed(key.keycode):
				return true
			if key.physical_keycode != KEY_NONE and Input.is_physical_key_pressed(key.physical_keycode):
				return true
	return false


func _is_non_mouse_action_just_pressed(action: String) -> bool:
	## Approximate: pressed now via non-mouse and soft just_pressed already checked.
	return _is_non_mouse_action_pressed(action) and Input.is_action_just_pressed(action)


func _process(_delta: float) -> void:
	_just_pressed.clear()
	_just_released.clear()


func get_move_axis() -> Vector2:
	var keyboard := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	if move_vector.length() > 0.05:
		return move_vector
	return keyboard


func get_look_axis() -> Vector2:
	return Input.get_vector("look_left", "look_right", "look_up", "look_down")
