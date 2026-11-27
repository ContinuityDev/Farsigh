extends RigidBody3D
## Distraction rock — makes noise on impact, spotted by guards as suspicious item.

var _launched: bool = false


func _ready() -> void:
	contact_monitor = true
	max_contacts_reported = 4
	body_entered.connect(_on_body_entered)
	add_to_group("suspicious_items")
	collision_layer = 8
	collision_mask = 1 | 4


func launch(dir: Vector3, speed: float, _owner: Node = null) -> void:
	_launched = true
	freeze = false
	linear_velocity = dir.normalized() * speed + Vector3.UP * 2.0


func _on_body_entered(_body: Node) -> void:
	if not _launched:
		return
	_launched = false
	NoiseBus.emit_noise(global_position, 12.0, "rock")
