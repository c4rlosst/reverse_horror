class_name HidingSpot
extends Interactable
## A closet, bed or pantry the player can crawl into and peek out of. The
## monster uses the same spots to wait out the family's flashlight.

## Raised instead of hiding when `monster_interacts` is set and the player
## has already become the monster (the bed becomes the ending).
@export var monster_interacts: bool = false
@export var hide_offset: Vector3 = Vector3.ZERO
@export var exit_offset: Vector3 = Vector3(0, 0, 1.2)
## Direction the player faces while hidden, in degrees around Y.
@export var facing_degrees: float = 0.0
@export var peek_range_degrees: float = 35.0
## Camera height while hidden (a bed is far lower than a closet).
@export var peek_height: float = 1.3
## Where a searcher stands to check this spot.
@export var check_point: Vector3 = Vector3.ZERO

func _init() -> void:
	victim_prompt = "Hide"
	monster_prompt = "Wait"

func interact(player: Player) -> void:
	if get_prompt() == "":
		return
	if monster_interacts and GameState.perspective == GameState.Perspective.MONSTER:
		interacted.emit(player)
		return
	GameState.hide_count += 1
	GameState.raise_event(&"hid", name)
	Sfx.play(&"rustle", -6.0)
	player.enter_hiding(self)

func hide_position() -> Vector3:
	return global_transform * hide_offset

func exit_position() -> Vector3:
	return global_transform * exit_offset
