extends Resource
class_name WeaponData
## Full arsenal stats + Gunsmith mod stat computation.
## Headshots one-shot with every weapon via HitZone.HEAD -> 9999.

@export var id: GameState.WeaponId = GameState.WeaponId.PISTOL
@export var display_name: String = "Weapon"
@export var slot_category: String = "primary"  # primary, secondary, special, throwable, melee
@export var description: String = ""
@export var fire_rate: float = 0.35
@export var damage: float = 35.0
@export var magazine_size: int = 12
@export var reserve_ammo: int = 48
@export var reload_time: float = 1.4
@export var noise_loudness: float = 12.0
@export var recoil_pitch: float = 1.4
@export var recoil_yaw: float = 0.4
@export var spread_deg: float = 0.8
@export var pellet_count: int = 1
@export var aim_fov: float = 55.0
@export var scope_overlay: bool = false
@export var ads_time: float = 0.28
@export var ads_spread_mult: float = 0.32
@export var ads_recoil_mult: float = 0.55
@export var ads_move_mult: float = 0.55
@export var is_suppressed: bool = false
@export var is_silent: bool = false
@export var is_melee: bool = false
@export var projectile_kind: String = "hitscan"  # hitscan, arrow, bolt, knife, frag, molotov, melee_swing
@export var arrow_type: String = "standard"      # standard, fire, explosive
@export var explosion_radius: float = 0.0
@export var projectile_speed: float = 80.0
@export var retrievable_projectile: bool = false
@export var automatic: bool = false
@export var max_range: float = 80.0
@export var supports_muzzle: bool = false
@export var supports_optic: bool = false
@export var supports_mag: bool = false
@export var supports_underbarrel: bool = false
@export var supports_arrow: bool = false


static func slot_weapons(slot: String) -> Array[GameState.WeaponId]:
	match slot:
		"primary":
			return [
				GameState.WeaponId.RIFLE,
				GameState.WeaponId.SMG,
				GameState.WeaponId.SHOTGUN,
				GameState.WeaponId.SNIPER,
				GameState.WeaponId.LMG,
				GameState.WeaponId.SILENCED_SNIPER,
				GameState.WeaponId.FLAMETHROWER,
				GameState.WeaponId.GRENADE_LAUNCHER,
			]
		"secondary":
			return [
				GameState.WeaponId.PISTOL,
				GameState.WeaponId.MACHINE_PISTOL,
				GameState.WeaponId.TRANQ_PISTOL,
			]
		"special":
			return [
				GameState.WeaponId.BOW,
				GameState.WeaponId.CROSSBOW,
				GameState.WeaponId.HUNTER_BOW,
			]
		"throwable":
			return [
				GameState.WeaponId.KNIFE,
				GameState.WeaponId.FRAG,
				GameState.WeaponId.MOLOTOV,
				GameState.WeaponId.THROWING_AXE,
				GameState.WeaponId.C4,
				GameState.WeaponId.PROX_MINE,
			]
		"melee":
			return [
				GameState.WeaponId.KNIFE,
				GameState.WeaponId.MACHETE,
				GameState.WeaponId.BAT,
			]
	return [GameState.WeaponId.RIFLE]


static func make_pistol() -> WeaponData:
	var w := WeaponData.new()
	w.id = GameState.WeaponId.PISTOL
	w.display_name = "1911 Tactical"
	w.slot_category = "secondary"
	w.description = "Reliable .45 sidearm. Crisp accuracy and quiet with a suppressor."
	w.fire_rate = 0.26
	w.damage = 34.0
	w.magazine_size = 12
	w.reserve_ammo = 48
	w.reload_time = 1.25
	w.noise_loudness = 34.0
	w.recoil_pitch = 1.5
	w.recoil_yaw = 0.35
	w.spread_deg = 0.65
	w.aim_fov = 56.0
	w.ads_time = 0.18
	w.ads_spread_mult = 0.28
	w.ads_recoil_mult = 0.48
	w.ads_move_mult = 0.62
	w.max_range = 60.0
	w.supports_muzzle = true
	w.supports_optic = true
	w.supports_mag = true
	w.supports_underbarrel = true
	return w


static func make_machine_pistol() -> WeaponData:
	var w := WeaponData.new()
	w.id = GameState.WeaponId.MACHINE_PISTOL
	w.display_name = "Skorpion Machine Pistol"
	w.slot_category = "secondary"
	w.description = "Full-auto compact sidearm that shreds close-quarters patrols."
	w.fire_rate = 0.082
	w.damage = 19.0
	w.magazine_size = 20
	w.reserve_ammo = 80
	w.reload_time = 1.35
	w.noise_loudness = 36.0
	w.recoil_pitch = 1.15
	w.recoil_yaw = 0.75
	w.spread_deg = 2.1
	w.automatic = true
	w.aim_fov = 56.0
	w.ads_time = 0.16
	w.ads_spread_mult = 0.38
	w.ads_recoil_mult = 0.52
	w.ads_move_mult = 0.58
	w.max_range = 42.0
	w.supports_muzzle = true
	w.supports_optic = true
	w.supports_mag = true
	w.supports_underbarrel = true
	return w


static func make_rifle() -> WeaponData:
	var w := WeaponData.new()
	w.id = GameState.WeaponId.RIFLE
	w.display_name = "AR-C Assault Rifle"
	w.slot_category = "primary"
	w.description = "Balanced Hope County militia carbine. Versatile at any range."
	w.fire_rate = 0.10
	w.damage = 28.0
	w.magazine_size = 30
	w.reserve_ammo = 120
	w.reload_time = 1.55
	w.noise_loudness = 48.0
	w.recoil_pitch = 1.25
	w.recoil_yaw = 0.45
	w.spread_deg = 1.0
	w.automatic = true
	w.aim_fov = 52.0
	w.ads_time = 0.26
	w.ads_spread_mult = 0.30
	w.ads_recoil_mult = 0.52
	w.ads_move_mult = 0.52
	w.max_range = 105.0
	w.supports_muzzle = true
	w.supports_optic = true
	w.supports_mag = true
	w.supports_underbarrel = true
	return w


static func make_smg() -> WeaponData:
	var w := WeaponData.new()
	w.id = GameState.WeaponId.SMG
	w.display_name = "MP-40 / Vector SMG"
	w.slot_category = "primary"
	w.description = "High fire-rate submachine gun with low recoil and quick handling."
	w.fire_rate = 0.072
	w.damage = 22.0
	w.magazine_size = 32
	w.reserve_ammo = 128
	w.reload_time = 1.25
	w.noise_loudness = 38.0
	w.recoil_pitch = 0.85
	w.recoil_yaw = 0.55
	w.spread_deg = 1.6
	w.automatic = true
	w.aim_fov = 54.0
	w.ads_time = 0.20
	w.ads_spread_mult = 0.34
	w.ads_recoil_mult = 0.50
	w.ads_move_mult = 0.56
	w.max_range = 58.0
	w.supports_muzzle = true
	w.supports_optic = true
	w.supports_mag = true
	w.supports_underbarrel = true
	return w


static func make_shotgun() -> WeaponData:
	var w := WeaponData.new()
	w.id = GameState.WeaponId.SHOTGUN
	w.display_name = "M133 Pump Shotgun"
	w.slot_category = "primary"
	w.description = "8-pellet buckshot devastator for room clearing and tight hallways."
	w.fire_rate = 0.78
	w.damage = 19.0
	w.pellet_count = 8
	w.magazine_size = 6
	w.reserve_ammo = 30
	w.reload_time = 1.9
	w.noise_loudness = 58.0
	w.recoil_pitch = 4.2
	w.recoil_yaw = 1.1
	w.spread_deg = 5.2
	w.aim_fov = 58.0
	w.ads_time = 0.30
	w.ads_spread_mult = 0.55
	w.ads_recoil_mult = 0.62
	w.ads_move_mult = 0.48
	w.max_range = 32.0
	w.supports_muzzle = true
	w.supports_optic = true
	w.supports_mag = true
	w.supports_underbarrel = true
	return w


static func make_sniper() -> WeaponData:
	var w := WeaponData.new()
	w.id = GameState.WeaponId.SNIPER
	w.display_name = "MBP .50 Sniper Rifle"
	w.slot_category = "primary"
	w.description = "Heavy bolt-action anti-materiel rifle. Long-range overwatch killer."
	w.fire_rate = 1.15
	w.damage = 110.0
	w.magazine_size = 5
	w.reserve_ammo = 25
	w.reload_time = 2.1
	w.noise_loudness = 68.0
	w.recoil_pitch = 5.0
	w.recoil_yaw = 0.6
	w.spread_deg = 0.12
	w.aim_fov = 17.5  # 4x relative to hip 70°; Adjust Zoom steps to 6x/8x at runtime
	w.scope_overlay = true
	w.ads_time = 0.42
	w.ads_spread_mult = 0.18
	w.ads_recoil_mult = 0.42
	w.ads_move_mult = 0.38
	w.max_range = 190.0
	w.supports_muzzle = true
	w.supports_optic = true
	w.supports_mag = true
	w.supports_underbarrel = true
	return w


static func make_lmg() -> WeaponData:
	var w := WeaponData.new()
	w.id = GameState.WeaponId.LMG
	w.display_name = "M60 Light Machine Gun"
	w.slot_category = "primary"
	w.description = "Belt-fed suppression monster. Huge capacity, loud roar, heavy climb."
	w.fire_rate = 0.095
	w.damage = 32.0
	w.magazine_size = 60
	w.reserve_ammo = 180
	w.reload_time = 2.6
	w.noise_loudness = 62.0
	w.recoil_pitch = 1.95
	w.recoil_yaw = 1.05
	w.spread_deg = 2.2
	w.automatic = true
	w.aim_fov = 54.0
	w.ads_time = 0.38
	w.ads_spread_mult = 0.36
	w.ads_recoil_mult = 0.58
	w.ads_move_mult = 0.42
	w.max_range = 115.0
	w.supports_muzzle = true
	w.supports_optic = true
	w.supports_mag = true
	w.supports_underbarrel = true
	return w


static func make_bow() -> WeaponData:
	var w := WeaponData.new()
	w.id = GameState.WeaponId.BOW
	w.display_name = "Compound Bow"
	w.slot_category = "special"
	w.description = "Whisper-quiet recurve/compound bow. Supports standard, fire & explosive arrows."
	w.fire_rate = 0.85
	w.damage = 78.0
	w.magazine_size = 1
	w.reserve_ammo = 14
	w.reload_time = 0.72
	w.noise_loudness = 1.5
	w.recoil_pitch = 1.1
	w.recoil_yaw = 0.15
	w.spread_deg = 0.25
	w.aim_fov = 48.0
	w.ads_time = 0.34
	w.ads_spread_mult = 0.22
	w.ads_recoil_mult = 0.45
	w.ads_move_mult = 0.48
	w.is_silent = true
	w.projectile_kind = "arrow"
	w.projectile_speed = 60.0
	w.retrievable_projectile = true
	w.max_range = 75.0
	w.supports_optic = true
	w.supports_arrow = true
	return w


static func make_crossbow() -> WeaponData:
	var w := WeaponData.new()
	w.id = GameState.WeaponId.CROSSBOW
	w.display_name = "Tactical Crossbow"
	w.slot_category = "special"
	w.description = "3-bolt magazine silent crossbow with flatter trajectory & scope rail."
	w.fire_rate = 0.58
	w.damage = 95.0
	w.magazine_size = 3
	w.reserve_ammo = 15
	w.reload_time = 1.65
	w.noise_loudness = 2.2
	w.recoil_pitch = 0.9
	w.recoil_yaw = 0.12
	w.spread_deg = 0.15
	w.aim_fov = 42.0
	w.ads_time = 0.30
	w.ads_spread_mult = 0.20
	w.ads_recoil_mult = 0.40
	w.ads_move_mult = 0.50
	w.is_silent = true
	w.projectile_kind = "bolt"
	w.projectile_speed = 76.0
	w.retrievable_projectile = true
	w.max_range = 95.0
	w.supports_optic = true
	w.supports_mag = true
	w.supports_arrow = true
	return w


static func make_knife() -> WeaponData:
	var w := WeaponData.new()
	w.id = GameState.WeaponId.KNIFE
	w.display_name = "Throwing Knives"
	w.slot_category = "throwable"
	w.description = "Balanced stealth throwing blades. Silent, retrievable, lethal."
	w.fire_rate = 0.50
	w.damage = 100.0
	w.magazine_size = 4
	w.reserve_ammo = 4
	w.reload_time = 0.75
	w.noise_loudness = 3.5
	w.recoil_pitch = 0.6
	w.recoil_yaw = 0.2
	w.aim_fov = 58.0
	w.ads_time = 0.22
	w.ads_spread_mult = 0.25
	w.ads_recoil_mult = 0.55
	w.ads_move_mult = 0.60
	w.is_silent = true
	w.is_melee = true
	w.projectile_kind = "knife"
	w.projectile_speed = 38.0
	w.retrievable_projectile = true
	w.max_range = 28.0
	return w


static func make_frag() -> WeaponData:
	var w := WeaponData.new()
	w.id = GameState.WeaponId.FRAG
	w.display_name = "M67 Frag Grenade"
	w.slot_category = "throwable"
	w.description = "Timed high-explosive fragmentation grenade. Clears rooms and vehicle clusters."
	w.fire_rate = 0.95
	w.damage = 165.0
	w.explosion_radius = 6.8
	w.magazine_size = 3
	w.reserve_ammo = 3
	w.reload_time = 0.8
	w.noise_loudness = 8.0
	w.aim_fov = 60.0
	w.ads_time = 0.24
	w.ads_move_mult = 0.58
	w.projectile_kind = "frag"
	w.projectile_speed = 18.0
	w.max_range = 32.0
	return w


static func make_molotov() -> WeaponData:
	var w := WeaponData.new()
	w.id = GameState.WeaponId.MOLOTOV
	w.display_name = "Molotov Cocktail"
	w.slot_category = "throwable"
	w.description = "Shatters on impact into an intense pool of burning fuel."
	w.fire_rate = 0.95
	w.damage = 28.0
	w.explosion_radius = 4.6
	w.magazine_size = 3
	w.reserve_ammo = 3
	w.reload_time = 0.8
	w.noise_loudness = 6.0
	w.aim_fov = 60.0
	w.ads_time = 0.24
	w.ads_move_mult = 0.58
	w.projectile_kind = "molotov"
	w.projectile_speed = 16.0
	w.max_range = 28.0
	return w


static func make_machete() -> WeaponData:
	var w := WeaponData.new()
	w.id = GameState.WeaponId.MACHETE
	w.display_name = "Kukri Machete"
	w.slot_category = "melee"
	w.description = "Heavy curved jungle blade. Silent devastating slashes up close."
	w.fire_rate = 0.52
	w.damage = 90.0
	w.magazine_size = 1
	w.reserve_ammo = 0
	w.noise_loudness = 3.0
	w.recoil_pitch = 0.8
	w.aim_fov = 62.0
	w.ads_time = 0.16
	w.ads_move_mult = 0.72
	w.is_silent = true
	w.is_melee = true
	w.projectile_kind = "melee_swing"
	w.max_range = 2.6
	return w


static func make_bat() -> WeaponData:
	var w := WeaponData.new()
	w.id = GameState.WeaponId.BAT
	w.display_name = "Aluminum Bat"
	w.slot_category = "melee"
	w.description = "Hope County slugger. Wide heavy swing with lethal head-crack."
	w.fire_rate = 0.62
	w.damage = 82.0
	w.magazine_size = 1
	w.reserve_ammo = 0
	w.noise_loudness = 8.0
	w.recoil_pitch = 1.2
	w.aim_fov = 62.0
	w.ads_time = 0.16
	w.ads_move_mult = 0.72
	w.is_melee = true
	w.projectile_kind = "melee_swing"
	w.max_range = 2.7
	return w




static func make_silenced_sniper() -> WeaponData:
	var w := make_sniper()
	w.id = GameState.WeaponId.SILENCED_SNIPER
	w.display_name = "Silenced Sniper"
	w.description = "Subsonic bolt gun. Near-silent long shots."
	w.noise_loudness = 8.0
	w.is_suppressed = true
	w.is_silent = true
	w.damage = 120.0
	w.fire_rate = 1.15
	return w


static func make_flamethrower() -> WeaponData:
	var w := WeaponData.new()
	w.id = GameState.WeaponId.FLAMETHROWER
	w.display_name = "Flamethrower"
	w.slot_category = "primary"
	w.description = "Short-range fire stream. Loud and messy."
	w.fire_rate = 0.08
	w.damage = 18.0
	w.magazine_size = 60
	w.reserve_ammo = 120
	w.reload_time = 2.4
	w.noise_loudness = 42.0
	w.automatic = true
	w.spread_deg = 4.0
	w.max_range = 12.0
	w.projectile_kind = "hitscan"
	w.aim_fov = 58.0
	return w


static func make_grenade_launcher() -> WeaponData:
	var w := WeaponData.new()
	w.id = GameState.WeaponId.GRENADE_LAUNCHER
	w.display_name = "Grenade Launcher"
	w.slot_category = "primary"
	w.description = "Lobbed HE rounds. Clears rooms."
	w.fire_rate = 0.85
	w.damage = 110.0
	w.magazine_size = 4
	w.reserve_ammo = 12
	w.reload_time = 2.6
	w.noise_loudness = 55.0
	w.projectile_kind = "frag"
	w.explosion_radius = 5.5
	w.projectile_speed = 28.0
	w.max_range = 55.0
	w.aim_fov = 52.0
	return w


static func make_hunter_bow() -> WeaponData:
	var w := make_bow()
	w.id = GameState.WeaponId.HUNTER_BOW
	w.display_name = "Hunter Recurve"
	w.description = "Quiet recurve. Dog-whistle tip distracts canines."
	w.noise_loudness = 1.0
	w.is_silent = true
	w.damage = 95.0
	w.arrow_type = "whistle"
	return w


static func make_tranq_pistol() -> WeaponData:
	var w := make_pistol()
	w.id = GameState.WeaponId.TRANQ_PISTOL
	w.display_name = "Tranq Pistol"
	w.description = "Non-lethal darts. Hostiles wake after ~45s."
	w.noise_loudness = 6.0
	w.is_suppressed = true
	w.is_silent = true
	w.damage = 9999.0
	w.projectile_kind = "tranq"
	w.magazine_size = 8
	w.reserve_ammo = 24
	return w


static func make_throwing_axe() -> WeaponData:
	var w := make_knife()
	w.id = GameState.WeaponId.THROWING_AXE
	w.display_name = "Throwing Axe"
	w.description = "Heavy silent axe. One-shot torso."
	w.damage = 9999.0
	w.noise_loudness = 2.5
	w.projectile_kind = "knife"
	w.magazine_size = 4
	w.reserve_ammo = 8
	return w


static func make_c4() -> WeaponData:
	var w := make_frag()
	w.id = GameState.WeaponId.C4
	w.display_name = "C4 Charge"
	w.description = "Place and detonate. Massive blast."
	w.projectile_kind = "c4"
	w.explosion_radius = 7.0
	w.damage = 200.0
	w.noise_loudness = 70.0
	w.magazine_size = 2
	w.reserve_ammo = 2
	return w


static func make_prox_mine() -> WeaponData:
	var w := make_frag()
	w.id = GameState.WeaponId.PROX_MINE
	w.display_name = "Proximity Mine"
	w.description = "Arms after place. Trips on hostiles."
	w.projectile_kind = "prox_mine"
	w.explosion_radius = 4.5
	w.damage = 140.0
	w.noise_loudness = 48.0
	w.magazine_size = 3
	w.reserve_ammo = 3
	return w


static func from_id(id: GameState.WeaponId, mods: Dictionary = {}) -> WeaponData:
	var w: WeaponData
	match id:
		GameState.WeaponId.PISTOL:
			w = make_pistol()
		GameState.WeaponId.MACHINE_PISTOL:
			w = make_machine_pistol()
		GameState.WeaponId.RIFLE:
			w = make_rifle()
		GameState.WeaponId.SMG:
			w = make_smg()
		GameState.WeaponId.SHOTGUN:
			w = make_shotgun()
		GameState.WeaponId.SNIPER:
			w = make_sniper()
		GameState.WeaponId.LMG:
			w = make_lmg()
		GameState.WeaponId.BOW:
			w = make_bow()
		GameState.WeaponId.CROSSBOW:
			w = make_crossbow()
		GameState.WeaponId.KNIFE:
			w = make_knife()
		GameState.WeaponId.FRAG:
			w = make_frag()
		GameState.WeaponId.MOLOTOV:
			w = make_molotov()
		GameState.WeaponId.MACHETE:
			w = make_machete()
		GameState.WeaponId.BAT:
			w = make_bat()
		GameState.WeaponId.SILENCED_SNIPER:
			w = make_silenced_sniper()
		GameState.WeaponId.FLAMETHROWER:
			w = make_flamethrower()
		GameState.WeaponId.GRENADE_LAUNCHER:
			w = make_grenade_launcher()
		GameState.WeaponId.HUNTER_BOW:
			w = make_hunter_bow()
		GameState.WeaponId.TRANQ_PISTOL:
			w = make_tranq_pistol()
		GameState.WeaponId.THROWING_AXE:
			w = make_throwing_axe()
		GameState.WeaponId.C4:
			w = make_c4()
		GameState.WeaponId.PROX_MINE:
			w = make_prox_mine()
		_:
			w = make_pistol()
	if not mods.is_empty():
		apply_mods(w, mods)
	return w


static func apply_mods(w: WeaponData, mods: Dictionary) -> void:
	# Muzzle attachment: suppressor cuts noise drastically & slightly trims range; compensator cuts recoil
	if w.supports_muzzle:
		var muzzle := String(mods.get("muzzle", "none"))
		if muzzle == "suppressor":
			w.is_suppressed = true
			w.noise_loudness = maxf(6.0, w.noise_loudness * 0.24)
			w.max_range *= 0.84
			w.damage *= 0.94
		elif muzzle == "compensator":
			w.recoil_pitch *= 0.68
			w.recoil_yaw *= 0.65
			w.noise_loudness *= 1.08

	# Optic attachment: FOV is relative to hip FOV 70° so zoom reads clearly in ADS.
	# red_dot ≈ 1.5x, holo ≈ 2x, scope ≈ 4x (variable 4/6/8x handled at runtime).
	const HIP_FOV := 70.0
	if w.supports_optic:
		var optic := String(mods.get("optic", "iron"))
		# Snipers always use a magnified scope (default 4x) — never leave them on iron.
		if w.id in [GameState.WeaponId.SNIPER, GameState.WeaponId.SILENCED_SNIPER] and optic in ["", "iron"]:
			optic = "scope"
		match optic:
			"red_dot":
				w.aim_fov = HIP_FOV / 1.5  # ≈ 46.7°
				w.scope_overlay = false
				w.spread_deg *= 0.85
				w.ads_time *= 0.92
			"holo":
				w.aim_fov = HIP_FOV / 2.0  # 35°
				w.scope_overlay = false
				w.spread_deg *= 0.78
				w.ads_time *= 0.95
			"scope":
				w.aim_fov = HIP_FOV / 4.0  # 17.5° base 4x; player can step to 6x/8x
				w.scope_overlay = true
				w.spread_deg *= 0.55
				w.max_range *= 1.15
				w.ads_time *= 1.18
				w.ads_move_mult *= 0.85
			_:
				# Iron sights — ~1.2× ADS zoom (Hayden: 1.1–1.25×)
				w.aim_fov = HIP_FOV / 1.2  # ≈ 58.3°
				w.scope_overlay = false

	# Magazine attachment: extended mag increases capacity, slightly slower reload
	if w.supports_mag:
		var mag := String(mods.get("mag", "standard"))
		if mag == "extended":
			w.magazine_size = int(ceil(float(w.magazine_size) * 1.5))
			w.reserve_ammo = int(ceil(float(w.reserve_ammo) * 1.35))
			w.reload_time *= 1.15

	# Underbarrel attachment: vertical grip cuts recoil; tactical laser tightens hipfire spread
	if w.supports_underbarrel:
		var ub := String(mods.get("underbarrel", "none"))
		if ub == "grip":
			w.recoil_pitch *= 0.70
			w.recoil_yaw *= 0.72
			w.ads_recoil_mult *= 0.88
			w.ads_time *= 0.94
		elif ub == "laser":
			w.spread_deg *= 0.52
			w.ads_spread_mult *= 0.90

	# Arrow / Bolt payload type for Bow & Crossbow
	if w.supports_arrow:
		var arrow := String(mods.get("arrow", "standard"))
		w.arrow_type = arrow
		if arrow == "fire":
			w.retrievable_projectile = false
			w.display_name += " [Fire]"
		elif arrow == "explosive":
			w.retrievable_projectile = false
			w.noise_loudness = 4.0
			w.display_name += " [Explosive]"
