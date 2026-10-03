class_name ShadowFigure
extends Node3D
## The thing the player hides from. Walks a fixed loop of waypoints and stops
## at each one to "search". Reaching a visible player ends the run.

@export var speed: float = 1.3
@export var pause_seconds: float = 2.5
@export var catch_distance: float = 1.2

var route: Array[Vector3] = []

var _index: int = 0
var _pause_left: float = 0.0
var _caught: bool = false

func _ready() -> void:
	deactivate()

func activate() -> void:
	if route.is_empty():
		return
	global_position = route[0]
	_index = 1 % route.size()
	_pause_left = 0.0
	visible = true
	set_physics_process(true)

func deactivate() -> void:
	visible = false
	set_physics_process(false)

func _physics_process(delta: float) -> void:
	if _pause_left > 0.0:
		_pause_left -= delta
		return
	var target := route[_index]
	var offset := Vector3(target.x - global_position.x, 0.0, target.z - global_position.z)
	if offset.length() < 0.1:
		_index = (_index + 1) % route.size()
		_pause_left = pause_seconds
		return
	global_position += offset.normalized() * speed * delta
	look_at(global_position + offset, Vector3.UP)
	_check_for_player()

func _check_for_player() -> void:
	if _caught:
		return
	var player := get_tree().get_first_node_in_group("player") as Player
	if player == null or player.hiding_in != null:
		return
	if global_position.distance_to(player.global_position) < catch_distance:
		_caught = true
		player.controls_enabled = false
		GameState.raise_event(&"caught")
