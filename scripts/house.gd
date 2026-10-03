extends Node3D
## Greybox house plus the story director. Four rooms, three hiding spots, one
## phone, and the beats that carry the player from victim to monster.

const WALL_HEIGHT := 2.6
const WALL_THICKNESS := 0.2

const ENDING_STEP_FORWARD := "They knew your footsteps before they saw you. Nobody turned the light on."
const ENDING_RETREAT := "You went back into the dark. They stopped looking eventually. You didn't."

var _wall_material := StandardMaterial3D.new()
var _floor_material := StandardMaterial3D.new()
var _prop_material := StandardMaterial3D.new()
var _prints_material := StandardMaterial3D.new()
var _family_material := StandardMaterial3D.new()
var _lights: Array[OmniLight3D] = []
var _light_energies: Array[float] = []

var _phone: Interactable
var _footprints: Interactable
var _step_forward: Interactable
var _retreat: Interactable

@onready var _player: Player = $Player
@onready var _figure: ShadowFigure = $ShadowFigure

func _ready() -> void:
	_make_materials()
	_build_shell()
	_build_props()
	_build_hiding_spots()
	_build_interactables()
	_build_lights()
	_figure.route = _patrol_route()
	_player.global_position = Vector3(5.5, 0.05, 3.6)
	GameState.event_raised.connect(_on_event)

func _make_materials() -> void:
	_wall_material.albedo_color = Color(0.46, 0.43, 0.38)
	_wall_material.roughness = 1.0
	_floor_material.albedo_color = Color(0.22, 0.17, 0.13)
	_floor_material.roughness = 1.0
	_prop_material.albedo_color = Color(0.3, 0.26, 0.22)
	_prop_material.roughness = 1.0
	_prints_material.albedo_color = Color(0.05, 0.07, 0.09)
	_prints_material.roughness = 0.2
	_family_material.albedo_color = Color(0.55, 0.5, 0.45)
	_family_material.roughness = 1.0

# --- Layout ---------------------------------------------------------------
# x runs west to east (-7..7), z runs north to south (-5..5).
# Top half: living room (west), kitchen (east). Bottom half: bedroom (west),
# hallway with the front door (east).

func _build_shell() -> void:
	_box("Floor", Vector3(0, -0.1, 0), Vector3(14, 0.2, 10), _floor_material)
	_box("Ceiling", Vector3(0, WALL_HEIGHT + 0.1, 0), Vector3(14, 0.2, 10), _wall_material)
	_wall_x(-5.0, -7.0, 7.0)
	_wall_x(5.0, -7.0, 7.0)
	_wall_z(-7.0, -5.0, 5.0)
	_wall_z(7.0, -5.0, 5.0)
	# Dividing wall with doorways at x -4..-2 (bedroom/living) and 3.5..5.5 (hall/kitchen).
	_wall_x(0.0, -7.0, -4.0)
	_wall_x(0.0, -2.0, 3.5)
	_wall_x(0.0, 5.5, 7.0)
	# Living room / kitchen, doorway at z -3..-1.
	_wall_z(2.0, -5.0, -3.0)
	_wall_z(2.0, -1.0, 0.0)
	# Bedroom / hallway, doorway at z 2..4.
	_wall_z(0.0, 0.0, 2.0)
	_wall_z(0.0, 4.0, 5.0)

func _wall_x(z: float, x0: float, x1: float) -> void:
	_box("Wall", Vector3((x0 + x1) / 2.0, WALL_HEIGHT / 2.0, z), Vector3(x1 - x0, WALL_HEIGHT, WALL_THICKNESS), _wall_material)

func _wall_z(x: float, z0: float, z1: float) -> void:
	_box("Wall", Vector3(x, WALL_HEIGHT / 2.0, (z0 + z1) / 2.0), Vector3(WALL_THICKNESS, WALL_HEIGHT, z1 - z0), _wall_material)

func _build_props() -> void:
	_box("Couch", Vector3(-3.0, 0.4, -4.0), Vector3(2.4, 0.8, 0.9), _prop_material)
	_box("Television", Vector3(-6.7, 0.7, -2.5), Vector3(0.4, 1.0, 1.4), _prop_material)
	_box("Counter", Vector3(4.5, 0.5, -4.5), Vector3(3.0, 1.0, 0.7), _prop_material)
	_box("FrontDoor", Vector3(6.0, 1.05, 4.9), Vector3(1.0, 2.1, 0.12), _prints_material)
	_box("BackDoor", Vector3(5.5, 1.05, -4.9), Vector3(1.0, 2.1, 0.12), _prints_material)

func _build_hiding_spots() -> void:
	var closet := _hiding_spot("Closet", Vector3(-6.2, 1.1, -4.2), Vector3(1.2, 2.2, 1.0))
	closet.hide_offset = Vector3(0, -1.1, 0)
	closet.exit_offset = Vector3(0, -1.1, 1.2)
	closet.facing_degrees = 180.0
	closet.peek_height = 1.5

	var bed := _hiding_spot("Bed", Vector3(-4.5, 0.3, 3.0), Vector3(2.0, 0.6, 1.6))
	bed.hide_offset = Vector3(0, -0.3, 0)
	bed.exit_offset = Vector3(1.6, -0.3, 0)
	bed.facing_degrees = -90.0
	bed.peek_height = 0.35

	var pantry := _hiding_spot("Pantry", Vector3(6.4, 1.1, -1.4), Vector3(1.0, 2.2, 1.0))
	pantry.hide_offset = Vector3(0, -1.1, 0)
	pantry.exit_offset = Vector3(-1.4, -1.1, 0)
	pantry.facing_degrees = 90.0
	pantry.peek_height = 1.5

func _build_interactables() -> void:
	_phone = _interactable("Phone", Vector3(3.0, 1.0, 4.82), Vector3(0.35, 0.25, 0.15), "Answer the phone")
	_phone.interacted.connect(_on_phone_answered)

	_footprints = _interactable("Footprints", Vector3(5.5, 0.01, -3.9), Vector3(0.6, 0.02, 1.6), "Look at the floor")
	_footprints.get_child(0).material_override = _prints_material
	_footprints.enabled = false
	_footprints.interacted.connect(_on_footprints_inspected)

	_step_forward = _interactable("StepForward", Vector3(4.6, 1.0, 3.0), Vector3(0.8, 2.0, 0.8), "", "Step forward")
	_step_forward.enabled = false
	_step_forward.interacted.connect(_end.bind(ENDING_STEP_FORWARD))

	_retreat = _interactable("Retreat", Vector3(6.4, 1.0, -4.82), Vector3(0.6, 1.4, 0.15), "", "Back into the dark")
	_retreat.enabled = false
	_retreat.interacted.connect(_end.bind(ENDING_RETREAT))

func _build_lights() -> void:
	_add_light(Vector3(-3.0, 2.0, -2.0), Color(1.0, 0.7, 0.4), 1.0, 7.0)
	_add_light(Vector3(4.5, 2.2, -2.5), Color(0.7, 0.85, 1.0), 0.8, 7.0)
	_add_light(Vector3(3.5, 2.2, 2.5), Color(1.0, 0.8, 0.55), 0.6, 7.0)
	_add_light(Vector3(-3.5, 2.2, 3.0), Color(0.6, 0.65, 1.0), 0.3, 6.0)

func _patrol_route() -> Array[Vector3]:
	return [
		Vector3(4.5, 0, -2.5), Vector3(4.5, 0, 0.0), Vector3(3.5, 0, 2.5),
		Vector3(0.0, 0, 3.0), Vector3(-3.0, 0, 3.0), Vector3(-3.0, 0, 0.0),
		Vector3(-3.0, 0, -2.5), Vector3(2.0, 0, -2.0),
	]

# --- Story beats ----------------------------------------------------------

func _on_phone_answered(_who: Player) -> void:
	_phone.enabled = false
	GameState.raise_event(&"phone_answered")
	_say("Hello?", 2.0)
	await get_tree().create_timer(2.8).timeout
	_say("[Slow breathing on the line.]", 3.0)
	await get_tree().create_timer(3.6).timeout
	_say("[The line goes dead. Something moves in the next room.]", 3.5)
	_figure.activate()

func _on_event(id: StringName) -> void:
	match id:
		&"hid":
			# The prints only show up once the player has hidden at least once.
			_footprints.enabled = true

func _on_footprints_inspected(_who: Player) -> void:
	_footprints.enabled = false
	_begin_reversal()

func _begin_reversal() -> void:
	_player.controls_enabled = false
	_say("The wet prints are the size of your shoes.", 3.0)
	await get_tree().create_timer(3.6).timeout
	GameState.set_perspective(GameState.Perspective.MONSTER)
	_figure.deactivate()
	_dim_lights()
	_say("You were never hiding from it.", 3.0)
	await get_tree().create_timer(3.6).timeout
	_player.controls_enabled = true
	_spawn_family()
	_step_forward.enabled = true
	_retreat.enabled = true

func _spawn_family() -> void:
	var spots := [Vector3(5.6, 0, 3.4), Vector3(6.3, 0, 3.8), Vector3(5.0, 0, 4.1)]
	for spot in spots:
		var body := MeshInstance3D.new()
		var capsule := CapsuleMesh.new()
		capsule.radius = 0.3
		capsule.height = 1.7
		body.mesh = capsule
		body.material_override = _family_material
		body.position = spot + Vector3(0, 0.85, 0)
		add_child(body)
	_say("Hello? Who's there? Turn the light on.", 4.0)

func _dim_lights() -> void:
	for i in _lights.size():
		create_tween().tween_property(_lights[i], "light_energy", _light_energies[i] * 0.08, 2.5)

func _end(_who: Player, text: String) -> void:
	_player.controls_enabled = false
	GameState.ending_reached.emit(text)

func _say(text: String, seconds: float) -> void:
	GameState.subtitle.emit(text, seconds)

# --- Builders -------------------------------------------------------------

func _box(box_name: String, pos: Vector3, size: Vector3, material: Material, body: StaticBody3D = null) -> StaticBody3D:
	if body == null:
		body = StaticBody3D.new()
	body.name = box_name
	body.position = pos
	var mesh := MeshInstance3D.new()
	var box_mesh := BoxMesh.new()
	box_mesh.size = size
	mesh.mesh = box_mesh
	mesh.material_override = material
	body.add_child(mesh)
	var shape := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = size
	shape.shape = box_shape
	body.add_child(shape)
	add_child(body)
	return body

func _hiding_spot(spot_name: String, pos: Vector3, size: Vector3) -> HidingSpot:
	return _box(spot_name, pos, size, _prop_material, HidingSpot.new()) as HidingSpot

func _interactable(item_name: String, pos: Vector3, size: Vector3, victim: String, monster: String = "") -> Interactable:
	var item := Interactable.new()
	item.victim_prompt = victim
	item.monster_prompt = monster
	return _box(item_name, pos, size, _prop_material, item) as Interactable

func _add_light(pos: Vector3, color: Color, energy: float, range_m: float) -> void:
	var light := OmniLight3D.new()
	light.position = pos
	light.light_color = color
	light.light_energy = energy
	light.omni_range = range_m
	add_child(light)
	_lights.append(light)
	_light_energies.append(energy)
