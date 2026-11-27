extends Node
## Global run state: loadout, outpost progress, session flags.

signal outpost_liberated(outpost_id: String)
signal outpost_status_changed(outpost_id: String, status: String)
signal detection_max_changed(value: float)
signal player_spotted()

enum WeaponId { PISTOL, RIFLE, BOW, KNIFE }

const OUTPOST_ID := "compound_alpha"

var selected_primary: WeaponId = WeaponId.PISTOL
var selected_secondary: WeaponId = WeaponId.KNIFE
var has_active_run: bool = false
var outposts: Dictionary = {}  # id -> {status: "active"|"liberated", guards_remaining: int}
var last_detection: float = 0.0
var is_paused: bool = false


func _ready() -> void:
	_ensure_defaults()
	call_deferred("_load_save")


func _load_save() -> void:
	SaveManager.load_game()


func _ensure_defaults() -> void:
	if not outposts.has(OUTPOST_ID):
		outposts[OUTPOST_ID] = {
			"status": "active",
			"guards_remaining": -1,
			"name": "Hope County Compound"
		}


func start_new_run() -> void:
	has_active_run = true
	selected_primary = WeaponId.PISTOL
	selected_secondary = WeaponId.KNIFE
	outposts[OUTPOST_ID] = {
		"status": "active",
		"guards_remaining": -1,
		"name": "Hope County Compound"
	}
	SaveManager.save_game()


func continue_run() -> bool:
	if not has_active_run:
		return false
	return true


func set_loadout(primary: WeaponId, secondary: WeaponId = WeaponId.KNIFE) -> void:
	selected_primary = primary
	selected_secondary = secondary
	SaveManager.save_game()


func mark_liberated(outpost_id: String = OUTPOST_ID) -> void:
	if not outposts.has(outpost_id):
		return
	outposts[outpost_id]["status"] = "liberated"
	outposts[outpost_id]["guards_remaining"] = 0
	outpost_liberated.emit(outpost_id)
	outpost_status_changed.emit(outpost_id, "liberated")
	SaveManager.save_game()


func is_liberated(outpost_id: String = OUTPOST_ID) -> bool:
	return outposts.get(outpost_id, {}).get("status", "active") == "liberated"


func set_guards_remaining(count: int, outpost_id: String = OUTPOST_ID) -> void:
	if not outposts.has(outpost_id):
		_ensure_defaults()
	outposts[outpost_id]["guards_remaining"] = count
	if count <= 0 and outposts[outpost_id]["status"] != "liberated":
		mark_liberated(outpost_id)


func weapon_name(id: WeaponId) -> String:
	match id:
		WeaponId.PISTOL:
			return "Suppressed Pistol"
		WeaponId.RIFLE:
			return "Assault Rifle"
		WeaponId.BOW:
			return "Hunting Bow"
		WeaponId.KNIFE:
			return "Throwing Knife"
	return "Unknown"


func serialize() -> Dictionary:
	return {
		"has_active_run": has_active_run,
		"selected_primary": int(selected_primary),
		"selected_secondary": int(selected_secondary),
		"outposts": outposts.duplicate(true),
	}


func deserialize(data: Dictionary) -> void:
	has_active_run = data.get("has_active_run", false)
	selected_primary = int(data.get("selected_primary", WeaponId.PISTOL)) as WeaponId
	selected_secondary = int(data.get("selected_secondary", WeaponId.KNIFE)) as WeaponId
	var loaded_outposts: Dictionary = data.get("outposts", {})
	if loaded_outposts.is_empty():
		_ensure_defaults()
	else:
		outposts = loaded_outposts
