class_name TouchControls
extends Control
## On-screen controls for tablets: a floating joystick on the left, drag
## anywhere on the right to look, and buttons for the rest. Appears on the
## first touch and hides again as soon as a key is pressed.

signal pause_requested

const JOY_RADIUS := 95.0
const JOY_DEADZONE := 0.18
const LOOK_SCALE := 2.0
const TAP_SECONDS := 0.12
const BUTTONS := {
	&"use": {"label": "Use", "radius": 56.0},
	&"run": {"label": "Run", "radius": 40.0},
	&"crouch": {"label": "Crouch", "radius": 40.0},
	&"light": {"label": "Light", "radius": 40.0},
	&"back": {"label": "Back away", "radius": 48.0},
	&"pause": {"label": "II", "radius": 28.0},
}

var _enabled: bool = true
var _active: bool = false
var _show_back_away: bool = false
var _centres: Dictionary = {}
var _joy_index: int = -1
var _joy_origin := Vector2.ZERO
var _joy_vector := Vector2.ZERO
var _look_index: int = -1
var _held: Dictionary = {}
var _crouch_on: bool = false

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS
	resized.connect(_layout)
	_layout()
	_set_active(DisplayServer.is_touchscreen_available())

func set_enabled(value: bool) -> void:
	_enabled = value
	if not value:
		_release_everything()
	queue_redraw()

func set_back_away_visible(value: bool) -> void:
	_show_back_away = value
	queue_redraw()

func _layout() -> void:
	_centres[&"use"] = size - Vector2(130, 150)
	_centres[&"run"] = size - Vector2(290, 90)
	_centres[&"light"] = size - Vector2(290, 215)
	_centres[&"crouch"] = size - Vector2(130, 295)
	_centres[&"back"] = size - Vector2(290, 340)
	_centres[&"pause"] = Vector2(size.x - 56, 56)
	queue_redraw()

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		_set_active(true)
		if not _enabled or get_tree().paused:
			return
		if event.pressed:
			_press(event.index, event.position)
		else:
			_lift(event.index)
	elif event is InputEventScreenDrag:
		if _enabled and not get_tree().paused:
			_drag(event.index, event.position, event.relative)
	elif event is InputEventKey and event.pressed:
		_set_active(false)

func _set_active(value: bool) -> void:
	if value == _active:
		return
	_active = value
	GameState.touch_mode = value
	if value:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if not value:
		_release_everything()
	queue_redraw()

func _press(index: int, position: Vector2) -> void:
	var button := _button_at(position)
	if button != &"":
		_held[index] = button
		_button_down(button)
	elif position.x < size.x * 0.45 and position.y > size.y * 0.25 and _joy_index == -1:
		_joy_index = index
		_joy_origin = position
		_joy_vector = Vector2.ZERO
	elif _look_index == -1:
		_look_index = index
	queue_redraw()

func _lift(index: int) -> void:
	if _held.has(index):
		_button_up(_held[index])
		_held.erase(index)
	if index == _joy_index:
		_joy_index = -1
		_joy_vector = Vector2.ZERO
		_apply_movement()
	if index == _look_index:
		_look_index = -1
	queue_redraw()

func _drag(index: int, position: Vector2, relative: Vector2) -> void:
	if index == _joy_index:
		_joy_vector = ((position - _joy_origin) / JOY_RADIUS).limit_length(1.0)
		_apply_movement()
		queue_redraw()
	elif index == _look_index:
		var player := _player()
		if player != null:
			player.look_by(relative * LOOK_SCALE)

func _button_at(position: Vector2) -> StringName:
	for id in BUTTONS:
		if id == &"back" and not _show_back_away:
			continue
		if position.distance_to(_centres[id]) <= float(BUTTONS[id]["radius"]) + 10.0:
			return id
	return &""

func _button_down(id: StringName) -> void:
	var player := _player()
	match id:
		&"use":
			if player != null:
				player.try_interact()
			_tap_action("interact")
		&"light":
			if player != null:
				player.toggle_flashlight()
		&"run":
			Input.action_press("sprint")
		&"crouch":
			_crouch_on = not _crouch_on
			if _crouch_on:
				Input.action_press("crouch")
			else:
				Input.action_release("crouch")
		&"back":
			_tap_action("back_away")
		&"pause":
			pause_requested.emit()

func _button_up(id: StringName) -> void:
	if id == &"run":
		Input.action_release("sprint")

func _tap_action(action: String) -> void:
	Input.action_press(action)
	get_tree().create_timer(TAP_SECONDS, true).timeout.connect(func() -> void: Input.action_release(action))

func _apply_movement() -> void:
	var v := _joy_vector if _joy_vector.length() > JOY_DEADZONE else Vector2.ZERO
	_set_axis("move_forward", maxf(-v.y, 0.0))
	_set_axis("move_back", maxf(v.y, 0.0))
	_set_axis("move_left", maxf(-v.x, 0.0))
	_set_axis("move_right", maxf(v.x, 0.0))

func _set_axis(action: String, strength: float) -> void:
	if strength > 0.0:
		Input.action_press(action, strength)
	else:
		Input.action_release(action)

func _release_everything() -> void:
	_joy_index = -1
	_look_index = -1
	_joy_vector = Vector2.ZERO
	_held.clear()
	_apply_movement()
	Input.action_release("sprint")
	if _crouch_on:
		_crouch_on = false
		Input.action_release("crouch")

func _player() -> Player:
	return get_tree().get_first_node_in_group("player") as Player

func _draw() -> void:
	if not _active or not _enabled:
		return
	var base := _joy_origin if _joy_index != -1 else Vector2(190, size.y - 190)
	var ring := Color(UiTheme.BONE, 0.28 if _joy_index == -1 else 0.5)
	draw_arc(base, JOY_RADIUS, 0.0, TAU, 48, ring, 3.0)
	draw_circle(base + _joy_vector * JOY_RADIUS, 34.0, Color(UiTheme.BONE, 0.35))
	for id in BUTTONS:
		if id == &"back" and not _show_back_away:
			continue
		var centre: Vector2 = _centres[id]
		var radius: float = BUTTONS[id]["radius"]
		var pressed: bool = _held.values().has(id) or (id == &"crouch" and _crouch_on)
		draw_circle(centre, radius, Color(UiTheme.INK, 0.55))
		draw_arc(centre, radius, 0.0, TAU, 40, Color(UiTheme.AMBER, 0.95 if pressed else 0.55), 3.0)
		var label: String = BUTTONS[id]["label"]
		var font := UiTheme.FONT_UI_BOLD
		var text_size := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 17)
		draw_string(font, centre + Vector2(-text_size.x / 2.0, 6.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color(UiTheme.BONE, 0.95 if pressed else 0.8))
