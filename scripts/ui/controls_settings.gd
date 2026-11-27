extends Control
## Full-screen Controls settings: PC rebinds, mobile help, sensitivity + touch size/opacity.


signal closed

const InputBindings = preload("res://scripts/systems/input_bindings.gd")

var _listening_action: String = ""
var _status: Label
var _pc_list: VBoxContainer
var _mobile_list: VBoxContainer
var _tab_pc: Button
var _tab_mobile: Button
var _pc_scroll: ScrollContainer
var _mobile_scroll: ScrollContainer
var _bind_buttons: Dictionary = {}  # action -> Button


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	_show_tab("pc")
	set_process_unhandled_input(true)


func _build_ui() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.03, 0.04, 0.94)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(820, 640)
	center.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	panel.add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 6)
	root.custom_minimum_size = Vector2(780, 600)
	margin.add_child(root)

	var title := Label.new()
	title.text = "CONTROLS"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 26)
	root.add_child(title)

	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 8)
	root.add_child(tabs)
	_tab_pc = Button.new()
	_tab_pc.text = "PC Bindings"
	_tab_pc.toggle_mode = true
	_tab_pc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tab_pc.pressed.connect(func(): _show_tab("pc"))
	tabs.add_child(_tab_pc)
	_tab_mobile = Button.new()
	_tab_mobile.text = "Mobile / Touch"
	_tab_mobile.toggle_mode = true
	_tab_mobile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tab_mobile.pressed.connect(func(): _show_tab("mobile"))
	tabs.add_child(_tab_mobile)

	_status = Label.new()
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.modulate = Color(0.9, 0.82, 0.45)
	_status.text = "Click a binding, then press a key. Esc cancels."
	root.add_child(_status)

	_pc_scroll = ScrollContainer.new()
	_pc_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_pc_scroll.custom_minimum_size = Vector2(0, 340)
	root.add_child(_pc_scroll)
	_pc_list = VBoxContainer.new()
	_pc_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_pc_scroll.add_child(_pc_list)

	_mobile_scroll = ScrollContainer.new()
	_mobile_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_mobile_scroll.custom_minimum_size = Vector2(0, 340)
	_mobile_scroll.visible = false
	root.add_child(_mobile_scroll)
	_mobile_list = VBoxContainer.new()
	_mobile_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_mobile_scroll.add_child(_mobile_list)

	_rebuild_pc_list()
	_rebuild_mobile_list()
	_build_sensitivity(root)

	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 10)
	root.add_child(footer)
	var reset := Button.new()
	reset.text = "Reset Defaults"
	reset.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	reset.pressed.connect(_on_reset)
	footer.add_child(reset)
	var back := Button.new()
	back.text = "Back"
	back.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	back.pressed.connect(_on_close)
	footer.add_child(back)


func _build_sensitivity(root: VBoxContainer) -> void:
	var hdr := Label.new()
	hdr.text = "Sensitivity & Touch"
	hdr.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hdr.add_theme_font_size_override("font_size", 16)
	root.add_child(hdr)
	_add_slider(root, "Mouse Look", GameState.mouse_look_sensitivity, 0.25, 2.0, func(v): GameState.set_mouse_look_sensitivity(v))
	_add_slider(root, "Touch Look", GameState.touch_look_sensitivity, 0.25, 2.0, func(v): GameState.set_touch_look_sensitivity(v))
	_add_slider(root, "ADS / Scope", GameState.ads_sensitivity, 0.25, 1.0, func(v): GameState.set_ads_sensitivity(v))
	_add_slider(root, "Touch Button Size", GameState.touch_btn_scale, 0.7, 1.4, func(v): GameState.set_touch_btn_scale(v))
	_add_slider(root, "Touch Button Opacity", GameState.touch_btn_opacity, 0.35, 1.0, func(v): GameState.set_touch_btn_opacity(v))


func _add_slider(parent: Control, label: String, value: float, mn: float, mx: float, on_change: Callable) -> void:
	var row := HBoxContainer.new()
	var lab := Label.new()
	lab.text = label
	lab.custom_minimum_size = Vector2(180, 0)
	row.add_child(lab)
	var sl := HSlider.new()
	sl.min_value = mn
	sl.max_value = mx
	sl.step = 0.05
	sl.value = value
	sl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var val_l := Label.new()
	val_l.custom_minimum_size = Vector2(48, 0)
	val_l.text = "%.2f" % value
	sl.value_changed.connect(func(v):
		val_l.text = "%.2f" % v
		on_change.call(v)
	)
	row.add_child(sl)
	row.add_child(val_l)
	parent.add_child(row)


func _show_tab(which: String) -> void:
	_tab_pc.button_pressed = which == "pc"
	_tab_mobile.button_pressed = which == "mobile"
	_pc_scroll.visible = which == "pc"
	_mobile_scroll.visible = which == "mobile"
	_listening_action = ""
	_status.text = "Click a binding, then press a key. Esc cancels." if which == "pc" else "Contextual buttons appear only when usable."


func _rebuild_pc_list() -> void:
	for c in _pc_list.get_children():
		c.queue_free()
	_bind_buttons.clear()
	var last_group := ""
	for entry in InputBindings.catalog():
		var group := String(entry["group"])
		if group != last_group:
			var g := Label.new()
			g.text = group.to_upper()
			g.modulate = Color(0.88, 0.78, 0.45)
			g.add_theme_font_size_override("font_size", 13)
			_pc_list.add_child(g)
			last_group = group
		var action := String(entry["action"])
		var row := HBoxContainer.new()
		var lab := Label.new()
		lab.text = String(entry["label"])
		lab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(lab)
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(120, 32)
		btn.text = _display_for(action, entry)
		btn.pressed.connect(_start_listen.bind(action, bool(entry.get("mouse", false))))
		row.add_child(btn)
		_bind_buttons[action] = btn
		_pc_list.add_child(row)


func _rebuild_mobile_list() -> void:
	for c in _mobile_list.get_children():
		c.queue_free()
	var intro := Label.new()
	intro.text = "Touch buttons pack into the right-side slots when usable. Long-press Swap opens the weapon wheel."
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_mobile_list.add_child(intro)
	for h in InputBindings.mobile_help():
		var row := HBoxContainer.new()
		var name_l := Label.new()
		name_l.text = String(h["btn"])
		name_l.custom_minimum_size = Vector2(110, 0)
		name_l.modulate = Color(0.85, 0.9, 0.7)
		row.add_child(name_l)
		var desc := Label.new()
		desc.text = String(h["desc"])
		desc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		row.add_child(desc)
		_mobile_list.add_child(row)


func _display_for(action: String, entry: Dictionary) -> String:
	var is_mouse := bool(entry.get("mouse", false))
	var code := int(entry["key"])
	var ov: Dictionary = GameState.keybind_overrides.get(action, {})
	if not ov.is_empty():
		code = int(ov.get("keycode", code))
		is_mouse = bool(ov.get("mouse", is_mouse))
	# Also show alt gadget key T if default Q
	var name := InputBindings.key_name(code, is_mouse)
	if action == "use_gadget" and code == KEY_Q:
		name = "Q / T"
	return name


func _start_listen(action: String, _was_mouse: bool) -> void:
	_listening_action = action
	_status.text = "Press a key for %s… (Esc cancel)" % action
	if _bind_buttons.has(action):
		(_bind_buttons[action] as Button).text = "…"


func _unhandled_input(event: InputEvent) -> void:
	if _listening_action == "":
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var ke := event as InputEventKey
		if ke.physical_keycode == KEY_ESCAPE:
			_listening_action = ""
			_rebuild_pc_list()
			_status.text = "Rebind cancelled."
			get_viewport().set_input_as_handled()
			return
		_commit_bind(_listening_action, int(ke.physical_keycode), false)
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed:
		var mb := event as InputEventMouseButton
		_commit_bind(_listening_action, int(mb.button_index), true)
		get_viewport().set_input_as_handled()


func _commit_bind(action: String, code: int, is_mouse: bool) -> void:
	var conflict := InputBindings.find_conflict(action, code, is_mouse, GameState.keybind_overrides)
	if conflict != "":
		_status.text = "Conflict with %s — pick another key." % conflict
		_listening_action = ""
		_rebuild_pc_list()
		return
	GameState.set_keybind(action, code, is_mouse)
	_listening_action = ""
	_rebuild_pc_list()
	_status.text = "Bound %s → %s" % [action, InputBindings.key_name(code, is_mouse)]


func _on_reset() -> void:
	GameState.reset_keybinds()
	_rebuild_pc_list()
	_status.text = "Bindings reset to defaults."


func _on_close() -> void:
	closed.emit()
	queue_free()
