extends CanvasLayer
## Crosshair, ammo, detection meter, status messages, pause overlay.

@onready var crosshair: Control = $Root/Crosshair
@onready var ammo_label: Label = $Root/AmmoLabel
@onready var weapon_label: Label = $Root/WeaponLabel
@onready var detection_bar: ProgressBar = $Root/DetectionBar
@onready var detection_label: Label = $Root/DetectionLabel
@onready var status_label: Label = $Root/StatusLabel
@onready var guards_label: Label = $Root/GuardsLabel
@onready var liberated_banner: Label = $Root/LiberatedBanner
@onready var pause_panel: Control = $Root/PausePanel
@onready var rocks_label: Label = $Root/RocksLabel
@onready var touch_controls: Control = $TouchControls

var _status_timer: float = 0.0
var _detection_display: float = 0.0


func _ready() -> void:
	add_to_group("hud")
	process_mode = Node.PROCESS_MODE_ALWAYS
	pause_panel.visible = false
	liberated_banner.visible = false
	status_label.text = ""
	detection_bar.value = 0
	if touch_controls:
		touch_controls.visible = TouchInput.is_touch_ui_desired()
	var player := get_tree().get_first_node_in_group("player")
	if player:
		_bind_player(player)
	else:
		call_deferred("_late_bind")


func _late_bind() -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player:
		_bind_player(player)


func _bind_player(player: Node) -> void:
	if player.has_signal("detection_changed"):
		player.detection_changed.connect(_on_detection)
	if player.has_node("WeaponManager"):
		var wm = player.get_node("WeaponManager")
		if wm.has_signal("ammo_changed"):
			wm.ammo_changed.connect(_on_ammo)
			wm._emit_ammo()


func _process(delta: float) -> void:
	if _status_timer > 0.0:
		_status_timer -= delta
		if _status_timer <= 0.0:
			status_label.text = ""
	# Smooth decay of detection meter when not updated
	_detection_display = move_toward(_detection_display, GameState.last_detection, delta * 2.0)
	detection_bar.value = _detection_display * 100.0
	detection_bar.modulate = Color(0.3, 0.9, 0.4).lerp(Color(0.95, 0.2, 0.15), _detection_display)
	var player := get_tree().get_first_node_in_group("player")
	if player and "rock_count" in player:
		rocks_label.text = "Rocks: %d" % player.rock_count


func _on_detection(value: float) -> void:
	_detection_display = maxf(_detection_display, value)
	GameState.last_detection = value


func _on_ammo(mag: int, reserve: int, weapon_name: String) -> void:
	ammo_label.text = "%d / %d" % [mag, reserve]
	weapon_label.text = weapon_name


func set_guard_count(n: int) -> void:
	guards_label.text = "Hostiles: %d" % n


func show_status(text: String, duration: float = 2.5) -> void:
	status_label.text = text
	_status_timer = duration


func show_liberation(name: String) -> void:
	show_status("OUTPOST LIBERATED — %s" % name, 6.0)
	set_liberated_banner(true)


func set_liberated_banner(on: bool) -> void:
	liberated_banner.visible = on
	if on:
		liberated_banner.text = "LIBERATED"


func set_paused(paused: bool) -> void:
	pause_panel.visible = paused


func _on_resume_pressed() -> void:
	GameState.is_paused = false
	get_tree().paused = false
	pause_panel.visible = false
	if not TouchInput.is_touch_ui_desired():
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _on_menu_pressed() -> void:
	GameState.is_paused = false
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")
