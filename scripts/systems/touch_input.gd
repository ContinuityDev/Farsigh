extends Node
## Bridges on-screen touch controls into InputMap actions and look deltas.
## Visible only on touch devices (or when force_touch_ui is enabled for testing).

signal look_delta(relative: Vector2)

var move_vector: Vector2 = Vector2.ZERO
var look_relative: Vector2 = Vector2.ZERO
var force_touch_ui: bool = false

## Soft action presses driven by touch buttons (cleared each frame after consume).
var _pressed: Dictionary = {}
var _just_pressed: Dictionary = {}
var _just_released: Dictionary = {}


func is_touch_ui_desired() -> bool:
	## Show virtual controls on phones/tablets only; hide on desktop PC.
	## Set force_touch_ui / TOUCH_UI=1 to preview on desktop.
	if force_touch_ui or OS.get_environment("TOUCH_UI") == "1":
		return true
	if OS.has_feature("mobile") or OS.has_feature("android") or OS.has_feature("ios"):
		return true
	return false


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


func is_action_pressed(action: String) -> bool:
	return _pressed.get(action, false) or Input.is_action_pressed(action)


func is_action_just_pressed(action: String) -> bool:
	var touch: bool = bool(_just_pressed.get(action, false))
	return touch or Input.is_action_just_pressed(action)


func is_action_just_released(action: String) -> bool:
	var touch: bool = bool(_just_released.get(action, false))
	return touch or Input.is_action_just_released(action)


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
