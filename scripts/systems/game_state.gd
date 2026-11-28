extends Node
## Global run state: selected outpost, per-outpost liberation persistence,
## 2-slot loadout + carried pool, and gunsmith weapon customization.

const OutpostCatalog = preload("res://scripts/levels/outpost_catalog.gd")
const AttachmentCatalog = preload("res://scripts/systems/attachment_catalog.gd")
const InputBindings = preload("res://scripts/systems/input_bindings.gd")

signal outpost_liberated(outpost_id: String)
signal outpost_status_changed(outpost_id: String, status: String)
signal detection_max_changed(value: float)
signal player_spotted()

enum WeaponId {
	PISTOL,
	RIFLE,
	BOW,
	KNIFE,
	SMG,
	SHOTGUN,
	SNIPER,
	LMG,
	CROSSBOW,
	MACHINE_PISTOL,
	MACHETE,
	BAT,
	FRAG,
	MOLOTOV,
	ROCK,
	# Shop specials
	SILENCED_SNIPER,
	FLAMETHROWER,
	GRENADE_LAUNCHER,
	HUNTER_BOW,
	TRANQ_PISTOL,
	THROWING_AXE,
	C4,
	PROX_MINE,
}

const OUTPOST_ID := "compound_alpha"

# Active outpost selected on Map Select
var selected_outpost_id: String = OUTPOST_ID

# 5-slot loadout (kept backward compatible with selected_primary / selected_secondary)
var selected_primary: WeaponId = WeaponId.RIFLE
var selected_secondary: WeaponId = WeaponId.PISTOL
var selected_special: WeaponId = WeaponId.BOW
var selected_throwable: WeaponId = WeaponId.KNIFE
var selected_melee: WeaponId = WeaponId.KNIFE

# Per-weapon gunsmith customization: int(WeaponId) -> {muzzle, optic, mag, underbarrel, arrow, skin}
var weapon_mods: Dictionary = {}

var has_active_run: bool = false
var outposts: Dictionary = {}  # id -> {status, guards_remaining, name, best: {}}
var last_detection: float = 0.0
var is_paused: bool = false

# Persistent player settings (saved with loadout prefs / user profile)
var mouse_look_sensitivity: float = 1.0  # PC mouse look (0.25–2.0)
var touch_look_sensitivity: float = 1.0  # mobile look-pad (0.25–2.0)
var ads_sensitivity: float = 0.55  # ADS/scope base multiplier (0.25–1.0)
## Optional per-zoom ADS multipliers (applied on top of ads_sensitivity at 4×/6×/8×)
var scope_sens_4x: float = 1.0
var scope_sens_6x: float = 0.85
var scope_sens_8x: float = 0.7
var invert_y: bool = false
var look_sensitivity: float = 1.0  # legacy alias → mouse_look_sensitivity
var touch_aim_toggle: bool = false  # false = hold Aim button, true = tap to toggle
var tap_to_fire: bool = false  # optional: short look-pad tap fires (off by default)
var graphics_quality: int = 2  # 0 Low / 1 Medium / 2 High (GraphicsQuality)
## Day/night: starting hour (0–24) and game-hours advanced per real second.
var day_start_hour: float = 14.0
var day_cycle_hours_per_second: float = 24.0 / 480.0  # ~8 real minutes per day
## PC keybind overrides: action -> {keycode, mouse}
var keybind_overrides: Dictionary = {}
var touch_btn_scale: float = 1.0
var touch_btn_opacity: float = 0.75

# Progression / shop / streaks (persisted)
var currency: int = 0
var owned_weapons: Array = []  # int WeaponId
var owned_items: Array = []  # String shop ids
var owned_abilities: Array = []  # String shop ids
var owned_streaks: Array = []  # String streak ids unlocked via first purchase
var streak_charges: Dictionary = {}  # streak_id -> int charges owned
var equipped_streaks: Array = ["", "", ""]  # up to 3 streak ids (must be owned)
var selected_streak: String = ""  # the support the Y key / SUPPORT button fires
var unlocked_mod_pack: bool = false
var unlocked_skin_pack: bool = false
## Paid gunsmith attachments unlocked (shop ids like att_red_dot). Suppressor free.
var unlocked_attachments: Array = []
## Persistent armour upgrade tier 0–3 (distinct from Field Plate Insert ability).
var armour_tier: int = 0
## Ally hire charges (Guns for Hire) — consumable per run like supports.
var ally_charges: Dictionary = {}  # ally_id -> int
var hired_ally: String = ""  # preferred ally type for next deploy
## Gadget / Lethal selection (separate from the 2 weapon slots).
var selected_gadget: String = "rock"
## selected_throwable doubles as the equipped lethal WeaponId
var run_stats: RunStats = RunStats.new()
var clearing_in_progress: bool = false

## Firearm-class weapons that can sit in the 2-slot wheel pool.
const CARRIED_WEAPON_IDS := [
	WeaponId.PISTOL, WeaponId.RIFLE, WeaponId.BOW, WeaponId.SMG, WeaponId.SHOTGUN,
	WeaponId.SNIPER, WeaponId.LMG, WeaponId.CROSSBOW, WeaponId.MACHINE_PISTOL,
	WeaponId.SILENCED_SNIPER, WeaponId.FLAMETHROWER, WeaponId.GRENADE_LAUNCHER,
	WeaponId.HUNTER_BOW, WeaponId.TRANQ_PISTOL,
]
## Lethal throwables (G key / Lethals button). Throwing knives included.
const LETHAL_WEAPON_IDS := [
	WeaponId.KNIFE, WeaponId.FRAG, WeaponId.MOLOTOV, WeaponId.THROWING_AXE,
	WeaponId.C4, WeaponId.PROX_MINE,
]
## Non-lethal gadgets (Q/T).
const GADGET_IDS := ["rock", "lure", "alarm_jammer", "smoke", "decoy"]

## World load gate — AI / detection stay frozen until the staged outpost load
## finishes and the post-spawn grace period elapses.
var world_loading: bool = false
var detection_grace_until_msec: int = 0
const DETECTION_GRACE_MS := 1500


func begin_world_load() -> void:
	world_loading = true
	detection_grace_until_msec = 0
	last_detection = 0.0


func finish_world_load(grace_ms: int = DETECTION_GRACE_MS) -> void:
	world_loading = false
	detection_grace_until_msec = Time.get_ticks_msec() + maxi(0, grace_ms)


func is_detection_frozen() -> bool:
	if world_loading:
		return true
	if detection_grace_until_msec <= 0:
		return false
	return Time.get_ticks_msec() < detection_grace_until_msec


## Await staged outpost load (smokes / tools). Returns false on timeout.
func wait_world_ready(timeout_sec: float = 45.0) -> bool:
	var waited := 0.0
	while world_loading and waited < timeout_sec:
		await get_tree().create_timer(0.2).timeout
		waited += 0.2
	return not world_loading


func _ready() -> void:
	_ensure_defaults()
	call_deferred("_load_save")


func _load_save() -> void:
	SaveManager.load_game()
	_ensure_defaults()
	apply_keybinds()


func _ensure_defaults() -> void:
	for spec in OutpostCatalog.all_outposts():
		var oid: String = String(spec["id"])
		if not outposts.has(oid):
			outposts[oid] = {
				"status": "active",
				"guards_remaining": -1,
				"name": String(spec["name"]),
				"best": {},
			}
		elif not outposts[oid].has("best"):
			outposts[oid]["best"] = {}
	if not outposts.has(selected_outpost_id):
		selected_outpost_id = OUTPOST_ID
	# Starter arsenal — always owned
	for wid in [
		WeaponId.PISTOL, WeaponId.RIFLE, WeaponId.BOW, WeaponId.KNIFE,
		WeaponId.SMG, WeaponId.SHOTGUN, WeaponId.SNIPER, WeaponId.LMG,
		WeaponId.CROSSBOW, WeaponId.MACHINE_PISTOL, WeaponId.MACHETE, WeaponId.BAT,
		WeaponId.FRAG, WeaponId.MOLOTOV,
	]:
		if not owns_weapon(wid):
			owned_weapons.append(int(wid))
	# Default suppressor on pistol so the classic stealth sidearm starts quiet
	if not weapon_mods.has(str(int(WeaponId.PISTOL))):
		weapon_mods[str(int(WeaponId.PISTOL))] = default_mods_for(WeaponId.PISTOL)
	while equipped_streaks.size() < 3:
		equipped_streaks.append("")
	if equipped_streaks.size() > 3:
		equipped_streaks = equipped_streaks.slice(0, 3)
	_migrate_attachment_unlocks()


func default_mods_for(id: WeaponId) -> Dictionary:
	## Defaults use only free attachments (suppressor free; optics/mags locked until shop).
	return {
		"muzzle": "suppressor" if id in [WeaponId.PISTOL, WeaponId.SILENCED_SNIPER] else "none",
		"optic": "iron",
		"mag": "standard",
		"underbarrel": "none",
		"arrow": "standard",
		"skin": "factory",
	}


func get_weapon_mods(id: WeaponId) -> Dictionary:
	var key := str(int(id))
	if not weapon_mods.has(key):
		weapon_mods[key] = default_mods_for(id)
	var base := default_mods_for(id)
	var saved: Dictionary = weapon_mods[key]
	for k in base.keys():
		if not saved.has(k):
			saved[k] = base[k]
	return saved


func set_weapon_mod(id: WeaponId, slot: String, value: String) -> void:
	if not owns_attachment(slot, value):
		return
	var m := get_weapon_mods(id)
	m[slot] = value
	weapon_mods[str(int(id))] = m
	SaveManager.save_game()


func start_new_run() -> void:
	has_active_run = true
	selected_outpost_id = OUTPOST_ID
	selected_primary = WeaponId.RIFLE
	selected_secondary = WeaponId.PISTOL
	selected_special = WeaponId.BOW
	selected_throwable = WeaponId.KNIFE
	selected_melee = WeaponId.KNIFE
	currency = 0
	owned_weapons.clear()
	owned_items.clear()
	owned_abilities.clear()
	owned_streaks.clear()
	streak_charges.clear()
	equipped_streaks = ["", "", ""]
	selected_streak = ""
	unlocked_mod_pack = false
	unlocked_skin_pack = false
	unlocked_attachments.clear()
	armour_tier = 0
	ally_charges.clear()
	hired_ally = ""
	outposts.clear()
	_ensure_defaults()
	SaveManager.save_game()


func owns_weapon(id: WeaponId) -> bool:
	return int(id) in owned_weapons or owned_weapons.has(int(id))


func owns_item(id: String) -> bool:
	return id in owned_items


func owns_ability(id: String) -> bool:
	return id in owned_abilities


func owns_streak(id: String) -> bool:
	## Unlocked only after purchasing at least once in the shop (never free).
	return id in owned_streaks


func get_streak_charges(id: String) -> int:
	return int(streak_charges.get(id, 0))


func add_streak_charge(id: String, amount: int = 1) -> void:
	if id == "":
		return
	var cap := StreakCatalog.max_carry(id)
	var next := mini(cap, get_streak_charges(id) + amount)
	streak_charges[id] = next
	if id not in owned_streaks:
		owned_streaks.append(id)
	if selected_streak == "" or get_streak_charges(selected_streak) <= 0:
		selected_streak = id
	_equip_streak_if_open(id)


func total_streak_charges() -> int:
	var n := 0
	for s in StreakCatalog.all_streaks():
		n += get_streak_charges(String(s["id"]))
	return n


func ensure_selected_streak() -> String:
	if selected_streak != "" and get_streak_charges(selected_streak) > 0:
		_equip_streak_if_open(selected_streak)
		return selected_streak
	for sid in equipped_streaks:
		var equipped_id := String(sid)
		if equipped_id != "" and get_streak_charges(equipped_id) > 0:
			selected_streak = equipped_id
			return selected_streak
	for s in StreakCatalog.all_streaks():
		var catalog_id := String(s["id"])
		if get_streak_charges(catalog_id) > 0:
			selected_streak = catalog_id
			_equip_streak_if_open(catalog_id)
			return selected_streak
	selected_streak = ""
	return ""


func select_streak(id: String) -> void:
	if get_streak_charges(id) <= 0:
		return
	selected_streak = id
	_equip_streak_if_open(id)


func _equip_streak_if_open(id: String) -> void:
	if id == "" or id in equipped_streaks:
		return
	for i in range(equipped_streaks.size()):
		if String(equipped_streaks[i]) == "":
			equipped_streaks[i] = id
			return


func consume_streak_charge(id: String) -> bool:
	var n := get_streak_charges(id)
	if n <= 0:
		return false
	streak_charges[id] = n - 1
	SaveManager.save_game()
	return true


func add_currency(amount: int) -> void:
	currency = maxi(0, currency + amount)
	SaveManager.save_game()


func owns_attachment(slot: String, value: String) -> bool:
	if AttachmentCatalog.is_free(slot, value):
		return true
	if slot == "skin" and value not in ["default", "factory"]:
		return unlocked_skin_pack
	if unlocked_mod_pack:
		return true
	var sid := AttachmentCatalog.shop_id_for(slot, value)
	return sid != "" and sid in unlocked_attachments


func unlock_attachment_id(shop_id: String) -> void:
	if shop_id == "" or shop_id in unlocked_attachments:
		return
	unlocked_attachments.append(shop_id)


func _migrate_attachment_unlocks() -> void:
	## Legacy mod_pack → all individual attachments. Otherwise strip unpaid equipped mods
	## (suppressor + iron/none/standard stay free).
	if unlocked_mod_pack:
		for e in AttachmentCatalog.all_attachments():
			unlock_attachment_id(String(e.get("id", "")))
	_sanitize_weapon_mods()


func _sanitize_weapon_mods() -> void:
	for key in weapon_mods.keys():
		var m: Dictionary = weapon_mods[key]
		for slot in m.keys():
			var val := String(m[slot])
			if owns_attachment(String(slot), val):
				continue
			# Reset to free default for this slot
			match String(slot):
				"muzzle": m[slot] = "none"
				"optic": m[slot] = "iron"
				"mag": m[slot] = "standard"
				"underbarrel": m[slot] = "none"
				"arrow": m[slot] = "standard"
				"skin": m[slot] = "default"
				_: m[slot] = "none"
		weapon_mods[key] = m


func get_ally_charges(ally_id: String) -> int:
	return int(ally_charges.get(ally_id, 0))


func add_ally_charge(ally_id: String, amount: int = 1) -> void:
	ally_charges[ally_id] = mini(2, get_ally_charges(ally_id) + amount)
	if hired_ally == "":
		hired_ally = ally_id
	SaveManager.save_game()


func consume_ally_charge(ally_id: String) -> bool:
	var n := get_ally_charges(ally_id)
	if n <= 0:
		return false
	ally_charges[ally_id] = n - 1
	SaveManager.save_game()
	return true


## Prefer hired_ally; else first role with charges. Consumes one charge.
func consume_hired_ally_for_deploy() -> String:
	var order: Array = []
	if hired_ally != "":
		order.append(hired_ally)
	for id in ["sniper", "stalker", "gunner", "beast"]:
		if id not in order:
			order.append(id)
	for id in order:
		if consume_ally_charge(String(id)):
			return String(id)
	return ""


func is_carried_weapon_id(id: WeaponId) -> bool:
	return id in CARRIED_WEAPON_IDS


func is_lethal_weapon_id(id: WeaponId) -> bool:
	return id in LETHAL_WEAPON_IDS


## Up to 3 unique firearms from primary / secondary / special loadout picks.
func get_carried_weapons() -> Array:
	var out: Array = []
	for wid in [selected_primary, selected_secondary, selected_special]:
		if not is_carried_weapon_id(wid):
			continue
		var found := false
		for existing in out:
			if int(existing) == int(wid):
				found = true
				break
		if not found:
			out.append(wid)
		if out.size() >= 3:
			break
	return out


## Assign a carried weapon into slot 1 (0) or slot 2 (1). Swaps if already equipped.
func assign_carried_to_slot(slot: int, wid: WeaponId) -> void:
	if not is_carried_weapon_id(wid):
		return
	if slot <= 0:
		if selected_secondary == wid:
			selected_secondary = selected_primary
		selected_primary = wid
	else:
		if selected_primary == wid:
			selected_primary = selected_secondary
		selected_secondary = wid
	SaveManager.save_game()


func owned_lethal_ids() -> Array:
	var out: Array = []
	out.append(WeaponId.KNIFE)
	for wid in LETHAL_WEAPON_IDS:
		if wid == WeaponId.KNIFE:
			continue
		if owns_weapon(wid) or wid == selected_throwable:
			out.append(wid)
	return out


func owned_gadget_ids() -> Array:
	var out: Array = ["rock"]
	for gid in ["lure", "alarm_jammer", "smoke", "decoy"]:
		if owns_item(gid):
			out.append(gid)
	return out


func gadget_display_name(gid: String) -> String:
	match gid:
		"rock": return "Rock"
		"lure": return "Lure"
		"alarm_jammer": return "Jammer"
		"smoke": return "Smoke"
		"decoy": return "Decoy"
		_: return gid.capitalize()


func lethal_display_name(wid: WeaponId) -> String:
	return WeaponData.from_id(wid).display_name


func armour_max() -> float:
	match armour_tier:
		1: return 20.0
		2: return 40.0
		3: return 60.0
		_: return 0.0


func armour_damage_mult() -> float:
	match armour_tier:
		1: return 0.85
		2: return 0.75
		3: return 0.65
		_: return 1.0


func try_purchase(entry_id: String) -> String:
	var e: Dictionary = ShopCatalog.entry(entry_id)
	if e.is_empty():
		return "Unknown item"
	var price := int(e.get("price", 0))
	var kind := String(e.get("kind", ""))
	# Already owned checks (streaks/allies are consumable — always rebuyable up to cap)
	match kind:
		"weapon":
			if owns_weapon(e.get("weapon") as WeaponId):
				return "Already owned"
		"item":
			if owns_item(entry_id):
				return "Already owned"
		"ability":
			if owns_ability(entry_id):
				return "Already owned"
		"streak":
			var sid0 := String(e.get("streak", ""))
			if get_streak_charges(sid0) >= StreakCatalog.max_carry(sid0):
				return "Carry limit reached (%d)" % StreakCatalog.max_carry(sid0)
		"ally":
			var aid0 := String(e.get("ally", ""))
			if get_ally_charges(aid0) >= 2:
				return "Carry limit reached (2)"
		"attachment":
			if entry_id in unlocked_attachments or unlocked_mod_pack:
				return "Already unlocked"
		"armour":
			var want := int(e.get("tier", 0))
			if armour_tier >= want:
				return "Already owned"
			if want > armour_tier + 1:
				return "Buy previous armour tier first"
		"mod":
			if unlocked_mod_pack:
				return "Already owned"
		"skin":
			if unlocked_skin_pack:
				return "Already owned"
	if currency < price:
		return "Need %d more Hope Dollars" % (price - currency)
	currency -= price
	match kind:
		"weapon":
			var wid: WeaponId = e.get("weapon") as WeaponId
			if not owns_weapon(wid):
				owned_weapons.append(int(wid))
		"item":
			owned_items.append(entry_id)
		"ability":
			owned_abilities.append(entry_id)
		"streak":
			var sid := String(e.get("streak", ""))
			if sid != "":
				add_streak_charge(sid, 1)
		"ally":
			var aid := String(e.get("ally", ""))
			if aid != "":
				add_ally_charge(aid, 1)
		"attachment":
			unlock_attachment_id(entry_id)
		"armour":
			armour_tier = maxi(armour_tier, int(e.get("tier", 0)))
		"mod":
			unlocked_mod_pack = true
			_migrate_attachment_unlocks()
		"skin":
			unlocked_skin_pack = true
	SaveManager.save_game()
	return ""


func set_equipped_streak(slot: int, streak_id: String) -> void:
	if slot < 0 or slot > 2:
		return
	if streak_id != "" and not owns_streak(streak_id):
		return
	equipped_streaks[slot] = streak_id
	SaveManager.save_game()


func begin_deploy_stats() -> void:
	run_stats = RunStats.new()
	run_stats.begin()
	clearing_in_progress = false


func record_best_clear(outpost_id: String, stats: Dictionary, payout: int) -> void:
	if not outposts.has(outpost_id):
		_ensure_defaults()
	var best: Dictionary = outposts[outpost_id].get("best", {})
	var prev_payout := int(best.get("payout", 0))
	if payout >= prev_payout:
		best = stats.duplicate(true)
		best["payout"] = payout
		best["when"] = Time.get_unix_time_from_system()
	outposts[outpost_id]["best"] = best
	outposts[outpost_id]["status"] = "liberated"
	outposts[outpost_id]["guards_remaining"] = 0
	SaveManager.save_game()


func continue_run() -> bool:
	return has_active_run


func select_outpost(outpost_id: String) -> void:
	if not outposts.has(outpost_id):
		_ensure_defaults()
	selected_outpost_id = outpost_id
	SaveManager.save_game()


func set_loadout(primary: WeaponId, secondary: WeaponId = WeaponId.KNIFE) -> void:
	selected_primary = primary
	selected_secondary = secondary
	SaveManager.save_game()


func set_full_loadout(primary: WeaponId, secondary: WeaponId, special: WeaponId, throwable: WeaponId, melee: WeaponId) -> void:
	selected_primary = primary
	selected_secondary = secondary
	selected_special = special
	selected_throwable = throwable
	selected_melee = melee
	SaveManager.save_game()


func mark_liberated(outpost_id: String = "") -> void:
	var oid := outpost_id if outpost_id != "" else selected_outpost_id
	if not outposts.has(oid):
		_ensure_defaults()
	outposts[oid]["status"] = "liberated"
	outposts[oid]["guards_remaining"] = 0
	outpost_liberated.emit(oid)
	outpost_status_changed.emit(oid, "liberated")
	SaveManager.save_game()


func is_liberated(outpost_id: String = "") -> bool:
	var oid := outpost_id if outpost_id != "" else selected_outpost_id
	return outposts.get(oid, {}).get("status", "active") == "liberated"


func liberated_count() -> int:
	var c := 0
	for oid in OutpostCatalog.all_ids():
		if is_liberated(oid):
			c += 1
	return c


func total_outposts() -> int:
	return OutpostCatalog.all_ids().size()


func set_guards_remaining(count: int, outpost_id: String = "") -> void:
	var oid := outpost_id if outpost_id != "" else selected_outpost_id
	if not outposts.has(oid):
		_ensure_defaults()
	outposts[oid]["guards_remaining"] = count
	# Beating is handled by the 3s clear countdown + results flow (not instant)


func weapon_name(id: WeaponId) -> String:
	match id:
		WeaponId.PISTOL:
			return "Tactical Pistol"
		WeaponId.RIFLE:
			return "Assault Rifle"
		WeaponId.BOW:
			return "Compound Bow"
		WeaponId.KNIFE:
			return "Throwing Knife"
		WeaponId.SMG:
			return "MP5 SMG"
		WeaponId.SHOTGUN:
			return "Pump Shotgun"
		WeaponId.SNIPER:
			return "Bolt Sniper"
		WeaponId.LMG:
			return "M60 LMG"
		WeaponId.CROSSBOW:
			return "Tactical Crossbow"
		WeaponId.MACHINE_PISTOL:
			return "Auto Pistol"
		WeaponId.MACHETE:
			return "Machete"
		WeaponId.BAT:
			return "Aluminum Bat"
		WeaponId.FRAG:
			return "Frag Grenade"
		WeaponId.MOLOTOV:
			return "Molotov Cocktail"
		WeaponId.ROCK:
			return "Distraction Rock"
		WeaponId.SILENCED_SNIPER:
			return "Silenced Sniper"
		WeaponId.FLAMETHROWER:
			return "Flamethrower"
		WeaponId.GRENADE_LAUNCHER:
			return "Grenade Launcher"
		WeaponId.HUNTER_BOW:
			return "Hunter Recurve"
		WeaponId.TRANQ_PISTOL:
			return "Tranq Pistol"
		WeaponId.THROWING_AXE:
			return "Throwing Axe"
		WeaponId.C4:
			return "C4 Charge"
		WeaponId.PROX_MINE:
			return "Proximity Mine"
	return "Unknown"


func serialize_loadout() -> Dictionary:
	return {
		"selected_primary": int(selected_primary),
		"selected_secondary": int(selected_secondary),
		"selected_special": int(selected_special),
		"selected_throwable": int(selected_throwable),
		"selected_melee": int(selected_melee),
		"weapon_mods": weapon_mods.duplicate(true),
		"mouse_look_sensitivity": mouse_look_sensitivity,
		"touch_look_sensitivity": touch_look_sensitivity,
		"ads_sensitivity": ads_sensitivity,
		"scope_sens_4x": scope_sens_4x,
		"scope_sens_6x": scope_sens_6x,
		"scope_sens_8x": scope_sens_8x,
		"invert_y": invert_y,
		"look_sensitivity": mouse_look_sensitivity,  # legacy key
		"touch_aim_toggle": touch_aim_toggle,
		"tap_to_fire": tap_to_fire,
		"graphics_quality": graphics_quality,
		"day_start_hour": day_start_hour,
		"day_cycle_hours_per_second": day_cycle_hours_per_second,
		"keybind_overrides": keybind_overrides.duplicate(true),
		"touch_btn_scale": touch_btn_scale,
		"touch_btn_opacity": touch_btn_opacity,
	}


func deserialize_loadout(data: Dictionary) -> void:
	selected_primary = int(data.get("selected_primary", selected_primary)) as WeaponId
	selected_secondary = int(data.get("selected_secondary", selected_secondary)) as WeaponId
	selected_special = int(data.get("selected_special", selected_special)) as WeaponId
	selected_throwable = int(data.get("selected_throwable", selected_throwable)) as WeaponId
	selected_melee = int(data.get("selected_melee", selected_melee)) as WeaponId
	var loaded_mods = data.get("weapon_mods", {})
	if loaded_mods is Dictionary:
		weapon_mods = (loaded_mods as Dictionary).duplicate(true)
	ads_sensitivity = clampf(float(data.get("ads_sensitivity", ads_sensitivity)), 0.25, 1.0)
	# Prefer new keys; fall back to legacy look_sensitivity for mouse
	var legacy_look := float(data.get("look_sensitivity", mouse_look_sensitivity))
	mouse_look_sensitivity = clampf(float(data.get("mouse_look_sensitivity", legacy_look)), 0.25, 2.0)
	touch_look_sensitivity = clampf(float(data.get("touch_look_sensitivity", mouse_look_sensitivity)), 0.25, 2.0)
	scope_sens_4x = clampf(float(data.get("scope_sens_4x", scope_sens_4x)), 0.25, 1.5)
	scope_sens_6x = clampf(float(data.get("scope_sens_6x", scope_sens_6x)), 0.25, 1.5)
	scope_sens_8x = clampf(float(data.get("scope_sens_8x", scope_sens_8x)), 0.25, 1.5)
	invert_y = bool(data.get("invert_y", invert_y))
	look_sensitivity = mouse_look_sensitivity
	touch_aim_toggle = bool(data.get("touch_aim_toggle", touch_aim_toggle))
	tap_to_fire = bool(data.get("tap_to_fire", tap_to_fire))
	graphics_quality = clampi(int(data.get("graphics_quality", graphics_quality)), 0, 2)
	day_start_hour = clampf(float(data.get("day_start_hour", day_start_hour)), 0.0, 23.99)
	day_cycle_hours_per_second = clampf(float(data.get("day_cycle_hours_per_second", day_cycle_hours_per_second)), 0.0, 2.0)
	var kb = data.get("keybind_overrides", {})
	if kb is Dictionary:
		keybind_overrides = (kb as Dictionary).duplicate(true)
	touch_btn_scale = clampf(float(data.get("touch_btn_scale", touch_btn_scale)), 0.7, 1.4)
	touch_btn_opacity = clampf(float(data.get("touch_btn_opacity", touch_btn_opacity)), 0.35, 1.0)
	_ensure_defaults()
	apply_keybinds()


func set_mouse_look_sensitivity(value: float) -> void:
	mouse_look_sensitivity = clampf(value, 0.25, 2.0)
	look_sensitivity = mouse_look_sensitivity
	SaveManager.save_loadout()


func set_touch_look_sensitivity(value: float) -> void:
	touch_look_sensitivity = clampf(value, 0.25, 2.0)
	SaveManager.save_loadout()


func set_ads_sensitivity(value: float) -> void:
	ads_sensitivity = clampf(value, 0.25, 1.0)
	SaveManager.save_loadout()


func set_scope_sens_4x(value: float) -> void:
	scope_sens_4x = clampf(value, 0.25, 1.5)
	SaveManager.save_loadout()


func set_scope_sens_6x(value: float) -> void:
	scope_sens_6x = clampf(value, 0.25, 1.5)
	SaveManager.save_loadout()


func set_scope_sens_8x(value: float) -> void:
	scope_sens_8x = clampf(value, 0.25, 1.5)
	SaveManager.save_loadout()


func set_invert_y(enabled: bool) -> void:
	invert_y = enabled
	SaveManager.save_loadout()


func set_touch_btn_scale(value: float) -> void:
	touch_btn_scale = clampf(value, 0.7, 1.4)
	SaveManager.save_loadout()


func set_touch_btn_opacity(value: float) -> void:
	touch_btn_opacity = clampf(value, 0.35, 1.0)
	SaveManager.save_loadout()


func set_keybind(action: String, keycode: int, is_mouse: bool = false) -> void:
	keybind_overrides[action] = {"keycode": keycode, "mouse": is_mouse}
	apply_keybinds()
	SaveManager.save_loadout()


func reset_keybinds() -> void:
	keybind_overrides.clear()
	apply_keybinds()
	SaveManager.save_loadout()


func apply_keybinds() -> void:
	InputBindings.apply_overrides(keybind_overrides)
	# Keep T as alternate for gadget unless rebound away from Q default
	if not keybind_overrides.has("use_gadget") or int(keybind_overrides["use_gadget"].get("keycode", KEY_Q)) == KEY_Q:
		if InputMap.has_action("use_gadget"):
			var has_t := false
			for ev in InputMap.action_get_events("use_gadget"):
				if ev is InputEventKey and (ev as InputEventKey).physical_keycode == KEY_T:
					has_t = true
			if not has_t:
				var kb := InputEventKey.new()
				kb.physical_keycode = KEY_T
				InputMap.action_add_event("use_gadget", kb)


func set_look_sensitivity(value: float) -> void:
	## Legacy API — routes to mouse look.
	set_mouse_look_sensitivity(value)


func get_scope_zoom_sens_mult(zoom_mult: float) -> float:
	## Extra ADS multiplier for variable sniper zoom steps.
	var z := int(round(zoom_mult))
	match z:
		6:
			return scope_sens_6x
		8:
			return scope_sens_8x
		_:
			return scope_sens_4x


func set_touch_aim_toggle(enabled: bool) -> void:
	touch_aim_toggle = enabled
	SaveManager.save_loadout()


func set_tap_to_fire(enabled: bool) -> void:
	tap_to_fire = enabled
	SaveManager.save_loadout()


func set_graphics_quality(value: int) -> void:
	graphics_quality = clampi(value, 0, 2)
	SaveManager.save_loadout()
	if GraphicsQuality and GraphicsQuality.level != graphics_quality:
		GraphicsQuality.set_level(graphics_quality)


func set_day_start_hour(value: float) -> void:
	day_start_hour = clampf(value, 0.0, 23.99)
	if DayNightCycle:
		DayNightCycle.start_hour = day_start_hour
		DayNightCycle.set_hour(day_start_hour)
	SaveManager.save_loadout()


func set_day_cycle_hours_per_second(value: float) -> void:
	day_cycle_hours_per_second = clampf(value, 0.0, 2.0)
	if DayNightCycle:
		DayNightCycle.cycle_hours_per_second = day_cycle_hours_per_second
	SaveManager.save_loadout()


func cycle_day_start_preset() -> float:
	## Cycles common start times: dawn / noon / dusk / night.
	var presets := [6.0, 12.0, 18.5, 22.0]
	var best_i := 0
	var best_d := 99.0
	for i in range(presets.size()):
		var d := absf(presets[i] - day_start_hour)
		if d < best_d:
			best_d = d
			best_i = i
	var next: float = presets[(best_i + 1) % presets.size()]
	set_day_start_hour(next)
	return next


func serialize() -> Dictionary:
	return {
		"has_active_run": has_active_run,
		"selected_outpost_id": selected_outpost_id,
		"selected_primary": int(selected_primary),
		"selected_secondary": int(selected_secondary),
		"selected_special": int(selected_special),
		"selected_throwable": int(selected_throwable),
		"selected_melee": int(selected_melee),
		"weapon_mods": weapon_mods.duplicate(true),
		"outposts": outposts.duplicate(true),
		"currency": currency,
		"owned_weapons": owned_weapons.duplicate(),
		"owned_items": owned_items.duplicate(),
		"owned_abilities": owned_abilities.duplicate(),
		"owned_streaks": owned_streaks.duplicate(),
		"streak_charges": streak_charges.duplicate(),
		"equipped_streaks": equipped_streaks.duplicate(),
		"selected_streak": selected_streak,
		"unlocked_mod_pack": unlocked_mod_pack,
		"unlocked_skin_pack": unlocked_skin_pack,
		"unlocked_attachments": unlocked_attachments.duplicate(),
		"armour_tier": armour_tier,
		"ally_charges": ally_charges.duplicate(),
		"hired_ally": hired_ally,
	}


func deserialize(data: Dictionary) -> void:
	has_active_run = bool(data.get("has_active_run", false))
	selected_outpost_id = String(data.get("selected_outpost_id", OUTPOST_ID))
	selected_primary = int(data.get("selected_primary", WeaponId.PISTOL)) as WeaponId
	selected_secondary = int(data.get("selected_secondary", WeaponId.KNIFE)) as WeaponId
	selected_special = int(data.get("selected_special", WeaponId.BOW)) as WeaponId
	selected_throwable = int(data.get("selected_throwable", WeaponId.KNIFE)) as WeaponId
	selected_melee = int(data.get("selected_melee", WeaponId.KNIFE)) as WeaponId
	var loaded_mods = data.get("weapon_mods", {})
	if loaded_mods is Dictionary:
		weapon_mods = (loaded_mods as Dictionary).duplicate(true)
	var loaded_outposts = data.get("outposts", {})
	if loaded_outposts is Dictionary and not (loaded_outposts as Dictionary).is_empty():
		outposts = (loaded_outposts as Dictionary).duplicate(true)
	currency = int(data.get("currency", 0))
	var ow = data.get("owned_weapons", [])
	if ow is Array:
		owned_weapons = (ow as Array).duplicate()
	var oi = data.get("owned_items", [])
	if oi is Array:
		owned_items = (oi as Array).duplicate()
	var oa = data.get("owned_abilities", [])
	if oa is Array:
		owned_abilities = (oa as Array).duplicate()
	var os = data.get("owned_streaks", [])
	if os is Array:
		owned_streaks = (os as Array).duplicate()
	var sc = data.get("streak_charges", {})
	if sc is Dictionary:
		streak_charges = (sc as Dictionary).duplicate()
	else:
		streak_charges.clear()
	var es = data.get("equipped_streaks", ["", "", ""])
	if es is Array:
		equipped_streaks = (es as Array).duplicate()
	# Never invent free unlocks — charges without ownership are treated as prior purchases
	for cid in streak_charges.keys():
		var cid_s := String(cid)
		if get_streak_charges(cid_s) > 0 and cid_s not in owned_streaks:
			owned_streaks.append(cid_s)
	# Strip equipped slots that were never purchased
	for i in range(equipped_streaks.size()):
		var sid := String(equipped_streaks[i])
		if sid != "" and sid not in owned_streaks:
			equipped_streaks[i] = ""
	selected_streak = String(data.get("selected_streak", ""))
	if selected_streak != "" and get_streak_charges(selected_streak) <= 0:
		selected_streak = ""
	ensure_selected_streak()
	unlocked_mod_pack = bool(data.get("unlocked_mod_pack", false))
	unlocked_skin_pack = bool(data.get("unlocked_skin_pack", false))
	var ua = data.get("unlocked_attachments", [])
	if ua is Array:
		unlocked_attachments = (ua as Array).duplicate()
	armour_tier = clampi(int(data.get("armour_tier", 0)), 0, 3)
	var ac = data.get("ally_charges", {})
	if ac is Dictionary:
		ally_charges = (ac as Dictionary).duplicate()
	hired_ally = String(data.get("hired_ally", ""))
	_ensure_defaults()
	_migrate_attachment_unlocks()
