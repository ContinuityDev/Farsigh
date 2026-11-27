extends Control


@onready var continue_btn: Button = $Center/VBox/ContinueBtn
@onready var new_run_btn: Button = $Center/VBox/NewRunBtn
@onready var quit_btn: Button = $Center/VBox/QuitBtn
@onready var status: Label = $Center/VBox/StatusLabel
@onready var subtitle: Label = $Center/VBox/Subtitle

var _shop_btn: Button
var _confirm_panel: Control


func _ready() -> void:
	add_to_group("main_menu")
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().paused = false
	GameState.is_paused = false
	continue_btn.disabled = not GameState.has_active_run
	_ensure_shop_btn()
	_ensure_confirm_panel()
	_refresh_status()
	for b in [continue_btn, new_run_btn, quit_btn]:
		b.custom_minimum_size = Vector2(280, 56)
	if OS.has_feature("web"):
		quit_btn.visible = false
		if subtitle:
			subtitle.text = "Stealth compound assault — playable in your browser"


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
	msg.text = "Start a New Run?\nThis wipes currency, owned gear, and outpost progress."
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
		status.text = "No active run — 5 Outposts await"
		status.modulate = Color(0.75, 0.75, 0.75)
	continue_btn.disabled = not GameState.has_active_run
	if _shop_btn:
		_shop_btn.disabled = not GameState.has_active_run


func _on_continue_pressed() -> void:
	if not GameState.continue_run():
		return
	get_tree().change_scene_to_file("res://scenes/ui/map_select.tscn")


func _on_new_run_pressed() -> void:
	if GameState.has_active_run and (GameState.currency > 0 or GameState.liberated_count() > 0 or not GameState.owned_items.is_empty()):
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
