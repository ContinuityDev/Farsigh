extends RefCounted
## PC keybind catalog, rebind, conflict detect, defaults, persist.



## action -> {label, default_keycode, group}
static func catalog() -> Array:
	return [
		{"action": "move_forward", "label": "Move Forward", "key": KEY_W, "group": "Movement"},
		{"action": "move_back", "label": "Move Back", "key": KEY_S, "group": "Movement"},
		{"action": "move_left", "label": "Move Left", "key": KEY_A, "group": "Movement"},
		{"action": "move_right", "label": "Move Right", "key": KEY_D, "group": "Movement"},
		{"action": "jump", "label": "Jump / Vault", "key": KEY_SPACE, "group": "Movement"},
		{"action": "sprint", "label": "Sprint", "key": KEY_SHIFT, "group": "Movement"},
		{"action": "crouch", "label": "Crouch", "key": KEY_C, "group": "Movement"},
		{"action": "lean_left", "label": "Peek Left", "key": KEY_Z, "group": "Movement"},
		{"action": "lean_right", "label": "Peek Right", "key": KEY_V, "group": "Movement"},
		{"action": "fire", "label": "Fire / Throw / Swing", "key": MOUSE_BUTTON_LEFT, "group": "Combat", "mouse": true},
		{"action": "aim", "label": "Aim / ADS", "key": MOUSE_BUTTON_RIGHT, "group": "Combat", "mouse": true},
		{"action": "reload", "label": "Reload", "key": KEY_R, "group": "Combat"},
		{"action": "melee", "label": "Takedown", "key": KEY_F, "group": "Combat"},
		{"action": "weapon_1", "label": "Weapon Slot 1", "key": KEY_1, "group": "Combat"},
		{"action": "weapon_2", "label": "Weapon Slot 2", "key": KEY_2, "group": "Combat"},
		{"action": "weapon_next", "label": "Swap Slots", "key": KEY_QUOTELEFT, "group": "Combat"},
		{"action": "weapon_wheel", "label": "Weapon Wheel", "key": KEY_TAB, "group": "Combat"},
		{"action": "use_gadget", "label": "Gadget (tap/hold)", "key": KEY_Q, "group": "Combat"},
		{"action": "use_lethal", "label": "Lethal (tap/hold)", "key": KEY_G, "group": "Combat"},
		{"action": "use_support", "label": "Support (tap/hold)", "key": KEY_Y, "group": "Combat"},
		{"action": "inspect_weapon", "label": "Inspect Weapon", "key": KEY_I, "group": "Combat"},
		{"action": "interact", "label": "Use / Revive / Door", "key": KEY_E, "group": "World"},
		{"action": "drop_body", "label": "Drop Body", "key": KEY_X, "group": "World"},
		{"action": "binoculars", "label": "Binoculars", "key": KEY_B, "group": "World"},
		{"action": "scope_zoom", "label": "Adjust Zoom", "key": KEY_N, "group": "World"},
		{"action": "ally_command", "label": "Ally Command", "key": KEY_H, "group": "World"},
		{"action": "pause_menu", "label": "Pause / Settings", "key": KEY_ESCAPE, "group": "System"},
	]


static func mobile_help() -> Array:
	return [
		{"btn": "Fire", "desc": "Shoot / throw / swing the active weapon."},
		{"btn": "Aim", "desc": "Hold or toggle ADS (setting)."},
		{"btn": "Jump", "desc": "Jump or vault low cover."},
		{"btn": "Crouch", "desc": "Toggle crouch for stealth."},
		{"btn": "Sprint", "desc": "Hold to run (no ADS)."},
		{"btn": "Peek L/R", "desc": "Lean around corners."},
		{"btn": "Swap", "desc": "Tap: cycle slot 1↔2. Long-press: weapon wheel."},
		{"btn": "GADGET", "desc": "Shown when you own gadgets. Tap use / hold mini-wheel."},
		{"btn": "LETHAL", "desc": "Shown with lethal ammo. Tap throw / hold mini-wheel."},
		{"btn": "SUPPORT", "desc": "Shown when you own a support charge. Tap uses it (mortar aims first). Long-press opens the wheel."},
		{"btn": "RELOAD", "desc": "Appears when mag is not full and reserve remains."},
		{"btn": "USE", "desc": "Interact, drop body, revive ally."},
		{"btn": "TAKEDOWN", "desc": "Only when a hostile is in melee range."},
		{"btn": "BINOS", "desc": "Tag hostiles; hide while ADS."},
		{"btn": "ZOOM", "desc": "While scoped — cycle 4×/6×/8×."},
		{"btn": "INSPECT", "desc": "Play weapon inspect animation."},
	]


static func key_name(code: int, is_mouse: bool = false) -> String:
	if is_mouse:
		match code:
			MOUSE_BUTTON_LEFT: return "LMB"
			MOUSE_BUTTON_RIGHT: return "RMB"
			MOUSE_BUTTON_MIDDLE: return "MMB"
			_: return "Mouse %d" % code
	if code == KEY_QUOTELEFT:
		return "`"
	return OS.get_keycode_string(code)


static func apply_overrides(overrides: Dictionary) -> void:
	## overrides: action -> {keycode:int, mouse:bool}
	for entry in catalog():
		var action := String(entry["action"])
		if not InputMap.has_action(action):
			continue
		var is_mouse := bool(entry.get("mouse", false))
		var code := int(entry["key"])
		if overrides.has(action):
			var ov: Dictionary = overrides[action]
			code = int(ov.get("keycode", code))
			is_mouse = bool(ov.get("mouse", is_mouse))
		_set_action_primary(action, code, is_mouse)


static func _set_action_primary(action: String, code: int, is_mouse: bool) -> void:
	## Replace keyboard/mouse primary event; keep joypad events.
	var keep: Array = []
	for ev in InputMap.action_get_events(action):
		if ev is InputEventJoypadButton or ev is InputEventJoypadMotion:
			keep.append(ev)
	InputMap.action_erase_events(action)
	for ev2 in keep:
		InputMap.action_add_event(action, ev2)
	if is_mouse:
		var mb := InputEventMouseButton.new()
		mb.button_index = code as MouseButton
		InputMap.action_add_event(action, mb)
	else:
		var kb := InputEventKey.new()
		kb.physical_keycode = code as Key
		InputMap.action_add_event(action, kb)


static func find_conflict(action: String, code: int, is_mouse: bool, overrides: Dictionary) -> String:
	for entry in catalog():
		var other := String(entry["action"])
		if other == action:
			continue
		var o_code := int(entry["key"])
		var o_mouse := bool(entry.get("mouse", false))
		if overrides.has(other):
			o_code = int(overrides[other].get("keycode", o_code))
			o_mouse = bool(overrides[other].get("mouse", o_mouse))
		if o_code == code and o_mouse == is_mouse:
			return String(entry["label"])
	return ""


static func defaults_dict() -> Dictionary:
	var d := {}
	for entry in catalog():
		d[String(entry["action"])] = {
			"keycode": int(entry["key"]),
			"mouse": bool(entry.get("mouse", false)),
		}
	return d
