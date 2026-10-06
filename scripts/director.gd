extends Node
## Story director. Walks the player through the night: the phone call, the
## hunt, the glass at the back door, the reversal, and the closet.

enum Phase { INTRO, RINGING, CALL, HUNT, KEY, DOOR, REVEAL, MONSTER, CHOICE, ENDED }

const BACK_DOOR_FRONT := Vector3(5.5, 0.0, -4.0)
const SIREN_AT := 120.0
const POLICE_AT := 200.0
const RING_VOLUME := 4.0

var phase: Phase = Phase.INTRO

var _house: Node3D
var _player: Player
var _figure: ShadowFigure
var _father: FamilyMember
var _mother: FamilyMember
var _ring: AudioStreamPlayer3D
var _ring_light: OmniLight3D
var _ring_tween: Tween
var _mimic: Node3D
var _mimic_light: OmniLight3D
var _has_key: bool = false
var _checkpoint := Vector3(5.5, 0.05, 3.6)
var _monster_time: float = 0.0
var _siren_started: bool = false
var _choice_ready: bool = false
var _stare_hinted: bool = false
var _hud: Node

func _ready() -> void:
	_begin.call_deferred()

func _begin() -> void:
	_house = get_parent()
	_player = _house.player
	_figure = _house.figure
	_hud = get_tree().get_first_node_in_group("hud")
	_build_mimic()
	_build_family()
	_connect_items()
	GameState.event_raised.connect(_on_event)
	_start_ringing()
	GameState.objective_changed.emit("Answer the ringing phone.")
	GameState.say("You're alone in the house. A phone is ringing in the hall.", 5.0)
	if _hud != null:
		_hud.fade_in(2.5)
	phase = Phase.RINGING
	await _wait(9.0)
	if phase == Phase.RINGING:
		if GameState.touch_mode:
			GameState.say("Drag the left side to move, the right to look. Tap Use at the phone.", 5.0)
		else:
			GameState.say("Move with WASD. Press E on the phone.", 4.0)
	await _wait(14.0)
	if phase == Phase.RINGING:
		GameState.say("[You turn toward the ringing.]", 3.0)
		_player.look_toward(_house.items[&"phone"].global_position, 1.2)

func _connect_items() -> void:
	var items: Dictionary = _house.items
	items[&"phone"].interacted.connect(_on_phone_answered)
	items[&"key"].interacted.connect(_on_key_taken)
	items[&"back_door"].interacted.connect(_on_back_door)
	(_house.spots[&"closet"] as HidingSpot).interacted.connect(_on_closet_opened)

func _build_mimic() -> void:
	_mimic = BodyBuilder.creature()
	_mimic.visible = false
	_house.add_child(_mimic)
	_mimic_light = OmniLight3D.new()
	_mimic_light.light_color = Color(0.5, 0.65, 1.0)
	_mimic_light.light_energy = 2.6
	_mimic_light.omni_range = 1.7
	_mimic_light.position = Vector3(0, 1.4, -0.5)
	_mimic.add_child(_mimic_light)

func _build_family() -> void:
	_father = FamilyMember.new()
	_father.role = FamilyMember.Role.FATHER
	_father.name = "Father"
	_house.add_child(_father)
	_father.setup(_house)
	_father.spotted_player.connect(_on_family_spotted)
	_father.left_house.connect(_on_family_left)
	_mother = FamilyMember.new()
	_mother.role = FamilyMember.Role.MOTHER
	_mother.name = "Mother"
	_house.add_child(_mother)
	_mother.setup(_house)
	_mother.spotted_player.connect(_on_family_spotted)
	_mother.left_house.connect(_on_family_left)

func _start_ringing() -> void:
	var phone: Node3D = _house.items[&"phone"]
	_ring = AudioStreamPlayer3D.new()
	_ring.stream = Sfx.BANK[&"phone_ring"][0]
	_ring.unit_size = 7.0
	_ring.max_distance = 40.0
	_ring.volume_db = RING_VOLUME
	phone.add_child(_ring)
	_ring.finished.connect(_ring.play)
	_ring.play()
	_ring_light = OmniLight3D.new()
	_ring_light.light_color = Color(1.0, 0.45, 0.3)
	_ring_light.omni_range = 3.5
	_ring_light.light_energy = 0.0
	_ring_light.position = Vector3(0, 0.3, 0)
	phone.add_child(_ring_light)
	_ring_tween = create_tween().set_loops()
	_ring_tween.tween_property(_ring_light, "light_energy", 2.0, 0.15)
	_ring_tween.tween_property(_ring_light, "light_energy", 0.1, 0.55)

func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds, false).timeout

func _process(delta: float) -> void:
	match phase:
		Phase.KEY:
			if _player.global_position.distance_to(BACK_DOOR_FRONT) < 4.2:
				_prepare_door()
		Phase.DOOR:
			_update_mimic()
		Phase.MONSTER:
			_tick_monster(delta)
		Phase.CHOICE:
			_tick_choice()

# --- Victim half ----------------------------------------------------------

func _on_phone_answered(_who: Player) -> void:
	if phase != Phase.RINGING:
		return
	phase = Phase.CALL
	_house.items[&"phone"].enabled = false
	_ring.finished.disconnect(_ring.play)
	_ring.stop()
	_ring_tween.kill()
	_ring_light.light_energy = 0.0
	GameState.raise_event(&"phone_answered")
	GameState.objective_changed.emit("")
	Sfx.play(&"phone_pickup", 0.0)
	var hiss := Sfx.loop(&"static", -20.0)
	await _wait(0.8)
	Sfx.play(&"voice", -3.0)
	GameState.say("[A voice on the line, too muffled to make out.]", 4.5)
	await _wait(5.2)
	Sfx.play(&"breathing", -6.0)
	GameState.say("[Breathing. Very close to the receiver.]", 3.5)
	await _wait(4.0)
	hiss.queue_free()
	Sfx.play(&"click", 0.0)
	GameState.say("[The line goes dead.]", 2.5)
	await _wait(3.0)
	Sfx.play_at(&"thump", _house.graph.position_of(&"living"), 4.0)
	GameState.say("Something just moved in the house.", 3.5)
	await _wait(1.5)
	_figure.activate(_player.global_position)
	GameState.objective_changed.emit("Find a way out. Try the doors.")
	_checkpoint = _player.global_position
	phase = Phase.HUNT
	await _wait(7.0)
	if phase == Phase.HUNT:
		GameState.say("Running is loud. Crouch to stay quiet, and hide if it gets close.", 5.0)
	await _wait(50.0)
	if phase == Phase.HUNT and not _has_key:
		_point_to_key()

func _on_key_taken(_who: Player) -> void:
	var key: Interactable = _house.items[&"key"]
	key.enabled = false
	key.visible = false
	for child in key.get_children():
		if child is CollisionShape3D:
			child.set_deferred("disabled", true)
	_has_key = true
	GameState.raise_event(&"took_key")
	Sfx.play(&"keys", -4.0)
	GameState.say("A brass key. It's still warm.", 3.5)
	GameState.objective_changed.emit("Get out through the back door.")
	if phase == Phase.HUNT:
		phase = Phase.KEY

func _on_back_door(_who: Player) -> void:
	if phase == Phase.REVEAL or phase == Phase.MONSTER:
		return
	if not _has_key:
		Sfx.play(&"clunk", -6.0)
		_point_to_key()
		return
	_run_reveal()

func _point_to_key() -> void:
	GameState.say("Locked. A key could be in the bedroom, west of the hall.", 5.0)
	GameState.objective_changed.emit("Find the key. Try the bedroom nightstand.")

func _on_event(id: StringName) -> void:
	match id:
		&"caught":
			_respawn()
		&"figure_stare":
			if not _stare_hinted:
				_stare_hinted = true
				GameState.say("It has stopped. It's looking right at you. Get out of its sight.", 5.0)

func _respawn() -> void:
	if phase == Phase.MONSTER or phase == Phase.REVEAL:
		return
	if _hud != null:
		await _hud.fade_out(0.9).finished
	_player.exit_hiding()
	_player.global_position = _checkpoint
	_player.controls_enabled = true
	_figure.activate(_player.global_position)
	GameState.tension = 0.0
	GameState.say("You come to on the hall floor, as if you never left it.", 4.0)
	if _hud != null:
		_hud.fade_in(1.5)

func _prepare_door() -> void:
	phase = Phase.DOOR
	_figure.deactivate()
	GameState.say("The footsteps have stopped.", 3.5)
	_mimic.visible = true

func _update_mimic() -> void:
	var door_side: float = -5.0
	var player_pos := _player.global_position
	var near := player_pos.distance_to(BACK_DOOR_FRONT) < 6.5
	_mimic.visible = near
	if not near:
		return
	_mimic.global_position = Vector3(player_pos.x, 0.0, 2.0 * door_side - player_pos.z)
	_mimic.scale.y = clampf(_player.eye_position().y / 1.6, 0.55, 1.1)
	var flat := Vector3(player_pos.x - _mimic.global_position.x, 0.0, player_pos.z - _mimic.global_position.z)
	_mimic.rotation.y = atan2(-flat.x, -flat.z)

# --- The reveal -----------------------------------------------------------

func _run_reveal() -> void:
	phase = Phase.REVEAL
	_player.controls_enabled = false
	_figure.deactivate()
	_mimic.visible = true
	_update_mimic()
	Sfx.play(&"clunk", 0.0)
	GameState.say("The key turns.", 2.0)
	await _wait(2.2)
	_player.look_toward(_mimic.global_position + Vector3(0, 1.6, 0), 1.2)
	GameState.say("In the glass, something stands exactly where you are standing.", 4.5)
	await _wait(4.8)
	GameState.say("It moves when you move.", 3.0)
	await _wait(3.2)
	Sfx.play(&"sting", 0.0)
	if _hud != null:
		_hud.glitch(2.0)
	for line in _replay_lines():
		GameState.say(line, 2.8)
		await _wait(3.0)
	_player.look_toward(Vector3(5.4, 0.0, -3.4), 1.5)
	GameState.say("The wet prints on the floor are the size of your shoes.", 4.0)
	await _wait(4.5)
	_become_monster()
	await _wait(2.0)
	await _replay_call()
	await _family_arrives()

func _replay_lines() -> Array[String]:
	var lines: Array[String] = []
	if GameState.has_done(&"phone_answered"):
		lines.append("You answered the phone. You never said a word.")
	var spots_hidden := {}
	for entry in GameState.action_log:
		if entry["id"] == &"hid":
			spots_hidden[String(entry["detail"]).to_lower()] = true
	for spot_name in spots_hidden:
		lines.append("You hid in the %s, and listened to yourself walk past." % spot_name)
	lines.append("You took the key from a stranger's nightstand.")
	return lines

func _become_monster() -> void:
	GameState.set_perspective(GameState.Perspective.MONSTER)
	_mimic.visible = false
	_house.show_monster_photo()
	for id in _house.lights:
		if id != &"tv":
			(_house.lights[id] as FlickeringLight).dim_to(0.2, 3.0)
	_house.brighten_night()
	for lamp: Lamp in _house.lamps:
		lamp.light.switched_on = true
	_player.controls_enabled = true
	_player.level_view(1.5)
	GameState.objective_changed.emit("")

func _replay_call() -> void:
	GameState.say("[The phone plays the call again. Clearly, this time.]", 4.0)
	Sfx.play(&"voice", -2.0)
	await _wait(4.5)
	GameState.say("\"Please. Whoever you are, we know you're in there.\"", 4.5)
	await _wait(4.8)
	GameState.say("\"The police are on their way. We won't come inside.\"", 4.5)
	await _wait(4.8)
	GameState.say("\"Just please... don't hurt my son.\"", 4.5)
	await _wait(5.0)

func _family_arrives() -> void:
	Sfx.play(&"car", -2.0)
	_sweep_headlights()
	await _wait(5.5)
	Sfx.play(&"knock", 0.0)
	await _wait(0.5)
	Sfx.play(&"knock", 0.0)
	await _wait(1.5)
	Sfx.play(&"clunk", 2.0)
	GameState.say("\"Danny? Danny, it's Dad. Stay where you are.\"", 4.0)
	_father.enter(&"hall_front")
	_mother.enter(&"hall_front")
	_mother.position += Vector3(0.9, 0, 0.4)
	GameState.objective_changed.emit("The boy is hiding somewhere.")
	_monster_time = 0.0
	phase = Phase.MONSTER

func _sweep_headlights() -> void:
	var beam := SpotLight3D.new()
	beam.light_energy = 6.0
	beam.spot_range = 22.0
	beam.spot_angle = 24.0
	beam.shadow_enabled = true
	beam.position = Vector3(1.0, 1.0, 14.0)
	beam.rotation_degrees = Vector3(0.0, 8.0, 0.0)
	_house.add_child(beam)
	var tween := create_tween()
	tween.tween_property(beam, "rotation_degrees:y", -20.0, 1.8)
	tween.tween_property(beam, "position:x", 5.0, 0.01)
	tween.tween_property(beam, "rotation_degrees:y", 12.0, 0.01)
	tween.tween_property(beam, "rotation_degrees:y", -14.0, 2.2)
	tween.tween_property(beam, "light_energy", 0.0, 1.0)
	tween.tween_callback(beam.queue_free)

# --- Monster half ---------------------------------------------------------

func _tick_monster(delta: float) -> void:
	_monster_time += delta
	if not _siren_started and _monster_time > SIREN_AT:
		_siren_started = true
		Sfx.play(&"siren", -12.0)
		GameState.say("Sirens, far away. Getting closer.", 4.0)
	if _monster_time > POLICE_AT:
		_end("OUT OF DARK", "Blue light filled every window. You ran out of dark before you ran out of time.")

func _on_family_spotted(member: FamilyMember) -> void:
	if member.role == FamilyMember.Role.FATHER:
		GameState.say("\"There's something in the hall! Get back, get BACK!\"", 4.0)
	else:
		GameState.say("\"Oh God. Oh God, it's right there.\"", 4.0)
	Sfx.play(&"thump", 2.0)

func _on_family_left(_member: FamilyMember) -> void:
	if _father.fled and _mother.fled:
		GameState.say("The front door slams. The house is quiet. Almost.", 4.0)
		GameState.objective_changed.emit("Only the boy is left.")

func _on_closet_opened(_who: Player) -> void:
	if phase != Phase.MONSTER:
		return
	phase = Phase.CHOICE
	_player.controls_enabled = false
	_house.closet_boy.visible = true
	_house.closet_glow.light_energy = 1.3
	var closet: HidingSpot = _house.spots[&"closet"]
	closet.enabled = false
	Sfx.play(&"creak", -2.0)
	_player.look_toward(_house.closet_boy.global_position + Vector3(0, 1.07, 0), 1.2)
	GameState.objective_changed.emit("")
	GameState.say("[A small breath, behind the slats.]", 3.5)
	await _wait(4.0)
	GameState.say("He's looking at you. He knows exactly what you are.", 4.5)
	await _wait(4.5)
	_choice_ready = true
	_player.set_prompt_override("[E] Reach out\n[Q] Back away")

func _tick_choice() -> void:
	if not _choice_ready:
		return
	if Input.is_action_just_pressed("interact"):
		_choice_ready = false
		_end("STILL HERE", "The boy stopped crying when your hand touched his. In the morning the police found the house locked from the inside, every light off, and the phone still off its cradle.")
	elif Input.is_action_just_pressed("back_away"):
		_choice_ready = false
		_end("LET GO", "You let the dark close over the closet door. They never came back for their things. The house is quiet now. You still answer when the phone rings.")

func _end(title: String, text: String) -> void:
	if phase == Phase.ENDED:
		return
	phase = Phase.ENDED
	_player.controls_enabled = false
	_player.set_prompt_override("")
	GameState.ending_reached.emit(title, text)
