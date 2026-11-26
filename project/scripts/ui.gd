class_name Ui
extends RefCounted
## The look every screen shares: colours, the theme, and small builders for labels and buttons.

## A garden at dusk: plum sky, warm cream text, honey light. No cold blues.
const SKY_TOP := Color("1f1629")
const SKY_BOTTOM := Color("5a3446")
const HORIZON := Color("c9805a")
const BG := SKY_TOP
const PANEL := Color("2b1f35")
const BUTTON := Color("3d2c45")
const BUTTON_HOVER := Color("4d3956")
const ACCENT := Color("f6b85e")
const ON_ACCENT := Color("2a1606")
const TEXT := Color("fbefe0")
const MUTED := Color("e0cbbd")
const FOCUS := Color("ffe2a3")
## The canvas is 480 units wide at least, so on a 390 px phone a unit is 0.81 px: 54 units are 44 px.
const BUTTON_HEIGHT := 54


static func box(color: Color, radius: int = 14, border: Color = Color.TRANSPARENT) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(radius)
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	if border.a > 0.0:
		style.set_border_width_all(3)
		style.border_color = border
	style.anti_aliasing = true
	return style


static func make_theme() -> Theme:
	var t := Theme.new()
	t.default_font_size = 20
	t.set_color("font_color", "Label", TEXT)
	t.set_color("font_color", "Button", TEXT)
	t.set_color("font_hover_color", "Button", TEXT)
	t.set_color("font_pressed_color", "Button", TEXT)
	t.set_color("font_focus_color", "Button", TEXT)
	t.set_color("font_disabled_color", "Button", Color(MUTED, 0.55))
	t.set_stylebox("normal", "Button", box(BUTTON))
	t.set_stylebox("hover", "Button", box(BUTTON_HOVER))
	t.set_stylebox("pressed", "Button", box(BUTTON.darkened(0.2)))
	t.set_stylebox("disabled", "Button", box(Color(BUTTON, 0.45)))
	t.set_stylebox("focus", "Button", box(Color.TRANSPARENT, 14, FOCUS))
	t.set_stylebox("panel", "PanelContainer", box(PANEL, 22))
	return t


## Gives `button` the gold look of the main action on a screen.
static func accent(button: Button) -> Button:
	button.add_theme_stylebox_override("normal", box(ACCENT))
	button.add_theme_stylebox_override("hover", box(ACCENT.lightened(0.12)))
	button.add_theme_stylebox_override("pressed", box(ACCENT.darkened(0.12)))
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		button.add_theme_color_override(state, ON_ACCENT)
	return button


static func label(text: String, font_size: int = 24, color: Color = TEXT) -> Label:
	var result := Label.new()
	result.text = text
	result.add_theme_font_size_override("font_size", font_size)
	result.add_theme_color_override("font_color", color)
	return result


static func button(text: String, action: Callable) -> Button:
	var result := Button.new()
	result.text = text
	result.focus_mode = Control.FOCUS_ALL
	result.custom_minimum_size = Vector2(0, BUTTON_HEIGHT)
	result.pressed.connect(action)
	return result


static func spacer(height: int) -> Control:
	var result := Control.new()
	result.custom_minimum_size = Vector2(0, height)
	return result


## "1 move", "18 moves".
static func count_of(amount: int, singular: String, plural: String = "") -> String:
	if amount == 1:
		return "1 " + singular
	return "%d %s" % [amount, plural if plural != "" else singular + "s"]


static var _reduced_motion := -1


## True when the player asked the system for less motion (prefers-reduced-motion on the web): light then
## shows at once, lanterns hang still and no fireflies fly.
static func reduced_motion() -> bool:
	if _reduced_motion < 0:
		_reduced_motion = 0
		if OS.has_feature("web"):
			var reduce: Variant = JavaScriptBridge.eval("window.matchMedia('(prefers-reduced-motion: reduce)').matches", true)
			# The bridge hands a JavaScript boolean back as an int (1 or 0), so convert it.
			_reduced_motion = 1 if bool(reduce) else 0
	return _reduced_motion == 1
