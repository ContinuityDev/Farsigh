extends Control


@onready var continue_btn: Button = $Center/VBox/ContinueBtn
@onready var new_run_btn: Button = $Center/VBox/NewRunBtn
@onready var quit_btn: Button = $Center/VBox/QuitBtn
@onready var status: Label = $Center/VBox/StatusLabel
@onready var subtitle: Label = $Center/VBox/Subtitle

var _shop_btn: Button
var _settings_btn: Button
var _confirm_panel: Control
var _settings_panel: Control


func _ready() -> void:
	add_to_group("main_menu")
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().paused = false
	GameState.is_paused = false
	continue_btn.disabled = not GameState.has_active_run
	_ensure_shop_btn()
	_ensure_settings_btn()
	_ensure_fullscreen_btn()
	_ensure_confirm_panel()
	_ensure_settings_panel()
	_refresh_status()
	for b in [continue_btn, new_run_btn, quit_btn]:
		b.custom_minimum_size = Vector2(280, 56)
	if OS.has_feature("web"):
		quit_btn.visible = false
		if subtitle:
			subtitle.text = "Stealth compound assault — playable in your browser"


func _ensure_fullscreen_btn() -> void:
	var vbox := $Center/VBox
	var fs := vbox.get_node_or_null("FullscreenBtn") as Button
	if fs == null:
		fs = Button.new()
		fs.name = "FullscreenBtn"
		fs.custom_minimum_size = Vector2(280, 56)
		fs.add_theme_font_size_override("font_size", 20)
		fs.pressed.connect(_on_fullscreen_pressed)
		vbox.add_child(fs)
		vbox.move_child(fs, quit_btn.get_index())
	_refresh_fullscreen_btn(fs)


func _refresh_fullscreen_btn(fs: Button = null) -> void:
	if fs == null:
		fs = $Center/VBox.get_node_or_null("FullscreenBtn") as Button
	if not is_instance_valid(fs):
		return
	var on := false
	if WebDisplay and WebDisplay.has_method("is_fullscreen"):
		on = bool(WebDisplay.is_fullscreen())
	fs.text = "Fullscreen: %s" % ("On" if on else "Off")


func _on_fullscreen_pressed() -> void:
	if WebDisplay and WebDisplay.has_method("toggle_fullscreen"):
		WebDisplay.toggle_fullscreen()
	_refresh_fullscreen_btn()


func _ensure_shop_btn() -> void:
	var vbox := $Center/VBox
	_shop_btn = vbox.get_node_or_null("ShopBtn") as Button
	if _shop_btn == null:
		_shop_btn = Button.new()
		_shop_btn.name = "ShopBtn"
		_shop_btn.text = "Shop / Armory"
		_shop_btn.custom_minimum_size = Vector2(280, 56)
		_shop_btn.add_theme_font_size_override("font_size", 20)
		_shop_btn.pressed.connect(_on_shop_pressed)
		vbox.add_child(_shop_btn)
		vbox.move_child(_shop_btn, quit_btn.get_index())
	_shop_btn.disabled = not GameState.has_active_run


func _ensure_settings_btn() -> void:
	var vbox := $Center/VBox
	_settings_btn = vbox.get_node_or_null("SettingsBtn") as Button
	if _settings_btn == null:
		_settings_btn = Button.new()
		_settings_btn.name = "SettingsBtn"
		_settings_btn.text = "Settings"
		_settings_btn.custom_minimum_size = Vector2(280, 56)
		_settings_btn.add_theme_font_size_override("font_size", 20)
		_settings_btn.pressed.connect(_on_settings_pressed)
		vbox.add_child(_settings_btn)
		vbox.move_child(_settings_btn, quit_btn.get_index())


func _ensure_settings_panel() -> void:
	_settings_panel = get_node_or_null("SettingsPanel") as Control
	if _settings_panel:
		return
	_settings_panel = Control.new()
	_settings_panel.name = "SettingsPanel"
	_settings_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_settings_panel.visible = false
	_settings_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.78)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_settings_panel.add_child(dim)
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -240
	panel.offset_right = 240
	panel.offset_top = -260
	panel.offset_bottom = 260
	_settings_panel.add_child(panel)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(460, 500)
	panel.add_child(scroll)
	var box := VBoxContainer.new()
	box.name = "SettingsVBox"
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 8)
	scroll.add_child(box)
	var title := Label.new()
	title.text = "Settings"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 26)
	box.add_child(title)
	_add_menu_slider(box, "MouseLook", "Mouse Look", GameState.mouse_look_sensitivity, 0.25, 2.0, Callable(GameState, "set_mouse_look_sensitivity"))
	_add_menu_slider(box, "TouchLook", "Touch Look", GameState.touch_look_sensitivity, 0.25, 2.0, Callable(GameState, "set_touch_look_sensitivity"))
	_add_menu_slider(box, "AdsSens", "ADS / Scope", GameState.ads_sensitivity, 0.25, 1.0, Callable(GameState, "set_ads_sensitivity"))
	_add_menu_slider(box, "Scope4x", "Scope 4× Mult", GameState.scope_sens_4x, 0.25, 1.5, Callable(GameState, "set_scope_sens_4x"))
	_add_menu_slider(box, "Scope6x", "Scope 6× Mult", GameState.scope_sens_6x, 0.25, 1.5, Callable(GameState, "set_scope_sens_6x"))
	_add_menu_slider(box, "Scope8x", "Scope 8× Mult", GameState.scope_sens_8x, 0.25, 1.5, Callable(GameState, "set_scope_sens_8x"))
	var inv := Button.new()
	inv.name = "InvertYBtn"
	inv.custom_minimum_size = Vector2(0, 44)
	inv.pressed.connect(func():
		GameState.set_invert_y(not GameState.invert_y)
		_refresh_menu_settings()
	)
	box.add_child(inv)
	var controls := Button.new()
	controls.name = "ControlsBtn"
	controls.text = "Controls…"
	controls.custom_minimum_size = Vector2(0, 44)
	controls.pressed.connect(_on_controls_from_menu)
	box.add_child(controls)
	var close := Button.new()
	close.text = "Close"
	close.custom_minimum_size = Vector2(0, 48)
	close.pressed.connect(func(): _settings_panel.visible = false)
	box.add_child(close)
	add_child(_settings_panel)
	_refresh_menu_settings()


func _on_controls_from_menu() -> void:
	if get_node_or_null("ControlsSettings") != null:
		return
	var panel = load("res://scripts/ui/controls_settings.gd").new()
	panel.name = "ControlsSettings"
	add_child(panel)


func _add_menu_slider(parent: VBoxContainer, key: String, title: String, value: float, min_v: float, max_v: float, setter: Callable) -> void:
	var row := VBoxContainer.new()
	row.name = key + "Row"
	row.add_theme_constant_override("separation", 2)
	var header := HBoxContainer.new()
	var title_lbl := Label.new()
	title_lbl.name = "Title"
	title_lbl.text = title
	title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var val_lbl := Label.new()
	val_lbl.name = "Value"
	val_lbl.text = "%d%%" % int(round(value * 100.0))
	val_lbl.custom_minimum_size = Vector2(56, 0)
	val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
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
	slider.custom_minimum_size = Vector2(400, 28)
	slider.value_changed.connect(func(v: float):
		setter.call(v)
		val_lbl.text = "%d%%" % int(round(v * 100.0))
	)
	row.add_child(slider)
	parent.add_child(row)


func _refresh_menu_settings() -> void:
	if not is_instance_valid(_settings_panel):
		return
	var box := _settings_panel.find_child("SettingsVBox", true, false) as VBoxContainer
	if box == null:
		return
	_sync_menu_row(box, "MouseLookRow", GameState.mouse_look_sensitivity)
	_sync_menu_row(box, "TouchLookRow", GameState.touch_look_sensitivity)
	_sync_menu_row(box, "AdsSensRow", GameState.ads_sensitivity)
	_sync_menu_row(box, "Scope4xRow", GameState.scope_sens_4x)
	_sync_menu_row(box, "Scope6xRow", GameState.scope_sens_6x)
	_sync_menu_row(box, "Scope8xRow", GameState.scope_sens_8x)
	var inv := box.get_node_or_null("InvertYBtn") as Button
	if is_instance_valid(inv):
		inv.text = "Invert Y: %s" % ("On" if GameState.invert_y else "Off")


func _sync_menu_row(box: VBoxContainer, row_name: String, value: float) -> void:
	var row := box.get_node_or_null(row_name) as Control
	if row == null:
		return
	var slider := row.get_node_or_null("Slider") as HSlider
	var val := row.get_node_or_null("Value") as Label
	# Value is under Header
	if val == null:
		var header := row.get_node_or_null("Header") as Control
		if header:
			val = header.get_node_or_null("Value") as Label
		# Our structure: Header is unnamed HBox — first child is title, second is Value via find
		if val == null and row.get_child_count() > 0:
			var h := row.get_child(0)
			if h is HBoxContainer and h.get_child_count() > 1:
				val = h.get_child(1) as Label
	if is_instance_valid(slider):
		slider.set_value_no_signal(value)
	if is_instance_valid(val):
		val.text = "%d%%" % int(round(value * 100.0))


func _on_settings_pressed() -> void:
	_ensure_settings_panel()
	_refresh_menu_settings()
	_settings_panel.visible = true


func _ensure_confirm_panel() -> void:
	_confirm_panel = get_node_or_null("ConfirmWipe") as Control
	if _confirm_panel:
		return
	_confirm_panel = Control.new()
	_confirm_panel.name = "ConfirmWipe"
	_confirm_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_confirm_panel.visible = false
	_confirm_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.72)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_confirm_panel.add_child(dim)
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.offset_left = -200
	box.offset_right = 200
	box.offset_top = -90
	box.offset_bottom = 90
	box.add_theme_constant_override("separation", 12)
	_confirm_panel.add_child(box)
	var msg := Label.new()
	msg.text = "Start a New Run?\nThis wipes currency, gear, support charges, and outpost progress."
	msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	msg.add_theme_font_size_override("font_size", 18)
	box.add_child(msg)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	box.add_child(row)
	var cancel := Button.new()
	cancel.text = "Cancel"
	cancel.custom_minimum_size = Vector2(120, 44)
	cancel.pressed.connect(func(): _confirm_panel.visible = false)
	row.add_child(cancel)
	var confirm := Button.new()
	confirm.text = "Wipe & Start"
	confirm.custom_minimum_size = Vector2(140, 44)
	confirm.modulate = Color(0.95, 0.55, 0.4)
	confirm.pressed.connect(_confirm_new_run)
	row.add_child(confirm)
	add_child(_confirm_panel)


func _refresh_status() -> void:
	var lib := GameState.liberated_count()
	var total := GameState.total_outposts()
	if lib == total and total > 0:
		status.text = "Hope County Liberated (%d / %d)  ·  $%d" % [lib, total, GameState.currency]
		status.modulate = Color(0.55, 0.95, 0.55)
	elif GameState.has_active_run:
		status.text = "Campaign — %d / %d beaten  ·  $%d Hope" % [lib, total, GameState.currency]
		status.modulate = Color(0.95, 0.78, 0.42)
	else:
		status.text = "No active run — 8 Outposts await"
		status.modulate = Color(0.75, 0.75, 0.75)
	continue_btn.disabled = not GameState.has_active_run
	if _shop_btn:
		_shop_btn.disabled = not GameState.has_active_run


func _on_continue_pressed() -> void:
	if not GameState.continue_run():
		return
	get_tree().change_scene_to_file("res://scenes/ui/map_select.tscn")


func _on_new_run_pressed() -> void:
	if GameState.has_active_run and (
		GameState.currency > 0
		or GameState.liberated_count() > 0
		or not GameState.owned_items.is_empty()
		or not GameState.owned_streaks.is_empty()
		or not GameState.streak_charges.is_empty()
	):
		_confirm_panel.visible = true
		return
	_confirm_new_run()


func _confirm_new_run() -> void:
	if _confirm_panel:
		_confirm_panel.visible = false
	SaveManager.clear_save()
	GameState.start_new_run()
	get_tree().change_scene_to_file("res://scenes/ui/map_select.tscn")


func _on_shop_pressed() -> void:
	if not GameState.has_active_run:
		return
	get_tree().change_scene_to_file("res://scenes/ui/shop.tscn")


func _on_quit_pressed() -> void:
	get_tree().quit()
