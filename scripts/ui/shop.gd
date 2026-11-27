extends Control
## Hope Dollars shop — weapons, items, abilities, streaks, mods/skins.


@onready var balance_label: Label = $Margin/RootVBox/Header/BalanceLabel
@onready var list: VBoxContainer = $Margin/RootVBox/Body/Scroll/ItemList
@onready var detail_title: Label = $Margin/RootVBox/Body/Detail/Title
@onready var detail_desc: Label = $Margin/RootVBox/Body/Detail/Desc
@onready var detail_price: Label = $Margin/RootVBox/Body/Detail/Price
@onready var buy_btn: Button = $Margin/RootVBox/Body/Detail/BuyBtn
@onready var status_label: Label = $Margin/RootVBox/Footer/StatusLabel
@onready var filter_tabs: HBoxContainer = $Margin/RootVBox/FilterTabs

var _selected_id: String = ""
var _filter: String = "all"
var _buttons: Dictionary = {}


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().paused = false
	GameState.is_paused = false
	_build_filters()
	_rebuild_list()
	_refresh_detail()


func _build_filters() -> void:
	for c in filter_tabs.get_children():
		c.queue_free()
	for f in [
		{"id": "all", "label": "All"},
		{"id": "weapon", "label": "Weapons"},
		{"id": "item", "label": "Items"},
		{"id": "ability", "label": "Abilities"},
		{"id": "attachment", "label": "Attachments"},
		{"id": "armour", "label": "Armour"},
		{"id": "ally", "label": "Allies"},
		{"id": "streak", "label": "Streaks"},
		{"id": "mod", "label": "Mod Kits"},
		{"id": "skin", "label": "Skins"},
	]:
		var b := Button.new()
		b.toggle_mode = true
		b.text = f["label"]
		b.custom_minimum_size = Vector2(0, 40)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(_on_filter.bind(String(f["id"])))
		filter_tabs.add_child(b)
		if String(f["id"]) == _filter:
			b.button_pressed = true


func _on_filter(fid: String) -> void:
	_filter = fid
	for b in filter_tabs.get_children():
		if b is Button:
			(b as Button).button_pressed = false
	_rebuild_list()
	_refresh_detail()


func _rebuild_list() -> void:
	for c in list.get_children():
		c.queue_free()
	_buttons.clear()
	balance_label.text = "$%d Hope Dollars" % GameState.currency
	for e in ShopCatalog.all_entries():
		var kind := String(e.get("kind", ""))
		if _filter != "all" and kind != _filter:
			continue
		var eid := String(e.get("id", ""))
		var owned := _is_owned(e)
		var btn := Button.new()
		btn.toggle_mode = true
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.custom_minimum_size = Vector2(0, 64)
		btn.add_theme_font_size_override("font_size", 15)
		var price := int(e.get("price", 0))
		var tag := "OWNED" if owned else "$%d" % price
		if kind == "streak":
			var sid := String(e.get("streak", ""))
			var ch := GameState.get_streak_charges(sid)
			tag = "x%d / %d" % [ch, StreakCatalog.max_carry(sid)] if ch > 0 else "$%d" % price
		btn.text = "%s  [%s]\n%s" % [String(e.get("name", "")), tag, String(e.get("desc", ""))]
		if owned:
			btn.modulate = Color(0.72, 0.95, 0.75)
		btn.pressed.connect(_on_select.bind(eid))
		list.add_child(btn)
		_buttons[eid] = btn
		if _selected_id == "" and not owned:
			_selected_id = eid
	if _selected_id != "" and _buttons.has(_selected_id):
		(_buttons[_selected_id] as Button).button_pressed = true


func _is_owned(e: Dictionary) -> bool:
	var kind := String(e.get("kind", ""))
	var eid := String(e.get("id", ""))
	match kind:
		"weapon":
			return GameState.owns_weapon(e.get("weapon") as GameState.WeaponId)
		"item":
			return GameState.owns_item(eid)
		"ability":
			return GameState.owns_ability(eid)
		"streak":
			# Consumables: show charge count, never permanently "owned"
			var sid := String(e.get("streak", ""))
			return GameState.get_streak_charges(sid) >= StreakCatalog.max_carry(sid)
		"mod":
			return GameState.unlocked_mod_pack
		"skin":
			return GameState.unlocked_skin_pack
		"attachment":
			return eid in GameState.unlocked_attachments or GameState.unlocked_mod_pack
		"armour":
			return GameState.armour_tier >= int(e.get("tier", 0))
		"ally":
			var aid := String(e.get("ally", ""))
			return GameState.get_ally_charges(aid) >= 2
	return false


func _on_select(eid: String) -> void:
	_selected_id = eid
	for id in _buttons:
		(_buttons[id] as Button).button_pressed = (id == eid)
	_refresh_detail()


func _refresh_detail() -> void:
	balance_label.text = "$%d Hope Dollars" % GameState.currency
	var e: Dictionary = ShopCatalog.entry(_selected_id)
	if e.is_empty():
		detail_title.text = "Select an item"
		detail_desc.text = ""
		detail_price.text = ""
		buy_btn.disabled = true
		return
	detail_title.text = String(e.get("name", ""))
	detail_desc.text = String(e.get("desc", ""))
	var owned := _is_owned(e)
	var price := int(e.get("price", 0))
	var kind := String(e.get("kind", ""))
	if kind == "streak":
		var sid := String(e.get("streak", ""))
		var ch := GameState.get_streak_charges(sid)
		var cap := StreakCatalog.max_carry(sid)
		detail_price.text = "Charge $%d  ·  Owned %d / %d" % [price, ch, cap]
		detail_price.modulate = Color(0.95, 0.82, 0.35)
		buy_btn.disabled = GameState.currency < price or ch >= cap
		buy_btn.text = "Buy Charge" if ch < cap else "At Carry Limit"
	elif owned:
		detail_price.text = "Already owned"
		detail_price.modulate = Color(0.55, 0.9, 0.55)
		buy_btn.disabled = true
		buy_btn.text = "Owned"
	else:
		detail_price.text = "Price: $%d" % price
		detail_price.modulate = Color(0.95, 0.82, 0.35)
		buy_btn.disabled = GameState.currency < price
		buy_btn.text = "Buy for $%d" % price


func _on_buy_pressed() -> void:
	var err := GameState.try_purchase(_selected_id)
	if err != "":
		status_label.text = err
		status_label.modulate = Color(0.95, 0.45, 0.35)
		return
	status_label.text = "Purchased — saved to profile"
	status_label.modulate = Color(0.55, 0.95, 0.55)
	_rebuild_list()
	_refresh_detail()


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/map_select.tscn")


func _on_loadout_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/loadout.tscn")
