class_name UiTheme
extends RefCounted
## Menu and HUD styling. Palette comes from the house at night: lamp amber on
## ink-dark, bone-coloured text, and a dim grey for secondary lines.

const INK := Color("#0B0D12")
const PANEL := Color("#14171E")
const EDGE := Color("#2A2F3A")
const BONE := Color("#E8E2D4")
const DIM := Color("#8C877B")
const AMBER := Color("#D9963F")
const ALARM := Color("#B3322B")

const FONT_UI: FontFile = preload("res://fonts/IBMPlexMono-Regular.ttf")
const FONT_UI_BOLD: FontFile = preload("res://fonts/IBMPlexMono-Medium.ttf")
const FONT_TITLE: FontFile = preload("res://fonts/SpecialElite-Regular.ttf")

static func build() -> Theme:
	var theme := Theme.new()
	theme.default_font = FONT_UI
	theme.default_font_size = 20
	theme.set_color("font_color", "Label", BONE)
	theme.set_color("font_color", "Button", BONE)
	theme.set_color("font_hover_color", "Button", BONE)
	theme.set_color("font_focus_color", "Button", BONE)
	theme.set_color("font_pressed_color", "Button", AMBER)
	theme.set_font("font", "Button", FONT_UI_BOLD)
	theme.set_stylebox("normal", "Button", _box(PANEL, EDGE))
	theme.set_stylebox("hover", "Button", _box(Color("#1C212B"), DIM))
	theme.set_stylebox("pressed", "Button", _box(Color("#1C212B"), AMBER))
	theme.set_stylebox("focus", "Button", _box(Color("#1C212B"), AMBER, 2))
	theme.set_stylebox("slider", "HSlider", _box(EDGE, EDGE, 0, 2, Vector2(0, 2)))
	theme.set_stylebox("grabber_area", "HSlider", _box(AMBER, AMBER, 0, 2, Vector2(0, 2)))
	theme.set_stylebox("grabber_area_highlight", "HSlider", _box(AMBER, AMBER, 0, 2, Vector2(0, 2)))
	return theme

static func _box(fill: Color, border: Color, border_width: int = 1, radius: int = 2, padding: Vector2 = Vector2(18, 10)) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = border
	box.set_border_width_all(border_width)
	box.set_corner_radius_all(radius)
	box.content_margin_left = padding.x
	box.content_margin_right = padding.x
	box.content_margin_top = padding.y
	box.content_margin_bottom = padding.y
	return box

static func panel(alpha: float = 0.82, padding: Vector2 = Vector2(18, 10)) -> StyleBoxFlat:
	var box := _box(Color(INK.r, INK.g, INK.b, alpha), Color(0, 0, 0, 0), 0, 2, padding)
	return box

## Slider rows for the settings (shared by title and pause menu).
static func settings_rows(parent: Container) -> void:
	_slider_row(parent, "Mouse sensitivity", 0.2, 3.0, GameState.mouse_sensitivity, func(value: float) -> void:
		GameState.mouse_sensitivity = value
		GameState.save_settings())
	_slider_row(parent, "Volume", 0.0, 1.0, GameState.master_volume, func(value: float) -> void:
		GameState.master_volume = value
		GameState.apply_volume()
		GameState.save_settings())

static func _slider_row(parent: Container, label_text: String, low: float, high: float, value: float, on_change: Callable) -> void:
	var label := Label.new()
	label.text = label_text
	label.add_theme_color_override("font_color", DIM)
	parent.add_child(label)
	var slider := HSlider.new()
	slider.min_value = low
	slider.max_value = high
	slider.step = 0.05
	slider.value = value
	slider.custom_minimum_size = Vector2(320, 24)
	slider.value_changed.connect(on_change)
	parent.add_child(slider)
