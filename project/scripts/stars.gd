class_name Stars
extends Control
## A row of three stars, `filled` of them lit. Drawn, because the built-in font has no star glyph.

var filled := 0:
	set(value):
		filled = value
		queue_redraw()

const ON := Color("ffc457")
const OFF := Color("3a4560")


func _init(count: int = 0, star_size: float = 48.0) -> void:
	filled = count
	custom_minimum_size = Vector2(star_size * 3.4, star_size)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var r := size.y / 2.0
	var step := size.x / 3.0
	for k in 3:
		var center := Vector2(step * (k + 0.5), size.y / 2.0)
		var points := PackedVector2Array()
		for p in 10:
			var angle := -PI / 2.0 + p * PI / 5.0
			var radius := r if p % 2 == 0 else r * 0.45
			points.append(center + Vector2(cos(angle), sin(angle)) * radius)
		draw_colored_polygon(points, ON if k < filled else OFF)
