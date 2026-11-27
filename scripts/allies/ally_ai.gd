extends CharacterBody3D
class_name AllyAI
## Guns-for-Hire companion: follow / hold / attack-marked. Stealth-aware roles.


enum Cmd { FOLLOW, HOLD, ATTACK }
enum Role { SNIPER, STALKER, GUNNER, BEAST }

const FOLLOW_DIST := 3.2
const HOLD_SPEED := 0.0
const MOVE_SPEED := 4.4
const STEALTH_SPEED := 2.6

var role: Role = Role.GUNNER
var cmd: Cmd = Cmd.FOLLOW
var ally_name: String = "Ally"
var hp: float = 120.0
var max_hp: float = 120.0
var is_downed: bool = false
var _hold_pos: Vector3 = Vector3.ZERO
var _fire_cd: float = 0.0
var _label: Label3D
var _visual: Node3D
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")


func setup(role_id: String, display_name: String) -> void:
	ally_name = display_name
	match role_id:
		"sniper":
			role = Role.SNIPER
			max_hp = 100.0
		"stalker":
			role = Role.STALKER
			max_hp = 110.0
		"beast":
			role = Role.BEAST
			max_hp = 80.0
		_:
			role = Role.GUNNER
			max_hp = 140.0
	hp = max_hp
	cmd = Cmd.FOLLOW
	_build_visual(role_id)
	_ensure_label()


func _ready() -> void:
	add_to_group("allies")
	collision_layer = 2
	collision_mask = 1
	set_physics_process(true)


func _build_visual(role_id: String) -> void:
	_visual = Node3D.new()
	_visual.name = "Visual"
	add_child(_visual)
	var body_col := Color(0.22, 0.38, 0.55)
	var accent := Color(0.85, 0.72, 0.28)
	match role_id:
		"sniper":
			body_col = Color(0.28, 0.32, 0.26)
			accent = Color(0.55, 0.62, 0.35)
		"stalker":
			body_col = Color(0.18, 0.22, 0.16)
			accent = Color(0.35, 0.55, 0.30)
		"beast":
			body_col = Color(0.42, 0.32, 0.22)
			accent = Color(0.55, 0.40, 0.25)
		_:
			body_col = Color(0.35, 0.28, 0.22)
			accent = Color(0.75, 0.45, 0.20)
	if role_id == "beast":
		ProcMesh.add_part(_visual, ProcMesh.box_mesh(Vector3(0.55, 0.35, 0.85), body_col), Vector3(0, 0.35, 0))
		ProcMesh.add_part(_visual, ProcMesh.box_mesh(Vector3(0.28, 0.28, 0.32), body_col), Vector3(0, 0.45, -0.45))
		ProcMesh.add_part(_visual, ProcMesh.box_mesh(Vector3(0.12, 0.28, 0.12), accent), Vector3(-0.18, 0.15, 0.25))
		ProcMesh.add_part(_visual, ProcMesh.box_mesh(Vector3(0.12, 0.28, 0.12), accent), Vector3(0.18, 0.15, 0.25))
	else:
		ProcMesh.add_part(_visual, ProcMesh.box_mesh(Vector3(0.38, 0.55, 0.24), body_col), Vector3(0, 1.05, 0))
		ProcMesh.add_part(_visual, ProcMesh.box_mesh(Vector3(0.22, 0.24, 0.22), Color(0.76, 0.60, 0.48)), Vector3(0, 1.48, 0))
		ProcMesh.add_part(_visual, ProcMesh.box_mesh(Vector3(0.16, 0.45, 0.16), body_col), Vector3(-0.12, 0.45, 0))
		ProcMesh.add_part(_visual, ProcMesh.box_mesh(Vector3(0.16, 0.45, 0.16), body_col), Vector3(0.12, 0.45, 0))
		ProcMesh.add_part(_visual, ProcMesh.box_mesh(Vector3(0.42, 0.08, 0.28), accent), Vector3(0, 1.22, 0))
		if role_id == "sniper":
			ProcMesh.add_part(_visual, ProcMesh.cylinder_mesh(0.025, 0.55, Color(0.15, 0.16, 0.18), 0.4, 0.6, 8), Vector3(0.18, 1.15, -0.25), Vector3(90, 0, 0))


func _ensure_label() -> void:
	if is_instance_valid(_label):
		return
	_label = Label3D.new()
	_label.name = "AllyLabel"
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.font_size = 36
	_label.outline_size = 8
	_label.position = Vector3(0, 2.15, 0)
	_label.no_depth_test = true
	add_child(_label)
	_refresh_label()


func _refresh_label() -> void:
	if not is_instance_valid(_label):
		return
	if is_downed:
		_label.text = "%s  [DOWN — E]" % ally_name
		_label.modulate = Color(1.0, 0.35, 0.25)
		return
	var cmd_txt := "FOLLOW"
	match cmd:
		Cmd.HOLD: cmd_txt = "HOLD"
		Cmd.ATTACK: cmd_txt = "ATTACK"
	_label.text = "%s  ·  %s  ·  %d" % [ally_name, cmd_txt, int(hp)]
	_label.modulate = Color(0.45, 0.85, 1.0)


func cycle_command() -> void:
	if is_downed:
		return
	cmd = ((int(cmd) + 1) % 3) as Cmd
	if cmd == Cmd.HOLD:
		_hold_pos = global_position
	_refresh_label()
	var hud := get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("show_status"):
		var names := ["Follow", "Hold", "Attack marked"]
		hud.show_status("%s: %s" % [ally_name, names[int(cmd)]], 1.6)


func set_command(c: Cmd) -> void:
	cmd = c
	if cmd == Cmd.HOLD:
		_hold_pos = global_position
	_refresh_label()


func apply_damage(amount: float, _hit_pos: Vector3 = Vector3.ZERO, _source: Node = null) -> void:
	if is_downed or amount <= 0.0:
		return
	hp = maxf(0.0, hp - amount)
	_refresh_label()
	if hp <= 0.0:
		_go_down()


func _go_down() -> void:
	is_downed = true
	velocity = Vector3.ZERO
	_refresh_label()
	var hud := get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("show_status"):
		hud.show_status("%s is down — approach and revive (E)" % ally_name, 3.0)


func revive() -> void:
	if not is_downed:
		return
	is_downed = false
	hp = max_hp * 0.55
	_refresh_label()


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta
	_fire_cd = maxf(0.0, _fire_cd - delta)
	if is_downed:
		velocity.x = 0
		velocity.z = 0
		move_and_slide()
		return
	var player := get_tree().get_first_node_in_group("player") as Node3D
	if not is_instance_valid(player):
		return
	match cmd:
		Cmd.FOLLOW:
			_do_follow(player, delta)
		Cmd.HOLD:
			_do_hold(delta)
		Cmd.ATTACK:
			_do_attack(player, delta)
	move_and_slide()
	_refresh_label()


func _do_follow(player: Node3D, _delta: float) -> void:
	var dest := player.global_position - (-player.global_transform.basis.z) * 1.2
	var dist := global_position.distance_to(dest)
	if dist > FOLLOW_DIST:
		var stealth := role == Role.STALKER or role == Role.SNIPER
		_move_to(dest, STEALTH_SPEED if stealth else MOVE_SPEED)
	else:
		velocity.x = 0
		velocity.z = 0
		# Engage nearby tagged while following
		_try_engage(false)


func _do_hold(_delta: float) -> void:
	if global_position.distance_to(_hold_pos) > 0.6:
		_move_to(_hold_pos, MOVE_SPEED * 0.8)
	else:
		velocity.x = 0
		velocity.z = 0
	_try_engage(role == Role.SNIPER)


func _do_attack(player: Node3D, _delta: float) -> void:
	var target := _best_target(true)
	if target == null:
		_do_follow(player, _delta)
		return
	var tp := (target as Node3D).global_position
	var dist := global_position.distance_to(tp)
	if role == Role.SNIPER:
		if dist > 18.0:
			_move_to(tp, MOVE_SPEED)
		else:
			velocity.x = 0
			velocity.z = 0
			_look_at_flat(tp)
			_try_engage(true)
	elif role == Role.STALKER or role == Role.BEAST:
		if dist > 1.4:
			_move_to(tp, STEALTH_SPEED if role == Role.STALKER else MOVE_SPEED * 1.15)
		else:
			velocity.x = 0
			velocity.z = 0
			_melee_target(target)
	else:
		if dist > 10.0:
			_move_to(tp, MOVE_SPEED)
		else:
			velocity.x = 0
			velocity.z = 0
			_look_at_flat(tp)
			_try_engage(true)


func _best_target(prefer_tagged: bool) -> Node:
	var best: Node = null
	var best_d := 9999.0
	for g in get_tree().get_nodes_in_group("guards"):
		if not is_instance_valid(g) or not (g is Node3D):
			continue
		if g.has_method("is_alive") and not g.is_alive():
			continue
		var tagged := bool(g.get("tagged")) if "tagged" in g else false
		if prefer_tagged and not tagged and role != Role.GUNNER:
			continue
		if prefer_tagged and not tagged and cmd == Cmd.ATTACK:
			# Attack command still prefers tagged, falls back to nearest hostile
			pass
		var d := global_position.distance_to((g as Node3D).global_position)
		var score := d
		if tagged:
			score *= 0.45
		if score < best_d:
			best_d = score
			best = g
	return best


func _try_engage(force: bool) -> void:
	if _fire_cd > 0.0:
		return
	var target := _best_target(true)
	if target == null and force:
		target = _best_target(false)
	if target == null:
		return
	var dist := global_position.distance_to((target as Node3D).global_position)
	match role:
		Role.SNIPER:
			if dist < 55.0:
				_shoot_target(target, 55.0, 1.1)
		Role.GUNNER:
			if dist < 28.0:
				_shoot_target(target, 18.0, 0.35)
		Role.STALKER:
			if dist < 1.6:
				_melee_target(target)
		Role.BEAST:
			if dist < 1.8:
				_melee_target(target)


func _shoot_target(target: Node, dmg: float, cd: float) -> void:
	_look_at_flat((target as Node3D).global_position)
	if target.has_method("apply_damage"):
		target.apply_damage(dmg, global_position, self)
	NoiseBus.emit_noise(global_position, 8.0 if role == Role.SNIPER else 35.0, "ally_fire")
	_fire_cd = cd


func _melee_target(target: Node) -> void:
	if _fire_cd > 0.0:
		return
	_look_at_flat((target as Node3D).global_position)
	var dmg := 85.0 if role == Role.STALKER else 22.0
	if target.has_method("apply_damage"):
		target.apply_damage(dmg, global_position, self)
	NoiseBus.emit_noise(global_position, 2.5 if role == Role.STALKER else 7.0, "ally_melee")
	_fire_cd = 0.7 if role == Role.STALKER else 0.5


func _move_to(dest: Vector3, speed: float) -> void:
	var flat := Vector3(dest.x, global_position.y, dest.z)
	var dir := flat - global_position
	if dir.length() < 0.15:
		velocity.x = 0
		velocity.z = 0
		return
	dir = dir.normalized()
	velocity.x = dir.x * speed
	velocity.z = dir.z * speed
	_look_at_flat(flat)


func _look_at_flat(pos: Vector3) -> void:
	var flat := Vector3(pos.x, global_position.y, pos.z) - global_position
	flat.y = 0.0
	if flat.length() < 0.05:
		return
	look_at(global_position + flat.normalized(), Vector3.UP)
