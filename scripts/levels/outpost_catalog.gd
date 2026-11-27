extends RefCounted
class_name OutpostCatalog
## Registry of Far Cry 5–inspired outposts (themes, spawns, patrols, alarms, snipers).


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
			"guards": [
				{"pos": Vector3(-10.5, 0.1, 6.0), "rot": 0.0, "sniper": false, "patrol": [Vector3(-10.5, 0.1, 8.0), Vector3(-10.5, 0.1, -9.0), Vector3(-4.0, 0.1, -1.0)]},
				{"pos": Vector3(11.5, 0.1, 2.0), "rot": 180.0, "sniper": false, "patrol": [Vector3(11.5, 0.1, 8.0), Vector3(11.5, 0.1, -8.5), Vector3(5.0, 0.1, 0.0)]},
				{"pos": Vector3(1.0, 0.1, -9.0), "rot": 90.0, "sniper": false, "patrol": [Vector3(-5.0, 0.1, -9.5), Vector3(7.0, 0.1, -9.5), Vector3(1.0, 0.1, -6.5)]},
				{"pos": Vector3(0.0, 0.1, 12.5), "rot": 0.0, "sniper": false, "patrol": [Vector3(0.0, 0.1, 14.5), Vector3(-7.0, 0.1, 11.0), Vector3(5.5, 0.1, 12.0)]},
				{"pos": Vector3(-15.25, 3.6, -15.25), "rot": -135.0, "sniper": true, "patrol": [Vector3(-15.25, 3.6, -15.25)]},
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
			"guards": [
				{"pos": Vector3(0.0, 0.1, 14.0), "rot": 0.0, "sniper": false, "patrol": [Vector3(-4.0, 0.1, 14.0), Vector3(6.0, 0.1, 14.0), Vector3(1.0, 0.1, 8.0)]},
				{"pos": Vector3(-10.0, 0.1, 4.0), "rot": 90.0, "sniper": false, "patrol": [Vector3(-12.0, 0.1, 8.0), Vector3(-12.0, 0.1, -6.0), Vector3(-5.0, 0.1, 0.0)]},
				{"pos": Vector3(10.5, 0.1, -4.0), "rot": -90.0, "sniper": false, "patrol": [Vector3(11.0, 0.1, 5.0), Vector3(11.0, 0.1, -12.0), Vector3(4.0, 0.1, -6.0)]},
				{"pos": Vector3(-1.0, 0.1, -13.0), "rot": 180.0, "sniper": false, "patrol": [Vector3(-6.0, 0.1, -14.0), Vector3(6.0, 0.1, -14.0), Vector3(0.0, 0.1, -7.0)]},
				{"pos": Vector3(15.0, 0.1, 10.0), "rot": 0.0, "sniper": false, "patrol": [Vector3(14.0, 0.1, 12.0), Vector3(16.0, 0.1, 0.0)]},
				{"pos": Vector3(14.0, 5.65, -12.0), "rot": -150.0, "sniper": true, "patrol": [Vector3(14.0, 5.65, -12.0)]},
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
			"guards": [
				{"pos": Vector3(-2.0, 0.1, 15.0), "rot": 0.0, "sniper": false, "patrol": [Vector3(-6.0, 0.1, 16.0), Vector3(6.0, 0.1, 15.0), Vector3(0.0, 0.1, 9.0)]},
				{"pos": Vector3(-11.0, 0.1, 6.0), "rot": 90.0, "sniper": false, "patrol": [Vector3(-13.0, 0.1, 11.0), Vector3(-13.0, 0.1, -6.0), Vector3(-7.0, 0.1, 2.0)]},
				{"pos": Vector3(11.0, 0.1, 4.0), "rot": -90.0, "sniper": false, "patrol": [Vector3(12.0, 0.1, 10.0), Vector3(12.0, 0.1, -9.0), Vector3(6.0, 0.1, -2.0)]},
				{"pos": Vector3(0.0, 0.1, -11.0), "rot": 180.0, "sniper": false, "patrol": [Vector3(-6.0, 0.1, -12.0), Vector3(8.0, 0.1, -12.0)]},
				{"pos": Vector3(4.0, 0.1, 2.0), "rot": 0.0, "sniper": false, "patrol": [Vector3(3.0, 0.1, 5.0), Vector3(3.0, 0.1, -5.0), Vector3(-3.0, 0.1, 0.0)]},
				{"pos": Vector3(-16.0, 3.6, 14.0), "rot": -45.0, "sniper": true, "patrol": [Vector3(-16.0, 3.6, 14.0)]},
				{"pos": Vector3(16.0, 3.6, -14.0), "rot": 145.0, "sniper": true, "patrol": [Vector3(16.0, 3.6, -14.0)]},
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
			"guards": [
				{"pos": Vector3(0.0, 0.1, 14.0), "rot": 0.0, "sniper": false, "patrol": [Vector3(-6.0, 0.1, 14.0), Vector3(7.0, 0.1, 14.0), Vector3(0.0, 0.1, 7.0)]},
				{"pos": Vector3(-10.0, 0.1, 4.0), "rot": 90.0, "sniper": false, "patrol": [Vector3(-12.0, 0.1, 9.0), Vector3(-11.0, 0.1, -5.0)]},
				{"pos": Vector3(9.0, 0.1, 3.0), "rot": -90.0, "sniper": false, "patrol": [Vector3(11.0, 0.1, 9.0), Vector3(9.0, 0.1, -5.0)]},
				{"pos": Vector3(0.0, 0.35, -10.0), "rot": 0.0, "sniper": false, "patrol": [Vector3(0.0, 0.35, -7.5), Vector3(0.0, 0.35, -18.0)]},
				{"pos": Vector3(4.5, 0.35, -18.5), "rot": 180.0, "sniper": false, "patrol": [Vector3(-5.0, 0.35, -18.5), Vector3(5.5, 0.35, -18.5)]},
				{"pos": Vector3(-11.5, 3.9, 0.0), "rot": -135.0, "sniper": true, "patrol": [Vector3(-11.5, 3.9, 0.0)]},
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
			"guards": [
				{"pos": Vector3(0.0, 0.1, 15.0), "rot": 0.0, "sniper": false, "patrol": [Vector3(-7.0, 0.1, 15.0), Vector3(7.0, 0.1, 15.0), Vector3(0.0, 0.1, 9.0)]},
				{"pos": Vector3(-11.0, 0.1, 4.0), "rot": 90.0, "sniper": false, "patrol": [Vector3(-13.0, 0.1, 9.0), Vector3(-13.0, 0.1, -8.0), Vector3(-6.0, 0.1, 0.0)]},
				{"pos": Vector3(11.0, 0.1, 4.0), "rot": -90.0, "sniper": false, "patrol": [Vector3(13.0, 0.1, 10.0), Vector3(13.0, 0.1, -8.0), Vector3(6.0, 0.1, 1.0)]},
				{"pos": Vector3(-3.0, 0.1, -7.0), "rot": 0.0, "sniper": false, "patrol": [Vector3(-7.0, 0.1, -6.5), Vector3(7.0, 0.1, -6.5)]},
				{"pos": Vector3(8.0, 0.1, -14.0), "rot": 180.0, "sniper": false, "patrol": [Vector3(4.0, 0.1, -15.0), Vector3(14.0, 0.1, -15.0)]},
				{"pos": Vector3(-2.0, 0.1, 2.0), "rot": 0.0, "sniper": false, "patrol": [Vector3(-5.0, 0.1, 3.0), Vector3(5.0, 0.1, 3.0), Vector3(0.0, 0.1, -3.0)]},
				{"pos": Vector3(-17.0, 3.6, -16.0), "rot": -140.0, "sniper": true, "patrol": [Vector3(-17.0, 3.6, -16.0)]},
				{"pos": Vector3(17.0, 3.6, -16.0), "rot": 140.0, "sniper": true, "patrol": [Vector3(17.0, 3.6, -16.0)]},
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
