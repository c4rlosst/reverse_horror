class_name Player
extends CharacterBody3D
## First-person controller. Walks, crouches, hides, and changes body after the
## reversal: lower camera, slower pace, no flashlight, and heavier steps.

const MOUSE_SENSITIVITY := 0.0022
const GRAVITY := 12.0

@export var walk_speed: float = 2.4
@export var sprint_speed: float = 4.0
@export var crouch_speed: float = 1.2
@export var monster_speed: float = 1.7
@export var stand_height: float = 1.6
@export var crouch_height: float = 1.0
@export var monster_height: float = 1.3
@export var stride_length: float = 1.6

var controls_enabled: bool = true
var hiding_in: HidingSpot = null

var _yaw: float = 0.0
var _pitch: float = 0.0
var _head_y: float = 1.6
var _bob_time: float = 0.0
var _last_prompt: String = ""
var _prompt_override: String = ""
var _stride_progress: float = 0.0
var _noise_radius: float = 0.0
var _look_tween: Tween

@onready var _collision: CollisionShape3D = $Collision
@onready var _head: Node3D = $Head
@onready var _camera: Camera3D = $Head/Camera3D
@onready var _reach: RayCast3D = $Head/Camera3D/Reach
@onready var _flashlight: SpotLight3D = $Head/Camera3D/Flashlight

func _ready() -> void:
	add_to_group("player")
	_yaw = rotation.y
	_head_y = stand_height
	_flashlight.shadow_enabled = true
	GameState.perspective_changed.connect(_on_perspective_changed)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _unhandled_input(event: InputEvent) -> void:
	if GameState.touch_mode:
		return
	if event is InputEventMouseButton and event.pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		look_by(event.relative)
	elif event.is_action_pressed("interact"):
		try_interact()
	elif event.is_action_pressed("flashlight"):
		toggle_flashlight()

func _physics_process(delta: float) -> void:
	_head_y = lerpf(_head_y, _target_head_height(), minf(delta * 8.0, 1.0))
	_flicker_flashlight()
	if hiding_in != null:
		velocity = Vector3.ZERO
		_noise_radius = 0.0
		_head.position.y = _head_y
		_set_prompt(_prompt_override if _prompt_override != "" else "Leave")
		return
	_move(delta)
	_update_prompt()

func eye_position() -> Vector3:
	return _camera.global_position

func flashlight_on() -> bool:
	return _flashlight.visible

func is_crouching() -> bool:
	return controls_enabled and Input.is_action_pressed("crouch") and hiding_in == null

func noise_radius() -> float:
	return _noise_radius

## Replaces the prompt text while hiding (used for the ending choice).
func set_prompt_override(text: String) -> void:
	_prompt_override = text
	if hiding_in == null:
		_set_prompt(text)

func enter_hiding(spot: HidingSpot) -> void:
	hiding_in = spot
	global_position = spot.hide_position()
	velocity = Vector3.ZERO
	_collision.set_deferred("disabled", true)
	_yaw = deg_to_rad(spot.facing_degrees)
	_pitch = 0.0
	rotation.y = _yaw
	_head.rotation.x = _pitch
	_flashlight.visible = false

func exit_hiding() -> void:
	if hiding_in == null:
		return
	global_position = hiding_in.exit_position()
	hiding_in = null
	_collision.set_deferred("disabled", false)
	Sfx.play(&"rustle", -8.0)

## Smoothly turns the view toward a world point. Used for scripted beats.
func look_toward(point: Vector3, seconds: float) -> void:
	var from := _camera.global_position
	var flat := Vector2(point.x - from.x, point.z - from.z)
	var target_yaw := atan2(-flat.x, -flat.y)
	var target_pitch := atan2(point.y - from.y, flat.length())
	if _look_tween != null:
		_look_tween.kill()
	_look_tween = create_tween().set_parallel(true)
	_look_tween.tween_method(_set_yaw, _yaw, _yaw + angle_difference(_yaw, target_yaw), seconds).set_trans(Tween.TRANS_SINE)
	_look_tween.tween_method(_set_pitch, _pitch, clampf(target_pitch, -1.4, 1.4), seconds).set_trans(Tween.TRANS_SINE)

## Eases the camera back to the horizon after a scripted look.
func level_view(seconds: float) -> void:
	if _look_tween != null:
		_look_tween.kill()
	_look_tween = create_tween()
	_look_tween.tween_method(_set_pitch, _pitch, 0.0, seconds).set_trans(Tween.TRANS_SINE)

func _set_yaw(value: float) -> void:
	_yaw = value
	rotation.y = _yaw

func _set_pitch(value: float) -> void:
	_pitch = value
	_head.rotation.x = _pitch

func look_by(relative: Vector2) -> void:
	if not controls_enabled:
		return
	var sensitivity := MOUSE_SENSITIVITY * GameState.mouse_sensitivity
	_yaw -= relative.x * sensitivity
	_pitch -= relative.y * sensitivity
	if hiding_in != null:
		var centre := deg_to_rad(hiding_in.facing_degrees)
		var spread := deg_to_rad(hiding_in.peek_range_degrees)
		_yaw = clampf(_yaw, centre - spread, centre + spread)
		_pitch = clampf(_pitch, -0.35, 0.35)
	else:
		_pitch = clampf(_pitch, -1.4, 1.4)
	rotation.y = _yaw
	_head.rotation.x = _pitch

func _move(delta: float) -> void:
	var input := Vector2.ZERO
	if controls_enabled:
		input = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction := (transform.basis * Vector3(input.x, 0.0, input.y)).normalized()
	var speed := _current_speed()
	velocity.x = direction.x * speed
	velocity.z = direction.z * speed
	velocity.y = 0.0 if is_on_floor() else velocity.y - GRAVITY * delta
	move_and_slide()
	var moving := input.length() > 0.1
	_noise_radius = 0.0
	if moving and is_on_floor():
		_noise_radius = _noise_for_speed(speed)
		_stride_progress += Vector2(velocity.x, velocity.z).length() * delta
		if _stride_progress >= stride_length:
			_stride_progress = 0.0
			_play_footstep()
	_bob_time += delta * speed * (2.2 if moving else 0.0)
	_head.position.y = _head_y + (sin(_bob_time) * 0.02 if moving else 0.0)

func _noise_for_speed(speed: float) -> float:
	if GameState.perspective == GameState.Perspective.MONSTER:
		return 2.0
	if speed >= sprint_speed:
		return 9.0
	if speed <= crouch_speed:
		return 1.5
	return 4.0

func _play_footstep() -> void:
	var monster := GameState.perspective == GameState.Perspective.MONSTER
	var volume := -8.0
	if monster or Input.is_action_pressed("crouch"):
		volume = -14.0
	elif Input.is_action_pressed("sprint"):
		volume = -2.0
	Sfx.play(&"footstep", volume, randf_range(0.9, 1.05) * (0.75 if monster else 1.0))

func _current_speed() -> float:
	if GameState.perspective == GameState.Perspective.MONSTER:
		return monster_speed
	if Input.is_action_pressed("crouch"):
		return crouch_speed
	if Input.is_action_pressed("sprint"):
		return sprint_speed
	return walk_speed

func _target_head_height() -> float:
	if hiding_in != null:
		return hiding_in.peek_height
	if GameState.perspective == GameState.Perspective.MONSTER:
		return monster_height
	if controls_enabled and Input.is_action_pressed("crouch"):
		return crouch_height
	return stand_height

func _flicker_flashlight() -> void:
	if not _flashlight.visible:
		return
	var stutter := GameState.tension > 0.5 and randf() < (GameState.tension - 0.4) * 0.35
	_flashlight.light_energy = 0.4 if stutter else 2.0

func try_interact() -> void:
	if not controls_enabled:
		return
	if hiding_in != null:
		if _prompt_override == "":
			exit_hiding()
		return
	var target := _aimed_interactable()
	if target != null:
		target.interact(self)

func _aimed_interactable() -> Interactable:
	if not _reach.is_colliding():
		return null
	return _reach.get_collider() as Interactable

func _update_prompt() -> void:
	if _prompt_override != "":
		_set_prompt(_prompt_override)
		return
	var target := _aimed_interactable() if controls_enabled else null
	_set_prompt(target.get_prompt() if target != null else "")

func _set_prompt(text: String) -> void:
	var shown := text
	if text != "" and not text.begins_with("["):
		shown = "[E] %s" % text
	if shown == _last_prompt:
		return
	_last_prompt = shown
	GameState.prompt_changed.emit(shown)

func toggle_flashlight() -> void:
	if hiding_in != null or GameState.perspective == GameState.Perspective.MONSTER:
		return
	_flashlight.visible = not _flashlight.visible
	Sfx.play(&"click", -4.0)

func _on_perspective_changed(perspective: GameState.Perspective) -> void:
	if perspective == GameState.Perspective.MONSTER:
		_flashlight.visible = false
