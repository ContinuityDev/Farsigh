extends Control
## On-screen virtual controls. Auto-shown on touch devices; hidden on desktop.
##
## Action buttons (Fire, Aim, Crouch, …) are driven by InputEventScreenTouch +
## touch index → TouchInput.press/release. They do NOT depend on
## emulate_mouse_from_touch or BaseButton.button_down — that path was broken on
## mobile web when LookPad (STOP) overlapped the buttons and ate emulated LMB.
##
## Contextual buttons (Takedown, Reload, Use, Adjust Zoom, …) only appear when
## usable, then pack into fixed right-side slots so the HUD stays gap-free.
##
## Look / move stick also use ScreenTouch indices (multi-touch safe).
## emulate_mouse_from_touch stays ON globally so menu Buttons still receive taps.
## Look-swipes never call press("fire").

## Always-visible combat/movement controls (never context-filtered away).
const ALWAYS_BUTTONS := [
	["FireBtn", "fire"],
	["AimBtn", "aim"],
	["CrouchBtn", "crouch"],
	["SprintBtn", "sprint"],
	["JumpBtn", "jump"],
	["LeanLeftBtn", "lean_left"],
	["LeanRightBtn", "lean_right"],
	["WeaponBtn", "weapon_next"],
]

## Context-filtered actions — shown only when usable, packed into CONTEXT_SLOTS.
const CONTEXT_BUTTONS := [
	["MeleeBtn", "melee"],
	["InteractBtn", "interact"],
	["ThrowBtn", "throw_item"],
	["ReloadBtn", "reload"],
	["InspectBtn", "inspect_weapon"],
	["BinoBtn", "binoculars"],
	["AdjustZoomBtn", "scope_zoom"],
]

## Packed layout for contextual buttons (right side, top → bottom, 2 columns).
## [offset_left, offset_top, offset_right, offset_bottom] relative to top-right.
const CONTEXT_SLOTS := [
	[-150.0, 80.0, -40.0, 150.0],
	[-270.0, 80.0, -160.0, 150.0],
	[-390.0, 80.0, -280.0, 150.0],
	[-150.0, 160.0, -40.0, 230.0],
	[-270.0, 160.0, -160.0, 230.0],
	[-390.0, 160.0, -280.0, 230.0],
	[-150.0, 240.0, -40.0, 310.0],
	[-270.0, 240.0, -160.0, 310.0],
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
var _context_btns: Array = []  # Array of [Control, String]
var _layout_tick: float = 0.0


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
	_context_btns.clear()
	for b in ALWAYS_BUTTONS:
		var btn := _wire_button(String(b[0]), String(b[1]))
		if btn:
			_action_btns.append([btn, String(b[1])])
	for b in CONTEXT_BUTTONS:
		var btn2 := _wire_button(String(b[0]), String(b[1]))
		if btn2:
			_action_btns.append([btn2, String(b[1])])
			_context_btns.append([btn2, String(b[1])])
	_update_contextual_buttons()


func _wire_button(node_name: String, action: String) -> BaseButton:
	if not is_instance_valid(root):
		return null
	var btn := root.get_node_or_null(node_name) as BaseButton
	if btn == null:
		return null
	# Visual only — presses come from ScreenTouch hit-tests below.
	btn.focus_mode = Control.FOCUS_NONE
	btn.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.disabled = false
	# Keep button_down as a desktop/fallback path (force_touch_ui + real mouse).
	btn.button_down.connect(_on_btn_down.bind(action))
	btn.button_up.connect(_on_btn_up.bind(action))
	return btn


func _on_btn_down(action: String) -> void:
	TouchInput.press(action)


func _on_btn_up(action: String) -> void:
	TouchInput.release(action)


func _process(delta: float) -> void:
	_refresh_visibility()
	_layout_tick += delta
	# Refresh contextual visibility ~10 Hz — cheap enough for HUD, avoids per-frame ray spam
	if _layout_tick >= 0.1:
		_layout_tick = 0.0
		if visible:
			_update_contextual_buttons()


func _refresh_visibility() -> void:
	var want := TouchInput.is_touch_ui_desired() and not GameState.is_paused
	if visible != want:
		visible = want
	if is_instance_valid(root) and root.visible != want:
		root.visible = want
	if not want:
		_release_all_holds()


func _update_contextual_buttons() -> void:
	if not is_instance_valid(root):
		return
	var player: Node = get_tree().get_first_node_in_group("player") as Node
	var wm: Node = null
	if is_instance_valid(player) and player.has_node("WeaponManager"):
		wm = player.get_node("WeaponManager")
	var aiming: bool = bool(player.get("is_aiming")) if is_instance_valid(player) else false
	var binos_up: bool = bool(player.get("binoculars_slow")) if is_instance_valid(player) else false
	var carried: Variant = player.get("carried_body") if is_instance_valid(player) else null

	var show: Dictionary = {}
	# Takedown — only when an enemy is in melee range/LOS
	show["melee"] = is_instance_valid(wm) and wm.has_method("can_takedown") and bool(wm.can_takedown(player))
	# Interact / drop body — when carrying, or when ray hits something interactable
	show["interact"] = false
	if is_instance_valid(player):
		if carried != null:
			show["interact"] = true
		elif player.get("interact_ray") is RayCast3D:
			var ray: RayCast3D = player.get("interact_ray")
			if ray.is_colliding():
				var col = ray.get_collider()
				var cur: Node = col as Node if col is Node else null
				for _i in range(4):
					if cur == null:
						break
					if cur.has_method("interact"):
						show["interact"] = true
						break
					cur = cur.get_parent()
	# Rock throw — only with rocks in inventory
	var rocks := int(player.get("rock_count")) if is_instance_valid(player) else 0
	show["throw_item"] = rocks > 0
	# Reload — mag not full AND reserve ammo available
	show["reload"] = is_instance_valid(wm) and wm.has_method("needs_reload") and bool(wm.needs_reload())
	# Inspect — whenever a weapon is equipped (not empty-handed)
	show["inspect_weapon"] = is_instance_valid(wm) and wm.get_active() != null
	# Binoculars — hide while ADS (scope owns the view). Stay visible while
	# raised so mobile can toggle them back down (same ScreenTouch hit-test).
	show["binoculars"] = not aiming
	# Adjust Zoom — only while ADS with a variable magnified scope
	# (binoculars use overlay ± buttons + pinch while raised).
	show["scope_zoom"] = aiming and is_instance_valid(wm) and wm.has_method("has_scope_overlay") and bool(wm.has_scope_overlay())

	# Apply visibility + release holds on buttons that disappear mid-press
	var visible_ctx: Array = []
	for pair in _context_btns:
		var btn: Control = pair[0]
		var action: String = String(pair[1])
		var want_vis: bool = bool(show.get(action, false))
		if is_instance_valid(btn):
			if btn.visible and not want_vis:
				_release_action_holds(action)
			btn.visible = want_vis
			if want_vis:
				visible_ctx.append(btn)

	# Pack remaining contextual buttons into fixed slots (no gaps)
	for i in range(visible_ctx.size()):
		if i >= CONTEXT_SLOTS.size():
			break
		var slot: Array = CONTEXT_SLOTS[i]
		var b: Control = visible_ctx[i]
		b.anchor_left = 1.0
		b.anchor_top = 0.0
		b.anchor_right = 1.0
		b.anchor_bottom = 0.0
		b.offset_left = float(slot[0])
		b.offset_top = float(slot[1])
		b.offset_right = float(slot[2])
		b.offset_bottom = float(slot[3])
		b.grow_horizontal = Control.GROW_DIRECTION_BEGIN


func _release_action_holds(action: String) -> void:
	var to_clear: Array = []
	for idx in _button_touches.keys():
		if String(_button_touches[idx]) == action:
			to_clear.append(idx)
	for idx2 in to_clear:
		TouchInput.release(action)
		_button_touches.erase(idx2)


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
	var idx := event.index
	var pos := event.position
	if event.pressed:
		# Action button hit-test first (highest priority)
		var action := _action_at(pos)
		if action != "":
			_button_touches[idx] = action
			TouchInput.press(action)
			get_viewport().set_input_as_handled()
			return
		# Left stick
		if _stick_touch_idx < 0 and _in_control(stick_base, pos):
			_stick_touch_idx = idx
			_update_stick(pos)
			get_viewport().set_input_as_handled()
			return
		# Look area (right half / look pad)
		if _look_touch_idx < 0 and _is_look_area(pos):
			_look_touch_idx = idx
			_last_look_pos = pos
			_look_start_pos = pos
			_look_start_msec = Time.get_ticks_msec()
			_look_dragged = false
			get_viewport().set_input_as_handled()
			return
	else:
		if _button_touches.has(idx):
			var action2: String = String(_button_touches[idx])
			TouchInput.release(action2)
			_button_touches.erase(idx)
			get_viewport().set_input_as_handled()
			return
		if idx == _stick_touch_idx:
			_stick_touch_idx = -1
			TouchInput.set_move_vector(Vector2.ZERO)
			if is_instance_valid(stick_knob):
				stick_knob.position = _stick_center - stick_knob.size * 0.5
			get_viewport().set_input_as_handled()
			return
		if idx == _look_touch_idx:
			_look_touch_idx = -1
			_maybe_tap_to_fire(pos)
			get_viewport().set_input_as_handled()
			return


func _handle_drag(event: InputEventScreenDrag) -> void:
	var idx := event.index
	var pos := event.position
	if _button_touches.has(idx):
		# Finger slid off a hold button — keep action held until release (sticky).
		get_viewport().set_input_as_handled()
		return
	if idx == _stick_touch_idx:
		_update_stick(pos)
		get_viewport().set_input_as_handled()
	elif idx == _look_touch_idx:
		var delta := pos - _last_look_pos
		_last_look_pos = pos
		if pos.distance_to(_look_start_pos) > 12.0:
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
