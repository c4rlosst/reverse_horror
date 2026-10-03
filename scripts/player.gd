class_name Player
extends CharacterBody3D
## First-person controller. Walks, crouches, hides, and changes body after the
## reversal: lower camera, slower pace, no flashlight.

const MOUSE_SENSITIVITY := 0.0022
const GRAVITY := 12.0

@export var walk_speed: float = 2.4
@export var sprint_speed: float = 4.0
@export var crouch_speed: float = 1.2
@export var monster_speed: float = 1.6
@export var stand_height: float = 1.6
@export var crouch_height: float = 1.0
@export var monster_height: float = 1.3

var controls_enabled: bool = true
var hiding_in: HidingSpot = null

var _yaw: float = 0.0
var _pitch: float = 0.0
var _head_y: float = 1.6
var _bob_time: float = 0.0
var _last_prompt: String = ""

@onready var _collision: CollisionShape3D = $Collision
@onready var _head: Node3D = $Head
@onready var _reach: RayCast3D = $Head/Camera3D/Reach
@onready var _flashlight: SpotLight3D = $Head/Camera3D/Flashlight

func _ready() -> void:
	add_to_group("player")
	_yaw = rotation.y
	_head_y = stand_height
	GameState.perspective_changed.connect(_on_perspective_changed)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_look(event.relative)
	elif event.is_action_pressed("interact"):
		_interact()
	elif event.is_action_pressed("flashlight"):
		_toggle_flashlight()

func _physics_process(delta: float) -> void:
	_head_y = lerpf(_head_y, _target_head_height(), minf(delta * 8.0, 1.0))
	if hiding_in != null:
		velocity = Vector3.ZERO
		_head.position.y = _head_y
		_set_prompt("Leave")
		return
	_move(delta)
	_update_prompt()

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

func _look(relative: Vector2) -> void:
	if not controls_enabled:
		return
	_yaw -= relative.x * MOUSE_SENSITIVITY
	_pitch -= relative.y * MOUSE_SENSITIVITY
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
	_bob_time += delta * speed * (2.2 if moving else 0.0)
	_head.position.y = _head_y + (sin(_bob_time) * 0.02 if moving else 0.0)

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

func _interact() -> void:
	if not controls_enabled:
		return
	if hiding_in != null:
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
	var target := _aimed_interactable() if controls_enabled else null
	_set_prompt(target.get_prompt() if target != null else "")

func _set_prompt(text: String) -> void:
	var shown := "[E] %s" % text if text != "" else ""
	if shown == _last_prompt:
		return
	_last_prompt = shown
	GameState.prompt_changed.emit(shown)

func _toggle_flashlight() -> void:
	if hiding_in != null or GameState.perspective == GameState.Perspective.MONSTER:
		return
	_flashlight.visible = not _flashlight.visible

func _on_perspective_changed(perspective: GameState.Perspective) -> void:
	if perspective == GameState.Perspective.MONSTER:
		_flashlight.visible = false
