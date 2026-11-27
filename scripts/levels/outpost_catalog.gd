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
			"difficulty": 1,
			"difficulty_label": "Standard",
			"layout": "compound_alpha",
			"unlocks_after": [],
			"description": "Walled supply yard with barracks, armory, 2-storey HQ, and timber watchtower.",
			"approaches": "South Gate, West Breach, North Service Gap, East Culvert",
			"player_spawn": Vector3(0.0, 0.15, 38.0),
			"sky_top": Color(0.24, 0.44, 0.70),
			"sky_horizon": Color(0.76, 0.71, 0.59),
			"fog_color": Color(0.64, 0.66, 0.62),
			"alarms": [Vector3(1.0, 0.0, -9.8)],
			"reinforce_points": [Vector3(24.0, 0.1, 24.0), Vector3(-24.0, 0.1, 22.0)],
			# Longer perimeter + courtyard loops on the enlarged compound.
			"guards": [
				_g(Vector3(-12.0, 0.1, 8.0), 0.0, [Vector3(-12.0, 0.1, 12.0), Vector3(-12.0, 0.1, -14.0), Vector3(-4.0, 0.1, -14.0), Vector3(-4.0, 0.1, 12.0), Vector3(-12.0, 0.1, 12.0)]),
				_g(Vector3(1.0, 0.1, -9.0), 90.0, [Vector3(1.0, 0.1, -9.5), Vector3(1.0, 0.2, -13.5), Vector3(1.0, 3.5, -14.0), Vector3(-2.5, 3.5, -14.0), Vector3(-2.5, 3.5, -10.0)], {"role": "interior"}),
				_g(Vector3(-18.0, 3.6, -18.0), -135.0, [Vector3(-18.0, 3.6, -18.0)], {"sniper": true, "role": "sniper"}),
				_g(Vector3(18.0, 3.55, -10.0), 45.0, [Vector3(18.0, 3.55, -10.0)], {"sniper": true, "role": "sniper"}),
				_g(Vector3(-18.0, 0.1, 18.0), 180.0, [Vector3(-18.0, 0.1, 18.0)], {"role": "heavy", "sentry": true}),
				_g(Vector3(2.5, 0.1, -12.0), 0.0, [Vector3(2.5, 0.1, -12.0), Vector3(-1.5, 0.1, -12.0), Vector3(-1.5, 0.1, -8.0), Vector3(2.5, 0.1, -8.0)], {"role": "officer"}),
				_g(Vector3(10.0, 0.1, 12.0), 0.0, [Vector3(10.0, 0.1, 12.0), Vector3(16.0, 0.1, 8.0), Vector3(16.0, 0.1, 2.0), Vector3(10.0, 0.1, 2.0)], {"role": "handler", "dog_id": "alpha_dog"}),
				_g(Vector3(11.2, 0.1, 12.0), 0.0, [Vector3(11.2, 0.1, 12.0), Vector3(16.5, 0.1, 8.5), Vector3(16.5, 0.1, 2.5), Vector3(11.2, 0.1, 2.5)], {"role": "dog", "dog_id": "alpha_dog"}),
				# East culvert patrol — covers new entrance
				_g(Vector3(22.0, 0.1, 0.0), 90.0, [Vector3(22.0, 0.1, -8.0), Vector3(22.0, 0.1, 8.0), Vector3(16.0, 0.1, 8.0), Vector3(16.0, 0.1, -8.0)]),
			],
		},
		{
			"id": "ranch_redbarn",
			"name": "Seed Family Ranch",
			"theme": "Farm Compound, Red Barn & Silos",

			"difficulty": 2,
			"difficulty_label": "Standard",
			"layout": "ranch_redbarn",
			"unlocks_after": [],
			"description": "Working cattle ranch with a 2-storey red barn, twin grain silos, farmhouse, and hay-bale corrals.",
			"approaches": "South Driveway, East Pasture, West Orchard, North Silo Lane",
			"player_spawn": Vector3(0.0, 0.15, 38.0),
			"sky_top": Color(0.28, 0.36, 0.62),
			"sky_horizon": Color(0.90, 0.62, 0.38),
			"fog_color": Color(0.76, 0.62, 0.48),
			"alarms": [Vector3(-3.0, 0.0, -5.0), Vector3(10.5, 0.0, 6.0)],
			"reinforce_points": [Vector3(28.0, 0.1, 24.0), Vector3(-28.0, 0.1, 20.0)],
			"guards": [
				_g(Vector3(0.0, 0.1, 18.0), 0.0, [Vector3(-8.0, 0.1, 18.0), Vector3(8.0, 0.1, 18.0), Vector3(8.0, 0.1, 10.0), Vector3(-8.0, 0.1, 10.0), Vector3(-8.0, 0.1, 18.0)]),
				_g(Vector3(-14.0, 0.1, 4.0), 90.0, [Vector3(-18.0, 0.1, 12.0), Vector3(-18.0, 0.1, -10.0), Vector3(-8.0, 0.1, -10.0), Vector3(-8.0, 0.1, 12.0)]),
				_g(Vector3(-1.0, 0.1, -18.0), 180.0, [Vector3(-10.0, 0.1, -20.0), Vector3(10.0, 0.1, -20.0), Vector3(4.0, 0.1, -10.0), Vector3(-4.0, 0.1, -10.0)]),
				_g(Vector3(14.0, 5.65, -12.0), -150.0, [Vector3(14.0, 5.65, -12.0)], {"sniper": true, "role": "sniper"}),
				_g(Vector3(-12.0, 3.55, -10.0), -40.0, [Vector3(-12.0, 3.55, -10.0)], {"sniper": true, "role": "sniper"}),
				_g(Vector3(-8.5, 0.1, -2.0), 0.0, [Vector3(-8.5, 0.1, -2.0), Vector3(-8.5, 3.4, -2.0), Vector3(-5.0, 3.4, -4.0)], {"role": "interior"}),
				_g(Vector3(6.0, 0.1, 6.0), 180.0, [Vector3(6.0, 0.1, 6.0)], {"role": "heavy", "sentry": true}),
				_g(Vector3(-2.0, 0.1, -4.0), 90.0, [Vector3(-2.0, 0.1, -4.0), Vector3(2.0, 0.1, -4.0), Vector3(2.0, 0.1, 2.0)], {"role": "officer"}),
				_g(Vector3(-14.0, 0.1, 10.0), 0.0, [Vector3(-14.0, 0.1, 10.0), Vector3(-10.0, 0.1, 14.0), Vector3(-6.0, 0.1, 10.0)], {"role": "handler", "dog_id": "ranch_dog"}),
				_g(Vector3(-13.0, 0.1, 10.5), 0.0, [Vector3(-13.0, 0.1, 10.5), Vector3(-9.5, 0.1, 14.0), Vector3(-5.5, 0.1, 10.5)], {"role": "dog", "dog_id": "ranch_dog"}),
				# East pasture + north silo lane entrance covers
				_g(Vector3(26.0, 0.1, 2.0), 90.0, [Vector3(26.0, 0.1, -8.0), Vector3(26.0, 0.1, 12.0), Vector3(18.0, 0.1, 12.0), Vector3(18.0, 0.1, -8.0)]),
				_g(Vector3(4.0, 0.1, -26.0), 180.0, [Vector3(-6.0, 0.1, -26.0), Vector3(12.0, 0.1, -26.0), Vector3(8.0, 0.1, -18.0)]),
			],
		},
		{
			"id": "lumber_mill",
			"name": "Baron Lumber Mill",
			"theme": "Pine Forest Sawmill",

			"difficulty": 2,
			"difficulty_label": "Standard",
			"layout": "lumber_mill",
			"unlocks_after": [],
			"description": "Timber yard packed with log stacks, a multi-storey saw mill, drying kiln, and logging trucks.",
			"approaches": "Main Haul Road, West Timber Trail, East Creek Bank, North Rail Spur",
			"player_spawn": Vector3(-2.0, 0.15, 40.0),
			"sky_top": Color(0.20, 0.42, 0.68),
			"sky_horizon": Color(0.72, 0.80, 0.82),
			"fog_color": Color(0.60, 0.68, 0.68),
			"alarms": [Vector3(2.5, 0.0, -4.0), Vector3(-13.0, 0.0, 2.0)],
			"reinforce_points": [Vector3(28.0, 0.1, 22.0), Vector3(-28.0, 0.1, -18.0)],
			"guards": [
				_g(Vector3(-2.0, 0.1, 20.0), 0.0, [Vector3(-10.0, 0.1, 22.0), Vector3(10.0, 0.1, 20.0), Vector3(6.0, 0.1, 10.0), Vector3(-6.0, 0.1, 10.0)]),
				_g(Vector3(-14.0, 0.1, 6.0), 90.0, [Vector3(-18.0, 0.1, 14.0), Vector3(-18.0, 0.1, -10.0), Vector3(-8.0, 0.1, -6.0), Vector3(-8.0, 0.1, 12.0)]),
				_g(Vector3(0.0, 0.1, -16.0), 180.0, [Vector3(-10.0, 0.1, -18.0), Vector3(12.0, 0.1, -18.0), Vector3(6.0, 0.1, -8.0)]),
				_g(Vector3(-16.0, 3.6, 14.0), -45.0, [Vector3(-16.0, 3.6, 14.0)], {"sniper": true, "role": "sniper"}),
				_g(Vector3(16.0, 3.6, -14.0), 145.0, [Vector3(16.0, 3.6, -14.0)], {"sniper": true, "role": "sniper"}),
				_g(Vector3(-2.0, 3.5, -2.0), 0.0, [Vector3(-4.0, 3.5, -2.0), Vector3(2.0, 3.5, -2.0), Vector3(-2.0, 0.1, 1.0)], {"role": "interior"}),
				_g(Vector3(8.0, 0.1, -6.0), 180.0, [Vector3(8.0, 0.1, -6.0)], {"role": "heavy", "sentry": true}),
				_g(Vector3(-8.0, 0.1, -2.0), 0.0, [Vector3(-8.0, 0.1, -2.0), Vector3(-4.0, 0.1, -2.0), Vector3(-4.0, 0.1, 4.0)], {"role": "officer"}),
				_g(Vector3(14.0, 0.1, 8.0), -90.0, [Vector3(14.0, 0.1, 8.0), Vector3(10.0, 0.1, 12.0), Vector3(18.0, 0.1, 6.0)], {"role": "handler", "dog_id": "mill_dog"}),
				_g(Vector3(14.8, 0.1, 8.5), -90.0, [Vector3(14.8, 0.1, 8.5), Vector3(10.5, 0.1, 12.5), Vector3(18.5, 0.1, 6.5)], {"role": "dog", "dog_id": "mill_dog"}),
				_g(Vector3(28.0, 0.1, 2.0), 90.0, [Vector3(28.0, 0.1, -10.0), Vector3(28.0, 0.1, 12.0), Vector3(20.0, 0.1, 8.0)]),
				_g(Vector3(0.0, 0.1, -28.0), 180.0, [Vector3(-10.0, 0.1, -28.0), Vector3(10.0, 0.1, -28.0), Vector3(4.0, 0.1, -20.0)]),
			],
		},
		{
			"id": "river_dock",
			"name": "Whitetail Bait & Dock",
			"theme": "Riverside Pier & Boathouse",

			"difficulty": 2,
			"difficulty_label": "Standard",
			"layout": "river_dock",
			"unlocks_after": [],
			"description": "Militia river checkpoint with a bait shop, 2-storey boathouse, wooden pier, and moored patrol boat.",
			"approaches": "South Highway Lot, West Riverbank, East Boat Launch, North Pier Crawl",
			"player_spawn": Vector3(0.0, 0.15, 36.0),
			"sky_top": Color(0.18, 0.44, 0.72),
			"sky_horizon": Color(0.68, 0.79, 0.85),
			"fog_color": Color(0.58, 0.70, 0.76),
			"alarms": [Vector3(-5.0, 0.0, 2.0)],
			"reinforce_points": [Vector3(24.0, 0.1, 22.0), Vector3(-24.0, 0.1, 22.0)],
			"guards": [
				_g(Vector3(0.0, 0.1, 18.0), 0.0, [Vector3(-10.0, 0.1, 18.0), Vector3(10.0, 0.1, 18.0), Vector3(6.0, 0.1, 8.0), Vector3(-6.0, 0.1, 8.0)]),
				_g(Vector3(-14.0, 0.1, 4.0), 90.0, [Vector3(-18.0, 0.1, 12.0), Vector3(-16.0, 0.1, -6.0), Vector3(-8.0, 0.1, 2.0)]),
				_g(Vector3(0.0, 0.35, -12.0), 0.0, [Vector3(0.0, 0.35, -8.0), Vector3(0.0, 0.35, -20.0), Vector3(4.0, 0.35, -18.0)]),
				_g(Vector3(-12.0, 6.75, 1.5), -135.0, [Vector3(-12.0, 6.75, 1.5)], {"sniper": true, "role": "sniper"}),
				_g(Vector3(11.0, 3.55, -6.0), 40.0, [Vector3(11.0, 3.55, -6.0)], {"sniper": true, "role": "sniper"}),
				_g(Vector3(-6.0, 0.1, -2.0), 0.0, [Vector3(-6.0, 0.1, -2.0), Vector3(-6.0, 3.4, -2.0), Vector3(-3.0, 3.4, 1.0)], {"role": "interior"}),
				_g(Vector3(6.0, 0.35, -16.0), 180.0, [Vector3(6.0, 0.35, -16.0)], {"role": "heavy", "sentry": true}),
				_g(Vector3(-3.0, 0.1, 4.0), 90.0, [Vector3(-3.0, 0.1, 4.0), Vector3(-7.0, 0.1, 4.0), Vector3(-7.0, 0.1, 10.0)], {"role": "officer"}),
				_g(Vector3(12.0, 0.1, 12.0), -90.0, [Vector3(12.0, 0.1, 12.0), Vector3(8.0, 0.1, 8.0), Vector3(16.0, 0.1, 8.0)], {"role": "handler", "dog_id": "dock_dog"}),
				_g(Vector3(12.8, 0.1, 12.4), -90.0, [Vector3(12.8, 0.1, 12.4), Vector3(8.5, 0.1, 8.5), Vector3(16.5, 0.1, 8.5)], {"role": "dog", "dog_id": "dock_dog"}),
				_g(Vector3(26.0, 0.1, 6.0), 90.0, [Vector3(26.0, 0.1, -2.0), Vector3(26.0, 0.1, 14.0), Vector3(18.0, 0.1, 10.0)]),
				_g(Vector3(-26.0, 0.1, 10.0), -90.0, [Vector3(-26.0, 0.1, 2.0), Vector3(-26.0, 0.1, 16.0), Vector3(-18.0, 0.1, 12.0)]),
			],
		},
		{
			"id": "hilltop_bunker",
			"name": "Jacob's Ridge Bunker",
			"theme": "Hilltop Radio & Militia Bunker",

			"difficulty": 3,
			"difficulty_label": "Hard",
			"layout": "hilltop_bunker",
			"unlocks_after": [],
			"description": "Fortified mountain bunker with underground garage, radio dishes, helipad, and twin sniper towers.",
			"approaches": "South Switchback Gate, West Cliff Gap, East Trench Breach, North Bunker Rear",
			"player_spawn": Vector3(0.0, 0.15, 40.0),
			"sky_top": Color(0.12, 0.20, 0.40),
			"sky_horizon": Color(0.68, 0.44, 0.36),
			"fog_color": Color(0.42, 0.38, 0.42),
			"alarms": [Vector3(0.0, 0.0, -5.0), Vector3(-10.0, 0.0, 7.0)],
			"reinforce_points": [Vector3(26.0, 0.1, 22.0), Vector3(-26.0, 0.1, 22.0)],
			"guards": [
				_g(Vector3(0.0, 0.1, 20.0), 0.0, [Vector3(-10.0, 0.1, 20.0), Vector3(10.0, 0.1, 20.0), Vector3(6.0, 0.1, 10.0), Vector3(-6.0, 0.1, 10.0)]),
				_g(Vector3(-14.0, 0.1, 4.0), 90.0, [Vector3(-18.0, 0.1, 12.0), Vector3(-18.0, 0.1, -12.0), Vector3(-8.0, 0.1, -4.0), Vector3(-8.0, 0.1, 10.0)]),
				_g(Vector3(0.0, -2.6, -14.5), 0.0, [Vector3(-2.5, -2.6, -14.5), Vector3(2.5, -2.6, -14.5), Vector3(0.0, 0.1, -9.0)], {"role": "interior"}),
				_g(Vector3(8.0, 0.1, -18.0), 180.0, [Vector3(4.0, 0.1, -20.0), Vector3(16.0, 0.1, -20.0), Vector3(12.0, 0.1, -10.0)]),
				_g(Vector3(-17.0, 3.6, -16.0), -140.0, [Vector3(-17.0, 3.6, -16.0)], {"sniper": true, "role": "sniper"}),
				_g(Vector3(17.0, 3.6, -16.0), 140.0, [Vector3(17.0, 3.6, -16.0)], {"sniper": true, "role": "sniper"}),
				_g(Vector3(0.0, 3.55, -8.0), 0.0, [Vector3(0.0, 3.55, -8.0)], {"sniper": true, "role": "sniper"}),
				_g(Vector3(-6.0, 0.1, 10.0), 180.0, [Vector3(-6.0, 0.1, 10.0)], {"role": "heavy", "sentry": true}),
				_g(Vector3(-1.0, 0.1, -6.0), 0.0, [Vector3(-1.0, 0.1, -6.0), Vector3(2.0, 0.1, -6.0), Vector3(2.0, 0.1, 0.0)], {"role": "officer"}),
				_g(Vector3(-8.0, 3.4, 2.0), 90.0, [Vector3(-8.0, 3.4, 2.0), Vector3(-4.0, 3.4, 2.0), Vector3(-6.0, 0.1, 4.0)], {"role": "interior"}),
				_g(Vector3(14.0, 0.1, 0.0), -90.0, [Vector3(14.0, 0.1, 0.0), Vector3(10.0, 0.1, 6.0), Vector3(18.0, 0.1, 4.0)], {"role": "handler", "dog_id": "ridge_dog"}),
				_g(Vector3(14.8, 0.1, 0.5), -90.0, [Vector3(14.8, 0.1, 0.5), Vector3(10.5, 0.1, 6.5), Vector3(18.5, 0.1, 4.5)], {"role": "dog", "dog_id": "ridge_dog"}),
				_g(Vector3(28.0, 0.1, 2.0), 90.0, [Vector3(28.0, 0.1, -8.0), Vector3(28.0, 0.1, 12.0), Vector3(20.0, 0.1, 8.0)]),
				_g(Vector3(-28.0, 0.1, 4.0), -90.0, [Vector3(-28.0, 0.1, -6.0), Vector3(-28.0, 0.1, 14.0), Vector3(-20.0, 0.1, 8.0)]),
			],
		},

		{
			"id": "eden_fortress",
			"name": "Eden's Gate Fortress",
			"theme": "Inner/Outer Wall Fortress",
			"difficulty": 4,
			"difficulty_label": "Extreme",
			"layout": "hilltop_bunker",
			"unlocks_after": ["compound_alpha", "ranch_redbarn"],
			"description": "Layered fortress with outer palisade, inner keep, armored heavies, elite snipers, and tripwire approaches.",
			"approaches": "South Gatehouse, West Sewer Cut, East Scaffold Breach",
			"player_spawn": Vector3(0.0, 0.15, 36.0),
			"sky_top": Color(0.10, 0.16, 0.32),
			"sky_horizon": Color(0.55, 0.38, 0.30),
			"fog_color": Color(0.36, 0.34, 0.38),
			"alarms": [Vector3(0.0, 0.0, -5.0), Vector3(-10.0, 0.0, 7.0), Vector3(10.0, 0.0, 7.0)],
			"reinforce_points": [Vector3(22.0, 0.1, 20.0), Vector3(-22.0, 0.1, 20.0), Vector3(0.0, 0.1, -22.0)],
			"cameras": [Vector3(-8.0, 0.0, 12.0), Vector3(8.0, 0.0, 12.0), Vector3(0.0, 0.0, -10.0)],
			"searchlights": [Vector3(-12.0, 0.0, 8.0), Vector3(12.0, 0.0, 8.0)],
			"tripwires": [Vector3(0.0, 0.0, 20.0), Vector3(-10.0, 0.0, 14.0)],
			"keycard_doors": [Vector3(0.0, 0.0, -9.5)],
			"guards": [
				_g(Vector3(0.0, 0.1, 16.0), 0.0, [Vector3(-8.0, 0.1, 16.0), Vector3(8.0, 0.1, 16.0)]),
				_g(Vector3(-12.0, 0.1, 6.0), 90.0, [Vector3(-14.0, 0.1, 12.0), Vector3(-14.0, 0.1, -6.0)]),
				_g(Vector3(12.0, 0.1, 6.0), -90.0, [Vector3(14.0, 0.1, 12.0), Vector3(14.0, 0.1, -6.0)]),
				_g(Vector3(0.0, -2.6, -14.5), 0.0, [Vector3(-2.5, -2.6, -14.5), Vector3(2.5, -2.6, -14.5)], {"role": "interior"}),
				_g(Vector3(-17.0, 3.6, -16.0), -140.0, [Vector3(-17.0, 3.6, -16.0)], {"sniper": true}),
				_g(Vector3(17.0, 3.6, -16.0), 140.0, [Vector3(17.0, 3.6, -16.0)], {"sniper": true}),
				_g(Vector3(0.0, 3.55, -8.0), 0.0, [Vector3(0.0, 3.55, -8.0)], {"sniper": true}),
				_g(Vector3(-6.0, 0.1, 10.0), 180.0, [Vector3(-6.0, 0.1, 10.0)], {"role": "heavy", "sentry": true}),
				_g(Vector3(6.0, 0.1, 10.0), 180.0, [Vector3(6.0, 0.1, 10.0)], {"role": "heavy", "sentry": true}),
				_g(Vector3(-1.0, 0.1, -6.0), 0.0, [Vector3(-1.0, 0.1, -6.0), Vector3(2.0, 0.1, -6.0)], {"role": "officer"}),
				_g(Vector3(-8.0, 3.4, 2.0), 90.0, [Vector3(-8.0, 3.4, 2.0), Vector3(-4.0, 3.4, 2.0)], {"role": "interior"}),
				_g(Vector3(14.0, 0.1, 0.0), -90.0, [Vector3(14.0, 0.1, 0.0), Vector3(10.0, 0.1, 6.0)], {"role": "handler", "dog_id": "fort_dog"}),
				_g(Vector3(14.8, 0.1, 0.5), -90.0, [Vector3(14.8, 0.1, 0.5), Vector3(10.5, 0.1, 6.5)], {"role": "dog", "dog_id": "fort_dog"}),
			],
		},
		{
			"id": "labour_camp",
			"name": "Holland Valley Labour Camp",
			"theme": "Prison Yard & Searchlights",
			"difficulty": 4,
			"difficulty_label": "Extreme",
			"layout": "ranch_redbarn",
			"unlocks_after": ["lumber_mill", "river_dock"],
			"description": "Fenced labour camp with searchlight towers, cameras on poles, locked sheds, and prowling dogs.",
			"approaches": "South Prison Gate, East Fence Cut, West Drainage Culvert",
			"player_spawn": Vector3(0.0, 0.15, 34.0),
			"sky_top": Color(0.16, 0.22, 0.38),
			"sky_horizon": Color(0.70, 0.55, 0.42),
			"fog_color": Color(0.50, 0.48, 0.46),
			"alarms": [Vector3(-3.0, 0.0, -5.0), Vector3(10.5, 0.0, 6.0), Vector3(-10.0, 0.0, 8.0)],
			"reinforce_points": [Vector3(22.0, 0.1, 20.0), Vector3(-22.0, 0.1, 16.0)],
			"cameras": [Vector3(-6.0, 0.0, 10.0), Vector3(8.0, 0.0, 8.0), Vector3(0.0, 0.0, -8.0)],
			"searchlights": [Vector3(-14.0, 0.0, 6.0), Vector3(14.0, 0.0, -4.0)],
			"tripwires": [Vector3(0.0, 0.0, 18.0), Vector3(8.0, 0.0, 12.0)],
			"keycard_doors": [Vector3(-2.0, 0.0, -6.0)],
			"guards": [
				_g(Vector3(0.0, 0.1, 14.0), 0.0, [Vector3(-5.0, 0.1, 14.0), Vector3(6.0, 0.1, 14.0)]),
				_g(Vector3(-10.0, 0.1, 4.0), 90.0, [Vector3(-12.0, 0.1, 8.0), Vector3(-12.0, 0.1, -6.0)]),
				_g(Vector3(10.5, 0.1, -4.0), -90.0, [Vector3(11.0, 0.1, 5.0), Vector3(11.0, 0.1, -12.0)]),
				_g(Vector3(-1.0, 0.1, -13.0), 180.0, [Vector3(-6.0, 0.1, -14.0), Vector3(6.0, 0.1, -14.0)]),
				_g(Vector3(14.0, 5.65, -12.0), -150.0, [Vector3(14.0, 5.65, -12.0)], {"sniper": true}),
				_g(Vector3(-12.0, 3.55, -10.0), -40.0, [Vector3(-12.0, 3.55, -10.0)], {"sniper": true}),
				_g(Vector3(-8.5, 0.1, -2.0), 0.0, [Vector3(-8.5, 0.1, -2.0), Vector3(-8.5, 3.4, -2.0)], {"role": "interior"}),
				_g(Vector3(6.0, 0.1, 6.0), 180.0, [Vector3(6.0, 0.1, 6.0)], {"role": "heavy", "sentry": true}),
				_g(Vector3(-2.0, 0.1, -4.0), 90.0, [Vector3(-2.0, 0.1, -4.0), Vector3(2.0, 0.1, -4.0)], {"role": "officer"}),
				_g(Vector3(-14.0, 0.1, 10.0), 0.0, [Vector3(-14.0, 0.1, 10.0), Vector3(-10.0, 0.1, 14.0)], {"role": "handler", "dog_id": "camp_dog"}),
				_g(Vector3(-13.0, 0.1, 10.5), 0.0, [Vector3(-13.0, 0.1, 10.5), Vector3(-9.5, 0.1, 14.0)], {"role": "dog", "dog_id": "camp_dog"}),
				_g(Vector3(4.0, 0.1, 10.0), 0.0, [Vector3(4.0, 0.1, 10.0)], {"role": "heavy", "sentry": true}),
			],
		},
		{
			"id": "cult_cathedral",
			"name": "Joseph's Cathedral HQ",
			"theme": "Cult Church Boss Compound",
			"difficulty": 5,
			"difficulty_label": "Boss",
			"layout": "compound_alpha",
			"unlocks_after": ["hilltop_bunker"],
			"description": "Cult headquarters with an elite commander, camera rings, alarm clusters, and overlapping sniper lanes.",
			"approaches": "South Processional Gate, West Choir Breach, North Bell Tower Climb",
			"player_spawn": Vector3(0.0, 0.15, 32.0),
			"sky_top": Color(0.20, 0.18, 0.28),
			"sky_horizon": Color(0.62, 0.40, 0.36),
			"fog_color": Color(0.40, 0.36, 0.40),
			"alarms": [Vector3(1.0, 0.0, -9.8), Vector3(-8.0, 0.0, 4.0), Vector3(8.0, 0.0, 4.0)],
			"reinforce_points": [Vector3(19.0, 0.1, 19.0), Vector3(-19.0, 0.1, 18.0), Vector3(0.0, 0.1, -20.0)],
			"cameras": [Vector3(-8.0, 0.0, 6.0), Vector3(8.0, 0.0, 6.0), Vector3(0.0, 0.0, -8.0), Vector3(-12.0, 0.0, -4.0)],
			"searchlights": [Vector3(0.0, 0.0, 10.0)],
			"tripwires": [Vector3(0.0, 0.0, 18.0)],
			"keycard_doors": [Vector3(1.0, 0.0, -11.0)],
			"guards": [
				_g(Vector3(-10.5, 0.1, 6.0), 0.0, [Vector3(-10.5, 0.1, 8.0), Vector3(-10.5, 0.1, -9.0)]),
				_g(Vector3(11.5, 0.1, 2.0), 180.0, [Vector3(11.5, 0.1, 8.0), Vector3(11.5, 0.1, -8.5)]),
				_g(Vector3(1.0, 0.1, -9.0), 90.0, [Vector3(1.0, 0.1, -9.5), Vector3(1.0, 3.5, -14.0)], {"role": "interior"}),
				_g(Vector3(-15.25, 3.6, -15.25), -135.0, [Vector3(-15.25, 3.6, -15.25)], {"sniper": true}),
				_g(Vector3(14.5, 3.55, -8.0), 45.0, [Vector3(14.5, 3.55, -8.0)], {"sniper": true}),
				_g(Vector3(-14.0, 0.1, 14.0), 180.0, [Vector3(-14.0, 0.1, 14.0)], {"role": "heavy", "sentry": true}),
				_g(Vector3(2.5, 0.1, -12.0), 0.0, [Vector3(2.5, 0.1, -12.0), Vector3(-1.5, 0.1, -12.0)], {"role": "commander"}),
				_g(Vector3(8.0, 0.1, 10.0), 0.0, [Vector3(8.0, 0.1, 10.0), Vector3(12.0, 0.1, 6.0)], {"role": "handler", "dog_id": "cult_dog"}),
				_g(Vector3(9.2, 0.1, 10.0), 0.0, [Vector3(9.2, 0.1, 10.0), Vector3(12.5, 0.1, 6.5)], {"role": "dog", "dog_id": "cult_dog"}),
				_g(Vector3(-6.0, 0.1, -2.0), 90.0, [Vector3(-6.0, 0.1, -2.0)], {"role": "heavy", "sentry": true}),
				_g(Vector3(6.0, 0.1, -4.0), -90.0, [Vector3(6.0, 0.1, -4.0)], {"role": "heavy", "sentry": true}),
				_g(Vector3(0.0, 3.5, -14.0), 0.0, [Vector3(-2.0, 3.5, -14.0), Vector3(2.0, 3.5, -14.0)], {"role": "interior", "sniper": true}),
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




static func difficulty_of(spec: Dictionary) -> int:
	return int(spec.get("difficulty", 1))


static func layout_id(spec: Dictionary) -> String:
	return String(spec.get("layout", spec.get("id", "compound_alpha")))


static func is_unlocked(outpost_id: String) -> bool:
	var spec := get_outpost(outpost_id)
	var req = spec.get("unlocks_after", [])
	if req is Array:
		for oid in req:
			if not GameState.is_liberated(String(oid)):
				return false
	return true

static func role_count(spec: Dictionary, role: String) -> int:
	var n := 0
	for g in spec.get("guards", []):
		if String(g.get("role", "")) == role:
			n += 1
	return n
