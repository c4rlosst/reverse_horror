extends Control
## Title screen: the name flickers like a failing hall light, the phone rings
## once in a while, and nothing else moves.

const GAME_SCENE := "res://scenes/game.tscn"

var _title: Label
var _lamp: ColorRect
var _menu: VBoxContainer
var _settings: VBoxContainer
var _fade: ColorRect
var _ring_timer: float = 4.0
var _starting: bool = false

func _ready() -> void:
	theme = UiTheme.build()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_build()
	Sfx.loop(&"ambient", -10.0, self)
	(_menu.get_child(0) as Button).grab_focus()
	create_tween().tween_property(_fade, "modulate:a", 0.0, 1.5)

func _process(delta: float) -> void:
	_ring_timer -= delta
	if _ring_timer <= 0.0:
		Sfx.play(&"phone_ring", -22.0)
		_ring_timer = randf_range(11.0, 16.0)
	var flicker := 1.0
	if randf() < 0.035:
		flicker = randf_range(0.25, 0.7)
	_title.modulate.a = lerpf(_title.modulate.a, flicker, 0.6)
	_lamp.color.a = lerpf(_lamp.color.a, 0.16 * flicker, 0.3)

func _build() -> void:
	_lamp = ColorRect.new()
	_lamp.color = Color(UiTheme.AMBER, 0.16)
	_lamp.set_anchors_preset(Control.PRESET_FULL_RECT)
	_lamp.anchor_left = 0.86
	_lamp.anchor_right = 0.862
	_lamp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_lamp)

	var column := VBoxContainer.new()
	column.set_anchors_preset(Control.PRESET_FULL_RECT)
	column.offset_left = 96
	column.offset_top = 96
	column.offset_right = -96
	column.offset_bottom = -64
	column.add_theme_constant_override("separation", 14)
	add_child(column)

	_title = Label.new()
	_title.text = "Welcome Home"
	_title.add_theme_font_override("font", UiTheme.FONT_TITLE)
	_title.add_theme_font_size_override("font_size", 96)
	column.add_child(_title)

	var tagline := Label.new()
	tagline.text = "A house-sitting job. One night. Someone else is in the house."
	tagline.add_theme_color_override("font_color", UiTheme.DIM)
	column.add_child(tagline)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 28)
	column.add_child(spacer)

	_menu = VBoxContainer.new()
	_menu.add_theme_constant_override("separation", 10)
	_menu.custom_minimum_size = Vector2(300, 0)
	_menu.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	column.add_child(_menu)
	_menu_button("Start game", _start)
	_menu_button("Settings", _toggle_settings)
	_menu_button("Quit", func() -> void: get_tree().quit())

	_settings = VBoxContainer.new()
	_settings.add_theme_constant_override("separation", 8)
	_settings.visible = false
	_settings.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	UiTheme.settings_rows(_settings)
	column.add_child(_settings)

	var filler := Control.new()
	filler.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(filler)

	var controls := Label.new()
	controls.text = "WASD move   Shift run   C crouch   E interact   F flashlight   Esc pause\nPlays best in the dark, with headphones."
	controls.add_theme_color_override("font_color", UiTheme.DIM)
	controls.add_theme_font_size_override("font_size", 16)
	column.add_child(controls)

	_fade = ColorRect.new()
	_fade.color = Color.BLACK
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fade)
	move_child($PostFx, get_child_count() - 2)

func _menu_button(text: String, action: Callable) -> void:
	var button := Button.new()
	button.text = text
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.pressed.connect(action)
	_menu.add_child(button)

func _toggle_settings() -> void:
	_settings.visible = not _settings.visible

func _start() -> void:
	if _starting:
		return
	_starting = true
	var tween := create_tween()
	tween.tween_property(_fade, "modulate:a", 1.0, 0.8)
	await tween.finished
	get_tree().change_scene_to_file(GAME_SCENE)
