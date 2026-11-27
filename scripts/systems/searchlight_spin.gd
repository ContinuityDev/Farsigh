extends Node3D
## Tiny yaw sweep for searchlight props.


var _t: float = 0.0


func _process(delta: float) -> void:
	_t += delta
	rotation.y = sin(_t * 0.55) * 0.85
