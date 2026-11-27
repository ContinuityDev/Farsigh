extends RefCounted
class_name OutpostCatalog
## Registry of Far Cry 5–inspired outposts (themes, spawns, patrols, alarms, snipers).
## Guard specs support: sniper, sentry, heavy, officer, dog, handler, chat_pair, interior.


static func _g(pos: Vector3, rot: float, patrol: Array, extras: Dictionary = {}) -> Dictionary:
	var d := {"pos": pos, "rot": rot, "sniper": false, "patrol": patrol}
	for k in extras.keys():
		d[k] = extras[k]
	return d


static func all_outposts() -> Array[Dictionary]:
	return [
		{
			"id": "compound_alpha",
			"name": "Hope County Compound",
			"theme": "Militia Supply Depot",
			"description": "Walled supply yard with barracks, armory, 2-storey HQ, and timber watchtower.",
			"approaches": "South Gate, West Breach, North Service Gap",
			"player_spawn": Vector3(0.0, 0.15, 30.0),
			"sky_top": Color(0.24, 0.44, 0.70),
			"sky_horizon": Color(0.76, 0.71, 0.59),
			"fog_color": Color(0.64, 0.66, 0.62),
			"alarms": [Vector3(1.0, 0.0, -9.8)],
			"reinforce_points": [Vector3(19.0, 0.1, 19.0), Vector3(-19.0, 0.1, 18.0)],
			# 5 → 12 hostiles. South approach stays lighter for stealth.
			"guards": [
				_g(Vector3(-10.5, 0.1, 6.0), 0.0, [Vector3(-10.5, 0.1, 8.0), Vector3(-10.5, 0.1, -9.0), Vector3(-4.0, 0.1, -1.0)]),
				_g(Vector3(11.5, 0.1, 2.0), 180.0, [Vector3(11.5, 0.1, 8.0), Vector3(11.5, 0.1, -8.5), Vector3(5.0, 0.1, 0.0)]),
				_g(Vector3(1.0, 0.1, -9.0), 90.0, [Vector3(1.0, 0.1, -9.5), Vector3(1.0, 0.2, -13.5), Vector3(1.0, 3.5, -14.0), Vector3(-2.5, 3.5, -14.0)], {"role": "interior"}),
				_g(Vector3(0.0, 0.1, 12.5), 0.0, [Vector3(0.0, 0.1, 14.5), Vector3(-7.0, 0.1, 11.0), Vector3(5.5, 0.1, 12.0)]),
				_g(Vector3(-15.25, 3.6, -15.25), -135.0, [Vector3(-15.25, 3.6, -15.25)], {"sniper": true}),
				# East rooftop sniper, NW heavy sentry, HQ officer, chat pair by crates, dog + handler
				_g(Vector3(14.5, 3.55, -8.0), 45.0, [Vector3(14.5, 3.55, -8.0)], {"sniper": true}),
				_g(Vector3(-14.0, 0.1, 14.0), 180.0, [Vector3(-14.0, 0.1, 14.0)], {"role": "heavy", "sentry": true}),
				_g(Vector3(2.5, 0.1, -12.0), 0.0, [Vector3(2.5, 0.1, -12.0), Vector3(-1.5, 0.1, -12.0)], {"role": "officer"}),
				_g(Vector3(-6.0, 0.1, 2.5), 90.0, [Vector3(-6.0, 0.1, 2.5)], {"role": "patrol", "chat_pair": "alpha_crates"}),
				_g(Vector3(-4.2, 0.1, 2.5), -90.0, [Vector3(-4.2, 0.1, 2.5)], {"role": "patrol", "chat_pair": "alpha_crates"}),
				_g(Vector3(8.0, 0.1, 10.0), 0.0, [Vector3(8.0, 0.1, 10.0), Vector3(12.0, 0.1, 6.0)], {"role": "handler", "dog_id": "alpha_dog"}),
				_g(Vector3(9.2, 0.1, 10.0), 0.0, [Vector3(9.2, 0.1, 10.0), Vector3(12.5, 0.1, 6.5)], {"role": "dog", "dog_id": "alpha_dog"}),
			],
		},
		{
			"id": "ranch_redbarn",
			"name": "Seed Family Ranch",
			"theme": "Farm Compound, Red Barn & Silos",
			"description": "Working cattle ranch with a 2-storey red barn, twin grain silos, farmhouse, and hay-bale corrals.",
			"approaches": "South Driveway, East Pasture, West Orchard, North Silo Lane",
			"player_spawn": Vector3(0.0, 0.15, 33.0),
			"sky_top": Color(0.28, 0.36, 0.62),
			"sky_horizon": Color(0.90, 0.62, 0.38),
			"fog_color": Color(0.76, 0.62, 0.48),
			"alarms": [Vector3(-3.0, 0.0, -5.0), Vector3(10.5, 0.0, 6.0)],
			"reinforce_points": [Vector3(22.0, 0.1, 20.0), Vector3(-22.0, 0.1, 16.0)],
			# 6 → 14
			"guards": [
				_g(Vector3(0.0, 0.1, 14.0), 0.0, [Vector3(-4.0, 0.1, 14.0), Vector3(6.0, 0.1, 14.0), Vector3(1.0, 0.1, 8.0)]),
				_g(Vector3(-10.0, 0.1, 4.0), 90.0, [Vector3(-12.0, 0.1, 8.0), Vector3(-12.0, 0.1, -6.0), Vector3(-5.0, 0.1, 0.0)]),
				_g(Vector3(10.5, 0.1, -4.0), -90.0, [Vector3(11.0, 0.1, 5.0), Vector3(11.0, 0.1, -12.0), Vector3(4.0, 0.1, -6.0)]),
				_g(Vector3(-1.0, 0.1, -13.0), 180.0, [Vector3(-6.0, 0.1, -14.0), Vector3(6.0, 0.1, -14.0), Vector3(0.0, 0.1, -7.0)]),
				_g(Vector3(15.0, 0.1, 10.0), 0.0, [Vector3(14.0, 0.1, 12.0), Vector3(16.0, 0.1, 0.0)]),
				_g(Vector3(14.0, 5.65, -12.0), -150.0, [Vector3(14.0, 5.65, -12.0)], {"sniper": true}),
				_g(Vector3(-12.0, 3.55, -10.0), -40.0, [Vector3(-12.0, 3.55, -10.0)], {"sniper": true}),
				_g(Vector3(-8.5, 0.1, -2.0), 0.0, [Vector3(-8.5, 0.1, -2.0), Vector3(-8.5, 3.4, -2.0), Vector3(-5.0, 3.4, -4.0)], {"role": "interior"}),
				_g(Vector3(6.0, 0.1, 6.0), 180.0, [Vector3(6.0, 0.1, 6.0)], {"role": "heavy", "sentry": true}),
				_g(Vector3(-2.0, 0.1, -4.0), 90.0, [Vector3(-2.0, 0.1, -4.0), Vector3(2.0, 0.1, -4.0)], {"role": "officer"}),
				_g(Vector3(4.0, 0.1, 16.0), -20.0, [Vector3(4.0, 0.1, 16.0)], {"role": "patrol", "chat_pair": "ranch_gate"}),
				_g(Vector3(5.6, 0.1, 16.0), 200.0, [Vector3(5.6, 0.1, 16.0)], {"role": "patrol", "chat_pair": "ranch_gate"}),
				_g(Vector3(-14.0, 0.1, 10.0), 0.0, [Vector3(-14.0, 0.1, 10.0), Vector3(-10.0, 0.1, 14.0)], {"role": "handler", "dog_id": "ranch_dog"}),
				_g(Vector3(-13.0, 0.1, 10.5), 0.0, [Vector3(-13.0, 0.1, 10.5), Vector3(-9.5, 0.1, 14.0)], {"role": "dog", "dog_id": "ranch_dog"}),
			],
		},
		{
			"id": "lumber_mill",
			"name": "Baron Lumber Mill",
			"theme": "Pine Forest Sawmill",
			"description": "Timber yard packed with log stacks, a multi-storey saw mill, drying kiln, and logging trucks.",
			"approaches": "Main Haul Road, West Timber Trail, East Creek Bank, North Rail Spur",
			"player_spawn": Vector3(-2.0, 0.15, 34.0),
			"sky_top": Color(0.20, 0.42, 0.68),
			"sky_horizon": Color(0.72, 0.80, 0.82),
			"fog_color": Color(0.60, 0.68, 0.68),
			"alarms": [Vector3(2.5, 0.0, -4.0), Vector3(-13.0, 0.0, 2.0)],
			"reinforce_points": [Vector3(23.0, 0.1, 18.0), Vector3(-23.0, 0.1, -16.0)],
			# 7 → 15
			"guards": [
				_g(Vector3(-2.0, 0.1, 15.0), 0.0, [Vector3(-6.0, 0.1, 16.0), Vector3(6.0, 0.1, 15.0), Vector3(0.0, 0.1, 9.0)]),
				_g(Vector3(-11.0, 0.1, 6.0), 90.0, [Vector3(-13.0, 0.1, 11.0), Vector3(-13.0, 0.1, -6.0), Vector3(-7.0, 0.1, 2.0)]),
				_g(Vector3(11.0, 0.1, 4.0), -90.0, [Vector3(12.0, 0.1, 10.0), Vector3(12.0, 0.1, -9.0), Vector3(6.0, 0.1, -2.0)]),
				_g(Vector3(0.0, 0.1, -11.0), 180.0, [Vector3(-6.0, 0.1, -12.0), Vector3(8.0, 0.1, -12.0)]),
				_g(Vector3(4.0, 0.1, 2.0), 0.0, [Vector3(3.0, 0.1, 5.0), Vector3(3.0, 0.1, -5.0), Vector3(-3.0, 0.1, 0.0)]),
				_g(Vector3(-16.0, 3.6, 14.0), -45.0, [Vector3(-16.0, 3.6, 14.0)], {"sniper": true}),
				_g(Vector3(16.0, 3.6, -14.0), 145.0, [Vector3(16.0, 3.6, -14.0)], {"sniper": true}),
				_g(Vector3(-2.0, 3.5, -2.0), 0.0, [Vector3(-4.0, 3.5, -2.0), Vector3(2.0, 3.5, -2.0), Vector3(-2.0, 0.1, 1.0)], {"role": "interior"}),
				_g(Vector3(8.0, 0.1, -6.0), 180.0, [Vector3(8.0, 0.1, -6.0)], {"role": "heavy", "sentry": true}),
				_g(Vector3(-8.0, 0.1, -2.0), 0.0, [Vector3(-8.0, 0.1, -2.0), Vector3(-4.0, 0.1, -2.0)], {"role": "officer"}),
				_g(Vector3(-14.0, 0.1, -10.0), 90.0, [Vector3(-14.0, 0.1, -10.0)], {"role": "sentry"}),
				_g(Vector3(2.0, 0.1, 18.0), 180.0, [Vector3(2.0, 0.1, 18.0)], {"role": "patrol", "chat_pair": "mill_logs"}),
				_g(Vector3(3.8, 0.1, 18.0), 0.0, [Vector3(3.8, 0.1, 18.0)], {"role": "patrol", "chat_pair": "mill_logs"}),
				_g(Vector3(14.0, 0.1, 8.0), -90.0, [Vector3(14.0, 0.1, 8.0), Vector3(10.0, 0.1, 12.0)], {"role": "handler", "dog_id": "mill_dog"}),
				_g(Vector3(14.8, 0.1, 8.5), -90.0, [Vector3(14.8, 0.1, 8.5), Vector3(10.5, 0.1, 12.5)], {"role": "dog", "dog_id": "mill_dog"}),
			],
		},
		{
			"id": "river_dock",
			"name": "Whitetail Bait & Dock",
			"theme": "Riverside Pier & Boathouse",
			"description": "Militia river checkpoint with a bait shop, 2-storey boathouse, wooden pier, and moored patrol boat.",
			"approaches": "South Highway Lot, West Riverbank, East Boat Launch",
			"player_spawn": Vector3(0.0, 0.15, 31.0),
			"sky_top": Color(0.18, 0.44, 0.72),
			"sky_horizon": Color(0.68, 0.79, 0.85),
			"fog_color": Color(0.58, 0.70, 0.76),
			"alarms": [Vector3(-5.0, 0.0, 2.0)],
			"reinforce_points": [Vector3(20.0, 0.1, 18.0), Vector3(-20.0, 0.1, 18.0)],
			# 6 → 14
			"guards": [
				_g(Vector3(0.0, 0.1, 14.0), 0.0, [Vector3(-6.0, 0.1, 14.0), Vector3(7.0, 0.1, 14.0), Vector3(0.0, 0.1, 7.0)]),
				_g(Vector3(-10.0, 0.1, 4.0), 90.0, [Vector3(-12.0, 0.1, 9.0), Vector3(-11.0, 0.1, -5.0)]),
				_g(Vector3(9.0, 0.1, 3.0), -90.0, [Vector3(11.0, 0.1, 9.0), Vector3(9.0, 0.1, -5.0)]),
				_g(Vector3(0.0, 0.35, -10.0), 0.0, [Vector3(0.0, 0.35, -7.5), Vector3(0.0, 0.35, -18.0)]),
				_g(Vector3(4.5, 0.35, -18.5), 180.0, [Vector3(-5.0, 0.35, -18.5), Vector3(5.5, 0.35, -18.5)]),
				_g(Vector3(-12.0, 6.75, 1.5), -135.0, [Vector3(-12.0, 6.75, 1.5)], {"sniper": true}),
				_g(Vector3(11.0, 3.55, -6.0), 40.0, [Vector3(11.0, 3.55, -6.0)], {"sniper": true}),
				_g(Vector3(-6.0, 0.1, -2.0), 0.0, [Vector3(-6.0, 0.1, -2.0), Vector3(-6.0, 3.4, -2.0), Vector3(-3.0, 3.4, 1.0)], {"role": "interior"}),
				_g(Vector3(6.0, 0.35, -14.0), 180.0, [Vector3(6.0, 0.35, -14.0)], {"role": "heavy", "sentry": true}),
				_g(Vector3(-3.0, 0.1, 4.0), 90.0, [Vector3(-3.0, 0.1, 4.0), Vector3(-7.0, 0.1, 4.0)], {"role": "officer"}),
				_g(Vector3(-8.0, 0.1, 12.0), 20.0, [Vector3(-8.0, 0.1, 12.0)], {"role": "patrol", "chat_pair": "dock_bait"}),
				_g(Vector3(-6.4, 0.1, 12.0), -160.0, [Vector3(-6.4, 0.1, 12.0)], {"role": "patrol", "chat_pair": "dock_bait"}),
				_g(Vector3(12.0, 0.1, 12.0), -90.0, [Vector3(12.0, 0.1, 12.0), Vector3(8.0, 0.1, 8.0)], {"role": "handler", "dog_id": "dock_dog"}),
				_g(Vector3(12.8, 0.1, 12.4), -90.0, [Vector3(12.8, 0.1, 12.4), Vector3(8.5, 0.1, 8.5)], {"role": "dog", "dog_id": "dock_dog"}),
			],
		},
		{
			"id": "hilltop_bunker",
			"name": "Jacob's Ridge Bunker",
			"theme": "Hilltop Radio & Militia Bunker",
			"description": "Fortified mountain bunker with underground garage, radio dishes, helipad, and twin sniper towers.",
			"approaches": "South Switchback Gate, West Cliff Gap, East Trench Breach",
			"player_spawn": Vector3(0.0, 0.15, 34.0),
			"sky_top": Color(0.12, 0.20, 0.40),
			"sky_horizon": Color(0.68, 0.44, 0.36),
			"fog_color": Color(0.42, 0.38, 0.42),
			"alarms": [Vector3(0.0, 0.0, -5.0), Vector3(-10.0, 0.0, 7.0)],
			"reinforce_points": [Vector3(21.0, 0.1, 18.0), Vector3(-21.0, 0.1, 18.0)],
			# 8 → 17
			"guards": [
				_g(Vector3(0.0, 0.1, 15.0), 0.0, [Vector3(-7.0, 0.1, 15.0), Vector3(7.0, 0.1, 15.0), Vector3(0.0, 0.1, 9.0)]),
				_g(Vector3(-11.0, 0.1, 4.0), 90.0, [Vector3(-13.0, 0.1, 9.0), Vector3(-13.0, 0.1, -8.0), Vector3(-6.0, 0.1, 0.0)]),
				_g(Vector3(11.0, 0.1, 4.0), -90.0, [Vector3(13.0, 0.1, 10.0), Vector3(13.0, 0.1, -8.0), Vector3(6.0, 0.1, 1.0)]),
				_g(Vector3(0.0, -2.6, -14.5), 0.0, [Vector3(-2.5, -2.6, -14.5), Vector3(2.5, -2.6, -14.5), Vector3(0.0, 0.1, -9.0)], {"role": "interior"}),
				_g(Vector3(8.0, 0.1, -14.0), 180.0, [Vector3(4.0, 0.1, -15.0), Vector3(14.0, 0.1, -15.0)]),
				_g(Vector3(-2.0, 0.1, 2.0), 0.0, [Vector3(-5.0, 0.1, 3.0), Vector3(5.0, 0.1, 3.0), Vector3(0.0, 0.1, -3.0)]),
				_g(Vector3(-17.0, 3.6, -16.0), -140.0, [Vector3(-17.0, 3.6, -16.0)], {"sniper": true}),
				_g(Vector3(17.0, 3.6, -16.0), 140.0, [Vector3(17.0, 3.6, -16.0)], {"sniper": true}),
				_g(Vector3(0.0, 3.55, -8.0), 0.0, [Vector3(0.0, 3.55, -8.0)], {"sniper": true}),
				_g(Vector3(-6.0, 0.1, 10.0), 180.0, [Vector3(-6.0, 0.1, 10.0)], {"role": "heavy", "sentry": true}),
				_g(Vector3(6.0, 0.1, 10.0), 180.0, [Vector3(6.0, 0.1, 10.0)], {"role": "heavy", "sentry": true}),
				_g(Vector3(-1.0, 0.1, -6.0), 0.0, [Vector3(-1.0, 0.1, -6.0), Vector3(2.0, 0.1, -6.0)], {"role": "officer"}),
				_g(Vector3(-8.0, 3.4, 2.0), 90.0, [Vector3(-8.0, 3.4, 2.0), Vector3(-4.0, 3.4, 2.0), Vector3(-6.0, 0.1, 4.0)], {"role": "interior"}),
				_g(Vector3(3.0, 0.1, 18.0), 180.0, [Vector3(3.0, 0.1, 18.0)], {"role": "patrol", "chat_pair": "ridge_gate"}),
				_g(Vector3(4.8, 0.1, 18.0), 0.0, [Vector3(4.8, 0.1, 18.0)], {"role": "patrol", "chat_pair": "ridge_gate"}),
				_g(Vector3(14.0, 0.1, 0.0), -90.0, [Vector3(14.0, 0.1, 0.0), Vector3(10.0, 0.1, 6.0)], {"role": "handler", "dog_id": "ridge_dog"}),
				_g(Vector3(14.8, 0.1, 0.5), -90.0, [Vector3(14.8, 0.1, 0.5), Vector3(10.5, 0.1, 6.5)], {"role": "dog", "dog_id": "ridge_dog"}),
			],
		},
	]


static func get_outpost(id: String) -> Dictionary:
	for o in all_outposts():
		if o["id"] == id:
			return o
	return all_outposts()[0]


static func all_ids() -> Array[String]:
	var ids: Array[String] = []
	for o in all_outposts():
		ids.append(String(o["id"]))
	return ids


static func get_all() -> Array[Dictionary]:
	return all_outposts()


static func guard_count(spec: Dictionary) -> int:
	return (spec.get("guards", []) as Array).size()


static func alarm_count(spec: Dictionary) -> int:
	return (spec.get("alarms", []) as Array).size()


static func sniper_count(spec: Dictionary) -> int:
	var n := 0
	for g in spec.get("guards", []):
		if bool(g.get("sniper", false)):
			n += 1
	return n


static func role_count(spec: Dictionary, role: String) -> int:
	var n := 0
	for g in spec.get("guards", []):
		if String(g.get("role", "")) == role:
			n += 1
	return n
