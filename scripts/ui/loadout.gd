extends Control
## Pre-mission weapon selection. Primary slot: pistol / rifle / bow. Secondary: knife.

@onready var pistol_btn: Button = $Center/VBox/Primaries/PistolBtn
@onready var rifle_btn: Button = $Center/VBox/Primaries/RifleBtn
@onready var bow_btn: Button = $Center/VBox/Primaries/BowBtn
@onready var desc: Label = $Center/VBox/Desc
@onready var deploy_btn: Button = $Center/VBox/DeployBtn
@onready var back_btn: Button = $Center/VBox/BackBtn

var selected: GameState.WeaponId = GameState.WeaponId.PISTOL


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	selected = GameState.selected_primary
	_refresh()
	for b in [pistol_btn, rifle_btn, bow_btn, deploy_btn, back_btn]:
		b.custom_minimum_size = Vector2(0, 52)


func _refresh() -> void:
	pistol_btn.button_pressed = selected == GameState.WeaponId.PISTOL
	rifle_btn.button_pressed = selected == GameState.WeaponId.RIFLE
	bow_btn.button_pressed = selected == GameState.WeaponId.BOW
	match selected:
		GameState.WeaponId.PISTOL:
			desc.text = "Suppressed Pistol — quiet shots, medium damage. Ideal for stealth clears."
		GameState.WeaponId.RIFLE:
			desc.text = "Assault Rifle — loud and deadly. Expect the whole compound to hear you."
		GameState.WeaponId.BOW:
			desc.text = "Hunting Bow — silent. Arrows can be retrieved. Slow fire rate."
	desc.text += "\nSecondary: Throwing Knife (melee takedown with F / Melee). Rocks: G / Throw."


func _on_pistol() -> void:
	selected = GameState.WeaponId.PISTOL
	_refresh()


func _on_rifle() -> void:
	selected = GameState.WeaponId.RIFLE
	_refresh()


func _on_bow() -> void:
	selected = GameState.WeaponId.BOW
	_refresh()


func _on_deploy() -> void:
	GameState.set_loadout(selected, GameState.WeaponId.KNIFE)
	get_tree().change_scene_to_file("res://scenes/levels/outpost.tscn")


func _on_back() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")
