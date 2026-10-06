class_name ShadowFigure
extends PathWalker
## The thing the player hides from. It patrols a loop through the house,
## stops at every hiding place to check it, hears running, and sees a player
## who stands in its line of sight. Hiding in a spot only works if it has not
## seen you go in.

enum State { DORMANT, PATROL, INVESTIGATE, CHASE, SEARCH, DRAG, STARE }

const PATROL_ROUTE: Array[StringName] = [
	&"kitchen", &"pantry_front", &"kitchen", &"d_lk", &"living", &"closet_front",
	&"living", &"d_bl", &"bedroom", &"d_hb", &"hall", &"hall_front", &"hall", &"d_hk",
]
const INSPECTED: Dictionary = {
	&"pantry_front": &"pantry", &"closet_front": &"closet", &"bedroom": &"bed",
}

@export var patrol_speed: float = 1.2
@export var investigate_speed: float = 1.9
@export var chase_speed: float = 3.3
@export var sight_range: float = 7.0
@export var sight_range_lit: float = 11.0
@export var sight_half_angle_degrees: float = 55.0
@export var grace_seconds: float = 6.0
@export var catch_distance: float = 1.15
@export var inspect_seconds: float = 4.0
## How long it stands and watches before it commits to the chase.
@export var stare_seconds: float = 3.0

var state: State = State.DORMANT
var _house: Node3D
var _route_index: int = 0
var _route_dir: int = 1
var _pause_left: float = 0.0
var _alert: float = 0.0
var _unseen_for: float = 0.0
var _last_known := Vector3.ZERO
var _caught: bool = false
var _model: Node3D
var _drag_spot: HidingSpot
var _warned: bool = false
var _stare_left: float = 0.0
var _rasp := AudioStreamPlayer3D.new()
var _print_side: float = 1.0

func setup(house: Node3D) -> void:
	_house = house
	_graph = house.graph
	_step_volume = 3.0
	_model = BodyBuilder.creature()
	add_child(_model)
	var animator := CreatureAnimator.new()
	add_child(animator)
	animator.setup(_model, self)
	_rasp.stream = Sfx.loop_stream(&"breathing")
	_rasp.pitch_scale = 0.55
	_rasp.unit_size = 3.0
	_rasp.max_distance = 12.0
	_rasp.volume_db = -3.0
	add_child(_rasp)
	deactivate()

## Starts patrolling from the route point farthest from `away_from`, standing
## still for a few seconds so the player is never ambushed on arrival.
func activate(away_from: Vector3 = Vector3.ZERO) -> void:
	_caught = false
	_alert = 0.0
	_unseen_for = 0.0
	_route_dir = 1 if randf() < 0.5 else -1
	_route_index = _farthest_route_index(away_from)
	global_position = _graph.position_of(PATROL_ROUTE[_route_index])
	visible = true
	state = State.PATROL
	_pause_left = grace_seconds
	_route_index = _next_route_index()
	_go_to_route_point()
	set_physics_process(true)
	_rasp.play()

func _farthest_route_index(point: Vector3) -> int:
	var best := 0
	var best_distance := -1.0
	for i in PATROL_ROUTE.size():
		var distance := _graph.position_of(PATROL_ROUTE[i]).distance_to(point)
		if distance > best_distance:
			best_distance = distance
			best = i
	return best

func _next_route_index() -> int:
	var next := _route_index + _route_dir
	if next >= PATROL_ROUTE.size() or next < 0:
		_route_dir = 1 if randf() < 0.5 else -1
		next = posmod(next, PATROL_ROUTE.size())
	return next

func deactivate() -> void:
	_rasp.stop()
	visible = false
	state = State.DORMANT
	set_physics_process(false)
	GameState.tension = 0.0
	GameState.pursuit = 0.0

func current_state_name() -> String:
	return State.keys()[state]

func _physics_process(delta: float) -> void:
	var player := get_tree().get_first_node_in_group("player") as Player
	if player == null:
		return
	_update_senses(player, delta)
	match state:
		State.PATROL:
			_step_patrol(delta)
		State.INVESTIGATE:
			_step_investigate(delta)
		State.CHASE:
			_step_chase(player, delta)
		State.SEARCH:
			_step_search(delta)
		State.DRAG:
			_step_drag(player, delta)
		State.STARE:
			_step_stare(player, delta)
	_update_tension(player)

func _update_senses(player: Player, delta: float) -> void:
	if state == State.DRAG:
		return
	if player.hiding_in != null:
		if state == State.CHASE or state == State.STARE:
			if _unseen_for < 0.6:
				_drag_spot = player.hiding_in
				state = State.DRAG
				_set_path_to(Vector3(_drag_spot.global_position.x, 0.0, _drag_spot.global_position.z))
			else:
				state = State.SEARCH
				_set_path_to(_last_known)
				_pause_left = 0.0
		_alert = maxf(_alert - delta * 0.5, 0.0)
		return
	var seen := _can_see(player)
	if seen:
		_unseen_for = 0.0
		_last_known = player.global_position
		var closeness := 1.0 - clampf(global_position.distance_to(player.global_position) / sight_range, 0.0, 1.0)
		_alert = minf(_alert + delta * (0.45 + closeness * 1.8), 1.0)
		if _alert >= 0.45 and not _warned:
			_warned = true
			Sfx.play_at(&"creak", global_position, 2.0)
		if _alert >= 1.0 and state != State.CHASE and state != State.STARE:
			_begin_stare()
	else:
		_unseen_for += delta
		_alert = maxf(_alert - delta * 0.35, 0.0)
		if _alert < 0.1:
			_warned = false
		if state == State.CHASE and _unseen_for > 3.5:
			state = State.SEARCH
			_set_path_to(_last_known)
			_pause_left = 0.0
		elif (state == State.PATROL or state == State.SEARCH) and _graph.path_length(global_position, player.global_position) < player.noise_radius():
			_last_known = player.global_position + Vector3(randf_range(-1.0, 1.0), 0.0, randf_range(-1.0, 1.0))
			state = State.INVESTIGATE
			_pause_left = 0.9
			Sfx.play_at(&"creak", global_position, 0.0)
			_face(player.global_position)
			_set_path_to(_last_known)
	var gap := global_position.distance_to(player.global_position)
	if state == State.STARE and gap < 2.2:
		_begin_chase()
	elif gap < catch_distance and state == State.CHASE:
		_catch(player)

## It stops where it is, turns to face you, and holds still. The breathing
## stops too, so the sudden quiet is the warning.
func _begin_stare() -> void:
	state = State.STARE
	_stare_left = stare_seconds
	_path = PackedVector3Array()
	_path_index = 0
	_rasp.stop()
	Sfx.play_at(&"growl", global_position, 3.0)
	GameState.raise_event(&"figure_stare")

func _step_stare(player: Player, delta: float) -> void:
	_face(player.global_position, delta * 5.0)
	_stare_left -= delta
	if _unseen_for > 1.0:
		state = State.SEARCH
		_set_path_to(_last_known)
		_pause_left = 0.0
		_rasp.play()
	elif _stare_left <= 0.0:
		_begin_chase()

func _begin_chase() -> void:
	state = State.CHASE
	_rasp.play()
	GameState.raise_event(&"figure_chase")
	Sfx.play_at(&"screech", global_position, 5.0)
	Sfx.play_at(&"thump", global_position, 4.0)

func _can_see(player: Player) -> bool:
	var eye := global_position + Vector3(0, 1.7, 0)
	var target := player.eye_position()
	var to_target := target - eye
	var distance := to_target.length()
	var limit := sight_range_lit if player.flashlight_on() else sight_range
	if player.is_crouching():
		limit *= 0.6
	if distance > limit:
		return false
	var forward := -global_transform.basis.z
	forward.y = 0.0
	var flat := to_target
	flat.y = 0.0
	if distance > 1.6 and rad_to_deg(forward.normalized().angle_to(flat.normalized())) > sight_half_angle_degrees:
		return false
	var query := PhysicsRayQueryParameters3D.create(eye, target)
	query.exclude = [player.get_rid()]
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()

func _step_patrol(delta: float) -> void:
	if _pause_left > 0.0:
		_pause_left -= delta
		return
	if _advance(delta, patrol_speed):
		var node_id := PATROL_ROUTE[_route_index]
		if INSPECTED.has(node_id):
			var spot: HidingSpot = _house.spots[INSPECTED[node_id]]
			_face(spot.global_position)
			_pause_left = inspect_seconds
			GameState.raise_event(&"figure_inspects", String(INSPECTED[node_id]))
			Sfx.play_at(&"creak", spot.global_position, 0.0)
		else:
			_pause_left = 0.8
		_route_index = _next_route_index()
		_go_to_route_point()

func _step_investigate(delta: float) -> void:
	if _pause_left > 0.0:
		_pause_left -= delta
		return
	if _advance(delta, investigate_speed):
		state = State.SEARCH
		_pause_left = 2.5

func _step_chase(player: Player, delta: float) -> void:
	_set_path_to(_last_known if _unseen_for > 0.3 else player.global_position)
	_advance(delta, chase_speed)

func _step_search(delta: float) -> void:
	if _pause_left > 0.0:
		_pause_left -= delta
		if _pause_left <= 0.0:
			_route_index = _nearest_route_index()
			state = State.PATROL
			_go_to_route_point()
		return
	if _advance(delta, investigate_speed):
		_pause_left = 3.0

func _step_drag(player: Player, delta: float) -> void:
	if _advance(delta, chase_speed) and not _caught:
		_catch(player)

func _catch(player: Player) -> void:
	if _caught:
		return
	_caught = true
	player.controls_enabled = false
	GameState.caught_count += 1
	GameState.raise_event(&"caught")

func _nearest_route_index() -> int:
	var best := 0
	var best_distance := INF
	for i in PATROL_ROUTE.size():
		var distance := _graph.position_of(PATROL_ROUTE[i]).distance_to(global_position)
		if distance < best_distance:
			best_distance = distance
			best = i
	return best

func _go_to_route_point() -> void:
	_set_path_to(_graph.position_of(PATROL_ROUTE[_route_index]))

func _update_tension(player: Player) -> void:
	var distance := global_position.distance_to(player.global_position)
	var proximity := clampf(1.0 - distance / 11.0, 0.0, 1.0)
	var hunting := state == State.CHASE or state == State.DRAG
	GameState.pursuit = 1.0 if hunting else (-0.3 if state == State.STARE else 0.0)
	var chase_boost := 0.5 if hunting or state == State.STARE else 0.0
	var inspecting := 0.35 if player.hiding_in != null and _pause_left > 0.0 and distance < 3.5 else 0.0
	GameState.tension = clampf(maxf(proximity * 0.8, _alert) + chase_boost + inspecting, 0.0, 1.0)

## Wet footprints trail behind it and dry out after a while.
func _on_step() -> void:
	var print_mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.14, 0.012, 0.32)
	print_mesh.mesh = box
	print_mesh.material_override = Surfaces.plain(Color(0.03, 0.05, 0.07), 0.15)
	_house.add_child(print_mesh)
	var sideways := global_transform.basis.x * 0.12 * _print_side
	_print_side = -_print_side
	print_mesh.global_position = Vector3(global_position.x + sideways.x, 0.007, global_position.z + sideways.z)
	print_mesh.rotation.y = rotation.y
	var tween := print_mesh.create_tween()
	tween.tween_interval(18.0)
	tween.tween_callback(print_mesh.queue_free)
