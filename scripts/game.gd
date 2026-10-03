extends Control
## Screen layer: prompt, subtitles, fades and the end card. The 3D world lives
## in a low-resolution SubViewport that this scene scales up.

const FADE_SECONDS := 2.5
const RESTART_HINT := "\n\nPress E to play again."

@onready var _prompt: Label = $Hud/Prompt
@onready var _subtitle: Label = $Hud/Subtitle
@onready var _fade: ColorRect = $Hud/Fade
@onready var _end_label: Label = $Hud/EndLabel
@onready var _post_fx: ColorRect = $PostFx

var _subtitle_serial: int = 0
var _ended: bool = false

func _ready() -> void:
	GameState.reset()
	GameState.prompt_changed.connect(_on_prompt_changed)
	GameState.subtitle.connect(_on_subtitle)
	GameState.ending_reached.connect(_on_ending)
	GameState.event_raised.connect(_on_event)
	GameState.perspective_changed.connect(_on_perspective_changed)

func _process(_delta: float) -> void:
	if _ended and Input.is_action_just_pressed("interact"):
		get_tree().reload_current_scene()

func _on_prompt_changed(text: String) -> void:
	_prompt.text = text

func _on_subtitle(text: String, seconds: float) -> void:
	_subtitle_serial += 1
	var serial := _subtitle_serial
	_subtitle.text = text
	await get_tree().create_timer(seconds).timeout
	if serial == _subtitle_serial:
		_subtitle.text = ""

func _on_event(id: StringName) -> void:
	if id == &"caught":
		_fade_to_black().finished.connect(func() -> void: get_tree().reload_current_scene())

func _on_perspective_changed(perspective: GameState.Perspective) -> void:
	var target := 1.0 if perspective == GameState.Perspective.MONSTER else 0.0
	var material := _post_fx.material as ShaderMaterial
	create_tween().tween_property(material, "shader_parameter/monster_mix", target, 3.0)

func _on_ending(text: String) -> void:
	_ended = true
	_prompt.text = ""
	_subtitle.text = ""
	await _fade_to_black().finished
	_end_label.text = text + RESTART_HINT
	_end_label.visible = true

func _fade_to_black() -> Tween:
	var tween := create_tween()
	tween.tween_property(_fade, "modulate:a", 1.0, FADE_SECONDS)
	return tween
