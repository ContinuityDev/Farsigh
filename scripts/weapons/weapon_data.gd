extends Resource
class_name WeaponData
## Static weapon stats. Noise drives AI hearing; damage drives combat.

@export var id: GameState.WeaponId = GameState.WeaponId.PISTOL
@export var display_name: String = "Weapon"
@export var fire_rate: float = 0.35
@export var damage: float = 35.0
@export var magazine_size: int = 12
@export var reserve_ammo: int = 48
@export var noise_loudness: float = 12.0
@export var is_suppressed: bool = false
@export var is_silent: bool = false
@export var is_melee: bool = false
@export var projectile_speed: float = 80.0
@export var retrievable_projectile: bool = false
@export var automatic: bool = false
@export var max_range: float = 80.0


static func make_pistol() -> WeaponData:
	var w := WeaponData.new()
	w.id = GameState.WeaponId.PISTOL
	w.display_name = "Suppressed Pistol"
	w.fire_rate = 0.28
	w.damage = 34.0
	w.magazine_size = 12
	w.reserve_ammo = 48
	w.noise_loudness = 10.0
	w.is_suppressed = true
	w.projectile_speed = 120.0
	w.max_range = 50.0
	return w


static func make_rifle() -> WeaponData:
	var w := WeaponData.new()
	w.id = GameState.WeaponId.RIFLE
	w.display_name = "Assault Rifle"
	w.fire_rate = 0.1
	w.damage = 28.0
	w.magazine_size = 30
	w.reserve_ammo = 90
	w.noise_loudness = 48.0
	w.automatic = true
	w.projectile_speed = 160.0
	w.max_range = 100.0
	return w


static func make_bow() -> WeaponData:
	var w := WeaponData.new()
	w.id = GameState.WeaponId.BOW
	w.display_name = "Hunting Bow"
	w.fire_rate = 0.9
	w.damage = 70.0
	w.magazine_size = 1
	w.reserve_ammo = 12
	w.noise_loudness = 1.5
	w.is_silent = true
	w.projectile_speed = 55.0
	w.retrievable_projectile = true
	w.max_range = 60.0
	return w


static func make_knife() -> WeaponData:
	var w := WeaponData.new()
	w.id = GameState.WeaponId.KNIFE
	w.display_name = "Throwing Knife"
	w.fire_rate = 0.55
	w.damage = 100.0
	w.magazine_size = 3
	w.reserve_ammo = 3
	w.noise_loudness = 4.0
	w.is_silent = true
	w.is_melee = true
	w.projectile_speed = 35.0
	w.retrievable_projectile = true
	w.max_range = 25.0
	return w


static func from_id(id: GameState.WeaponId) -> WeaponData:
	match id:
		GameState.WeaponId.PISTOL:
			return make_pistol()
		GameState.WeaponId.RIFLE:
			return make_rifle()
		GameState.WeaponId.BOW:
			return make_bow()
		GameState.WeaponId.KNIFE:
			return make_knife()
	return make_pistol()
