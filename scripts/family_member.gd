class_name FamilyMember
extends PathWalker
## One of the people who live here. The father searches with a flashlight and
## bolts when the beam finds the player; the mother waits by the front door.

enum Role { FATHER, MOTHER }

signal spotted_player(member: FamilyMember)
signal left_house(member: FamilyMember)

const SEARCH_ROUTE: Array[StringName] = [
	&"hall", &"d_hk", &"kitchen", &"d_lk", &"living", &"closet_front",
	&"living", &"d_bl", &"bedroom", &"d_hb",
]

@export var role: Role = Role.FATHER
@export var beam_half_angle_degrees: float = 20.0
@export var beam_range: float = 9.0
@export var walk_speed: float = 1.1
@export var flee_speed: float = 3.2

var present: bool = false
var fled: bool = false

var _house: Node3D
var _beam: SpotLight3D
var _glow: OmniLight3D
var _route_index: int = 0
var _pause_left: float = 0.0
var _alert: float = 0.0
var _panic: bool = false

func setup(house: Node3D) -> void:
	_house = house
	_graph = house.graph
	_step_volume = -2.0
	_step_pitch = Vector2(0.95, 1.1)
	var colour := Color(0.2, 0.22, 0.26) if role == Role.FATHER else Color(0.35, 0.22, 0.24)
	add_child(BodyBuilder.person(colour, 1.85 if role == Role.FATHER else 1.68))
	if role == Role.FATHER:
		_beam = SpotLight3D.new()
		_beam.position = Vector3(0.3, 1.25, -0.3)
		_beam.spot_range = beam_range + 3.0
		_beam.spot_angle = beam_half_angle_degrees + 6.0
		_beam.light_energy = 3.0
		_beam.shadow_enabled = true
		add_child(_beam)
	else:
		_glow = OmniLight3D.new()
		_glow.position = Vector3(0.2, 1.3, -0.3)
		_glow.light_color = Color(0.7, 0.85, 1.0)
		_glow.omni_range = 3.0
		_glow.light_energy = 0.8
		add_child(_glow)
	visible = false
	set_physics_process(false)

func enter(spawn_node: StringName) -> void:
	present = true
	fled = false
	_panic = false
	_alert = 0.0
	visible = true
	global_position = _graph.position_of(spawn_node)
	set_physics_process(true)
	if role == Role.FATHER:
		_route_index = 0
		_set_path_to(_graph.position_of(SEARCH_ROUTE[0]))

func _physics_process(delta: float) -> void:
	if not present:
		return
	var player := get_tree().get_first_node_in_group("player") as Player
	if player == null:
		return
	if _panic:
		_step_flee(delta)
		return
	_watch_for_player(player, delta)
	if role == Role.FATHER:
		_step_search(delta)

func _step_search(delta: float) -> void:
	if _pause_left > 0.0:
		_pause_left -= delta
		rotation.y += sin(Time.get_ticks_msec() * 0.0015) * delta * 0.8
		return
	if _advance(delta, walk_speed):
		_pause_left = 2.2
		_route_index = (_route_index + 1) % SEARCH_ROUTE.size()
		_set_path_to(_graph.position_of(SEARCH_ROUTE[_route_index]))

func _watch_for_player(player: Player, delta: float) -> void:
	var seen := false
	if player.hiding_in == null:
		var to_player := player.global_position + Vector3(0, 1.0, 0) - (global_position + Vector3(0, 1.4, 0))
		var distance := to_player.length()
		if distance < 1.6:
			seen = true
		elif role == Role.FATHER and distance < beam_range:
			var forward := -global_transform.basis.z
			if rad_to_deg(forward.angle_to(to_player.normalized())) < beam_half_angle_degrees and _line_clear(player):
				seen = true
		elif role == Role.MOTHER and distance < 4.0 and _line_clear(player):
			seen = true
	_alert = clampf(_alert + (delta * 1.2 if seen else -delta * 0.6), 0.0, 1.0)
	if _alert >= 1.0:
		_start_panic()
	var fear := _alert
	GameState.tension = maxf(GameState.tension * 0.9, fear)

func _line_clear(player: Player) -> bool:
	var from := global_position + Vector3(0, 1.4, 0)
	var query := PhysicsRayQueryParameters3D.create(from, player.eye_position())
	query.exclude = [player.get_rid()]
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()

func _start_panic() -> void:
	_panic = true
	if _beam != null:
		_beam.light_energy = 1.2
	_set_path_to(_graph.position_of(&"hall_front"))
	spotted_player.emit(self)

func _step_flee(delta: float) -> void:
	if _advance(delta, flee_speed):
		_leave()

func _leave() -> void:
	present = false
	fled = true
	visible = false
	set_physics_process(false)
	Sfx.play_at(&"clunk", global_position, 2.0)
	left_house.emit(self)
