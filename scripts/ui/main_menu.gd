extends Control


@onready var continue_btn: Button = $Center/VBox/ContinueBtn
@onready var new_run_btn: Button = $Center/VBox/NewRunBtn
@onready var quit_btn: Button = $Center/VBox/QuitBtn
@onready var status: Label = $Center/VBox/StatusLabel
@onready var subtitle: Label = $Center/VBox/Subtitle


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().paused = false
	GameState.is_paused = false
	continue_btn.disabled = not GameState.has_active_run
	_refresh_status()
	# Touch-friendly minimum sizes
	for b in [continue_btn, new_run_btn, quit_btn]:
		b.custom_minimum_size = Vector2(280, 56)


func _refresh_status() -> void:
	if GameState.is_liberated():
		status.text = "Hope County Compound — Liberated"
		status.modulate = Color(0.55, 0.9, 0.55)
	elif GameState.has_active_run:
		status.text = "Hope County Compound — Contested"
		status.modulate = Color(0.95, 0.75, 0.4)
	else:
		status.text = "No active run"
		status.modulate = Color(0.75, 0.75, 0.75)


func _on_continue_pressed() -> void:
	if not GameState.continue_run():
		return
	get_tree().change_scene_to_file("res://scenes/ui/loadout.tscn")


func _on_new_run_pressed() -> void:
	SaveManager.clear_save()
	GameState.start_new_run()
	get_tree().change_scene_to_file("res://scenes/ui/loadout.tscn")


func _on_quit_pressed() -> void:
	get_tree().quit()
