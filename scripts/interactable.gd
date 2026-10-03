class_name Interactable
extends StaticBody3D
## Anything the player can aim at and press the interact key on.

signal interacted(player: Player)

@export var victim_prompt: String = "Use"
@export var monster_prompt: String = ""
@export var enabled: bool = true

func get_prompt() -> String:
	if not enabled:
		return ""
	if GameState.perspective == GameState.Perspective.MONSTER and monster_prompt != "":
		return monster_prompt
	return victim_prompt

func interact(player: Player) -> void:
	if get_prompt() == "":
		return
	interacted.emit(player)
