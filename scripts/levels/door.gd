extends Node3D
class_name InteractiveDoor
## Hinged interactive door leaf for multi-room buildings.
## Players toggle it with Interact (E / Touch), and guards auto-open it on approach.

const ProcMesh = preload("res://scripts/mesh/proc_mesh.gd")

var is_open: bool = false
var _target_angle: float = 0.0
var _pivot: Node3D
var _body: StaticBody3D
var _auto_close_timer: float = 0.0


static func create(parent: Node3D, hinge_pos: Vector3, yaw_deg: float, width: float = 1.28, height: float = 2.28, color: Color = Color(0.36, 0.24, 0.14)) -> Node3D:
	var door: Node3D = (load("res://scripts/levels/door.gd") as GDScript).new()
	door.name = "InteractiveDoor"
	door.position = hinge_pos
	door.rotation_degrees.y = yaw_deg
	parent.add_child(door)
	door._build(width, height, color)
	return door


func _ready() -> void:
	add_to_group("doors")


func _build(width: float, height: float, color: Color) -> void:
	_pivot = Node3D.new()
	_pivot.name = "HingePivot"
	add_child(_pivot)

	# Door slab extends along +X from hinge at x=0
	var slab := ProcMesh.box_mesh(Vector3(width, height, 0.08), color, 0.78, 0.08)
	ProcMesh.add_part(_pivot, slab, Vector3(width * 0.5, height * 0.5, 0.0))
	# Recessed panel trim
	var trim := ProcMesh.box_mesh(Vector3(width * 0.72, height * 0.36, 0.10), color.darkened(0.14))
	ProcMesh.add_part(_pivot, trim, Vector3(width * 0.5, height * 0.68, 0.0))
	ProcMesh.add_part(_pivot, trim, Vector3(width * 0.5, height * 0.25, 0.0))
	# Brass / iron handle on both sides
	var handle_col := Color(0.75, 0.64, 0.32)
	ProcMesh.add_part(_pivot, ProcMesh.box_mesh(Vector3(0.14, 0.04, 0.16), handle_col, 0.3, 0.75), Vector3(width - 0.16, height * 0.46, 0.0))

	# Collision body attached to pivot (layer 1 world + layer 16 interactable)
	_body = StaticBody3D.new()
	_body.collision_layer = 1 | 16
	_body.collision_mask = 0
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(width, height, 0.14)
	cs.shape = shape
	cs.position = Vector3(width * 0.5, height * 0.5, 0.0)
	_body.add_child(cs)
	_pivot.add_child(_body)


func set_nav_bake_passable(passable: bool) -> void:
	if is_instance_valid(_body):
		_body.collision_layer = 16 if passable else (1 | 16)


func interact(actor: Node) -> void:
	is_open = not is_open
	_target_angle = deg_to_rad(94.0) if is_open else 0.0
	_auto_close_timer = 0.0
	NoiseBus.emit_noise(global_position, 5.5, "door")
	var hud := get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("show_status") and actor != null and actor.is_in_group("player"):
		hud.show_status("Door opened" if is_open else "Door closed", 1.2)


func open_for_guard() -> void:
	if not is_open:
		is_open = true
		_target_angle = deg_to_rad(94.0)
		_auto_close_timer = 4.5


func get_prompt() -> String:
	return "[E] Close Door" if is_open else "[E] Open Door"


func _physics_process(delta: float) -> void:
	if is_instance_valid(_pivot):
		_pivot.rotation.y = lerp_angle(_pivot.rotation.y, _target_angle, clampf(delta * 8.5, 0.0, 1.0))
	if _auto_close_timer > 0.0:
		_auto_close_timer -= delta
		if _auto_close_timer <= 0.0 and is_open:
			is_open = false
			_target_angle = 0.0
