extends Control
class_name ItemMiniWheel
## Small radial picker for Gadgets or Lethals (hold Q / G).


signal picked(kind: String, id: String)

const SLOW_SCALE := 0.45
const RADIUS := 110.0

var open: bool = false
var kind: String = "gadget"  # gadget | lethal
var _entries: Array = []
var _hover: int = -1
var _saved_scale: float = 1.0
var _center: Vector2 = Vector2.ZERO


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_preset(Control.PRESET_FULL_RECT)
	process_mode = Node.PROCESS_MODE_ALWAYS
	z_index = 85


func open_for(k: String, entries: Array) -> void:
	if open or entries.is_empty():
		return
	kind = k
	_entries = entries.duplicate(true)
	var n := _entries.size()
	var step := TAU / float(maxi(1, n))
	var start := -PI * 0.5
	for i in range(n):
		_entries[i]["angle"] = start + step * float(i)
	open = true
	visible = true
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	size = get_viewport().get_visible_rect().size
	_hover = 0
	_saved_scale = Engine.time_scale
	Engine.time_scale = SLOW_SCALE
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	queue_redraw()


func close_wheel(apply: bool = true) -> void:
	if not open:
		return
	if apply and _hover >= 0 and _hover < _entries.size():
		picked.emit(kind, String(_entries[_hover].get("id", "")))
	open = false
	visible = false
	Engine.time_scale = _saved_scale if _saved_scale > 0.05 else 1.0
	if not TouchInput.is_touch_ui_desired() and not OS.has_feature("web"):
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _process(_delta: float) -> void:
	if not open:
		return
	_center = size * 0.5
	var mp := get_local_mouse_position() - _center
	var sx := Input.get_joy_axis(0, JOY_AXIS_RIGHT_X)
	var sy := Input.get_joy_axis(0, JOY_AXIS_RIGHT_Y)
	var dir := mp if mp.length() > 20.0 else Vector2(sx, sy)
	if dir.length() > 0.2:
		var ang := atan2(dir.y, dir.x)
		_hover = _nearest(ang)
	queue_redraw()


func _nearest(ang: float) -> int:
	var best := 0
	var best_d := 999.0
	for i in range(_entries.size()):
		var d := absf(angle_difference(float(_entries[i]["angle"]), ang))
		if d < best_d:
			best_d = d
			best = i
	return best


func _gui_input(event: InputEvent) -> void:
	if not open:
		return
	if event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		if not st.pressed:
			close_wheel(true)
			accept_event()
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and not mb.pressed:
			close_wheel(true)
			accept_event()


func _draw() -> void:
	if not open:
		return
	var c := _center
	draw_circle(c, RADIUS + 22.0, Color(0.05, 0.06, 0.07, 0.75))
	var title := "GADGETS"
	if kind == "lethal":
		title = "LETHALS"
	elif kind == "support":
		title = "SUPPORT"
	draw_string(ThemeDB.fallback_font, c + Vector2(-36, 6), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(0.9, 0.85, 0.5))
	for i in range(_entries.size()):
		var e: Dictionary = _entries[i]
		var ang: float = float(e["angle"])
		var pos := c + Vector2(cos(ang), sin(ang)) * RADIUS
		var selected := i == _hover
		var col := Color(0.95, 0.88, 0.4) if selected else Color(0.78, 0.8, 0.84)
		draw_circle(pos, 32.0 if selected else 26.0, Color(0.12, 0.13, 0.15, 0.95))
		draw_arc(pos, 32.0 if selected else 26.0, 0.0, TAU, 28, col, 2.0, true)
		var label := String(e.get("name", "?"))
		var cnt := int(e.get("count", 0))
		draw_string(ThemeDB.fallback_font, pos + Vector2(-30, -6), label, HORIZONTAL_ALIGNMENT_CENTER, 60, 12, col)
		draw_string(ThemeDB.fallback_font, pos + Vector2(-18, 12), "×%d" % cnt, HORIZONTAL_ALIGNMENT_CENTER, 36, 12, Color(0.95, 0.95, 0.95))
