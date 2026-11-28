extends RefCounted
class_name StreakCatalog
## Buyable consumable support abilities (not kill-streak gated).
## New profiles own none and carry zero charges.


static func all_streaks() -> Array:
	return [
		{"id": "recon_drone", "name": "Recon Drone", "short": "Recon", "desc": "Tag all hostiles for 12s", "duration": 12.0, "price": 120, "max_carry": 3},
		{"id": "mortar", "name": "Mortar Mark", "short": "Mortar", "desc": "HE strike on a marked point", "duration": 0.0, "price": 200, "max_carry": 2, "targeted": true},
		{"id": "fangs", "name": "Fangs for Hire", "short": "Fangs", "desc": "Attack dog for 40s", "duration": 40.0, "price": 240, "max_carry": 2},
		{"id": "emp", "name": "EMP Pulse", "short": "EMP", "desc": "Disable all alarms", "duration": 0.0, "price": 180, "max_carry": 3},
		{"id": "overwatch", "name": "Sniper Overwatch", "short": "Overwatch", "desc": "Ally drops 3 distant hostiles", "duration": 0.0, "price": 280, "max_carry": 2},
		{"id": "gunship", "name": "Gunship", "short": "Gunship", "desc": "Area fire for 8s on a marked point", "duration": 8.0, "price": 360, "max_carry": 1, "targeted": true},
	]


static func by_id(id: String) -> Dictionary:
	for s in all_streaks():
		if String(s["id"]) == id:
			return s
	return {}


static func price_for(id: String) -> int:
	return int(by_id(id).get("price", 9999))


static func max_carry(id: String) -> int:
	return int(by_id(id).get("max_carry", 1))


static func is_targeted(id: String) -> bool:
	return bool(by_id(id).get("targeted", false))
