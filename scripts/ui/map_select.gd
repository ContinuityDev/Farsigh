extends Control
## Tactical Outpost / Map Select screen showing liberation status per outpost,
## garrison intel (guards, snipers, alarms), and tactical approaches.

const OutpostCatalog = preload("res://scripts/levels/outpost_catalog.gd")

@onready var progress_label: Label = $Margin/RootVBox/Header/ProgressLabel
@onready var outpost_list: VBoxContainer = $Margin/RootVBox/Body/Scroll/OutpostList
@onready var detail_name: Label = $Margin/RootVBox/Body/DetailPanel/DetailMargin/DetailVBox/DetailName
@onready var detail_theme: Label = $Margin/RootVBox/Body/DetailPanel/DetailMargin/DetailVBox/DetailTheme
@onready var detail_status: Label = $Margin/RootVBox/Body/DetailPanel/DetailMargin/DetailVBox/DetailStatus
@onready var detail_desc: Label = $Margin/RootVBox/Body/DetailPanel/DetailMargin/DetailVBox/DetailDesc
@onready var detail_intel: Label = $Margin/RootVBox/Body/DetailPanel/DetailMargin/DetailVBox/DetailIntel
@onready var detail_approaches: Label = $Margin/RootVBox/Body/DetailPanel/DetailMargin/DetailVBox/DetailApproaches

var _selected_id: String = "compound_alpha"
var _cards: Dictionary = {}


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().paused = false
	GameState.is_paused = false
	_selected_id = GameState.selected_outpost_id
	_build_cards()
	_refresh()


func _build_cards() -> void:
	for c in outpost_list.get_children():
		c.queue_free()
	_cards.clear()

	for def in OutpostCatalog.get_all():
		var oid: String = def["id"]
		var is_lib := GameState.is_liberated(oid)
		var g_count := OutpostCatalog.guard_count(def)
		var s_count := OutpostCatalog.sniper_count(def)
		var a_count := OutpostCatalog.alarm_count(def)
		var badge := "LIBERATED" if is_lib else "CONTESTED"
		var btn := Button.new()
		btn.toggle_mode = true
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.custom_minimum_size = Vector2(0, 74)
		btn.add_theme_font_size_override("font_size", 16)
		btn.text = "%s  [%s]\n%s  •  %d Hostiles (%d Snipers)  •  %d Alarms" % [
			def["name"], badge, def["theme"], g_count, s_count, a_count
		]
		if is_lib:
			btn.modulate = Color(0.75, 1.0, 0.78)
		btn.pressed.connect(_on_select.bind(oid))
		outpost_list.add_child(btn)
		_cards[oid] = btn


func _on_select(oid: String) -> void:
	_selected_id = oid
	GameState.select_outpost(oid)
	_refresh()


func _refresh() -> void:
	var lib_cnt := GameState.liberated_count()
	var total := GameState.total_outposts()
	progress_label.text = "Liberated: %d / %d" % [lib_cnt, total]
	progress_label.modulate = Color(0.5, 0.95, 0.55) if lib_cnt == total else Color(0.95, 0.82, 0.45)

	for oid in _cards:
		var b: Button = _cards[oid]
		b.button_pressed = (oid == _selected_id)

	var def := OutpostCatalog.get_outpost(_selected_id)
	var is_lib := GameState.is_liberated(_selected_id)
	detail_name.text = String(def.get("name", ""))
	detail_theme.text = String(def.get("theme", ""))
	if is_lib:
		detail_status.text = "STATUS: LIBERATED (Revisit safe — clear skies)"
		detail_status.modulate = Color(0.45, 0.95, 0.55)
	else:
		detail_status.text = "STATUS: HOSTILE GARRISON"
		detail_status.modulate = Color(0.96, 0.65, 0.35)
	detail_desc.text = String(def.get("description", ""))
	detail_intel.text = "Garrison: %d Guards (%d Snipers)   |   Alarm Panels: %d" % [
		OutpostCatalog.guard_count(def),
		OutpostCatalog.sniper_count(def),
		OutpostCatalog.alarm_count(def),
	]
	var approaches_raw = def.get("approaches", "")
	var lines := PackedStringArray(["Tactical Entry Approaches:"])
	if approaches_raw is Array:
		for a in approaches_raw:
			lines.append("  • " + String(a))
	else:
		for a in String(approaches_raw).split(","):
			var trimmed := a.strip_edges()
			if trimmed != "":
				lines.append("  • " + trimmed)
	detail_approaches.text = "\n".join(lines)


func _on_gunsmith_pressed() -> void:
	GameState.select_outpost(_selected_id)
	get_tree().change_scene_to_file("res://scenes/ui/loadout.tscn")


func _on_deploy_pressed() -> void:
	GameState.select_outpost(_selected_id)
	get_tree().change_scene_to_file("res://scenes/levels/outpost.tscn")


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")
