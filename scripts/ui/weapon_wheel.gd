extends Control
class_name WeaponWheel
## Radial weapon wheel — hold TAB (or long-press Swap on mobile).
## Assigns a carried weapon (up to 3) into slot 1 or slot 2.


signal closed_assigned(slot: int, weapon_id: int)

const SLOW_SCALE := 0.32
const RADIUS := 148.0
const INNER := 52.0

var open: bool = false
var _target_slot: int = 0  # 0 or 1 — which loadout slot to fill
var _entries: Array = []  # [{wid, name, angle}]
var _hover: int = -1
var _saved_scale: float = 1.0
var _center: Vector2 = Vector2.ZERO
var _touch_mode: bool = false


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_preset(Control.PRESET_FULL_RECT)
	process_mode = Node.PROCESS_MODE_ALWAYS
	z_index = 80


func is_open() -> bool:
	return open


func open_wheel(for_slot: int = -1, touch: bool = false) -> void:
	if open:
		return
	_touch_mode = touch
	var wm := _weapon_manager()
	if wm == null:
		return
	_target_slot = for_slot if for_slot >= 0 else clampi(int(wm.get("active_slot")), 0, 1)
	_entries = _build_entries()
	if _entries.is_empty():
		return
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
		var wid: int = int(_entries[_hover]["wid"])
		_assign(wid)
		closed_assigned.emit(_target_slot, wid)
	open = false
	visible = false
	Engine.time_scale = _saved_scale if _saved_scale > 0.05 else 1.0
	if not TouchInput.is_touch_ui_desired() and not OS.has_feature("web"):
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif TouchInput.is_web_desktop():
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _weapon_manager() -> Node:
	var player := get_tree().get_first_node_in_group("player")
	if is_instance_valid(player) and player.has_node("WeaponManager"):
		return player.get_node("WeaponManager")
	return null


func _build_entries() -> Array:
	var carried := GameState.get_carried_weapons()
	var out: Array = []
	var n := carried.size()
	if n == 0:
		return out
	var step := TAU / float(n)
	var start := -PI * 0.5
	for i in range(n):
		var wid: GameState.WeaponId = carried[i]
		var w := WeaponData.from_id(wid, GameState.get_weapon_mods(wid))
		out.append({
			"wid": int(wid),
			"name": w.display_name,
			"angle": start + step * float(i),
		})
	return out


func _assign(wid_int: int) -> void:
	var wid := wid_int as GameState.WeaponId
	GameState.assign_carried_to_slot(_target_slot, wid)
	var wm := _weapon_manager()
	if wm and wm.has_method("refresh_slot_from_loadout"):
		wm.refresh_slot_from_loadout(_target_slot)
		wm.select_slot(_target_slot)
	var hud := get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("show_status"):
		var w := WeaponData.from_id(wid, GameState.get_weapon_mods(wid))
		hud.show_status("Slot %d ← %s" % [_target_slot + 1, w.display_name], 1.6)


func _process(_delta: float) -> void:
	if not open:
		return
	_center = size * 0.5
	var dir := _aim_dir()
	if dir.length() > 0.18:
		var ang := atan2(dir.y, dir.x)
		_hover = _nearest_entry(ang)
	queue_redraw()


func _aim_dir() -> Vector2:
	# Mouse / touch relative to center, else right stick
	var mp := get_local_mouse_position()
	var mouse_dir := mp - _center
	if mouse_dir.length() > 24.0:
		return mouse_dir.normalized()
	var sx := Input.get_joy_axis(0, JOY_AXIS_RIGHT_X)
	var sy := Input.get_joy_axis(0, JOY_AXIS_RIGHT_Y)
	var stick := Vector2(sx, sy)
	if stick.length() > 0.35:
		return stick.normalized()
	return Vector2.ZERO


func _nearest_entry(ang: float) -> int:
	var best := 0
	var best_d := 999.0
	for i in range(_entries.size()):
		var a: float = float(_entries[i]["angle"])
		var d := absf(angle_difference(a, ang))
		if d < best_d:
			best_d = d
			best = i
	return best


func _gui_input(event: InputEvent) -> void:
	if not open:
		return
	if event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		if st.pressed:
			_hover = _nearest_entry(atan2((st.position - _center).y, (st.position - _center).x))
			queue_redraw()
		else:
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
	draw_circle(c, RADIUS + 28.0, Color(0.04, 0.05, 0.06, 0.72))
	draw_arc(c, RADIUS, 0.0, TAU, 64, Color(0.85, 0.78, 0.45, 0.55), 2.5, true)
	draw_circle(c, INNER, Color(0.08, 0.09, 0.10, 0.9))
	var slot_txt := "SLOT %d" % (_target_slot + 1)
	draw_string(ThemeDB.fallback_font, c + Vector2(-28, 6), slot_txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.92, 0.86, 0.55))
	var s1 := GameState.selected_primary
	var s2 := GameState.selected_secondary
	for i in range(_entries.size()):
		var e: Dictionary = _entries[i]
		var ang: float = float(e["angle"])
		var pos := c + Vector2(cos(ang), sin(ang)) * RADIUS
		var wid: int = int(e["wid"])
		var selected := (i == _hover)
		var in_slot := (wid == int(s1) and _target_slot == 0) or (wid == int(s2) and _target_slot == 1)
		var col := Color(0.95, 0.9, 0.55) if selected else Color(0.75, 0.78, 0.82)
		if in_slot:
			col = Color(0.45, 0.92, 0.55)
		draw_circle(pos, 36.0 if selected else 30.0, Color(0.12, 0.14, 0.16, 0.95))
		draw_arc(pos, 36.0 if selected else 30.0, 0.0, TAU, 32, col, 2.0 if selected else 1.4, true)
		var label := String(e["name"])
		if label.length() > 14:
			label = label.substr(0, 12) + "…"
		draw_string(ThemeDB.fallback_font, pos + Vector2(-34, 5), label, HORIZONTAL_ALIGNMENT_LEFT, 68, 12, col)
	draw_string(ThemeDB.fallback_font, c + Vector2(-90, RADIUS + 48), "Aim · release to equip", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.7, 0.72, 0.75, 0.85))
