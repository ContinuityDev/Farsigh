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
var outposts: Dictionary = {}  # id -> {status: "active"|"liberated", guards_remaining: int, name: String}
var last_detection: float = 0.0
var is_paused: bool = false


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
			}
	if not outposts.has(selected_outpost_id):
		selected_outpost_id = OUTPOST_ID
	# Default suppressor on pistol so the classic stealth sidearm starts quiet
	if not weapon_mods.has(str(int(WeaponId.PISTOL))):
		weapon_mods[str(int(WeaponId.PISTOL))] = default_mods_for(WeaponId.PISTOL)


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
	selected_primary = WeaponId.PISTOL
	selected_secondary = WeaponId.KNIFE
	selected_special = WeaponId.BOW
	selected_throwable = WeaponId.KNIFE
	selected_melee = WeaponId.KNIFE
	outposts.clear()
	_ensure_defaults()
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
	if count <= 0 and outposts[oid]["status"] != "liberated":
		mark_liberated(oid)


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
	return "Unknown"


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
	_ensure_defaults()
