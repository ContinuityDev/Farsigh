extends Node
## Disk persistence for run state and liberated outposts.

const SAVE_PATH := "user://outpost_save.json"


func save_game() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("SaveManager: could not open save file for writing")
		return
	var payload := {
		"version": 1,
		"game": GameState.serialize(),
	}
	file.store_string(JSON.stringify(payload, "\t"))
	file.close()


func load_game() -> bool:
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
	return true


func clear_save() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)
	GameState.has_active_run = false
	GameState.outposts.clear()
	GameState._ensure_defaults()
