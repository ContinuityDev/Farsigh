extends Node3D
class_name GuardVisual
## Placeholder visual root for guards.
## Art follow-up: replace PlaceholderMesh with a character scene; drive the same
## AnimationPlayer animation names (idle / walk / alert / combat / death).

signal animation_finished(anim_name: StringName)

@onready var placeholder_mesh: MeshInstance3D = $PlaceholderMesh
@onready var anim_player: AnimationPlayer = $AnimationPlayer

const ANIM_IDLE := &"idle"
const ANIM_WALK := &"walk"
const ANIM_ALERT := &"alert"
const ANIM_COMBAT := &"combat"
const ANIM_DEATH := &"death"


func _ready() -> void:
	_ensure_stub_animations()
	if anim_player and not anim_player.animation_finished.is_connected(_on_anim_finished):
		anim_player.animation_finished.connect(_on_anim_finished)
	play(ANIM_IDLE)


func play(anim_name: StringName, custom_blend: float = 0.15) -> void:
	if anim_player == null:
		return
	if not anim_player.has_animation(anim_name):
		return
	if anim_player.current_animation == String(anim_name) and anim_player.is_playing():
		return
	anim_player.play(anim_name, custom_blend)


func play_state(state_name: String) -> void:
	match state_name:
		"PATROL":
			play(ANIM_WALK)
		"SUSPICIOUS", "ALERT":
			play(ANIM_ALERT)
		"COMBAT":
			play(ANIM_COMBAT)
		"DEAD":
			play(ANIM_DEATH)
		_:
			play(ANIM_IDLE)


func set_placeholder_color(color: Color) -> void:
	if placeholder_mesh == null:
		return
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	placeholder_mesh.material_override = mat


func _on_anim_finished(anim_name: StringName) -> void:
	animation_finished.emit(anim_name)


func _ensure_stub_animations() -> void:
	## Empty looping stubs so AnimationPlayer API is ready for the art pass.
	if anim_player == null:
		return
	var lib := anim_player.get_animation_library("")
	if lib == null:
		lib = AnimationLibrary.new()
		anim_player.add_animation_library("", lib)
	for anim_name in [ANIM_IDLE, ANIM_WALK, ANIM_ALERT, ANIM_COMBAT, ANIM_DEATH]:
		if lib.has_animation(anim_name):
			continue
		var anim := Animation.new()
		anim.length = 0.5 if anim_name != ANIM_DEATH else 0.8
		anim.loop_mode = Animation.LOOP_LINEAR if anim_name != ANIM_DEATH else Animation.LOOP_NONE
		# Tiny scale pulse so the stub is "alive" without looking like final art
		var track := anim.add_track(Animation.TYPE_VALUE)
		anim.track_set_path(track, NodePath("PlaceholderMesh:scale"))
		anim.track_insert_key(track, 0.0, Vector3.ONE)
		var peak := Vector3(1.02, 1.02, 1.02) if anim_name != ANIM_DEATH else Vector3(1.0, 0.15, 1.0)
		anim.track_insert_key(track, anim.length * 0.5, peak)
		anim.track_insert_key(track, anim.length, Vector3.ONE if anim_name != ANIM_DEATH else Vector3(1.0, 0.12, 1.0))
		lib.add_animation(anim_name, anim)
