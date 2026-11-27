extends Node
## Spawns Guns-for-Hire allies and routes command / revive input.


const AllyAIScript = preload("res://scripts/allies/ally_ai.gd")

const ALLY_NAMES := {
	"sniper": "Grace",
	"stalker": "Jess",
	"gunner": "Hurk",
	"beast": "Boomer",
}

var ally: CharacterBody3D = null


func _ready() -> void:
	add_to_group("ally_manager")
	name = "AllyManager"
	set_process(true)
	call_deferred("_try_spawn")


func _try_spawn() -> void:
	var role := GameState.consume_hired_ally_for_deploy()
	if role == "":
		return
	var a := CharacterBody3D.new()
	a.set_script(AllyAIScript)
	a.name = "Ally"
	var parent := get_parent()
	if parent == null:
		return
	parent.add_child(a)
	ally = a
	var disp := String(ALLY_NAMES.get(role, "Ally"))
	if ally.has_method("setup"):
		ally.setup(role, disp)
	var player := get_tree().get_first_node_in_group("player") as Node3D
	if is_instance_valid(player):
		ally.global_position = player.global_position + Vector3(-1.4, 0.1, 1.2)
	var hud := get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("show_status"):
		hud.show_status("%s hired — H cycle commands · E revive when down" % disp, 3.5)
	if hud and hud.has_method("refresh_ally_hud"):
		hud.refresh_ally_hud()


func _process(_delta: float) -> void:
	if not is_instance_valid(ally):
		return
	if TouchInput.is_action_just_pressed("ally_command"):
		if ally.has_method("cycle_command"):
			ally.cycle_command()
		var hud := get_tree().get_first_node_in_group("hud")
		if hud and hud.has_method("refresh_ally_hud"):
			hud.refresh_ally_hud()
	# Revive: interact near downed ally
	if bool(ally.get("is_downed")) and TouchInput.is_action_just_pressed("interact"):
		var player := get_tree().get_first_node_in_group("player") as Node3D
		if is_instance_valid(player) and player.global_position.distance_to(ally.global_position) < 2.4:
			if ally.has_method("revive"):
				ally.revive()
			var hud2 := get_tree().get_first_node_in_group("hud")
			if hud2 and hud2.has_method("show_status"):
				hud2.show_status("%s revived" % String(ally.get("ally_name")), 1.8)
			if hud2 and hud2.has_method("refresh_ally_hud"):
				hud2.refresh_ally_hud()


func has_ally() -> bool:
	return is_instance_valid(ally)


func ally_status() -> Dictionary:
	if not is_instance_valid(ally):
		return {}
	return {
		"name": String(ally.get("ally_name")),
		"hp": float(ally.get("hp")),
		"max_hp": float(ally.get("max_hp")),
		"downed": bool(ally.get("is_downed")),
		"cmd": int(ally.get("cmd")),
	}
