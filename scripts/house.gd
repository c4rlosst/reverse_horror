extends Node3D
## The house: geometry, furniture, lights, and the walkable graph. Story
## logic lives in director.gd; this script only builds and exposes things.

const WALL_HEIGHT := 2.6
const WALL_THICKNESS := 0.2
const DOOR_HEIGHT := 2.1
const SILL := 0.9
const WINDOW_TOP := 2.0

var graph := HouseGraph.new()
var spots: Dictionary = {}
var items: Dictionary = {}
var lights: Dictionary = {}
var lamps: Array[Lamp] = []
var photo_frames: Array[MeshInstance3D] = []
var closet_boy: Node3D
var closet_glow: OmniLight3D

@onready var player: Player = $Player
@onready var figure: ShadowFigure = $ShadowFigure

func _ready() -> void:
	Sfx.world = self
	_build_shell()
	_build_living_room()
	_build_kitchen()
	_build_bedroom()
	_build_hall()
	_build_footprints()
	_build_moon()
	_build_graph()
	figure.setup(self)
	player.global_position = Vector3(5.5, 0.05, 3.6)
	player.rotation.y = deg_to_rad(90.0)

func _process(_delta: float) -> void:
	for id in lights:
		var light: FlickeringLight = lights[id]
		var distance := figure.global_position.distance_to(light.global_position)
		light.flicker_amount = clampf(1.0 - distance / 7.0, 0.0, 1.0) if figure.visible else 0.0

# --- Shell ----------------------------------------------------------------
# x runs west to east (-7..7), z runs north to south (-5..5). A window or
# doorway is Vector4(start, end, bottom, top) measured along the wall.

func _build_shell() -> void:
	_box("Floor", Vector3(0, -0.1, 0), Vector3(14, 0.2, 10), Surfaces.floor_boards())
	_box("Ceiling", Vector3(0, WALL_HEIGHT + 0.1, 0), Vector3(14, 0.2, 10), Surfaces.ceiling())
	_box("Yard", Vector3(0, -0.35, 0), Vector3(80, 0.2, 80), Surfaces.plain(Color(0.05, 0.07, 0.05)), false)
	_wall(&"x", -5.0, -7.0, 7.0, [
		Vector4(-4.6, -3.4, SILL, WINDOW_TOP),
		Vector4(3.0, 4.2, 1.1, WINDOW_TOP),
		Vector4(5.0, 6.0, SILL, 1.95),
	])
	_wall(&"x", 5.0, -7.0, 7.0, [
		Vector4(1.0, 2.2, SILL, WINDOW_TOP),
		Vector4(-3.8, -2.6, SILL, WINDOW_TOP),
	])
	_wall(&"z", -7.0, -5.0, 5.0, [Vector4(1.6, 2.8, SILL, WINDOW_TOP)])
	_wall(&"z", 7.0, -5.0, 5.0, [Vector4(-3.8, -2.6, SILL, WINDOW_TOP)])
	_wall(&"x", 0.0, -7.0, 7.0, [
		Vector4(-4.0, -2.0, 0.0, DOOR_HEIGHT),
		Vector4(3.5, 5.5, 0.0, DOOR_HEIGHT),
	])
	_wall(&"z", 2.0, -5.0, 0.0, [Vector4(-3.0, -1.0, 0.0, DOOR_HEIGHT)])
	_wall(&"z", 0.0, 0.0, 5.0, [Vector4(2.0, 4.0, 0.0, DOOR_HEIGHT)])

func _wall(axis: StringName, fixed: float, from: float, to: float, openings: Array) -> void:
	var cursor := from
	for opening: Vector4 in openings:
		if opening.x > cursor:
			_wall_segment(axis, fixed, cursor, opening.x, 0.0, WALL_HEIGHT, true)
		if opening.z > 0.0:
			_wall_segment(axis, fixed, opening.x, opening.y, 0.0, opening.z, false)
			_glass(axis, fixed, opening.x, opening.y, opening.z, opening.w)
		_wall_segment(axis, fixed, opening.x, opening.y, opening.w, WALL_HEIGHT, false)
		cursor = opening.y
	if cursor < to:
		_wall_segment(axis, fixed, cursor, to, 0.0, WALL_HEIGHT, true)

func _wall_segment(axis: StringName, fixed: float, a: float, b: float, y0: float, y1: float, baseboard: bool) -> void:
	var length := b - a
	var centre_y := (y0 + y1) / 2.0
	var height := y1 - y0
	var mid := (a + b) / 2.0
	var wall: StaticBody3D
	if axis == &"x":
		wall = _box("Wall", Vector3(mid, centre_y, fixed), Vector3(length, height, WALL_THICKNESS), Surfaces.wallpaper())
		if baseboard:
			_part(wall, Vector3(0, -centre_y + 0.07, 0), Vector3(length, 0.14, WALL_THICKNESS + 0.04), Surfaces.wood(Color(0.2, 0.14, 0.1)))
	else:
		wall = _box("Wall", Vector3(fixed, centre_y, mid), Vector3(WALL_THICKNESS, height, length), Surfaces.wallpaper())
		if baseboard:
			_part(wall, Vector3(0, -centre_y + 0.07, 0), Vector3(WALL_THICKNESS + 0.04, 0.14, length), Surfaces.wood(Color(0.2, 0.14, 0.1)))

func _glass(axis: StringName, fixed: float, a: float, b: float, y0: float, y1: float) -> void:
	var length := b - a
	var mid := (a + b) / 2.0
	var centre_y := (y0 + y1) / 2.0
	var height := y1 - y0
	var pane: StaticBody3D
	if axis == &"x":
		pane = _box("Window", Vector3(mid, centre_y, fixed), Vector3(length, height, 0.04), Surfaces.glass())
		_part(pane, Vector3(0, 0, 0), Vector3(length, 0.05, 0.08), Surfaces.wood(Color(0.2, 0.15, 0.1)))
		_part(pane, Vector3(0, 0, 0), Vector3(0.05, height, 0.08), Surfaces.wood(Color(0.2, 0.15, 0.1)))
	else:
		pane = _box("Window", Vector3(fixed, centre_y, mid), Vector3(0.04, height, length), Surfaces.glass())
		_part(pane, Vector3(0, 0, 0), Vector3(0.08, 0.05, length), Surfaces.wood(Color(0.2, 0.15, 0.1)))
		_part(pane, Vector3(0, 0, 0), Vector3(0.08, height, 0.05), Surfaces.wood(Color(0.2, 0.15, 0.1)))

# --- Rooms ----------------------------------------------------------------

func _build_living_room() -> void:
	var fabric := Surfaces.fabric(Color(0.28, 0.2, 0.16))
	var couch := _solid("Couch", Vector3(-4.6, 0.4, -2.5), Vector3(0.95, 0.8, 2.4))
	_part(couch, Vector3(0, -0.15, 0), Vector3(0.95, 0.5, 2.4), fabric)
	_part(couch, Vector3(0.37, 0.2, 0), Vector3(0.22, 0.8, 2.4), fabric)
	_part(couch, Vector3(0, 0.0, 1.1), Vector3(0.95, 0.6, 0.2), fabric)
	_part(couch, Vector3(0, 0.0, -1.1), Vector3(0.95, 0.6, 0.2), fabric)
	_part(couch, Vector3(-0.05, 0.17, 0.5), Vector3(0.7, 0.18, 0.95), fabric)
	_part(couch, Vector3(-0.05, 0.17, -0.5), Vector3(0.7, 0.18, 0.95), fabric)

	var table := _solid("CoffeeTable", Vector3(-5.8, 0.2, -2.5), Vector3(0.6, 0.4, 1.0))
	_part(table, Vector3.ZERO, Vector3(0.6, 0.4, 1.0), Surfaces.wood(Color(0.22, 0.15, 0.1)))

	var stand := _solid("TvStand", Vector3(-6.6, 0.3, -2.5), Vector3(0.55, 0.6, 1.8))
	_part(stand, Vector3.ZERO, Vector3(0.55, 0.6, 1.8), Surfaces.wood(Color(0.17, 0.12, 0.09)))
	_part(stand, Vector3(0, 0.62, 0), Vector3(0.18, 0.8, 1.25), Surfaces.plain(Color(0.03, 0.03, 0.035), 0.4))
	_part(stand, Vector3(0.1, 0.62, 0), Vector3(0.02, 0.66, 1.1), Surfaces.glow(Color(0.35, 0.55, 0.85), 0.55))

	var shelf := _solid("Bookshelf", Vector3(-0.9, 1.0, -4.65), Vector3(1.3, 2.0, 0.4))
	_part(shelf, Vector3.ZERO, Vector3(1.3, 2.0, 0.4), Surfaces.wood(Color(0.2, 0.14, 0.09)))
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for row in 4:
		for slot in 9:
			var colour := Color.from_hsv(rng.randf(), 0.35, rng.randf_range(0.25, 0.5))
			_part(shelf, Vector3(-0.55 + slot * 0.13, -0.78 + row * 0.5, 0.2), Vector3(0.1, 0.38, 0.05), Surfaces.plain(colour))

	var side := _solid("SideTable", Vector3(-2.3, 0.3, -4.6), Vector3(0.5, 0.6, 0.5))
	_part(side, Vector3.ZERO, Vector3(0.5, 0.6, 0.5), Surfaces.wood(Color(0.22, 0.15, 0.1)))
	var lamp := _make_lamp("LivingLamp", Vector3(-2.3, 0.85, -4.6))
	lamp.light = _add_light(&"living", Vector3(-2.3, 1.15, -4.55), Color(1.0, 0.72, 0.42), 1.1, 8.0, true)
	items[&"living_lamp"] = lamp

	var closet := _wardrobe("Closet", Vector3(-6.25, 1.1, -4.4), Vector3(1.2, 2.2, 1.0), 0.0)
	closet.exit_offset = Vector3(0, -1.1, 1.2)
	closet.facing_degrees = 180.0
	closet.peek_height = 1.5
	closet.monster_interacts = true
	closet.monster_prompt = "Open the door"
	closet.check_point = Vector3(-6.25, 0.0, -3.1)
	spots[&"closet"] = closet
	closet_boy = BodyBuilder.person(Color(0.62, 0.6, 0.58), 1.15)
	closet_boy.position = Vector3(0, -1.0, -0.1)
	closet_boy.rotation_degrees.y = 180.0
	closet_boy.visible = false
	closet.add_child(closet_boy)
	closet_glow = OmniLight3D.new()
	closet_glow.light_color = Color(0.55, 0.7, 1.0)
	closet_glow.light_energy = 0.0
	closet_glow.omni_range = 2.5
	closet_glow.position = Vector3(0, 0.3, 0.2)
	closet.add_child(closet_glow)
	var eyes := Surfaces.glow(Color(0.9, 0.95, 1.0), 1.2)
	for side_x in [-0.045, 0.045]:
		var eye := MeshInstance3D.new()
		var eye_mesh := SphereMesh.new()
		eye_mesh.radius = 0.02
		eye_mesh.height = 0.04
		eye.mesh = eye_mesh
		eye.material_override = eyes
		eye.position = Vector3(side_x, 1.07, -0.1)
		closet_boy.add_child(eye)

	var tv := Interactable.new()
	tv.name = "Television"
	tv.victim_prompt = "Look at the TV"
	tv.victim_text = "Static. The picture rolls once, as if something passed in front of it."
	tv.monster_text = "Static. In the grey you can almost see your own outline."
	_box("Television", Vector3(-6.35, 0.95, -2.5), Vector3(0.1, 0.7, 1.2), null, true, tv, false)
	items[&"tv"] = tv
	_add_light(&"tv", Vector3(-5.9, 1.0, -2.5), Color(0.5, 0.7, 1.0), 0.8, 5.0, false).ambient_flicker = 0.25

func _build_kitchen() -> void:
	var counter := _solid("Counter", Vector3(3.4, 0.5, -4.55), Vector3(2.0, 1.0, 0.8))
	_part(counter, Vector3.ZERO, Vector3(2.0, 1.0, 0.8), Surfaces.wood(Color(0.28, 0.22, 0.16)))
	_part(counter, Vector3(0, 0.52, 0), Vector3(2.05, 0.05, 0.85), Surfaces.plain(Color(0.35, 0.35, 0.33), 0.4))

	var table := _solid("KitchenTable", Vector3(3.2, 0.4, -0.95), Vector3(1.2, 0.8, 0.8))
	_part(table, Vector3(0, 0.37, 0), Vector3(1.2, 0.06, 0.8), Surfaces.wood(Color(0.3, 0.22, 0.14)))
	for leg_x in [-0.52, 0.52]:
		for leg_z in [-0.32, 0.32]:
			_part(table, Vector3(leg_x, -0.02, leg_z), Vector3(0.06, 0.76, 0.06), Surfaces.wood(Color(0.25, 0.18, 0.12)))
	_part(table, Vector3(0.1, 0.43, 0.0), Vector3(0.22, 0.04, 0.22), Surfaces.plain(Color(0.7, 0.68, 0.62)))
	var sandwich := Interactable.new()
	sandwich.name = "Sandwich"
	sandwich.victim_prompt = "Look at the plate"
	sandwich.victim_text = "A sandwich, one bite taken, the crusts cut off. Still cold. Someone left in a hurry."
	sandwich.monster_text = "Someone left in a hurry. You think it was you who made them go."
	_box("Plate", Vector3(3.3, 0.86, -0.95), Vector3(0.25, 0.08, 0.25), null, true, sandwich, false)
	items[&"sandwich"] = sandwich

	var fridge := _solid("Fridge", Vector3(6.55, 0.95, -4.35), Vector3(0.8, 1.9, 0.8))
	_part(fridge, Vector3.ZERO, Vector3(0.8, 1.9, 0.8), Surfaces.plain(Color(0.6, 0.6, 0.58), 0.35))
	_part(fridge, Vector3(-0.42, 0.2, 0.25), Vector3(0.03, 0.7, 0.04), Surfaces.plain(Color(0.2, 0.2, 0.2)))
	var note := Interactable.new()
	note.name = "FridgeNote"
	note.victim_prompt = "Read the note"
	note.victim_text = "A note on the fridge, in a mother's handwriting: \"Danny, don't open the door for anyone. Back by midnight. Love, Mom.\""
	note.monster_text = "The note says Danny. A child's name. He's been counting the minutes since the lights went out."
	_box("FridgeNote", Vector3(6.12, 1.35, -4.35), Vector3(0.03, 0.28, 0.2), Surfaces.plain(Color(0.85, 0.82, 0.7)), true, note)
	items[&"fridge_note"] = note

	var pantry := _wardrobe("Pantry", Vector3(6.4, 1.1, -1.4), Vector3(1.0, 2.2, 1.0), -90.0)
	pantry.exit_offset = Vector3(0, -1.1, 1.4)
	pantry.facing_degrees = 90.0
	pantry.peek_height = 1.5
	pantry.check_point = Vector3(5.1, 0.0, -1.4)
	spots[&"pantry"] = pantry

	var switch := _make_lamp("KitchenSwitch", Vector3(6.0, 1.3, -0.12), Vector3(0.1, 0.14, 0.04), false)
	switch.light = _add_light(&"kitchen", Vector3(4.3, 2.3, -2.4), Color(0.75, 0.9, 1.0), 0.9, 8.0, true)
	items[&"kitchen_switch"] = switch

	var back_door := _door("BackDoor", Vector3(5.5, 1.05, -4.88), true)
	back_door.victim_prompt = "Try the back door"
	items[&"back_door"] = back_door

func _build_bedroom() -> void:
	var linen := Surfaces.fabric(Color(0.3, 0.32, 0.38))
	var bed := _wardrobe_spot("Bed", Vector3(-4.5, 0.36, 3.0), Vector3(2.0, 0.72, 1.6))
	for leg_x in [-0.95, 0.95]:
		for leg_z in [-0.75, 0.75]:
			_part(bed, Vector3(leg_x, -0.18, leg_z), Vector3(0.08, 0.36, 0.08), Surfaces.wood(Color(0.2, 0.14, 0.1)))
	_part(bed, Vector3(0, 0.1, 0), Vector3(2.0, 0.06, 1.6), Surfaces.wood(Color(0.2, 0.14, 0.1)))
	_part(bed, Vector3(0, 0.24, 0), Vector3(2.0, 0.22, 1.6), linen)
	_part(bed, Vector3(-0.8, 0.4, 0), Vector3(0.4, 0.12, 0.9), Surfaces.fabric(Color(0.55, 0.55, 0.52)))
	_part(bed, Vector3(-1.02, 0.45, 0), Vector3(0.06, 0.9, 1.6), Surfaces.wood(Color(0.2, 0.14, 0.1)))
	bed.hide_offset = Vector3(0, -0.36, 0)
	bed.exit_offset = Vector3(1.6, -0.36, 0)
	bed.facing_degrees = -90.0
	bed.peek_height = 0.3
	bed.check_point = Vector3(-2.9, 0.0, 3.0)
	spots[&"bed"] = bed

	var stand := _solid("Nightstand", Vector3(-6.4, 0.275, 3.2), Vector3(0.6, 0.55, 0.9))
	_part(stand, Vector3.ZERO, Vector3(0.6, 0.55, 0.9), Surfaces.wood(Color(0.22, 0.15, 0.1)))
	var lamp := _make_lamp("BedroomLamp", Vector3(-6.4, 0.75, 3.45))
	lamp.light = _add_light(&"bedroom", Vector3(-6.3, 0.98, 3.45), Color(0.6, 0.68, 1.0), 0.8, 6.5, true)
	items[&"bedroom_lamp"] = lamp
	var key := Interactable.new()
	key.name = "Key"
	key.victim_prompt = "Take the key"
	_box("Key", Vector3(-6.4, 0.6, 2.95), Vector3(0.1, 0.03, 0.05), Surfaces.glow(Color(0.9, 0.75, 0.3), 0.6), true, key)
	items[&"key"] = key

	var dresser := _solid("Dresser", Vector3(-3.0, 0.45, 4.65), Vector3(1.2, 0.9, 0.5))
	_part(dresser, Vector3.ZERO, Vector3(1.2, 0.9, 0.5), Surfaces.wood(Color(0.24, 0.17, 0.11)))
	for drawer in 3:
		_part(dresser, Vector3(0, -0.28 + drawer * 0.28, -0.26), Vector3(1.1, 0.02, 0.03), Surfaces.plain(Color(0.08, 0.06, 0.05)))

func _build_hall() -> void:
	var console := _solid("Console", Vector3(3.0, 0.4, 4.65), Vector3(1.3, 0.8, 0.45))
	_part(console, Vector3.ZERO, Vector3(1.3, 0.8, 0.45), Surfaces.wood(Color(0.2, 0.14, 0.1)))
	var phone := Interactable.new()
	phone.name = "Phone"
	phone.victim_prompt = "Answer the phone"
	phone.victim_text = ""
	_box("Phone", Vector3(3.0, 0.9, 4.65), Vector3(0.28, 0.14, 0.2), Surfaces.plain(Color(0.05, 0.05, 0.06), 0.3), true, phone)
	items[&"phone"] = phone

	var hall_lamp := _make_lamp("HallLamp", Vector3(3.8, 0.95, 4.65))
	hall_lamp.light = _add_light(&"hall", Vector3(3.8, 1.25, 4.4), Color(1.0, 0.8, 0.55), 0.8, 7.0, true)
	items[&"hall_lamp"] = hall_lamp

	var frame := Interactable.new()
	frame.name = "FamilyPhoto"
	frame.victim_prompt = "Look at the photo"
	frame.victim_text = "A family photo: a mother, a father, a small boy. They are smiling, but all three are looking just past the camera."
	frame.monster_text = "They aren't looking past the camera. They are looking at you."
	var frame_body := _box("FamilyPhoto", Vector3(0.14, 1.5, 1.0), Vector3(0.05, 0.62, 0.5), Surfaces.wood(Color(0.12, 0.09, 0.07)), true, frame)
	var picture := MeshInstance3D.new()
	var picture_mesh := BoxMesh.new()
	picture_mesh.size = Vector3(0.02, 0.5, 0.38)
	picture.mesh = picture_mesh
	picture.material_override = _photo_material(false)
	picture.position = Vector3(0.03, 0, 0)
	frame_body.add_child(picture)
	photo_frames.append(picture)
	items[&"photo"] = frame

	var front_door := _door("FrontDoor", Vector3(6.0, 1.05, 4.88), false)
	front_door.victim_prompt = "Try the front door"
	front_door.victim_text = "Locked. The deadbolt is on the outside."
	front_door.monster_text = "You could open it. You don't."
	items[&"front_door"] = front_door

	var coats := _solid("CoatRack", Vector3(1.3, 0.9, 4.75), Vector3(0.4, 1.8, 0.3))
	_part(coats, Vector3.ZERO, Vector3(0.1, 1.8, 0.1), Surfaces.wood(Color(0.15, 0.1, 0.07)))
	_part(coats, Vector3(0, 0.3, 0), Vector3(0.36, 1.1, 0.14), Surfaces.fabric(Color(0.12, 0.13, 0.15)))

func _build_footprints() -> void:
	var wet := Surfaces.plain(Color(0.03, 0.05, 0.07), 0.15)
	var spots_xz := [
		Vector2(5.35, -4.5), Vector2(5.65, -4.0), Vector2(5.35, -3.5), Vector2(5.6, -3.0),
		Vector2(5.2, -2.5), Vector2(5.45, -2.0), Vector2(5.0, -1.5), Vector2(4.8, -1.0),
	]
	for i in spots_xz.size():
		_box("Print%d" % i, Vector3(spots_xz[i].x, 0.006, spots_xz[i].y), Vector3(0.13, 0.012, 0.3), wet, false)

func _build_moon() -> void:
	var moon := DirectionalLight3D.new()
	moon.rotation_degrees = Vector3(-32.0, 28.0, 0.0)
	moon.light_color = Color(0.45, 0.55, 0.85)
	moon.light_energy = 0.4
	moon.shadow_enabled = true
	add_child(moon)

func _build_graph() -> void:
	graph.add_node(&"hall", Vector3(3.5, 0, 2.6), [&"hall"])
	graph.add_node(&"hall_front", Vector3(5.4, 0, 3.6), [&"hall"])
	graph.add_node(&"d_hk", Vector3(4.5, 0, 0.0), [&"hall", &"kitchen"])
	graph.add_node(&"kitchen", Vector3(4.3, 0, -2.4), [&"kitchen"])
	graph.add_node(&"pantry_front", Vector3(5.1, 0, -1.4), [&"kitchen"])
	graph.add_node(&"backdoor_front", Vector3(5.5, 0, -3.8), [&"kitchen"])
	graph.add_node(&"d_lk", Vector3(2.0, 0, -2.0), [&"living", &"kitchen"])
	graph.add_node(&"living", Vector3(-3.0, 0, -2.4), [&"living"])
	graph.add_node(&"closet_front", Vector3(-6.25, 0, -3.0), [&"living"])
	graph.add_node(&"d_bl", Vector3(-3.0, 0, 0.0), [&"living", &"bedroom"])
	graph.add_node(&"bedroom", Vector3(-2.9, 0, 3.0), [&"bedroom"])
	graph.add_node(&"d_hb", Vector3(0.0, 0, 3.0), [&"bedroom", &"hall"])
	for pair in [
		[&"hall", &"hall_front"], [&"hall", &"d_hk"], [&"d_hk", &"kitchen"],
		[&"kitchen", &"pantry_front"], [&"kitchen", &"backdoor_front"], [&"kitchen", &"d_lk"],
		[&"d_lk", &"living"], [&"living", &"closet_front"], [&"living", &"d_bl"],
		[&"d_bl", &"bedroom"], [&"bedroom", &"d_hb"], [&"d_hb", &"hall"],
	]:
		graph.link(pair[0], pair[1])

# --- Builders -------------------------------------------------------------

func _box(box_name: String, pos: Vector3, size: Vector3, material: Material, collide: bool = true, body: StaticBody3D = null, with_mesh: bool = true) -> StaticBody3D:
	if body == null:
		body = StaticBody3D.new()
	body.name = box_name
	body.position = pos
	if with_mesh and material != null:
		var mesh := MeshInstance3D.new()
		var box_mesh := BoxMesh.new()
		box_mesh.size = size
		mesh.mesh = box_mesh
		mesh.material_override = material
		body.add_child(mesh)
	if collide:
		var shape := CollisionShape3D.new()
		var box_shape := BoxShape3D.new()
		box_shape.size = size
		shape.shape = box_shape
		body.add_child(shape)
	add_child(body)
	return body

func _part(parent: Node3D, pos: Vector3, size: Vector3, material: Material) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var box_mesh := BoxMesh.new()
	box_mesh.size = size
	mesh.mesh = box_mesh
	mesh.material_override = material
	mesh.position = pos
	parent.add_child(mesh)
	return mesh

## A collidable prop whose visuals are added as parts in its local space.
func _solid(solid_name: String, pos: Vector3, collision_size: Vector3) -> StaticBody3D:
	return _box(solid_name, pos, collision_size, null, true)

func _wardrobe_spot(spot_name: String, pos: Vector3, size: Vector3) -> HidingSpot:
	return _box(spot_name, pos, size, null, true, HidingSpot.new()) as HidingSpot

## Cabinet with a slatted door on its local +z face. The camera sits inside
## and looks out between the slats.
func _wardrobe(spot_name: String, pos: Vector3, size: Vector3, yaw_degrees: float) -> HidingSpot:
	var spot := _wardrobe_spot(spot_name, pos, size)
	spot.rotation_degrees.y = yaw_degrees
	spot.hide_offset = Vector3(0, -size.y / 2.0, 0)
	var wood := Surfaces.wood(Color(0.2, 0.14, 0.09))
	var dark := Surfaces.plain(Color(0.02, 0.015, 0.01))
	_part(spot, Vector3(0, 0, -size.z / 2.0 + 0.02), Vector3(size.x, size.y, 0.04), wood)
	_part(spot, Vector3(-size.x / 2.0 + 0.02, 0, 0), Vector3(0.04, size.y, size.z), wood)
	_part(spot, Vector3(size.x / 2.0 - 0.02, 0, 0), Vector3(0.04, size.y, size.z), wood)
	_part(spot, Vector3(0, size.y / 2.0 - 0.02, 0), Vector3(size.x, 0.04, size.z), wood)
	_part(spot, Vector3(0, -size.y / 2.0 + 0.02, 0), Vector3(size.x, 0.04, size.z), dark)
	var slat_height := 0.12
	var pitch := 0.2
	var count := int(size.y / pitch)
	for i in count:
		var y := -size.y / 2.0 + 0.1 + i * pitch
		if y > size.y / 2.0 - 0.1:
			break
		_part(spot, Vector3(0, y, size.z / 2.0 - 0.02), Vector3(size.x - 0.08, slat_height, 0.03), wood)
	_part(spot, Vector3(0, 0, size.z / 2.0 - 0.02), Vector3(0.05, size.y, 0.04), wood)
	return spot

func _make_lamp(lamp_name: String, pos: Vector3, collision_size: Vector3 = Vector3(0.24, 0.4, 0.24), table_lamp: bool = true) -> Lamp:
	var lamp := Lamp.new()
	_box(lamp_name, pos, collision_size, null, true, lamp)
	lamps.append(lamp)
	var dark := Surfaces.plain(Color(0.08, 0.06, 0.05), 0.5)
	var shade_material := Surfaces.glow(Color(1.0, 0.78, 0.5), 0.8).duplicate() as StandardMaterial3D
	if table_lamp:
		_part(lamp, Vector3(0, -0.18, 0), Vector3(0.14, 0.04, 0.14), dark)
		_part(lamp, Vector3(0, -0.06, 0), Vector3(0.03, 0.24, 0.03), dark)
		lamp.bulb = _part(lamp, Vector3(0, 0.1, 0), Vector3(0.24, 0.2, 0.24), shade_material)
	else:
		lamp.bulb = _part(lamp, Vector3.ZERO, collision_size, shade_material)
	return lamp

func _add_light(id: StringName, pos: Vector3, color: Color, energy: float, range_m: float, shadows: bool) -> FlickeringLight:
	var light := FlickeringLight.new()
	light.position = pos
	light.light_color = color
	light.base_energy = energy
	light.omni_range = range_m
	light.shadow_enabled = shadows
	add_child(light)
	lights[id] = light
	return light

func _door(door_name: String, pos: Vector3, glazed: bool) -> Interactable:
	var door := Interactable.new()
	_box(door_name, pos, Vector3(1.0, 2.1, 0.1), null, true, door)
	var wood := Surfaces.wood(Color(0.17, 0.11, 0.07))
	_part(door, Vector3(0, -0.5, 0), Vector3(0.96, 1.1, 0.06), wood)
	if not glazed:
		_part(door, Vector3(0, 0.55, 0), Vector3(0.96, 1.0, 0.06), wood)
	_part(door, Vector3(0.4, -0.05, 0.05), Vector3(0.05, 0.05, 0.08), Surfaces.plain(Color(0.6, 0.5, 0.2), 0.3))
	for side in [-0.5, 0.5]:
		_part(door, Vector3(side, 0, 0), Vector3(0.08, 2.1, 0.12), wood)
	_part(door, Vector3(0, 1.03, 0), Vector3(1.08, 0.08, 0.12), wood)
	return door

func _photo_material(with_shadow: bool) -> StandardMaterial3D:
	var size := 64
	var img := Image.create(size, size, false, Image.FORMAT_RGB8)
	img.fill(Color(0.55, 0.47, 0.35))
	var ink := Color(0.15, 0.1, 0.08)
	for person in [[18, 40, 8, 22], [32, 38, 8, 24], [47, 48, 5, 14]]:
		var cx: int = person[0]
		var head_y: int = person[1]
		var radius: int = person[2] / 2
		var body_h: int = person[3]
		for y in size:
			for x in size:
				if Vector2(x, y).distance_to(Vector2(cx, size - head_y)) < radius + 1:
					img.set_pixel(x, y, ink)
				elif absi(x - cx) < radius + 2 and y > size - head_y + radius and y < size - head_y + radius + body_h:
					img.set_pixel(x, y, ink)
	if with_shadow:
		for y in range(4, size - 4):
			for x in range(52, 60):
				img.set_pixel(x, y, Color(0.02, 0.02, 0.03))
		for y in range(6, 14):
			for x in range(51, 61):
				if Vector2(x, y).distance_to(Vector2(55.5, 10)) < 5.0:
					img.set_pixel(x, y, Color(0.02, 0.02, 0.03))
	var material := StandardMaterial3D.new()
	material.albedo_texture = ImageTexture.create_from_image(img)
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
	material.roughness = 0.5
	return material

func show_monster_photo() -> void:
	for frame in photo_frames:
		frame.material_override = _photo_material(true)

## The monster sees better in the dark than the victim did.
func brighten_night() -> void:
	var env := ($WorldEnvironment as WorldEnvironment).environment
	var tween := create_tween().set_parallel(true)
	tween.tween_property(env, "ambient_light_energy", 0.75, 3.0)
	tween.tween_property(env, "ambient_light_color", Color(0.35, 0.42, 0.62), 3.0)
