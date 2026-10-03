class_name PathWalker
extends Node3D
## Shared movement for anything that walks the house graph: the figure and
## the family. Moves along waypoint paths and plays footsteps.

var _graph: HouseGraph
var _path := PackedVector3Array()
var _path_index: int = 0
var _stride: float = 0.0
var _step_volume: float = 3.0
var _step_pitch: Vector2 = Vector2(0.7, 0.85)
var _step_length: float = 1.0

func _set_path_to(target: Vector3) -> void:
	_path = _graph.path(global_position, target)
	_path_index = 0

## Moves along the current path. Returns true on arrival.
func _advance(delta: float, speed: float) -> bool:
	if _path_index >= _path.size():
		return true
	var target := _path[_path_index]
	var offset := Vector3(target.x - global_position.x, 0.0, target.z - global_position.z)
	if offset.length() < 0.12:
		_path_index += 1
		return _path_index >= _path.size()
	var step := offset.normalized() * speed * delta
	global_position += step
	_face(global_position + offset, delta * 6.0)
	_stride += step.length()
	if _stride >= _step_length:
		_stride = 0.0
		Sfx.play_at(&"footstep", global_position, _step_volume, randf_range(_step_pitch.x, _step_pitch.y))
	return false

func _face(point: Vector3, weight: float = 1.0) -> void:
	var flat := Vector3(point.x - global_position.x, 0.0, point.z - global_position.z)
	if flat.length() < 0.01:
		return
	var target_yaw := atan2(-flat.x, -flat.z)
	rotation.y = lerp_angle(rotation.y, target_yaw, clampf(weight, 0.0, 1.0))
