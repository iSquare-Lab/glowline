class_name MenuLogo
extends Control
## The sun and three lanterns on the menu, drawn like the board, glowing softly.

var _t := 0.0


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	var c := size / 2.0 + Vector2(0, 6)
	var glow := 0.5 + 0.5 * sin(_t * 2.0)
	var pipe := 12.0
	var ends := [Vector2(-90, 8), Vector2(90, 8), Vector2(0, -36)]
	for e: Vector2 in ends:
		draw_line(c, c + e, Color(1.0, 0.72, 0.25, 0.22), pipe * 2.4)
		draw_line(c, c + e, Color("ffc457"), pipe)
	for e: Vector2 in ends:
		draw_circle(c + e, 24.0 + glow * 6.0, Color(1.0, 0.75, 0.3, 0.16))
		draw_circle(c + e, 18.0, Color("ffcf6b"))
		draw_circle(c + e, 9.0, Color("fff7e3"))
	draw_circle(c, 44.0 + glow * 8.0, Color(1.0, 0.78, 0.3, 0.12))
	draw_circle(c, 32.0, Color("ffd27a"))
	draw_circle(c, 17.0, Color("fff4d6"))
