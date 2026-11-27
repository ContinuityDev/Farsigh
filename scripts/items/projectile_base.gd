extends RigidBody3D
class_name ProjectileBase
## Shared throwable / arrow / knife projectile.

const ThrowableOrdnance = preload("res://scripts/items/throwable_ordnance.gd")

@export var item_kind: String = "projectile"
@export var impact_noise: float = 6.0

var damage: float = 30.0
var retrievable: bool = false
var payload_type: String = "standard"  # "standard" | "fire" | "explosive"
var spent: bool = false
var _owner: Node = null


func launch(dir: Vector3, dmg: float, speed: float, can_retrieve: bool = false, owner_node: Node = null, payload: String = "standard") -> void:
	damage = dmg
	retrievable = can_retrieve and payload == "standard"
	payload_type = payload
	_owner = owner_node
	freeze = false
	linear_velocity = dir.normalized() * speed
	if dir.length() > 0.01:
		look_at(global_position + dir, Vector3.UP)


func _ready() -> void:
	contact_monitor = true
	max_contacts_reported = 8
	body_entered.connect(_on_body_entered)
	add_to_group("suspicious_items")
	collision_layer = 8
	# world + enemies + bodies + hitboxes
	collision_mask = 1 | 4 | 16 | 128


func _physics_process(_delta: float) -> void:
	if spent:
		return
	# Area HitZones are not RigidBody contacts — probe with a short ray along velocity
	if linear_velocity.length() < 0.5:
		return
	var space := get_world_3d().direct_space_state
	var from := global_position
	var to := global_position + linear_velocity.normalized() * 0.6
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.collision_mask = 1 | 16 | 128
	query.collide_with_areas = true
	query.collide_with_bodies = true
	query.exclude = [get_rid()]
	var hit := space.intersect_ray(query)
	if hit.is_empty():
		return
	_resolve_hit(hit.collider, hit.position)


func _on_body_entered(body: Node) -> void:
	_resolve_hit(body, global_position)


func _resolve_hit(body: Object, hit_pos: Vector3) -> void:
	if spent or body == null:
		return
	spent = true
	NoiseBus.emit_noise(hit_pos, impact_noise, item_kind)
	if body is HitZone:
		var zone := body as HitZone
		var owner_node := zone.get_damage_owner()
		if owner_node and owner_node.has_method("apply_hit_zone"):
			owner_node.apply_hit_zone(zone, damage, hit_pos, _owner)
		elif owner_node and owner_node.has_method("apply_damage"):
			owner_node.apply_damage(zone.resolve_damage(damage), hit_pos, _owner, zone.zone_name())
	elif body.has_method("apply_damage"):
		body.apply_damage(damage, hit_pos, _owner)
	elif body.get_parent() and body.get_parent().has_method("apply_damage"):
		body.get_parent().apply_damage(damage, hit_pos, _owner)
	# Special arrow/bolt payloads (fire or explosive from Gunsmith customization!)
	if payload_type == "explosive":
		NoiseBus.emit_noise(hit_pos, 68.0, "explosive_arrow")
		for g in get_tree().get_nodes_in_group("guards"):
			if is_instance_valid(g) and g is Node3D and (g as Node3D).global_position.distance_to(hit_pos) <= 5.5:
				if g.has_method("apply_damage"):
					g.apply_damage(130.0, hit_pos, _owner, "BLAST")
		ThrowableOrdnance.spawn_explosion_fx(get_tree().current_scene, hit_pos, 5.5)
	elif payload_type == "fire":
		NoiseBus.emit_noise(hit_pos, 24.0, "fire_arrow")
		ThrowableOrdnance.spawn_fire_pool(get_tree().current_scene, hit_pos, 3.6, 20.0, 5.0, _owner)
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	freeze = true
	set_physics_process(false)
	if not retrievable:
		await get_tree().create_timer(2.0).timeout
		queue_free()


func interact(player: Node) -> void:
	if not retrievable or not spent:
		return
	if player.has_node("WeaponManager"):
		var wm = player.get_node("WeaponManager")
		if wm.has_method("add_retrievable_ammo"):
			wm.add_retrievable_ammo(item_kind)
	queue_free()
