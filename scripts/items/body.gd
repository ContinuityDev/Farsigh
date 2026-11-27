extends RigidBody3D
## Unconscious / dead body that guards can spot. Player can pick up and hide.

var carried: bool = false
var hidden: bool = false
var silent_kill: bool = false


func _ready() -> void:
	add_to_group("bodies")
	freeze = true
	collision_layer = 16
	collision_mask = 1


func setup(was_silent: bool) -> void:
	silent_kill = was_silent
	var mesh := get_node_or_null("MeshInstance3D") as MeshInstance3D
	if mesh:
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.25, 0.22, 0.28) if was_silent else Color(0.35, 0.1, 0.1)
		mesh.material_override = mat


func set_carried(v: bool) -> void:
	carried = v
	hidden = v
	visible = true
	collision_layer = 0 if v else 16


func is_hidden() -> bool:
	return hidden or carried


func interact(player: Node) -> void:
	if carried:
		return
	if player.has_method("pick_up_body"):
		player.pick_up_body(self)
