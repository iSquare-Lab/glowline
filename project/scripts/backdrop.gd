class_name Backdrop
extends Control
## The dusk sky behind every screen: plum above, rose lower down, a faint apricot glow at the horizon.

## How far the horizon glow goes from rose to apricot. Kept low so the muted text above the buttons keeps
## a contrast of 4.5:1.
const GLOW := 0.4


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var w := size.x
	var h := size.y
	var horizon := h * 0.78
	var low := Ui.SKY_BOTTOM.lerp(Ui.HORIZON, GLOW)
	draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(w, 0), Vector2(w, horizon), Vector2(0, horizon)]),
		PackedColorArray([Ui.SKY_TOP, Ui.SKY_TOP, Ui.SKY_BOTTOM, Ui.SKY_BOTTOM]))
	draw_polygon(PackedVector2Array([Vector2(0, horizon), Vector2(w, horizon), Vector2(w, h), Vector2(0, h)]),
		PackedColorArray([Ui.SKY_BOTTOM, Ui.SKY_BOTTOM, low, low]))
