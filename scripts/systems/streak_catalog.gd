extends RefCounted
class_name StreakCatalog
## Call-of-Duty-style scorestreaks earned by undetected kill chains.


static func all_streaks() -> Array:
	return [
		{"id": "recon_drone", "name": "Recon Drone", "need": 3, "desc": "Tag all hostiles for 12s", "duration": 12.0},
		{"id": "mortar", "name": "Mortar Mark", "need": 5, "desc": "HE strike on look point", "duration": 0.0},
		{"id": "fangs", "name": "Fangs for Hire", "need": 6, "desc": "Attack dog for 40s", "duration": 40.0},
		{"id": "emp", "name": "EMP Pulse", "need": 7, "desc": "Disable all alarms", "duration": 0.0},
		{"id": "overwatch", "name": "Sniper Overwatch", "need": 8, "desc": "Ally drops 3 distant hostiles", "duration": 0.0},
		{"id": "gunship", "name": "Gunship", "need": 10, "desc": "Area fire for 8s", "duration": 8.0},
	]


static func by_id(id: String) -> Dictionary:
	for s in all_streaks():
		if String(s["id"]) == id:
			return s
	return {}


static func need_for(id: String) -> int:
	return int(by_id(id).get("need", 99))
