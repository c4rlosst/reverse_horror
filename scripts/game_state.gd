extends Node
## Global story state: whose eyes the player is looking through, and a log of
## what they did so the second half of the game can replay it.

enum Perspective { VICTIM, MONSTER }

signal perspective_changed(perspective: Perspective)
signal prompt_changed(text: String)
signal subtitle(text: String, seconds: float)
signal event_raised(id: StringName)
signal ending_reached(text: String)

var perspective: Perspective = Perspective.VICTIM
var action_log: Array[Dictionary] = []

func set_perspective(value: Perspective) -> void:
	if value == perspective:
		return
	perspective = value
	perspective_changed.emit(perspective)

func log_action(id: StringName, detail: String = "") -> void:
	action_log.append({"id": id, "detail": detail, "time": Time.get_ticks_msec()})

func raise_event(id: StringName, detail: String = "") -> void:
	log_action(id, detail)
	event_raised.emit(id)

func has_done(id: StringName) -> bool:
	for entry in action_log:
		if entry["id"] == id:
			return true
	return false

func reset() -> void:
	perspective = Perspective.VICTIM
	action_log.clear()
