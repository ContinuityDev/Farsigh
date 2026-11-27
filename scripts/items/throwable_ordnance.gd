extends RigidBody3D
class_name ThrowableOrdnance
## Thrown M67 Frag Grenade (timed AoE blast) & Molotov Cocktail (impact fire pool).
## Lightweight procedural visuals (expanding sphere / flickering flame cones) for WebGL.

const ProcMesh = preload("res://scripts/mesh/proc_mesh.gd")

var kind: String = "frag"  # "frag" | "molotov"
var damage: float = 150.0
var blast_radius: float = 6.5
var fuse_time: float = 1.65
var _owner: Node = null
var _detonated: bool = false
var _timer: float = 0.0


static func spawn_ordnance(parent: Node, origin: Vector3, dir: Vector3, ordnance_kind: String, dmg: float, radius: float, owner_node: Node) -> Node3D:
	var n: ThrowableOrdnance = (load("res://scripts/items/throwable_ordnance.gd") as GDScript).new()
	n.kind = ordnance_kind
	n.damage = dmg
	n.blast_radius = radius
	n._owner = owner_node
	n.position = origin
	parent.add_child(n)
	n.linear_velocity = dir.normalized() * (17.5 if ordnance_kind == "frag" else 16.0) + Vector3.UP * 3.8
	n.angular_velocity = Vector3(6.0, 3.0, -4.0)
	return n


func _ready() -> void:
	collision_layer = 8
	collision_mask = 1 | 4
	contact_monitor = true
	max_contacts_reported = 4
	body_entered.connect(_on_impact)

	var cs := CollisionShape3D.new()
	var sph := SphereShape3D.new()
	sph.radius = 0.10
	cs.shape = sph
	add_child(cs)

	if kind == "frag":
		ProcMesh.add_part(self, ProcMesh.sphere_mesh(0.08, Color(0.24, 0.30, 0.20), 0.75, 0.2), Vector3.ZERO)
		ProcMesh.add_part(self, ProcMesh.box_mesh(Vector3(0.04, 0.05, 0.04), Color(0.45, 0.45, 0.44)), Vector3(0, 0.09, 0))
	else:
		# Glass bottle with amber fuel + lit glowing rag wick
		ProcMesh.add_part(self, ProcMesh.cylinder_mesh(0.055, 0.22, Color(0.76, 0.44, 0.14), 0.25, 0.15, 8), Vector3.ZERO)
		ProcMesh.add_part(self, ProcMesh.cylinder_mesh(0.022, 0.10, Color(0.70, 0.42, 0.16), 0.25, 0.15, 8), Vector3(0, 0.14, 0))
		var flame := ProcMesh.sphere_mesh(0.05, Color(1.0, 0.55, 0.12))
		flame.material_override = ProcMesh.emissive(Color(1.0, 0.50, 0.10), 2.8)
		ProcMesh.add_part(self, flame, Vector3(0, 0.22, 0))


func _physics_process(delta: float) -> void:
	if _detonated:
		return
	_timer += delta
	if kind == "frag" and _timer >= fuse_time:
		_detonate_frag(global_position)
	elif kind == "molotov" and _timer >= 4.0:
		_detonate_molotov(global_position)


func _on_impact(_body: Node) -> void:
	if _detonated:
		return
	if kind == "molotov":
		_detonate_molotov(global_position)


func _detonate_frag(center: Vector3) -> void:
	if _detonated:
		return
	_detonated = true
	NoiseBus.emit_noise(center, 78.0, "frag_explosion")
	_apply_radial_damage(center, blast_radius, damage)
	spawn_explosion_fx(get_tree().current_scene, center, blast_radius)
	queue_free()


func _detonate_molotov(center: Vector3) -> void:
	if _detonated:
		return
	_detonated = true
	NoiseBus.emit_noise(center, 34.0, "molotov_shatter")
	spawn_fire_pool(get_tree().current_scene, center, blast_radius, 22.0, 5.5, _owner)
	queue_free()


func _apply_radial_damage(center: Vector3, radius: float, max_dmg: float) -> void:
	for g in get_tree().get_nodes_in_group("guards"):
		if not is_instance_valid(g) or not (g is Node3D):
			continue
		var d := (g as Node3D).global_position.distance_to(center)
		if d <= radius and g.has_method("apply_damage"):
			var falloff := 1.0 - clampf(d / radius, 0.0, 0.85)
			g.apply_damage(max_dmg * falloff, center, _owner, "BLAST")


static func spawn_explosion_fx(scene_root: Node, center: Vector3, radius: float) -> void:
	if not is_instance_valid(scene_root):
		return
	var fx := Node3D.new()
	fx.position = center
	scene_root.add_child(fx)
	var core := ProcMesh.sphere_mesh(0.6, Color(1.0, 0.65, 0.15))
	core.material_override = ProcMesh.emissive(Color(1.0, 0.55, 0.12), 3.4)
	fx.add_child(core)
	var smoke := ProcMesh.sphere_mesh(0.9, Color(0.22, 0.20, 0.18))
	smoke.position = Vector3(0, 0.5, 0)
	fx.add_child(smoke)
	var tw := fx.create_tween()
	tw.set_parallel(true)
	tw.tween_property(core, "scale", Vector3.ONE * (radius * 0.65), 0.28)
	tw.tween_property(smoke, "scale", Vector3.ONE * (radius * 0.55), 0.55)
	tw.tween_property(smoke, "position:y", 2.4, 0.55)
	tw.chain().tween_callback(fx.queue_free)


static func spawn_fire_pool(scene_root: Node, center: Vector3, radius: float, dps: float, duration: float, owner_node: Node) -> void:
	if not is_instance_valid(scene_root):
		return
	var pool := Node3D.new()
	pool.position = Vector3(center.x, maxf(0.05, center.y), center.z)
	scene_root.add_child(pool)
	# Scorched glowing ring + low-poly flame cones
	var glow := ProcMesh.cylinder_mesh(radius * 0.72, 0.06, Color(0.95, 0.35, 0.08), 0.9, 0.0, 12)
	glow.material_override = ProcMesh.emissive(Color(1.0, 0.38, 0.06), 2.2)
	pool.add_child(glow)
	for i in range(6):
		var a := float(i) * TAU / 6.0
		var r := radius * (0.28 + float(i % 2) * 0.25)
		var flame := ProcMesh.cone_mesh(0.32, 0.03, 0.95 + float(i % 3) * 0.25, Color(1.0, 0.55, 0.12), 0.8, 0.0, 6)
		flame.material_override = ProcMesh.emissive(Color(1.0, 0.52, 0.08), 2.6)
		ProcMesh.add_part(pool, flame, Vector3(cos(a) * r, 0.45, sin(a) * r))

	# Tick burn damage cleanly via scene timer steps (no custom script attach needed)
	var ticks := maxi(1, int(duration / 0.5))
	for t in range(ticks):
		var delay := float(t) * 0.5
		pool.get_tree().create_timer(delay).timeout.connect(func():
			if not is_instance_valid(pool):
				return
			for g in pool.get_tree().get_nodes_in_group("guards"):
				if is_instance_valid(g) and g is Node3D and (g as Node3D).global_position.distance_to(pool.global_position) <= radius:
					if g.has_method("apply_damage"):
						g.apply_damage(dps * 0.5, pool.global_position, owner_node, "FIRE")
		)
	pool.get_tree().create_timer(duration).timeout.connect(func():
		if is_instance_valid(pool):
			pool.queue_free()
	)
