extends Node
## Global run state: selected outpost, per-outpost liberation persistence,
## 5-slot loadout, and gunsmith weapon customization.

const OutpostCatalog = preload("res://scripts/levels/outpost_catalog.gd")

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

# Persistent player settings (saved with loadout prefs)
var ads_sensitivity: float = 0.55  # multiplier applied while aiming (0.25–1.0)
var touch_aim_toggle: bool = false  # false = hold Aim button, true = tap to toggle
var tap_to_fire: bool = false  # optional: short look-pad tap fires (off by default)

# Progression / shop / streaks (persisted)
var currency: int = 0
var owned_weapons: Array = []  # int WeaponId
var owned_items: Array = []  # String shop ids
var owned_abilities: Array = []  # String shop ids
var owned_streaks: Array = []  # String streak ids
var equipped_streaks: Array = ["", "", ""]  # up to 3 streak ids
var unlocked_mod_pack: bool = false
var unlocked_skin_pack: bool = false
var run_stats: RunStats = RunStats.new()
var clearing_in_progress: bool = false

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


func default_mods_for(id: WeaponId) -> Dictionary:
	return {
		"muzzle": "suppressor" if id == WeaponId.PISTOL else "none",
		"optic": "scope" if id == WeaponId.SNIPER else ("red_dot" if id == WeaponId.RIFLE else "iron"),
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
	equipped_streaks = ["", "", ""]
	unlocked_mod_pack = false
	unlocked_skin_pack = false
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
	return id in owned_streaks


func add_currency(amount: int) -> void:
	currency = maxi(0, currency + amount)
	SaveManager.save_game()


func try_purchase(entry_id: String) -> String:
	var e: Dictionary = ShopCatalog.entry(entry_id)
	if e.is_empty():
		return "Unknown item"
	var price := int(e.get("price", 0))
	var kind := String(e.get("kind", ""))
	# Already owned checks
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
			if owns_streak(String(e.get("streak", ""))):
				return "Already owned"
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
			if sid != "" and not owns_streak(sid):
				owned_streaks.append(sid)
		"mod":
			unlocked_mod_pack = true
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
		"ads_sensitivity": ads_sensitivity,
		"touch_aim_toggle": touch_aim_toggle,
		"tap_to_fire": tap_to_fire,
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
	touch_aim_toggle = bool(data.get("touch_aim_toggle", touch_aim_toggle))
	tap_to_fire = bool(data.get("tap_to_fire", tap_to_fire))
	_ensure_defaults()


func set_ads_sensitivity(value: float) -> void:
	ads_sensitivity = clampf(value, 0.25, 1.0)
	SaveManager.save_loadout()


func set_touch_aim_toggle(enabled: bool) -> void:
	touch_aim_toggle = enabled
	SaveManager.save_loadout()


func set_tap_to_fire(enabled: bool) -> void:
	tap_to_fire = enabled
	SaveManager.save_loadout()


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
		"equipped_streaks": equipped_streaks.duplicate(),
		"unlocked_mod_pack": unlocked_mod_pack,
		"unlocked_skin_pack": unlocked_skin_pack,
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
	var es = data.get("equipped_streaks", ["", "", ""])
	if es is Array:
		equipped_streaks = (es as Array).duplicate()
	unlocked_mod_pack = bool(data.get("unlocked_mod_pack", false))
	unlocked_skin_pack = bool(data.get("unlocked_skin_pack", false))
	_ensure_defaults()
