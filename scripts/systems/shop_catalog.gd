extends RefCounted
class_name ShopCatalog
## Currency prices and unlock catalog. Tuned so ~1–3 clears buy a new special weapon.

# --- Currency earn rates ---
const BASE_REWARD := {
	"compound_alpha": 180,
	"ranch_redbarn": 200,
	"lumber_mill": 210,
	"river_dock": 200,
	"hilltop_bunker": 240,
}
const BONUS_UNDETECTED := 100
const BONUS_NO_ALARMS := 75
const BONUS_HEADSHOT := 5
const BONUS_TAKEDOWN := 15
const BONUS_BODY_HIDDEN := 10
const BONUS_SPEED := 50  # under 4 minutes
const SPEED_LIMIT_SEC := 240.0
const REPLAY_MULT := 0.5


static func base_for(outpost_id: String) -> int:
	return int(BASE_REWARD.get(outpost_id, 180))


static func compute_payout(outpost_id: String, stats: Dictionary, is_replay: bool) -> Dictionary:
	var base := base_for(outpost_id)
	var lines: Array = [{"label": "Base clear", "amount": base}]
	var total := base
	if bool(stats.get("undetected", false)):
		lines.append({"label": "Ghost — undetected", "amount": BONUS_UNDETECTED})
		total += BONUS_UNDETECTED
	if bool(stats.get("no_alarms", true)):
		lines.append({"label": "Silent compound — no alarms", "amount": BONUS_NO_ALARMS})
		total += BONUS_NO_ALARMS
	var hs := int(stats.get("headshots", 0))
	if hs > 0:
		var a := hs * BONUS_HEADSHOT
		lines.append({"label": "Headshots ×%d" % hs, "amount": a})
		total += a
	var td := int(stats.get("takedowns", 0))
	if td > 0:
		var a2 := td * BONUS_TAKEDOWN
		lines.append({"label": "Takedowns ×%d" % td, "amount": a2})
		total += a2
	var hid := int(stats.get("bodies_hidden", 0))
	if hid > 0:
		var a3 := hid * BONUS_BODY_HIDDEN
		lines.append({"label": "Bodies hidden ×%d" % hid, "amount": a3})
		total += a3
	var elapsed := float(stats.get("elapsed_sec", 9999.0))
	if elapsed <= SPEED_LIMIT_SEC:
		lines.append({"label": "Speed clear (<4 min)", "amount": BONUS_SPEED})
		total += BONUS_SPEED
	if is_replay:
		var reduced := int(round(float(total) * REPLAY_MULT))
		lines.append({"label": "Replay (50%)", "amount": reduced - total})
		total = reduced
	return {"total": total, "lines": lines}


# --- Shop entries ---
# kind: weapon | item | ability | streak | mod | skin

static func all_entries() -> Array:
	return [
		# Special weapons (~1–3 clears)
		{"id": "silenced_sniper", "kind": "weapon", "weapon": GameState.WeaponId.SILENCED_SNIPER, "name": "Silenced Sniper", "desc": "Subsonic bolt rifle. Near-silent long shots.", "price": 400, "slot": "primary"},
		{"id": "flamethrower", "kind": "weapon", "weapon": GameState.WeaponId.FLAMETHROWER, "name": "Flamethrower", "desc": "Short-range fire stream. Loud and messy.", "price": 450, "slot": "primary"},
		{"id": "grenade_launcher", "kind": "weapon", "weapon": GameState.WeaponId.GRENADE_LAUNCHER, "name": "Grenade Launcher", "desc": "Lobbed HE rounds. Clears rooms.", "price": 500, "slot": "primary"},
		{"id": "hunter_bow", "kind": "weapon", "weapon": GameState.WeaponId.HUNTER_BOW, "name": "Hunter Recurve", "desc": "Quiet bow. Dog-whistle tip distracts dogs.", "price": 350, "slot": "special"},
		{"id": "tranq_pistol", "kind": "weapon", "weapon": GameState.WeaponId.TRANQ_PISTOL, "name": "Tranq Pistol", "desc": "Non-lethal darts. Guards wake after ~45s.", "price": 300, "slot": "secondary"},
		{"id": "throwing_axes", "kind": "weapon", "weapon": GameState.WeaponId.THROWING_AXE, "name": "Throwing Axes", "desc": "Heavy silent throwables. One-shot torso.", "price": 250, "slot": "throwable"},
		{"id": "c4", "kind": "weapon", "weapon": GameState.WeaponId.C4, "name": "C4 Charge", "desc": "Place and detonate. Massive blast.", "price": 350, "slot": "throwable"},
		{"id": "prox_mine", "kind": "weapon", "weapon": GameState.WeaponId.PROX_MINE, "name": "Proximity Mine", "desc": "Arms after place. Trips on hostiles.", "price": 300, "slot": "throwable"},
		# Items / abilities
		{"id": "lure", "kind": "item", "name": "Distraction Lure", "desc": "Throws a noisemaker that pulls patrols.", "price": 120},
		{"id": "binoculars", "kind": "item", "name": "Tagging Binoculars", "desc": "ADS marks nearby hostiles for 20s.", "price": 180},
		{"id": "medkit", "kind": "item", "name": "Field Medkit", "desc": "Restore 50 HP (one use per deploy).", "price": 100},
		{"id": "alarm_jammer", "kind": "item", "name": "Alarm Jammer", "desc": "Disables nearest alarm on use.", "price": 220},
		{"id": "ghillie", "kind": "ability", "name": "Ghillie Suit", "desc": "Harder to spot while crouched in grass.", "price": 260},
		{"id": "adrenaline", "kind": "ability", "name": "Adrenaline", "desc": "Faster takedowns and vaults.", "price": 200},
		{"id": "armor", "kind": "ability", "name": "Plate Carrier", "desc": "+40 max HP every deploy.", "price": 240},
		# Gunsmith unlocks
		{"id": "mod_pack", "kind": "mod", "name": "Advanced Mod Kit", "desc": "Unlocks compensator, holo, extended mag, laser for owned guns.", "price": 150},
		{"id": "skin_pack", "kind": "skin", "name": "Finish Pack", "desc": "Unlocks olive, tan, crimson, arctic, gold skins.", "price": 120},
		# Streak unlocks
		{"id": "streak_recon", "kind": "streak", "streak": "recon_drone", "name": "Recon Drone", "desc": "Streak 3 — tags hostiles for 12s.", "price": 200},
		{"id": "streak_mortar", "kind": "streak", "streak": "mortar", "name": "Mortar Mark", "desc": "Streak 5 — HE on look-point.", "price": 350},
		{"id": "streak_fangs", "kind": "streak", "streak": "fangs", "name": "Fangs for Hire", "desc": "Streak 6 — attack dog companion.", "price": 400},
		{"id": "streak_emp", "kind": "streak", "streak": "emp", "name": "EMP Pulse", "desc": "Streak 7 — fries every alarm.", "price": 300},
		{"id": "streak_overwatch", "kind": "streak", "streak": "overwatch", "name": "Sniper Overwatch", "desc": "Streak 8 — ally drops distant hostiles.", "price": 450},
		{"id": "streak_gunship", "kind": "streak", "streak": "gunship", "name": "Gunship", "desc": "Streak 10 — area suppression around you.", "price": 600},
	]


static func entry(id: String) -> Dictionary:
	for e in all_entries():
		if String(e.get("id", "")) == id:
			return e
	return {}
