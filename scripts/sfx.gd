extends Node
## Sound helper. Plain one-shots, positional one-shots inside the 3D world,
## and seamless loops. Positional sounds need `world` to be the House node.

const BANK := {
	&"footstep": [
		preload("res://audio/footstep_1.wav"),
		preload("res://audio/footstep_2.wav"),
		preload("res://audio/footstep_3.wav"),
	],
	&"phone_ring": [preload("res://audio/phone_ring.wav")],
	&"phone_pickup": [preload("res://audio/phone_pickup.wav")],
	&"ambient": [preload("res://audio/ambient_room.wav")],
	&"heartbeat": [preload("res://audio/heartbeat.wav")],
	&"breathing": [preload("res://audio/breathing.wav")],
	&"static": [preload("res://audio/static_hiss.wav")],
	&"creak": [preload("res://audio/door_creak.wav")],
	&"rustle": [preload("res://audio/rustle.wav")],
	&"keys": [preload("res://audio/key_jingle.wav")],
	&"clunk": [preload("res://audio/door_clunk.wav")],
	&"click": [preload("res://audio/click.wav")],
	&"sting": [preload("res://audio/reveal_sting.wav")],
	&"voice": [preload("res://audio/phone_voice.wav")],
	&"car": [preload("res://audio/car_arrive.wav")],
	&"knock": [preload("res://audio/door_knock.wav")],
	&"thump": [preload("res://audio/thump.wav")],
	&"siren": [preload("res://audio/siren.wav")],
}

var world: Node = null

func _pick(id: StringName) -> AudioStream:
	var options: Array = BANK[id]
	return options[randi() % options.size()]

func play(id: StringName, volume_db: float = 0.0, pitch: float = 1.0) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.process_mode = Node.PROCESS_MODE_PAUSABLE
	player.stream = _pick(id)
	player.volume_db = volume_db
	player.pitch_scale = pitch
	add_child(player)
	player.finished.connect(player.queue_free)
	player.play()
	return player

func play_at(id: StringName, position: Vector3, volume_db: float = 0.0, pitch: float = 1.0, max_distance: float = 25.0) -> AudioStreamPlayer3D:
	if world == null or not is_instance_valid(world):
		return null
	var player := AudioStreamPlayer3D.new()
	player.stream = _pick(id)
	player.volume_db = volume_db
	player.pitch_scale = pitch
	player.unit_size = 5.0
	player.max_distance = max_distance
	world.add_child(player)
	player.global_position = position
	player.finished.connect(player.queue_free)
	player.play()
	return player

## Returns a player the caller owns. The stream is a private copy set to loop.
func loop(id: StringName, volume_db: float = 0.0, parent: Node = null) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.stream = loop_stream(id)
	player.volume_db = volume_db
	(parent if parent != null else self).add_child(player)
	player.play()
	return player

func loop_stream(id: StringName) -> AudioStream:
	var stream := _pick(id).duplicate() as AudioStreamWAV
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = stream.data.size() / 2
	return stream
