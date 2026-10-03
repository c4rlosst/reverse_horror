class_name Interactable
extends StaticBody3D
## Anything the player can aim at and press the interact key on. Optional
## text is shown as a subtitle, with a different line once the player has
## become the monster.

signal interacted(player: Player)

@export var victim_prompt: String = "Use"
@export var monster_prompt: String = ""
@export_multiline var victim_text: String = ""
@export_multiline var monster_text: String = ""
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
	var text := victim_text
	if GameState.perspective == GameState.Perspective.MONSTER and monster_text != "":
		text = monster_text
	if text != "":
		GameState.say(text)
	interacted.emit(player)
