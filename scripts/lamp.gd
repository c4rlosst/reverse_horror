class_name Lamp
extends Interactable
## A table lamp. Only the monster can work it: the victim has no reason to
## touch the lights, but the monster can put a room back into the dark.

var light: FlickeringLight
var bulb: MeshInstance3D

func _init() -> void:
	victim_prompt = ""
	monster_prompt = "Switch off"

func interact(player: Player) -> void:
	if get_prompt() == "":
		return
	var turn_on := not light.switched_on
	light.switch(turn_on, 0.15)
	_set_bulb(turn_on)
	monster_prompt = "Switch off" if turn_on else "Switch on"
	Sfx.play_at(&"click", global_position, 2.0)
	GameState.raise_event(&"lamp_on" if turn_on else &"lamp_off", name)
	interacted.emit(player)

func _set_bulb(on: bool) -> void:
	if bulb == null:
		return
	var material := bulb.material_override as StandardMaterial3D
	material.emission_energy_multiplier = 0.8 if on else 0.0
