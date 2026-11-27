extends Node3D
class_name OutpostManager
## Tracks living guards, liberation, and liberated persistence for one compound.

signal liberation_achieved

@export var outpost_id: String = "compound_alpha"
@export var outpost_display_name: String = "Hope County Compound"

var _guards: Array[GuardAI] = []
var liberated: bool = false


func _ready() -> void:
	add_to_group("outpost")
	_setup_environment()
	liberated = GameState.is_liberated(outpost_id)
	call_deferred("_bind_guards")
	if liberated:
		call_deferred("_show_already_liberated")


func _setup_environment() -> void:
	var we := get_node_or_null("WorldEnvironment") as WorldEnvironment
	if we == null:
		return
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.45, 0.55, 0.62)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.55, 0.58, 0.5)
	env.ambient_light_energy = 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	we.environment = env


func _bind_guards() -> void:
	_guards.clear()
	for n in get_tree().get_nodes_in_group("guards"):
		if n is GuardAI and is_ancestor_of(n):
			register_guard(n)
		elif n is GuardAI:
			# Guards may be children of this outpost
			register_guard(n)
	# Prefer only children under this node
	_guards.clear()
	_collect_guards(self)
	_update_count()


func _collect_guards(node: Node) -> void:
	for c in node.get_children():
		if c is GuardAI:
			register_guard(c)
		_collect_guards(c)


func register_guard(g: GuardAI) -> void:
	if g in _guards:
		return
	_guards.append(g)
	if not g.died.is_connected(_on_guard_died):
		g.died.connect(_on_guard_died)
	_update_count()


func _on_guard_died(g: GuardAI) -> void:
	_guards.erase(g)
	_update_count()
	if _guards.is_empty() and not liberated:
		_liberate()


func _update_count() -> void:
	var alive := 0
	for g in _guards:
		if is_instance_valid(g) and g.is_alive():
			alive += 1
	GameState.set_guards_remaining(alive, outpost_id)
	var hud := get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("set_guard_count"):
		hud.set_guard_count(alive)


func _liberate() -> void:
	liberated = true
	GameState.mark_liberated(outpost_id)
	liberation_achieved.emit()
	var hud := get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("show_liberation"):
		hud.show_liberation(outpost_display_name)


func _show_already_liberated() -> void:
	# Clear remaining hostiles for a freed outpost revisit
	for g in get_tree().get_nodes_in_group("guards"):
		if g is GuardAI and is_ancestor_of(g):
			g.queue_free()
	var hud := get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("show_status"):
		hud.show_status("%s — Liberated" % outpost_display_name, 4.0)
	if hud and hud.has_method("set_liberated_banner"):
		hud.set_liberated_banner(true)
