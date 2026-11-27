extends Node
## Optional: set AUTO_CAPTURE=1 to save screenshots after boot for docs.


func _ready() -> void:
	if OS.get_environment("AUTO_CAPTURE") != "1":
		return
	await get_tree().create_timer(2.5).timeout
	_capture("01_main_menu")
	# If somehow in-game already
	await get_tree().create_timer(0.5).timeout


func capture_named(name: String) -> void:
	_capture(name)


func _capture(name: String) -> void:
	var img := get_viewport().get_texture().get_image()
	if img == null:
		return
	var dir := "user://screenshots"
	DirAccess.make_dir_recursive_absolute(dir)
	var path := "%s/%s.png" % [dir, name]
	img.save_png(path)
	# Also copy next to project docs if possible
	var project_path := ProjectSettings.globalize_path("res://docs/screenshots/%s.png" % name)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://docs/screenshots"))
	img.save_png(project_path)
	print("Screenshot saved: ", path, " / ", project_path)
