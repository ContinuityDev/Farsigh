extends Node
## Central hearing bus. Weapons, footsteps, and throwables emit noise events.
## Guards subscribe and react based on distance and noise strength.

signal noise_emitted(position: Vector3, loudness: float, source: String)

## Loudness reference (approximate hear distance in meters at full volume):
## footsteps walk ~8, crouch ~3, sprint ~14
## suppressed pistol ~12, rifle ~45, bow ~2, knife throw ~6, rock impact ~10


func emit_noise(world_pos: Vector3, loudness: float, source: String = "generic") -> void:
	if loudness <= 0.0:
		return
	noise_emitted.emit(world_pos, loudness, source)
