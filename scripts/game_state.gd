extends Node
## Global story state: whose eyes the player is looking through, what they
## did (so the second half can replay it), and the saved settings.

enum Perspective { VICTIM, MONSTER }

const SETTINGS_PATH := "user://settings.cfg"

signal perspective_changed(perspective: Perspective)
signal prompt_changed(text: String)
signal subtitle(text: String, seconds: float)
signal objective_changed(text: String)
signal event_raised(id: StringName)
signal ending_reached(title: String, text: String)

var perspective: Perspective = Perspective.VICTIM
var action_log: Array[Dictionary] = []
var hide_count: int = 0
var caught_count: int = 0
var started_msec: int = 0
## 0..1, how close the player is to being found (or, as the monster, found out).
var tension: float = 0.0
## Camera push: 1 while being hunted (field of view widens), slightly negative while stared at.
var pursuit: float = 0.0

## True once the player has touched the screen; false again on any key or mouse.
var touch_mode: bool = false
var mouse_sensitivity: float = 1.0
var master_volume: float = 0.8

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	load_settings()

func reset() -> void:
	perspective = Perspective.VICTIM
	action_log.clear()
	hide_count = 0
	caught_count = 0
	tension = 0.0
	pursuit = 0.0
	started_msec = Time.get_ticks_msec()

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

func say(text: String, seconds: float = 0.0) -> void:
	var length := seconds if seconds > 0.0 else clampf(1.6 + text.length() * 0.055, 2.0, 7.0)
	subtitle.emit(text, length)

func elapsed_seconds() -> int:
	return int((Time.get_ticks_msec() - started_msec) / 1000.0)

func apply_volume() -> void:
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(master_volume, 0.0001)))

func load_settings() -> void:
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) == OK:
		mouse_sensitivity = clampf(float(config.get_value("controls", "mouse_sensitivity", 1.0)), 0.2, 3.0)
		master_volume = clampf(float(config.get_value("audio", "master_volume", 0.8)), 0.0, 1.0)
	apply_volume()

func save_settings() -> void:
	var config := ConfigFile.new()
	config.set_value("controls", "mouse_sensitivity", mouse_sensitivity)
	config.set_value("audio", "master_volume", master_volume)
	config.save(SETTINGS_PATH)
