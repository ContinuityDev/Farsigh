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
	max_contacts_reported = 4
	body_entered.connect(_on_body_entered)
	add_to_group("suspicious_items")
	collision_layer = 8
	collision_mask = 1 | 4 | 16


func _on_body_entered(body: Node) -> void:
	if spent:
		return
	spent = true
	NoiseBus.emit_noise(global_position, impact_noise, item_kind)
	if body.has_method("apply_damage"):
		body.apply_damage(damage, global_position, _owner)
	elif body.get_parent() and body.get_parent().has_method("apply_damage"):
		body.get_parent().apply_damage(damage, global_position, _owner)
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	freeze = true
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
