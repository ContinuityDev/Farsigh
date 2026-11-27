extends RigidBody3D
## Unconscious / dead humanoid guard body that guards can spot. Player can pick up and hide.

var carried: bool = false
var hidden: bool = false
var silent_kill: bool = false


func _ready() -> void:
	add_to_group("bodies")
	freeze = true
	collision_layer = 16
	collision_mask = 1
	_build_humanoid_body()


func _build_humanoid_body() -> void:
	var old_mesh := get_node_or_null("MeshInstance3D") as MeshInstance3D
	if is_instance_valid(old_mesh):
		old_mesh.visible = false
	if get_node_or_null("DownedRig"):
		return
	var rig := Node3D.new()
	rig.name = "DownedRig"
	add_child(rig)
	var jacket := Color(0.24, 0.27, 0.22)
	var vest := Color(0.14, 0.15, 0.16)
	var pants := Color(0.21, 0.20, 0.18)
	var boot := Color(0.10, 0.09, 0.09)
	var helmet := Color(0.18, 0.20, 0.17)
	# Supine torso + vest
	ProcMesh.add_part(rig, ProcMesh.box_mesh(Vector3(0.42, 0.22, 0.54), jacket), Vector3(0, 0.02, -0.05))
	ProcMesh.add_part(rig, ProcMesh.box_mesh(Vector3(0.45, 0.25, 0.38), vest), Vector3(0, 0.04, -0.06))
	# Head + helmet
	ProcMesh.add_part(rig, ProcMesh.sphere_mesh(0.14, helmet), Vector3(0.02, 0.04, -0.46))
	# Splayed arms & legs
	ProcMesh.add_part(rig, ProcMesh.box_mesh(Vector3(0.13, 0.12, 0.52), jacket), Vector3(-0.30, 0.0, -0.08), Vector3(0, -24, 0))
	ProcMesh.add_part(rig, ProcMesh.box_mesh(Vector3(0.13, 0.12, 0.52), jacket), Vector3(0.32, 0.0, -0.04), Vector3(0, 18, 0))
	ProcMesh.add_part(rig, ProcMesh.box_mesh(Vector3(0.15, 0.14, 0.68), pants), Vector3(-0.14, 0.0, 0.48), Vector3(0, 8, 0))
	ProcMesh.add_part(rig, ProcMesh.box_mesh(Vector3(0.15, 0.14, 0.68), pants), Vector3(0.16, 0.0, 0.48), Vector3(0, -10, 0))
	ProcMesh.add_part(rig, ProcMesh.box_mesh(Vector3(0.14, 0.16, 0.20), boot), Vector3(-0.17, 0.02, 0.84))
	ProcMesh.add_part(rig, ProcMesh.box_mesh(Vector3(0.14, 0.16, 0.20), boot), Vector3(0.19, 0.02, 0.84))


func setup(was_silent: bool) -> void:
	silent_kill = was_silent
	var rig := get_node_or_null("DownedRig") as Node3D
	if is_instance_valid(rig) and not was_silent:
		ProcMesh.add_part(rig, ProcMesh.box_mesh(Vector3(0.55, 0.02, 0.55), Color(0.36, 0.06, 0.05)), Vector3(0, -0.10, -0.1))


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
