class_name CreatureAnimator
extends Node
## Poses the creature at a low frame rate so it moves in stutters, the way
## something wrong would. It hangs its arms, snaps its head toward the
## player even when walking away, and opens its jaw when it hunts.

const FPS := 14.0
const CHASING := [3, 5]
const STARING := 6

var _parts: Dictionary
var _owner: Node3D
var _tick: float = 0.0
var _phase: float = 0.0
var _speed: float = 0.0
var _last_position := Vector3.ZERO
var _head_yaw: float = 0.0
var _head_roll: float = 0.0
var _head_pitch: float = 0.0
var _wander_yaw: float = 0.0
var _wander_roll: float = 0.0
var _next_wander: float = 0.0
var _next_twitch: float = 3.0
var _twitch: float = 0.0
var _lean: float = 0.0

func setup(model: Node3D, owner_node: Node3D) -> void:
	_parts = model.get_meta("parts")
	_owner = owner_node
	_last_position = owner_node.global_position
	pose(0.0, false, 0.0, false)

func _process(delta: float) -> void:
	if _owner == null or not _owner.visible:
		return
	_tick += delta
	if _tick < 1.0 / FPS:
		return
	var dt := _tick
	_tick = 0.0
	_speed = lerpf(_speed, _owner.global_position.distance_to(_last_position) / dt, 0.6)
	_last_position = _owner.global_position
	var state: int = _owner.get("state")
	var chasing: bool = CHASING.has(state)
	var staring: bool = state == STARING
	_phase += _speed * dt * 2.1
	_step_head(dt, chasing or staring)
	pose(_phase, chasing, clampf(_speed / 1.4, 0.0, 1.0), staring)

func _step_head(dt: float, chasing: bool) -> void:
	_next_wander -= dt
	if _next_wander <= 0.0:
		_wander_yaw = randf_range(-0.7, 0.7)
		_wander_roll = randf_range(-0.55, 0.55)
		_next_wander = randf_range(0.7, 2.0)
	_next_twitch -= dt
	_twitch = 0.0
	if _next_twitch <= 0.0:
		_twitch = randf_range(-0.6, 0.6)
		_next_twitch = randf_range(2.5, 6.0)
	var target_yaw := _wander_yaw
	var target_roll := _wander_roll
	var target_pitch := 0.0
	var player := _owner.get_tree().get_first_node_in_group("player") as Player
	if player != null:
		var local := _owner.to_local(player.eye_position())
		if local.length() < 14.0:
			target_yaw = clampf(atan2(-local.x, -local.z), -1.4, 1.4)
			target_roll = 0.35 if not chasing else 0.0
			target_pitch = clampf(atan2(local.y - 2.0, Vector2(local.x, local.z).length()), -0.5, 0.4)
	_head_yaw = lerpf(_head_yaw, target_yaw, 0.55)
	_head_roll = lerpf(_head_roll, target_roll, 0.4)
	_head_pitch = lerpf(_head_pitch, target_pitch, 0.4)

func pose(phase: float, chasing: bool, walk: float, staring: bool) -> void:
	var swing := sin(phase)
	var arm_swing := sin(phase + 0.6)
	_lean = lerpf(_lean, 0.42 if chasing else (0.14 if staring else 0.0), 0.3)
	_parts["hips"].position.y = 0.95 - 0.035 * absf(swing) * walk
	_parts["spine"].rotation = Vector3(deg_to_rad(-22.0) - _lean, 0.0, sin(phase * 0.5) * 0.08 * walk)
	_parts["thigh_l"].rotation.x = swing * 0.55 * walk + 0.12
	_parts["thigh_r"].rotation.x = -swing * 0.55 * walk + 0.12
	_parts["knee_l"].rotation.x = -(0.2 + maxf(0.0, -swing) * 0.9 * walk)
	_parts["knee_r"].rotation.x = -(0.2 + maxf(0.0, swing) * 0.9 * walk)
	for tag in ["l", "r"]:
		var sign := 1.0 if tag == "l" else -1.0
		if chasing:
			_parts["shoulder_" + tag].rotation.x = 1.3 + sin(phase * 1.5 + sign) * 0.12
			_parts["elbow_" + tag].rotation.x = 0.4
			_parts["hand_" + tag].rotation.x = randf_range(-0.2, 0.2)
		elif staring:
			_parts["shoulder_" + tag].rotation.x = 0.22 + sin(Time.get_ticks_msec() * 0.011 + sign) * 0.04
			_parts["elbow_" + tag].rotation.x = 0.1
			_parts["hand_" + tag].rotation.x = randf_range(-0.35, 0.35)
		else:
			_parts["shoulder_" + tag].rotation.x = -arm_swing * sign * 0.28 * walk + 0.08
			_parts["elbow_" + tag].rotation.x = -0.12
			_parts["hand_" + tag].rotation.x = sin(phase * 0.7 + sign) * 0.1
	_parts["neck"].rotation = Vector3(-0.3 - _lean * 0.5, 0.0, 0.0)
	_parts["head"].rotation = Vector3(_head_pitch, _head_yaw + _twitch, _head_roll + _twitch * 0.5)
	var jaw_open := 0.1 + (0.65 + randf() * 0.15 if chasing else (0.3 + randf() * 0.06 if staring else 0.0))
	_parts["jaw"].rotation.x = -jaw_open
