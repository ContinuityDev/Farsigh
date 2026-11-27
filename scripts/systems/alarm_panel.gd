extends StaticBody3D
class_name AlarmPanel
## Guard-activated alarm that spawns reinforcements. Player can disable it.

signal alarm_triggered
signal alarm_disabled

@export var reinforcement_scene: PackedScene
@export var reinforcement_points: Array[NodePath] = []
@export var max_reinforcements: int = 2

var disabled: bool = false
var triggered: bool = false
var _spawned: int = 0

@onready var mesh: MeshInstance3D = $MeshInstance3D
@onready var label: Label3D = $Label3D


func _ready() -> void:
	add_to_group("alarms")
	collision_layer = 32
	if reinforcement_points.is_empty():
		var a := get_parent().get_node_or_null("ReinforceA")
		var b := get_parent().get_node_or_null("ReinforceB")
		if a:
			reinforcement_points.append(a.get_path())
		if b:
			reinforcement_points.append(b.get_path())
	_update_visual()


func is_disabled() -> bool:
	return disabled


func trigger(_by: Node = null) -> void:
	if disabled or triggered:
		return
	triggered = true
	alarm_triggered.emit()
	_update_visual()
	# Officers call in extra reinforcements (faster / denser response)
	var extra := 0
	if is_instance_valid(_by) and bool(_by.get("is_officer")):
		extra = 2
	_spawn_reinforcements(extra)
	var hud := get_tree().get_first_node_in_group("hud")
	if is_instance_valid(hud) and hud.has_method("show_status"):
		if extra > 0:
			hud.show_status("OFFICER ALARM — heavy reinforcements inbound!", 3.8)
		else:
			hud.show_status("ALARM — reinforcements inbound!", 3.5)


func interact(player: Node) -> void:
	if disabled:
		return
	disabled = true
	triggered = false
	alarm_disabled.emit()
	_update_visual()
	NoiseBus.emit_noise(global_position, 2.0, "alarm_disable")
	var hud := get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("show_status"):
		hud.show_status("Alarm disabled", 2.0)


func _spawn_reinforcements(extra: int = 0) -> void:
	if reinforcement_scene == null:
		reinforcement_scene = preload("res://scenes/enemies/guard.tscn")
	var tree := get_tree()
	if tree == null:
		return
	var outpost := tree.get_first_node_in_group("outpost")
	var scene := tree.current_scene
	var cap := max_reinforcements + maxi(0, extra)
	# Cycle reinforce points so officer extras still spawn even with 2 markers
	var paths: Array = reinforcement_points.duplicate()
	if paths.is_empty():
		return
	var i := 0
	while _spawned < cap:
		var path = paths[i % paths.size()]
		i += 1
		var marker := get_node_or_null(path)
		if not is_instance_valid(marker):
			if i > paths.size() * 3:
				break
			continue
		var g := reinforcement_scene.instantiate()
		if is_instance_valid(outpost):
			outpost.add_child(g)
		elif is_instance_valid(scene):
			scene.add_child(g)
		else:
			g.free()
			break
		if g is Node3D and marker is Node3D:
			var jitter := Vector3(randf_range(-1.2, 1.2), 0.0, randf_range(-1.2, 1.2))
			(g as Node3D).global_position = (marker as Node3D).global_position + jitter
		if g.has_method("_set_state"):
			g._set_state(GuardAI.State.COMBAT)
		_spawned += 1
		if is_instance_valid(outpost) and outpost.has_method("register_guard"):
			outpost.register_guard(g)
		if i > cap * 4:
			break


func _update_visual() -> void:
	var mat := StandardMaterial3D.new()
	if disabled:
		mat.albedo_color = Color(0.2, 0.5, 0.25)
		if label:
			label.text = "ALARM OFF"
	elif triggered:
		mat.albedo_color = Color(0.95, 0.15, 0.1)
		if label:
			label.text = "ALARM!"
	else:
		mat.albedo_color = Color(0.8, 0.55, 0.1)
		if label:
			label.text = "ALARM"
	if mesh:
		mesh.material_override = mat
