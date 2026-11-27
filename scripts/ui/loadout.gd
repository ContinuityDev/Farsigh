extends Control
## Interactive 5-slot Loadout & Gunsmith Workbench with live rotating 3D weapon
## preview, real-time stat comparison bars, attachments (suppressor, compensator,
## optics, extended mag, grip, laser, arrow types, skins), and automatic persistence.

const OutpostCatalog = preload("res://scripts/levels/outpost_catalog.gd")
const WeaponDataScript = preload("res://scripts/weapons/weapon_data.gd")
const ViewmodelRigScript = preload("res://scripts/weapons/viewmodel_rig.gd")

const SLOTS := [
	{"key": "primary", "label": "1. PRIMARY"},
	{"key": "secondary", "label": "2. SECONDARY"},
	{"key": "special", "label": "3. SPECIAL / BOW"},
	{"key": "throwable", "label": "4. THROWABLE"},
	{"key": "melee", "label": "5. MELEE"},
]

const MOD_GROUPS := [
	{
		"key": "muzzle",
		"label": "Muzzle",
		"flag": "supports_muzzle",
		"options": [
			{"id": "none", "label": "Standard"},
			{"id": "suppressor", "label": "Suppressor (-Noise, -Range)"},
			{"id": "compensator", "label": "Compensator (-Recoil)"},
		],
	},
	{
		"key": "optic",
		"label": "Optic / Sight",
		"flag": "supports_optic",
		"options": [
			{"id": "iron", "label": "Iron Sights"},
			{"id": "red_dot", "label": "Red Dot"},
			{"id": "holo", "label": "Holo Sight"},
			{"id": "scope", "label": "4x Scope (+Zoom)"},
		],
	},
	{
		"key": "mag",
		"label": "Magazine",
		"flag": "supports_mag",
		"options": [
			{"id": "standard", "label": "Standard Mag"},
			{"id": "extended", "label": "Extended Mag (+50%)"},
		],
	},
	{
		"key": "underbarrel",
		"label": "Underbarrel",
		"flag": "supports_underbarrel",
		"options": [
			{"id": "none", "label": "None"},
			{"id": "grip", "label": "Vertical Grip (-Recoil)"},
			{"id": "laser", "label": "Tactical Laser (-Spread)"},
		],
	},
	{
		"key": "arrow",
		"label": "Arrow / Bolt Type",
		"flag": "supports_arrow",
		"options": [
			{"id": "standard", "label": "Standard Broadhead"},
			{"id": "fire", "label": "Fire Tip (Ignites)"},
			{"id": "explosive", "label": "Explosive Warhead"},
		],
	},
	{
		"key": "skin",
		"label": "Skin / Finish",
		"flag": "",
		"options": [
			{"id": "default", "label": "Matte Black"},
			{"id": "olive", "label": "Woodland Olive"},
			{"id": "tan", "label": "Desert Tan"},
			{"id": "crimson", "label": "Hope Crimson"},
			{"id": "arctic", "label": "Alpine Arctic"},
			{"id": "gold", "label": "Prestige Gold"},
		],
	},
]

@onready var outpost_tag: Label = $Margin/RootVBox/Header/OutpostTag
@onready var slot_tabs: HBoxContainer = $Margin/RootVBox/SlotTabs
@onready var weapon_list: VBoxContainer = $Margin/RootVBox/Body/WeaponPanel/WeaponScroll/WeaponList
@onready var preview_viewport: SubViewport = $Margin/RootVBox/Body/CenterVBox/PreviewPanel/PreviewContainer/PreviewViewport
@onready var weapon_title: Label = $Margin/RootVBox/Body/CenterVBox/WeaponTitle
@onready var weapon_desc: Label = $Margin/RootVBox/Body/CenterVBox/WeaponDesc
@onready var stats_box: VBoxContainer = $Margin/RootVBox/Body/CenterVBox/StatsBox
@onready var mods_vbox: VBoxContainer = $Margin/RootVBox/Body/ModsPanel/ModsScroll/ModsVBox
@onready var summary_label: Label = $Margin/RootVBox/Footer/SummaryLabel

var _active_slot: String = "primary"
var _tab_buttons: Dictionary = {}
var _preview_rig: Node3D = null
var _preview_turntable: Node3D = null
var _spin_angle: float = 0.35


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().paused = false
	GameState.is_paused = false
	var def := OutpostCatalog.get_outpost(GameState.selected_outpost_id)
	outpost_tag.text = "Target: %s" % String(def.get("name", "Hope County Compound"))
	_setup_preview_stage()
	_build_slot_tabs()
	_refresh_all()


func _process(delta: float) -> void:
	if is_instance_valid(_preview_turntable):
		_spin_angle += delta * 0.55
		_preview_turntable.rotation.y = sin(_spin_angle) * 0.72 + 1.15


func _setup_preview_stage() -> void:
	var stage := Node3D.new()
	stage.name = "GunsmithStage"
	preview_viewport.add_child(stage)

	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.11, 0.13, 0.12)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.75, 0.78, 0.75)
	env.ambient_light_energy = 0.85
	var we := WorldEnvironment.new()
	we.environment = env
	stage.add_child(we)

	var key_light := DirectionalLight3D.new()
	key_light.rotation_degrees = Vector3(-35, 38, 0)
	key_light.light_energy = 1.35
	stage.add_child(key_light)

	var rim_light := DirectionalLight3D.new()
	rim_light.rotation_degrees = Vector3(-18, -145, 0)
	rim_light.light_color = Color(0.72, 0.85, 1.0)
	rim_light.light_energy = 0.65
	stage.add_child(rim_light)

	var cam := Camera3D.new()
	cam.position = Vector3(0.0, 0.05, 1.08)
	cam.fov = 40.0
	cam.current = true
	stage.add_child(cam)

	_preview_turntable = Node3D.new()
	_preview_turntable.name = "Turntable"
	_preview_turntable.position = Vector3(0.0, -0.01, 0.0)
	stage.add_child(_preview_turntable)

	_preview_rig = Node3D.new()
	_preview_rig.set_script(ViewmodelRigScript)
	_preview_turntable.add_child(_preview_rig)
	_preview_rig.set_process(false)
	_preview_rig.position = Vector3.ZERO
	var pv: Node3D = _preview_rig.get_node_or_null("ViewmodelPivot")
	if pv != null:
		pv.position = Vector3.ZERO
		pv.rotation = Vector3.ZERO
		for arm_name in ["LeftArm", "RightArm"]:
			var arm := pv.get_node_or_null(arm_name)
			if arm != null:
				arm.visible = false


func _build_slot_tabs() -> void:
	for c in slot_tabs.get_children():
		c.queue_free()
	_tab_buttons.clear()
	for s in SLOTS:
		var btn := Button.new()
		btn.toggle_mode = true
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.custom_minimum_size = Vector2(0, 44)
		btn.text = s["label"]
		btn.pressed.connect(_on_slot_tab.bind(s["key"]))
		slot_tabs.add_child(btn)
		_tab_buttons[s["key"]] = btn


func _on_slot_tab(slot_key: String) -> void:
	_active_slot = slot_key
	_refresh_all()


func _current_weapon_id() -> GameState.WeaponId:
	match _active_slot:
		"primary":
			return GameState.selected_primary
		"secondary":
			return GameState.selected_secondary
		"special":
			return GameState.selected_special
		"throwable":
			return GameState.selected_throwable
		"melee":
			return GameState.selected_melee
	return GameState.selected_primary


func _select_weapon_for_slot(wid: GameState.WeaponId) -> void:
	match _active_slot:
		"primary":
			GameState.selected_primary = wid
		"secondary":
			GameState.selected_secondary = wid
		"special":
			GameState.selected_special = wid
		"throwable":
			GameState.selected_throwable = wid
		"melee":
			GameState.selected_melee = wid
	SaveManager.save_loadout()
	if GameState.has_active_run:
		SaveManager.save_game()
	_refresh_all()


func _refresh_all() -> void:
	for k in _tab_buttons:
		(_tab_buttons[k] as Button).button_pressed = (k == _active_slot)
	_rebuild_weapon_list()
	var wid := _current_weapon_id()
	var mods := GameState.get_weapon_mods(wid)
	var base_w: WeaponData = WeaponDataScript.from_id(wid)
	var modded_w: WeaponData = WeaponDataScript.from_id(wid, mods)
	_update_preview(wid, mods)
	weapon_title.text = modded_w.display_name
	weapon_desc.text = modded_w.description + "  (Headshots always one-shot!)"
	_rebuild_stats(base_w, modded_w)
	_rebuild_mods(wid, base_w, mods)
	summary_label.text = "Loadout: %s | %s | %s | %s | %s  (Saved)" % [
		GameState.weapon_name(GameState.selected_primary),
		GameState.weapon_name(GameState.selected_secondary),
		GameState.weapon_name(GameState.selected_special),
		GameState.weapon_name(GameState.selected_throwable),
		GameState.weapon_name(GameState.selected_melee),
	]


func _rebuild_weapon_list() -> void:
	for c in weapon_list.get_children():
		c.queue_free()
	var cur := _current_weapon_id()
	var ids: Array[GameState.WeaponId] = WeaponDataScript.slot_weapons(_active_slot)
	for wid in ids:
		if not GameState.owns_weapon(wid):
			continue
		var wd: WeaponData = WeaponDataScript.from_id(wid, GameState.get_weapon_mods(wid))
		var btn := Button.new()
		btn.toggle_mode = true
		btn.button_pressed = (wid == cur)
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.custom_minimum_size = Vector2(0, 56)
		var dmg_txt := "%d x %d" % [int(wd.damage), wd.pellet_count] if wd.pellet_count > 1 else "%d" % int(wd.damage)
		btn.text = "%s\nDMG %s  •  RNG %dm  •  NOISE %d" % [wd.display_name, dmg_txt, int(wd.max_range), int(wd.noise_loudness)]
		btn.pressed.connect(_select_weapon_for_slot.bind(wid))
		weapon_list.add_child(btn)
	# Streak loadout (3 consumable slots)
	var streak_hdr := Label.new()
	streak_hdr.text = "SUPPORT CHARGES (buy in Shop — empty until purchased)"
	streak_hdr.add_theme_font_size_override("font_size", 13)
	streak_hdr.modulate = Color(0.88, 0.80, 0.54)
	weapon_list.add_child(streak_hdr)
	for slot_i in range(3):
		var sid := ""
		if slot_i < GameState.equipped_streaks.size():
			sid = String(GameState.equipped_streaks[slot_i])
		var row := HBoxContainer.new()
		var lab := Label.new()
		lab.custom_minimum_size = Vector2(70, 0)
		lab.text = "Slot %d" % (slot_i + 1)
		row.add_child(lab)
		var opt := OptionButton.new()
		opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		opt.add_item("— Buy in shop —", 0)
		opt.set_item_metadata(0, "")
		var sel_idx := 0
		var idx := 1
		var any_owned := false
		for s in StreakCatalog.all_streaks():
			var id := String(s["id"])
			if not GameState.owns_streak(id):
				continue
			any_owned = true
			var ch := GameState.get_streak_charges(id)
			opt.add_item("%s (x%d)" % [String(s["name"]), ch], idx)
			opt.set_item_metadata(idx, id)
			if id == sid:
				sel_idx = idx
			idx += 1
		if not any_owned:
			opt.set_item_text(0, "— Locked — Buy in shop —")
		opt.select(sel_idx)
		opt.item_selected.connect(_on_streak_slot.bind(slot_i, opt))
		row.add_child(opt)
		weapon_list.add_child(row)


func _update_preview(wid: GameState.WeaponId, mods: Dictionary) -> void:
	if not is_instance_valid(_preview_rig):
		return
	_preview_rig.rebuild_weapon(wid, mods)
	_preview_rig.show_weapon(wid, false)
	var slot: Node3D = _preview_rig.get_slot(wid)
	if is_instance_valid(slot):
		slot.position = Vector3(0.0, -0.02, 0.14)
		slot.rotation_degrees = Vector3(0.0, 0.0, 0.0)
		slot.scale = Vector3(1.15, 1.15, 1.15)


func _rebuild_stats(base_w: WeaponData, modded_w: WeaponData) -> void:
	for c in stats_box.get_children():
		c.queue_free()
	var total_dmg := modded_w.damage * float(maxi(1, modded_w.pellet_count))
	var base_dmg := base_w.damage * float(maxi(1, base_w.pellet_count))
	var rpm := int(round(60.0 / maxf(0.05, modded_w.fire_rate)))
	var stealth_val := clampf(100.0 - modded_w.noise_loudness * 1.3, 5.0, 100.0)
	var base_stealth := clampf(100.0 - base_w.noise_loudness * 1.3, 5.0, 100.0)
	var control_val := clampf(100.0 - modded_w.recoil_pitch * 16.0, 10.0, 100.0)
	var base_control := clampf(100.0 - base_w.recoil_pitch * 16.0, 10.0, 100.0)
	var rows := [
		["Damage", total_dmg, base_dmg, 160.0, "%d" % int(total_dmg)],
		["Fire Rate", float(rpm), float(rpm), 900.0, "%d RPM" % rpm],
		["Range", modded_w.max_range, base_w.max_range, 190.0, "%dm" % int(modded_w.max_range)],
		["Stealth", stealth_val, base_stealth, 100.0, "Noise %d" % int(modded_w.noise_loudness)],
		["Control", control_val, base_control, 100.0, "Recoil %.1f" % modded_w.recoil_pitch],
		["Mag / Zoom", float(modded_w.magazine_size), float(base_w.magazine_size), 90.0, "Mag %d | FOV %d°" % [modded_w.magazine_size, int(modded_w.aim_fov)]],
	]
	for r in rows:
		var h := HBoxContainer.new()
		var lbl := Label.new()
		lbl.custom_minimum_size = Vector2(92, 0)
		lbl.add_theme_font_size_override("font_size", 13)
		lbl.text = String(r[0])
		h.add_child(lbl)

		var pb := ProgressBar.new()
		pb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		pb.max_value = float(r[3])
		pb.value = clampf(float(r[1]), 0.0, float(r[3]))
		pb.show_percentage = false
		pb.custom_minimum_size = Vector2(0, 16)
		var delta_v := float(r[1]) - float(r[2])
		if delta_v > 0.2:
			pb.modulate = Color(0.42, 0.95, 0.52)
		elif delta_v < -0.2:
			pb.modulate = Color(0.95, 0.52, 0.36)
		h.add_child(pb)

		var val_lbl := Label.new()
		val_lbl.custom_minimum_size = Vector2(118, 0)
		val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		val_lbl.add_theme_font_size_override("font_size", 12)
		val_lbl.text = String(r[4])
		h.add_child(val_lbl)
		stats_box.add_child(h)


func _rebuild_mods(wid: GameState.WeaponId, base_w: WeaponData, mods: Dictionary) -> void:
	for c in mods_vbox.get_children():
		c.queue_free()

	for grp in MOD_GROUPS:
		var flag: String = grp["flag"]
		if flag != "" and not bool(base_w.get(flag)):
			continue
		var gkey: String = grp["key"]
		var cur_val := String(mods.get(gkey, grp["options"][0]["id"]))
		var header := Label.new()
		header.text = String(grp["label"]).to_upper()
		header.add_theme_font_size_override("font_size", 13)
		header.modulate = Color(0.88, 0.80, 0.54)
		mods_vbox.add_child(header)

		var flow := HFlowContainer.new()
		flow.add_theme_constant_override("h_separation", 6)
		flow.add_theme_constant_override("v_separation", 6)
		for opt in grp["options"]:
			var b := Button.new()
			b.toggle_mode = true
			b.button_pressed = (String(opt["id"]) == cur_val)
			b.custom_minimum_size = Vector2(0, 38)
			b.add_theme_font_size_override("font_size", 13)
			b.text = String(opt["label"])
			b.pressed.connect(_on_mod_picked.bind(wid, gkey, String(opt["id"])))
			flow.add_child(b)
		mods_vbox.add_child(flow)


func _on_mod_picked(wid: GameState.WeaponId, mod_slot: String, mod_val: String) -> void:
	GameState.set_weapon_mod(wid, mod_slot, mod_val)
	SaveManager.save_loadout()
	_refresh_all()


func _on_streak_slot(item_index: int, slot_i: int, opt: OptionButton) -> void:
	var sid := String(opt.get_item_metadata(item_index))
	GameState.set_equipped_streak(slot_i, sid)


func _on_deploy() -> void:
	SaveManager.save_loadout()
	if GameState.has_active_run:
		SaveManager.save_game()
	GameState.begin_world_load()
	get_tree().change_scene_to_file("res://scenes/levels/outpost.tscn")


func _on_back() -> void:
	SaveManager.save_loadout()
	get_tree().change_scene_to_file("res://scenes/ui/map_select.tscn")
