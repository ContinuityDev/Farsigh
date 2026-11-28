extends CanvasLayer
## Crosshair, ammo, detection meter, status messages, pause overlay.

const WeaponWheelScript = preload("res://scripts/ui/weapon_wheel.gd")
const ItemMiniWheelScript = preload("res://scripts/ui/item_mini_wheel.gd")

@onready var crosshair: Control = $Root/Crosshair
@onready var ammo_label: Label = $Root/AmmoLabel
@onready var weapon_label: Label = $Root/WeaponLabel
@onready var detection_bar: ProgressBar = $Root/DetectionBar
@onready var detection_label: Label = $Root/DetectionLabel
@onready var status_label: Label = $Root/StatusLabel
@onready var guards_label: Label = $Root/GuardsLabel
@onready var liberated_banner: Label = $Root/LiberatedBanner
@onready var pause_panel: Control = $Root/PausePanel
@onready var rocks_label: Label = $Root/RocksLabel
@onready var touch_controls: Control = $TouchControls

var _status_timer: float = 0.0
var _detection_display: float = 0.0
var _capture_hint: Label
var _scope_overlay: Control
var _clear_countdown_label: Label
var _results_panel: Control
var _streak_row: HBoxContainer
var _streak_buttons: Array = []
var _currency_label: Label
var _scope_zoom_label: Label
var _hidden_label: Label
var _weapon_wheel: Control
var _item_wheel: Control
var _gadget_lethal_label: Label
var _support_card: PanelContainer
var _support_label: Label
var _armour_bar: ProgressBar
var _ally_label: Label


func _ready() -> void:
	add_to_group("hud")
	process_mode = Node.PROCESS_MODE_ALWAYS
	pause_panel.visible = false
	liberated_banner.visible = false
	status_label.text = ""
	detection_bar.value = 0
	# Per-guard ?/! meters replace the global detection bar (kept for soft max hint only).
	if is_instance_valid(detection_bar):
		detection_bar.modulate.a = 0.35
	if is_instance_valid(detection_label):
		detection_label.text = "AWARENESS"
		detection_label.modulate.a = 0.55
	_ensure_capture_hint()
	_ensure_scope_overlay()
	_ensure_settings_buttons()
	_ensure_clear_ui()
	_ensure_streak_buttons()
	_ensure_currency_label()
	_ensure_hidden_indicator()
	_ensure_weapon_wheels()
	_ensure_gadget_lethal_hud()
	_ensure_support_card()
	_ensure_vitals_bars()
	_ensure_ally_label()
	if touch_controls:
		touch_controls.visible = TouchInput.is_touch_ui_desired()
	set_click_to_capture_hint(TouchInput.is_web_desktop())
	var player := get_tree().get_first_node_in_group("player")
	if player:
		_bind_player(player)
	else:
		call_deferred("_late_bind")


func _ensure_capture_hint() -> void:
	_capture_hint = get_node_or_null("Root/CaptureHint") as Label
	if _capture_hint:
		return
	_capture_hint = Label.new()
	_capture_hint.name = "CaptureHint"
	_capture_hint.text = "Click to capture mouse"
	_capture_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_capture_hint.add_theme_font_size_override("font_size", 18)
	_capture_hint.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_capture_hint.offset_left = -180
	_capture_hint.offset_right = 180
	_capture_hint.offset_top = -80
	_capture_hint.offset_bottom = -40
	_capture_hint.visible = false
	$Root.add_child(_capture_hint)


func set_click_to_capture_hint(show: bool) -> void:
	_ensure_capture_hint()
	if _capture_hint:
		_capture_hint.visible = show


func _ensure_scope_overlay() -> void:
	_scope_overlay = get_node_or_null("Root/ScopeOverlay") as Control
	if _scope_overlay:
		return
	_scope_overlay = Control.new()
	_scope_overlay.name = "ScopeOverlay"
	_scope_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_scope_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_scope_overlay.visible = false
	# Soft circular-ish vignette ( Compatibility-safe ColorRects — no shader required).
	# Outer frame stays dark; the open center must never be covered (that looked like a black sight).
	for spec in [
		[0.0, 0.0, 1.0, 0.12],
		[0.0, 0.88, 1.0, 1.0],
		[0.0, 0.12, 0.18, 0.88],
		[0.82, 0.12, 1.0, 0.88],
	]:
		var bar := ColorRect.new()
		bar.color = Color(0.01, 0.015, 0.02, 0.94)
		bar.anchor_left = spec[0]
		bar.anchor_top = spec[1]
		bar.anchor_right = spec[2]
		bar.anchor_bottom = spec[3]
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_scope_overlay.add_child(bar)
	# Corner fill to round the aperture visually without covering the lens center
	for corner in [[0.18, 0.12, 0.28, 0.22], [0.72, 0.12, 0.82, 0.22], [0.18, 0.78, 0.28, 0.88], [0.72, 0.78, 0.82, 0.88]]:
		var c := ColorRect.new()
		c.color = Color(0.01, 0.015, 0.02, 0.55)
		c.anchor_left = corner[0]
		c.anchor_top = corner[1]
		c.anchor_right = corner[2]
		c.anchor_bottom = corner[3]
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_scope_overlay.add_child(c)
	var hline := ColorRect.new()
	hline.color = Color(0.1, 0.1, 0.1, 0.9)
	hline.anchor_left = 0.22
	hline.anchor_right = 0.78
	hline.anchor_top = 0.5
	hline.anchor_bottom = 0.5
	hline.offset_top = -1.0
	hline.offset_bottom = 1.0
	hline.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_scope_overlay.add_child(hline)
	var vline := ColorRect.new()
	vline.color = Color(0.1, 0.1, 0.1, 0.9)
	vline.anchor_left = 0.5
	vline.anchor_right = 0.5
	vline.anchor_top = 0.14
	vline.anchor_bottom = 0.86
	vline.offset_left = -1.0
	vline.offset_right = 1.0
	vline.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_scope_overlay.add_child(vline)
	var dot := ColorRect.new()
	dot.color = Color(1.0, 0.2, 0.15, 0.95)
	dot.anchor_left = 0.5
	dot.anchor_right = 0.5
	dot.anchor_top = 0.5
	dot.anchor_bottom = 0.5
	dot.offset_left = -2.0
	dot.offset_right = 2.0
	dot.offset_top = -2.0
	dot.offset_bottom = 2.0
	dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_scope_overlay.add_child(dot)
	_scope_zoom_label = Label.new()
	_scope_zoom_label.name = "ScopeZoomLabel"
	_scope_zoom_label.text = "4x"
	_scope_zoom_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_scope_zoom_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_scope_zoom_label.offset_left = -40
	_scope_zoom_label.offset_right = 40
	_scope_zoom_label.offset_top = -72
	_scope_zoom_label.offset_bottom = -40
	_scope_zoom_label.add_theme_font_size_override("font_size", 18)
	_scope_zoom_label.add_theme_color_override("font_color", Color(0.85, 0.9, 0.95, 0.85))
	_scope_zoom_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_scope_overlay.add_child(_scope_zoom_label)
	$Root.add_child(_scope_overlay)
	$Root.move_child(_scope_overlay, 0)


func set_scope_overlay(on: bool) -> void:
	if is_instance_valid(_scope_overlay):
		_scope_overlay.visible = on
	if on and is_instance_valid(crosshair):
		crosshair.visible = false


func set_scope_zoom_label(mult: float) -> void:
	if is_instance_valid(_scope_zoom_label):
		_scope_zoom_label.text = "%dx" % int(round(mult))


func set_ads_crosshair(hide: bool) -> void:
	## Hide the hipfire crosshair whenever the player is aiming (iron/optic/scope).
	if is_instance_valid(crosshair):
		var scoped := is_instance_valid(_scope_overlay) and _scope_overlay.visible
		crosshair.visible = not hide and not scoped


func _late_bind() -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player:
		_bind_player(player)


func _bind_player(player: Node) -> void:
	if player.has_signal("detection_changed"):
		player.detection_changed.connect(_on_detection)
	if player.has_node("WeaponManager"):
		var wm = player.get_node("WeaponManager")
		if wm.has_signal("ammo_changed"):
			wm.ammo_changed.connect(_on_ammo)
			wm._emit_ammo()


func _process(delta: float) -> void:
	if _status_timer > 0.0:
		_status_timer -= delta
		if _status_timer <= 0.0 and is_instance_valid(status_label):
			status_label.text = ""
	# Smooth decay of detection meter when not updated
	_detection_display = move_toward(_detection_display, GameState.last_detection, delta * 2.0)
	if is_instance_valid(detection_bar):
		detection_bar.value = _detection_display * 100.0
		detection_bar.modulate = Color(0.3, 0.9, 0.4).lerp(Color(0.95, 0.2, 0.15), _detection_display)
	var player := get_tree().get_first_node_in_group("player")
	if is_instance_valid(player) and is_instance_valid(rocks_label):
		var hp_val := int(player.get("hp"))
		var max_hp := int(player.get("max_hp"))
		var arm := int(player.get("armour"))
		var stance := "CROUCH" if bool(player.get("is_crouching")) else "STAND"
		rocks_label.text = "HP %d/%d  ARM %d  |  %s" % [hp_val, max_hp if max_hp > 0 else 160, arm, stance]
		refresh_vitals()
		refresh_gadget_lethal_hud()
		refresh_ally_hud()


func _on_detection(value: float) -> void:
	_detection_display = maxf(_detection_display, value)
	GameState.last_detection = value


func _on_ammo(mag: int, reserve: int, weapon_name: String) -> void:
	ammo_label.text = "%d / %d" % [mag, reserve]
	weapon_label.text = weapon_name


func set_guard_count(n: int) -> void:
	guards_label.text = "Hostiles: %d" % n


func show_status(text: String, duration: float = 2.5) -> void:
	status_label.text = text
	_status_timer = duration


func show_liberation(name: String) -> void:
	show_status("%s is free" % name, 6.0)
	set_liberated_banner(true)
	_play_liberation_fanfare()


func _play_liberation_fanfare() -> void:
	var player := get_node_or_null("Fanfare") as AudioStreamPlayer
	if player == null:
		player = AudioStreamPlayer.new()
		player.name = "Fanfare"
		add_child(player)
	if player.stream == null:
		player.stream = _liberation_tone()
	player.play()


func _liberation_tone() -> AudioStreamWAV:
	## Short C-major sting. Generated so the web build does not ship an audio file.
	var rate := 22050
	var count := int(rate * 1.5)
	var data := PackedByteArray()
	data.resize(count * 2)
	var notes := PackedFloat32Array([523.25, 659.25, 783.99, 1046.5])
	for i in count:
		var t := float(i) / float(rate)
		var env := clampf(t / 0.04, 0.0, 1.0) * clampf((1.5 - t) / 0.7, 0.0, 1.0)
		var s := 0.0
		for k in notes.size():
			if t > float(k) * 0.11:
				s += sin(TAU * notes[k] * t)
		s = clampf(s / float(notes.size()) * env * 0.4, -1.0, 1.0)
		data.encode_s16(i * 2, int(s * 28000.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = rate
	wav.stereo = false
	wav.data = data
	return wav


func set_liberated_banner(on: bool) -> void:
	liberated_banner.visible = on
	if on:
		liberated_banner.text = "OUTPOST LIBERATED"
		liberated_banner.add_theme_color_override("font_color", Color(0.96, 0.93, 0.84))
		liberated_banner.add_theme_font_size_override("font_size", 40)


func _ensure_clear_ui() -> void:
	_clear_countdown_label = get_node_or_null("Root/ClearCountdown") as Label
	if _clear_countdown_label == null:
		_clear_countdown_label = Label.new()
		_clear_countdown_label.name = "ClearCountdown"
		_clear_countdown_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_clear_countdown_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_clear_countdown_label.add_theme_font_size_override("font_size", 36)
		_clear_countdown_label.set_anchors_preset(Control.PRESET_CENTER)
		_clear_countdown_label.offset_left = -280
		_clear_countdown_label.offset_right = 280
		_clear_countdown_label.offset_top = -40
		_clear_countdown_label.offset_bottom = 40
		_clear_countdown_label.modulate = Color(0.95, 0.88, 0.45)
		_clear_countdown_label.visible = false
		$Root.add_child(_clear_countdown_label)
	_results_panel = get_node_or_null("Root/ClearResults") as Control
	if _results_panel == null:
		_results_panel = Control.new()
		_results_panel.name = "ClearResults"
		_results_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
		_results_panel.mouse_filter = Control.MOUSE_FILTER_STOP
		_results_panel.visible = false
		var dim := ColorRect.new()
		dim.name = "Dim"
		dim.color = Color(0.02, 0.04, 0.03, 0.78)
		dim.set_anchors_preset(Control.PRESET_FULL_RECT)
		dim.mouse_filter = Control.MOUSE_FILTER_STOP
		_results_panel.add_child(dim)
		var panel := PanelContainer.new()
		panel.name = "Panel"
		panel.set_anchors_preset(Control.PRESET_CENTER)
		panel.offset_left = -260
		panel.offset_right = 260
		panel.offset_top = -220
		panel.offset_bottom = 220
		_results_panel.add_child(panel)
		var margin := MarginContainer.new()
		margin.add_theme_constant_override("margin_left", 18)
		margin.add_theme_constant_override("margin_right", 18)
		margin.add_theme_constant_override("margin_top", 16)
		margin.add_theme_constant_override("margin_bottom", 16)
		panel.add_child(margin)
		var vbox := VBoxContainer.new()
		vbox.name = "VBox"
		vbox.add_theme_constant_override("separation", 8)
		margin.add_child(vbox)
		var title := Label.new()
		title.name = "Title"
		title.add_theme_font_size_override("font_size", 26)
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		title.text = "COMPOUND BEATEN"
		vbox.add_child(title)
		var lines := RichTextLabel.new()
		lines.name = "Lines"
		lines.bbcode_enabled = true
		lines.fit_content = true
		lines.scroll_active = false
		lines.custom_minimum_size = Vector2(0, 180)
		lines.add_theme_font_size_override("normal_font_size", 16)
		vbox.add_child(lines)
		var total := Label.new()
		total.name = "Total"
		total.add_theme_font_size_override("font_size", 22)
		total.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		total.modulate = Color(0.95, 0.82, 0.35)
		vbox.add_child(total)
		var actions := HBoxContainer.new()
		actions.name = "Actions"
		actions.alignment = BoxContainer.ALIGNMENT_CENTER
		actions.add_theme_constant_override("separation", 12)
		vbox.add_child(actions)
		var shop_btn := Button.new()
		shop_btn.name = "ShopBtn"
		shop_btn.text = "Open Shop"
		shop_btn.custom_minimum_size = Vector2(140, 48)
		shop_btn.pressed.connect(_on_results_shop)
		actions.add_child(shop_btn)
		var map_btn := Button.new()
		map_btn.name = "MapBtn"
		map_btn.text = "Outpost Select"
		map_btn.custom_minimum_size = Vector2(160, 48)
		map_btn.pressed.connect(_on_results_map)
		actions.add_child(map_btn)
		$Root.add_child(_results_panel)


func show_clear_countdown(seconds: int) -> void:
	_ensure_clear_ui()
	if is_instance_valid(_results_panel):
		_results_panel.visible = false
	_clear_countdown_label.visible = true
	_clear_countdown_label.text = "Compound clearing… %d" % seconds
	show_status("Compound clearing… %d" % seconds, 1.05)


func show_clear_results(outpost_name: String, payout_info: Dictionary, was_replay: bool, balance: int) -> void:
	_ensure_clear_ui()
	if is_instance_valid(_clear_countdown_label):
		_clear_countdown_label.visible = false
	set_liberated_banner(true)
	liberated_banner.text = "BEATEN" if not was_replay else "REPLAY CLEAR"
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_results_panel.visible = true
	var title := _results_panel.get_node("Panel/MarginContainer/VBox/Title") as Label
	if title == null:
		title = _results_panel.find_child("Title", true, false) as Label
	if title:
		title.text = ("REPLAY CLEAR — %s" if was_replay else "COMPOUND BEATEN — %s") % outpost_name
	var lines_lbl := _results_panel.find_child("Lines", true, false) as RichTextLabel
	var bb := ""
	for line in payout_info.get("lines", []):
		var amt := int(line.get("amount", 0))
		var sign := "+" if amt >= 0 else ""
		bb += "%s  [color=#e8c84a]%s%d[/color]\n" % [String(line.get("label", "")), sign, amt]
	if lines_lbl:
		lines_lbl.text = bb
	var total_lbl := _results_panel.find_child("Total", true, false) as Label
	if total_lbl:
		total_lbl.text = "Earned $%d   ·   Wallet $%d" % [int(payout_info.get("total", 0)), balance]
	_refresh_currency()


func _on_results_shop() -> void:
	GameState.is_paused = false
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().change_scene_to_file("res://scenes/ui/shop.tscn")


func _on_results_map() -> void:
	GameState.is_paused = false
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().change_scene_to_file("res://scenes/ui/map_select.tscn")


func _ensure_currency_label() -> void:
	_currency_label = get_node_or_null("Root/CurrencyLabel") as Label
	if _currency_label == null:
		_currency_label = Label.new()
		_currency_label.name = "CurrencyLabel"
		_currency_label.add_theme_font_size_override("font_size", 16)
		_currency_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
		_currency_label.offset_left = -180
		_currency_label.offset_right = -16
		_currency_label.offset_top = 12
		_currency_label.offset_bottom = 36
		_currency_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		_currency_label.modulate = Color(0.95, 0.82, 0.35)
		$Root.add_child(_currency_label)
	_refresh_currency()


func _refresh_currency() -> void:
	if is_instance_valid(_currency_label):
		_currency_label.text = "$%d Hope" % GameState.currency


func _ensure_streak_buttons() -> void:
	_streak_row = get_node_or_null("Root/StreakRow") as HBoxContainer
	if _streak_row == null:
		_streak_row = HBoxContainer.new()
		_streak_row.name = "StreakRow"
		# Top-center — clear of move stick (bottom-left) and fire cluster (bottom-right)
		_streak_row.set_anchors_preset(Control.PRESET_CENTER_TOP)
		_streak_row.offset_left = -200
		_streak_row.offset_right = 200
		_streak_row.offset_top = 52
		_streak_row.offset_bottom = 108
		_streak_row.add_theme_constant_override("separation", 8)
		_streak_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		$Root.add_child(_streak_row)
	_streak_buttons.clear()
	for c in _streak_row.get_children():
		c.queue_free()
	for i in range(3):
		var b := Button.new()
		b.name = "Streak%d" % i
		b.custom_minimum_size = Vector2(120, 52)
		b.add_theme_font_size_override("font_size", 13)
		b.text = "—"
		b.disabled = true
		# Visual hit target — activation via ScreenTouch in _input (mobile-safe)
		b.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.focus_mode = Control.FOCUS_NONE
		b.pressed.connect(_on_streak_pressed.bind(i))
		_streak_row.add_child(b)
		_streak_buttons.append(b)
	refresh_streak_buttons()


func _input(event: InputEvent) -> void:
	## Slot buttons: touch taps, and mouse clicks when the pointer is not captured.
	if GameState.is_paused or _streak_buttons.is_empty():
		return
	var pos := Vector2(-9999, -9999)
	if event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed:
		pos = (event as InputEventScreenTouch).position
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if not mb.pressed or mb.button_index != MOUSE_BUTTON_LEFT:
			return
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			return
		pos = mb.position
	else:
		return
	for i in range(_streak_buttons.size()):
		var btn: Button = _streak_buttons[i]
		if not is_instance_valid(btn) or btn.disabled or not btn.visible:
			continue
		if btn.get_global_rect().has_point(pos):
			_on_streak_pressed(i)
			get_viewport().set_input_as_handled()
			return


func refresh_streak_buttons() -> void:
	if _streak_buttons.is_empty():
		refresh_support_card()
		return
	var sm := get_tree().get_first_node_in_group("streak_manager")
	var any_visible := false
	for i in range(3):
		var sid := ""
		if i < GameState.equipped_streaks.size():
			sid = String(GameState.equipped_streaks[i])
		var btn: Button = _streak_buttons[i]
		# Hide empty slots and spent charges. Owned-but-empty is not a button.
		if sid == "" or GameState.get_streak_charges(sid) <= 0:
			btn.visible = false
			btn.disabled = true
			continue
		btn.visible = true
		any_visible = true
		var info: Dictionary = StreakCatalog.by_id(sid)
		var charges := GameState.get_streak_charges(sid)
		var ready := charges > 0
		if sm and sm.has_method("can_activate"):
			ready = bool(sm.can_activate(i))
		var selected := sid == GameState.ensure_selected_streak()
		btn.text = "%s%s\nx%d" % ["▸ " if selected else "", String(info.get("name", sid)), charges]
		btn.disabled = not ready
		btn.modulate = Color(0.95, 0.78, 0.35) if selected else (Color(0.55, 0.95, 0.55) if ready else Color(0.85, 0.85, 0.85))
	if is_instance_valid(_streak_row):
		_streak_row.visible = any_visible
	refresh_support_card()


func _on_streak_pressed(slot: int) -> void:
	var sm := get_tree().get_first_node_in_group("streak_manager")
	if sm and sm.has_method("try_activate"):
		sm.try_activate(slot)
		refresh_streak_buttons()


func set_paused(paused: bool) -> void:
	pause_panel.visible = paused
	if paused:
		_refresh_settings_ui()


func _ensure_hidden_indicator() -> void:
	_hidden_label = get_node_or_null("Root/HiddenLabel") as Label
	if _hidden_label:
		return
	_hidden_label = Label.new()
	_hidden_label.name = "HiddenLabel"
	_hidden_label.text = "HIDDEN"
	_hidden_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hidden_label.add_theme_font_size_override("font_size", 20)
	_hidden_label.add_theme_color_override("font_color", Color(0.45, 0.95, 0.55))
	_hidden_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_hidden_label.offset_left = -80
	_hidden_label.offset_right = 80
	_hidden_label.offset_top = 52
	_hidden_label.offset_bottom = 80
	_hidden_label.visible = false
	$Root.add_child(_hidden_label)


func set_hidden_indicator(fully_hidden: bool, in_foliage: bool = false) -> void:
	_ensure_hidden_indicator()
	if not is_instance_valid(_hidden_label):
		return
	if fully_hidden:
		_hidden_label.text = "HIDDEN"
		_hidden_label.add_theme_color_override("font_color", Color(0.4, 0.95, 0.55))
		_hidden_label.visible = true
	elif in_foliage:
		_hidden_label.text = "IN COVER"
		_hidden_label.add_theme_color_override("font_color", Color(0.75, 0.9, 0.45))
		_hidden_label.visible = true
	else:
		_hidden_label.visible = false


func _widen_pause_panel() -> void:
	var vbox := pause_panel.get_node_or_null("PauseVBox") as VBoxContainer
	if vbox == null:
		return
	vbox.offset_left = -220.0
	vbox.offset_right = 220.0
	vbox.offset_top = -280.0
	vbox.offset_bottom = 280.0
	vbox.add_theme_constant_override("separation", 10)


func _refresh_settings_ui() -> void:
	_sync_slider_row("MouseLookRow", GameState.mouse_look_sensitivity, 0.25, 2.0)
	_sync_slider_row("TouchLookRow", GameState.touch_look_sensitivity, 0.25, 2.0)
	_sync_slider_row("AdsSensRow", GameState.ads_sensitivity, 0.25, 1.0)
	_sync_slider_row("Scope4xRow", GameState.scope_sens_4x, 0.25, 1.5)
	_sync_slider_row("Scope6xRow", GameState.scope_sens_6x, 0.25, 1.5)
	_sync_slider_row("Scope8xRow", GameState.scope_sens_8x, 0.25, 1.5)
	var inv := pause_panel.get_node_or_null("PauseVBox/InvertYBtn") as Button
	if is_instance_valid(inv):
		inv.text = "Invert Y: %s" % ("On" if GameState.invert_y else "Off")
	var qual_btn := pause_panel.get_node_or_null("PauseVBox/QualityBtn") as Button
	if is_instance_valid(qual_btn):
		var qname := GraphicsQuality.level_name() if GraphicsQuality else "High"
		qual_btn.text = "Graphics Quality: %s" % qname
	var aim_btn := pause_panel.get_node_or_null("PauseVBox/TouchAimBtn") as Button
	if is_instance_valid(aim_btn):
		aim_btn.text = "Touch Aim: %s" % ("Toggle" if GameState.touch_aim_toggle else "Hold")
	var tap_btn := pause_panel.get_node_or_null("PauseVBox/TapToFireBtn") as Button
	if is_instance_valid(tap_btn):
		tap_btn.text = "Tap-to-Fire: %s" % ("On" if GameState.tap_to_fire else "Off")
	var fs_btn := pause_panel.get_node_or_null("PauseVBox/FullscreenBtn") as Button
	if is_instance_valid(fs_btn):
		var on := WebDisplay.is_fullscreen() if WebDisplay else false
		fs_btn.text = "Fullscreen: %s" % ("On" if on else "Off")
	var day_btn := pause_panel.get_node_or_null("PauseVBox/DayStartBtn") as Button
	if is_instance_valid(day_btn):
		var h := GameState.day_start_hour
		var label := "Afternoon"
		if h < 8.0:
			label = "Dawn"
		elif h < 15.0:
			label = "Noon"
		elif h < 20.0:
			label = "Dusk"
		else:
			label = "Night"
		day_btn.text = "Start Time: %s (%.0f:00)" % [label, h]
	var cyc_btn := pause_panel.get_node_or_null("PauseVBox/DayCycleBtn") as Button
	if is_instance_valid(cyc_btn):
		var cps := GameState.day_cycle_hours_per_second
		var mins := 999 if cps <= 0.0001 else int(round(24.0 / cps / 60.0))
		if cps <= 0.0001:
			cyc_btn.text = "Day Cycle: Frozen"
		else:
			cyc_btn.text = "Day Cycle: ~%d min" % mins


func _sync_slider_row(row_name: String, value: float, min_v: float, max_v: float) -> void:
	var row := pause_panel.get_node_or_null("PauseVBox/%s" % row_name) as Control
	if row == null:
		return
	var slider := row.get_node_or_null("Slider") as HSlider
	var val_lbl := row.get_node_or_null("Value") as Label
	if val_lbl == null and row.get_child_count() > 0:
		var header = row.get_child(0)
		if header is HBoxContainer and header.get_child_count() > 1:
			val_lbl = header.get_child(1) as Label
	if is_instance_valid(slider):
		slider.min_value = min_v
		slider.max_value = max_v
		slider.set_value_no_signal(value)
	if is_instance_valid(val_lbl):
		val_lbl.text = "%d%%" % int(round(value * 100.0))


func _make_slider_row(parent: VBoxContainer, row_name: String, title: String, value: float, min_v: float, max_v: float, setter: Callable) -> void:
	if parent.get_node_or_null(row_name) != null:
		return
	var row := VBoxContainer.new()
	row.name = row_name
	row.add_theme_constant_override("separation", 2)
	var header := HBoxContainer.new()
	header.name = "Header"
	var title_lbl := Label.new()
	title_lbl.name = "Title"
	title_lbl.text = title
	title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_lbl.add_theme_font_size_override("font_size", 14)
	var val_lbl := Label.new()
	val_lbl.name = "Value"
	val_lbl.text = "%d%%" % int(round(value * 100.0))
	val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	val_lbl.custom_minimum_size = Vector2(52, 0)
	val_lbl.add_theme_font_size_override("font_size", 14)
	val_lbl.add_theme_color_override("font_color", Color(0.75, 0.9, 1.0))
	header.add_child(title_lbl)
	header.add_child(val_lbl)
	row.add_child(header)
	var slider := HSlider.new()
	slider.name = "Slider"
	slider.min_value = min_v
	slider.max_value = max_v
	slider.step = 0.01
	slider.value = value
	slider.custom_minimum_size = Vector2(0, 28)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.value_changed.connect(func(v: float):
		setter.call(v)
		val_lbl.text = "%d%%" % int(round(v * 100.0))
	)
	row.add_child(slider)
	parent.add_child(row)
	# Insert after PauseTitle (index 1) so settings sit above Resume
	var insert_at := mini(parent.get_child_count() - 1, 1)
	# Keep stacking: find last Sens* / Invert / Quality block
	for i in range(parent.get_child_count()):
		var n := parent.get_child(i)
		if String(n.name).begins_with("MouseLook") or String(n.name).begins_with("TouchLook") \
				or String(n.name).begins_with("AdsSens") or String(n.name).begins_with("Scope") \
				or String(n.name) == "SensHeader" or String(n.name) == "InvertYBtn" \
				or String(n.name) == "QualityBtn" or String(n.name) == "TouchAimBtn" \
				or String(n.name) == "TapToFireBtn" or String(n.name) == "FullscreenBtn":
			insert_at = i + 1
	parent.move_child(row, insert_at)


func _ensure_settings_buttons() -> void:
	var vbox := pause_panel.get_node_or_null("PauseVBox") as VBoxContainer
	if vbox == null:
		return
	_widen_pause_panel()
	# Remove legacy cycle buttons if present from older builds
	for legacy in ["AdsSensBtn", "LookSensBtn"]:
		var old := vbox.get_node_or_null(legacy)
		if old:
			old.queue_free()
	if vbox.get_node_or_null("SensHeader") == null:
		var hdr := Label.new()
		hdr.name = "SensHeader"
		hdr.text = "Sensitivity"
		hdr.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		hdr.add_theme_font_size_override("font_size", 18)
		vbox.add_child(hdr)
		vbox.move_child(hdr, 1)
	_make_slider_row(vbox, "MouseLookRow", "Mouse Look", GameState.mouse_look_sensitivity, 0.25, 2.0, Callable(GameState, "set_mouse_look_sensitivity"))
	_make_slider_row(vbox, "TouchLookRow", "Touch Look", GameState.touch_look_sensitivity, 0.25, 2.0, Callable(GameState, "set_touch_look_sensitivity"))
	_make_slider_row(vbox, "AdsSensRow", "ADS / Scope", GameState.ads_sensitivity, 0.25, 1.0, Callable(GameState, "set_ads_sensitivity"))
	_make_slider_row(vbox, "Scope4xRow", "Scope 4× Mult", GameState.scope_sens_4x, 0.25, 1.5, Callable(GameState, "set_scope_sens_4x"))
	_make_slider_row(vbox, "Scope6xRow", "Scope 6× Mult", GameState.scope_sens_6x, 0.25, 1.5, Callable(GameState, "set_scope_sens_6x"))
	_make_slider_row(vbox, "Scope8xRow", "Scope 8× Mult", GameState.scope_sens_8x, 0.25, 1.5, Callable(GameState, "set_scope_sens_8x"))
	if vbox.get_node_or_null("InvertYBtn") == null:
		var inv := Button.new()
		inv.name = "InvertYBtn"
		inv.custom_minimum_size = Vector2(0, 36)
		inv.pressed.connect(_on_invert_y_pressed)
		vbox.add_child(inv)
		vbox.move_child(inv, _settings_insert_index(vbox))
	if vbox.get_node_or_null("QualityBtn") == null:
		var qual := Button.new()
		qual.name = "QualityBtn"
		qual.custom_minimum_size = Vector2(0, 36)
		qual.pressed.connect(_on_quality_pressed)
		vbox.add_child(qual)
		vbox.move_child(qual, _settings_insert_index(vbox))
	if vbox.get_node_or_null("TouchAimBtn") == null:
		var aim := Button.new()
		aim.name = "TouchAimBtn"
		aim.custom_minimum_size = Vector2(0, 36)
		aim.pressed.connect(_on_touch_aim_pressed)
		vbox.add_child(aim)
		vbox.move_child(aim, _settings_insert_index(vbox))
	if vbox.get_node_or_null("TapToFireBtn") == null:
		var tap := Button.new()
		tap.name = "TapToFireBtn"
		tap.custom_minimum_size = Vector2(0, 36)
		tap.pressed.connect(_on_tap_to_fire_pressed)
		vbox.add_child(tap)
		vbox.move_child(tap, _settings_insert_index(vbox))
	if vbox.get_node_or_null("FullscreenBtn") == null:
		var fs := Button.new()
		fs.name = "FullscreenBtn"
		fs.custom_minimum_size = Vector2(0, 36)
		fs.pressed.connect(_on_fullscreen_pressed)
		vbox.add_child(fs)
		vbox.move_child(fs, _settings_insert_index(vbox))
	if vbox.get_node_or_null("ControlsBtn") == null:
		var ctrl := Button.new()
		ctrl.name = "ControlsBtn"
		ctrl.text = "Controls…"
		ctrl.custom_minimum_size = Vector2(0, 36)
		ctrl.pressed.connect(_on_controls_pressed)
		vbox.add_child(ctrl)
		vbox.move_child(ctrl, _settings_insert_index(vbox))
	if vbox.get_node_or_null("DayStartBtn") == null:
		var dayb := Button.new()
		dayb.name = "DayStartBtn"
		dayb.custom_minimum_size = Vector2(0, 36)
		dayb.pressed.connect(_on_day_start_pressed)
		vbox.add_child(dayb)
		vbox.move_child(dayb, _settings_insert_index(vbox))
	if vbox.get_node_or_null("DayCycleBtn") == null:
		var cyc := Button.new()
		cyc.name = "DayCycleBtn"
		cyc.custom_minimum_size = Vector2(0, 36)
		cyc.pressed.connect(_on_day_cycle_pressed)
		vbox.add_child(cyc)
		vbox.move_child(cyc, _settings_insert_index(vbox))
	_refresh_settings_ui()


func _on_day_start_pressed() -> void:
	GameState.cycle_day_start_preset()
	_refresh_settings_ui()


func _on_day_cycle_pressed() -> void:
	## Cycle length presets: frozen / slow (16min) / default (8min) / fast (3min)
	var presets := [0.0, 24.0 / 960.0, 24.0 / 480.0, 24.0 / 180.0]
	var best_i := 0
	var best_d := 99.0
	for i in range(presets.size()):
		var d := absf(presets[i] - GameState.day_cycle_hours_per_second)
		if d < best_d:
			best_d = d
			best_i = i
	GameState.set_day_cycle_hours_per_second(presets[(best_i + 1) % presets.size()])
	_refresh_settings_ui()


func _on_controls_pressed() -> void:
	if get_node_or_null("ControlsSettings") != null:
		return
	var panel = load("res://scripts/ui/controls_settings.gd").new()
	panel.name = "ControlsSettings"
	panel.closed.connect(func(): pass)
	add_child(panel)


func _settings_insert_index(vbox: VBoxContainer) -> int:
	## Place new settings controls just above ResumeBtn.
	var resume := vbox.get_node_or_null("ResumeBtn")
	if resume:
		return resume.get_index()
	return mini(vbox.get_child_count() - 1, 1)


func _on_invert_y_pressed() -> void:
	GameState.set_invert_y(not GameState.invert_y)
	_refresh_settings_ui()
	show_status("Invert Y %s" % ("on" if GameState.invert_y else "off"), 1.2)


func _on_quality_pressed() -> void:
	var lvl := 0
	if GraphicsQuality:
		lvl = GraphicsQuality.cycle()
		GameState.set_graphics_quality(lvl)
	_refresh_settings_ui()
	var qname := GraphicsQuality.level_name() if GraphicsQuality else "High"
	show_status("Graphics Quality: %s (rebuild view / reload outpost for all effects)" % qname, 2.2)


func _on_touch_aim_pressed() -> void:
	GameState.set_touch_aim_toggle(not GameState.touch_aim_toggle)
	_refresh_settings_ui()
	show_status("Touch Aim set to %s" % ("Toggle" if GameState.touch_aim_toggle else "Hold"), 1.6)


func _on_tap_to_fire_pressed() -> void:
	GameState.set_tap_to_fire(not GameState.tap_to_fire)
	_refresh_settings_ui()
	show_status("Tap-to-Fire %s (look-pad tap)" % ("enabled" if GameState.tap_to_fire else "disabled"), 1.8)


func _on_fullscreen_pressed() -> void:
	if WebDisplay:
		WebDisplay.toggle_fullscreen()
	_refresh_settings_ui()
	show_status("Fullscreen %s" % ("on" if WebDisplay and WebDisplay.is_fullscreen() else "off"), 1.2)


func _on_resume_pressed() -> void:
	GameState.is_paused = false
	get_tree().paused = false
	pause_panel.visible = false
	if not TouchInput.is_touch_ui_desired():
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _on_outpost_select_pressed() -> void:
	GameState.is_paused = false
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().change_scene_to_file("res://scenes/ui/map_select.tscn")


func _on_gunsmith_pressed() -> void:
	GameState.is_paused = false
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().change_scene_to_file("res://scenes/ui/loadout.tscn")


func _on_menu_pressed() -> void:
	GameState.is_paused = false
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")


func _ensure_weapon_wheels() -> void:
	if _weapon_wheel == null:
		_weapon_wheel = WeaponWheelScript.new()
		_weapon_wheel.name = "WeaponWheel"
		add_child(_weapon_wheel)
	if _item_wheel == null:
		_item_wheel = ItemMiniWheelScript.new()
		_item_wheel.name = "ItemMiniWheel"
		_item_wheel.picked.connect(_on_item_wheel_picked)
		add_child(_item_wheel)


func _ensure_support_card() -> void:
	_support_card = get_node_or_null("Root/SupportCard") as PanelContainer
	if _support_card == null:
		_support_card = PanelContainer.new()
		_support_card.name = "SupportCard"
		_support_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.07, 0.08, 0.06, 0.86)
		style.border_color = Color(0.93, 0.62, 0.18)
		style.set_border_width_all(2)
		style.set_corner_radius_all(4)
		style.set_content_margin_all(8)
		_support_card.add_theme_stylebox_override("panel", style)
		_support_label = Label.new()
		_support_label.name = "SupportLabel"
		_support_label.add_theme_font_size_override("font_size", 15)
		_support_label.add_theme_color_override("font_color", Color(0.96, 0.9, 0.72))
		_support_card.add_child(_support_label)
		$Root.add_child(_support_card)
	else:
		_support_label = _support_card.get_node_or_null("SupportLabel") as Label
	_support_card.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	# Sit above the weapon/ammo card so the loadout readout stays readable.
	_support_card.offset_left = 16
	_support_card.offset_top = -304
	_support_card.offset_right = 340
	_support_card.offset_bottom = -214
	_support_card.visible = false


func _support_key_label() -> String:
	if not InputMap.has_action("use_support"):
		return "Y"
	for ev in InputMap.action_get_events("use_support"):
		if ev is InputEventKey:
			var key := (ev as InputEventKey).physical_keycode
			return OS.get_keycode_string(key)
	return "Y"


func refresh_support_card() -> void:
	_ensure_support_card()
	if not is_instance_valid(_support_card) or not is_instance_valid(_support_label):
		return
	var sid := GameState.ensure_selected_streak()
	if sid == "" or GameState.total_streak_charges() <= 0:
		_support_card.visible = false
		return
	var info := StreakCatalog.by_id(sid)
	var charges := GameState.get_streak_charges(sid)
	var key := _support_key_label()
	var sm := get_tree().get_first_node_in_group("streak_manager")
	var placing := sm != null and sm.has_method("is_placing") and bool(sm.is_placing())
	_support_card.visible = true
	if placing:
		_support_label.text = "STRIKE  [%s]\n%s\nClick or press again to confirm" % [key, String(info.get("name", sid))]
	else:
		var aim := "  ·  aim first" if StreakCatalog.is_targeted(sid) else ""
		_support_label.text = "SUPPORT  [%s]\n%s  ×%d%s\nTap to use  ·  hold for wheel" % [key, String(info.get("name", sid)), charges, aim]


func _ensure_gadget_lethal_hud() -> void:
	_gadget_lethal_label = get_node_or_null("Root/GadgetLethalLabel") as Label
	if _gadget_lethal_label == null:
		_gadget_lethal_label = Label.new()
		_gadget_lethal_label.name = "GadgetLethalLabel"
		_gadget_lethal_label.add_theme_font_size_override("font_size", 15)
		_gadget_lethal_label.add_theme_constant_override("outline_size", 4)
		_gadget_lethal_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
		_gadget_lethal_label.modulate = Color(0.88, 0.86, 0.72)
		$Root.add_child(_gadget_lethal_label)
	_gadget_lethal_label.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_gadget_lethal_label.offset_left = 24
	_gadget_lethal_label.offset_top = -96
	_gadget_lethal_label.offset_right = 430
	_gadget_lethal_label.offset_bottom = -16


func _ensure_vitals_bars() -> void:
	_armour_bar = get_node_or_null("Root/ArmourBar") as ProgressBar
	if _armour_bar:
		return
	_armour_bar = ProgressBar.new()
	_armour_bar.name = "ArmourBar"
	_armour_bar.max_value = 100
	_armour_bar.show_percentage = false
	_armour_bar.custom_minimum_size = Vector2(160, 10)
	_armour_bar.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_armour_bar.offset_left = 16
	_armour_bar.offset_top = 86
	_armour_bar.offset_right = 176
	_armour_bar.offset_bottom = 96
	_armour_bar.modulate = Color(0.45, 0.7, 1.0)
	$Root.add_child(_armour_bar)


func _ensure_ally_label() -> void:
	_ally_label = get_node_or_null("Root/AllyLabel") as Label
	if _ally_label:
		return
	_ally_label = Label.new()
	_ally_label.name = "AllyLabel"
	_ally_label.add_theme_font_size_override("font_size", 14)
	_ally_label.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_ally_label.offset_left = 16
	_ally_label.offset_top = 104
	_ally_label.offset_right = 360
	_ally_label.offset_bottom = 128
	_ally_label.modulate = Color(0.55, 0.85, 1.0)
	_ally_label.visible = false
	$Root.add_child(_ally_label)


func open_weapon_wheel(slot: int = 0) -> void:
	_ensure_weapon_wheels()
	if is_instance_valid(_item_wheel) and bool(_item_wheel.get("open")):
		_item_wheel.close_wheel(false)
	_weapon_wheel.open_wheel(slot, TouchInput.is_touch_ui_desired())


func close_weapon_wheel(apply: bool = true) -> void:
	if is_instance_valid(_weapon_wheel):
		_weapon_wheel.close_wheel(apply)


func weapon_wheel_open() -> bool:
	return is_instance_valid(_weapon_wheel) and bool(_weapon_wheel.get("open"))


func open_gadget_wheel() -> void:
	_ensure_weapon_wheels()
	if weapon_wheel_open():
		return
	var player := get_tree().get_first_node_in_group("player")
	var entries: Array = []
	for gid in GameState.owned_gadget_ids():
		var cnt := 0
		if is_instance_valid(player) and player.has_method("gadget_count"):
			cnt = int(player.gadget_count(String(gid)))
		else:
			cnt = 1 if String(gid) == "rock" else 0
		if cnt <= 0:
			continue
		entries.append({"id": String(gid), "name": GameState.gadget_display_name(String(gid)), "count": cnt})
	if entries.is_empty():
		return
	_item_wheel.open_for("gadget", entries)


func open_support_wheel() -> void:
	_ensure_weapon_wheels()
	if weapon_wheel_open():
		return
	var entries: Array = []
	for s in StreakCatalog.all_streaks():
		var sid := String(s["id"])
		var cnt := GameState.get_streak_charges(sid)
		if cnt <= 0:
			continue
		var wheel_name := String(s.get("short", s["name"]))
		entries.append({"id": sid, "name": wheel_name, "count": cnt})
	if entries.is_empty():
		return
	var sm := get_tree().get_first_node_in_group("streak_manager")
	if sm and sm.has_method("is_placing") and bool(sm.is_placing()) and sm.has_method("cancel_place"):
		sm.cancel_place()
	_item_wheel.open_for("support", entries)


func open_lethal_wheel() -> void:
	_ensure_weapon_wheels()
	if weapon_wheel_open():
		return
	var player := get_tree().get_first_node_in_group("player")
	var wm = player.get_node_or_null("WeaponManager") if is_instance_valid(player) else null
	var entries: Array = []
	for wid in GameState.owned_lethal_ids():
		var w := WeaponData.from_id(wid as GameState.WeaponId)
		var cnt := 1
		if is_instance_valid(wm) and wm.lethal != null and int(wm.lethal.id) == int(wid):
			cnt = int(wm.lethal_count)
		elif wid == GameState.WeaponId.KNIFE:
			cnt = 4
		else:
			cnt = w.magazine_size
		if cnt <= 0:
			continue
		entries.append({"id": str(int(wid)), "name": w.display_name, "count": cnt})
	if entries.is_empty():
		return
	_item_wheel.open_for("lethal", entries)


func close_item_wheel(apply: bool = true) -> void:
	if is_instance_valid(_item_wheel):
		_item_wheel.close_wheel(apply)


func _on_item_wheel_picked(kind: String, id: String) -> void:
	if kind == "gadget":
		GameState.selected_gadget = id
		show_status("Gadget: %s" % GameState.gadget_display_name(id), 1.4)
	elif kind == "lethal":
		var wid := int(id) as GameState.WeaponId
		var player := get_tree().get_first_node_in_group("player")
		if is_instance_valid(player) and player.has_node("WeaponManager"):
			player.get_node("WeaponManager").set_lethal(wid)
		show_status("Lethal: %s" % GameState.lethal_display_name(wid), 1.4)
	elif kind == "support":
		GameState.select_streak(id)
		var info := StreakCatalog.by_id(id)
		show_status("Support: %s ×%d" % [String(info.get("name", id)), GameState.get_streak_charges(id)], 1.4)
	refresh_gadget_lethal_hud()
	refresh_streak_buttons()


func refresh_gadget_lethal_hud() -> void:
	_ensure_gadget_lethal_hud()
	if not is_instance_valid(_gadget_lethal_label):
		return
	var player := get_tree().get_first_node_in_group("player")
	var gname := GameState.gadget_display_name(GameState.selected_gadget)
	var gcnt := 0
	if is_instance_valid(player) and player.has_method("gadget_count"):
		gcnt = int(player.gadget_count())
	var lname := "—"
	var lcnt := 0
	if is_instance_valid(player) and player.has_node("WeaponManager"):
		var wm = player.get_node("WeaponManager")
		if wm.lethal != null:
			lname = String(wm.lethal.display_name)
			lcnt = int(wm.lethal_count)
	_gadget_lethal_label.text = "GADGET [Q]  %s ×%d\nLETHAL [G]  %s ×%d\nWHEEL [TAB]     SWAP [1/2]" % [gname, gcnt, lname, lcnt]


func refresh_vitals() -> void:
	_ensure_vitals_bars()
	var player := get_tree().get_first_node_in_group("player")
	if not is_instance_valid(player) or not is_instance_valid(_armour_bar):
		return
	var max_a := float(player.get("max_armour"))
	_armour_bar.max_value = maxf(1.0, max_a)
	_armour_bar.value = float(player.get("armour"))
	_armour_bar.visible = max_a > 0.0


func refresh_ally_hud() -> void:
	_ensure_ally_label()
	var am := get_tree().get_first_node_in_group("ally_manager")
	if not is_instance_valid(am) or not am.has_method("ally_status"):
		if is_instance_valid(_ally_label):
			_ally_label.visible = false
		return
	var st: Dictionary = am.ally_status()
	if st.is_empty():
		_ally_label.visible = false
		return
	_ally_label.visible = true
	var cmds := ["FOLLOW", "HOLD", "ATTACK"]
	var cmd_i := clampi(int(st.get("cmd", 0)), 0, 2)
	if bool(st.get("downed", false)):
		_ally_label.text = "ALLY %s DOWN — approach + E" % String(st.get("name", "Ally"))
	else:
		_ally_label.text = "ALLY %s  %s  HP %d  [H]" % [String(st.get("name", "Ally")), cmds[cmd_i], int(st.get("hp", 0))]
