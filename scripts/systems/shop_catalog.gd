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
	"eden_fortress": 420,
	"labour_camp": 400,
	"cult_cathedral": 520,
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
		{"id": "lure", "kind": "item", "name": "Distraction Lure", "desc": "Gadget: noisemaker that pulls patrols (Q/T).", "price": 120},
		{"id": "smoke", "kind": "item", "name": "Smoke Canister", "desc": "Gadget: deploys a concealment cloud.", "price": 140},
		{"id": "decoy", "kind": "item", "name": "Audio Decoy", "desc": "Gadget: loud distraction away from you.", "price": 130},
		{"id": "binoculars_pro", "kind": "item", "name": "Pro Binoculars", "desc": "Upgrade: faster tagging (0.25s) and longer mark range.", "price": 180},
		{"id": "medkit", "kind": "item", "name": "Field Medkit", "desc": "Restore 50 HP (one use per deploy).", "price": 100},
		{"id": "alarm_jammer", "kind": "item", "name": "Alarm Jammer", "desc": "Gadget: disables nearest alarm on use (Q/T).", "price": 220},
		{"id": "ghillie", "kind": "ability", "name": "Ghillie Suit", "desc": "Harder to spot while crouched in grass.", "price": 260},
		{"id": "adrenaline", "kind": "ability", "name": "Adrenaline", "desc": "Faster takedowns and vaults.", "price": 200},
		# Consumable deploy buff (NOT the persistent armour upgrade)
		{"id": "armor", "kind": "ability", "name": "Field Plate Insert", "desc": "Consumable buff: +40 max HP this deploy only. Distinct from Armour Upgrade tiers.", "price": 140},
		# Persistent armour upgrade tiers (profile)
		{"id": "armour_t1", "kind": "armour", "tier": 1, "name": "Armour Upgrade I", "desc": "Persistent: +20 armour bar, 15% damage reduction. Survives between runs.", "price": 180},
		{"id": "armour_t2", "kind": "armour", "tier": 2, "name": "Armour Upgrade II", "desc": "Persistent: +40 armour bar, 25% DR. Requires Tier I.", "price": 320},
		{"id": "armour_t3", "kind": "armour", "tier": 3, "name": "Armour Upgrade III", "desc": "Persistent: +60 armour bar, 35% DR. Requires Tier II.", "price": 480},
		# Individual gunsmith attachments (suppressor stays free — not listed)
		{"id": "att_red_dot", "kind": "attachment", "slot": "optic", "value": "red_dot", "name": "Red Dot Sight", "desc": "Unlock red-dot optic in Gunsmith.", "price": 80},
		{"id": "att_holo", "kind": "attachment", "slot": "optic", "value": "holo", "name": "Holo Sight", "desc": "Unlock holo optic in Gunsmith.", "price": 100},
		{"id": "att_scope", "kind": "attachment", "slot": "optic", "value": "scope", "name": "4–8× Scope", "desc": "Unlock magnified scope + Adjust Zoom.", "price": 140},
		{"id": "att_compensator", "kind": "attachment", "slot": "muzzle", "value": "compensator", "name": "Compensator", "desc": "Unlock compensator muzzle (suppressor is free).", "price": 90},
		{"id": "att_extended", "kind": "attachment", "slot": "mag", "value": "extended", "name": "Extended Mag", "desc": "Unlock +50% magazine capacity.", "price": 110},
		{"id": "att_grip", "kind": "attachment", "slot": "underbarrel", "value": "grip", "name": "Vertical Grip", "desc": "Unlock underbarrel grip.", "price": 75},
		{"id": "att_laser", "kind": "attachment", "slot": "underbarrel", "value": "laser", "name": "Tactical Laser", "desc": "Unlock underbarrel laser.", "price": 85},
		{"id": "att_fire", "kind": "attachment", "slot": "arrow", "value": "fire", "name": "Fire Tip", "desc": "Unlock fire arrows/bolts.", "price": 60},
		{"id": "att_explosive", "kind": "attachment", "slot": "arrow", "value": "explosive", "name": "Explosive Warhead", "desc": "Unlock explosive arrows/bolts.", "price": 95},
		{"id": "skin_pack", "kind": "skin", "name": "Finish Pack", "desc": "Unlocks olive, tan, crimson, arctic, gold skins.", "price": 120},
		# Legacy bundle (still purchasable — unlocks all attachments at once)
		{"id": "mod_pack", "kind": "mod", "name": "Advanced Mod Kit", "desc": "Unlocks every paid attachment at once (bundle).", "price": 420},
		# Consumable support charges
		{"id": "streak_recon", "kind": "streak", "streak": "recon_drone", "name": "Recon Drone Charge", "desc": "Consumable — tags hostiles for 12s. Buy charges in shop.", "price": 120},
		{"id": "streak_mortar", "kind": "streak", "streak": "mortar", "name": "Mortar Mark Charge", "desc": "Consumable — HE on look-point.", "price": 200},
		{"id": "streak_fangs", "kind": "streak", "streak": "fangs", "name": "Fangs for Hire Charge", "desc": "Consumable — attack dog companion.", "price": 240},
		{"id": "streak_emp", "kind": "streak", "streak": "emp", "name": "EMP Pulse Charge", "desc": "Consumable — fries every alarm.", "price": 180},
		{"id": "streak_overwatch", "kind": "streak", "streak": "overwatch", "name": "Sniper Overwatch Charge", "desc": "Consumable — ally drops distant hostiles.", "price": 280},
		{"id": "streak_gunship", "kind": "streak", "streak": "gunship", "name": "Gunship Charge", "desc": "Consumable — area suppression.", "price": 360},
		# Guns for Hire allies (consumable hires per run — like supports)
		{"id": "ally_sniper", "kind": "ally", "ally": "sniper", "name": "Hire: Grace (Sniper)", "desc": "Ally sniper — holds overwatch, engages tagged targets. Consumable hire.", "price": 280},
		{"id": "ally_stalker", "kind": "ally", "ally": "stalker", "name": "Hire: Jess (Stalker)", "desc": "Stealth melee ally — quiet takedowns on marked hostiles. Consumable hire.", "price": 260},
		{"id": "ally_gunner", "kind": "ally", "ally": "gunner", "name": "Hire: Hurk (Gunner)", "desc": "Loud gunner — follows and lays fire on tagged enemies. Consumable hire.", "price": 300},
		{"id": "ally_beast", "kind": "ally", "ally": "beast", "name": "Hire: Boomer (Beast)", "desc": "Animal companion — flushes and bites tagged prey. Consumable hire.", "price": 240},
	]


static func entry(id: String) -> Dictionary:
	for e in all_entries():
		if String(e.get("id", "")) == id:
			return e
	return {}
