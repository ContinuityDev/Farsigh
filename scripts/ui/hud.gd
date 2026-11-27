extends CanvasLayer
## Crosshair, ammo, detection meter, status messages, pause overlay.

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


func _ready() -> void:
	add_to_group("hud")
	process_mode = Node.PROCESS_MODE_ALWAYS
	pause_panel.visible = false
	liberated_banner.visible = false
	status_label.text = ""
	detection_bar.value = 0
	_ensure_capture_hint()
	_ensure_scope_overlay()
	_ensure_settings_buttons()
	_ensure_clear_ui()
	_ensure_streak_buttons()
	_ensure_currency_label()
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
		var rocks := int(player.get("rock_count"))
		var hp_val := int(player.get("hp"))
		var stance := "CROUCH" if bool(player.get("is_crouching")) else "STAND"
		rocks_label.text = "HP: %d  |  %s (C)  |  Rocks: %d" % [hp_val, stance, rocks]


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
	show_status("OUTPOST LIBERATED — %s" % name, 6.0)
	set_liberated_banner(true)


func set_liberated_banner(on: bool) -> void:
	liberated_banner.visible = on
	if on:
		liberated_banner.text = "LIBERATED"


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
	## Streak HUD buttons: ScreenTouch hit-test (same pattern as touch action buttons).
	if GameState.is_paused or not TouchInput.is_touch_ui_desired():
		return
	if not (event is InputEventScreenTouch and event.pressed):
		return
	if _streak_buttons.is_empty():
		return
	var pos: Vector2 = event.position
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
		return
	var sm := get_tree().get_first_node_in_group("streak_manager")
	var any_visible := false
	for i in range(3):
		var sid := ""
		if i < GameState.equipped_streaks.size():
			sid = String(GameState.equipped_streaks[i])
		var btn: Button = _streak_buttons[i]
		# Only show when a streak is equipped and owned (hide empty slots).
		if sid == "" or not GameState.owns_streak(sid):
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
		btn.text = "%s\nx%d" % [String(info.get("name", sid)), charges]
		btn.disabled = not ready
		btn.modulate = Color(0.55, 0.95, 0.55) if ready else Color(0.85, 0.85, 0.85)
	if is_instance_valid(_streak_row):
		_streak_row.visible = any_visible


func _on_streak_pressed(slot: int) -> void:
	var sm := get_tree().get_first_node_in_group("streak_manager")
	if sm and sm.has_method("try_activate"):
		sm.try_activate(slot)
		refresh_streak_buttons()


func set_paused(paused: bool) -> void:
	pause_panel.visible = paused
	if paused:
		_refresh_settings_ui()


func _refresh_settings_ui() -> void:
	var sens_btn := pause_panel.get_node_or_null("PauseVBox/AdsSensBtn") as Button
	if is_instance_valid(sens_btn):
		sens_btn.text = "ADS Sensitivity: %d%%" % int(round(GameState.ads_sensitivity * 100.0))
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


func _ensure_settings_buttons() -> void:
	var vbox := pause_panel.get_node_or_null("PauseVBox") as VBoxContainer
	if vbox == null:
		return
	if vbox.get_node_or_null("AdsSensBtn") == null:
		var sens := Button.new()
		sens.name = "AdsSensBtn"
		sens.custom_minimum_size = Vector2(0, 40)
		sens.pressed.connect(_on_ads_sens_pressed)
		vbox.add_child(sens)
		vbox.move_child(sens, mini(3, vbox.get_child_count() - 1))
	if vbox.get_node_or_null("TouchAimBtn") == null:
		var aim := Button.new()
		aim.name = "TouchAimBtn"
		aim.custom_minimum_size = Vector2(0, 40)
		aim.pressed.connect(_on_touch_aim_pressed)
		vbox.add_child(aim)
		vbox.move_child(aim, mini(4, vbox.get_child_count() - 1))
	if vbox.get_node_or_null("TapToFireBtn") == null:
		var tap := Button.new()
		tap.name = "TapToFireBtn"
		tap.custom_minimum_size = Vector2(0, 40)
		tap.pressed.connect(_on_tap_to_fire_pressed)
		vbox.add_child(tap)
		vbox.move_child(tap, mini(5, vbox.get_child_count() - 1))
	if vbox.get_node_or_null("FullscreenBtn") == null:
		var fs := Button.new()
		fs.name = "FullscreenBtn"
		fs.custom_minimum_size = Vector2(0, 40)
		fs.pressed.connect(_on_fullscreen_pressed)
		vbox.add_child(fs)
		vbox.move_child(fs, mini(6, vbox.get_child_count() - 1))
	_refresh_settings_ui()


func _on_ads_sens_pressed() -> void:
	# Cycle Low (35%) → Med (55%) → High (75%) → Full (100%)
	var steps: Array[float] = [0.35, 0.55, 0.75, 1.0]
	var idx := 0
	for i in range(steps.size()):
		if absf(GameState.ads_sensitivity - steps[i]) < 0.05:
			idx = (i + 1) % steps.size()
			break
	GameState.set_ads_sensitivity(steps[idx])
	_refresh_settings_ui()
	show_status("ADS mouse/look sensitivity: %d%%" % int(round(GameState.ads_sensitivity * 100.0)), 1.6)


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
