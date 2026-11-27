extends RigidBody3D
class_name ProjectileBase
## Shared throwable / arrow / knife projectile.

@export var item_kind: String = "projectile"
@export var impact_noise: float = 6.0

var damage: float = 30.0
var retrievable: bool = false
var spent: bool = false
var _owner: Node = null


func launch(dir: Vector3, dmg: float, speed: float, can_retrieve: bool = false, owner_node: Node = null) -> void:
	damage = dmg
	retrievable = can_retrieve
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
