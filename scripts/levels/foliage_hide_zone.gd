extends Area3D
class_name FoliageHideZone
## Tall grass / bush volume. Player inside (especially crouched) is heavily
## hidden. Guards can still notice on bump contact.

@export var crouch_visibility: float = 0.08
@export var stand_visibility: float = 0.42


func _ready() -> void:
	add_to_group("foliage_hide")
	collision_layer = 0
	collision_mask = 2  # player layer
	monitoring = true
	monitorable = false
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player") and body.has_method("enter_foliage"):
		body.enter_foliage(self)


func _on_body_exited(body: Node) -> void:
	if body.is_in_group("player") and body.has_method("exit_foliage"):
		body.exit_foliage(self)


func visibility_mult(crouched: bool) -> float:
	return crouch_visibility if crouched else stand_visibility
