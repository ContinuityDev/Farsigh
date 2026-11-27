extends Area3D
class_name HitZone
## Collider used by weapons to resolve body-part damage.
## Future art pass can reparent / retarget these to bones; keep the Zone enum stable.

enum Zone { HEAD, TORSO, LIMBS }

@export var zone: Zone = Zone.TORSO

## Multipliers applied to weapon base damage. Head is always lethal (one-shot).
const MULT := {
	Zone.HEAD: 999.0,
	Zone.TORSO: 1.0,
	Zone.LIMBS: 0.55,
}


func _ready() -> void:
	monitoring = false
	monitorable = true
	collision_layer = 128  # hitboxes (layer 8)
	collision_mask = 0
	add_to_group("hit_zones")


func get_damage_owner() -> Node:
	var n: Node = get_parent()
	while n:
		if n.has_method("apply_damage"):
			return n
		n = n.get_parent()
	return null


func resolve_damage(base_damage: float) -> float:
	if zone == Zone.HEAD:
		return 9999.0  # one-shot headshot
	return base_damage * float(MULT.get(zone, 1.0))


func zone_name() -> String:
	return Zone.keys()[zone]
