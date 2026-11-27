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
	# Dark vignette bars + crisp fine mil-dot sniper crosshair lines
	for spec in [
		[0.0, 0.0, 1.0, 0.14],
		[0.0, 0.86, 1.0, 1.0],
		[0.0, 0.14, 0.22, 0.86],
		[0.78, 0.14, 1.0, 0.86],
	]:
		var bar := ColorRect.new()
		bar.color = Color(0.02, 0.03, 0.02, 0.92)
		bar.anchor_left = spec[0]
		bar.anchor_top = spec[1]
		bar.anchor_right = spec[2]
		bar.anchor_bottom = spec[3]
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_scope_overlay.add_child(bar)
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
	$Root.add_child(_scope_overlay)
	$Root.move_child(_scope_overlay, 0)


func set_scope_overlay(on: bool) -> void:
	if is_instance_valid(_scope_overlay):
		_scope_overlay.visible = on
	if on and is_instance_valid(crosshair):
		crosshair.visible = false


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
