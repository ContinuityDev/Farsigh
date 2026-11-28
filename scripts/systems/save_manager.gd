extends Node
## Disk persistence for campaign progress. On desktop/native this is a normal
## user:// file; on HTML5/Web Godot maps user:// to IndexedDB so progress
## survives page reloads.

const SAVE_PATH := "user://outpost_save.json"
const LOADOUT_PATH := "user://loadout_prefs.json"
const PROFILE_VERSION := 4


func save_game() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file != null:
		var payload := {
			"version": PROFILE_VERSION,
			"game": GameState.serialize(),
		}
		file.store_string(JSON.stringify(payload, "\t"))
		file.close()
	else:
		push_warning("SaveManager: could not open save file for writing")
	save_loadout()


func save_loadout() -> void:
	var file := FileAccess.open(LOADOUT_PATH, FileAccess.WRITE)
	if file == null:
		return
	var payload := {
		"version": PROFILE_VERSION,
		"loadout": GameState.serialize_loadout(),
	}
	file.store_string(JSON.stringify(payload, "\t"))
	file.close()


func load_game() -> bool:
	load_loadout()
	if not FileAccess.file_exists(SAVE_PATH):
		return false
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return false
	var text := file.get_as_text()
	file.close()
	var data = JSON.parse_string(text)
	if typeof(data) != TYPE_DICTIONARY:
		return false
	var game: Dictionary = data.get("game", {})
	GameState.deserialize(game)
	# Re-apply dedicated loadout prefs if present so gunsmith customizations always persist
	load_loadout()
	return true


func load_loadout() -> bool:
	if not FileAccess.file_exists(LOADOUT_PATH):
		return false
	var file := FileAccess.open(LOADOUT_PATH, FileAccess.READ)
	if file == null:
		return false
	var text := file.get_as_text()
	file.close()
	var data = JSON.parse_string(text)
	if typeof(data) != TYPE_DICTIONARY:
		return false
	var lo: Dictionary = data.get("loadout", {})
	GameState.deserialize_loadout(lo)
	return true


func clear_save() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)
	GameState.has_active_run = false
	GameState.currency = 0
	GameState.owned_weapons.clear()
	GameState.owned_items.clear()
	GameState.owned_abilities.clear()
	GameState.owned_streaks.clear()
	GameState.streak_charges.clear()
	GameState.equipped_streaks = ["", "", ""]
	GameState.selected_streak = ""
	GameState.unlocked_mod_pack = false
	GameState.unlocked_skin_pack = false
	GameState.outposts.clear()
	GameState._ensure_defaults()
