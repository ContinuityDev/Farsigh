extends Marker3D
## Drop into a compound. A guard spawns here on the next load.
## Patrol waypoints are child PatrolPoint markers (local positions).
## Edit role / sniper / sentry / dog_id in the Inspector.

@export var role: String = "patrol"
@export var sniper: bool = false
@export var sentry: bool = false
@export var dog_id: String = ""


func _ready() -> void:
	add_to_group("guard_spawn", true)
