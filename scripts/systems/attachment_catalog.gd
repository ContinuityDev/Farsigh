extends RefCounted
class_name AttachmentCatalog
## Individual gunsmith attachments that must be purchased (except free defaults).
## Suppressor is always free. Iron / none / standard / default skin are free.


## Free by default — never locked in gunsmith.
const FREE_IDS := {
	"muzzle:none": true,
	"muzzle:suppressor": true,
	"optic:iron": true,
	"mag:standard": true,
	"underbarrel:none": true,
	"arrow:standard": true,
	"skin:default": true,
	"skin:factory": true,
}


static func all_attachments() -> Array:
	return [
		{"id": "att_red_dot", "slot": "optic", "value": "red_dot", "name": "Red Dot Sight", "price": 80},
		{"id": "att_holo", "slot": "optic", "value": "holo", "name": "Holo Sight", "price": 100},
		{"id": "att_scope", "slot": "optic", "value": "scope", "name": "4–8× Scope", "price": 140},
		{"id": "att_compensator", "slot": "muzzle", "value": "compensator", "name": "Compensator", "price": 90},
		{"id": "att_extended", "slot": "mag", "value": "extended", "name": "Extended Mag", "price": 110},
		{"id": "att_grip", "slot": "underbarrel", "value": "grip", "name": "Vertical Grip", "price": 75},
		{"id": "att_laser", "slot": "underbarrel", "value": "laser", "name": "Tactical Laser", "price": 85},
		{"id": "att_fire", "slot": "arrow", "value": "fire", "name": "Fire Tip", "price": 60},
		{"id": "att_explosive", "slot": "arrow", "value": "explosive", "name": "Explosive Warhead", "price": 95},
	]


static func key_for(slot: String, value: String) -> String:
	return "%s:%s" % [slot, value]


static func is_free(slot: String, value: String) -> bool:
	return bool(FREE_IDS.get(key_for(slot, value), false))


static func entry_for(slot: String, value: String) -> Dictionary:
	for e in all_attachments():
		if String(e.get("slot", "")) == slot and String(e.get("value", "")) == value:
			return e
	return {}


static func price_for(slot: String, value: String) -> int:
	if is_free(slot, value):
		return 0
	# Skins use skin_pack
	if slot == "skin" and value not in ["default", "factory"]:
		return 120
	return int(entry_for(slot, value).get("price", 0))


static func shop_id_for(slot: String, value: String) -> String:
	var e := entry_for(slot, value)
	if not e.is_empty():
		return String(e.get("id", ""))
	if slot == "skin" and value not in ["default", "factory"]:
		return "skin_pack"
	return ""
