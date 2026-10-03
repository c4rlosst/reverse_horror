extends Node
## Room tone, the heartbeat that follows GameState.tension, and the
## breathing that takes over once the player has become the monster.

const AMBIENT_DB := -12.0

var _ambient: AudioStreamPlayer
var _breathing: AudioStreamPlayer
var _heart: AudioStreamPlayer
var _heart_timer: float = 0.0
var _tension: float = 0.0
var _monster_mix: float = 0.0

func _ready() -> void:
	_ambient = Sfx.loop(&"ambient", AMBIENT_DB, self)
	_breathing = Sfx.loop(&"breathing", -80.0, self)
	_heart = AudioStreamPlayer.new()
	_heart.stream = Sfx.BANK[&"heartbeat"][0]
	add_child(_heart)

func _process(delta: float) -> void:
	_tension = lerpf(_tension, GameState.tension, minf(delta * 2.0, 1.0))
	var monster := GameState.perspective == GameState.Perspective.MONSTER
	_monster_mix = move_toward(_monster_mix, 1.0 if monster else 0.0, delta * 0.4)
	_ambient.pitch_scale = lerpf(1.0, 0.8, _monster_mix)
	_ambient.volume_db = AMBIENT_DB + _tension * 3.0
	_breathing.volume_db = lerpf(-80.0, -9.0, _monster_mix)
	_breathing.pitch_scale = lerpf(0.8, 1.0, _tension) if monster else 1.0
	_heart_timer -= delta
	if _tension > 0.12 and _heart_timer <= 0.0:
		_heart.volume_db = lerpf(-30.0, -2.0, _tension)
		_heart.pitch_scale = lerpf(0.9, 1.15, _tension)
		_heart.play()
		_heart_timer = lerpf(1.2, 0.5, _tension)
