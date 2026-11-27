extends RefCounted
class_name DropIn
## Makes anything dropped into a compound work on the next load:
## collision, hiding, and AI cover. Editor gizmos stay in the scene
## and are hidden while the game is running.


static func apply(root: Node) -> void:
	if root == null:
		return
	_walk(root)


static func _walk(node: Node) -> void:
	var lname := String(node.name).to_lower()
	if node is Node3D and (node.is_in_group("editor_gizmo") or node.name == "EditorGizmo" or node.name == "CoverGizmo"):
		(node as Node3D).visible = false
	if node is Marker3D and (node.name == "CoverPoint" or node.is_in_group("cover_points")):
		node.add_to_group("cover_points")
	if (node is OmniLight3D or node is SpotLight3D) and not node.is_in_group("compound_lights"):
		var parent_name := String(node.get_parent().name) if node.get_parent() else ""
		if node.name == "CompoundLight" or parent_name == "Floodlight" or parent_name == "LightPole":
			node.add_to_group("compound_lights")
	if node is MeshInstance3D and (lname.ends_with("_col") or lname.contains("_col_") or lname.ends_with("_collision")):
		_ensure_trimesh(node as MeshInstance3D)
	if node is Node3D and not (node is FoliageHideZone) and (lname.ends_with("_hide") or lname.contains("_hide_")):
		_ensure_hide(node as Node3D)
	if node is Node3D and (lname.ends_with("_cover") or lname.contains("_cover_")) and not node.is_in_group("cover_points"):
		node.add_to_group("cover_points")
	for c in node.get_children():
		_walk(c)


static func _ensure_trimesh(mi: MeshInstance3D) -> void:
	if mi.mesh == null:
		return
	var p: Node = mi
	while p != null:
		if p is StaticBody3D:
			return
		p = p.get_parent()
	var body := StaticBody3D.new()
	body.name = "DropCollision"
	body.collision_layer = 1
	body.collision_mask = 0
	var cs := CollisionShape3D.new()
	cs.shape = mi.mesh.create_trimesh_shape()
	body.add_child(cs)
	mi.add_child(body)


static func _ensure_hide(host: Node3D) -> void:
	for c in host.get_children():
		if c is FoliageHideZone or c.is_in_group("foliage_hide"):
			return
	var zone := FoliageHideZone.new()
	zone.name = "HideZone"
	var cs := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = 1.4
	cs.shape = shape
	cs.position = Vector3(0, 0.8, 0)
	zone.add_child(cs)
	host.add_child(zone)
