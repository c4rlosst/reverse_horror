class_name HidingSpot
extends Interactable
## A closet, bed or pantry the player can crawl into and peek out of.
## The same spot is reused after the reversal, where "Hide" becomes "Wait".

@export var hide_offset: Vector3 = Vector3.ZERO
@export var exit_offset: Vector3 = Vector3(0, 0, 1.2)
## Direction the player faces while hidden, in degrees around Y.
@export var facing_degrees: float = 0.0
@export var peek_range_degrees: float = 35.0
## Camera height while hidden (a bed is far lower than a closet).
@export var peek_height: float = 1.3

func _init() -> void:
	victim_prompt = "Hide"
	monster_prompt = "Wait"

func interact(player: Player) -> void:
	if not enabled:
		return
	GameState.raise_event(&"hid", name)
	player.enter_hiding(self)

func hide_position() -> Vector3:
	return global_transform * hide_offset

func exit_position() -> Vector3:
	return global_transform * exit_offset
