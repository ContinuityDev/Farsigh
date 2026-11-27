extends Node3D
class_name ViewmodelRig
## Placeholder first-person weapon slots.
## Art follow-up: instance real viewmodels under each *Slot node; keep slot names.

@onready var pistol_slot: Node3D = $PistolSlot
@onready var rifle_slot: Node3D = $RifleSlot
@onready var bow_slot: Node3D = $BowSlot
@onready var knife_slot: Node3D = $KnifeSlot

var _slots: Dictionary = {}


func _ready() -> void:
	_slots = {
		GameState.WeaponId.PISTOL: pistol_slot,
		GameState.WeaponId.RIFLE: rifle_slot,
		GameState.WeaponId.BOW: bow_slot,
		GameState.WeaponId.KNIFE: knife_slot,
	}
	_build_placeholders()
	hide_all()


func _build_placeholders() -> void:
	## Simple colored blocks — deliberately not final art.
	_make_placeholder(pistol_slot, Vector3(0.08, 0.12, 0.28), Color(0.25, 0.28, 0.22))
	_make_placeholder(rifle_slot, Vector3(0.1, 0.12, 0.55), Color(0.2, 0.22, 0.25))
	_make_placeholder(bow_slot, Vector3(0.06, 0.45, 0.08), Color(0.45, 0.32, 0.18))
	_make_placeholder(knife_slot, Vector3(0.04, 0.05, 0.22), Color(0.55, 0.55, 0.6))


func _make_placeholder(slot: Node3D, size: Vector3, color: Color) -> void:
	if slot == null:
		return
	if slot.get_node_or_null("PlaceholderMesh"):
		return
	var mi := MeshInstance3D.new()
	mi.name = "PlaceholderMesh"
	var box := BoxMesh.new()
	box.size = size
	mi.mesh = box
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mi.material_override = mat
	mi.position = Vector3(0.22, -0.16, -0.35)
	slot.add_child(mi)


func hide_all() -> void:
	for slot in _slots.values():
		if slot:
			slot.visible = false


func show_weapon(id: GameState.WeaponId) -> void:
	hide_all()
	var slot: Node3D = _slots.get(id)
	if slot:
		slot.visible = true


func get_slot(id: GameState.WeaponId) -> Node3D:
	return _slots.get(id) as Node3D
