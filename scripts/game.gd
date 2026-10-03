extends Control
## Screen layer around the low-resolution 3D world: prompt, subtitles,
## objective, fades, pause menu and the end card. Built in code so the layout
## stays readable in one place.

const FADE_SECONDS := 2.5
const SUBTITLE_MAX_WIDTH := 880.0

var _prompt: Label
var _subtitle: Label
var _subtitle_panel: PanelContainer
var _objective: Label
var _fade: ColorRect
var _crosshair: ColorRect
var _capture_hint: Label
var _pause_menu: Control
var _end_card: Control
var _end_title: Label
var _end_body: Label
var _end_stats: Label
var _subtitle_serial: int = 0
var _objective_serial: int = 0
var _ended: bool = false
var _paused: bool = false

@onready var _post_fx: ColorRect = $PostFx

func _ready() -> void:
	add_to_group("hud")
	process_mode = Node.PROCESS_MODE_ALWAYS
	$WorldContainer.process_mode = Node.PROCESS_MODE_PAUSABLE
	theme = UiTheme.build()
	GameState.reset()
	_build_hud()
	_build_pause_menu()
	_build_end_card()
	GameState.prompt_changed.connect(_on_prompt_changed)
	GameState.subtitle.connect(_on_subtitle)
	GameState.objective_changed.connect(_on_objective)
	GameState.perspective_changed.connect(_on_perspective_changed)
	GameState.ending_reached.connect(_on_ending)
	_fade.modulate.a = 1.0

func _process(delta: float) -> void:
	var material := _post_fx.material as ShaderMaterial
	var current: float = material.get_shader_parameter("tension")
	material.set_shader_parameter("tension", lerpf(current, GameState.tension, minf(delta * 3.0, 1.0)))
	_capture_hint.visible = not _paused and not _ended and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED
	if Input.is_action_just_pressed("ui_cancel") and not _ended:
		_set_paused(not _paused)

# --- Public screen effects ------------------------------------------------

func fade_in(seconds: float) -> Tween:
	var tween := create_tween()
	tween.tween_property(_fade, "modulate:a", 0.0, seconds)
	return tween

func fade_out(seconds: float) -> Tween:
	var tween := create_tween()
	tween.tween_property(_fade, "modulate:a", 1.0, seconds)
	return tween

func glitch(seconds: float) -> void:
	var material := _post_fx.material as ShaderMaterial
	var tween := create_tween().set_parallel(true)
	tween.tween_property(material, "shader_parameter/aberration", 0.03, 0.15)
	tween.tween_property(material, "shader_parameter/grain_strength", 0.35, 0.15)
	tween.chain().tween_property(material, "shader_parameter/aberration", 0.002, seconds)
	tween.parallel().tween_property(material, "shader_parameter/grain_strength", 0.07, seconds)

# --- Signals --------------------------------------------------------------

func _on_prompt_changed(text: String) -> void:
	_prompt.text = text
	_prompt.visible = text != ""

func _on_subtitle(text: String, seconds: float) -> void:
	_subtitle_serial += 1
	var serial := _subtitle_serial
	_subtitle.text = text
	_subtitle_panel.visible = true
	await get_tree().create_timer(seconds, false).timeout
	if serial == _subtitle_serial:
		_subtitle_panel.visible = false

func _on_objective(text: String) -> void:
	_objective_serial += 1
	var serial := _objective_serial
	var tween := create_tween()
	tween.tween_property(_objective, "modulate:a", 0.0, 0.25)
	await tween.finished
	if serial != _objective_serial:
		return
	_objective.text = text
	if text != "":
		create_tween().tween_property(_objective, "modulate:a", 1.0, 0.6)

func _on_perspective_changed(perspective: GameState.Perspective) -> void:
	var target := 1.0 if perspective == GameState.Perspective.MONSTER else 0.0
	var material := _post_fx.material as ShaderMaterial
	create_tween().tween_property(material, "shader_parameter/monster_mix", target, 3.0)
	_crosshair.color = UiTheme.ALARM if target > 0.5 else UiTheme.BONE
	_crosshair.color.a = 0.6

func _on_ending(title: String, text: String) -> void:
	_ended = true
	_prompt.visible = false
	_subtitle_panel.visible = false
	_crosshair.visible = false
	_objective.text = ""
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	await fade_out(FADE_SECONDS).finished
	_end_title.text = title
	_end_body.text = text
	var seconds := GameState.elapsed_seconds()
	_end_stats.text = "Night lasted %d:%02d.  Hid %s.  Caught %s." % [seconds / 60, seconds % 60, _times(GameState.hide_count), _times(GameState.caught_count)]
	_end_card.visible = true
	(_end_card.find_child("PlayAgain", true, false) as Button).grab_focus()

func _times(count: int) -> String:
	if count == 0:
		return "never"
	return "once" if count == 1 else "%d times" % count

func _set_paused(value: bool) -> void:
	_paused = value
	get_tree().paused = value
	_pause_menu.visible = value
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if value else Input.MOUSE_MODE_CAPTURED
	if value:
		(_pause_menu.find_child("Resume", true, false) as Button).grab_focus()

# --- Layout ---------------------------------------------------------------

func _full_rect(node: Control) -> void:
	node.set_anchors_preset(Control.PRESET_FULL_RECT)
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE

func _build_hud() -> void:
	var hud := Control.new()
	hud.name = "Hud"
	_full_rect(hud)
	add_child(hud)

	_crosshair = ColorRect.new()
	_crosshair.color = Color(UiTheme.BONE, 0.6)
	_crosshair.custom_minimum_size = Vector2(4, 4)
	_crosshair.set_anchors_preset(Control.PRESET_CENTER)
	_crosshair.offset_left = -2
	_crosshair.offset_right = 2
	_crosshair.offset_top = -2
	_crosshair.offset_bottom = 2
	_crosshair.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(_crosshair)

	_objective = Label.new()
	_objective.position = Vector2(32, 28)
	_objective.add_theme_color_override("font_color", UiTheme.AMBER)
	_objective.add_theme_font_size_override("font_size", 18)
	_objective.add_theme_constant_override("outline_size", 6)
	_objective.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	hud.add_child(_objective)

	_capture_hint = Label.new()
	_capture_hint.text = "Click to look around"
	_capture_hint.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_capture_hint.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_capture_hint.offset_top = 90
	_capture_hint.add_theme_color_override("font_color", UiTheme.BONE)
	_capture_hint.add_theme_constant_override("outline_size", 8)
	_capture_hint.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
	_capture_hint.visible = false
	hud.add_child(_capture_hint)

	_prompt = Label.new()
	_prompt.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_prompt.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_prompt.offset_top = -190
	_prompt.offset_bottom = -140
	_prompt.offset_left = -300
	_prompt.offset_right = 300
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.add_theme_color_override("font_color", UiTheme.AMBER)
	_prompt.add_theme_font_size_override("font_size", 22)
	_prompt.add_theme_constant_override("outline_size", 8)
	_prompt.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
	_prompt.visible = false
	hud.add_child(_prompt)

	_subtitle_panel = PanelContainer.new()
	_subtitle_panel.add_theme_stylebox_override("panel", UiTheme.panel(0.7))
	_subtitle_panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_subtitle_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_subtitle_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_subtitle_panel.offset_bottom = -48
	_subtitle_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_subtitle_panel.visible = false
	hud.add_child(_subtitle_panel)
	_subtitle = Label.new()
	_subtitle.custom_minimum_size = Vector2(SUBTITLE_MAX_WIDTH, 0)
	_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_subtitle.add_theme_font_size_override("font_size", 22)
	_subtitle_panel.add_child(_subtitle)

	_fade = ColorRect.new()
	_fade.color = Color.BLACK
	_full_rect(_fade)
	add_child(_fade)

func _build_pause_menu() -> void:
	_pause_menu = ColorRect.new()
	(_pause_menu as ColorRect).color = Color(UiTheme.INK, 0.86)
	_full_rect(_pause_menu)
	_pause_menu.mouse_filter = Control.MOUSE_FILTER_STOP
	_pause_menu.visible = false
	add_child(_pause_menu)
	var column := VBoxContainer.new()
	column.set_anchors_preset(Control.PRESET_CENTER)
	column.grow_horizontal = Control.GROW_DIRECTION_BOTH
	column.grow_vertical = Control.GROW_DIRECTION_BOTH
	column.add_theme_constant_override("separation", 14)
	_pause_menu.add_child(column)
	var heading := Label.new()
	heading.text = "Paused"
	heading.add_theme_font_override("font", UiTheme.FONT_TITLE)
	heading.add_theme_font_size_override("font_size", 48)
	column.add_child(heading)
	var resume := Button.new()
	resume.name = "Resume"
	resume.text = "Resume"
	resume.pressed.connect(func() -> void: _set_paused(false))
	column.add_child(resume)
	UiTheme.settings_rows(column)
	var quit := Button.new()
	quit.text = "Quit to title"
	quit.pressed.connect(_quit_to_title)
	column.add_child(quit)

func _build_end_card() -> void:
	_end_card = ColorRect.new()
	(_end_card as ColorRect).color = Color.BLACK
	_full_rect(_end_card)
	_end_card.mouse_filter = Control.MOUSE_FILTER_STOP
	_end_card.visible = false
	add_child(_end_card)
	var column := VBoxContainer.new()
	column.set_anchors_preset(Control.PRESET_CENTER)
	column.grow_horizontal = Control.GROW_DIRECTION_BOTH
	column.grow_vertical = Control.GROW_DIRECTION_BOTH
	column.custom_minimum_size = Vector2(720, 0)
	column.add_theme_constant_override("separation", 22)
	_end_card.add_child(column)
	_end_title = Label.new()
	_end_title.add_theme_font_override("font", UiTheme.FONT_TITLE)
	_end_title.add_theme_font_size_override("font_size", 64)
	_end_title.add_theme_color_override("font_color", UiTheme.ALARM)
	column.add_child(_end_title)
	_end_body = Label.new()
	_end_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_end_body.add_theme_font_size_override("font_size", 22)
	column.add_child(_end_body)
	_end_stats = Label.new()
	_end_stats.add_theme_color_override("font_color", UiTheme.DIM)
	column.add_child(_end_stats)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 12)
	column.add_child(buttons)
	var again := Button.new()
	again.name = "PlayAgain"
	again.text = "Play again"
	again.pressed.connect(func() -> void: get_tree().reload_current_scene())
	buttons.add_child(again)
	var title := Button.new()
	title.text = "Main menu"
	title.pressed.connect(_quit_to_title)
	buttons.add_child(title)

func _quit_to_title() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/title.tscn")
